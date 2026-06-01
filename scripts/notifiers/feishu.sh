#!/bin/bash
# 飞书机器人通知
# 用法: ./feishu.sh --webhook "https://open.feishu.cn/open-apis/bot/v2/hook/xxx" --title "标题" --content "内容"

WEBHOOK=""
TITLE=""
CONTENT=""
SIGN=""  # 可选：签名密钥（开启安全设置时）

while [[ $# -gt 0 ]]; do
    case $1 in
        --webhook) WEBHOOK="$2"; shift 2 ;;
        --title) TITLE="$2"; shift 2 ;;
        --content) CONTENT="$2"; shift 2 ;;
        --sign) SIGN="$2"; shift 2 ;;
        *) shift ;;
    esac
done

[[ -z "$WEBHOOK" ]] && { echo "缺少 webhook"; exit 1; }

# 生成签名（如果配置了）
timestamp=$(date +%s)
if [[ -n "$SIGN" ]]; then
    sign=$(echo -n "${timestamp}\n${SIGN}" | openssl dgst -sha256 -hmac "${SIGN}" -binary | base64)
    SIGN_JSON=",\"sign\":\"${sign}\""
else
    SIGN_JSON=""
fi

# 截断内容（飞书限制 4096）
CONTENT_TRUNCATED="${CONTENT:0:4000}"
[[ ${#CONTENT} -gt 4000 ]] && CONTENT_TRUNCATED="${CONTENT_TRUNCATED}...\n\n(内容已截断，完整内容请查看日志)"

# 构建消息
curl -s -X POST "$WEBHOOK" \
    -H 'Content-Type: application/json' \
    -d "{
        \"msg_type\": \"interactive\",
        \"timestamp\": \"${timestamp}\"${SIGN_JSON},
        \"card\": {
            \"header\": {
                \"title\": {
                    \"tag\": \"plain_text\",
                    \"content\": \"${TITLE}\"
                },
                \"template\": \"red\"
            },
            \"elements\": [
                {
                    \"tag\": \"div\",
                    \"text\": {
                        \"tag\": \"lark_md\",
                        \"content\": \"${CONTENT_TRUNCATED}\"
                    }
                }
            ]
        }
    }" > /dev/null

echo "✓ 飞书通知已发送"
