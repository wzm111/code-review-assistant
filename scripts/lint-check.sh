#!/bin/bash
# 代码规范自动检查
# 运行 ESLint, Prettier, Black, gofmt, flake8 等

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

TARGET_DIR="${1:-.}"

echo -e "${CYAN}🎨 Lint Check / 代码规范检查${NC}"
echo "=========================================="
echo ""

cd "$TARGET_DIR"

# 获取变更文件
CHANGED_FILES=$(git diff --name-only HEAD~1..HEAD 2>/dev/null || git diff --name-only 2>/dev/null || true)

if [[ -z "$CHANGED_FILES" ]]; then
    echo -e "${YELLOW}无变更文件${NC}"
    exit 0
fi

has_errors=false

# 1. ESLint (JavaScript/TypeScript)
js_files=$(printf '%s\n' "$CHANGED_FILES" | grep -E '\.(js|ts|jsx|tsx)$' || true)
if [[ -n "$js_files" ]]; then
    echo -e "${CYAN}【ESLint】${NC}"

    if [[ -f ".eslintrc.js" || -f ".eslintrc.json" || -f ".eslintrc" || -f "eslint.config.js" ]]; then
        if command -v npx &> /dev/null; then
            printf '%s\n' "$js_files" | while read -r file; do
                if [[ -f "$file" ]]; then
                    npx eslint "$file" --format compact 2>&1 | head -5 || true
                fi
            done
        else
            echo -e "  ${YELLOW}⚠️ npx 未安装${NC}"
        fi
    else
        echo -e "  ${YELLOW}⚠️ 未找到 ESLint 配置文件${NC}"
    fi
    echo ""
fi

# 2. Prettier (格式化检查)
web_files=$(printf '%s\n' "$CHANGED_FILES" | grep -E '\.(js|ts|jsx|tsx|css|scss|html|json|md|yaml|yml)$' || true)
if [[ -n "$web_files" ]]; then
    echo -e "${CYAN}【Prettier】${NC}"

    if [[ -f ".prettierrc" || -f ".prettierrc.js" || -f ".prettierrc.json" || -f "prettier.config.js" ]]; then
        if command -v npx &> /dev/null; then
            printf '%s\n' "$web_files" | while read -r file; do
                if [[ -f "$file" ]]; then
                    result=$(npx prettier --check "$file" 2>&1 || true)
                    if [[ "$result" =~ "Checking formatting".*"[warn]" ]]; then
                        echo -e "  ${YELLOW}🟡 ${file} (格式不一致)${NC}"
                        has_errors=true
                    elif [[ "$result" =~ "Checking formatting".*"[error]" ]]; then
                        echo -e "  ${RED}🔴 ${file} (格式错误)${NC}"
                        has_errors=true
                    fi
                fi
            done
            if [[ "$has_errors" == false ]]; then
                echo -e "  ${GREEN}✅ 格式检查通过${NC}"
            fi
        fi
    fi
    echo ""
fi

# 3. Black (Python)
py_files=$(printf '%s\n' "$CHANGED_FILES" | grep -E '\.py$' || true)
if [[ -n "$py_files" ]]; then
    echo -e "${CYAN}【Black / Python】${NC}"

    if command -v black &> /dev/null; then
        printf '%s\n' "$py_files" | while read -r file; do
            if [[ -f "$file" ]]; then
                result=$(black --check "$file" 2>&1 || true)
                if [[ "$result" =~ "would reformat" ]]; then
                    echo -e "  ${YELLOW}🟡 ${file} (需要格式化)${NC}"
                    has_errors=true
                fi
            fi
        done
        if [[ "$has_errors" == false ]]; then
            echo -e "  ${GREEN}✅ Black 检查通过${NC}"
        fi
    else
        echo -e "  ${YELLOW}⚠️ Black 未安装 (pip install black)${NC}"
    fi
    echo ""
fi

# 4. gofmt (Go)
go_files=$(printf '%s\n' "$CHANGED_FILES" | grep -E '\.go$' || true)
if [[ -n "$go_files" ]]; then
    echo -e "${CYAN}【gofmt】${NC}"

    if command -v gofmt &> /dev/null; then
        printf '%s\n' "$go_files" | while read -r file; do
            if [[ -f "$file" ]]; then
                diff=$(gofmt -d "$file" 2>/dev/null || true)
                if [[ -n "$diff" ]]; then
                    echo -e "  ${YELLOW}🟡 ${file} (格式不一致)${NC}"
                    has_errors=true
                fi
            fi
        done
        if [[ "$has_errors" == false ]]; then
            echo -e "  ${GREEN}✅ gofmt 检查通过${NC}"
        fi
    fi
    echo ""
fi

# 5. PHP CS Fixer
php_files=$(printf '%s\n' "$CHANGED_FILES" | grep -E '\.php$' || true)
if [[ -n "$php_files" ]]; then
    echo -e "${CYAN}【PHP】${NC}"
    if command -v php &> /dev/null; then
        printf '%s\n' "$php_files" | while read -r file; do
            if [[ -f "$file" ]]; then
                # 简单语法检查
                php -l "$file" 2>&1 | grep -v "No syntax errors" || true
            fi
        done
    fi
    echo ""
fi

# 6. 通用检查：尾随空格、Tab 混用
echo -e "${CYAN}【通用检查】${NC}"

trailing_space=false
tab_mix=false

while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    [[ -f "$file" ]] || continue

    # 尾随空格
    if grep -n ' $' "$file" > /dev/null 2>&1; then
        if [[ "$trailing_space" == false ]]; then
            echo -e "  ${YELLOW}⚠️ 尾随空格:${NC}"
            trailing_space=true
        fi
        echo "    ${file}"
    fi

    # Tab/空格混用（对缩进敏感的文件）
    if [[ "$file" =~ \.(py|yaml|yml)$ ]]; then
        if grep -n $'\t' "$file" > /dev/null 2>&1; then
            if [[ "$tab_mix" == false ]]; then
                echo -e "  ${YELLOW}⚠️ Tab/空格混用:${NC}"
                tab_mix=true
            fi
            echo "    ${file}"
        fi
    fi
done <<< "$CHANGED_FILES"

if [[ "$trailing_space" == false && "$tab_mix" == false ]]; then
    echo -e "  ${GREEN}✅ 通用检查通过${NC}"
fi

echo ""

if [[ "$has_errors" == true ]]; then
    echo -e "${YELLOW}提示: 运行格式化工具自动修复${NC}"
    echo "  npx prettier --write ."
    echo "  black ."
    echo "  gofmt -w ."
    exit 1
else
    echo -e "${GREEN}✅ 所有规范检查通过${NC}"
    exit 0
fi
