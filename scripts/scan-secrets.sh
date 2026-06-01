#!/bin/bash
# 安全密钥扫描脚本
# 扫描代码中的硬编码密钥、Token、密码等敏感信息

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

TARGET_DIR="${1:-.}"
SEVERITY="${2:-all}"  # all, critical, high
FOUND=0

echo -e "${CYAN}🔐 Security Secret Scanner / 安全密钥扫描${NC}"
echo "=========================================="
echo ""

# 定义扫描规则
# 格式: 名称|正则表达式|严重级别
declare -a RULES=(
    # Critical - 必须立即处理
    "AWS Access Key|AKIA[0-9A-Z]{16}|critical"
    "AWS Secret Key|[0-9a-zA-Z/+]{40}|critical"
    "GitHub Token|ghp_[0-9a-zA-Z]{36}|critical"
    "GitHub OAuth|gho_[0-9a-zA-Z]{36}|critical"
    "Slack Token|xox[baprs]-[0-9a-zA-Z]{10,48}|critical"
    "OpenAI API Key|sk-[0-9a-zA-Z]{48}|critical"
    "Google API Key|AIza[0-9a-zA-Z_-]{35}|critical"
    "Private Key|-----BEGIN (RSA |DSA |EC |OPENSSH )?PRIVATE KEY-----|critical"
    "Password Assignment|password\s*=\s*['\"][^'\"]{8,}['\"]|critical"
    "DB Connection String|mongodb(\+srv)?://[^\s\"']+:[^\s\"']+@|critical"
    "DB Password|jdbc:[^;]*password=[^&;\s]+|critical"

    # High - 高风险
    "JWT Token|eyJ[a-zA-Z0-9_-]*\.eyJ[a-zA-Z0-9_-]*\.[a-zA-Z0-9_-]*|high"
    "Basic Auth|Basic\s+[a-zA-Z0-9+/]{20,}=?|high"
    "Bearer Token|Bearer\s+[a-zA-Z0-9_\-\.]{20,}|high"
    "API Key Pattern|api[_-]?key\s*[:=]\s*['\"][a-zA-Z0-9]{16,}['\"]|high"
    "Secret Pattern|secret[_-]?key\s*[:=]\s*['\"][a-zA-Z0-9]{16,}['\"]|high"
    "Token Pattern|token\s*[:=]\s*['\"][a-zA-Z0-9]{20,}['\"]|high"
    "Firebase URL|https://[a-z0-9-]+\.firebaseio\.com|high"
    "Heroku API Key|[hH]eroku.*[a-zA-Z0-9]{32,}|high"
    "Mailgun API Key|key-[0-9a-zA-Z]{32}|high"
    "Stripe Key|sk_live_[0-9a-zA-Z]{24,}|high"
    "PayPal Token|access_token\$production\$[0-9a-z]{16}\$[0-9a-f]{32}|high"

    # Medium - 中风险
    "IP Address|\b(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b|medium"
    "Email in Code|[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}|medium"
    "TODO with Secret|TODO.*(?:password|secret|key|token)|medium"
    "Console Log with Data|console\.(log|warn|error)\(.*(?:password|secret|token|key)|medium"
)

# 排除的文件/目录
EXCLUDE_PATTERN='\.(git|svn|hg)|node_modules/|vendor/|\.min\.(js|css)|\.map$|dist/|build/|target/|__pycache__/|\.pyc$|\.egg-info/|\.tox/|\.venv/|venv/|env/'

# 分类统计
critical_count=0
high_count=0
medium_count=0

echo -e "${YELLOW}扫描目录: ${TARGET_DIR}${NC}"
echo -e "${YELLOW}严重级别: ${SEVERITY}${NC}"
echo ""

# 执行扫描
for rule in "${RULES[@]}"; do
    IFS='|' read -r name pattern level <<< "$rule"

    # 根据严重级别过滤
    if [[ "$SEVERITY" != "all" && "$level" != "$SEVERITY" && "$level" != "critical" ]]; then
        continue
    fi

    # 扫描文件（排除常见非源码文件以减少误报）
    matches=$(grep -rEn "$pattern" "$TARGET_DIR" \
        --exclude-dir={.git,node_modules,vendor,dist,build,target,__pycache__,.venv,venv,env,public} \
        --exclude='*.min.js' --exclude='*.min.css' --exclude='*.map' \
        --exclude='*-[A-Za-z0-9]*.js' --exclude='*-[A-Za-z0-9]*.css' \
        --exclude='*.pyc' --exclude='*.egg-info' \
        --exclude='package-lock.json' --exclude='yarn.lock' --exclude='pnpm-lock.yaml' \
        --exclude='CHANGELOG*' --exclude='LICENSE*' --exclude='AUTHORS*' \
        --exclude='*.md' --exclude='*.txt' --exclude='*.log' \
        2>/dev/null || true)

    if [[ -n "$matches" ]]; then
        # 先计算匹配数量
        count=$(printf '%s\n' "$matches" | wc -l | tr -d ' ')

        case "$level" in
            critical) color="${RED}" icon="🔴" ; critical_count=$((critical_count + count)) ;;
            high) color="${YELLOW}" icon="🟠" ; high_count=$((high_count + count)) ;;
            medium) color="${CYAN}" icon="🟡" ; medium_count=$((medium_count + count)) ;;
        esac

        level_upper=$(printf '%s\n' "$level" | tr '[:lower:]' '[:upper:]')
        echo -e "${color}${icon} [${level_upper}] ${name}${NC}"
        printf '%s\n' "$matches" | head -5 | while read -r line; do
            file=$(printf '%s\n' "$line" | cut -d: -f1)
            lineno=$(printf '%s\n' "$line" | cut -d: -f2)
            content=$(printf '%s\n' "$line" | cut -d: -f3-)
            # 脱敏显示：保留前4个可见字符，其余用 **** 替换
            # 匹配密钥值（等号/冒号/引号后的内容）
            masked="$content"
            # 策略1: key="value" 或 key='value' 形式 → 保留前4字符
            masked=$(printf '%s\n' "$masked" | perl -pe 's/((?:api[_-]?key|secret[_-]?key|token|password)\s*[:=]\s*["\x27])([a-zA-Z0-9_\-\/+]{4})[a-zA-Z0-9_\-\/+=]{4,}/${1}${2}****/gi' 2>/dev/null || echo "$masked")
            # 策略2: Bearer / Basic Token
            masked=$(printf '%s\n' "$masked" | perl -pe 's/((?:Bearer|Basic)\s+)([a-zA-Z0-9_\-\.\/+=]{4})[a-zA-Z0-9_\-\.\/+=]{4,}/${1}${2}****/g' 2>/dev/null || echo "$masked")
            # 策略3: URL 中的密码 → mongodb://user:pass@host
            masked=$(printf '%s\n' "$masked" | perl -pe 's/(:\/\/[^:]*:)([a-zA-Z0-9_\-]{2})[a-zA-Z0-9_\-]{2,}(@)/${1}${2}****${3}/g' 2>/dev/null || echo "$masked")
            # 策略4: 通用长字符串脱敏（AWS Key、GitHub Token 等）
            masked=$(printf '%s\n' "$masked" | perl -pe 's/([a-zA-Z0-9]{4})[a-zA-Z0-9\/+]{10,}/${1}****/g' 2>/dev/null || echo "$masked")
            # 截断超长行（构建产物的 minified 代码可能一行很长）
            if [[ "${#masked}" -gt 120 ]]; then
                masked="${masked:0:120} …（已截断，共 ${#masked} 字符）"
            fi
            echo "   ${file}:${lineno}: ${masked}"
        done

        if [[ $count -gt 5 ]]; then
            echo "   ... 共 ${count} 处"
        fi
        echo ""

        FOUND=$((FOUND + count))
    fi
done

# 额外检查：.env 文件是否被提交
echo -e "${CYAN}【检查 .env 文件】${NC}"

# 高风险的 .env 文件（不应提交）
env_sensitive=$(find "$TARGET_DIR" -maxdepth 3 \( -name ".env" -o -name ".env.local" -o -name ".env.*.local" \) -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null || true)

# 环境配置文件（可能是前端项目的合法配置）
env_config=$(find "$TARGET_DIR" -maxdepth 3 \( -name ".env.production" -o -name ".env.development" -o -name ".env.staging" -o -name ".env.test" -o -name ".env.preview" \) -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null || true)

env_risk_count=0

# 统一输出 .env 检查结果
if [[ -z "$env_sensitive" && -z "$env_config" ]]; then
    echo -e "${GREEN}✓ 未发现已提交的 .env 文件${NC}"
else
    # 敏感文件（必须处理）
    if [[ -n "$env_sensitive" ]]; then
        echo -e "${RED}🔴 敏感 .env 文件（不应提交，请添加到 .gitignore）:${NC}"
        printf '%s\n' "$env_sensitive" | while read -r f; do
            [[ -z "$f" ]] && continue
            printf '   %b•%b %s\n' "$RED" "$NC" "$f"
        done
        env_risk_count=$(printf '%s\n' "$env_sensitive" | grep -v '^$' | wc -l | tr -d ' ')
        FOUND=$((FOUND + env_risk_count))
    fi

    # 可提交的配置文件（需确认不含密钥）
    if [[ -n "$env_config" ]]; then
        echo -e "${YELLOW}ℹ️  环境配置文件（可提交，但请确认不含密钥）:${NC}"
        printf '%s\n' "$env_config" | while read -r f; do
            [[ -z "$f" ]] && continue
            printf '   %b•%b %s\n' "$YELLOW" "$NC" "$f"
        done
    fi
fi
echo ""

# 检查结果
echo -e "${CYAN}【风险分类汇总】${NC}"
echo "  🔴 Critical (严重): ${critical_count} 处 — 必须立即处理（密钥、密码、Token 等）"
echo "  🟠 High (高风险):   ${high_count} 处 — 建议尽快处理（JWT、API Key 等）"
echo "  🟡 Medium (中风险): ${medium_count} 处 — 注意排查（IP、邮箱、TODO 等）"
if [[ $env_risk_count -gt 0 ]]; then
    echo "  🟠 .env 文件:       ${env_risk_count} 处 — 检查是否含敏感配置"
fi
echo ""

if [[ $FOUND -eq 0 ]]; then
    echo -e "${GREEN}✅ 未发现敏感信息泄露${NC}"
    exit 0
else
    echo -e "${RED}⚠️ 共发现 ${FOUND} 处潜在安全风险${NC}"
    echo -e "${YELLOW}建议立即处理 Critical 级别问题${NC}"
    exit 1
fi
