#!/bin/bash
# 自动推荐 Reviewer
# 根据 git 历史分析谁最熟悉被修改的代码

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TARGET_DIR="${1:-.}"

echo -e "${CYAN}👥 Reviewer Assignment / Reviewer 推荐${NC}"
echo "=========================================="
echo ""

cd "$TARGET_DIR"

# 获取变更文件
CHANGED_FILES=$(git diff --name-only HEAD~1..HEAD 2>/dev/null || git diff --name-only 2>/dev/null || true)

if [[ -z "$CHANGED_FILES" ]]; then
    echo -e "${YELLOW}无变更文件${NC}"
    exit 0
fi

echo -e "${CYAN}【变更文件】${NC}"
printf '%s\n' "$CHANGED_FILES" | head -10 | sed 's/^/  /'
[[ $(printf '%s\n' "$CHANGED_FILES" | wc -l) -gt 10 ]] && echo "  ..."
echo ""

# 分析每个文件的历史贡献者
echo -e "${CYAN}【代码熟悉度分析】${NC}"
echo ""

# 使用索引数组替代关联数组（Bash 3.2 兼容）
authors=()
scores=()
files_map=()

# 查找作者索引，找不到返回 -1
get_author_idx() {
    local target="$1"
    local i=0
    while [[ $i -lt ${#authors[@]} ]]; do
        if [[ "${authors[$i]}" == "$target" ]]; then
            echo "$i"
            return 0
        fi
        i=$((i + 1))
    done
    echo "-1"
}

while IFS= read -r file; do
    [[ -z "$file" ]] && continue

    # 获取该文件最近 20 次提交的作者
    file_authors=$(git log -20 --pretty=format:"%an" -- "$file" 2>/dev/null || true)

    if [[ -n "$file_authors" ]]; then
        # 最近的提交权重更高
        line_num=0
        while IFS= read -r author; do
            line_num=$((line_num + 1))
            # 权重: 最近 = 20分, 最远 = 1分
            weight=$((21 - line_num))

            idx=$(get_author_idx "$author")
            if [[ "$idx" == "-1" ]]; then
                authors+=("$author")
                scores+=(0)
                files_map+=("")
                idx=$((${#authors[@]} - 1))
            fi

            scores[$idx]=$((${scores[$idx]} + weight))

            current_files="${files_map[$idx]}"
            if [[ ! "$current_files" =~ "$file" ]]; then
                files_map[$idx]="${current_files}${file},"
            fi
        done <<< "$file_authors"
    fi
done <<< "$CHANGED_FILES"

# 排除当前提交者
current_author=$(git log -1 --pretty=format:"%an" 2>/dev/null || echo "")

# 排序输出
echo "按代码熟悉度排序 (分数越高越熟悉):"
echo ""

# 将数组转为可排序格式
i=0
while [[ $i -lt ${#authors[@]} ]]; do
    author="${authors[$i]}"
    # 跳过当前提交者
    [[ "$author" == "$current_author" ]] && { i=$((i + 1)); continue; }

    score="${scores[$i]}"
    files="${files_map[$i]}"
    file_count=$(printf '%s\n' "$files" | tr ',' '\n' | grep -v '^$' | wc -l | tr -d ' ')

    echo "${score}|${author}|${file_count}|${files}"
    i=$((i + 1))
done | sort -t'|' -k1 -nr | head -5 | while IFS='|' read -r score author file_count files; do

    # 计算熟悉度百分比
    total_files=$(printf '%s\n' "$CHANGED_FILES" | wc -l | tr -d ' ')
    percent=$((file_count * 100 / total_files))

    if [[ $score -ge 50 ]]; then
        echo -e "  ${GREEN}⭐ ${author}${NC}"
    elif [[ $score -ge 20 ]]; then
        echo -e "  ${BLUE}  ${author}${NC}"
    else
        echo -e "  ${YELLOW}  ${author}${NC}"
    fi

    echo "     分数: ${score} | 涉及文件: ${file_count}/${total_files} (${percent}%)"

    # 显示熟悉的具体文件
    printf '%s\n' "$files" | tr ',' '\n' | grep -v '^$' | head -3 | sed 's/^/     - /'
    [[ $(printf '%s\n' "$files" | tr ',' '\n' | grep -v '^$' | wc -l) -gt 3 ]] && echo "     ..."
    echo ""
done

# 推荐 Reviewer
echo -e "${CYAN}【推荐 Reviewer】${NC}"
echo ""

top_reviewer=$(
    i=0
    while [[ $i -lt ${#authors[@]} ]]; do
        author="${authors[$i]}"
        [[ "$author" == "$current_author" ]] && { i=$((i + 1)); continue; }
        echo "${scores[$i]}|${author}"
        i=$((i + 1))
    done | sort -t'|' -k1 -nr | head -1
)

if [[ -n "$top_reviewer" ]]; then
    IFS='|' read -r score author <<< "$top_reviewer"
    echo -e "  ${GREEN}主 Reviewer: ${author} (分数: ${score})${NC}"
    echo "  推荐理由: 最熟悉本次变更的代码"
    echo ""
fi

# 如果分数都很低，提示需要 Code Owner
echo -e "${YELLOW}提示:${NC}"
echo "  - 分数 > 50: 非常推荐作为 Reviewer"
echo "  - 分数 20-50: 可以作为 Reviewer"
echo "  - 分数 < 20: 建议同时指定 Code Owner"
echo ""

# 检查是否有 CODEOWNERS
echo -e "${CYAN}【CODEOWNERS 检查】${NC}"
codeowners_files="CODEOWNERS .github/CODEOWNERS docs/CODEOWNERS"
found=false
for f in $codeowners_files; do
    if [[ -f "$f" ]]; then
        echo -e "  ${GREEN}✓ 找到 ${f}${NC}"
        found=true
        break
    fi
done

if [[ "$found" == false ]]; then
    echo -e "  ${YELLOW}⚠️ 未找到 CODEOWNERS 文件${NC}"
    echo "  建议创建 .github/CODEOWNERS 规范代码归属"
fi

echo ""
echo -e "${GREEN}✅ Reviewer 分析完成${NC}"
