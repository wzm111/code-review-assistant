#!/bin/bash
# Telegram Bot 通知
# 用法: ./telegram.sh --token "botxxx:yyy" --chat "-123456789" --title "标题" --content "内容"

TOKEN="${TELEGRAM_BOT_TOKEN:-}"
CHAT_ID="${TELEGRAM_CHAT_ID:-}"
TITLE=""
CONTENT=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --token) TOKEN="$2"; shift 2 ;;
        --chat) CHAT_ID="$2"; shift 2 ;;
        --title) TITLE="$2"; shift 2 ;;
        --content) CONTENT="$2"; shift 2 ;;
        *) shift ;;
    esac
done

[[ -z "$TOKEN" ]] && { echo "缺少 Bot Token (--token 或 TELEGRAM_BOT_TOKEN)"; exit 1; }
[[ -z "$CHAT_ID" ]] && { echo "缺少 Chat ID (--chat 或 TELEGRAM_CHAT_ID)"; exit 1; }

MESSAGE="*${TITLE}*\n\n${CONTENT}"
TRUNCATED="${MESSAGE:0:4000}"

curl -s -X POST "https://api.telegram.org/${TOKEN}/sendMessage" \
    -H 'Content-Type: application/json' \
    -d "{
        \"chat_id\": \"${CHAT_ID}\",
        \"text\": \"${TRUNCATED}\",
        \"parse_mode\": \"Markdown\",
        \"disable_web_page_preview\": true
    }" > /dev/null

echo "✓ Telegram 通知已发送"
