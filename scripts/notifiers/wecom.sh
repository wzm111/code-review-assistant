#!/bin/bash
# 企业微信机器人通知
# 用法: ./wecom.sh --webhook "https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=xxx" --title "标题" --content "内容"

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

# 截断（企业微信限制 4096）
FULL_CONTENT="### ${TITLE}\n\n${CONTENT}"
TRUNCATED="${FULL_CONTENT:0:4000}"
[[ ${#FULL_CONTENT} -gt 4000 ]] && TRUNCATED="${TRUNCATED}...\n\n(内容已截断)"

# markdown 格式
curl -s -X POST "$WEBHOOK" \
    -H 'Content-Type: application/json' \
    -d "{
        \"msgtype\": \"markdown\",
        \"markdown\": {
            \"content\": \"${TRUNCATED}\"
        }
    }" > /dev/null

echo "✓ 企业微信通知已发送"
