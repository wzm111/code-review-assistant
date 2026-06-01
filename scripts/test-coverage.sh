#!/bin/bash
# 测试覆盖率分析
# 检测新增代码的测试覆盖情况

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

TARGET_DIR="${1:-.}"
THRESHOLD="${2:-80}"

echo -e "${CYAN}🧪 Test Coverage / 测试覆盖率分析${NC}"
echo "=========================================="
echo ""

cd "$TARGET_DIR"

# 获取变更文件（新增/修改的源码文件）
CHANGED_FILES=$(git diff --name-only HEAD~1..HEAD 2>/dev/null || git diff --name-only 2>/dev/null || true)

if [[ -z "$CHANGED_FILES" ]]; then
    echo -e "${YELLOW}无变更文件${NC}"
    exit 0
fi

# 根据语言检测对应的覆盖率工具
echo -e "${CYAN}【覆盖率工具检测】${NC}"

COVERAGE_TOOL=""
COVERAGE_FILE=""

# JavaScript / TypeScript
if [[ -f "coverage/lcov.info" ]]; then
    COVERAGE_FILE="coverage/lcov.info"
    COVERAGE_TOOL="lcov"
    echo -e "  发现: ${GREEN}LCOV (JS/TS)${NC}"
# Python
elif [[ -f ".coverage" ]] || [[ -f "coverage.xml" ]]; then
    COVERAGE_FILE="coverage.xml"
    COVERAGE_TOOL="coverage.py"
    echo -e "  发现: ${GREEN}coverage.py${NC}"
# Go
elif [[ -f "coverage.out" ]]; then
    COVERAGE_FILE="coverage.out"
    COVERAGE_TOOL="go"
    echo -e "  发现: ${GREEN}go test -cover${NC}"
# Java
elif find . -name "jacoco*.xml" -maxdepth 3 2>/dev/null | head -1 | grep -q .; then
    COVERAGE_FILE=$(find . -name "jacoco*.xml" -maxdepth 3 | head -1)
    COVERAGE_TOOL="jacoco"
    echo -e "  发现: ${GREEN}JaCoCo (Java)${NC}"
else
    echo -e "  ${YELLOW}⚠️ 未找到覆盖率报告文件${NC}"
    echo "  请先生成覆盖率报告:"
    echo "    JS/TS: npx jest --coverage"
    echo "    Python: pytest --cov=. --cov-report=xml"
    echo "    Go: go test -coverprofile=coverage.out ./..."
    echo "    Java: mvn jacoco:report"
    exit 0
fi

echo ""
echo -e "${CYAN}【新增代码覆盖分析】${NC}"

uncovered_files=()
low_coverage_files=()

# 检查每个变更文件是否在覆盖率报告中
while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    [[ -f "$file" ]] || continue

    # 跳过测试文件、配置文件
    if [[ "$file" =~ ".test." ]] || [[ "$file" =~ "_test." ]] || [[ "$file" =~ "spec." ]] || \
       [[ "$file" =~ "__tests__" ]] || [[ "$file" =~ "config" ]] || [[ "$file" =~ "\.json" ]] || \
       [[ "$file" =~ "\.md" ]] || [[ "$file" =~ "\.yaml" ]] || [[ "$file" =~ "\.yml" ]]; then
        continue
    fi

    # 检查是否在覆盖率报告中
    in_report=false
    case "$COVERAGE_TOOL" in
        lcov)
            if grep -q "SF:.*$file" "$COVERAGE_FILE" 2>/dev/null; then
                in_report=true
                # 提取覆盖率百分比
                # 简化：检查是否有未覆盖的行
                block=$(sed -n "/SF:.*$file/,/end_of_record/p" "$COVERAGE_FILE" 2>/dev/null || true)
                if printf '%s\n' "$block" | grep -q "LH:0"; then
                    uncovered_files+=("$file")
                fi
            fi
            ;;
        coverage.py|go|jacoco)
            if grep -q "$file" "$COVERAGE_FILE" 2>/dev/null; then
                in_report=true
            fi
            ;;
    esac

    if [[ "$in_report" == false ]]; then
        uncovered_files+=("$file")
    fi
done <<< "$CHANGED_FILES"

# 输出结果
if [[ ${#uncovered_files[@]} -gt 0 ]]; then
    echo -e "  ${RED}🔴 以下文件缺少测试覆盖:${NC}"
    for f in "${uncovered_files[@]}"; do
        echo "    - $f"
    done
else
    echo -e "  ${GREEN}✅ 新增代码均有测试覆盖${NC}"
fi

echo ""
echo -e "${CYAN}【建议】${NC}"
if [[ ${#uncovered_files[@]} -gt 0 ]]; then
    echo "  1. 为上述文件补充单元测试"
    echo "  2. 关键路径建议达到 ${THRESHOLD}% 以上覆盖率"
    echo "  3. 边界条件和异常分支不要遗漏"
    exit 1
else
    echo "  所有新增代码已覆盖，继续保持！"
    exit 0
fi
