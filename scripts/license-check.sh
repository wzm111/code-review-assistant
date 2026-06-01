#!/bin/bash
# 许可证合规检查
# 扫描新增依赖的许可证，防止引入 GPL 等传染性许可证

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

TARGET_DIR="${1:-.}"

echo -e "${CYAN}📜 License Check / 许可证合规检查${NC}"
echo "=========================================="
echo ""

cd "$TARGET_DIR"

# 检测包管理文件变更
PKG_FILES=$(git diff --name-only HEAD~1..HEAD 2>/dev/null | grep -E 'package\.json|requirements\.txt|go\.mod|Cargo\.toml|composer\.json|pom\.xml|build\.gradle' || true)

if [[ -z "$PKG_FILES" ]]; then
    echo -e "${YELLOW}未检测到依赖文件变更${NC}"
    exit 0
fi

echo -e "${CYAN}【变更的依赖文件】${NC}"
printf '%s\n' "$PKG_FILES" | sed 's/^/  /'
echo ""

# 定义风险等级
HIGH_RISK=("GPL" "AGPL" "LGPL" "SSPL" "ODbL" "EPL")
MEDIUM_RISK=("MPL" "CDDL" "CPL" "EPL")
SAFE=("MIT" "Apache" "BSD" "ISC" "WTFPL" "Unlicense" "CC0" "Zlib")

violations=()
warnings=()

# JavaScript / npm
if printf '%s\n' "$PKG_FILES" | grep -q "package"; then
    echo -e "${CYAN}【npm 依赖分析】${NC}"

    if [[ -f "package.json" ]] && command -v npm &>/dev/null; then
        # 获取新增依赖
        current=$(cat package.json | grep -A 100 '"dependencies"' | grep -v "^--" | head -50)
        prev=$(git show HEAD~1:package.json 2>/dev/null | grep -A 100 '"dependencies"' | grep -v "^--" | head -50 || true)

        # 尝试列出所有依赖的许可证（如果 package-lock 存在）
        if [[ -f "package-lock.json" ]] && command -v npx &>/dev/null; then
            # 尝试使用 license-checker
            if npx license-checker --json > /tmp/licenses.json 2>/dev/null; then
                # 简化：只检查新增的直接依赖
                for license in "${HIGH_RISK[@]}"; do
                    found=$(cat /tmp/licenses.json | grep -i "$license" | head -5 || true)
                    if [[ -n "$found" ]]; then
                        violations+=("npm: 发现 $license 许可证依赖")
                    fi
                done
            fi
        fi
    fi
fi

# Python
if printf '%s\n' "$PKG_FILES" | grep -q "requirements"; then
    echo -e "${CYAN}【Python 依赖分析】${NC}"
    # Python 许可证检查较为复杂，简化处理
    echo "  ${YELLOW}⚠️ Python 许可证需手动检查 (pip-licenses)${NC}"
    echo "    运行: pip install pip-licenses && pip-licenses --format=json"
fi

# Go
if printf '%s\n' "$PKG_FILES" | grep -q "go\.mod"; then
    echo -e "${CYAN}【Go 依赖分析】${NC}"
    if command -v go &>/dev/null; then
        # go-licenses 工具
        if command -v go-licenses &>/dev/null; then
            go-licenses csv . 2>/dev/null | while IFS="," read -r pkg url license; do
                for risk in "${HIGH_RISK[@]}"; do
                    if printf '%s\n' "$license" | grep -qi "$risk"; then
                        violations+=("Go: $pkg -> $license")
                    fi
                done
            done
        else
            echo "  ${YELLOW}⚠️ go-licenses 未安装${NC}"
            echo "    go install github.com/google/go-licenses@latest"
        fi
    fi
fi

# Java
if printf '%s\n' "$PKG_FILES" | grep -qE "pom|gradle"; then
    echo -e "${CYAN}【Java 依赖分析】${NC}"
    echo "  ${YELLOW}⚠️ Java 许可证需手动检查${NC}"
    echo "    Maven: mvn org.codehaus.mojo:license-maven-plugin:aggregate-third-party-report"
fi

echo ""
echo -e "${CYAN}【审查结果】${NC}"
echo ""

if [[ ${#violations[@]} -gt 0 ]]; then
    echo -e "${RED}🔴 高风险许可证 (传染性强，可能污染整个项目):${NC}"
    for v in "${violations[@]}"; do
        echo "  - $v"
    done
    echo ""
    echo -e "${YELLOW}高风险许可证说明:${NC}"
    echo "  GPL/AGPL: 衍生作品必须开源"
    echo "  SSPL: 服务端使用需开源"
fi

if [[ ${#warnings[@]} -gt 0 ]]; then
    echo -e "${YELLOW}🟡 中等风险:${NC}"
    for w in "${warnings[@]}"; do
        echo "  - $w"
    done
fi

if [[ ${#violations[@]} -eq 0 && ${#warnings[@]} -eq 0 ]]; then
    echo -e "  ${GREEN}✅ 未检测到高风险许可证${NC}"
fi

echo ""
echo -e "${CYAN}【许可证合规建议】${NC}"
echo "  1. 优先使用 MIT / Apache-2.0 / BSD 许可证的依赖"
echo "  2. 商业项目避免 GPL/AGPL 依赖"
echo "  3. 在 CI 中集成 license-checker"
echo "  4. 维护允许/禁止的许可证白名单"
echo "  5. 法务审核核心依赖的许可证条款"
