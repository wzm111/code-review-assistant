#!/bin/bash
# 供应链安全扫描
# 检测 typosquatting 攻击、已知恶意包、依赖劫持

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

TARGET_DIR="${1:-.}"

echo -e "${CYAN}🔗 Supply Chain / 供应链安全${NC}"
echo "=========================================="
echo ""

cd "$TARGET_DIR"

# 检测包管理文件变更
PKG_FILES=$(git diff --name-only HEAD~1..HEAD 2>/dev/null | grep -E 'package\.json|requirements\.txt|go\.mod|Cargo\.toml|composer\.json|pom\.xml|build\.gradle|package-lock\.json|yarn\.lock' || true)

if [[ -z "$PKG_FILES" ]]; then
    echo -e "${YELLOW}未检测到依赖文件变更${NC}"
    exit 0
fi

echo -e "${CYAN}【变更的依赖文件】${NC}"
printf '%s\n' "$PKG_FILES" | sed 's/^/  /'
echo ""

risks=()

# 常见 typosquatting 目标（流行包的拼写变体）
TYPO_TARGETS=(
    "lodash" "express" "request" "axios" "react" "vue" "angular"
    "django" "flask" "fastapi" "spring" "hibernate"
    "numpy" "pandas" "tensorflow" "pytorch"
    "webpack" "babel" "eslint" "prettier"
)

# 已知恶意包名模式
MALICIOUS_PATTERNS=(
    "node-fetch-native" "crossenv" "cross-env.js" "jquery.js"
    "mariadb-native" "mysql-native" "python-dateutilz"
    "djanga" "django-server" "setup-tools"
)

echo -e "${CYAN}【供应链风险分析】${NC}"
echo ""

# 提取新增依赖
new_deps=""
if printf '%s\n' "$PKG_FILES" | grep -q "package"; then
    if [[ -f "package.json" ]]; then
        current=$(cat package.json 2>/dev/null | grep -E '"\w+"\s*:\s*"[\^~]?[0-9]' || true)
        prev=$(git show HEAD~1:package.json 2>/dev/null | grep -E '"\w+"\s*:\s*"[\^~]?[0-9]' || true)
        if [[ -n "$current" && -n "$prev" ]]; then
            new_deps=$(comm -23 <(printf '%s\n' "$current" | sort) <(printf '%s\n' "$prev" | sort) || true)
        fi
    fi
elif printf '%s\n' "$PKG_FILES" | grep -q "requirements"; then
    if [[ -f "requirements.txt" ]]; then
        current=$(cat requirements.txt 2>/dev/null | grep -v '^#' | grep -v '^$' | sort || true)
        prev=$(git show HEAD~1:requirements.txt 2>/dev/null | grep -v '^#' | grep -v '^$' | sort || true)
        if [[ -n "$current" && -n "$prev" ]]; then
            new_deps=$(comm -23 <(echo "$current") <(echo "$prev") || true)
        fi
    fi
fi

if [[ -n "$new_deps" ]]; then
    echo -e "${CYAN}新增依赖:${NC}"
    printf '%s\n' "$new_deps" | sed 's/^/  /'
    echo ""

    # 检查 typosquatting
    while IFS= read -r dep; do
        dep_name=$(printf '%s\n' "$dep" | grep -oE '^[^=<>~^[:space:]]+' | head -1 || true)
        [[ -z "$dep_name" ]] && continue

        # 检查是否是知名包的拼写变体
        for target in "${TYPO_TARGETS[@]}"; do
            # 编辑距离近似检测
            if [[ "$dep_name" != "$target" ]] && [[ "${#dep_name}" -ge "${#target}" ]]; then
                # 简化：检查是否包含目标名但多了/少了字符
                if printf '%s\n' "$dep_name" | grep -qi "$target"; then
                    if [[ "${#dep_name}" -ne "${#target}" ]]; then
                        risks+=("$dep_name: 疑似 $target 的拼写变体 (typosquatting)")
                    fi
                fi
            fi
        done

        # 检查已知恶意模式
        for pattern in "${MALICIOUS_PATTERNS[@]}"; do
            if [[ "$dep_name" == "$pattern" ]]; then
                risks+=("$dep_name: 匹配已知恶意包名模式")
            fi
        done

        # 检查不寻常的包名
        if printf '%s\n' "$dep_name" | grep -qE '[0-9]{4,}|_{3,}|^-|[A-Z]{5,}'; then
            risks+=("$dep_name: 包名异常，请人工确认")
        fi
    done <<< "$new_deps"
else
    echo -e "  ${YELLOW}未检测到新增依赖${NC}"
fi

echo ""
echo -e "${CYAN}【检查结果】${NC}"
echo ""

if [[ ${#risks[@]} -gt 0 ]]; then
    echo -e "${RED}🔴 供应链风险:${NC}"
    for risk in "${risks[@]}"; do
        echo "  - $risk"
    done
    echo ""
    echo -e "${YELLOW}⚠️ 请在 npm/pypi 官网验证这些包的真实性${NC}"
else
    echo -e "  ${GREEN}✅ 未检测到明显的供应链风险${NC}"
fi

echo -e "${CYAN}【供应链安全最佳实践】${NC}"
echo "  1. 使用 lock 文件固定依赖版本"
echo "  2. 安装前在 npmjs.com / pypi.org 验证包信息"
echo "  3. 检查包的下载量、维护状态、GitHub 星数"
echo "  4. 使用私有 registry 或 verdaccio"
echo "  5. 在 CI 中集成 Snyk / npm audit"
echo "  6. 定期审查依赖树 (npm ls / pipdeptree)"
echo "  7. 使用 Dependabot 自动更新安全补丁"

if [[ ${#risks[@]} -gt 0 ]]; then
    exit 1
fi
