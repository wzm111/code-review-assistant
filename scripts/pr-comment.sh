#!/bin/bash
# PR 内联评论
# 将审查结果解析为 GitHub PR 行级评论

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

TARGET_DIR="${1:-.}"
PR_NUMBER="${2:-}"
REVIEW_FILE="${3:-}"

echo -e "${CYAN}${BOLD}💬 PR Comment / PR 内联评论${NC}"
echo "=============================================="
echo ""

cd "$TARGET_DIR"

# ===== 检查环境 =====

if ! command -v gh &>/dev/null; then
    echo -e "${RED}错误: gh CLI 未安装${NC}"
    echo "安装: https://cli.github.com/"
    exit 1
fi

if ! gh auth status &>/dev/null; then
    echo -e "${RED}错误: gh CLI 未认证${NC}"
    echo "运行: gh auth login"
    exit 1
fi

if [[ -z "$PR_NUMBER" ]]; then
    # 尝试自动检测当前 PR
    PR_NUMBER=$(gh pr view --json number -q '.number' 2>/dev/null || true)
    if [[ -z "$PR_NUMBER" ]]; then
        echo -e "${RED}错误: 无法检测 PR 编号${NC}"
        echo "用法: pr-comment . <pr-number> [review-output-file]"
        exit 1
    fi
    echo -e "${BLUE}自动检测到 PR #${PR_NUMBER}${NC}"
fi

# ===== 读取审查结果 =====

if [[ -n "$REVIEW_FILE" && -f "$REVIEW_FILE" ]]; then
    REVIEW_OUTPUT=$(cat "$REVIEW_FILE")
else
    # 从 stdin 读取
    REVIEW_OUTPUT=$(cat)
fi

if [[ -z "$REVIEW_OUTPUT" ]]; then
    echo -e "${YELLOW}无审查结果输入${NC}"
    echo "用法示例:"
    echo "  bash scripts/scan-secrets.sh . | bash scripts/pr-comment.sh . 42"
    echo "  bash scripts/pr-comment.sh . 42 review_output.txt"
    exit 0
fi

# ===== 解析审查结果 =====

echo -e "${CYAN}【解析审查结果】${NC}"
echo ""

COMMENTS=()
SUMMARY_LINES=()

# 解析 [File:Line] 格式的评论
while IFS= read -r line; do
    # 匹配 [file:line] 或 [file.ts:42] 格式
    if [[ "$line" =~ \[([a-zA-Z0-9_\-\./]+):([0-9]+)\][[:space:]]*(.*) ]]; then
        file="${BASH_REMATCH[1]}"
        lineno="${BASH_REMATCH[2]}"
        message="${BASH_REMATCH[3]}"

        # 确定严重度
        severity="suggestion"
        if [[ "$line" =~ 🔴|CRITICAL|critical|严重 ]]; then
            severity="critical"
        elif [[ "$line" =~ 🟡|HIGH|high|高危 ]]; then
            severity="warning"
        elif [[ "$line" =~ 🟢|LOW|low|低危 ]]; then
            severity="suggestion"
        fi

        COMMENTS+=("${file}:${lineno}:${severity}:${message}")
    elif [[ "$line" =~ 🔴|🟡|⚠️|❌ ]]; then
        # 没有行号的摘要行
        SUMMARY_LINES+=("$line")
    fi
done <<< "$REVIEW_OUTPUT"

echo -e "  ${BLUE}解析到 ${#COMMENTS[@]} 条行级评论${NC}"
echo -e "  ${BLUE}解析到 ${#SUMMARY_LINES[@]} 条摘要${NC}"
echo ""

# ===== 构建评论数据 =====

echo -e "${CYAN}【构建评论数据】${NC}"
echo ""

REVIEW_BODY="## Code Review Assistant\n\n"

# 添加摘要
if [[ ${#SUMMARY_LINES[@]} -gt 0 ]]; then
    REVIEW_BODY+="### Summary\n\n"
    for summary in "${SUMMARY_LINES[@]}"; do
        REVIEW_BODY+="${summary}\n"
    done
    REVIEW_BODY+="\n"
fi

# 添加行级评论统计
if [[ ${#COMMENTS[@]} -gt 0 ]]; then
    REVIEW_BODY+="### Inline Comments (${#COMMENTS[@]})\n\n"
fi

echo -e "  ${GREEN}✅ 评论内容准备完成${NC}"
echo ""

# ===== 提交 PR Review =====

echo -e "${CYAN}【提交 PR Review】${NC}"
echo ""

# 方法1: 使用 gh pr review --comment (适用于少量评论)
if [[ ${#COMMENTS[@]} -le 10 ]]; then
    echo -e "  ${BLUE}使用 gh pr review 提交 ${#COMMENTS[@]} 条评论...${NC}"

    # 创建临时 review body 文件
    TEMP_BODY=$(mktemp)
    echo -e "$REVIEW_BODY" > "$TEMP_BODY"

    # 提交 review
    if gh pr review "$PR_NUMBER" --comment --body-file "$TEMP_BODY"; then
        echo -e "  ${GREEN}✅ PR Review 提交成功${NC}"
    else
        echo -e "  ${YELLOW}⚠️ gh pr review 失败，尝试替代方案${NC}"
    fi
    rm -f "$TEMP_BODY"
fi

# 方法2: 使用 GitHub API 提交行级评论 (更精确)
if [[ ${#COMMENTS[@]} -gt 0 ]]; then
    echo -e "  ${BLUE}使用 GitHub API 提交行级评论...${NC}"

    # 获取 PR 信息
    PR_INFO=$(gh pr view "$PR_NUMBER" --json headRefOid,baseRefOid 2>/dev/null || true)
    HEAD_SHA=$(printf '%s\n' "$PR_INFO" | grep -o '"headRefOid":"[^"]*"' | cut -d'"' -f4 || true)

    if [[ -z "$HEAD_SHA" ]]; then
        HEAD_SHA=$(git rev-parse HEAD)
    fi

    # 构建评论 JSON
    COMMENTS_JSON="["
    first=true
    for comment in "${COMMENTS[@]}"; do
        IFS=':' read -r file lineno severity message <<< "$comment"

        # 获取文件在 PR 中的 diff 位置
        # 简化：使用文件路径和行号
        if [[ "$first" == true ]]; then
            first=false
        else
            COMMENTS_JSON+=","
        fi

        COMMENTS_JSON+="{\"path\":\"${file}\",\"line\":${lineno},\"body\":\"${severity}: ${message}\"}"
    done
    COMMENTS_JSON+="]"

    # 创建 review
    REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null || echo "")
    if [[ -n "$REPO" ]]; then
        REVIEW_PAYLOAD=$(cat <<EOF
{
  "commit_id": "${HEAD_SHA}",
  "body": "$(echo -e "$REVIEW_BODY" | sed 's/"/\\"/g' | tr '\n' ' ')",
  "event": "COMMENT",
  "comments": ${COMMENTS_JSON}
}
EOF
)

        RESPONSE=$(curl -s -X POST \
            -H "Authorization: token $(gh auth token)" \
            -H "Accept: application/vnd.github.v3+json" \
            "https://api.github.com/repos/${REPO}/pulls/${PR_NUMBER}/reviews" \
            -d "$REVIEW_PAYLOAD" 2>/dev/null || true)

        if printf '%s\n' "$RESPONSE" | grep -q '"id"'; then
            echo -e "  ${GREEN}✅ 行级评论提交成功${NC}"
        else
            echo -e "  ${YELLOW}⚠️ API 提交失败，可能原因:${NC}"
            echo "     - 行号不在 PR diff 范围内"
            echo "     - 权限不足"
            echo "     - 评论已存在"
        fi
    fi
fi

echo ""
echo -e "${GREEN}${BOLD}PR Review 提交完成${NC}"
echo ""
echo -e "${CYAN}查看 PR:${NC}"
gh pr view "$PR_NUMBER" --json url -q '.url' 2>/dev/null || true
