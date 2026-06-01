#!/bin/bash
# 资源泄露扫描
# 检测文件句柄、数据库连接、网络连接未关闭

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

TARGET_DIR="${1:-.}"

echo -e "${CYAN}💧 Resource Leak / 资源泄露扫描${NC}"
echo "=========================================="
echo ""

cd "$TARGET_DIR"

CHANGED_FILES=$(git diff --name-only HEAD~1..HEAD 2>/dev/null | grep -E '\.(js|ts|jsx|tsx|vue|py|go|java|php|rb|swift|kt|dart|rs|c|cpp)$' || true)

if [[ -z "$CHANGED_FILES" ]]; then
    echo -e "${YELLOW}无源码文件变更${NC}"
    exit 0
fi

leaks=()

echo -e "${CYAN}【扫描资源分配与释放】${NC}"
echo ""

while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    [[ -f "$file" ]] || continue

    content=$(cat "$file" 2>/dev/null || true)
    [[ -z "$content" ]] && continue

    # ===== JavaScript / TypeScript =====
    if [[ "$file" =~ \.(js|ts|jsx|tsx|vue)$ ]]; then
        # 1. setInterval 没有 clearInterval
        intervals=$(printf '%s\n' "$content" | grep -nE 'setInterval\s*\(' || true)
        if [[ -n "$intervals" ]]; then
            clears=$(printf '%s\n' "$content" | grep -cE 'clearInterval' || true)
            sets=$(printf '%s\n' "$content" | grep -cE 'setInterval' || true)
            if [[ "$clears" -lt "$sets" ]]; then
                leaks+=("$file: setInterval ($sets) 多于 clearInterval ($clears)")
            fi
        fi

        # 2. addEventListener 没有 removeEventListener
        listeners=$(printf '%s\n' "$content" | grep -nE 'addEventListener\s*\(' || true)
        if [[ -n "$listeners" ]]; then
            removes=$(printf '%s\n' "$content" | grep -cE 'removeEventListener' || true)
            adds=$(printf '%s\n' "$content" | grep -cE 'addEventListener' || true)
            if [[ "$removes" -lt "$adds" ]]; then
                leaks+=("$file: addEventListener ($adds) 多于 removeEventListener ($removes)")
            fi
        fi

        # 3. 数据库连接未关闭
        db_opens=$(printf '%s\n' "$content" | grep -nE '\.connect\s*\(|createConnection|mongoose\.connect|pg\.Pool|new\s+Pool' || true)
        if [[ -n "$db_opens" ]]; then
            db_closes=$(printf '%s\n' "$content" | grep -cE '\.close\s*\(|\.end\s*\(|\.destroy\s*\(' || true)
            if [[ "$db_closes" -eq 0 ]]; then
                leaks+=("$file: 数据库连接没有关闭逻辑")
            fi
        fi
    fi

    # ===== Python =====
    if [[ "$file" =~ \.py$ ]]; then
        # 1. 文件未用 with
        file_opens=$(printf '%s\n' "$content" | grep -nE '^[^#]*\bopen\s*\(' || true)
        if [[ -n "$file_opens" ]]; then
            with_stmts=$(printf '%s\n' "$content" | grep -cE '^\s*with\s+.*open' || true)
            opens=$(printf '%s\n' "$content" | grep -cE '\bopen\s*\(' || true)
            if [[ "$with_stmts" -lt "$opens" ]]; then
                leaks+=("$file: $opens 处 open() 但仅 $with_stmts 处使用 with")
            fi
        fi

        # 2. 数据库连接未关闭
        db_cursors=$(printf '%s\n' "$content" | grep -nE '\.cursor\s*\(|\.connect\s*\(' || true)
        if [[ -n "$db_cursors" ]]; then
            closes=$(printf '%s\n' "$content" | grep -cE '\.close\s*\(' || true)
            if [[ "$closes" -eq 0 ]]; then
                leaks+=("$file: 数据库游标/连接可能未关闭")
            fi
        fi
    fi

    # ===== Go =====
    if [[ "$file" =~ \.go$ ]]; then
        # 1. 文件打开没有 defer Close
        file_opens=$(printf '%s\n' "$content" | grep -nE 'os\.Open|os\.Create|os\.OpenFile' || true)
        if [[ -n "$file_opens" ]]; then
            defers=$(printf '%s\n' "$content" | grep -cE 'defer\s+\w+\.Close\s*\(' || true)
            opens=$(printf '%s\n' "$content" | grep -cE 'os\.Open|os\.Create|os\.OpenFile' || true)
            if [[ "$defers" -lt "$opens" ]]; then
                leaks+=("$file: $opens 处文件打开但仅 $defers 处 defer Close")
            fi
        fi
    fi

    # ===== Java =====
    if [[ "$file" =~ \.java$ ]]; then
        # 1. InputStream/Connection 没有 close
        streams=$(printf '%s\n' "$content" | grep -nE 'new\s+(FileInputStream|BufferedReader|Connection|Statement|ResultSet)' || true)
        if [[ -n "$streams" ]]; then
            closes=$(printf '%s\n' "$content" | grep -cE '\.close\s*\(' || true)
            if [[ "$closes" -eq 0 ]]; then
                leaks+=("$file: 资源对象没有 close() 调用")
            fi
        fi
    fi

done <<< "$CHANGED_FILES"

echo -e "${CYAN}【扫描结果】${NC}"
echo ""

if [[ ${#leaks[@]} -gt 0 ]]; then
    echo -e "${RED}🔴 检测到资源泄露风险:${NC}"
    for leak in "${leaks[@]}"; do
        echo "  - $leak"
    done
    echo ""
    echo -e "${YELLOW}资源泄露会导致内存耗尽、连接池耗尽、文件句柄耗尽${NC}"
else
    echo -e "  ${GREEN}✅ 未检测到明显的资源泄露风险${NC}"
fi

echo ""
echo -e "${CYAN}【资源管理最佳实践】${NC}"
echo "  1. 使用 try-with-resources / defer / with 自动释放"
echo "  2. 成对出现: open→close, connect→disconnect, add→remove"
echo "  3. 使用连接池而非每次新建连接"
echo "  4. 清理定时器、事件监听器、订阅"
echo "  5. 使用 RAII 模式 (C++/Rust)"

if [[ ${#leaks[@]} -gt 0 ]]; then
    exit 1
fi
