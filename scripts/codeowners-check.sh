#!/bin/bash
# CODEOWNERS 匹配检查
# 验证关键文件是否被正确的 owner review

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

TARGET_DIR="${1:-.}"

echo -e "${CYAN}👥 CODEOWNERS / 代码所有者检查${NC}"
echo "=========================================="
echo ""

cd "$TARGET_DIR"

# 查找 CODEOWNERS 文件
CODEOWNERS=""
for path in "CODEOWNERS" ".github/CODEOWNERS" ".gitlab/CODEOWNERS" "docs/CODEOWNERS"; do
    if [[ -f "$path" ]]; then
        CODEOWNERS="$path"
        break
    fi
done

if [[ -z "$CODEOWNERS" ]]; then
    echo -e "${YELLOW}未找到 CODEOWNERS 文件${NC}"
    echo "  建议创建: .github/CODEOWNERS"
    echo "  格式示例:"
    echo "    *       @team/backend"
    echo "    src/ui/ @team/frontend"
    echo "    *.sql   @team/dba"
    exit 0
fi

echo -e "${CYAN}【CODEOWNERS 文件】${NC} $CODEOWNERS"
echo ""

# 获取变更文件
CHANGED_FILES=$(git diff --name-only HEAD~1..HEAD 2>/dev/null || true)

if [[ -z "$CHANGED_FILES" ]]; then
    echo -e "${YELLOW}无变更文件${NC}"
    exit 0
fi

echo -e "${CYAN}【变更文件与 Owner 匹配】${NC}"
echo ""

missing_owner=()
while IFS= read -r file; do
    [[ -z "$file" ]] && continue

    # 匹配 CODEOWNERS 规则
    owner=$(grep -E "^[^#].*${file}" "$CODEOWNERS" 2>/dev/null | tail -1 | grep -oE '@[^[:space:]]+' || true)

    if [[ -z "$owner" ]]; then
        # 尝试通配符匹配
        owner=$(grep -E "^[^#].*\*" "$CODEOWNERS" 2>/dev/null | tail -1 | grep -oE '@[^[:space:]]+' || true)
    fi

    if [[ -n "$owner" ]]; then
        echo -e "  ${GREEN}✓${NC} $file → $owner"
    else
        echo -e "  ${YELLOW}⚠${NC} $file → (无 owner)"
        missing_owner+=("$file")
    fi
done <<< "$CHANGED_FILES"

echo ""

# 关键路径检查
echo -e "${CYAN}【关键路径检查】${NC}"
critical_paths=("auth" "security" "payment" "billing" "deploy" "ci" "k8s" "terraform" "migration" "secret")

critical_unowned=()
while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    for cp in "${critical_paths[@]}"; do
        if [[ "$file" =~ $cp ]]; then
            owner=$(grep -E "^[^#].*${file}" "$CODEOWNERS" 2>/dev/null | tail -1 | grep -oE '@[^[:space:]]+' || true)
            if [[ -z "$owner" ]]; then
                critical_unowned+=("$file (含 '$cp' 路径)")
            fi
            break
        fi
    done
done <<< "$CHANGED_FILES"

if [[ ${#critical_unowned[@]} -gt 0 ]]; then
    echo -e "  ${RED}🔴 以下关键文件缺少 owner:${NC}"
    for f in "${critical_unowned[@]}"; do
        echo "    - $f"
    done
    echo ""
    echo -e "${YELLOW}建议: 为这些路径添加专门的 owner${NC}"
fi

echo ""
echo -e "${CYAN}【CODEOWNERS 最佳实践】${NC}"
echo "  1. 关键路径必须有明确的 owner (@team/xxx)"
echo "  2. 配置评审规则: 必须 owner 批准才能合并"
echo "  3. 定期审查 CODEOWNERS，移除离职人员"
echo "  4. 使用团队标签而非个人账号"
