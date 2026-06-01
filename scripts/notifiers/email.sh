#!/bin/bash
# 邮件通知
# 用法: ./email.sh --to "user@example.com" --subject "标题" --content "内容" [--smtp host:port] [--user username] [--pass password]

TO=""
SUBJECT=""
CONTENT=""
SMTP_HOST="${SMTP_HOST:-smtp.gmail.com}"
SMTP_PORT="${SMTP_PORT:-587}"
SMTP_USER="${SMTP_USER:-}"
SMTP_PASS="${SMTP_PASS:-}"

while [[ $# -gt 0 ]]; do
    case $1 in
        --to) TO="$2"; shift 2 ;;
        --subject) SUBJECT="$2"; shift 2 ;;
        --content) CONTENT="$2"; shift 2 ;;
        --smtp)
            SMTP_HOST=$(echo "$2" | cut -d: -f1)
            SMTP_PORT=$(echo "$2" | cut -d: -f2)
            shift 2 ;;
        --user) SMTP_USER="$2"; shift 2 ;;
        --pass) SMTP_PASS="$2"; shift 2 ;;
        *) shift ;;
    esac
done

[[ -z "$TO" ]] && { echo "缺少收件人邮箱 (--to)"; exit 1; }

# 尝试使用 sendmail
if command -v sendmail > /dev/null 2>&1; then
    {
        echo "To: $TO"
        echo "Subject: $SUBJECT"
        echo "Content-Type: text/plain; charset=UTF-8"
        echo ""
        echo "$CONTENT"
    } | sendmail "$TO"
    echo "✓ 邮件已发送 (sendmail)"
    exit 0
fi

# 尝试使用 Python + smtplib
if command -v python3 > /dev/null 2>&1; then
    python3 << EOF
import smtplib, os
from email.mime.text import MIMEText

msg = MIMEText("""$CONTENT""", 'plain', 'utf-8')
msg['Subject'] = "$SUBJECT"
msg['To'] = "$TO"
msg['From'] = os.environ.get('SMTP_USER', 'code-review@localhost')

try:
    server = smtplib.SMTP('${SMTP_HOST}', ${SMTP_PORT})
    server.starttls()
    if '${SMTP_USER}' and '${SMTP_PASS}':
        server.login('${SMTP_USER}', '${SMTP_PASS}')
    server.send_message(msg)
    server.quit()
    print("✓ 邮件已发送 (Python SMTP)")
except Exception as e:
    print(f"✗ 邮件发送失败: {e}")
EOF
    exit 0
fi

# 尝试使用 mail 命令
if command -v mail > /dev/null 2>&1; then
    echo "$CONTENT" | mail -s "$SUBJECT" "$TO"
    echo "✓ 邮件已发送 (mail)"
    exit 0
fi

echo "✗ 未找到邮件发送工具 (sendmail/python3/mail)"
exit 1
