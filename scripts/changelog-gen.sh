#!/bin/bash
# Changelog 自动生成
# 基于 Conventional Commits 生成 CHANGELOG 草案

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TARGET_DIR="${1:-.}"
SINCE="${2:-}"  # 起始 tag 或 commit

echo -e "${CYAN}📝 Changelog Generator / 变更日志生成${NC}"
echo "=========================================="
echo ""

cd "$TARGET_DIR"

# 确定版本范围
if [[ -z "$SINCE" ]]; then
    # 使用最近的 tag
    SINCE=$(git describe --tags --abbrev=0 2>/dev/null || echo "HEAD~10")
    echo -e "${CYAN}基于最近的 tag: ${SINCE}${NC}"
else
    echo -e "${CYAN}基于范围: ${SINCE}..HEAD${NC}"
fi

# 获取提交记录
COMMITS=$(git log "${SINCE}..HEAD" --pretty=format:"%s|%b" 2>/dev/null || true)

if [[ -z "$COMMITS" ]]; then
    echo -e "${YELLOW}该范围内无提交记录${NC}"
    exit 0
fi

echo ""
echo -e "${CYAN}【生成 CHANGELOG 草案】${NC}"
echo ""

# 分类提交
FEATURES=""
FIXES=""
DOCS=""
STYLE=""
REFACTOR=""
PERF=""
TEST=""
CHORE=""
SECURITY=""
BREAKING=""

while IFS='|' read -r subject body; do
    [[ -z "$subject" ]] && continue

    # 检测 breaking change
    if printf '%s\n' "$subject" | grep -qE '^\w+\(.*\)!:' || printf '%s\n' "$body" | grep -qi "BREAKING CHANGE"; then
        BREAKING+="- ${subject}\n"
        continue
    fi

    # 按类型分类
    if printf '%s\n' "$subject" | grep -qE '^feat(\(.*\))?:'; then
        FEATURES+="- ${subject}\n"
    elif printf '%s\n' "$subject" | grep -qE '^fix(\(.*\))?:'; then
        FIXES+="- ${subject}\n"
    elif printf '%s\n' "$subject" | grep -qE '^docs(\(.*\))?:'; then
        DOCS+="- ${subject}\n"
    elif printf '%s\n' "$subject" | grep -qE '^style(\(.*\))?:'; then
        STYLE+="- ${subject}\n"
    elif printf '%s\n' "$subject" | grep -qE '^refactor(\(.*\))?:'; then
        REFACTOR+="- ${subject}\n"
    elif printf '%s\n' "$subject" | grep -qE '^perf(\(.*\))?:'; then
        PERF+="- ${subject}\n"
    elif printf '%s\n' "$subject" | grep -qE '^test(\(.*\))?:'; then
        TEST+="- ${subject}\n"
    elif printf '%s\n' "$subject" | grep -qE '^chore(\(.*\))?:'; then
        CHORE+="- ${subject}\n"
    elif printf '%s\n' "$subject" | grep -qE '^security(\(.*\))?:'; then
        SECURITY+="- ${subject}\n"
    else
        # 不符合规范的提交
        CHORE+="- ${subject} *(未遵循 Conventional Commits)*\n"
    fi
done <<< "$COMMITS"

# 输出生成的 CHANGELOG
VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "$(date +%Y.%m.%d)")

cat << EOF
## [${VERSION}] - $(date '+%Y-%m-%d')

EOF

if [[ -n "$BREAKING" ]]; then
    echo "### ⚠ Breaking Changes"
    echo -e "$BREAKING"
    echo ""
fi

if [[ -n "$SECURITY" ]]; then
    echo "### 🔒 Security"
    echo -e "$SECURITY"
    echo ""
fi

if [[ -n "$FEATURES" ]]; then
    echo "### ✨ Features"
    echo -e "$FEATURES"
    echo ""
fi

if [[ -n "$FIXES" ]]; then
    echo "### 🐛 Bug Fixes"
    echo -e "$FIXES"
    echo ""
fi

if [[ -n "$PERF" ]]; then
    echo "### ⚡ Performance"
    echo -e "$PERF"
    echo ""
fi

if [[ -n "$REFACTOR" ]]; then
    echo "### ♻️ Refactor"
    echo -e "$REFACTOR"
    echo ""
fi

if [[ -n "$DOCS" ]]; then
    echo "### 📚 Documentation"
    echo -e "$DOCS"
    echo ""
fi

if [[ -n "$TEST" ]]; then
    echo "### ✅ Tests"
    echo -e "$TEST"
    echo ""
fi

if [[ -n "$STYLE" ]]; then
    echo "### 💄 Styles"
    echo -e "$STYLE"
    echo ""
fi

if [[ -n "$CHORE" ]]; then
    echo "### 🔧 Chores"
    echo -e "$CHORE"
    echo ""
fi

echo "---"
echo ""
echo -e "${GREEN}✅ CHANGELOG 草案生成完成${NC}"
echo -e "${YELLOW}提示: 复制上方内容到 CHANGELOG.md 中，并根据实际情况补充详细说明${NC}"
