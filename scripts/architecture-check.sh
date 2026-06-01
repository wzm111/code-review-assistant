#!/bin/bash
# 架构合规检查
# 检测分层违规、循环依赖、错误 import 方向

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

TARGET_DIR="${1:-.}"

echo -e "${CYAN}🏗️ Architecture / 架构合规检查${NC}"
echo "=========================================="
echo ""

cd "$TARGET_DIR"

CHANGED_FILES=$(git diff --name-only HEAD~1..HEAD 2>/dev/null | grep -E '\.(js|ts|jsx|tsx|vue|py|go|java|php|rb)$' || true)

if [[ -z "$CHANGED_FILES" ]]; then
    echo -e "${YELLOW}无源码文件变更${NC}"
    exit 0
fi

violations=()

echo -e "${CYAN}【扫描架构违规】${NC}"
echo ""

# 检测项目架构模式
ARCH_PATTERN=""
if [[ -d "src/domain" ]] || [[ -d "src/application" ]] || [[ -d "src/infrastructure" ]]; then
    ARCH_PATTERN="ddd"
    echo -e "  ${CYAN}检测到: DDD 分层架构${NC}"
elif [[ -d "src/controllers" ]] || [[ -d "src/services" ]] || [[ -d "src/repositories" ]]; then
    ARCH_PATTERN="mvc"
    echo -e "  ${CYAN}检测到: MVC / 三层架构${NC}"
elif [[ -d "src/pages" ]] && [[ -d "src/components" ]]; then
    ARCH_PATTERN="frontend"
    echo -e "  ${CYAN}检测到: 前端页面+组件架构${NC}"
else
    echo -e "  ${YELLOW}未识别特定架构模式${NC}"
fi

while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    [[ -f "$file" ]] || continue

    content=$(cat "$file" 2>/dev/null || true)
    [[ -z "$content" ]] && continue

    # 提取 import / require
    imports=$(printf '%s\n' "$content" | grep -oE "(import|require|from)\s+['\"][^'\"]+['\"]" || true)

    case "$ARCH_PATTERN" in
        ddd)
            # DDD: Domain 层不能依赖其他层
            if [[ "$file" =~ /domain/ ]]; then
                bad_imports=$(printf '%s\n' "$imports" | grep -E 'application|infrastructure|presentation|api' || true)
                if [[ -n "$bad_imports" ]]; then
                    violations+=("$file: Domain 层违规依赖外层 (application/infrastructure)")
                fi
            fi
            # Infrastructure 层不能反向依赖 Domain
            if [[ "$file" =~ /infrastructure/ ]]; then
                infra_to_infra=$(printf '%s\n' "$imports" | grep -E 'application|presentation' || true)
                if [[ -n "$infra_to_infra" ]]; then
                    violations+=("$file: Infrastructure 层违规依赖上层")
                fi
            fi
            ;;
        mvc)
            # Controller → Service → Repository 单向依赖
            if [[ "$file" =~ /repository/ ]]; then
                repo_violation=$(printf '%s\n' "$imports" | grep -E '/controller/|/service/' || true)
                if [[ -n "$repo_violation" ]]; then
                    violations+=("$file: Repository 层反向依赖上层 (controller/service)")
                fi
            fi
            if [[ "$file" =~ /service/ ]]; then
                svc_violation=$(printf '%s\n' "$imports" | grep -E '/controller/' || true)
                if [[ -n "$svc_violation" ]]; then
                    violations+=("$file: Service 层反向依赖 Controller")
                fi
            fi
            ;;
        frontend)
            # 组件不能反向依赖页面
            if [[ "$file" =~ /components/ ]]; then
                page_import=$(printf '%s\n' "$imports" | grep -E '/pages/' || true)
                if [[ -n "$page_import" ]]; then
                    violations+=("$file: 组件层反向依赖页面层")
                fi
            fi
            # utils 不能依赖业务组件
            if [[ "$file" =~ /utils?/ ]]; then
                biz_import=$(printf '%s\n' "$imports" | grep -E '/components/|/pages/' || true)
                if [[ -n "$biz_import" ]]; then
                    violations+=("$file: 工具层违规依赖业务层")
                fi
            fi
            ;;
    esac

    # 通用：检测循环依赖（简化版）
    for import_line in $imports; do
        # 提取相对路径
        rel_path=$(printf '%s\n' "$import_line" | grep -oE '\./[^[:space:]]+' | head -1 || true)
        if [[ -n "$rel_path" ]]; then
            # 检查被导入的文件是否反过来导入当前文件
            target_file="${file%/*}/${rel_path}"
            target_file="${target_file%\.}"
            for ext in "" ".ts" ".tsx" ".js" ".jsx" ".vue" ".py" ".go" ".java"; do
                if [[ -f "${target_file}${ext}" ]]; then
                    target_content=$(cat "${target_file}${ext}" 2>/dev/null || true)
                    if printf '%s\n' "$target_content" | grep -q "${file}"; then
                        violations+=("$file ↔ ${target_file}${ext}: 循环依赖")
                    fi
                    break
                fi
            done
        fi
    done

done <<< "$CHANGED_FILES"

echo -e "${CYAN}【检查结果】${NC}"
echo ""

if [[ ${#violations[@]} -gt 0 ]]; then
    echo -e "${RED}🔴 架构违规:${NC}"
    for v in "${violations[@]}"; do
        echo "  - $v"
    done
    echo ""
else
    echo -e "  ${GREEN}✅ 未检测到架构违规${NC}"
fi

echo -e "${CYAN}【架构最佳实践】${NC}"
echo "  1. 依赖方向: 外层 → 内层，禁止反向依赖"
echo "  2. Domain/Entity 层不依赖任何框架"
echo "  3. 使用依赖注入解耦层间依赖"
echo "  4. 避免循环依赖，使用接口/事件总线"
echo "  5. 公共工具提取到独立模块"

if [[ ${#violations[@]} -gt 0 ]]; then
    exit 1
fi
