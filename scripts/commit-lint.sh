#!/bin/bash
# Git 提交规范检查
# 检查 commit message 格式是否符合 Conventional Commits

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

TARGET_DIR="${1:-.}"
BASE_REF="${2:-HEAD~5}"

echo -e "${CYAN}📝 Commit Lint / 提交规范检查${NC}"
echo "=========================================="
echo ""

cd "$TARGET_DIR"

# 获取提交记录
COMMITS=$(git log "${BASE_REF}..HEAD" --pretty=format:"%H|%s|%an|%ad" --date=short 2>/dev/null || true)

if [[ -z "$COMMITS" ]]; then
    echo -e "${YELLOW}无新提交${NC}"
    exit 0
fi

# Conventional Commits 类型
VALID_TYPES="feat|fix|docs|style|refactor|test|chore|perf|ci|build|revert|security"

total=0
valid=0
invalid=0

# 分析提交格式错误的具体原因（Bash 3.2 兼容）
analyze_commit_error() {
    local msg="$1"
    local reason=""
    local suggestion=""

    # 检查是否以反引号开头（Markdown 代码块复制粘贴）
    if printf '%s\n' "$msg" | grep -qE '^`+'; then
        reason="commit message 以反引号开头，可能是复制粘贴时带入了 Markdown 代码块格式"
        suggestion=$(printf '%s\n' "$msg" | sed -E 's/^`+[[:space:]]*//')
        printf '%s|%s\n' "$reason" "$suggestion"
        return 0
    fi

    # 提取开头的单词
    local first_word
    first_word=$(printf '%s\n' "$msg" | sed -E 's/^([a-zA-Z]+).*/\1/')

    case "$first_word" in
        featrue)
            reason="type 拼写错误: \"featrue\" → 应为 \"feat\""
            suggestion="feat: $(printf '%s\n' "$msg" | sed -E 's/^featrue:?[[:space:]]*//')"
            ;;
        fea|featur|feate)
            reason="type 拼写/不完整: \"$first_word\" → 应为 \"feat\""
            suggestion="feat: $(printf '%s\n' "$msg" | sed -E 's/^[a-zA-Z]+:?[[:space:]]*//')"
            ;;
        fixe|fixd)
            reason="type 拼写错误: \"$first_word\" → 应为 \"fix\""
            suggestion="fix: $(printf '%s\n' "$msg" | sed -E 's/^[a-zA-Z]+:?[[:space:]]*//')"
            ;;
        doc)
            reason="type 拼写错误: \"$first_word\" → 应为 \"docs\"（复数形式）"
            suggestion="docs: $(printf '%s\n' "$msg" | sed -E 's/^[a-zA-Z]+:?[[:space:]]*//')"
            ;;
        refacto|refator)
            reason="type 拼写错误: \"$first_word\" → 应为 \"refactor\""
            suggestion="refactor: $(printf '%s\n' "$msg" | sed -E 's/^[a-zA-Z]+:?[[:space:]]*//')"
            ;;
        tes|testin)
            reason="type 拼写错误: \"$first_word\" → 应为 \"test\""
            suggestion="test: $(printf '%s\n' "$msg" | sed -E 's/^[a-zA-Z]+:?[[:space:]]*//')"
            ;;
        choe|chor)
            reason="type 拼写错误: \"$first_word\" → 应为 \"chore\""
            suggestion="chore: $(printf '%s\n' "$msg" | sed -E 's/^[a-zA-Z]+:?[[:space:]]*//')"
            ;;
        perfo|perfe)
            reason="type 拼写错误: \"$first_word\" → 应为 \"perf\""
            suggestion="perf: $(printf '%s\n' "$msg" | sed -E 's/^[a-zA-Z]+:?[[:space:]]*//')"
            ;;
        feat|fix|docs|style|refactor|test|chore|perf|ci|build|revert|security)
            # 合法 type，检查格式问题
            if printf '%s\n' "$msg" | grep -qE "^[a-z]+(\([^)]*\))?!?$"; then
                reason="缺少冒号(:)和空格，或描述内容为空"
                suggestion="$first_word: 添加具体的修改描述"
            elif printf '%s\n' "$msg" | grep -qE "^[a-z]+(\([^)]*\))?:[^[:space:]]"; then
                reason="冒号后缺少空格（应为 \": \"）"
                suggestion=$(printf '%s\n' "$msg" | sed -E 's/^([a-z]+(\([^)]*\))?!?:)([^[:space:]])/\1 \3/')
            else
                reason="subject（描述内容）为空或格式不正确"
                suggestion="格式: $first_word[(scope)]: <具体描述>"
            fi
            ;;
        "")
            reason="commit message 为空"
            suggestion="请填写有意义的提交描述"
            ;;
        *)
            if printf '%s\n' "$first_word" | grep -qE "^(${VALID_TYPES})$"; then
                reason="不符合 Conventional Commits 格式"
                suggestion="格式: <type>[(scope)]: <subject>"
            else
                reason="未知的 type \"$first_word\"，不在允许列表中"
                suggestion="可用 type: feat, fix, docs, style, refactor, test, chore, perf, ci, build, revert, security"
            fi
            ;;
    esac

    printf '%s|%s\n' "$reason" "$suggestion"
}

while IFS='|' read -r hash subject author date; do
    [[ -z "$hash" ]] && continue

    total=$((total + 1))

    # 检查格式: type(scope): subject（Bash 3.2 兼容，使用 grep -E 替代 =~）
    # 用 printf 代替 echo 避免 subject 中的反引号触发命令替换
    if printf '%s\n' "$subject" | grep -qE "^(${VALID_TYPES})(\([^)]*\))?!?: .+"; then
        # 提取 type 和 scope
        type=$(printf '%s\n' "$subject" | sed -E "s/^(${VALID_TYPES}).*/\1/")
        scope=$(printf '%s\n' "$subject" | sed -E "s/^${VALID_TYPES}(\([^)]*\))?!?: .*/\1/")

        # 检查长度
        len=${#subject}
        if [[ $len -gt 72 ]]; then
            subj_preview="${subject:0:50}"
            printf '  %b🟡 %s 标题过长 (%d > 72): %s...%b\n' "$YELLOW" "${hash:0:7}" "$len" "$subj_preview" "$NC"
            invalid=$((invalid + 1))
        else
            printf '  %b✓ %s [%s] %s%b\n' "$GREEN" "${hash:0:7}" "$type" "$subject" "$NC"
            valid=$((valid + 1))
        fi
    else
        # 分析具体错误原因
        error_info=$(analyze_commit_error "$subject")
        error_reason=$(printf '%s\n' "$error_info" | cut -d'|' -f1)
        error_suggestion=$(printf '%s\n' "$error_info" | cut -d'|' -f2-)

        printf '  %b✗ %s 格式错误: %s%b\n' "$RED" "${hash:0:7}" "$subject" "$NC"
        if [[ -n "$error_reason" ]]; then
            printf '     %b💡 原因:%b %s\n' "$RED" "$NC" "$error_reason"
        fi
        if [[ -n "$error_suggestion" ]]; then
            printf '     %b✅ 建议:%b %s\n' "$YELLOW" "$NC" "$error_suggestion"
        fi
        invalid=$((invalid + 1))
    fi
done <<< "$COMMITS"

echo ""
printf '%b【统计】%b\n' "$CYAN" "$NC"
printf '  总计: %d\n' "$total"
printf '  通过: %b%d%b\n' "$GREEN" "$valid" "$NC"
printf '  失败: %b%d%b\n' "$RED" "$invalid" "$NC"

if [[ $invalid -gt 0 ]]; then
    echo ""
    echo -e "${YELLOW}Conventional Commits 格式:${NC}"
    echo "  <type>[(scope)][!]: <subject>"
    echo ""
    echo "  type 可选值:"
    echo "    feat     - 新功能"
    echo "    fix      - 修复"
    echo "    docs     - 文档"
    echo "    style    - 代码格式"
    echo "    refactor - 重构"
    echo "    test     - 测试"
    echo "    chore    - 构建/工具"
    echo "    perf     - 性能"
    echo "    ci       - CI配置"
    echo "    build    - 构建"
    echo "    security - 安全"
    echo ""
    echo "  示例:"
    echo "    feat(user): add login page"
    echo "    fix(api): resolve null pointer exception"
    echo "    docs: update README"
    exit 1
else
    echo ""
    echo -e "${GREEN}✅ 所有提交符合规范${NC}"
    exit 0
fi
