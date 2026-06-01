#!/bin/bash
# 错误处理完整性检查
# 检测未捕获异常、空 catch、错误日志缺失等问题

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

TARGET_DIR="${1:-.}"

echo -e "${CYAN}🛡️ Error Handling / 错误处理完整性检查${NC}"
echo "=========================================="
echo ""

cd "$TARGET_DIR"

CHANGED_FILES=$(git diff --name-only HEAD~1..HEAD 2>/dev/null | grep -E '\.(js|ts|jsx|tsx|vue|py|go|java|php|rb|swift|kt|dart|rs|c|cpp)$' || true)

if [[ -z "$CHANGED_FILES" ]]; then
    echo -e "${YELLOW}无源码文件变更${NC}"
    exit 0
fi

critical_issues=()
warnings=()

echo -e "${CYAN}【扫描变更文件】${NC}"
echo ""

while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    [[ -f "$file" ]] || continue

    content=$(cat "$file" 2>/dev/null || true)
    [[ -z "$content" ]] && continue

    # ===== JavaScript / TypeScript =====
    if [[ "$file" =~ \.(js|ts|jsx|tsx|vue)$ ]]; then
        # 1. 空 catch
        empty_catch=$(printf '%s\n' "$content" | grep -nE 'catch\s*\([^)]*\)\s*\{\s*\}' || true)
        if [[ -n "$empty_catch" ]]; then
            critical_issues+=("$file: 空 catch 块 (吞掉了所有错误)")
        fi

        # 2. catch 中只有 console.log
        catch_console=$(printf '%s\n' "$content" | grep -nE 'catch.*\{' -A 2 | grep -E 'console\.(log|warn|error)\(' | grep -v 'throw' || true)
        if [[ -n "$catch_console" ]]; then
            warnings+=("$file: catch 中仅 console.log，未处理或抛出错误")
        fi

        # 3. async 函数没有 try/catch
        async_funcs=$(printf '%s\n' "$content" | grep -nE 'async\s+function|async\s*\(' || true)
        if [[ -n "$async_funcs" ]]; then
            async_count=$(printf '%s\n' "$async_funcs" | wc -l | tr -d ' ')
            try_count=$(printf '%s\n' "$content" | grep -cE 'try\s*\{' || true)
            if [[ "$try_count" -lt "$async_count" ]]; then
                warnings+=("$file: $async_count 个 async 但仅 $try_count 个 try/catch")
            fi
        fi

        # 4. Promise 没有 .catch
        promises=$(printf '%s\n' "$content" | grep -nE 'new\s+Promise|\.then\(' || true)
        if [[ -n "$promises" ]]; then
            no_catch=$(printf '%s\n' "$content" | grep -cE '\.catch\(' || true)
            if [[ "$no_catch" -eq 0 ]]; then
                warnings+=("$file: 使用 Promise 但未处理 .catch")
            fi
        fi

        # 5. throw 字符串而非 Error 对象
        throw_string=$(printf '%s\n' "$content" | grep -nE "throw\s+['\"]" || true)
        if [[ -n "$throw_string" ]]; then
            warnings+=("$file: throw 字符串而非 Error 对象，丢失堆栈信息")
        fi
    fi

    # ===== Python =====
    if [[ "$file" =~ \.py$ ]]; then
        # 1. 空 except
        empty_except=$(printf '%s\n' "$content" | grep -nE 'except\s*:\s*$|except\s+Exception\s*:\s*$' || true)
        if [[ -n "$empty_except" ]]; then
            critical_issues+=("$file: 裸 except / 捕获所有 Exception")
        fi

        # 2. except pass
        except_pass=$(printf '%s\n' "$content" | grep -nE 'except.*:\s*$' -A 1 | grep 'pass' || true)
        if [[ -n "$except_pass" ]]; then
            critical_issues+=("$file: except 块中只有 pass (吞掉所有错误)")
        fi

        # 3. 未处理的文件操作
        file_ops=$(printf '%s\n' "$content" | grep -nE 'open\s*\(' || true)
        if [[ -n "$file_ops" ]]; then
            with_count=$(printf '%s\n' "$content" | grep -cE 'with\s+open' || true)
            total_open=$(printf '%s\n' "$content" | grep -cE 'open\s*\(' || true)
            if [[ "$with_count" -lt "$total_open" ]]; then
                warnings+=("$file: $total_open 处文件打开，仅 $with_count 处使用 with (可能未关闭)")
            fi
        fi
    fi

    # ===== Go =====
    if [[ "$file" =~ \.go$ ]]; then
        # 1. 忽略 error 返回值
        ignored_error=$(printf '%s\n' "$content" | grep -nE '^\s*_,\s*\w+\s*:=\s*\w+' || true)
        if [[ -n "$ignored_error" ]]; then
            warnings+=("$file: 忽略函数返回值 (可能包含 error)")
        fi

        # 2. err 检查后没有处理
        err_checked=$(printf '%s\n' "$content" | grep -nE 'if\s+err\s*!=\s*nil' -A 2 | grep -E '^\s*\}\s*$' || true)
        if [[ -n "$err_checked" ]]; then
            warnings+=("$file: err != nil 检查后没有处理逻辑")
        fi
    fi

    # ===== Java / Kotlin =====
    if [[ "$file" =~ \.(java|kt)$ ]]; then
        # 1. 空 catch
        empty_catch=$(printf '%s\n' "$content" | grep -nE 'catch\s*\([^)]*\)\s*\{\s*\}' || true)
        if [[ -n "$empty_catch" ]]; then
            critical_issues+=("$file: 空 catch 块")
        fi

        # 2. catch 中仅打印
        catch_print=$(printf '%s\n' "$content" | grep -nE 'catch.*\{' -A 3 | grep -E 'printStackTrace|System\.out\.print|e\.print' | grep -v 'throw' || true)
        if [[ -n "$catch_print" ]]; then
            warnings+=("$file: catch 中仅打印错误，未重新抛出或处理")
        fi
    fi

done <<< "$CHANGED_FILES"

# 输出结果
echo -e "${CYAN}【检查结果】${NC}"
echo ""

if [[ ${#critical_issues[@]} -gt 0 ]]; then
    echo -e "${RED}🔴 严重问题 (可能隐藏生产故障):${NC}"
    for issue in "${critical_issues[@]}"; do
        echo "  - $issue"
    done
    echo ""
fi

if [[ ${#warnings[@]} -gt 0 ]]; then
    echo -e "${YELLOW}🟡 警告:${NC}"
    for w in "${warnings[@]}"; do
        echo "  - $w"
    done
    echo ""
fi

if [[ ${#critical_issues[@]} -eq 0 && ${#warnings[@]} -eq 0 ]]; then
    echo -e "  ${GREEN}✅ 错误处理检查通过${NC}"
fi

echo -e "${CYAN}【错误处理最佳实践】${NC}"
echo "  1. 绝不使用空 catch/except，至少记录日志"
echo "  2. catch 后应 throw/return 或记录结构化日志"
echo "  3. async/await 必须配合 try/catch"
echo "  4. 优先抛 Error 对象而非字符串 (保留堆栈)"
echo "  5. 区分业务错误和系统错误，使用不同策略"
echo "  6. Go: 每个 error 返回值都必须检查"

if [[ ${#critical_issues[@]} -gt 0 ]]; then
    exit 1
fi
