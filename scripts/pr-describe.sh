#!/bin/bash
# PR 描述自动生成
# 分析 git diff 和 commit 信息，自动生成 PR 标题和描述

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

echo -e "${CYAN}${BOLD}📝 PR Describe / PR 描述自动生成${NC}"
echo "=============================================="
echo ""

cd "$TARGET_DIR"

# ===== 获取变更信息 =====

BASE_REF=$(git merge-base HEAD origin/main 2>/dev/null || git merge-base HEAD main 2>/dev/null || echo "HEAD~1")
CHANGED_FILES=$(git diff --name-only "$BASE_REF"..HEAD 2>/dev/null || git diff --name-only HEAD~1..HEAD 2>/dev/null || true)
COMMIT_MESSAGES=$(git log --format="%s" "$BASE_REF"..HEAD 2>/dev/null || git log --format="%s" -5 2>/dev/null || true)

echo -e "${BLUE}【分析变更】${NC}"
echo ""

# 分析文件类型
FEAT_FILES=$(printf '%s\n' "$CHANGED_FILES" | grep -E '\.(js|ts|jsx|tsx|py|go|java|kt|php|rs|rb|swift)$' || true)
TEST_FILES=$(printf '%s\n' "$CHANGED_FILES" | grep -E '\.(test|spec)\.(js|ts|jsx|tsx|py|go|java|kt|php)$' || true)
DOC_FILES=$(printf '%s\n' "$CHANGED_FILES" | grep -E '\.(md|rst|txt)$|README|CHANGELOG|docs/' || true)
CONFIG_FILES=$(printf '%s\n' "$CHANGED_FILES" | grep -E '\.(json|yaml|yml|toml|ini|conf|env)$|Dockerfile|docker-compose|\.github/' || true)

TOTAL_COUNT=$(printf '%s\n' "$CHANGED_FILES" | grep -v '^$' | wc -l | tr -d ' ')
FEAT_COUNT=$(printf '%s\n' "$FEAT_FILES" | grep -v '^$' | wc -l | tr -d ' ')
TEST_COUNT=$(printf '%s\n' "$TEST_FILES" | grep -v '^$' | wc -l | tr -d ' ')
DOC_COUNT=$(printf '%s\n' "$DOC_FILES" | grep -v '^$' | wc -l | tr -d ' ')
CONFIG_COUNT=$(printf '%s\n' "$CONFIG_FILES" | grep -v '^$' | wc -l | tr -d ' ')

# 判断变更类型
if [[ "$COMMIT_MESSAGES" =~ (feat|feature|add|implement) ]]; then
    CHANGE_TYPE="feat"
    TYPE_LABEL="✨ Feature"
elif [[ "$COMMIT_MESSAGES" =~ (fix|bugfix|hotfix|patch) ]]; then
    CHANGE_TYPE="fix"
    TYPE_LABEL="🐛 Fix"
elif [[ "$COMMIT_MESSAGES" =~ (docs|doc|documentation) ]]; then
    CHANGE_TYPE="docs"
    TYPE_LABEL="📝 Docs"
elif [[ "$COMMIT_MESSAGES" =~ (refactor|cleanup|clean) ]]; then
    CHANGE_TYPE="refactor"
    TYPE_LABEL="♻️ Refactor"
elif [[ "$COMMIT_MESSAGES" =~ (test|tests|testing) ]]; then
    CHANGE_TYPE="test"
    TYPE_LABEL="✅ Test"
elif [[ "$COMMIT_MESSAGES" =~ (chore|deps|dependency|upgrade|bump) ]]; then
    CHANGE_TYPE="chore"
    TYPE_LABEL="🔧 Chore"
elif [[ "$COMMIT_MESSAGES" =~ (perf|performance|optimize) ]]; then
    CHANGE_TYPE="perf"
    TYPE_LABEL="⚡ Performance"
elif [[ "$COMMIT_MESSAGES" =~ (security|vuln|cve) ]]; then
    CHANGE_TYPE="security"
    TYPE_LABEL="🔒 Security"
else
    CHANGE_TYPE="chore"
    TYPE_LABEL="🔧 Update"
fi

# 生成 PR 标题
echo -e "${CYAN}${BOLD}【生成 PR 标题】${NC}"
echo ""

# 从 commit message 提取主题
# 去除 Conventional Commits 的 type(scope): 前缀（BSD sed 兼容，使用 -E 扩展正则）
MAIN_SUBJECT=$(printf '%s\n' "$COMMIT_MESSAGES" | head -1 | sed -E 's/^[a-z]+(\([^)]*\))?!?:[[:space:]]*//' | sed 's/^[[:space:]]*//' | sed 's/\.$//' || true)

if [[ -z "$MAIN_SUBJECT" ]]; then
    if [[ $FEAT_COUNT -gt 0 ]]; then
        MAIN_SUBJECT="update ${FEAT_COUNT} files"
    else
        MAIN_SUBJECT="update configuration"
    fi
fi

PR_TITLE="${TYPE_LABEL}: ${MAIN_SUBJECT}"
echo -e "  ${GREEN}${BOLD}${PR_TITLE}${NC}"
echo ""

# ===== 生成 PR 描述 =====

echo -e "${CYAN}${BOLD}【生成 PR 描述】${NC}"
echo ""

PR_BODY=""
PR_BODY+="## Summary\n\n"
PR_BODY+="${TYPE_LABEL} — ${MAIN_SUBJECT}\n\n"

# 变更统计
PR_BODY+="## Changes\n\n"
PR_BODY+="| Type | Count |\n"
PR_BODY+="|------|-------|\n"
PR_BODY+="| Source files | ${FEAT_COUNT} |\n"
PR_BODY+="| Test files | ${TEST_COUNT} |\n"
PR_BODY+="| Documentation | ${DOC_COUNT} |\n"
PR_BODY+="| Configuration | ${CONFIG_COUNT} |\n"
PR_BODY+="| **Total** | **${TOTAL_COUNT}** |\n\n"

# 变更文件列表
if [[ $TOTAL_COUNT -gt 0 ]]; then
    PR_BODY+="### Files Changed\n\n"
    PR_BODY+="\`\`\`\n"
    PR_BODY+="${CHANGED_FILES}\n"
    PR_BODY+="\`\`\`\n\n"
fi

# Commit 摘要
if [[ -n "$COMMIT_MESSAGES" ]]; then
    PR_BODY+="### Commits\n\n"
    while IFS= read -r msg; do
        [[ -z "$msg" ]] && continue
        PR_BODY+="- ${msg}\n"
    done <<< "$COMMIT_MESSAGES"
    PR_BODY+="\n"
fi

# 风险评估
if [[ $TOTAL_COUNT -gt 10 ]]; then
    PR_BODY+="### ⚠️ Risk Assessment\n\n"
    PR_BODY+="**HIGH** — Large change set (${TOTAL_COUNT} files). Recommend careful review.\n\n"
elif [[ $TOTAL_COUNT -gt 5 ]]; then
    PR_BODY+="### Risk Assessment\n\n"
    PR_BODY+="**MEDIUM** — Moderate change set. Standard review recommended.\n\n"
else
    PR_BODY+="### Risk Assessment\n\n"
    PR_BODY+="**LOW** — Small focused change. Quick review should suffice.\n\n"
fi

# 审查清单
PR_BODY+="### Review Checklist\n\n"
PR_BODY+="- [ ] Code follows project style guidelines\n"
PR_BODY+="- [ ] Tests added/updated for new behavior\n"
PR_BODY+="- [ ] Documentation updated if needed\n"
PR_BODY+="- [ ] No hardcoded secrets or credentials\n"
PR_BODY+="- [ ] Error handling is comprehensive\n"
PR_BODY+="- [ ] Breaking changes are documented\n\n"

echo "$PR_BODY"

# ===== 更新 PR =====

echo ""
echo -e "${CYAN}${BOLD}【操作】${NC}"
echo ""

if [[ -n "$PR_NUMBER" ]]; then
    if command -v gh &>/dev/null; then
        # 写入临时文件
        TEMP_FILE=$(mktemp)
        echo "$PR_BODY" > "$TEMP_FILE"

        # 更新 PR 标题和描述
        gh pr edit "$PR_NUMBER" --title "$PR_TITLE" --body-file "$TEMP_FILE"
        rm -f "$TEMP_FILE"
        echo -e "  ${GREEN}✅ PR #${PR_NUMBER} 已更新${NC}"
    else
        echo -e "  ${YELLOW}⚠️ gh CLI 未安装，仅输出描述内容${NC}"
        echo ""
        echo -e "${CYAN}手动更新命令:${NC}"
        echo "  gh pr edit ${PR_NUMBER} --title \"${PR_TITLE}\" --body \"...\""
    fi
else
    echo -e "  ${YELLOW}未指定 PR 编号，仅输出描述内容${NC}"
    echo ""
    echo -e "${CYAN}使用方式:${NC}"
    echo "  pr-describe . <pr-number>   # 自动更新 PR"
    echo "  pr-describe .               # 仅输出描述"
fi
