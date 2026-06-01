#!/bin/bash
# PR 上下文读取脚本
# 获取 PR 描述、关联 Issue、Reviewer 评论等上下文信息

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TARGET_DIR="${1:-.}"
REMOTE_URL=""
PR_NUMBER="${2:-}"

echo -e "${CYAN}📋 PR Context Reader / PR 上下文读取${NC}"
echo "=========================================="
echo ""

cd "$TARGET_DIR"

# 获取远程仓库信息
get_remote_info() {
    REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")

    if [[ -z "$REMOTE_URL" ]]; then
        echo -e "${YELLOW}⚠️ 未配置远程仓库${NC}"
        return 1
    fi

    # 解析平台
    if [[ "$REMOTE_URL" == *"github.com"* ]]; then
        PLATFORM="github"
    elif [[ "$REMOTE_URL" == *"gitlab"* ]]; then
        PLATFORM="gitlab"
    elif [[ "$REMOTE_URL" == *"gitee"* ]]; then
        PLATFORM="gitee"
    else
        PLATFORM="unknown"
    fi

    # 解析 owner/repo
    if [[ "$REMOTE_URL" =~ github\.com[:/]([^/]+)/([^/]+)(\.git)?$ ]]; then
        OWNER="${BASH_REMATCH[1]}"
        REPO="${BASH_REMATCH[2]%.git}"
    elif [[ "$REMOTE_URL" =~ gitlab[^/]+/(.+)/(.+)(\.git)?$ ]]; then
        OWNER="${BASH_REMATCH[1]}"
        REPO="${BASH_REMATCH[2]%.git}"
    else
        OWNER=""
        REPO=""
    fi

    echo -e "${GREEN}平台: ${PLATFORM}${NC}"
    echo -e "${GREEN}仓库: ${OWNER}/${REPO}${NC}"
    echo ""

    return 0
}

# 获取提交信息作为 PR 上下文
get_commit_context() {
    echo -e "${CYAN}【提交上下文】${NC}"

    # 最近一次的提交信息
    local latest_msg=$(git log -1 --pretty=format:"%s" 2>/dev/null || echo "")
    local latest_body=$(git log -1 --pretty=format:"%b" 2>/dev/null || echo "")
    local latest_author=$(git log -1 --pretty=format:"%an <%ae>" 2>/dev/null || echo "")
    local latest_date=$(git log -1 --pretty=format:"%ad" --date=short 2>/dev/null || echo "")

    echo "最新提交:"
    echo "  作者: ${latest_author}"
    echo "  日期: ${latest_date}"
    echo "  标题: ${latest_msg}"
    if [[ -n "$latest_body" ]]; then
        echo "  详情:"
        printf '%s\n' "$latest_body" | sed 's/^/    /'
    fi
    echo ""

    # 分析提交类型
    if [[ "$latest_msg" =~ ^(feat|feature): ]]; then
        echo "  类型: ✨ 新功能"
    elif [[ "$latest_msg" =~ ^fix: ]]; then
        echo "  类型: 🐛 修复"
    elif [[ "$latest_msg" =~ ^(docs|doc): ]]; then
        echo "  类型: 📝 文档"
    elif [[ "$latest_msg" =~ ^style: ]]; then
        echo "  类型: 💄 样式"
    elif [[ "$latest_msg" =~ ^refactor: ]]; then
        echo "  类型: ♻️ 重构"
    elif [[ "$latest_msg" =~ ^(test|tests): ]]; then
        echo "  类型: ✅ 测试"
    elif [[ "$latest_msg" =~ ^chore: ]]; then
        echo "  类型: 🔧 构建"
    elif [[ "$latest_msg" =~ ^(security|sec): ]]; then
        echo "  类型: 🔒 安全"
    else
        echo "  类型: 📝 其他"
    fi
    echo ""
}

# 获取变更统计
get_change_stats() {
    echo -e "${CYAN}【变更统计】${NC}"

    # 获取变更文件列表
    local changed_files=$(git diff --name-only HEAD~1..HEAD 2>/dev/null || git diff --name-only 2>/dev/null || true)

    if [[ -z "$changed_files" ]]; then
        echo -e "${YELLOW}无变更${NC}"
        return
    fi

    local file_count=$(printf '%s\n' "$changed_files" | wc -l | tr -d ' ')
    echo "变更文件数: ${file_count}"

    # 按类型统计
    echo ""
    echo "文件类型分布:"
    printf '%s\n' "$changed_files" | grep -oE '\.[^.]+$' | sort | uniq -c | sort -rn | head -10 | sed 's/^/  /'

    # 统计增删行
    local stats=$(git diff --shortstat HEAD~1..HEAD 2>/dev/null || git diff --shortstat 2>/dev/null || true)
    if [[ -n "$stats" ]]; then
        echo ""
        echo "代码变更: ${stats}"
    fi

    # 关键文件标记
    echo ""
    echo "关键变更文件:"
    printf '%s\n' "$changed_files" | grep -E '(config|security|auth|login|password|token|api|route|middleware)' | head -5 | sed 's/^/  ⚠️ /' || true

    echo ""
}

# 获取 GitHub PR 信息（如果有 gh CLI）
get_github_pr_info() {
    if ! command -v gh &> /dev/null; then
        return
    fi

    echo -e "${CYAN}【GitHub PR 信息】${NC}"

    # 获取当前分支关联的 PR
    local current_branch=$(git branch --show-current 2>/dev/null || echo "")
    local pr_info=$(gh pr view "$current_branch" --json number,title,body,author,reviewers,labels 2>/dev/null || true)

    if [[ -n "$pr_info" && "$pr_info" != "{}" ]]; then
        printf '%s\n' "$pr_info" | python3 -m json.tool 2>/dev/null || echo "$pr_info"
    else
        echo -e "${YELLOW}未找到关联 PR${NC}"
    fi
    echo ""
}

# 获取关联的 Issue 引用
get_linked_issues() {
    echo -e "${CYAN}【关联 Issue】${NC}"

    # 从提交信息中提取 Issue 引用
    local issues=$(git log -10 --pretty=format:"%s%n%b" | grep -oE '#[0-9]+|fixes?\s+#?[0-9]+|closes?\s+#?[0-9]+|resolves?\s+#?[0-9]+' | sort -u || true)

    if [[ -n "$issues" ]]; then
        echo "引用:"
        printf '%s\n' "$issues" | sed 's/^/  /'
    else
        echo -e "${YELLOW}未检测到 Issue 引用${NC}"
    fi
    echo ""
}

# 分析代码影响范围
analyze_impact() {
    echo -e "${CYAN}【影响范围分析】${NC}"

    local changed_files=$(git diff --name-only HEAD~1..HEAD 2>/dev/null || git diff --name-only 2>/dev/null || true)

    if [[ -z "$changed_files" ]]; then
        echo -e "${YELLOW}无变更${NC}"
        return
    fi

    # 检查是否修改了关键文件
    local critical_files=$(printf '%s\n' "$changed_files" | grep -E '(package\.json|pom\.xml|requirements\.txt|go\.mod|Dockerfile|\.env|config\.|nginx\.conf)' || true)
    if [[ -n "$critical_files" ]]; then
        echo -e "${YELLOW}⚠️ 修改了配置文件:${NC}"
        printf '%s\n' "$critical_files" | sed 's/^/  /'
        echo ""
    fi

    # 检查是否有测试文件
    local test_files=$(printf '%s\n' "$changed_files" | grep -E '(.+\.test\..*|.+\.spec\..*|tests?/.*|__tests__/.*)' || true)
    if [[ -n "$test_files" ]]; then
        echo -e "${GREEN}✅ 包含测试文件:${NC}"
        printf '%s\n' "$test_files" | sed 's/^/  /'
    else
        echo -e "${YELLOW}⚠️ 未检测到测试文件变更${NC}"
    fi

    # 检查是否有文档更新
    local doc_files=$(printf '%s\n' "$changed_files" | grep -E '(README|CHANGELOG|\.md$|docs/)' || true)
    if [[ -n "$doc_files" ]]; then
        echo ""
        echo -e "${GREEN}📄 包含文档更新:${NC}"
        printf '%s\n' "$doc_files" | sed 's/^/  /'
    fi

    echo ""
}

# 生成审查提示
generate_review_prompt() {
    echo -e "${CYAN}【Claude Code 审查提示】${NC}"
    echo ""
    echo "---"
    echo "请审查以下代码变更:"
    echo ""
    echo "仓库: $(pwd)"
    echo "分支: $(git branch --show-current 2>/dev/null || echo 'unknown')"
    echo "提交: $(git log -1 --pretty=format:'%h - %s' 2>/dev/null || echo 'unknown')"
    echo ""
    echo "变更文件:"
    git diff --name-only HEAD~1..HEAD 2>/dev/null || git diff --name-only 2>/dev/null || true
    echo "---"
}

# 主逻辑
if ! get_remote_info; then
    # 即使没有远程仓库，也尝试获取本地上下文
    get_commit_context
    get_change_stats
    analyze_impact
    generate_review_prompt
    exit 0
fi

get_commit_context
get_change_stats
get_linked_issues
analyze_impact
get_github_pr_info
generate_review_prompt

echo ""
echo -e "${GREEN}✅ PR 上下文读取完成${NC}"
