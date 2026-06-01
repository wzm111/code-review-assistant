#!/bin/bash
# 配置漂移检测
# 检测环境配置与模板不一致、敏感值硬编码等问题

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

TARGET_DIR="${1:-.}"

echo -e "${CYAN}🔧 Config Drift / 配置漂移检测${NC}"
echo "=========================================="
echo ""

cd "$TARGET_DIR"

CHANGED_FILES=$(git diff --name-only HEAD~1..HEAD 2>/dev/null | grep -E '\.(env|yaml|yml|json|toml|ini|conf|config\.js|config\.ts)$' || true)

if [[ -z "$CHANGED_FILES" ]]; then
    echo -e "${YELLOW}无配置文件变更${NC}"
    exit 0
fi

issues=()

echo -e "${CYAN}【扫描配置文件】${NC}"
echo ""

while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    [[ -f "$file" ]] || continue

    content=$(cat "$file" 2>/dev/null || true)
    [[ -z "$content" ]] && continue

    # 1. 硬编码敏感值
    sensitive=$(printf '%s\n' "$content" | grep -nE 'password\s*[:=]\s*[^${]|secret\s*[:=]\s*[^${]|token\s*[:=]\s*[^${]|api_key\s*[:=]\s*[^${]' || true)
    if [[ -n "$sensitive" ]]; then
        issues+=("$file: 配置中包含硬编码敏感值，应使用环境变量引用")
    fi

    # 2. 生产环境配置检查
    if [[ "$file" =~ \.(env|production|prod) ]]; then
        # 生产环境不应有 debug
        if printf '%s\n' "$content" | grep -qiE 'debug\s*[:=]\s*(true|1|on)'; then
            issues+=("$file: 生产环境配置开启了 debug 模式")
        fi

        # 不应使用本地数据库
        if printf '%s\n' "$content" | grep -qiE 'localhost|127\.0\.0\.1|0\.0\.0\.0'; then
            if printf '%s\n' "$content" | grep -qiE 'database|db_host|redis|mongo'; then
                issues+=("$file: 生产环境使用了本地地址")
            fi
        fi
    fi

    # 3. 配置项缺失检查（对比 .env.example）
    if [[ "$file" =~ \.env$ ]] && [[ -f ".env.example" ]]; then
        example_keys=$(cat .env.example | grep -oE '^[A-Za-z_][A-Za-z0-9_]*' | sort -u || true)
        actual_keys=$(printf '%s\n' "$content" | grep -oE '^[A-Za-z_][A-Za-z0-9_]*' | sort -u || true)
        missing=$(comm -23 <(echo "$example_keys") <(echo "$actual_keys") || true)
        if [[ -n "$missing" ]]; then
            issues+=("$file: 缺少 .env.example 中的配置项: $(printf '%s\n' "$missing" | tr '\n' ' ')")
        fi
    fi

    # 4. 重复配置
    dup_keys=$(printf '%s\n' "$content" | grep -oE '^[A-Za-z_][A-Za-z0-9_]*' | sort | uniq -d || true)
    if [[ -n "$dup_keys" ]]; then
        issues+=("$file: 重复的配置键: $(printf '%s\n' "$dup_keys" | tr '\n' ' ')")
    fi

    # 5. 配置格式问题
    if [[ "$file" =~ \.yaml$|\.yml$ ]]; then
        # 检查 YAML 基本格式
        if printf '%s\n' "$content" | grep -qE '^\s*\w+\s*:\s*[^\s]' && printf '%s\n' "$content" | grep -qE '^\s*\w+\s*:\s*$'; then
            : # 格式正常
        fi
        # 检测混合 tab/space
        if printf '%s\n' "$content" | grep -qE $'^\s*\t'; then
            issues+=("$file: YAML 使用 tab 缩进，应使用空格")
        fi
    fi

done <<< "$CHANGED_FILES"

echo -e "${CYAN}【检查结果】${NC}"
echo ""

if [[ ${#issues[@]} -gt 0 ]]; then
    echo -e "${YELLOW}🟡 配置问题:${NC}"
    for issue in "${issues[@]}"; do
        echo "  - $issue"
    done
    echo ""
else
    echo -e "  ${GREEN}✅ 配置检查通过${NC}"
fi

echo -e "${CYAN}【配置管理最佳实践】${NC}"
echo "  1. 敏感配置使用环境变量或 secret manager"
echo "  2. 维护 .env.example 作为配置模板"
echo "  3. 生产环境禁用 debug 模式"
echo "  4. 使用配置验证 (schema validation)"
echo "  5. 不同环境的配置使用不同文件"
echo "  6. 配置变更需同步更新文档"
