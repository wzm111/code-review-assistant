#!/bin/bash
# 测试质量检查
# 检测脆弱测试、缺少边界测试、sleep/timeout 滥用

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

TARGET_DIR="${1:-.}"

echo -e "${CYAN}🧪 Test Quality / 测试质量检查${NC}"
echo "=========================================="
echo ""

cd "$TARGET_DIR"

TEST_FILES=$(git diff --name-only HEAD~1..HEAD 2>/dev/null | grep -E '\.(test|spec)\.(js|ts|jsx|tsx|py|go|java|php|rb)$|_test\.go$|tests?/.*\.(js|ts|py)$' || true)

if [[ -z "$TEST_FILES" ]]; then
    echo -e "${YELLOW}无测试文件变更${NC}"
    exit 0
fi

critical_issues=()
warnings=()

echo -e "${CYAN}【变更的测试文件】${NC}"
printf '%s\n' "$TEST_FILES" | sed 's/^/  /'
echo ""

while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    [[ -f "$file" ]] || continue

    content=$(cat "$file" 2>/dev/null || true)
    [[ -z "$content" ]] && continue

    # 1. 脆弱测试：setTimeout / sleep / wait
    flaky_timeouts=$(printf '%s\n' "$content" | grep -nE 'setTimeout|sleep\(|setInterval|wait\(|\.sleep\(' || true)
    if [[ -n "$flaky_timeouts" ]]; then
        critical_issues+=("$file: 使用 setTimeout/sleep，测试可能不稳定")
    fi

    # 2. 缺少边界测试
    if ! printf '%s\n' "$content" | grep -qE 'null|undefined|NaN|Infinity|\"\"|\[\]|\{\}|0'; then
        warnings+=("$file: 未检测到边界值测试 (null/空/0)")
    fi

    # 3. 测试没有断言
    assertions=$(printf '%s\n' "$content" | grep -cE 'expect\(|assert\.|should\.|t\.(Equal|True|False|Error)|assertEquals|assertTrue|assertFalse' || true)
    test_cases=$(printf '%s\n' "$content" | grep -cE 'it\(|test\(|describe\(|func\s+Test' || true)
    if [[ "$assertions" -lt "$test_cases" ]]; then
        warnings+=("$file: $test_cases 个测试用例但仅 $assertions 个断言")
    fi

    # 4. 硬编码测试数据
    hardcoded=$(printf '%s\n' "$content" | grep -nE '"test"|"example"|12345|"foo"|"bar"|"hello"|"world"' || true)
    if [[ -n "$hardcoded" ]]; then
        warnings+=("$file: 使用硬编码测试数据，建议用工厂函数/faker生成")
    fi

    # 5. 没有清理/ teardown
    if ! printf '%s\n' "$content" | grep -qE 'afterEach|afterAll|tearDown|cleanup|defer\s+' ; then
        if printf '%s\n' "$content" | grep -qE 'create|new\s|connect|open'; then
            warnings+=("$file: 创建资源但没有清理逻辑 (afterEach/tearDown)")
        fi
    fi

    # 6. 测试之间相互依赖
    if printf '%s\n' "$content" | grep -qE '\.only\(|\.skip\(|pending|xit\(|xtest\('; then
        warnings+=("$file: 使用了 .only/.skip，可能存在测试依赖或跳过问题")
    fi

    # 7. 没有测试覆盖率标记
    if ! printf '%s\n' "$content" | grep -qE 'describe|it\(|test\(' ; then
        warnings+=("$file: 结构异常，缺少 describe/it/test 分组")
    fi

done <<< "$TEST_FILES"

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

if [[ ${#critical_issues[@]} -eq 0 && ${#warnings[@]} -eq 0 ]]; then
    echo -e "  ${GREEN}✅ 测试质量检查通过${NC}"
fi

echo -e "${CYAN}【测试质量最佳实践】${NC}"
echo "  1. 禁止使用 setTimeout/sleep，使用 mock timer"
echo "  2. 每个测试独立，不依赖执行顺序"
echo "  3. 边界值: null, undefined, '', [], 0, NaN, Infinity"
echo "  4. 使用工厂函数或 faker 生成测试数据"
echo "  5. 测试后清理: afterEach / tearDown / cleanup"
echo "  6. 断言数量 >= 测试用例数量"
echo "  7. 覆盖率目标: 行覆盖 80%，分支覆盖 70%"

if [[ ${#critical_issues[@]} -gt 0 ]]; then
    exit 1
fi
