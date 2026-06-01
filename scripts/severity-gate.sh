#!/bin/bash
# 严重度评分 + 质量门禁
# 收集所有审查结果，计算风险评分，判断是否通过质量门禁

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

TARGET_DIR="${1:-.}"
THRESHOLD="${2:-high}"

echo -e "${CYAN}${BOLD}🛡️  Severity Gate / 严重度评分 + 质量门禁${NC}"
echo "================================================"
echo ""

cd "$TARGET_DIR"

# ===== 严重度权重 =====（Bash 3.2 兼容，使用函数替代关联数组）
get_weight() {
    case "$1" in
        CRITICAL) echo 10 ;;
        HIGH)     echo 5  ;;
        MEDIUM)   echo 2  ;;
        LOW)      echo 1  ;;
        *)        echo 0  ;;
    esac
}

# ===== 质量门禁阈值 =====（Bash 3.2 兼容）
get_threshold() {
    case "$1" in
        critical) echo 10 ;;
        high)     echo 25 ;;
        medium)   echo 50 ;;
        low)      echo 100 ;;
        *)        echo 25 ;;
    esac
}

echo -e "${BLUE}【评分规则】${NC}"
echo "  CRITICAL: 10 分/条  (安全漏洞、数据丢失、崩溃)"
echo "  HIGH:     5  分/条  (逻辑错误、性能严重问题)"
echo "  MEDIUM:   2  分/条  (代码异味、维护性问题)"
echo "  LOW:      1  分/条  (风格建议、优化建议)"
echo ""
echo -e "${BLUE}【门禁阈值】${NC}"
echo "  critical 级别: 总分 ≤ $(get_threshold critical) 才能通过"
echo "  high 级别:     总分 ≤ $(get_threshold high) 才能通过"
echo "  medium 级别:   总分 ≤ $(get_threshold medium) 才能通过"
echo "  low 级别:      总分 ≤ $(get_threshold low) 才能通过"
echo -e "${YELLOW}当前门禁级别: ${BOLD}${THRESHOLD}${NC}"
echo ""

# ===== 运行各审查模块并收集结果 =====

CRITICAL_COUNT=0
HIGH_COUNT=0
MEDIUM_COUNT=0
LOW_COUNT=0
TOTAL_SCORE=0

run_checker() {
    local script="$1"
    local script_path="scripts/${script}.sh"
    local label="$2"

    if [[ ! -f "$script_path" ]]; then
        return
    fi

    echo -e "${CYAN}Running ${label}...${NC}"
    local output
    output=$(bash "$script_path" "$TARGET_DIR" 2>&1 || true)

    # 解析输出中的严重度标记
    local c=$(printf '%s\n' "$output" | grep -cE '\[CRITICAL\]|🔴|严重' || true)
    local h=$(printf '%s\n' "$output" | grep -cE '\[HIGH\]|🟠|高危' || true)
    local m=$(printf '%s\n' "$output" | grep -cE '\[MEDIUM\]|🟡|中危' || true)
    local l=$(printf '%s\n' "$output" | grep -cE '\[LOW\]|🟢|低危' || true)

    CRITICAL_COUNT=$((CRITICAL_COUNT + c))
    HIGH_COUNT=$((HIGH_COUNT + h))
    MEDIUM_COUNT=$((MEDIUM_COUNT + m))
    LOW_COUNT=$((LOW_COUNT + l))

    # 如果发现了问题，输出摘要
    if [[ $c -gt 0 || $h -gt 0 || $m -gt 0 || $l -gt 0 ]]; then
        echo -e "  ${YELLOW}Found: ${c} critical, ${h} high, ${m} medium, ${l} low${NC}"
    fi
}

# 运行关键检查器
echo -e "${CYAN}【执行审查模块】${NC}"
echo ""

run_checker "scan-secrets" "Secret Scan"
run_checker "scan-deps" "Dependency Scan"
run_checker "concurrency-check" "Concurrency Check"
run_checker "error-handling" "Error Handling"
run_checker "resource-leak" "Resource Leak"
run_checker "code-smell" "Code Smell"
run_checker "naming-convention" "Naming Convention"
run_checker "type-safety" "Type Safety"
run_checker "pii-scan" "PII Scan"
run_checker "supply-chain" "Supply Chain"

echo ""

# ===== 计算总分 =====

TOTAL_SCORE=$((
    CRITICAL_COUNT * $(get_weight CRITICAL) +
    HIGH_COUNT * $(get_weight HIGH) +
    MEDIUM_COUNT * $(get_weight MEDIUM) +
    LOW_COUNT * $(get_weight LOW)
))

THRESHOLD_SCORE=$(get_threshold "$THRESHOLD")

# ===== 输出评分报告 =====

echo -e "${CYAN}${BOLD}【评分报告】${NC}"
echo "======================================"
echo ""

printf "  %-20s %s\n" "CRITICAL issues:" "${CRITICAL_COUNT}"
printf "  %-20s %s\n" "HIGH issues:" "${HIGH_COUNT}"
printf "  %-20s %s\n" "MEDIUM issues:" "${MEDIUM_COUNT}"
printf "  %-20s %s\n" "LOW issues:" "${LOW_COUNT}"
echo ""
printf "  ${BOLD}%-20s %s${NC}\n" "Total Score:" "${TOTAL_SCORE}"
printf "  ${BOLD}%-20s %s${NC}\n" "Threshold:" "${THRESHOLD_SCORE}"
echo ""

# 风险等级
if [[ $TOTAL_SCORE -eq 0 ]]; then
    RISK_LEVEL="SAFE"
    RISK_COLOR="$GREEN"
elif [[ $TOTAL_SCORE -le 10 ]]; then
    RISK_LEVEL="LOW"
    RISK_COLOR="$GREEN"
elif [[ $TOTAL_SCORE -le 25 ]]; then
    RISK_LEVEL="MEDIUM"
    RISK_COLOR="$YELLOW"
elif [[ $TOTAL_SCORE -le 50 ]]; then
    RISK_LEVEL="HIGH"
    RISK_COLOR="$RED"
else
    RISK_LEVEL="CRITICAL"
    RISK_COLOR="$RED"
fi

echo -e "  ${BOLD}Risk Level: ${RISK_COLOR}${RISK_LEVEL}${NC}"
echo ""

# ===== 门禁判断 =====

echo -e "${CYAN}${BOLD}【质量门禁结果】${NC}"
echo "======================================"
echo ""

if [[ $TOTAL_SCORE -le $THRESHOLD_SCORE ]]; then
    echo -e "  ${GREEN}${BOLD}✅ PASSED${NC} — Score ${TOTAL_SCORE} ≤ threshold ${THRESHOLD_SCORE}"
    echo -e "  ${GREEN}Code quality meets the ${THRESHOLD} standard.${NC}"
    echo ""
    exit 0
else
    echo -e "  ${RED}${BOLD}❌ FAILED${NC} — Score ${TOTAL_SCORE} > threshold ${THRESHOLD_SCORE}"
    echo -e "  ${RED}Code quality does not meet the ${THRESHOLD} standard.${NC}"
    echo ""

    if [[ $CRITICAL_COUNT -gt 0 ]]; then
        echo -e "  ${RED}CRITICAL: ${CRITICAL_COUNT} issues must be fixed immediately.${NC}"
    fi
    if [[ $HIGH_COUNT -gt 0 ]]; then
        echo -e "  ${YELLOW}HIGH: ${HIGH_COUNT} issues should be fixed before merge.${NC}"
    fi
    if [[ $MEDIUM_COUNT -gt 0 ]]; then
        echo -e "  ${YELLOW}MEDIUM: ${MEDIUM_COUNT} issues recommended to fix.${NC}"
    fi
    if [[ $LOW_COUNT -gt 0 ]]; then
        echo -e "  ${BLUE}LOW: ${LOW_COUNT} suggestions for improvement.${NC}"
    fi
    echo ""

    # 输出各模块详细结果
    echo -e "${CYAN}【详细审查结果】${NC}"
    echo "Run individual scripts for full details:"
    echo "  bash scripts/scan-secrets.sh ."
    echo "  bash scripts/code-smell.sh ."
    echo "  bash scripts/naming-convention.sh ."
    echo ""

    exit 1
fi
