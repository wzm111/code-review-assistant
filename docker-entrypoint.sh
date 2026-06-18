#!/bin/bash
# Code Review Assistant / 通用 Docker 入口脚本
# 云厂商无关：任何支持 Docker 的 CI/CD 平台都可以直接调用此镜像

set -e

TARGET_DIR="${1:-.}"
SEVERITY="${SEVERITY:-high}"
REPORT_DIR="${REPORT_DIR:-/tmp/cra-reports}"

mkdir -p "$REPORT_DIR"

cd "$TARGET_DIR" || {
    echo "❌ 无法进入目标目录: $TARGET_DIR" >&2
    exit 1
}

echo "🤖 Code Review Assistant / 通用审查"
echo "=========================================="
echo "目标目录: $(pwd)"
echo "门禁阈值: $SEVERITY"
echo ""

run_scan() {
    local name="$1"
    local script="$2"
    local output="$3"
    shift 3

    echo "🔍 $name"
    if bash "$script" "$@" > "$output" 2>&1; then
        echo "  ✓ $name 完成"
    else
        echo "  ⚠️ $name 发现异常或退出非 0（继续后续扫描）"
    fi
}

# 阶段 1: 密钥扫描
if [[ "${SCAN_SECRET:-true}" == "true" ]]; then
    run_scan "Secret Scan / 密钥扫描" \
        "/opt/cra/scripts/scan-secrets.sh" \
        "$REPORT_DIR/secrets.txt" \
        "." "critical"
fi

# 阶段 2: 依赖漏洞扫描
if [[ "${SCAN_DEPS:-true}" == "true" ]]; then
    run_scan "Dependency Scan / 依赖漏洞扫描" \
        "/opt/cra/scripts/scan-deps.sh" \
        "$REPORT_DIR/deps.txt" \
        "."
fi

# 阶段 3: 代码质量扫描
if [[ "${SCAN_QUALITY:-true}" == "true" ]]; then
    run_scan "Code Smell / 代码异味" \
        "/opt/cra/scripts/code-smell.sh" \
        "$REPORT_DIR/smell.txt" \
        "."
    run_scan "Naming Convention / 命名规范" \
        "/opt/cra/scripts/naming-convention.sh" \
        "$REPORT_DIR/naming.txt" \
        "."
    run_scan "Lint Check / 规范检查" \
        "/opt/cra/scripts/lint-check.sh" \
        "$REPORT_DIR/lint.txt" \
        "."
fi

# 阶段 4: 汇总报告输出
echo ""
echo "📋 Review Report / 审查报告"
echo "=========================================="

REPORT_FILE="$REPORT_DIR/report.md"
echo "## Code Review Assistant 报告" > "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

for f in secrets.txt deps.txt smell.txt naming.txt lint.txt; do
    path="$REPORT_DIR/$f"
    if [[ -s "$path" ]]; then
        echo "### $f" >> "$REPORT_FILE"
        echo '```' >> "$REPORT_FILE"
        head -50 "$path" >> "$REPORT_FILE"
        echo '```' >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"

        echo "--- $f ---"
        head -30 "$path"
        echo ""
    fi
done

echo ""
echo "完整报告: $REPORT_FILE"
echo ""

# 阶段 5: 质量门禁（失败时返回非 0，阻断流水线）
echo "🚦 Severity Gate / 质量门禁 ($SEVERITY)"
exec bash /opt/cra/scripts/severity-gate.sh "." "$SEVERITY"
