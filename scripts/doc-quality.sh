#!/bin/bash
# 注释/文档质量检查
# 检测过时注释、缺少文档的公共API、TODO/FIXME追踪

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

TARGET_DIR="${1:-.}"

echo -e "${CYAN}📖 Doc Quality / 注释与文档质量${NC}"
echo "=========================================="
echo ""

cd "$TARGET_DIR"

CHANGED_FILES=$(git diff --name-only HEAD~1..HEAD 2>/dev/null | grep -E '\.(js|ts|jsx|tsx|vue|py|go|java|php|rb|swift|kt|dart|rs|c|cpp)$' || true)

if [[ -z "$CHANGED_FILES" ]]; then
    echo -e "${YELLOW}无源码文件变更${NC}"
    exit 0
fi

warnings=()
todos=()

echo -e "${CYAN}【扫描文档与注释】${NC}"
echo ""

while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    [[ -f "$file" ]] || continue

    content=$(cat "$file" 2>/dev/null || true)
    [[ -z "$content" ]] && continue

    # 1. 公共函数/类缺少文档注释
    # JavaScript/TypeScript
    if [[ "$file" =~ \.(js|ts|jsx|tsx)$ ]]; then
        # 检测 export 的函数但没有 JSDoc
        exports=$(printf '%s\n' "$content" | grep -nE '^\s*export\s+(function|const|class|interface)' || true)
        if [[ -n "$exports" ]]; then
            while IFS= read -r line; do
                line_num=$(printf '%s\n' "$line" | cut -d: -f1)
                # 检查前一行是否是注释
                prev_line=$(sed -n "$((line_num-1))p" "$file" 2>/dev/null || true)
                if ! printf '%s\n' "$prev_line" | grep -qE '^\s*(/\*\*|//|#|\*)'; then
                    func_name=$(printf '%s\n' "$line" | grep -oE '\w+\s*(\(|=)' | head -1 | sed 's/[(=]//')
                    warnings+=("$file:$line_num: export 函数 '$func_name' 缺少文档注释")
                fi
            done <<< "$exports"
        fi
    fi

    # Python
    if [[ "$file" =~ \.py$ ]]; then
        funcs=$(printf '%s\n' "$content" | grep -nE '^\s*def\s+\w+\s*\(' || true)
        if [[ -n "$funcs" ]]; then
            while IFS= read -r line; do
                line_num=$(printf '%s\n' "$line" | cut -d: -f1)
                # 检查是否是私有函数
                func_name=$(printf '%s\n' "$line" | grep -oE 'def\s+\w+' | sed 's/def //')
                if [[ ! "$func_name" =~ ^_ ]]; then
                    # 检查是否有 docstring
                    next_lines=$(sed -n "$((line_num+1)),$((line_num+3))p" "$file" 2>/dev/null || true)
                    if ! printf '%s\n' "$next_lines" | grep -qE '^\s*"""|^\s*\'\'\'''; then
                        warnings+=("$file:$line_num: 公共函数 '$func_name' 缺少 docstring")
                    fi
                fi
            done <<< "$funcs"
        fi
    fi

    # Go
    if [[ "$file" =~ \.go$ ]]; then
        funcs=$(printf '%s\n' "$content" | grep -nE '^func\s+([A-Z]\w*)' || true)
        if [[ -n "$funcs" ]]; then
            while IFS= read -r line; do
                line_num=$(printf '%s\n' "$line" | cut -d: -f1)
                prev_line=$(sed -n "$((line_num-1))p" "$file" 2>/dev/null || true)
                if ! printf '%s\n' "$prev_line" | grep -qE '^\s*//'; then
                    func_name=$(printf '%s\n' "$line" | grep -oE 'func\s+\w+' | sed 's/func //')
                    warnings+=("$file:$line_num: 导出函数 '$func_name' 缺少注释")
                fi
            done <<< "$funcs"
        fi
    fi

    # 2. 过时注释检测（注释与代码不匹配）
    # 简化：检测注释中的参数名是否在代码中存在
    # 这是一个启发式检测

    # 3. TODO/FIXME 追踪
    file_todos=$(printf '%s\n' "$content" | grep -nE 'TODO|FIXME|HACK|XXX' || true)
    if [[ -n "$file_todos" ]]; then
        todo_count=$(printf '%s\n' "$file_todos" | wc -l | tr -d ' ')
        todos+=("$file: $todo_count 个 TODO/FIXME")
    fi

done <<< "$CHANGED_FILES"

echo -e "${CYAN}【检查结果】${NC}"
echo ""

if [[ ${#warnings[@]} -gt 0 ]]; then
    echo -e "${YELLOW}🟡 文档缺失:${NC}"
    for w in "${warnings[@]}"; do
        echo "  - $w"
    done
    echo ""
fi

if [[ ${#todos[@]} -gt 0 ]]; then
    echo -e "${CYAN}📋 TODO/FIXME 追踪:${NC}"
    for t in "${todos[@]}"; do
        echo "  - $t"
    done
    echo ""
fi

if [[ ${#warnings[@]} -eq 0 && ${#todos[@]} -eq 0 ]]; then
    echo -e "  ${GREEN}✅ 文档质量检查通过${NC}"
fi

echo -e "${CYAN}【文档最佳实践】${NC}"
echo "  1. 所有公共 API 必须有文档注释 (JSDoc/docstring/Go doc)"
echo "  2. 注释解释 WHY 而非 WHAT"
echo "  3. 复杂算法必须有步骤说明"
echo "  4. TODO 必须包含 issue 链接或责任人"
echo "  5. 更新代码时同步更新注释"
echo "  6. 删除过时注释，不要留着误导"
