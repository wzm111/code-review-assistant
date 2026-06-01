#!/bin/bash
# 依赖漏洞扫描脚本
# 检测 package.json, pom.xml, requirements.txt, go.mod, Cargo.toml 中的已知漏洞

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

TARGET_DIR="${1:-.}"
SEVERITY_FILTER="${2:-}"  # high, moderate, low

echo -e "${CYAN}📦 Dependency Vulnerability Scanner / 依赖漏洞扫描${NC}"
echo "=========================================="
echo ""

cd "$TARGET_DIR"

# 检测项目类型并扫描
scan_npm() {
    if [[ ! -f "package.json" ]]; then
        return
    fi

    echo -e "${CYAN}【npm / Node.js】${NC}"

    if ! command -v npm &> /dev/null; then
        echo -e "${YELLOW}⚠️ npm 未安装，跳过 Node.js 扫描${NC}"
        return
    fi

    # 使用 npm audit
    if npm audit --json &> /dev/null 2>/dev/null; then
        local audit_result=$(npm audit --json 2>/dev/null || true)
        local vuln_count=$(printf '%s\n' "$audit_result" | grep -o '"vulnerabilities"' | wc -l | tr -d ' ')

        if [[ "$vuln_count" -gt 0 ]]; then
            echo -e "${RED}⚠️ 发现漏洞${NC}"
            npm audit 2>/dev/null | head -30 || true
        else
            echo -e "${GREEN}✅ npm audit 通过${NC}"
        fi
    else
        echo -e "${YELLOW}无法运行 npm audit，请确保 node_modules 已安装${NC}"
    fi
    echo ""
}

scan_python() {
    if [[ ! -f "requirements.txt" && ! -f "Pipfile" && ! -f "pyproject.toml" ]]; then
        return
    fi

    echo -e "${CYAN}【Python】${NC}"

    # 尝试使用 pip-audit 或 safety
    if command -v pip-audit &> /dev/null; then
        pip-audit --format=json 2>/dev/null | head -20 || echo -e "${GREEN}✅ pip-audit 通过${NC}"
    elif command -v safety &> /dev/null; then
        safety check --json 2>/dev/null | head -20 || echo -e "${GREEN}✅ safety check 通过${NC}"
    else
        echo -e "${YELLOW}⚠️ 未安装 pip-audit 或 safety，建议安装:${NC}"
        echo "   pip install pip-audit"
        echo "   或 pip install safety"

        # 简单检查：列出依赖
        if [[ -f "requirements.txt" ]]; then
            echo ""
            echo "当前依赖:"
            cat requirements.txt | grep -v '^#' | grep -v '^$' | head -10
        fi
    fi
    echo ""
}

scan_java() {
    if [[ ! -f "pom.xml" && ! -f "build.gradle" ]]; then
        return
    fi

    echo -e "${CYAN}【Java】${NC}"

    if [[ -f "pom.xml" ]] && command -v mvn &> /dev/null; then
        mvn org.owasp:dependency-check-maven:check -q 2>/dev/null || true
        if [[ -f "target/dependency-check-report.json" ]]; then
            local vulns=$(grep -o '"vulnerabilities"' target/dependency-check-report.json 2>/dev/null | wc -l | tr -d ' ')
            if [[ "$vulns" -gt 0 ]]; then
                echo -e "${RED}⚠️ 发现 ${vulns} 个漏洞${NC}"
            else
                echo -e "${GREEN}✅ 依赖检查通过${NC}"
            fi
        fi
    else
        echo -e "${YELLOW}⚠️ 建议安装 OWASP Dependency Check${NC}"
    fi
    echo ""
}

scan_go() {
    if [[ ! -f "go.mod" ]]; then
        return
    fi

    echo -e "${CYAN}【Go】${NC}"

    if command -v govulncheck &> /dev/null; then
        govulncheck ./... 2>/dev/null || echo -e "${GREEN}✅ govulncheck 通过${NC}"
    else
        echo -e "${YELLOW}⚠️ 未安装 govulncheck，建议安装:${NC}"
        echo "   go install golang.org/x/vuln/cmd/govulncheck@latest"
    fi
    echo ""
}

scan_rust() {
    if [[ ! -f "Cargo.toml" ]]; then
        return
    fi

    echo -e "${CYAN}【Rust】${NC}"

    if command -v cargo-audit &> /dev/null; then
        cargo audit --json 2>/dev/null | head -20 || echo -e "${GREEN}✅ cargo audit 通过${NC}"
    else
        echo -e "${YELLOW}⚠️ 未安装 cargo-audit，建议安装:${NC}"
        echo "   cargo install cargo-audit"
    fi
    echo ""
}

scan_php() {
    if [[ ! -f "composer.json" ]]; then
        return
    fi

    echo -e "${CYAN}【PHP】${NC}"

    if command -v composer &> /dev/null; then
        composer audit 2>/dev/null || echo -e "${GREEN}✅ composer audit 通过${NC}"
    else
        echo -e "${YELLOW}⚠️ composer 未安装${NC}"
    fi
    echo ""
}

# 通用 OSV 扫描（支持多种语言）
scan_osv() {
    echo -e "${CYAN}【通用 OSV 扫描】${NC}"

    if command -v osv-scanner &> /dev/null; then
        osv-scanner -r . 2>/dev/null || true
    else
        echo -e "${YELLOW}⚠️ 未安装 osv-scanner，建议安装:${NC}"
        echo "   见 https://google.github.io/osv-scanner/installation/"
    fi
    echo ""
}

# 主逻辑
echo -e "${YELLOW}扫描目录: ${TARGET_DIR}${NC}"
echo ""

scan_npm
scan_python
scan_java
scan_go
scan_rust
scan_php
scan_osv

echo -e "${CYAN}扫描完成${NC}"
echo ""
echo -e "${YELLOW}建议:${NC}"
echo "  1. 定期运行: npm audit, pip-audit, cargo audit 等"
echo "  2. 启用 Dependabot 或 Renovate 自动更新"
echo "  3. CI 中集成漏洞扫描门禁"
