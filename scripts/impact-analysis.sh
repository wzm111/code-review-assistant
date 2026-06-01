#!/bin/bash
# 变更影响分析脚本
# 分析代码修改影响了哪些模块、接口、测试

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

TARGET_DIR="${1:-.}"
BASE_REF="${2:-HEAD~1}"

echo -e "${CYAN}📊 Change Impact Analysis / 变更影响分析${NC}"
echo "=========================================="
echo ""

cd "$TARGET_DIR"

# 获取变更文件
CHANGED_FILES=$(git diff --name-only "$BASE_REF"..HEAD 2>/dev/null || git diff --name-only 2>/dev/null || true)

if [[ -z "$CHANGED_FILES" ]]; then
    echo -e "${YELLOW}无变更${NC}"
    exit 0
fi

echo -e "${YELLOW}基准对比: ${BASE_REF}..HEAD${NC}"
echo ""

# 1. 模块影响分析
echo -e "${CYAN}【模块影响】${NC}"

# 按目录分组
printf '%s\n' "$CHANGED_FILES" | awk -F/ '{
    if (NF > 1) {
        module = $1
        if (NF > 2 && $1 ~ /^(src|app|lib|packages)$/) {
            module = $1 "/" $2
        }
        modules[module]++
    }
}'

# 使用更简单的方式
printf '%s\n' "$CHANGED_FILES" | while read -r file; do
    dir=$(dirname "$file" | cut -d/ -f1-2)
    echo "$dir"
done | sort | uniq -c | sort -rn | head -10 | sed 's/^/  /'

echo ""

# 2. 接口/API 影响
echo -e "${CYAN}【API / 接口影响】${NC}"

# 查找路由/API 定义文件的变化
API_FILES=$(printf '%s\n' "$CHANGED_FILES" | grep -E '(route|router|api|controller|handler|endpoint)' | head -10 || true)
if [[ -n "$API_FILES" ]]; then
    echo -e "${YELLOW}⚠️ 以下 API 相关文件被修改:${NC}"
    printf '%s\n' "$API_FILES" | sed 's/^/  /'
    echo ""
    echo "  建议检查:"
    echo "    - 接口兼容性（向后兼容）"
    echo "    - API 文档是否同步更新"
    echo "    - 调用方是否需要适配"
    echo ""
else
    echo -e "${GREEN}✅ 未修改 API 路由/控制器${NC}"
    echo ""
fi

# 3. 数据库影响
echo -e "${CYAN}【数据库影响】${NC}"

DB_FILES=$(printf '%s\n' "$CHANGED_FILES" | grep -E '(migration|schema|entity|model|\.sql|prisma|typeorm|sequelize)' | head -10 || true)
if [[ -n "$DB_FILES" ]]; then
    echo -e "${RED}🔴 数据库相关变更:${NC}"
    printf '%s\n' "$DB_FILES" | sed 's/^/  /'
    echo ""
    echo "  风险检查:"
    echo "    - 是否可回滚？"
    echo "    - 大数据表是否锁表？"
    echo "    - 是否有数据迁移脚本？"
    echo "    - 新旧代码是否兼容？"
    echo ""
else
    echo -e "${GREEN}✅ 未修改数据库相关文件${NC}"
    echo ""
fi

# 4. 配置文件影响
echo -e "${CYAN}【配置影响】${NC}"

CONFIG_FILES=$(printf '%s\n' "$CHANGED_FILES" | grep -E '(config|\.env|nginx|docker|k8s|yaml|yml|json$)' | head -10 || true)
if [[ -n "$CONFIG_FILES" ]]; then
    echo -e "${YELLOW}⚠️ 配置文件变更:${NC}"
    printf '%s\n' "$CONFIG_FILES" | sed 's/^/  /'
    echo ""
else
    echo -e "${GREEN}✅ 未修改配置文件${NC}"
    echo ""
fi

# 5. 测试影响分析
echo -e "${CYAN}【测试覆盖检查】${NC}"

TEST_FILES=$(printf '%s\n' "$CHANGED_FILES" | grep -E '(\.test\.|\.spec\.|tests?/|__tests__/)' || true)
SRC_FILES=$(printf '%s\n' "$CHANGED_FILES" | grep -v -E '(\.test\.|\.spec\.|tests?/|__tests__/|\.md$|docs/)' || true)

if [[ -n "$TEST_FILES" ]]; then
    echo -e "${GREEN}✅ 包含测试文件:${NC}"
    printf '%s\n' "$TEST_FILES" | sed 's/^/  /'
    echo ""
fi

if [[ -n "$SRC_FILES" ]]; then
    echo "源文件变更:"
    printf '%s\n' "$SRC_FILES" | sed 's/^/  /'

    # 检查对应测试是否存在
    echo ""
    echo "对应测试检查:"
    printf '%s\n' "$SRC_FILES" | while read -r src; do
        base=$(basename "$src" | sed 's/\.[^.]*$//')
        dir=$(dirname "$src")

        # 常见测试文件命名
        test_candidates=(
            "${dir}/${base}.test.js"
            "${dir}/${base}.test.ts"
            "${dir}/${base}.test.tsx"
            "${dir}/${base}.spec.js"
            "${dir}/${base}.spec.ts"
            "${dir}/__tests__/${base}.test.js"
            "${dir}/../tests/${base}.test.js"
            "tests/${base}.test.js"
        )

        found=false
        for test in "${test_candidates[@]}"; do
            if [[ -f "$test" ]]; then
                found=true
                break
            fi
        done

        if [[ "$found" == false ]]; then
            echo "  ⚠️ ${src} - 未找到对应测试"
        fi
    done
fi

echo ""

# 6. 风险评级
echo -e "${CYAN}【综合风险评级】${NC}"

RISK=0
RISK_REASONS=""

# 数据库变更 = 高风险
if [[ -n "$DB_FILES" ]]; then
    RISK=$((RISK + 3))
    RISK_REASONS="${RISK_REASONS}数据库变更 "
fi

# API 变更 = 中高风险
if [[ -n "$API_FILES" ]]; then
    RISK=$((RISK + 2))
    RISK_REASONS="${RISK_REASONS}API变更 "
fi

# 配置变更 = 中风险
if [[ -n "$CONFIG_FILES" ]]; then
    RISK=$((RISK + 1))
    RISK_REASONS="${RISK_REASONS}配置变更 "
fi

# 大量文件变更 = 风险增加
FILE_COUNT=$(printf '%s\n' "$CHANGED_FILES" | wc -l | tr -d ' ')
if [[ $FILE_COUNT -gt 20 ]]; then
    RISK=$((RISK + 1))
    RISK_REASONS="${RISK_REASONS}大量文件(${FILE_COUNT}) "
fi

# 无测试覆盖 = 风险增加
if [[ -z "$TEST_FILES" && -n "$SRC_FILES" ]]; then
    RISK=$((RISK + 1))
    RISK_REASONS="${RISK_REASONS}缺少测试 "
fi

if [[ $RISK -ge 4 ]]; then
    echo -e "${RED}🔴 高风险${NC} - ${RISK_REASONS}"
    echo "  建议: 仔细审查 + 充分测试 + 灰度发布"
elif [[ $RISK -ge 2 ]]; then
    echo -e "${YELLOW}🟡 中风险${NC} - ${RISK_REASONS}"
    echo "  建议: 标准审查流程"
else
    echo -e "${GREEN}🟢 低风险${NC}"
    echo "  建议: 快速审查"
fi

echo ""
echo -e "${GREEN}✅ 影响分析完成${NC}"
