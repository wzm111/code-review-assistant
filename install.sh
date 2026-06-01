#!/bin/bash
# Code Review Assistant - Universal Installer
# Supports: Claude Code, Cursor, Claude Desktop (MCP), VS Code, Generic CLI

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'
BOLD='\033[1m'

REPO_URL="${REPO_URL:-https://github.com/YOURNAME/code-review-assistant}"
INSTALL_DIR=""
MODE=""

# ===== Utility Functions =====

print_header() {
    echo -e "${CYAN}"
    echo '  ____          _      _____                      _             _              _   _'
    echo ' / ___|___   __| | ___|  ___|_      _____        / \   ___  ___| |_ _   _ _ __| |_(_)_ __   __ _'
    echo '| |   / _ \ / _` |/ _ \ |_  \ \ /\ / / _ \      / _ \ / __|/ _ \ __| | | | \'__| __| | \'_ \ / _` |'
    echo '| |__| (_) | (_| |  __/  _|  \ V  V / (_) |    / ___ \\__ \  __/ |_| |_| | |  | |_| | | | | (_| |'
    echo ' \____\___/ \__,_|\___|_|     \_/\_/ \___/    /_/   \_\___/\___|\__|\__,_|_|   \__|_|_| |_|\__, |'
    echo '                                                                                          |___/'
    echo -e "${NC}"
    echo -e "${BOLD}Universal AI Code Review Tool - Multi-Platform Installer${NC}"
    echo ""
}

log_info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ===== Pre-flight Checks =====

check_prerequisites() {
    log_info "Checking prerequisites..."

    if ! command -v git &>/dev/null; then
        log_error "git is required but not installed"
        exit 1
    fi

    if ! command -v bash &>/dev/null; then
        log_error "bash is required but not installed"
        exit 1
    fi

    log_ok "Prerequisites satisfied"
}

# ===== Installation Targets =====

install_claude_code() {
    local target_dir="${1:-$HOME/.claude/skills/code-review-assistant}"
    log_info "Installing for Claude Code..."

    mkdir -p "$target_dir"
    cp -r scripts rules SKILL.md scheduled-review.yml .env.example "$target_dir/"

    # Claude Code skill is already in SKILL.md format
    log_ok "Claude Code skill installed to $target_dir"
    echo ""
    echo -e "${CYAN}Usage:${NC}"
    echo "  1. Restart Claude Code"
    echo "  2. Type: ${BOLD}/code-review-assistant${NC}"
    echo ""
}

install_mcp() {
    local target_dir="${1:-$HOME/.config/code-review-assistant}"
    log_info "Installing MCP server..."

    mkdir -p "$target_dir"
    cp -r scripts rules mcp "$target_dir/"

    cd "$target_dir/mcp"

    if command -v npm &>/dev/null; then
        log_info "Installing Node.js dependencies..."
        npm install --production
        log_ok "Dependencies installed"
    else
        log_warn "npm not found. Please install Node.js and run 'npm install' in $target_dir/mcp"
    fi

    log_ok "MCP server installed to $target_dir"
    echo ""
    echo -e "${CYAN}Configuration required:${NC}"
    echo ""
    echo -e "${BOLD}For Cursor:${NC}"
    echo "  1. Open Cursor Settings > MCP"
    echo "  2. Add a new MCP server:"
    echo "     Name: code-review-assistant"
    echo "     Command: node $target_dir/mcp/server.js"
    echo "  3. The AI will auto-discover all 25+ review tools"
    echo ""
    echo -e "${BOLD}For Claude Desktop:${NC}"
    echo "  1. Edit ~/Library/Application Support/Claude/claude_desktop_config.json (macOS)"
    echo "     or %APPDATA%\\Claude\\claude_desktop_config.json (Windows)"
    echo "  2. Add:"
cat <<EOF
  {
    "mcpServers": {
      "code-review-assistant": {
        "command": "node",
        "args": ["$target_dir/mcp/server.js"]
      }
    }
  }
EOF
    echo ""
}

install_cursor_rules() {
    local target_dir="${1:-.}"
    log_info "Generating .cursorrules for Cursor..."

    cat > "$target_dir/.cursorrules" <<'EOF'
# Code Review Assistant - Cursor Rules
# This file tells Cursor how to use the code review capabilities

## Code Review Protocol
When asked to review code, you MUST:
1. Run the appropriate review scripts from the scripts/ directory
2. Report findings with file:line references
3. Prioritize: Security > Correctness > Performance > Maintainability

## Available Review Tools
You can execute these bash scripts to perform automated checks:
- scripts/scan-secrets.sh [dir] [all|critical|high]  - Scan for hardcoded secrets
- scripts/scan-deps.sh [dir]                          - Check dependency vulnerabilities
- scripts/code-smell.sh [dir]                         - Detect code smells
- scripts/naming-convention.sh [dir]                  - Check naming conventions
- scripts/lint-check.sh [dir]                         - Run lint checks
- scripts/complexity-analysis.sh [dir] [quick|standard|deep] - Analyze complexity
- scripts/concurrency-check.sh [dir]                  - Check concurrency issues
- scripts/error-handling.sh [dir]                     - Check error handling
- scripts/type-safety.sh [dir] [threshold]            - Check type safety
- scripts/test-coverage.sh [dir] [threshold]          - Analyze test coverage
- scripts/pii-scan.sh [dir] [severity]                - Scan for PII leaks
- scripts/supply-chain.sh [dir]                       - Check supply chain risks

## Review Output Format
Structure reviews as:
## Critical Issues
- [file:line] Issue + fix suggestion

## Warnings
- [file:line] Issue + suggestion

## Suggestions
- [file:line] Improvement idea

## Positive Notes
- What was done well
EOF

    log_ok ".cursorrules generated at $target_dir/.cursorrules"
    echo ""
}

install_vscode_extension_config() {
    local target_dir="${1:-.}"
    log_info "Generating VS Code / Copilot configuration..."

    mkdir -p "$target_dir/.vscode"

    cat > "$target_dir/.vscode/settings.json" <<EOF
{
  "github.copilot.chat.codeReview.instructions": [
    {
      "file": "${target_dir}/.copilot-review-rules.md"
    }
  ]
}
EOF

    cat > "$target_dir/.copilot-review-rules.md" <<'EOF'
# Copilot Code Review Instructions

## Pre-Review Checklist
Before reviewing any code, run these scripts:
```bash
bash scripts/scan-secrets.sh .      # Check for secrets
bash scripts/scan-deps.sh .         # Check dependencies
bash scripts/naming-convention.sh . # Check naming
```

## Review Priorities
1. Security vulnerabilities (injection, secrets, XSS)
2. Logic correctness (null checks, race conditions)
3. Performance issues (N+1 queries, unnecessary re-renders)
4. Maintainability (naming, complexity, duplication)

## Output Format
Always cite specific file:line references.
Provide concrete fix suggestions, not vague complaints.
EOF

    log_ok "VS Code configuration generated"
    echo ""
}

install_global_cli() {
    local target_dir="${1:-$HOME/.local/share/code-review-assistant}"
    log_info "Installing global CLI..."

    mkdir -p "$target_dir"
    cp -r scripts rules mcp dashboard "$target_dir/"

    # Create wrapper script
    cat > "$target_dir/bin/cra" <<'EOF'
#!/bin/bash
# Code Review Assistant CLI
cd "$(dirname "$0")/.."

# ── Dashboard 模式 ─────────────────────────────────────────────
if [[ "$1" == "--dashboard" || "$1" == "-d" || "$1" == "dashboard" ]]; then
    shift || true
    PORT="${1:-8080}"
    echo "🔍 启动 Code Review Assistant Dashboard..."
    echo "   端口: $PORT"
    echo ""
    exec bash dashboard/launcher.sh "$PORT"
fi

# ── 帮助 ──────────────────────────────────────────────────────
if [[ "$1" == "--help" || "$1" == "-h" || -z "$1" ]]; then
    echo "Code Review Assistant CLI"
    echo ""
    echo "Usage:"
    echo "  cra <command> [args...]      运行审查脚本"
    echo "  cra --dashboard [port]       启动 Web 面板（默认 8080）"
    echo "  cra -d [port]                同上"
    echo "  cra --help                   显示帮助"
    echo ""
    echo "Available commands:"
    ls scripts/*.sh 2>/dev/null | sed 's|scripts/||' | sed 's/.sh$//' | sed 's/^/  /'
    echo ""
    echo "Examples:"
    echo "  cra scan-secrets . critical"
    echo "  cra severity-gate . high"
    echo "  cra --dashboard              启动面板"
    echo "  cra -d 9000                  在 9000 端口启动面板"
    exit 0
fi

# ── 运行脚本 ──────────────────────────────────────────────────
SCRIPT="$1"
shift
if [[ -f "scripts/${SCRIPT}.sh" ]]; then
    bash "scripts/${SCRIPT}.sh" "$@"
else
    echo "❌ 未知命令: $SCRIPT"
    echo ""
    echo "可用命令:"
    ls scripts/*.sh 2>/dev/null | sed 's|scripts/||' | sed 's/.sh$//' | sed 's/^/  /'
    echo ""
    echo "使用 'cra --help' 查看完整帮助"
    exit 1
fi
EOF
    chmod +x "$target_dir/bin/cra"

    # Try to add to PATH
    local shell_rc=""
    if [[ "$SHELL" == */zsh ]]; then
        shell_rc="$HOME/.zshrc"
    elif [[ "$SHELL" == */bash ]]; then
        shell_rc="$HOME/.bashrc"
    fi

    if [[ -n "$shell_rc" && -f "$shell_rc" ]]; then
        if ! grep -q "$target_dir/bin" "$shell_rc" 2>/dev/null; then
            echo "export PATH=\"$target_dir/bin:\$PATH\"" >> "$shell_rc"
            log_ok "Added $target_dir/bin to PATH in $shell_rc"
            log_warn "Please run: source $shell_rc"
        fi
    fi

    log_ok "Global CLI installed to $target_dir"
    echo ""
    echo -e "${CYAN}Usage:${NC}"
    echo "  cra scan-secrets ."
    echo "  cra code-smell ."
    echo "  cra naming-convention ."
    echo "  cra --dashboard            启动 Web 面板"
    echo ""
}

# ===== Interactive Mode =====

interactive_install() {
    echo ""
    echo -e "${BOLD}Which AI platform are you using?${NC}"
    echo ""
    echo "  1) Claude Code      (Claude CLI / claude-code)"
    echo "  2) Claude Desktop   (MCP server)"
    echo "  3) Cursor           (MCP server + .cursorrules)"
    echo "  4) VS Code + Copilot (Extension config)"
    echo "  5) Generic CLI      (Command-line tool for any AI)"
    echo "  6) All of the above (Full installation)"
    echo ""
    read -p "Enter choice (1-6): " choice

    case $choice in
        1)
            install_claude_code
            ;;
        2)
            install_mcp
            ;;
        3)
            install_mcp
            install_cursor_rules
            ;;
        4)
            install_vscode_extension_config
            ;;
        5)
            install_global_cli
            ;;
        6)
            install_claude_code
            install_mcp
            install_cursor_rules
            install_vscode_extension_config
            install_global_cli
            ;;
        *)
            log_error "Invalid choice"
            exit 1
            ;;
    esac
}

# ===== Direct Mode =====

direct_install() {
    case "$MODE" in
        claude)
            install_claude_code "$INSTALL_DIR"
            ;;
        mcp)
            install_mcp "$INSTALL_DIR"
            ;;
        cursor)
            install_mcp "$INSTALL_DIR"
            install_cursor_rules
            ;;
        vscode)
            install_vscode_extension_config
            ;;
        cli|global)
            install_global_cli "$INSTALL_DIR"
            ;;
        all)
            install_claude_code "$INSTALL_DIR"
            install_mcp "$INSTALL_DIR"
            install_cursor_rules
            install_vscode_extension_config
            install_global_cli "$INSTALL_DIR"
            ;;
        *)
            log_error "Unknown mode: $MODE"
            echo "Valid modes: claude, mcp, cursor, vscode, cli, all"
            exit 1
            ;;
    esac
}

# ===== Main =====

usage() {
    echo "Usage: install.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -m, --mode MODE       Installation mode: claude|mcp|cursor|vscode|cli|all"
    echo "  -d, --dir DIR         Installation directory (default: platform-specific)"
    echo "  -h, --help            Show this help"
    echo ""
    echo "Modes:"
    echo "  claude    - Claude Code skill (SKILL.md format)"
    echo "  mcp       - MCP server for Claude Desktop, Cursor, Windsurf"
    echo "  cursor    - MCP server + .cursorrules for Cursor"
    echo "  vscode    - VS Code settings + Copilot rules"
    echo "  cli       - Global command-line tool"
    echo "  all       - Install everything"
    echo ""
    echo "Examples:"
    echo "  install.sh                           # Interactive mode"
    echo "  install.sh --mode claude             # Install for Claude Code"
    echo "  install.sh --mode cursor --dir ~/tools"
    echo "  install.sh --mode all"
    echo ""
}

main() {
    print_header
    check_prerequisites

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -m|--mode)
                MODE="$2"
                shift 2
                ;;
            -d|--dir)
                INSTALL_DIR="$2"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    if [[ -z "$MODE" ]]; then
        interactive_install
    else
        direct_install
    fi

    echo ""
    echo -e "${GREEN}${BOLD}Installation complete!${NC}"
    echo ""
    echo -e "${CYAN}Need help?${NC} See README.md for platform-specific setup guides."
}

main "$@"
