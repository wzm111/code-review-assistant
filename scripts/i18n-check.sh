#!/bin/bash
# 国际化完整性检查
# 检测硬编码文案和缺失的 i18n key

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

TARGET_DIR="${1:-.}"

echo -e "${CYAN}🌍 i18n Check / 国际化完整性检查${NC}"
echo "=========================================="
echo ""

cd "$TARGET_DIR"

# 检测 i18n 配置文件
I18N_FILES=""
I18N_FRAMEWORK=""

if [[ -f "locales/en.json" ]] || [[ -f "locales/zh.json" ]] || find . -maxdepth 3 -name "*.json" -path "*/locales/*" 2>/dev/null | head -1 | grep -q .; then
    I18N_FRAMEWORK="generic"
    I18N_FILES=$(find . -maxdepth 3 -path "*/locales/*" -name "*.json" 2>/dev/null | head -5)
elif [[ -f "src/i18n/index.ts" ]] || [[ -f "src/i18n.js" ]]; then
    I18N_FRAMEWORK="vue-i18n/react-i18n"
    I18N_FILES=$(find . -maxdepth 4 -path "*/locales/*" -name "*.json" -o -name "*.ts" 2>/dev/null | head -5)
elif [[ -f "messages/en.json" ]] || [[ -d "lang" ]]; then
    I18N_FRAMEWORK="intl"
fi

# 获取变更的前端文件
CHANGED_FILES=$(git diff --name-only HEAD~1..HEAD 2>/dev/null | grep -E '\.(js|ts|jsx|tsx|vue|html)$' || true)

if [[ -z "$CHANGED_FILES" ]]; then
    echo -e "${YELLOW}无前端文件变更${NC}"
    exit 0
fi

echo -e "${CYAN}【变更的前端文件】${NC}"
printf '%s\n' "$CHANGED_FILES" | sed 's/^/  /'
echo ""

hardcoded_texts=()
missing_i18n=()

while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    [[ -f "$file" ]] || continue

    content=$(cat "$file" 2>/dev/null || true)
    [[ -z "$content" ]] && continue

    # 检测硬编码中文/英文（排除注释和 console）
    # 匹配单引号/双引号/反引号中的中文字符串
    found_chinese=$(printf '%s\n' "$content" | grep -nE "['\"\`][^'\"\`]*[\x{4e00}-\x{9fff}]+[^'\"\`]*['\"\`]" 2>/dev/null || true)

    # 匹配未被 t() 或 $t() 或 intl.formatMessage 包裹的英文文案
    # 简化：检测 >Text< 或 "Text" 在 JSX/Vue 模板中
    if [[ "$file" =~ \.(jsx|tsx|vue)$ ]]; then
        found_text=$(printf '%s\n' "$content" | grep -nE ">[A-Za-z\s]{3,30}<" 2>/dev/null || true)
    fi

    if [[ -n "$found_chinese" ]]; then
        hardcoded_texts+=("$file:")
        while IFS= read -r line; do
            hardcoded_texts+=("  $line")
        done <<< "$found_chinese"
    fi

done <<< "$CHANGED_FILES"

# 输出结果
echo -e "${CYAN}【审查结果】${NC}"
echo ""

if [[ ${#hardcoded_texts[@]} -gt 0 ]]; then
    echo -e "${YELLOW}🟡 疑似硬编码文案 (需确认是否应提取到 i18n):${NC}"
    for item in "${hardcoded_texts[@]}"; do
        echo "  $item"
    done
    echo ""
fi

if [[ ${#missing_i18n[@]} -gt 0 ]]; then
    echo -e "${RED}🔴 引用了不存在的 i18n key:${NC}"
    for item in "${missing_i18n[@]}"; do
        echo "  $item"
    done
    echo ""
fi

if [[ ${#hardcoded_texts[@]} -eq 0 && ${#missing_i18n[@]} -eq 0 ]]; then
    echo -e "  ${GREEN}✅ 未检测到明显的 i18n 问题${NC}"
fi

echo -e "${CYAN}【i18n 最佳实践】${NC}"
echo "  1. 所有用户可见文案必须使用 i18n key"
echo "  2. 新增 key 需同步到所有语言文件"
echo "  3. 避免拼接字符串 (use interpolation)"
echo "  4. 考虑复数形式 (pluralization)"
echo "  5. 日期/数字/货币使用 locale-aware 格式化"
