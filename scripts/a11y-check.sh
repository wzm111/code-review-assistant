#!/bin/bash
# 无障碍检查 (Accessibility)
# 检测前端组件缺少 ARIA 标签、颜色对比度等问题

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

TARGET_DIR="${1:-.}"

echo -e "${CYAN}♿ Accessibility / 无障碍检查${NC}"
echo "=========================================="
echo ""

cd "$TARGET_DIR"

CHANGED_FILES=$(git diff --name-only HEAD~1..HEAD 2>/dev/null | grep -E '\.(jsx|tsx|vue|html|css|scss)$' || true)

if [[ -z "$CHANGED_FILES" ]]; then
    echo -e "${YELLOW}无前端文件变更${NC}"
    exit 0
fi

issues=()

echo -e "${CYAN}【扫描无障碍问题】${NC}"
echo ""

while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    [[ -f "$file" ]] || continue

    content=$(cat "$file" 2>/dev/null || true)
    [[ -z "$content" ]] && continue

    # HTML/Vue/JSX 文件
    if [[ "$file" =~ \.(jsx|tsx|vue|html)$ ]]; then
        # 1. img 缺少 alt
        imgs=$(printf '%s\n' "$content" | grep -nE '<img[^>]*>' || true)
        if [[ -n "$imgs" ]]; then
            while IFS= read -r line; do
                if ! printf '%s\n' "$line" | grep -qE 'alt\s*=|alt:'; then
                    issues+=("$file: img 缺少 alt 属性")
                fi
            done <<< "$imgs"
        fi

        # 2. 按钮/链接缺少可访问文本
        btns=$(printf '%s\n' "$content" | grep -nE '<button[^>]*>\s*</button>|<a[^>]*>\s*</a>' || true)
        if [[ -n "$btns" ]]; then
            issues+=("$file: 按钮/链接缺少文本内容或 aria-label")
        fi

        # 3. 表单字段缺少 label
        inputs=$(printf '%s\n' "$content" | grep -nE '<input[^>]*>' || true)
        if [[ -n "$inputs" ]]; then
            while IFS= read -r line; do
                if ! printf '%s\n' "$line" | grep -qE 'id\s*=|aria-label|aria-labelledby|placeholder'; then
                    issues+=("$file: input 缺少关联 label")
                fi
            done <<< "$inputs"
        fi

        # 4. 颜色对比度提示（CSS/SCSS）
        if [[ "$file" =~ \.(css|scss)$ ]]; then
            colors=$(printf '%s\n' "$content" | grep -nE 'color\s*:|background-color\s*:' || true)
            if [[ -n "$colors" ]]; then
                # 简化：检测是否同时定义了前景色和背景色
                has_color=$(printf '%s\n' "$content" | grep -cE 'color\s*:' || true)
                has_bg=$(printf '%s\n' "$content" | grep -cE 'background-color\s*:|background\s*:' || true)
                if [[ "$has_color" -gt 0 && "$has_bg" -eq 0 ]]; then
                    issues+=("$file: 定义了文字颜色但没有背景色，可能导致对比度不足")
                fi
            fi
        fi

        # 5. 键盘导航
        clickable=$(printf '%s\n' "$content" | grep -nE 'onClick\s*=|@click' || true)
        if [[ -n "$clickable" ]]; then
            # 检查是否有 tabIndex 或键盘事件
            no_keyboard=$(printf '%s\n' "$content" | grep -nE 'onClick' | grep -vE 'tabIndex|onKeyDown|onKeyPress|role\s*=.*button' || true)
            if [[ -n "$no_keyboard" ]]; then
                issues+=("$file: 可点击元素缺少键盘支持 (tabIndex/onKeyDown)")
            fi
        fi

        # 6. 动态内容缺少 aria-live
        dynamic=$(printf '%s\n' "$content" | grep -nE 'setState|v-if|v-show|ngIf|\{.*\}' || true)
        if [[ -n "$dynamic" ]]; then
            if ! printf '%s\n' "$content" | grep -qE 'aria-live|aria-atomic|role\s*=.*alert|role\s*=.*status'; then
                issues+=("$file: 动态内容可能缺少 aria-live 通知")
            fi
        fi
    fi

done <<< "$CHANGED_FILES"

echo -e "${CYAN}【检查结果】${NC}"
echo ""

if [[ ${#issues[@]} -gt 0 ]]; then
    echo -e "${YELLOW}🟡 无障碍问题:${NC}"
    for issue in "${issues[@]}"; do
        echo "  - $issue"
    done
    echo ""
else
    echo -e "  ${GREEN}✅ 未检测到明显无障碍问题${NC}"
fi

echo -e "${CYAN}【无障碍最佳实践】${NC}"
echo "  1. 所有 img 必须有有意义的 alt 文本"
echo "  2. 按钮/链接必须有可访问文本 (aria-label)"
echo "  3. 表单字段必须有 label 关联"
echo "  4. 颜色对比度 >= 4.5:1 (WCAG AA)"
echo "  5. 所有交互必须支持键盘导航"
echo "  6. 动态内容使用 aria-live 通知"
echo "  7. 使用语义化 HTML (button 而非 div onclick)"
