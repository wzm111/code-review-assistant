#!/bin/bash
# Slack Webhook 通知
# 用法: ./slack.sh --webhook "https://hooks.slack.com/services/xxx" --title "标题" --content "内容"

WEBHOOK=""
TITLE=""
CONTENT=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --webhook) WEBHOOK="$2"; shift 2 ;;
        --title) TITLE="$2"; shift 2 ;;
        --content) CONTENT="$2"; shift 2 ;;
        *) shift ;;
    esac
done

[[ -z "$WEBHOOK" ]] && { echo "缺少 webhook"; exit 1; }

# 截断
TEXT="*${TITLE}*\n\n${CONTENT}"
TRUNCATED="${TEXT:0:3500}"

curl -s -X POST "$WEBHOOK" \
    -H 'Content-Type: application/json' \
    -d "{
        \"text\": \"${TRUNCATED}\",
        \"mrkdwn\": true
    }" > /dev/null

echo "✓ Slack 通知已发送"
