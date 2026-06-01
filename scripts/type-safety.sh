#!/bin/bash
# 类型安全深度检查
# 检测 TypeScript/Flow 中的 any 滥用、类型收窄缺失等

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

TARGET_DIR="${1:-.}"
ANY_THRESHOLD="${2:-5}"

echo -e "${CYAN}🔍 Type Safety / 类型安全深度检查${NC}"
echo "=========================================="
echo ""

cd "$TARGET_DIR"

CHANGED_FILES=$(git diff --name-only HEAD~1..HEAD 2>/dev/null | grep -E '\.(ts|tsx|vue)$' || true)

if [[ -z "$CHANGED_FILES" ]]; then
    echo -e "${YELLOW}无 TypeScript 文件变更${NC}"
    exit 0
fi

critical_issues=()
warnings=()
any_count=0

echo -e "${CYAN}【扫描 TypeScript 文件】${NC}"
echo ""

while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    [[ -f "$file" ]] || continue

    content=$(cat "$file" 2>/dev/null || true)
    [[ -z "$content" ]] && continue

    # 1. any 使用统计
    file_any=$(printf '%s\n' "$content" | grep -cE ':\s*any\b|\bas\s+any\b' || true)
    if [[ "$file_any" -gt 0 ]]; then
        any_count=$((any_count + file_any))
        if [[ "$file_any" -gt 3 ]]; then
            warnings+=("$file: 使用 $file_any 处 any，建议替换为具体类型")
        fi
    fi

    # 2. 非空断言 (!)
    non_null=$(printf '%s\n' "$content" | grep -nE '!\.' || true)
    if [[ -n "$non_null" ]]; then
        bang_count=$(printf '%s\n' "$non_null" | wc -l | tr -d ' ')
        if [[ "$bang_count" -gt 5 ]]; then
            warnings+=("$file: $bang_count 处非空断言 (!)，建议添加空值检查")
        fi
    fi

    # 3. as 类型断言滥用
    type_assertions=$(printf '%s\n' "$content" | grep -nE '\bas\s+\w+' || true)
    if [[ -n "$type_assertions" ]]; then
        assertions=$(printf '%s\n' "$type_assertions" | wc -l | tr -d ' ')
        if [[ "$assertions" -gt 3 ]]; then
            warnings+=("$file: $assertions 处 as 类型断言，建议用类型守卫替代")
        fi
    fi

    # 4. @ts-ignore / @ts-expect-error
    ts_ignore=$(printf '%s\n' "$content" | grep -nE '@ts-ignore|@ts-expect-error' || true)
    if [[ -n "$ts_ignore" ]]; then
        ignore_count=$(printf '%s\n' "$ts_ignore" | wc -l | tr -d ' ')
        warnings+=("$file: $ignore_count 处 @ts-ignore/@ts-expect-error")
    fi

    # 5. 缺少返回类型
    funcs_no_return=$(printf '%s\n' "$content" | grep -nE '(function|const|let|var)\s+\w+\s*=\s*\([^)]*\)\s*=>' || true)
    if [[ -n "$funcs_no_return" ]]; then
        # 简化：检测箭头函数但没有返回类型注解
        no_type=$(printf '%s\n' "$content" | grep -nE '\)\s*=>\s*\{' | grep -v ':' || true)
        if [[ -n "$no_type" ]]; then
            warnings+=("$file: 函数缺少返回类型注解")
        fi
    fi

    # 6. 隐式 any (参数没有类型)
    if printf '%s\n' "$content" | grep -qE 'noImplicitAny.*false'; then
        critical_issues+=("$file: tsconfig 关闭了 noImplicitAny")
    fi

done <<< "$CHANGED_FILES"

echo -e "${CYAN}【检查结果】${NC}"
echo ""

if [[ ${#critical_issues[@]} -gt 0 ]]; then
    echo -e "${RED}🔴 严重问题:${NC}"
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

if [[ "$any_count" -gt "$ANY_THRESHOLD" ]]; then
    echo -e "${YELLOW}📊 本次变更共使用 $any_count 处 any (阈值: $ANY_THRESHOLD)${NC}"
    echo ""
fi

if [[ ${#critical_issues[@]} -eq 0 && ${#warnings[@]} -eq 0 ]]; then
    echo -e "  ${GREEN}✅ 类型安全检查通过${NC}"
fi

echo -e "${CYAN}【类型安全最佳实践】${NC}"
echo "  1. 禁用 any，使用 unknown + 类型守卫"
echo "  2. 函数参数和返回值都标注类型"
echo "  3. 使用严格模式: strict, noImplicitAny, strictNullChecks"
echo "  4. 用类型守卫 (is, in, typeof) 替代 as 断言"
echo "  5. 用可选链 (?.) 和非空合并 (??) 替代 !"
echo "  6. 为第三方库添加 @types/ 或自定义声明"
