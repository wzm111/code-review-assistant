#!/bin/bash
# 代码复用性检查
# 检测重复代码、复制粘贴、相似逻辑未抽象等问题

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

TARGET_DIR="${1:-.}"
MIN_LINES="${2:-5}"

echo -e "${CYAN}♻️ Reuse Check / 代码复用性检查${NC}"
echo "=========================================="
echo ""

cd "$TARGET_DIR"

CHANGED_FILES=$(git diff --name-only HEAD~1..HEAD 2>/dev/null | grep -E '\.(js|ts|jsx|tsx|vue|py|go|java|php|rb|swift|kt|dart|rs|c|cpp|h|m|mm)$' || true)

if [[ -z "$CHANGED_FILES" ]]; then
    echo -e "${YELLOW}无源码文件变更${NC}"
    exit 0
fi

duplicate_blocks=()
similar_functions=()
magic_values=()

echo -e "${CYAN}【分析变更文件】${NC}"
echo ""

# 收集所有变更文件的内容用于对比
all_content=""
while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    [[ -f "$file" ]] || continue
    content=$(cat "$file" 2>/dev/null || true)
    [[ -z "$content" ]] && continue
    all_content+="\n===== $file =====\n$content"
done <<< "$CHANGED_FILES"

# 1. 检测重复代码块（基于行的完全匹配）
echo -e "${CYAN}【1. 重复代码块检测】${NC}"

while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    [[ -f "$file" ]] || continue

    # 提取非空、非注释行，计算指纹
    stripped=$(grep -vE '^\s*(//|#|\*|/\*|\*/|\*|\s*\*\s|import|from|package|using|include)' "$file" 2>/dev/null | \
               sed 's/\s//g' | grep -v '^$' || true)

    [[ -z "$stripped" ]] && continue

    # 检测连续重复行（简化实现）
    dupes=$(printf '%s\n' "$stripped" | sort | uniq -d | head -10 || true)
    if [[ -n "$dupes" ]]; then
        dup_count=$(printf '%s\n' "$dupes" | wc -l | tr -d ' ')
        if [[ "$dup_count" -ge 3 ]]; then
            duplicate_blocks+=("$file: 发现 $dup_count 处重复行模式")
        fi
    fi
done <<< "$CHANGED_FILES"

if [[ ${#duplicate_blocks[@]} -gt 0 ]]; then
    for item in "${duplicate_blocks[@]}"; do
        echo -e "  ${YELLOW}⚠️ $item${NC}"
    done
else
    echo -e "  ${GREEN}✅ 未检测到明显重复代码块${NC}"
fi

echo ""

# 2. 检测相似函数（基于函数名和参数模式）
echo -e "${CYAN}【2. 相似函数检测】${NC}"

# 提取所有函数定义
func_signatures=""
while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    [[ -f "$file" ]] || continue

    content=$(cat "$file" 2>/dev/null || true)
    [[ -z "$content" ]] && continue

    # 提取函数签名（简化）
    if [[ "$file" =~ \.(js|ts|jsx|tsx|vue)$ ]]; then
        sigs=$(printf '%s\n' "$content" | grep -oE '(function\s+\w+|const\s+\w+\s*=\s*(async\s*)?\(|\w+\s*\([^)]*\)\s*\{)' | head -20 || true)
    elif [[ "$file" =~ \.(py)$ ]]; then
        sigs=$(printf '%s\n' "$content" | grep -oE 'def\s+\w+\s*\([^)]*\)' | head -20 || true)
    elif [[ "$file" =~ \.(go)$ ]]; then
        sigs=$(printf '%s\n' "$content" | grep -oE 'func\s+(\([^)]*\)\s+)?\w+\s*\([^)]*\)' | head -20 || true)
    elif [[ "$file" =~ \.(java|kt)$ ]]; then
        sigs=$(printf '%s\n' "$content" | grep -oE '(public|private|protected)\s+(static\s+)?\w+\s+\w+\s*\([^)]*\)' | head -20 || true)
    fi

    if [[ -n "$sigs" ]]; then
        func_signatures+="$sigs\n"
    fi
done <<< "$CHANGED_FILES"

# 检测相似函数名（如 getUserById / getUserByName / getUserByEmail）
if [[ -n "$func_signatures" ]]; then
    similar=$(echo -e "$func_signatures" | grep -oE '\w+' | sort | uniq -c | sort -rn | awk '$1 > 1 {print}' | head -10 || true)
    if [[ -n "$similar" ]]; then
        echo -e "  ${YELLOW}⚠️ 检测到可能的重复函数模式:${NC}"
        printf '%s\n' "$similar" | sed 's/^/    /'
        similar_functions+=("存在相似命名函数，建议抽象为通用函数")
    else
        echo -e "  ${GREEN}✅ 函数命名无重复模式${NC}"
    fi
else
    echo -e "  ${YELLOW}⚠️ 未提取到函数签名${NC}"
fi

echo ""

# 3. 检测魔法值/字符串重复
echo -e "${CYAN}【3. 魔法值/字符串重复检测】${NC}"

all_strings=""
while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    [[ -f "$file" ]] || continue

    content=$(cat "$file" 2>/dev/null || true)
    [[ -z "$content" ]] && continue

    # 提取字符串字面量（长度 3-30）
    strings=$(printf '%s\n' "$content" | grep -oE "['\"][A-Za-z0-9_\-\s]{3,30}['\"]" | grep -vE "^['\"](import|from|return|function|class|const|let|var|if|else|for|while)['\"]$" || true)
    if [[ -n "$strings" ]]; then
        all_strings+="$strings\n"
    fi
done <<< "$CHANGED_FILES"

if [[ -n "$all_strings" ]]; then
    repeated=$(echo -e "$all_strings" | sort | uniq -c | sort -rn | awk '$1 >= 2 && length($2) > 5 {print}' | head -10 || true)
    if [[ -n "$repeated" ]]; then
        echo -e "  ${YELLOW}⚠️ 以下字符串在多处重复出现:${NC}"
        printf '%s\n' "$repeated" | sed 's/^/    /'
        magic_values+=("重复字符串应提取为常量")
    else
        echo -e "  ${GREEN}✅ 字符串使用较合理${NC}"
    fi
else
    echo -e "  ${YELLOW}⚠️ 未提取到字符串${NC}"
fi

echo ""

# 4. 检测重复配置/常量定义
echo -e "${CYAN}【4. 配置/常量重复检测】${NC}"

config_patterns=""
while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    [[ -f "$file" ]] || continue

    content=$(cat "$file" 2>/dev/null || true)
    [[ -z "$content" ]] && continue

    # 提取常量定义
    if [[ "$file" =~ \.(js|ts|jsx|tsx)$ ]]; then
        consts=$(printf '%s\n' "$content" | grep -oE 'const\s+[A-Z_]+\s*=\s*[^;]+' | head -20 || true)
    elif [[ "$file" =~ \.(py)$ ]]; then
        consts=$(printf '%s\n' "$content" | grep -oE '[A-Z_]+\s*=\s*[^#]+' | head -20 || true)
    elif [[ "$file" =~ \.(go)$ ]]; then
        consts=$(printf '%s\n' "$content" | grep -oE 'const\s+\w+\s*=\s*[^/]+' | head -20 || true)
    fi

    if [[ -n "$consts" ]]; then
        config_patterns+="$consts\n"
    fi
done <<< "$CHANGED_FILES"

if [[ -n "$config_patterns" ]]; then
    # 检查常量名是否在多个文件中重复定义
    dup_consts=$(echo -e "$config_patterns" | grep -oE '[A-Z_]+' | sort | uniq -c | sort -rn | awk '$1 >= 2 {print}' | head -5 || true)
    if [[ -n "$dup_consts" ]]; then
        echo -e "  ${YELLOW}⚠️ 以下常量名在多处定义:${NC}"
        printf '%s\n' "$dup_consts" | sed 's/^/    /'
        echo -e "  ${YELLOW}建议: 提取到统一的 constants/config 文件${NC}"
    else
        echo -e "  ${GREEN}✅ 常量定义无重复${NC}"
    fi
else
    echo -e "  ${YELLOW}⚠️ 未检测到常量定义${NC}"
fi

echo ""

# 5. 跨文件重复逻辑检测
echo -e "${CYAN}【5. 跨文件重复逻辑检测】${NC}"

# 简化的：检测相同的 import 模式、相同的错误处理模式等
if [[ $(printf '%s\n' "$CHANGED_FILES" | wc -l | tr -d ' ') -gt 1 ]]; then
    # 检测多个文件中相同的错误处理
    error_patterns=$(printf '%s\n' "$all_content" | grep -oE '(catch|except)\s*\([^)]*\)\s*\{' | sort | uniq -c | sort -rn | awk '$1 >= 2 {print}' | head -3 || true)
    if [[ -n "$error_patterns" ]]; then
        echo -e "  ${YELLOW}⚠️ 多个文件使用相似的错误处理模式，建议抽象为通用错误处理:${NC}"
        printf '%s\n' "$error_patterns" | sed 's/^/    /'
    else
        echo -e "  ${GREEN}✅ 跨文件逻辑较合理${NC}"
    fi
else
    echo -e "  ${YELLOW}ℹ️ 仅单个文件变更，跳过跨文件检测${NC}"
fi

echo ""

# 总结
echo -e "${CYAN}【复用性评分】${NC}"
issue_count=$((${#duplicate_blocks[@]} + ${#similar_functions[@]} + ${#magic_values[@]}))

if [[ "$issue_count" -eq 0 ]]; then
    echo -e "  ${GREEN}✅ 代码复用性良好${NC}"
elif [[ "$issue_count" -le 2 ]]; then
    echo -e "  ${YELLOW}🟡 复用性一般，有 $issue_count 处可优化${NC}"
else
    echo -e "  ${RED}🔴 复用性较差，发现 $issue_count 处重复/相似代码${NC}"
fi

echo ""
echo -e "${CYAN}【复用性优化建议】${NC}"
echo "  1. 提取重复代码为通用函数/工具类"
echo "  2. 相似函数使用策略模式或高阶函数"
echo "  3. 魔法值/字符串提取为命名常量"
echo "  4. 重复的配置项集中到统一配置文件"
echo "  5. 跨文件共享逻辑封装到 utils/service 层"
echo "  6. 使用 DRY 原则：Don't Repeat Yourself"
