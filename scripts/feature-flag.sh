#!/bin/bash
# Feature Flag 清理检测
# 发现过期/已发布 feature flag 的残留代码

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

TARGET_DIR="${1:-.}"

echo -e "${CYAN}🚩 Feature Flag / 功能开关清理检测${NC}"
echo "=========================================="
echo ""

cd "$TARGET_DIR"

# 检测 feature flag 配置文件
FLAG_CONFIG=""
FLAG_LIST=""

# LaunchDarkly / Unleash / 自定义
if [[ -f "feature-flags.json" ]]; then
    FLAG_CONFIG="feature-flags.json"
elif [[ -f "flags.yml" ]] || [[ -f "flags.yaml" ]]; then
    FLAG_CONFIG=$(find . -maxdepth 2 -name "flags.*" 2>/dev/null | head -1)
elif [[ -f ".env" ]] && grep -q "FEATURE_" .env 2>/dev/null; then
    FLAG_CONFIG=".env"
fi

# 提取已知的 flag 名称
KNOWN_FLAGS=""
if [[ -n "$FLAG_CONFIG" ]]; then
    KNOWN_FLAGS=$(cat "$FLAG_CONFIG" 2>/dev/null | grep -oE '[A-Za-z_][A-Za-z0-9_]*' | grep -iE 'feature|flag|toggle' | sort -u || true)
fi

# 获取变更文件
CHANGED_FILES=$(git diff --name-only HEAD~1..HEAD 2>/dev/null | grep -E '\.(js|ts|jsx|tsx|vue|py|go|java|php)$' || true)

if [[ -z "$CHANGED_FILES" ]]; then
    echo -e "${YELLOW}无源码文件变更${NC}"
    exit 0
fi

echo -e "${CYAN}【扫描 feature flag 代码】${NC}"
echo ""

flag_usage=()
old_flags=()

while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    [[ -f "$file" ]] || continue

    content=$(cat "$file" 2>/dev/null || true)
    [[ -z "$content" ]] && continue

    # 检测常见的 feature flag 使用模式
    # JavaScript/TypeScript
    js_flags=$(printf '%s\n' "$content" | grep -nE 'isFeatureEnabled|featureFlag|useFeatureFlag|FLAGS\.|feature\.' 2>/dev/null || true)
    if [[ -n "$js_flags" ]]; then
        flag_usage+=("$file:")
        while IFS= read -r line; do
            flag_usage+=("  $line")
        done <<< "$js_flags"
    fi

    # 检测老旧的 flag 判断模式 (if/else 包裹大量代码)
    old_pattern=$(printf '%s\n' "$content" | grep -nE 'if\s*\(\s*(feature|flag|toggle)' 2>/dev/null || true)
    if [[ -n "$old_pattern" ]]; then
        # 统计 if 块内的行数
        old_flags+=("$file: 包含 feature flag 条件分支")
    fi

done <<< "$CHANGED_FILES"

# 输出结果
echo -e "${CYAN}【检测结果】${NC}"
echo ""

if [[ ${#flag_usage[@]} -gt 0 ]]; then
    echo -e "${YELLOW}🟡 本次变更涉及 Feature Flag:${NC}"
    for item in "${flag_usage[@]}"; do
        echo "  $item"
    done
    echo ""
fi

if [[ ${#old_flags[@]} -gt 0 ]]; then
    echo -e "${YELLOW}🟡 历史 Feature Flag 代码 (可清理):${NC}"
    for item in "${old_flags[@]}"; do
        echo "  - $item"
    done
    echo ""
    echo -e "${CYAN}【清理建议】${NC}"
    echo "  1. 检查 flag 是否已全量发布"
    echo "  2. 移除 flag 判断，保留 true 分支代码"
    echo "  3. 删除 flag 配置"
    echo "  4. 更新相关测试"
fi

if [[ ${#flag_usage[@]} -eq 0 && ${#old_flags[@]} -eq 0 ]]; then
    echo -e "  ${GREEN}✅ 本次变更未涉及 Feature Flag${NC}"
fi
