#!/bin/bash
# LINE Notify 通知
# 用法: ./line.sh --token "xxx" --title "标题" --content "内容"

TOKEN="${LINE_NOTIFY_TOKEN:-}"
TITLE=""
CONTENT=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --token) TOKEN="$2"; shift 2 ;;
        --title) TITLE="$2"; shift 2 ;;
        --content) CONTENT="$2"; shift 2 ;;
        *) shift ;;
    esac
done

[[ -z "$TOKEN" ]] && { echo "缺少 LINE Notify Token (--token 或环境变量 LINE_NOTIFY_TOKEN)"; exit 1; }

MESSAGE="${TITLE}\n\n${CONTENT}"
TRUNCATED="${MESSAGE:0:950}"

curl -s -X POST https://notify-api.line.me/api/notify \
    -H "Authorization: Bearer ${TOKEN}" \
    -F "message=${TRUNCATED}" > /dev/null

echo "✓ LINE 通知已发送"
