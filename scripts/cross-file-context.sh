#!/bin/bash
# 跨文件上下文分析
# 分析变更的跨文件影响：调用链、依赖关系、接口实现、风险评估

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

TARGET_DIR="${1:-.}"
BASE_REF="${2:-HEAD~1}"

echo -e "${CYAN}${BOLD}🔗 Cross-File Context / 跨文件上下文分析${NC}"
echo "=============================================="
echo ""

cd "$TARGET_DIR"

# ===== 获取变更文件 =====
CHANGED_FILES=$(git diff --name-only "$BASE_REF"..HEAD 2>/dev/null || git diff --name-only 2>/dev/null || true)

if [[ -z "$CHANGED_FILES" ]]; then
    echo -e "${YELLOW}无变更文件${NC}"
    exit 0
fi

echo -e "${BLUE}【变更文件】${NC}"
printf '%s\n' "$CHANGED_FILES" | sed 's/^/  /'
echo ""

# ===== 提取变更的函数/类名 =====

declare -a CHANGED_IDENTIFIERS=()

echo -e "${CYAN}【提取变更标识符】${NC}"

while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    [[ -f "$file" ]] || continue

    # 根据语言提取函数/类名
    if [[ "$file" =~ \.(js|ts|jsx|tsx)$ ]]; then
        # JS/TS: function, const, class, export
        ids=$(git diff "$BASE_REF"..HEAD -- "$file" | grep -E '^\+.*\b(function|const|let|var|class|interface|type|export)\b' | grep -oE '\b[a-zA-Z_][a-zA-Z0-9_]*\b' | grep -vE '^(function|const|let|var|class|interface|type|export|default|async|static|private|public|protected|readonly)$' | sort -u || true)
    elif [[ "$file" =~ \.py$ ]]; then
        # Python: def, class
        ids=$(git diff "$BASE_REF"..HEAD -- "$file" | grep -E '^\+.*\b(def|class)\b' | grep -oE '\b[a-zA-Z_][a-zA-Z0-9_]*\b' | grep -vE '^(def|class|self|cls|if|else|elif|for|while|try|except|finally|with|return|yield|pass|break|continue|import|from|as)$' | sort -u || true)
    elif [[ "$file" =~ \.go$ ]]; then
        # Go: func, type, var, const
        ids=$(git diff "$BASE_REF"..HEAD -- "$file" | grep -E '^\+.*\b(func|type|var|const)\b' | grep -oE '\b[a-zA-Z_][a-zA-Z0-9_]*\b' | grep -vE '^(func|type|var|const|struct|interface|map|chan|go|defer|return|if|else|for|range|switch|case|default|package|import)$' | sort -u || true)
    elif [[ "$file" =~ \.(java|kt)$ ]]; then
        # Java/Kotlin: method, class, interface
        ids=$(git diff "$BASE_REF"..HEAD -- "$file" | grep -E '^\+.*\b(public|private|protected|static|final|abstract|void|boolean|int|String|List|Map|Set|Optional|fun|val|var|class|interface|object)\b' | grep -oE '\b[a-zA-Z_][a-zA-Z0-9_]*\b' | grep -vE '^(public|private|protected|static|final|abstract|void|boolean|int|String|List|Map|Set|Optional|fun|val|var|class|interface|object|if|else|for|while|return|try|catch|finally|throw|new|this|super|extends|implements)$' | sort -u || true)
    elif [[ "$file" =~ \.php$ ]]; then
        # PHP: function, class
        ids=$(git diff "$BASE_REF"..HEAD -- "$file" | grep -E '^\+.*\b(function|class|interface|trait)\b' | grep -oE '\b[a-zA-Z_][a-zA-Z0-9_]*\b' | grep -vE '^(function|class|interface|trait|public|private|protected|static|final|abstract|return|if|else|elseif|for|foreach|while|try|catch|finally|throw|new|this|self|parent)$' | sort -u || true)
    else
        ids=""
    fi

    if [[ -n "$ids" ]]; then
        while IFS= read -r id; do
            [[ -z "$id" ]] && continue
            # 过滤常见短词
            [[ "${#id}" -lt 3 ]] && continue
            CHANGED_IDENTIFIERS+=("$id")
            echo -e "  ${GREEN}✓${NC} $file: $id"
        done <<< "$ids"
    fi
done <<< "$CHANGED_FILES"

if [[ ${#CHANGED_IDENTIFIERS[@]} -eq 0 ]]; then
    echo -e "  ${YELLOW}未提取到变更标识符${NC}"
fi
echo ""

# ===== 调用链分析 =====

echo -e "${CYAN}【调用链分析】${NC}"
echo ""

CALLER_COUNT=0
CALLEE_COUNT=0

for id in "${CHANGED_IDENTIFIERS[@]}"; do
    # 谁调用了这个函数
    callers=$(git grep -n "$id" -- "*.js" "*.ts" "*.jsx" "*.tsx" "*.py" "*.go" "*.java" "*.kt" "*.php" 2>/dev/null | grep -v "^Binary" | head -20 || true)
    if [[ -n "$callers" ]]; then
        CALLER_COUNT=$((CALLER_COUNT + $(printf '%s\n' "$callers" | wc -l)))
        echo -e "  ${BLUE}📞 $id 被调用位置:${NC}"
        printf '%s\n' "$callers" | head -5 | sed 's/^/     /'
        local_count=$(printf '%s\n' "$callers" | wc -l | tr -d ' ')
        if [[ "$local_count" -gt 5 ]]; then
            echo -e "     ${YELLOW}... 还有 $((local_count - 5)) 处${NC}"
        fi
        echo ""
    fi

done

if [[ $CALLER_COUNT -eq 0 ]]; then
    echo -e "  ${YELLOW}未检测到跨文件调用${NC}"
fi
echo ""

# ===== 依赖分析 =====

echo -e "${CYAN}【导入/依赖分析】${NC}"
echo ""

IMPORT_COUNT=0

while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    [[ -f "$file" ]] || continue

    # 获取变更模块名（用于分析谁导入了它）
    module_name=""
    if [[ "$file" =~ \.(js|ts|jsx|tsx)$ ]]; then
        module_name=$(basename "$file" | sed 's/\.[^.]*$//')
    elif [[ "$file" =~ \.py$ ]]; then
        module_name=$(basename "$file" | sed 's/\.[^.]*$//')
    elif [[ "$file" =~ \.go$ ]]; then
        module_name=$(grep -E '^package ' "$file" | head -1 | awk '{print $2}' || true)
    fi

    if [[ -n "$module_name" ]]; then
        # 查找谁导入了这个模块
        if [[ "$file" =~ \.(js|ts|jsx|tsx)$ ]]; then
            importers=$(git grep -lE "(import|require).*['\"].*${module_name}.*['\"]" -- "*.js" "*.ts" "*.jsx" "*.tsx" 2>/dev/null | grep -v "^Binary" | head -10 || true)
        elif [[ "$file" =~ \.py$ ]]; then
            importers=$(git grep -lE "(import|from).*${module_name}" -- "*.py" 2>/dev/null | grep -v "^Binary" | head -10 || true)
        elif [[ "$file" =~ \.go$ ]]; then
            importers=$(git grep -lE "${module_name}\." -- "*.go" 2>/dev/null | grep -v "^Binary" | head -10 || true)
        else
            importers=""
        fi

        if [[ -n "$importers" ]]; then
            local_count=$(printf '%s\n' "$importers" | wc -l | tr -d ' ')
            IMPORT_COUNT=$((IMPORT_COUNT + local_count))
            echo -e "  ${BLUE}📦 $file ($module_name) 被导入次数: ${local_count}${NC}"
            printf '%s\n' "$importers" | sed 's/^/     /'
            echo ""
        fi
    fi
done <<< "$CHANGED_FILES"

if [[ $IMPORT_COUNT -eq 0 ]]; then
    echo -e "  ${YELLOW}未检测到跨模块依赖${NC}"
fi
echo ""

# ===== 接口/实现分析 =====

echo -e "${CYAN}【接口/实现分析】${NC}"
echo ""

INTERFACE_CHANGES=0

while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    [[ -f "$file" ]] || continue

    # 检测接口/抽象类变更
    if [[ "$file" =~ \.(java|kt)$ ]]; then
        # Java/Kotlin: interface, abstract class
        interfaces=$(git diff "$BASE_REF"..HEAD -- "$file" | grep -E '^\+.*\b(interface|abstract\s+class)\b' | grep -oE '\b[A-Z][a-zA-Z0-9_]*\b' | grep -vE '^(interface|abstract|class|public|private|protected|static|final|extends|implements)$' | sort -u || true)
        if [[ -n "$interfaces" ]]; then
            while IFS= read -r iface; do
                [[ -z "$iface" ]] && continue
                # 查找实现类
                impls=$(git grep -lE "implements\s+${iface}|:\s*${iface}" -- "*.java" "*.kt" 2>/dev/null | head -10 || true)
                if [[ -n "$impls" ]]; then
                    INTERFACE_CHANGES=$((INTERFACE_CHANGES + 1))
                    echo -e "  ${YELLOW}⚠️ 接口 ${iface} 发生变更${NC}"
                    echo -e "  ${BLUE}   实现类:${NC}"
                    printf '%s\n' "$impls" | sed 's/^/     /'
                    echo ""
                fi
            done <<< "$interfaces"
        fi
    elif [[ "$file" =~ \.(ts|tsx)$ ]]; then
        # TypeScript: interface
        interfaces=$(git diff "$BASE_REF"..HEAD -- "$file" | grep -E '^\+.*\binterface\b' | grep -oE '\b[A-Z][a-zA-Z0-9_]*\b' | grep -vE '^(interface|export|default|extends|implements)$' | sort -u || true)
        if [[ -n "$interfaces" ]]; then
            while IFS= read -r iface; do
                [[ -z "$iface" ]] && continue
                # 查找实现
                impls=$(git grep -lE "implements\s+${iface}|:\s*${iface}\b" -- "*.ts" "*.tsx" 2>/dev/null | head -10 || true)
                if [[ -n "$impls" ]]; then
                    INTERFACE_CHANGES=$((INTERFACE_CHANGES + 1))
                    echo -e "  ${YELLOW}⚠️ 接口 ${iface} 发生变更${NC}"
                    echo -e "  ${BLUE}   实现位置:${NC}"
                    printf '%s\n' "$impls" | sed 's/^/     /'
                    echo ""
                fi
            done <<< "$interfaces"
        fi
    elif [[ "$file" =~ \.py$ ]]; then
        # Python: abstract base class
        classes=$(git diff "$BASE_REF"..HEAD -- "$file" | grep -E '^\+.*\bclass\b.*\b(ABC|abstract)\"' | grep -oE '\b[A-Z][a-zA-Z0-9_]*\b' | grep -vE '^(class|ABC|abstract|ABCMeta|metaclass)$' | sort -u || true)
        if [[ -n "$classes" ]]; then
            while IFS= read -r cls; do
                [[ -z "$cls" ]] && continue
                impls=$(git grep -lE "class\s+\w+\(.*${cls}\)" -- "*.py" 2>/dev/null | head -10 || true)
                if [[ -n "$impls" ]]; then
                    INTERFACE_CHANGES=$((INTERFACE_CHANGES + 1))
                    echo -e "  ${YELLOW}⚠️ 抽象类 ${cls} 发生变更${NC}"
                    echo -e "  ${BLUE}   子类:${NC}"
                    printf '%s\n' "$impls" | sed 's/^/     /'
                    echo ""
                fi
            done <<< "$classes"
        fi
    fi
done <<< "$CHANGED_FILES"

if [[ $INTERFACE_CHANGES -eq 0 ]]; then
    echo -e "  ${GREEN}✅ 未检测到接口/抽象类变更${NC}"
fi
echo ""

# ===== 风险评估 =====

echo -e "${CYAN}${BOLD}【风险评估】${NC}"
echo "======================================"
echo ""

CHANGED_COUNT=$(printf '%s\n' "$CHANGED_FILES" | wc -l | tr -d ' ')
TOTAL_AFFECTED=$((CALLER_COUNT + IMPORT_COUNT + INTERFACE_CHANGES))

# 风险等级计算
if [[ $TOTAL_AFFECTED -eq 0 && $CHANGED_COUNT -le 3 ]]; then
    RISK_LEVEL="LOW"
    RISK_COLOR="$GREEN"
    RISK_DESC="变更范围小，影响面有限"
elif [[ $TOTAL_AFFECTED -le 5 && $CHANGED_COUNT -le 5 ]]; then
    RISK_LEVEL="MEDIUM"
    RISK_COLOR="$YELLOW"
    RISK_DESC="中等影响范围，需关注调用链"
elif [[ $TOTAL_AFFECTED -le 15 || $INTERFACE_CHANGES -gt 0 ]]; then
    RISK_LEVEL="HIGH"
    RISK_COLOR="$RED"
    RISK_DESC="影响面较大，接口变更可能导致连锁反应"
else
    RISK_LEVEL="CRITICAL"
    RISK_COLOR="$RED"
    RISK_DESC="广泛影响，建议拆分变更或增加测试覆盖"
fi

echo -e "  ${BOLD}变更文件数:${NC} ${CHANGED_COUNT}"
echo -e "  ${BOLD}跨文件调用:${NC} ${CALLER_COUNT} 处"
echo -e "  ${BOLD}模块被导入:${NC} ${IMPORT_COUNT} 处"
echo -e "  ${BOLD}接口变更:${NC} ${INTERFACE_CHANGES} 处"
echo -e "  ${BOLD}总影响面:${NC} ${TOTAL_AFFECTED}"
echo ""
echo -e "  ${BOLD}风险等级: ${RISK_COLOR}${RISK_LEVEL}${NC}"
echo -e "  ${RISK_COLOR}${RISK_DESC}${NC}"
echo ""

# 建议
if [[ "$RISK_LEVEL" == "HIGH" || "$RISK_LEVEL" == "CRITICAL" ]]; then
    echo -e "${YELLOW}【建议】${NC}"
    echo "  1. 增加集成测试覆盖受影响的调用链"
    echo "  2. 与相关模块负责人确认兼容性"
    echo "  3. 考虑渐进式发布（灰度/Feature Flag）"
    echo "  4. 准备回滚方案"
    echo ""
fi
