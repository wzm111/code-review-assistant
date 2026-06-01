#!/bin/bash
# WhatsApp 通知 (通过 Twilio API)
# 用法: ./whatsapp.sh --sid "ACxxx" --token "xxx" --from "+1234567890" --to "+8613800138000" --title "标题" --content "内容"

TWILIO_SID="${TWILIO_SID:-}"
TWILIO_TOKEN="${TWILIO_TOKEN:-}"
FROM="${WHATSAPP_FROM:-}"  # Twilio WhatsApp 号码，格式: whatsapp:+1234567890
TO=""
TITLE=""
CONTENT=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --sid) TWILIO_SID="$2"; shift 2 ;;
        --token) TWILIO_TOKEN="$2"; shift 2 ;;
        --from) FROM="$2"; shift 2 ;;
        --to) TO="$2"; shift 2 ;;
        --title) TITLE="$2"; shift 2 ;;
        --content) CONTENT="$2"; shift 2 ;;
        *) shift ;;
    esac
done

[[ -z "$TWILIO_SID" ]] && { echo "缺少 Twilio SID"; exit 1; }
[[ -z "$TWILIO_TOKEN" ]] && { echo "缺少 Twilio Token"; exit 1; }
[[ -z "$FROM" ]] && { echo "缺少发件号码 (--from 或 WHATSAPP_FROM)"; exit 1; }
[[ -z "$TO" ]] && { echo "缺少收件号码 (--to)"; exit 1; }

# 确保号码格式正确
[[ ! "$FROM" =~ ^whatsapp: ]] && FROM="whatsapp:${FROM}"
[[ ! "$TO" =~ ^whatsapp: ]] && TO="whatsapp:${TO}"

MESSAGE="${TITLE}\n\n${CONTENT}"
TRUNCATED="${MESSAGE:0:1500}"

curl -s -X POST "https://api.twilio.com/2010-04-01/Accounts/${TWILIO_SID}/Messages.json" \
    --user "${TWILIO_SID}:${TWILIO_TOKEN}" \
    -d "From=${FROM}" \
    -d "To=${TO}" \
    -d "Body=${TRUNCATED}" > /dev/null

echo "✓ WhatsApp 通知已发送"
