#!/bin/bash
# 敏感个人信息 (PII) 扫描
# 检测日志/API响应中可能泄露的个人隐私数据

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

TARGET_DIR="${1:-.}"
SEVERITY="${2:-all}"

echo -e "${CYAN}🔒 PII Scan / 敏感个人信息扫描${NC}"
echo "=========================================="
echo ""

cd "$TARGET_DIR"

CHANGED_FILES=$(git diff --name-only HEAD~1..HEAD 2>/dev/null || git diff --name-only 2>/dev/null || true)

if [[ -z "$CHANGED_FILES" ]]; then
    echo -e "${YELLOW}无变更文件${NC}"
    exit 0
fi

critical_findings=()
warnings=()

# PII 正则模式
PATTERNS_CRITICAL=(
    # 中国大陆手机号
    '1[3-9][0-9]{9}'
    # 身份证号 (18位)
    '[1-9][0-9]{5}(19|20)[0-9]{2}((0[1-9])|(1[0-2]))(([0-2][1-9])|10|20|30|31)[0-9Xx]{4}'
    # 银行卡号 (16-19位)
    '[0-9]{16,19}'
)

PATTERNS_WARN=(
    # 邮箱
    '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'
    # IP 地址
    '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'
    # 护照号
    '[EG]\d{8}'
)

# 高风险上下文（日志、API响应、console）
CONTEXT_KEYWORDS='console\.(log|warn|error|info)|logger\.|log\.|\bprint\(|response\.|return\s+|res\.(send|json|body)'

echo -e "${CYAN}【扫描范围】${NC} 变更文件中的 PII 数据"
echo ""

while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    [[ -f "$file" ]] || continue

    content=$(cat "$file" 2>/dev/null || true)
    [[ -z "$content" ]] && continue

    # 只扫描源码文件
    if ! [[ "$file" =~ \.(js|ts|jsx|tsx|vue|py|go|java|php|rb|swift|kt|dart|rs|c|cpp|h|m|mm)$ ]]; then
        continue
    fi

    # 检测高危 PII
    for pattern in "${PATTERNS_CRITICAL[@]}"; do
        matches=$(printf '%s\n' "$content" | grep -nE "$pattern" 2>/dev/null || true)
        if [[ -n "$matches" ]]; then
            # 检查是否在高风险上下文
            context_match=false
            while IFS= read -r line; do
                line_num=$(printf '%s\n' "$line" | cut -d: -f1)
                # 获取前后几行作为上下文
                context=$(sed -n "$((line_num-2)),$((line_num+2))p" "$file" 2>/dev/null || true)
                if printf '%s\n' "$context" | grep -qiE "$CONTEXT_KEYWORDS"; then
                    context_match=true
                    break
                fi
            done <<< "$matches"

            if [[ "$context_match" == true ]]; then
                critical_findings+=("$file: 检测到 $pattern 且位于日志/响应上下文")
            else
                warnings+=("$file: 检测到 $pattern")
            fi
        fi
    done

    # 检测邮箱/IP 等
    for pattern in "${PATTERNS_WARN[@]}"; do
        matches=$(printf '%s\n' "$content" | grep -nE "$pattern" 2>/dev/null | head -3 || true)
        if [[ -n "$matches" ]]; then
            warnings+=("$file: 检测到 $pattern")
        fi
    done

done <<< "$CHANGED_FILES"

# 输出结果
echo -e "${CYAN}【扫描结果】${NC}"
echo ""

if [[ ${#critical_findings[@]} -gt 0 ]]; then
    echo -e "${RED}🔴 高危 (可能泄露个人隐私):${NC}"
    for f in "${critical_findings[@]}"; do
        echo "  - $f"
    done
    echo ""
fi

if [[ ${#warnings[@]} -gt 0 ]]; then
    echo -e "${YELLOW}🟡 警告 (检测到 PII 模式):${NC}"
    for w in "${warnings[@]}"; do
        echo "  - $w"
    done
    echo ""
fi

if [[ ${#critical_findings[@]} -eq 0 && ${#warnings[@]} -eq 0 ]]; then
    echo -e "  ${GREEN}✅ 未检测到 PII 数据泄露风险${NC}"
fi

echo -e "${CYAN}【数据隐私最佳实践】${NC}"
echo "  1. 日志中禁止输出手机号、身份证号等敏感字段"
echo "  2. API 响应脱敏处理 (如: 138****8888)"
echo "  3. 数据库加密存储敏感信息"
echo "  4. 遵守 GDPR / 个人信息保护法"
echo "  5. 访问敏感数据需审计日志"

if [[ ${#critical_findings[@]} -gt 0 ]]; then
    exit 1
fi
