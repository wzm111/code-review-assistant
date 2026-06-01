#!/bin/bash
# 钉钉机器人通知
# 用法: ./dingtalk.sh --webhook "https://oapi.dingtalk.com/robot/send?access_token=xxx" --title "标题" --content "内容"

WEBHOOK=""
TITLE=""
CONTENT=""
SECRET=""  # 可选：加签密钥

while [[ $# -gt 0 ]]; do
    case $1 in
        --webhook) WEBHOOK="$2"; shift 2 ;;
        --title) TITLE="$2"; shift 2 ;;
        --content) CONTENT="$2"; shift 2 ;;
        --secret) SECRET="$2"; shift 2 ;;
        *) shift ;;
    esac
done

[[ -z "$WEBHOOK" ]] && { echo "缺少 webhook"; exit 1; }

# 加签
if [[ -n "$SECRET" ]]; then
    timestamp=$(date +%s000)
    sign=$(echo -n "${timestamp}\n${SECRET}" | openssl dgst -sha256 -hmac "${SECRET}" -binary | base64 | tr '+/' '-_' | tr -d '=')
    WEBHOOK="${WEBHOOK}&timestamp=${timestamp}&sign=${sign}"
fi

# 截断
CONTENT_TRUNCATED="${CONTENT:0:15000}"

# 发送 markdown 消息
curl -s -X POST "$WEBHOOK" \
    -H 'Content-Type: application/json' \
    -d "{
        \"msgtype\": \"markdown\",
        \"markdown\": {
            \"title\": \"${TITLE}\",
            \"text\": \"### ${TITLE}\n${CONTENT_TRUNCATED}\"
        }
    }" > /dev/null

echo "✓ 钉钉通知已发送"
