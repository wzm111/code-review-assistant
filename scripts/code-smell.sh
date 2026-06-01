#!/bin/bash
# 代码异味检测
# 上帝类、长参数、过度耦合、过深嵌套

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

TARGET_DIR="${1:-.}"

echo -e "${CYAN}👃 Code Smell / 代码异味检测${NC}"
echo "=========================================="
echo ""

cd "$TARGET_DIR"

CHANGED_FILES=$(git diff --name-only HEAD~1..HEAD 2>/dev/null | grep -E '\.(js|ts|jsx|tsx|vue|py|go|java|php|rb|swift|kt|dart|rs|c|cpp)$' || true)

if [[ -z "$CHANGED_FILES" ]]; then
    echo -e "${YELLOW}无源码文件变更${NC}"
    exit 0
fi

smells=()

echo -e "${CYAN}【扫描代码异味】${NC}"
echo ""

while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    [[ -f "$file" ]] || continue

    content=$(cat "$file" 2>/dev/null || true)
    [[ -z "$content" ]] && continue

    lines=$(wc -l < "$file" | tr -d ' ')

    # 1. 上帝类 / 文件过大
    if [[ "$lines" -gt 500 ]]; then
        smells+=("$file: 文件 $lines 行 (超过500行，考虑拆分)")
    fi

    # 2. 函数过长
    # 简化检测：统计函数定义之间的行数
    func_starts=$(printf '%s\n' "$content" | grep -nE '(function|def|func|public|private)\s+\w+.*\{' | cut -d: -f1 || true)
    if [[ -n "$func_starts" ]]; then
        prev=0
        for start in $func_starts; do
            if [[ "$prev" -gt 0 ]]; then
                func_len=$((start - prev))
                if [[ "$func_len" -gt 80 ]]; then
                    smells+=("$file: 发现 $func_len 行的超长函数 (建议 < 50 行)")
                fi
            fi
            prev=$start
        done
    fi

    # 3. 参数过多
    long_params=$(printf '%s\n' "$content" | grep -nE '\([^)]{80,}\)' || true)
    if [[ -n "$long_params" ]]; then
        smells+=("$file: 发现参数过多的函数，建议使用对象/结构体传参")
    fi

    # 4. 嵌套过深
    max_indent=0
    while IFS= read -r line; do
        indent=$(printf '%s\n' "$line" | sed 's/\t/    /g' | sed 's/^\(\s*\).*/\1/' | wc -c | tr -d ' ')
        if [[ "$indent" -gt "$max_indent" ]]; then
            max_indent=$indent
        fi
    done <<< "$content"

    if [[ "$max_indent" -gt 16 ]]; then  # 4层缩进
        smells+=("$file: 最大缩进 $max_indent 空格 (约 $((max_indent/4)) 层嵌套，建议 < 3 层)")
    fi

    # 5. 过多 if/else
    if_count=$(printf '%s\n' "$content" | grep -cE '\bif\b' || true)
    if [[ "$if_count" -gt 10 ]]; then
        smells+=("$file: $if_count 个 if 语句，考虑用策略模式/多态替代")
    fi

    # 6. 过多 TODO/FIXME
    todos=$(printf '%s\n' "$content" | grep -cE 'TODO|FIXME|HACK|XXX|BUG' || true)
    if [[ "$todos" -gt 3 ]]; then
        smells+=("$file: $todos 个 TODO/FIXME，技术债堆积")
    fi

    # 7. 过度导入
    import_count=$(printf '%s\n' "$content" | grep -cE '^\s*(import|require|from|using|include)' || true)
    if [[ "$import_count" -gt 20 ]]; then
        smells+=("$file: $import_count 个导入，可能职责不单一")
    fi

done <<< "$CHANGED_FILES"

echo -e "${CYAN}【检测结果】${NC}"
echo ""

if [[ ${#smells[@]} -gt 0 ]]; then
    echo -e "${YELLOW}🟡 代码异味:${NC}"
    for smell in "${smells[@]}"; do
        echo "  - $smell"
    done
    echo ""
else
    echo -e "  ${GREEN}✅ 未检测到明显代码异味${NC}"
fi

echo -e "${CYAN}【重构建议】${NC}"
echo "  1. 文件 > 500 行: 按功能拆分模块"
echo "  2. 函数 > 50 行: 提取子函数"
echo "  3. 参数 > 4 个: 使用参数对象"
echo "  4. 嵌套 > 3 层: 提前返回/提取函数"
echo "  5. if 过多: 用策略模式/状态机/多态"
echo "  6. TODO 过多: 创建技术债工单跟踪"
echo "  7. 导入过多: 检查是否违反单一职责"

if [[ ${#smells[@]} -gt 3 ]]; then
    exit 1
fi
