#!/bin/bash
# 代码复杂度分析脚本
# 分析圈复杂度、函数长度、文件行数

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

TARGET_DIR="${1:-.}"
SEVERITY="${2:-standard}"  # quick, standard, deep

echo -e "${CYAN}📊 Code Complexity Analysis / 代码复杂度分析${NC}"
echo "=========================================="
echo ""

cd "$TARGET_DIR"

# 获取变更文件
CHANGED_FILES=$(git diff --name-only HEAD~1..HEAD 2>/dev/null || git diff --name-only 2>/dev/null || true)

if [[ -z "$CHANGED_FILES" ]]; then
    echo -e "${YELLOW}无变更文件${NC}"
    exit 0
fi

# 1. 文件统计
echo -e "${CYAN}【文件规模】${NC}"
printf '%s\n' "$CHANGED_FILES" | while read -r file; do
    if [[ -f "$file" ]]; then
        lines=$(wc -l < "$file" | tr -d ' ')
        if [[ $lines -gt 500 ]]; then
            echo -e "  ${RED}🔴 ${file}: ${lines} 行 (过大)${NC}"
        elif [[ $lines -gt 300 ]]; then
            echo -e "  ${YELLOW}🟡 ${file}: ${lines} 行 (偏大)${NC}"
        else
            echo -e "  ${GREEN}🟢 ${file}: ${lines} 行${NC}"
        fi
    fi
done
echo ""

# 2. 函数长度分析（按语言）
echo -e "${CYAN}【函数长度检测】${NC}"

# JavaScript/TypeScript
js_files=$(printf '%s\n' "$CHANGED_FILES" | grep -E '\.(js|ts|jsx|tsx)$' || true)
if [[ -n "$js_files" ]]; then
    echo "  JavaScript/TypeScript:"
    printf '%s\n' "$js_files" | while read -r file; do
        if [[ -f "$file" ]]; then
            # 简单检测：函数定义到下一个函数定义之间的行数
            awk '/^(export )?(async )?function [a-zA-Z_]/ || /^(const|let|var) [a-zA-Z_]+ = (async )?<<?<function|<<?<=\(|=>/ || /^(class|interface|type) [a-zA-Z_]/ {
                if (func_start > 0) {
                    len = NR - func_start
                    if (len > 50) print "    🔴 " func_name ": " len " 行"
                    else if (len > 30) print "    🟡 " func_name ": " len " 行"
                }
                func_start = NR
                func_name = $0
            }' "$file" 2>/dev/null || true
        fi
    done
    echo ""
fi

# Python
py_files=$(printf '%s\n' "$CHANGED_FILES" | grep -E '\.py$' || true)
if [[ -n "$py_files" ]]; then
    echo "  Python:"
    printf '%s\n' "$py_files" | while read -r file; do
        if [[ -f "$file" ]]; then
            awk '/^def [a-zA-Z_]/ || /^class [a-zA-Z_]/ {
                if (func_start > 0) {
                    len = NR - func_start
                    if (len > 50) print "    🔴 " func_name ": " len " 行"
                    else if (len > 30) print "    🟡 " func_name ": " len " 行"
                }
                func_start = NR
                func_name = $0
            }' "$file" 2>/dev/null || true
        fi
    done
    echo ""
fi

# Java
java_files=$(printf '%s\n' "$CHANGED_FILES" | grep -E '\.(java|kt)$' || true)
if [[ -n "$java_files" ]]; then
    echo "  Java/Kotlin:"
    printf '%s\n' "$java_files" | while read -r file; do
        if [[ -f "$file" ]]; then
            awk '/^(public |private |protected )?(static )?[a-zA-Z<>\[\]]+ [a-zA-Z_]/ {
                if (func_start > 0) {
                    len = NR - func_start
                    if (len > 50) print "    🔴 " func_name ": " len " 行"
                    else if (len > 30) print "    🟡 " func_name ": " len " 行"
                }
                func_start = NR
                func_name = $0
            }' "$file" 2>/dev/null || true
        fi
    done
    echo ""
fi

# 3. 圈复杂度估算（简化版）
if [[ "$SEVERITY" == "deep" ]]; then
    echo -e "${CYAN}【圈复杂度估算】${NC}"
    echo "  (基于条件分支数量估算)"
    echo ""

    printf '%s\n' "$CHANGED_FILES" | while read -r file; do
        if [[ -f "$file" ]]; then
            # 统计 if/for/while/switch/try/&&/||/?: 等分支点
            branches=$(grep -cE '\b(if|for|while|switch|catch|\|\||&&|\?\s*:)' "$file" 2>/dev/null || echo 0)
            if [[ "$branches" -gt 15 ]]; then
                echo -e "  ${RED}🔴 ${file}: ~${branches} 个分支点 (高复杂度)${NC}"
            elif [[ "$branches" -gt 10 ]]; then
                echo -e "  ${YELLOW}🟡 ${file}: ~${branches} 个分支点 (中复杂度)${NC}"
            fi
        fi
    done
    echo ""
fi

# 4. 代码重复检测（简化版）
echo -e "${CYAN}【代码重复检测】${NC}"

# 检测相同的连续行（5行以上）
dup_found=false
for file in $(printf '%s\n' "$CHANGED_FILES" | head -20); do
    if [[ -f "$file" ]]; then
        # 提取非空行，排序后检测重复
        dups=$(grep -v '^\s*$' "$file" 2>/dev/null | sort | uniq -d | head -5 || true)
        if [[ -n "$dups" ]]; then
            echo -e "  ${YELLOW}🟡 ${file} 发现重复行:${NC}"
            printf '%s\n' "$dups" | sed 's/^/    /' | head -3
            dup_found=true
        fi
    fi
done

if [[ "$dup_found" == false ]]; then
    echo -e "  ${GREEN}✅ 未发现明显重复代码${NC}"
fi

echo ""
echo -e "${GREEN}✅ 复杂度分析完成${NC}"
echo ""
echo -e "${YELLOW}建议阈值:${NC}"
echo "  文件大小: < 300 行"
echo "  函数长度: < 30 行"
echo "  圈复杂度: < 10"
