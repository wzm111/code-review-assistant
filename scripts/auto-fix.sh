#!/bin/bash
# 自动修复模式
# 对审查发现的简单问题自动生成并应用修复

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

TARGET_DIR="${1:-.}"
APPLY="${2:-}"

echo -e "${CYAN}${BOLD}🔧 Auto-Fix / 自动修复模式${NC}"
echo "=============================================="
echo ""

cd "$TARGET_DIR"

DRY_RUN=true
if [[ "$APPLY" == "--apply" || "$APPLY" == "-a" ]]; then
    DRY_RUN=false
    echo -e "${YELLOW}⚠️  应用模式：将直接修改文件！${NC}"
    echo ""
else
    echo -e "${BLUE}💡 预览模式：仅显示修复内容，不修改文件${NC}"
    echo -e "${BLUE}   使用 --apply 参数应用修复${NC}"
    echo ""
fi

FIX_COUNT=0
SKIP_COUNT=0

# ===== 修复函数 =====

apply_or_preview() {
    local file="$1"
    local desc="$2"
    local fix_cmd="$3"

    if [[ "$DRY_RUN" == true ]]; then
        echo -e "  ${YELLOW}[PREVIEW]${NC} ${desc}"
        echo -e "  ${BLUE}File: ${file}${NC}"
        # 显示 diff
        cp "$file" "/tmp/autofix_$(basename "$file")_backup"
        eval "$fix_cmd"
        diff -u "/tmp/autofix_$(basename "$file")_backup" "$file" || true
        cp "/tmp/autofix_$(basename "$file")_backup" "$file"
        rm -f "/tmp/autofix_$(basename "$file")_backup"
        SKIP_COUNT=$((SKIP_COUNT + 1))
    else
        echo -e "  ${GREEN}[APPLIED]${NC} ${desc}"
        eval "$fix_cmd"
        FIX_COUNT=$((FIX_COUNT + 1))
    fi
}

# ===== 1. 去除行尾空格 =====

echo -e "${CYAN}【1. 去除行尾空格】${NC}"
echo ""

TRAILING_FILES=$(git grep -I -l '[[:space:]]$' -- '*.js' '*.ts' '*.jsx' '*.tsx' '*.py' '*.go' '*.java' '*.kt' '*.php' '*.md' '*.json' '*.yml' '*.yaml' '*.sh' 2>/dev/null || true)

if [[ -n "$TRAILING_FILES" ]]; then
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        apply_or_preview "$file" "去除行尾空格" "sed -i '' 's/[[:space:]]*$//' '$file'"
    done <<< "$TRAILING_FILES"
else
    echo -e "  ${GREEN}✅ 无行尾空格问题${NC}"
fi
echo ""

# ===== 2. 确保文件末尾有换行 =====

echo -e "${CYAN}【2. 确保文件末尾有换行】${NC}"
echo ""

NO_NL_FILES=$(git grep -I -l '' -- '*.js' '*.ts' '*.jsx' '*.tsx' '*.py' '*.go' '*.java' '*.kt' '*.php' '*.json' '*.yml' '*.yaml' '*.sh' 2>/dev/null | while read -r f; do [[ -n "$(tail -c1 "$f")" ]] && echo "$f"; done || true)

if [[ -n "$NO_NL_FILES" ]]; then
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        apply_or_preview "$file" "添加文件末尾换行" "echo '' >> '$file'"
    done <<< "$NO_NL_FILES"
else
    echo -e "  ${GREEN}✅ 文件末尾换行正常${NC}"
fi
echo ""

# ===== 3. 格式化（如果存在工具） =====

echo -e "${CYAN}【3. 代码格式化】${NC}"
echo ""

# Prettier (JS/TS)
if command -v npx &>/dev/null && [[ -f "package.json" ]]; then
    PRETTIER_FILES=$(git diff --name-only HEAD~1..HEAD 2>/dev/null | grep -E '\.(js|ts|jsx|tsx|json|md|yml|yaml)$' || true)
    if [[ -n "$PRETTIER_FILES" ]]; then
        if npx prettier --version &>/dev/null; then
            echo -e "  ${BLUE}运行 Prettier...${NC}"
            if [[ "$DRY_RUN" == true ]]; then
                printf '%s\n' "$PRETTIER_FILES" | xargs npx prettier --check 2>/dev/null || true
                SKIP_COUNT=$((SKIP_COUNT + $(printf '%s\n' "$PRETTIER_FILES" | wc -l | tr -d ' ')))
            else
                printf '%s\n' "$PRETTIER_FILES" | xargs npx prettier --write 2>/dev/null || true
                FIX_COUNT=$((FIX_COUNT + $(printf '%s\n' "$PRETTIER_FILES" | wc -l | tr -d ' ')))
                echo -e "  ${GREEN}✅ Prettier 格式化完成${NC}"
            fi
        fi
    fi
fi

# Black (Python)
if command -v black &>/dev/null; then
    PY_FILES=$(git diff --name-only HEAD~1..HEAD 2>/dev/null | grep '\.py$' || true)
    if [[ -n "$PY_FILES" ]]; then
        echo -e "  ${BLUE}运行 Black...${NC}"
        if [[ "$DRY_RUN" == true ]]; then
            printf '%s\n' "$PY_FILES" | xargs black --check 2>/dev/null || true
            SKIP_COUNT=$((SKIP_COUNT + $(printf '%s\n' "$PY_FILES" | wc -l | tr -d ' ')))
        else
            printf '%s\n' "$PY_FILES" | xargs black 2>/dev/null || true
            FIX_COUNT=$((FIX_COUNT + $(printf '%s\n' "$PY_FILES" | wc -l | tr -d ' ')))
            echo -e "  ${GREEN}✅ Black 格式化完成${NC}"
        fi
    fi
fi

# gofmt (Go)
if command -v gofmt &>/dev/null; then
    GO_FILES=$(git diff --name-only HEAD~1..HEAD 2>/dev/null | grep '\.go$' || true)
    if [[ -n "$GO_FILES" ]]; then
        echo -e "  ${BLUE}运行 gofmt...${NC}"
        if [[ "$DRY_RUN" == true ]]; then
            printf '%s\n' "$GO_FILES" | xargs gofmt -l 2>/dev/null || true
            SKIP_COUNT=$((SKIP_COUNT + $(printf '%s\n' "$GO_FILES" | wc -l | tr -d ' ')))
        else
            printf '%s\n' "$GO_FILES" | xargs gofmt -w 2>/dev/null || true
            FIX_COUNT=$((FIX_COUNT + $(printf '%s\n' "$GO_FILES" | wc -l | tr -d ' ')))
            echo -e "  ${GREEN}✅ gofmt 格式化完成${NC}"
        fi
    fi
fi

echo ""

# ===== 4. 修复未使用的 import（JS/TS 简单场景） =====

echo -e "${CYAN}【4. 清理未使用的 import（JS/TS）】${NC}"
echo ""

JS_FILES=$(git diff --name-only HEAD~1..HEAD 2>/dev/null | grep -E '\.(js|ts|jsx|tsx)$' || true)

if [[ -n "$JS_FILES" ]]; then
    UNUSED_FOUND=false
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        [[ -f "$file" ]] || continue

        # 简单检测：查找 import 语句，检查是否在文件中使用
        imports=$(grep -nE "^\s*import\s+\{[^}]+\}" "$file" 2>/dev/null || true)
        if [[ -n "$imports" ]]; then
            while IFS= read -r import_line; do
                [[ -z "$import_line" ]] && continue
                # 提取导入的变量名
                vars=$(printf '%s\n' "$import_line" | grep -oE '\{[^}]+\}' | tr -d '{}' | tr ',' '\n' | sed 's/ //g' || true)
                if [[ -n "$vars" ]]; then
                    while IFS= read -r var; do
                        [[ -z "$var" ]] && continue
                        # 检查是否在 import 语句之外使用
                        usages=$(grep -cE "\b${var}\b" "$file" 2>/dev/null || echo "0")
                        if [[ "$usages" -le 1 ]]; then
                            echo -e "  ${YELLOW}⚠️  ${file}: 未使用的 import '${var}'${NC}"
                            UNUSED_FOUND=true
                            # 这里不自动删除，因为可能误伤，仅标记
                            SKIP_COUNT=$((SKIP_COUNT + 1))
                        fi
                    done <<< "$vars"
                fi
            done <<< "$imports"
        fi
    done <<< "$JS_FILES"

    if [[ "$UNUSED_FOUND" == false ]]; then
        echo -e "  ${GREEN}✅ 未发现明显的未使用 import${NC}"
    fi
else
    echo -e "  ${GREEN}✅ 无 JS/TS 文件变更${NC}"
fi
echo ""

# ===== 5. 修复简单的常量命名（Python UPPER_SNAKE_CASE） =====

echo -e "${CYAN}【5. 常量命名修复（Python）】${NC}"
echo ""

PY_FILES_CHANGED=$(git diff --name-only HEAD~1..HEAD 2>/dev/null | grep '\.py$' || true)

if [[ -n "$PY_FILES_CHANGED" ]]; then
    PY_FIX_FOUND=false
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        [[ -f "$file" ]] || continue

        # 查找顶层的 camelCase 或 PascalCase 常量
        # 模式：全大写字母开头的赋值
        lines=$(grep -nE "^[A-Z][a-zA-Z0-9_]*\s*=" "$file" 2>/dev/null | grep -vE "^[A-Z_]+\s*=" || true)
        if [[ -n "$lines" ]]; then
            while IFS= read -r line; do
                [[ -z "$line" ]] && continue
                lineno=$(printf '%s\n' "$line" | cut -d: -f1)
                old_name=$(printf '%s\n' "$line" | grep -oE '^[A-Z][a-zA-Z0-9_]*' || true)
                new_name=$(printf '%s\n' "$old_name" | sed -E 's/([a-z0-9])([A-Z])/\1_\2/g' | tr '[:lower:]' '[:upper:]')

                if [[ "$old_name" != "$new_name" ]]; then
                    echo -e "  ${YELLOW}⚠️  ${file}:${lineno} '${old_name}' → '${new_name}'${NC}"
                    if [[ "$DRY_RUN" == false ]]; then
                        sed -i '' "${lineno}s/\b${old_name}\b/${new_name}/g" "$file"
                        FIX_COUNT=$((FIX_COUNT + 1))
                    else
                        SKIP_COUNT=$((SKIP_COUNT + 1))
                    fi
                    PY_FIX_FOUND=true
                fi
            done <<< "$lines"
        fi
    done <<< "$PY_FILES_CHANGED"

    if [[ "$PY_FIX_FOUND" == false ]]; then
        echo -e "  ${GREEN}✅ 常量命名正常${NC}"
    fi
else
    echo -e "  ${GREEN}✅ 无 Python 文件变更${NC}"
fi
echo ""

# ===== 6. 修复 EOF 问题 =====

echo -e "${CYAN}【6. 修复文件格式问题】${NC}"
echo ""

# 检查并修复 BOM
BOM_FILES=$(find . -maxdepth 3 -type f \( -name '*.js' -o -name '*.ts' -o -name '*.json' -o -name '*.md' \) -exec file {} \; 2>/dev/null | grep 'UTF-8 (with BOM)' | cut -d: -f1 || true)
if [[ -n "$BOM_FILES" ]]; then
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        echo -e "  ${YELLOW}⚠️  ${file}: 包含 BOM${NC}"
        if [[ "$DRY_RUN" == false ]]; then
            tail -c +4 "$file" > "$file.tmp" && mv "$file.tmp" "$file"
            FIX_COUNT=$((FIX_COUNT + 1))
        else
            SKIP_COUNT=$((SKIP_COUNT + 1))
        fi
    done <<< "$BOM_FILES"
else
    echo -e "  ${GREEN}✅ 无 BOM 问题${NC}"
fi
echo ""

# ===== 汇总 =====

echo -e "${CYAN}${BOLD}【修复汇总】${NC}"
echo "======================================"
echo ""

if [[ "$DRY_RUN" == true ]]; then
    echo -e "  ${YELLOW}预览模式 — 共发现 ${SKIP_COUNT} 处可修复问题${NC}"
    echo ""
    echo -e "  ${CYAN}使用以下命令应用修复:${NC}"
    echo "    bash scripts/auto-fix.sh . --apply"
    echo ""
    # 创建标记文件供 GitHub Actions 检测
    echo "$SKIP_COUNT" > .autofix_candidates
    echo -e "  ${BLUE}已生成 .autofix_candidates 文件 (${SKIP_COUNT} 个候选修复)${NC}"
else
    echo -e "  ${GREEN}已应用 ${FIX_COUNT} 处修复${NC}"
    echo ""
    # 创建标记文件
    touch .autofix_applied
    echo -e "  ${GREEN}已生成 .autofix_applied 标记文件${NC}"
fi

echo ""
