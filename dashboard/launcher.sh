#!/usr/bin/env bash
# Code Review Assistant Dashboard Launcher
# ========================================
# 自动检测运行环境并启动 Dashboard Web 服务
#
# 使用方式:
#     bash dashboard/launcher.sh          # 默认端口 8080
#     bash dashboard/launcher.sh 9000     # 指定端口
#
# 优先级: Node.js > Python3 > Python2 > 提示安装

set -euo pipefail

PORT="${1:-8080}"
DASHBOARD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "═══════════════════════════════════════════════════════════════"
echo "  🔍 Code Review Assistant Dashboard 启动器"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# ── 检测 Node.js ───────────────────────────────────────────────
if command -v node &>/dev/null; then
    NODE_VERSION=$(node --version 2>/dev/null | sed 's/v//')
    MAJOR=$(echo "$NODE_VERSION" | cut -d. -f1)
    if [ "$MAJOR" -ge 14 ] 2>/dev/null; then
        echo "✅ 检测到 Node.js v${NODE_VERSION}（推荐）"
        echo "   启动命令: node ${DASHBOARD_DIR}/server.js --port ${PORT}"
        echo ""
        cd "$DASHBOARD_DIR"
        exec node server.js --port "$PORT"
    else
        echo "⚠️  Node.js v${NODE_VERSION} 版本过低，需要 ≥14"
    fi
else
    echo "⏳ 未检测到 Node.js"
fi

# ── 检测 Python3 ───────────────────────────────────────────────
if command -v python3 &>/dev/null; then
    PY_VERSION=$(python3 --version 2>/dev/null | awk '{print $2}')
    echo "✅ 检测到 Python ${PY_VERSION}"
    echo "   启动命令: python3 ${DASHBOARD_DIR}/server.py --port ${PORT}"
    echo ""
    cd "$DASHBOARD_DIR"
    exec python3 server.py --port "$PORT"
fi

# ── 检测 Python2 ───────────────────────────────────────────────
if command -v python &>/dev/null; then
    PY_VERSION=$(python --version 2>&1 | awk '{print $2}')
    echo "✅ 检测到 Python ${PY_VERSION}"
    echo "   启动命令: python ${DASHBOARD_DIR}/server.py --port ${PORT}"
    echo ""
    cd "$DASHBOARD_DIR"
    exec python server.py --port "$PORT"
fi

# ── 都未安装 ───────────────────────────────────────────────────
echo ""
echo "❌ 未检测到可用的运行时环境"
echo ""
echo "请安装以下任一环境："
echo ""
echo "  【推荐】Node.js (≥14):"
echo "    macOS:  brew install node"
echo "    Ubuntu: sudo apt install nodejs npm"
echo "    官网:   https://nodejs.org"
echo ""
echo "  【备选】Python3:"
echo "    macOS:  brew install python3"
echo "    Ubuntu: sudo apt install python3"
echo ""
echo "安装完成后重新运行此脚本。"
echo ""
exit 1
