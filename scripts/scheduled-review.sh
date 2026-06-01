#!/bin/bash
# Code Review Assistant - 智能定时审查脚本
# 用法: ./scheduled-review.sh [选项]
# 零配置即可运行，所有参数均可通过命令行指定

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 默认值（零配置即可运行）
DEFAULT_TIME="09:00"
DEFAULT_DAYS="1,2,3,4,5"  # 周一至周五
DEFAULT_DEPTH="standard"
DEFAULT_FORMAT="markdown"

# 解析参数
TIME=""
DAYS=""
DEPTH=""
REPO_PATH=""
FORCE=false
INSTALL=false
UNINSTALL=false
STATUS=false
NOW=false
LIST=false
VERBOSE=false

# 通知渠道
NOTIFY=""
WEBHOOK=""
EMAIL_TO=""

# 增强审查选项
SCAN_SECRETS=false
SCAN_DEPS=false
IMPACT=false
CONTEXT=false
SAVE_HISTORY=false
COMPLEXITY=false
LINT=false
COMMIT_LINT=false
REVIEWER=false
EXPORT=false
EXPORT_FORMAT="markdown"

# 第三批扩展选项
TEST_COVERAGE=false
API_CONTRACT=false
BUNDLE_SIZE=false
DB_MIGRATION=false
I18N_CHECK=false
PII_SCAN=false
FEATURE_FLAG=false
CODEOWNERS_CHECK=false
LICENSE_CHECK=false
PERF_BENCHMARK=false
CHANGELOG_GEN=false
CONCURRENCY_CHECK=false

# 第四批扩展选项
REUSE_CHECK=false

# 第五批扩展选项
ERROR_HANDLING=false
RESOURCE_LEAK=false
TYPE_SAFETY=false
ARCHITECTURE=false
TEST_QUALITY=false
CODE_SMELL=false
DOC_QUALITY=false
A11Y_CHECK=false
CONFIG_DRIFT=false
SUPPLY_CHAIN=false
NAMING_CONVENTION=false

# 严重级别过滤
SEVERITY="all"  # all | critical | high | medium

show_help() {
    cat << 'EOF'
Code Review Assistant - 定时审查脚本

用法:
  ./scheduled-review.sh [选项]

零配置模式:
  ./scheduled-review.sh              使用默认设置立即执行一次审查

常用选项:
  -t, --time TIME         设置执行时间 (默认: 09:00)
  -d, --days DAYS         设置执行日期 (默认: 1,2,3,4,5 周一至周五)
                          格式: 1,3,5 或 1-5 或 all
  --depth DEPTH           审查深度: quick | standard | deep (默认: standard)
  --severity LEVEL        严重级别过滤: all | critical | high | medium
                          critical=只执行5星检查 high=4星+5星 medium=3星+
  -p, --path PATH         指定仓库路径 (默认: 当前目录)
  -f, --force             强制执行，忽略时间检查
  -n, --now               立即执行一次审查

定时任务管理:
  -i, --install           安装到系统 crontab
  -u, --uninstall         从 crontab 卸载
  -s, --status            查看定时任务状态
  -l, --list              列出所有已安装的审查任务

通知选项:
  --notify CHANNEL        通知渠道: feishu, dingtalk, wecom, slack,
                          line, whatsapp, telegram, email
  --webhook URL           Webhook URL (飞书/钉钉/企微/Slack)
  --to ADDRESS            收件地址 (邮件/WhatsApp)

环境变量 (配置通知凭证):
  FEISHU_WEBHOOK, DINGTALK_WEBHOOK, WECOM_WEBHOOK, SLACK_WEBHOOK,
  LINE_NOTIFY_TOKEN, TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID,
  TWILIO_SID, TWILIO_TOKEN, WHATSAPP_FROM,
  SMTP_USER, SMTP_PASS

示例:
  # 立即审查当前目录
  ./scheduled-review.sh --now

增强审查选项:
  --scan-secrets          扫描硬编码密钥和敏感信息
  --scan-deps             扫描依赖漏洞
  --impact                执行变更影响分析
  --context               读取 PR 上下文信息
  --history               保存审查历史记录
  --complexity            代码复杂度分析
  --lint                  代码规范检查
  --commit-lint           提交信息规范检查
  --reviewer              自动推荐 Reviewer
  --export [FORMAT]       导出报告 (markdown/html)

扩展审查选项:
  --test-coverage         测试覆盖率分析
  --api-contract          API 契约变更检测
  --bundle-size           Bundle 体积分析
  --db-migration          数据库迁移安全审查
  --i18n                  国际化完整性检查
  --pii                   PII 敏感信息扫描
  --feature-flag          Feature Flag 清理检测
  --codeowners            CODEOWNERS 匹配检查
  --license               许可证合规检查
  --perf                  性能基准回归分析
  --changelog             Changelog 自动生成
  --concurrency           并发安全深度检测
  --reuse                 代码复用性检查

深度审查选项:
  --error-handling        错误处理完整性检查
  --resource-leak         资源泄露扫描
  --type-safety           类型安全深度检查 (TypeScript)
  --architecture          架构合规检查 (分层/依赖方向)
  --test-quality          测试质量检查 (脆弱测试/边界)
  --code-smell            代码异味检测 (上帝类/长函数)
  --doc-quality           注释/文档质量检查
  --a11y                  无障碍检查 (ARIA/键盘导航)
  --config-drift          配置漂移检测
  --supply-chain          供应链安全扫描
  --naming                命名规范检查

示例:
  # 立即审查当前目录
  ./scheduled-review.sh --now

  # 全面审查（安全扫描 + 依赖检查 + 影响分析）
  ./scheduled-review.sh --now --scan-secrets --scan-deps --impact

  # 审查并通知到飞书
  ./scheduled-review.sh --now --notify feishu

  # 审查并通过邮件发送
  ./scheduled-review.sh --now --notify email --to "team@example.com"

  # 安装定时任务 + 自动推送到钉钉
  ./scheduled-review.sh --install --time 09:00 --notify dingtalk
EOF
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--time)
            TIME="$2"
            shift 2
            ;;
        -d|--days)
            DAYS="$2"
            shift 2
            ;;
        --depth)
            DEPTH="$2"
            shift 2
            ;;
        -p|--path)
            REPO_PATH="$2"
            shift 2
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -n|--now)
            NOW=true
            shift
            ;;
        -i|--install)
            INSTALL=true
            shift
            ;;
        -u|--uninstall)
            UNINSTALL=true
            shift
            ;;
        -s|--status)
            STATUS=true
            shift
            ;;
        -l|--list)
            LIST=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --notify)
            NOTIFY="$2"
            shift 2
            ;;
        --webhook)
            WEBHOOK="$2"
            shift 2
            ;;
        --to)
            EMAIL_TO="$2"
            shift 2
            ;;
        --scan-secrets)
            SCAN_SECRETS=true
            shift
            ;;
        --scan-deps)
            SCAN_DEPS=true
            shift
            ;;
        --impact)
            IMPACT=true
            shift
            ;;
        --context)
            CONTEXT=true
            shift
            ;;
        --history)
            SAVE_HISTORY=true
            shift
            ;;
        --complexity)
            COMPLEXITY=true
            shift
            ;;
        --lint)
            LINT=true
            shift
            ;;
        --commit-lint)
            COMMIT_LINT=true
            shift
            ;;
        --reviewer)
            REVIEWER=true
            shift
            ;;
        --export)
            EXPORT=true
            if [[ -n "${2:-}" && ! "$2" =~ ^-- ]]; then
                EXPORT_FORMAT="$2"
                shift 2
            else
                shift
            fi
            ;;
        --test-coverage)
            TEST_COVERAGE=true
            shift
            ;;
        --api-contract)
            API_CONTRACT=true
            shift
            ;;
        --bundle-size)
            BUNDLE_SIZE=true
            shift
            ;;
        --db-migration)
            DB_MIGRATION=true
            shift
            ;;
        --i18n)
            I18N_CHECK=true
            shift
            ;;
        --pii)
            PII_SCAN=true
            shift
            ;;
        --feature-flag)
            FEATURE_FLAG=true
            shift
            ;;
        --codeowners)
            CODEOWNERS_CHECK=true
            shift
            ;;
        --license)
            LICENSE_CHECK=true
            shift
            ;;
        --perf)
            PERF_BENCHMARK=true
            shift
            ;;
        --changelog)
            CHANGELOG_GEN=true
            shift
            ;;
        --concurrency)
            CONCURRENCY_CHECK=true
            shift
            ;;
        --reuse)
            REUSE_CHECK=true
            shift
            ;;
        --error-handling)
            ERROR_HANDLING=true
            shift
            ;;
        --resource-leak)
            RESOURCE_LEAK=true
            shift
            ;;
        --type-safety)
            TYPE_SAFETY=true
            shift
            ;;
        --architecture)
            ARCHITECTURE=true
            shift
            ;;
        --test-quality)
            TEST_QUALITY=true
            shift
            ;;
        --code-smell)
            CODE_SMELL=true
            shift
            ;;
        --doc-quality)
            DOC_QUALITY=true
            shift
            ;;
        --a11y)
            A11Y_CHECK=true
            shift
            ;;
        --config-drift)
            CONFIG_DRIFT=true
            shift
            ;;
        --supply-chain)
            SUPPLY_CHAIN=true
            shift
            ;;
        --naming)
            NAMING_CONVENTION=true
            shift
            ;;
        --severity)
            SEVERITY="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}未知选项: $1${NC}"
            echo "使用 --help 查看帮助"
            exit 1
            ;;
    esac
done

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SCRIPT_NAME="$(basename "$0")"
FULL_SCRIPT_PATH="${SCRIPT_DIR}/${SCRIPT_NAME}"

# 如果指定了仓库路径
if [[ -n "$REPO_PATH" ]]; then
    REVIEW_DIR="$(cd "$REPO_PATH" 2>/dev/null || echo "$REPO_PATH")"
else
    REVIEW_DIR="$(pwd)"
fi

# 使用默认值
TIME="${TIME:-$DEFAULT_TIME}"
DAYS="${DAYS:-$DEFAULT_DAYS}"
DEPTH="${DEPTH:-$DEFAULT_DEPTH}"

# 转换 days 格式
parse_days() {
    local input="$1"
    if [[ "$input" == "all" ]]; then
        echo "0,1,2,3,4,5,6"
    elif [[ "$input" =~ ^[0-6]-[0-6]$ ]]; then
        local start=${input%-*}
        local end=${input#*-}
        local result=""
        for ((i=start; i<=end; i++)); do
            result="${result}${i},"
        done
        echo "${result%,}"
    else
        echo "$input"
    fi
}

DAYS_PARSED=$(parse_days "$DAYS")

# ========== 功能函数 ==========

log() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${BLUE}[$(date '+%H:%M:%S')] $1${NC}"
    fi
}

print_header() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     Code Review Assistant - 代码审查助手                  ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_config() {
    echo -e "${YELLOW}当前配置:${NC}"
    echo "  执行时间: ${GREEN}${TIME}${NC}"
    echo "  执行日期: ${GREEN}${DAYS_PARSED}${NC} (0=周日, 1=周一, ...)"
    echo "  审查深度: ${GREEN}${DEPTH}${NC}"
    echo "  目标目录: ${GREEN}${REVIEW_DIR}${NC}"
    echo ""
}

# 严重级别映射：自动启用对应优先级的检查
apply_severity() {
    case "$SEVERITY" in
        critical)
            # 只执行 ★★★★★ (Critical) 级别检查
            SCAN_SECRETS=true
            SCAN_DEPS=true
            PII_SCAN=true
            CONCURRENCY_CHECK=true
            ERROR_HANDLING=true
            RESOURCE_LEAK=true
            echo -e "${YELLOW}严重级别: Critical (仅执行 5星 关键检查)${NC}"
            ;;
        high)
            # 执行 ★★★★★ + ★★★★☆
            SCAN_SECRETS=true
            SCAN_DEPS=true
            PII_SCAN=true
            CONCURRENCY_CHECK=true
            ERROR_HANDLING=true
            RESOURCE_LEAK=true
            LINT=true
            CODE_SMELL=true
            TYPE_SAFETY=true
            ARCHITECTURE=true
            NAMING_CONVENTION=true
            CONFIG_DRIFT=true
            echo -e "${YELLOW}严重级别: High (执行 4星 + 5星 检查)${NC}"
            ;;
        medium)
            # 执行 ★★★★★ + ★★★★☆ + ★★★☆☆
            SCAN_SECRETS=true
            SCAN_DEPS=true
            PII_SCAN=true
            CONCURRENCY_CHECK=true
            ERROR_HANDLING=true
            RESOURCE_LEAK=true
            LINT=true
            CODE_SMELL=true
            TYPE_SAFETY=true
            ARCHITECTURE=true
            NAMING_CONVENTION=true
            CONFIG_DRIFT=true
            TEST_QUALITY=true
            TEST_COVERAGE=true
            IMPACT=true
            REUSE_CHECK=true
            DB_MIGRATION=true
            API_CONTRACT=true
            SUPPLY_CHAIN=true
            echo -e "${YELLOW}严重级别: Medium (执行 3星 + 4星 + 5星 检查)${NC}"
            ;;
        all|*)
            # 默认：执行所有已启用的检查（保持用户显式指定的）
            ;;
    esac
}

# 执行审查
do_review() {
    print_header
    print_config

    # 应用严重级别过滤
    apply_severity

    log "检查目标目录..."

    # 检查目录
    if [[ ! -d "$REVIEW_DIR" ]]; then
        echo -e "${RED}错误: 目录不存在: ${REVIEW_DIR}${NC}"
        exit 1
    fi

    cd "$REVIEW_DIR"

    # 检查 git
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo -e "${RED}错误: ${REVIEW_DIR} 不是 git 仓库${NC}"
        echo "提示: 使用 --path 指定正确的仓库路径"
        exit 1
    fi

    log "获取代码变更..."

    # ====== 增强扫描 ======

    # 1. 安全密钥扫描
    if [[ "$SCAN_SECRETS" == true ]]; then
        echo ""
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        "${SCRIPT_DIR}/scan-secrets.sh" "$REVIEW_DIR" || true
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo ""
    fi

    # 2. 依赖漏洞扫描
    if [[ "$SCAN_DEPS" == true ]]; then
        echo ""
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        "${SCRIPT_DIR}/scan-deps.sh" "$REVIEW_DIR" || true
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo ""
    fi

    # 3. PR 上下文读取
    if [[ "$CONTEXT" == true ]]; then
        echo ""
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        "${SCRIPT_DIR}/pr-context.sh" "$REVIEW_DIR" || true
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo ""
    fi

    # 4. 变更影响分析
    if [[ "$IMPACT" == true ]]; then
        echo ""
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        "${SCRIPT_DIR}/impact-analysis.sh" "$REVIEW_DIR" || true
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo ""
    fi

    # 5. 代码复杂度分析
    if [[ "$COMPLEXITY" == true ]]; then
        echo ""
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        "${SCRIPT_DIR}/complexity-analysis.sh" "$REVIEW_DIR" "$DEPTH" || true
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo ""
    fi

    # 6. 代码规范检查
    if [[ "$LINT" == true ]]; then
        echo ""
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        "${SCRIPT_DIR}/lint-check.sh" "$REVIEW_DIR" || true
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo ""
    fi

    # 7. 提交规范检查
    if [[ "$COMMIT_LINT" == true ]]; then
        echo ""
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        "${SCRIPT_DIR}/commit-lint.sh" "$REVIEW_DIR" || true
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo ""
    fi

    # 8. Reviewer 推荐
    if [[ "$REVIEWER" == true ]]; then
        echo ""
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        "${SCRIPT_DIR}/reviewer-assign.sh" "$REVIEW_DIR" || true
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo ""
    fi

    # ====== 获取上次审查以来的变更 ======
    LAST_REVIEW_TAG="code-review-assistant/last-review"
    local commit_range=""
    local changes=""
    local since_desc=""

    if git rev-parse "$LAST_REVIEW_TAG" > /dev/null 2>&1; then
        since_desc="自上次审查以来"
        commit_range="${LAST_REVIEW_TAG}..HEAD"
        changes=$(git log "$commit_range" --name-only --pretty=format: | sort -u | grep -v '^$' || true)
    else
        since_desc="最近 3 天"
        commit_range="HEAD~3..HEAD"
        changes=$(git log --since="3 days ago" --name-only --pretty=format: | sort -u | grep -v '^$' || true)
    fi

    if [[ -z "$changes" ]]; then
        echo -e "${GREEN}✓ 没有新的变更需要审查${NC}"
        echo ""
        echo "提示: 使用 --force 强制审查最近提交"
        exit 0
    fi

    # 生成审查报告
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}  审查范围: ${since_desc}${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # 提交记录
    echo -e "${CYAN}【提交记录】${NC}"
    git log --oneline --color=always "$commit_range" 2>/dev/null | head -15 || echo "(无新提交)"
    echo ""

    # 变更文件
    echo -e "${CYAN}【变更文件】${NC}"
    local file_count=$(printf '%s\n' "$changes" | wc -l | tr -d ' ')
    printf '%s\n' "$changes" | head -20
    if [[ $file_count -gt 20 ]]; then
        echo -e "${YELLOW}... 共 ${file_count} 个文件${NC}"
    fi
    echo ""

    # 统计信息
    local added_lines=$(git diff --shortstat "$commit_range" 2>/dev/null | grep -oP '\d+(?= insertion)' || echo "0")
    local deleted_lines=$(git diff --shortstat "$commit_range" 2>/dev/null | grep -oP '\d+(?= deletion)' || echo "0")

    echo -e "${CYAN}【统计】${NC}"
    echo "  新增行数: ${GREEN}${added_lines}${NC}"
    echo "  删除行数: ${GREEN}${deleted_lines}${NC}"
    echo ""

    # 生成 Claude 提示
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  请在 Claude Code 中执行以下命令:${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${CYAN}/code-review-assistant${NC}"
    echo ""
    echo "或粘贴以下内容:"
    echo ""
    echo "---"
    echo "请审查以下代码变更:"
    echo ""
    echo "仓库: ${REVIEW_DIR}"
    echo "范围: ${commit_range}"
    echo "深度: ${DEPTH}"
    echo "说明: ${since_desc}的变更"
    echo ""
    echo "变更文件 (${file_count} 个):"
    printf '%s\n' "$changes" | head -50
    echo "---"
    echo ""

    # 更新 last-review 标记
    git tag -f "$LAST_REVIEW_TAG" HEAD > /dev/null 2>&1
    echo -e "${GREEN}✓ 已更新审查标记${NC}"
    echo ""

    # 发送通知
    send_notification "$changes" "$file_count" "$added_lines" "$deleted_lines"

    # 9. 导出报告
    if [[ "$EXPORT" == true ]]; then
        echo ""
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        "${SCRIPT_DIR}/export-report.sh" "$REVIEW_DIR" "$EXPORT_FORMAT" || true
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo ""
    fi

    # 10. 测试覆盖率分析
    if [[ "$TEST_COVERAGE" == true ]]; then
        echo ""
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        "${SCRIPT_DIR}/test-coverage.sh" "$REVIEW_DIR" || true
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo ""
    fi

    # 11. API 契约变更检测
    if [[ "$API_CONTRACT" == true ]]; then
        echo ""
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        "${SCRIPT_DIR}/api-contract.sh" "$REVIEW_DIR" || true
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo ""
    fi

    # 12. Bundle 体积分析
    if [[ "$BUNDLE_SIZE" == true ]]; then
        echo ""
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        "${SCRIPT_DIR}/bundle-size.sh" "$REVIEW_DIR" || true
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo ""
    fi

    # 13. 数据库迁移安全审查
    if [[ "$DB_MIGRATION" == true ]]; then
        echo ""
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        "${SCRIPT_DIR}/db-migration.sh" "$REVIEW_DIR" || true
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo ""
    fi

    # 14. 国际化完整性检查
    if [[ "$I18N_CHECK" == true ]]; then
        echo ""
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        "${SCRIPT_DIR}/i18n-check.sh" "$REVIEW_DIR" || true
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo ""
    fi

    # 15. PII 敏感信息扫描
    if [[ "$PII_SCAN" == true ]]; then
        echo ""
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        "${SCRIPT_DIR}/pii-scan.sh" "$REVIEW_DIR" || true
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo ""
    fi

    # 16. Feature Flag 清理检测
    if [[ "$FEATURE_FLAG" == true ]]; then
        echo ""
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        "${SCRIPT_DIR}/feature-flag.sh" "$REVIEW_DIR" || true
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo ""
    fi

    # 17. CODEOWNERS 匹配检查
    if [[ "$CODEOWNERS_CHECK" == true ]]; then
        echo ""
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        "${SCRIPT_DIR}/codeowners-check.sh" "$REVIEW_DIR" || true
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo ""
    fi

    # 18. 许可证合规检查
    if [[ "$LICENSE_CHECK" == true ]]; then
        echo ""
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        "${SCRIPT_DIR}/license-check.sh" "$REVIEW_DIR" || true
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo ""
    fi

    # 19. 性能基准回归分析
    if [[ "$PERF_BENCHMARK" == true ]]; then
        echo ""
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        "${SCRIPT_DIR}/perf-benchmark.sh" "$REVIEW_DIR" || true
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo ""
    fi

    # 20. Changelog 生成
    if [[ "$CHANGELOG_GEN" == true ]]; then
        echo ""
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        "${SCRIPT_DIR}/changelog-gen.sh" "$REVIEW_DIR" || true
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo ""
    fi

    # 21. 并发安全深度检测
    if [[ "$CONCURRENCY_CHECK" == true ]]; then
        echo ""
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        "${SCRIPT_DIR}/concurrency-check.sh" "$REVIEW_DIR" || true
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo ""
    fi

    # 22. 代码复用性检查
    if [[ "$REUSE_CHECK" == true ]]; then
        echo ""
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        "${SCRIPT_DIR}/reuse-check.sh" "$REVIEW_DIR" || true
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo ""
    fi

    # 23. 错误处理完整性
    if [[ "$ERROR_HANDLING" == true ]]; then
        echo ""
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        "${SCRIPT_DIR}/error-handling.sh" "$REVIEW_DIR" || true
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo ""
    fi

    # 24. 资源泄露扫描
    if [[ "$RESOURCE_LEAK" == true ]]; then
        echo ""
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        "${SCRIPT_DIR}/resource-leak.sh" "$REVIEW_DIR" || true
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo ""
    fi

    # 25. 类型安全深度检查
    if [[ "$TYPE_SAFETY" == true ]]; then
        echo ""
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        "${SCRIPT_DIR}/type-safety.sh" "$REVIEW_DIR" || true
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo ""
    fi

    # 26. 架构合规检查
    if [[ "$ARCHITECTURE" == true ]]; then
        echo ""
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        "${SCRIPT_DIR}/architecture-check.sh" "$REVIEW_DIR" || true
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo ""
    fi

    # 27. 测试质量检查
    if [[ "$TEST_QUALITY" == true ]]; then
        echo ""
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        "${SCRIPT_DIR}/test-quality.sh" "$REVIEW_DIR" || true
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo ""
    fi

    # 28. 代码异味检测
    if [[ "$CODE_SMELL" == true ]]; then
        echo ""
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        "${SCRIPT_DIR}/code-smell.sh" "$REVIEW_DIR" || true
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo ""
    fi

    # 29. 文档质量检查
    if [[ "$DOC_QUALITY" == true ]]; then
        echo ""
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        "${SCRIPT_DIR}/doc-quality.sh" "$REVIEW_DIR" || true
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo ""
    fi

    # 30. 无障碍检查
    if [[ "$A11Y_CHECK" == true ]]; then
        echo ""
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        "${SCRIPT_DIR}/a11y-check.sh" "$REVIEW_DIR" || true
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo ""
    fi

    # 31. 配置漂移检测
    if [[ "$CONFIG_DRIFT" == true ]]; then
        echo ""
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        "${SCRIPT_DIR}/config-drift.sh" "$REVIEW_DIR" || true
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo ""
    fi

    # 32. 供应链安全扫描
    if [[ "$SUPPLY_CHAIN" == true ]]; then
        echo ""
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        "${SCRIPT_DIR}/supply-chain.sh" "$REVIEW_DIR" || true
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo ""
    fi

    # 33. 命名规范检查
    if [[ "$NAMING_CONVENTION" == true ]]; then
        echo ""
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        "${SCRIPT_DIR}/naming-convention.sh" "$REVIEW_DIR" || true
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo ""
    fi
}

# 发送通知
send_notification() {
    local changes="$1"
    local file_count="$2"
    local added_lines="$3"
    local deleted_lines="$4"

    # 如果没有指定通知渠道，检查环境变量
    if [[ -z "$NOTIFY" ]]; then
        if [[ -n "$FEISHU_WEBHOOK" ]]; then NOTIFY="feishu"; WEBHOOK="$FEISHU_WEBHOOK"; fi
        if [[ -n "$DINGTALK_WEBHOOK" ]]; then NOTIFY="dingtalk"; WEBHOOK="$DINGTALK_WEBHOOK"; fi
        if [[ -n "$WECOM_WEBHOOK" ]]; then NOTIFY="wecom"; WEBHOOK="$WECOM_WEBHOOK"; fi
        if [[ -n "$SLACK_WEBHOOK" ]]; then NOTIFY="slack"; WEBHOOK="$SLACK_WEBHOOK"; fi
        if [[ -n "$LINE_NOTIFY_TOKEN" ]]; then NOTIFY="line"; fi
        if [[ -n "$TELEGRAM_BOT_TOKEN" ]]; then NOTIFY="telegram"; fi
        if [[ -n "$TWILIO_SID" ]]; then NOTIFY="whatsapp"; fi
        if [[ -n "$SMTP_USER" ]]; then NOTIFY="email"; fi
    fi

    [[ -z "$NOTIFY" ]] && return

    # 构建通知内容
    local repo_name=$(basename "$REVIEW_DIR")
    local title="📝 Code Review: ${repo_name}"
    local content="**仓库:** ${REVIEW_DIR}\n"
    content+="**变更文件:** ${file_count} 个\n"
    content+="**新增/删除:** +${added_lines} / -${deleted_lines}\n"
    content+="**审查深度:** ${DEPTH}\n\n"
    content+="**主要变更:**\n"
    content+=$(printf '%s\n' "$changes" | head -10 | sed 's/^/- /')
    [[ $(printf '%s\n' "$changes" | wc -l) -gt 10 ]] && content+="\n... (更多文件)"
    content+="\n\n请在 Claude Code 中执行: /code-review-assistant"

    echo -e "${YELLOW}发送 ${NOTIFY} 通知...${NC}"

    local NOTIFIER_DIR="${SCRIPT_DIR}/notifiers"
    case "$NOTIFY" in
        feishu)
            "${NOTIFIER_DIR}/feishu.sh" --webhook "${WEBHOOK:-$FEISHU_WEBHOOK}" --title "$title" --content "$content"
            ;;
        dingtalk)
            "${NOTIFIER_DIR}/dingtalk.sh" --webhook "${WEBHOOK:-$DINGTALK_WEBHOOK}" --title "$title" --content "$content"
            ;;
        wecom)
            "${NOTIFIER_DIR}/wecom.sh" --webhook "${WEBHOOK:-$WECOM_WEBHOOK}" --title "$title" --content "$content"
            ;;
        slack)
            "${NOTIFIER_DIR}/slack.sh" --webhook "${WEBHOOK:-$SLACK_WEBHOOK}" --title "$title" --content "$content"
            ;;
        line)
            "${NOTIFIER_DIR}/line.sh" --title "$title" --content "$content"
            ;;
        telegram)
            "${NOTIFIER_DIR}/telegram.sh" --title "$title" --content "$content"
            ;;
        whatsapp)
            "${NOTIFIER_DIR}/whatsapp.sh" --to "${EMAIL_TO}" --title "$title" --content "$content"
            ;;
        email)
            "${NOTIFIER_DIR}/email.sh" --to "${EMAIL_TO}" --subject "$title" --content "$content"
            ;;
        *)
            echo -e "${RED}未知通知渠道: ${NOTIFY}${NC}"
            ;;
    esac
}

# 安装到 crontab
install_cron() {
    print_header
    echo -e "${YELLOW}安装定时任务...${NC}"
    echo ""

    # 构建通知参数
    local extra_args=""
    [[ -n "$NOTIFY" ]] && extra_args="${extra_args} --notify ${NOTIFY}"
    [[ -n "$WEBHOOK" ]] && extra_args="${extra_args} --webhook ${WEBHOOK}"
    [[ -n "$EMAIL_TO" ]] && extra_args="${extra_args} --to ${EMAIL_TO}"
    [[ "$SCAN_SECRETS" == true ]] && extra_args="${extra_args} --scan-secrets"
    [[ "$SCAN_DEPS" == true ]] && extra_args="${extra_args} --scan-deps"
    [[ "$IMPACT" == true ]] && extra_args="${extra_args} --impact"
    [[ "$CONTEXT" == true ]] && extra_args="${extra_args} --context"
    [[ "$SAVE_HISTORY" == true ]] && extra_args="${extra_args} --history"
    [[ "$COMPLEXITY" == true ]] && extra_args="${extra_args} --complexity"
    [[ "$LINT" == true ]] && extra_args="${extra_args} --lint"
    [[ "$COMMIT_LINT" == true ]] && extra_args="${extra_args} --commit-lint"
    [[ "$REVIEWER" == true ]] && extra_args="${extra_args} --reviewer"
    [[ "$EXPORT" == true ]] && extra_args="${extra_args} --export ${EXPORT_FORMAT}"
    [[ "$TEST_COVERAGE" == true ]] && extra_args="${extra_args} --test-coverage"
    [[ "$API_CONTRACT" == true ]] && extra_args="${extra_args} --api-contract"
    [[ "$BUNDLE_SIZE" == true ]] && extra_args="${extra_args} --bundle-size"
    [[ "$DB_MIGRATION" == true ]] && extra_args="${extra_args} --db-migration"
    [[ "$I18N_CHECK" == true ]] && extra_args="${extra_args} --i18n"
    [[ "$PII_SCAN" == true ]] && extra_args="${extra_args} --pii"
    [[ "$FEATURE_FLAG" == true ]] && extra_args="${extra_args} --feature-flag"
    [[ "$CODEOWNERS_CHECK" == true ]] && extra_args="${extra_args} --codeowners"
    [[ "$LICENSE_CHECK" == true ]] && extra_args="${extra_args} --license"
    [[ "$PERF_BENCHMARK" == true ]] && extra_args="${extra_args} --perf"
    [[ "$CHANGELOG_GEN" == true ]] && extra_args="${extra_args} --changelog"
    [[ "$CONCURRENCY_CHECK" == true ]] && extra_args="${extra_args} --concurrency"
    [[ "$REUSE_CHECK" == true ]] && extra_args="${extra_args} --reuse"
    [[ "$ERROR_HANDLING" == true ]] && extra_args="${extra_args} --error-handling"
    [[ "$RESOURCE_LEAK" == true ]] && extra_args="${extra_args} --resource-leak"
    [[ "$TYPE_SAFETY" == true ]] && extra_args="${extra_args} --type-safety"
    [[ "$ARCHITECTURE" == true ]] && extra_args="${extra_args} --architecture"
    [[ "$TEST_QUALITY" == true ]] && extra_args="${extra_args} --test-quality"
    [[ "$CODE_SMELL" == true ]] && extra_args="${extra_args} --code-smell"
    [[ "$DOC_QUALITY" == true ]] && extra_args="${extra_args} --doc-quality"
    [[ "$A11Y_CHECK" == true ]] && extra_args="${extra_args} --a11y"
    [[ "$CONFIG_DRIFT" == true ]] && extra_args="${extra_args} --config-drift"
    [[ "$SUPPLY_CHAIN" == true ]] && extra_args="${extra_args} --supply-chain"
    [[ "$NAMING_CONVENTION" == true ]] && extra_args="${extra_args} --naming"

    # 转换时间为 cron 格式
    local cron_times=""
    IFS=',' read -ra TIME_ARRAY <<< "$TIME"
    for t in "${TIME_ARRAY[@]}"; do
        local hour=$(printf '%s\n' "$t" | cut -d: -f1)
        local minute=$(printf '%s\n' "$t" | cut -d: -f2)
        cron_times="${cron_times}${minute} ${hour} * * ${DAYS_PARSED} cd ${REVIEW_DIR} && ${FULL_SCRIPT_PATH} --now --path ${REVIEW_DIR} --depth ${DEPTH} ${extra_args} >> /tmp/code-review-assistant.log 2>&1"
        cron_times="${cron_times}"$'\n'
    done

    # 备份现有 crontab
    crontab -l > /tmp/crontab.backup 2>/dev/null || true

    # 移除旧的 code-review-assistant 任务
    crontab -l 2>/dev/null | grep -v "code-review-assistant" > /tmp/crontab.new || true

    # 添加新任务
    echo "# Code Review Assistant - 自动代码审查 ($(date '+%Y-%m-%d %H:%M'))" >> /tmp/crontab.new
    echo "$cron_times" >> /tmp/crontab.new

    # 安装
    crontab /tmp/crontab.new

    echo -e "${GREEN}✓ 定时任务已安装${NC}"
    echo ""
    echo -e "${YELLOW}任务详情:${NC}"
    echo "  执行时间: ${GREEN}${TIME}${NC}"
    echo "  执行日期: ${GREEN}${DAYS_PARSED}${NC}"
    echo "  审查深度: ${GREEN}${DEPTH}${NC}"
    echo "  目标目录: ${GREEN}${REVIEW_DIR}${NC}"
    [[ -n "$NOTIFY" ]] && echo "  通知渠道: ${GREEN}${NOTIFY}${NC}"
    echo ""
    echo -e "${YELLOW}查看所有任务:${NC}"
    echo "  crontab -l | grep code-review-assistant"
    echo ""
    echo -e "${YELLOW}查看执行日志:${NC}"
    echo "  tail -f /tmp/code-review-assistant.log"
}

# 卸载
do_uninstall() {
    print_header
    echo -e "${YELLOW}卸载定时任务...${NC}"
    echo ""

    crontab -l 2>/dev/null | grep -v "code-review-assistant" > /tmp/crontab.new || true
    crontab /tmp/crontab.new

    echo -e "${GREEN}✓ 已卸载所有 Code Review Assistant 定时任务${NC}"
    echo ""
}

# 查看状态
do_status() {
    print_header
    echo -e "${YELLOW}定时任务状态:${NC}"
    echo ""

    local tasks=$(crontab -l 2>/dev/null | grep "code-review-assistant" || true)

    if [[ -z "$tasks" ]]; then
        echo -e "${YELLOW}暂无已安装的定时任务${NC}"
        echo ""
        echo "使用以下命令安装:"
        echo "  ./scheduled-review.sh --install --time 09:00"
    else
        echo -e "${GREEN}已安装的任务:${NC}"
        echo ""
        echo "$tasks"
    fi

    echo ""
    echo -e "${YELLOW}最近日志:${NC}"
    if [[ -f /tmp/code-review-assistant.log ]]; then
        tail -20 /tmp/code-review-assistant.log
    else
        echo "(暂无日志)"
    fi
    echo ""
}

# 列出所有任务
do_list() {
    print_header
    echo -e "${YELLOW}所有已安装的审查任务:${NC}"
    echo ""
    crontab -l 2>/dev/null | grep "code-review-assistant" | grep -v "^#" || echo "(暂无任务)"
    echo ""
}

# ========== 主逻辑 ==========

# 处理命令
if [[ "$UNINSTALL" == true ]]; then
    do_uninstall
    exit 0
fi

if [[ "$STATUS" == true ]]; then
    do_status
    exit 0
fi

if [[ "$LIST" == true ]]; then
    do_list
    exit 0
fi

if [[ "$INSTALL" == true ]]; then
    install_cron
    exit 0
fi

# 执行审查（默认或 --now）
if [[ "$NOW" == true ]] || [[ "$FORCE" == true ]] || [[ $# -eq 0 ]]; then
    do_review
    exit 0
fi

# 如果没有匹配任何操作，显示帮助
show_help
