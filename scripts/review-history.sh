#!/bin/bash
# 审查历史追踪脚本
# 记录每次审查发现的问题，支持对比修复情况

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

TARGET_DIR="${1:-.}"
COMMAND="${2:-list}"  # list, show, diff, stats
REVIEW_ID="${3:-}"

DATA_DIR="${TARGET_DIR}/.code-review-assistant"
HISTORY_FILE="${DATA_DIR}/history.jsonl"

echo -e "${CYAN}📈 Review History / 审查历史${NC}"
echo "=========================================="
echo ""

# 初始化数据目录
init_storage() {
    if [[ ! -d "$DATA_DIR" ]]; then
        mkdir -p "$DATA_DIR"
        echo -e "${YELLOW}创建审查历史目录: ${DATA_DIR}${NC}"
    fi
}

# 保存审查记录
save_review() {
    init_storage

    local review_id="review_$(date +%Y%m%d_%H%M%S)"
    local commit=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
    local branch=$(git branch --show-current 2>/dev/null || echo "unknown")
    local author=$(git log -1 --pretty=format:"%an" 2>/dev/null || echo "unknown")

    # 从 stdin 读取审查结果
    local content=$(cat)

    # 提取问题数量
    local critical=$(printf '%s\n' "$content" | grep -c "🔴" || echo 0)
    local warning=$(printf '%s\n' "$content" | grep -c "🟡" || echo 0)
    local suggestion=$(printf '%s\n' "$content" | grep -c "💡" || echo 0)

    # 构建 JSON 记录
    local record=$(cat <<EOF
{
    "id": "${review_id}",
    "timestamp": "$(date -Iseconds)",
    "commit": "${commit}",
    "branch": "${branch}",
    "author": "${author}",
    "stats": {
        "critical": ${critical},
        "warning": ${warning},
        "suggestion": ${suggestion}
    },
    "content": $(printf '%s\n' "$content" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null || echo '""')
}
EOF
)

    echo "$record" >> "$HISTORY_FILE"
    echo -e "${GREEN}✅ 审查记录已保存: ${review_id}${NC}"
    echo ""
}

# 列出所有审查记录
list_reviews() {
    if [[ ! -f "$HISTORY_FILE" ]]; then
        echo -e "${YELLOW}暂无审查历史${NC}"
        return
    fi

    echo -e "${CYAN}【审查记录列表】${NC}"
    echo ""

    local count=0
    while IFS= read -r line; do
        count=$((count + 1))
        local id=$(printf '%s\n' "$line" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
        local timestamp=$(printf '%s\n' "$line" | grep -o '"timestamp":"[^"]*"' | cut -d'"' -f4)
        local branch=$(printf '%s\n' "$line" | grep -o '"branch":"[^"]*"' | cut -d'"' -f4)
        local critical=$(printf '%s\n' "$line" | grep -o '"critical":[0-9]*' | cut -d: -f2)
        local warning=$(printf '%s\n' "$line" | grep -o '"warning":[0-9]*' | cut -d: -f2)

        echo "  ${count}. ${id}"
        echo "     时间: ${timestamp}"
        echo "     分支: ${branch}"
        echo "     问题: ${RED}${critical} Critical${NC}, ${YELLOW}${warning} Warning${NC}"
        echo ""
    done < "$HISTORY_FILE"

    echo -e "${GREEN}共 ${count} 条记录${NC}"
}

# 显示单条记录详情
show_review() {
    if [[ ! -f "$HISTORY_FILE" ]]; then
        echo -e "${YELLOW}暂无审查历史${NC}"
        return
    fi

    if [[ -z "$REVIEW_ID" ]]; then
        echo -e "${RED}请指定审查 ID${NC}"
        echo "用法: ./review-history.sh show <review_id>"
        return
    fi

    local record=$(grep "\"id\":\"${REVIEW_ID}\"" "$HISTORY_FILE" || true)

    if [[ -z "$record" ]]; then
        echo -e "${RED}未找到记录: ${REVIEW_ID}${NC}"
        return
    fi

    echo -e "${CYAN}【审查详情】${NC}"
    printf '%s\n' "$record" | python3 -m json.tool 2>/dev/null || echo "$record"
}

# 对比两次审查
diff_reviews() {
    if [[ ! -f "$HISTORY_FILE" ]]; then
        echo -e "${YELLOW}暂无审查历史${NC}"
        return
    fi

    echo -e "${CYAN}【审查趋势对比】${NC}"
    echo ""

    # 获取最近两次审查的统计
    local records=$(tail -2 "$HISTORY_FILE")

    if [[ $(printf '%s\n' "$records" | wc -l) -lt 2 ]]; then
        echo -e "${YELLOW}需要至少 2 条记录才能对比${NC}"
        return
    fi

    local line1=$(printf '%s\n' "$records" | head -1)
    local line2=$(printf '%s\n' "$records" | tail -1)

    local id1=$(printf '%s\n' "$line1" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
    local id2=$(printf '%s\n' "$line2" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

    local c1=$(printf '%s\n' "$line1" | grep -o '"critical":[0-9]*' | cut -d: -f2)
    local c2=$(printf '%s\n' "$line2" | grep -o '"critical":[0-9]*' | cut -d: -f2)
    local w1=$(printf '%s\n' "$line1" | grep -o '"warning":[0-9]*' | cut -d: -f2)
    local w2=$(printf '%s\n' "$line2" | grep -o '"warning":[0-9]*' | cut -d: -f2)

    echo "对比: ${id1} vs ${id2}"
    echo ""
    echo "Critical: ${c1} → ${c2} ($(python3 -c "print('+'+str(${c2}-${c1}) if ${c2}>${c1} else str(${c2}-${c1}))"))"
    echo "Warning:  ${w1} → ${w2} ($(python3 -c "print('+'+str(${w2}-${w1}) if ${w2}>${w1} else str(${w2}-${w1}))"))"

    if [[ $c2 -lt $c1 ]]; then
        echo -e "${GREEN}✅ Critical 问题减少${NC}"
    elif [[ $c2 -gt $c1 ]]; then
        echo -e "${RED}⚠️ Critical 问题增加${NC}"
    fi

    echo ""
}

# 统计报告
show_stats() {
    if [[ ! -f "$HISTORY_FILE" ]]; then
        echo -e "${YELLOW}暂无审查历史${NC}"
        return
    fi

    echo -e "${CYAN}【审查统计报告】${NC}"
    echo ""

    local total=$(wc -l < "$HISTORY_FILE" | tr -d ' ')
    local total_critical=0
    local total_warning=0
    local total_suggestion=0

    while IFS= read -r line; do
        local c=$(printf '%s\n' "$line" | grep -o '"critical":[0-9]*' | cut -d: -f2)
        local w=$(printf '%s\n' "$line" | grep -o '"warning":[0-9]*' | cut -d: -f2)
        local s=$(printf '%s\n' "$line" | grep -o '"suggestion":[0-9]*' | cut -d: -f2)

        total_critical=$((total_critical + c))
        total_warning=$((total_warning + w))
        total_suggestion=$((total_suggestion + s))
    done < "$HISTORY_FILE"

    echo "审查次数: ${total}"
    echo ""
    echo "累计发现:"
    echo "  Critical:   ${RED}${total_critical}${NC}"
    echo "  Warning:    ${YELLOW}${total_warning}${NC}"
    echo "  Suggestion: ${CYAN}${total_suggestion}${NC}"
    echo ""

    # 最近的趋势
    if [[ $total -ge 2 ]]; then
        local last=$(tail -1 "$HISTORY_FILE")
        local last_critical=$(printf '%s\n' "$last" | grep -o '"critical":[0-9]*' | cut -d: -f2)

        echo "最近审查: ${last_critical} Critical"

        if [[ $last_critical -eq 0 ]]; then
            echo -e "${GREEN}✅ 最近审查无严重问题${NC}"
        fi
    fi
}

# 主逻辑
case "$COMMAND" in
    save)
        save_review
        ;;
    list)
        list_reviews
        ;;
    show)
        show_review
        ;;
    diff)
        diff_reviews
        ;;
    stats)
        show_stats
        ;;
    *)
        echo "用法: ./review-history.sh [list|show|diff|stats|save]"
        echo ""
        echo "  list  - 列出所有审查记录"
        echo "  show  - 显示单条记录详情"
        echo "  diff  - 对比最近两次审查"
        echo "  stats - 统计报告"
        echo "  save  - 从 stdin 保存审查结果"
        ;;
esac
