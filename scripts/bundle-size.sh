#!/bin/bash
# Bundle 体积分析
# 检测新增依赖导致的包体积膨胀

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

TARGET_DIR="${1:-.}"
THRESHOLD_MB="${2:-1}"

echo -e "${CYAN}📦 Bundle Size / 构建产物体积分析${NC}"
echo "=========================================="
echo ""

cd "$TARGET_DIR"

# 检测包管理文件变更
PKG_CHANGED=$(git diff --name-only HEAD~1..HEAD 2>/dev/null | grep -E 'package\.json|package-lock\.json|yarn\.lock|pnpm-lock\.yaml' || true)

echo -e "${CYAN}【依赖变更检测】${NC}"

if [[ -z "$PKG_CHANGED" ]]; then
    echo -e "  ${YELLOW}未检测到 package.json 变更${NC}"
else
    echo "  变更文件:"
    printf '%s\n' "$PKG_CHANGED" | sed 's/^/    /'
fi

echo ""

# 分析 package.json 新增依赖
if [[ -f "package.json" ]]; then
    echo -e "${CYAN}【新增依赖分析】${NC}"

    # 获取当前和之前的 package.json
    current_deps=$(cat package.json 2>/dev/null | grep -E '"dependencies"|"devDependencies"' -A 100 | head -50 || true)
    prev_deps=$(git show HEAD~1:package.json 2>/dev/null | grep -E '"dependencies"|"devDependencies"' -A 100 | head -50 || true)

    # 提取新增依赖
    added_deps=""
    if [[ -n "$current_deps" && -n "$prev_deps" ]]; then
        # 简化提取：找当前有但之前没有的键
        current_keys=$(printf '%s\n' "$current_deps" | grep -oE '"[^"]+"\s*:' | sed 's/://' | sort -u)
        prev_keys=$(printf '%s\n' "$prev_deps" | grep -oE '"[^"]+"\s*:' | sed 's/://' | sort -u)
        added_deps=$(comm -23 <(echo "$current_keys") <(echo "$prev_keys") 2>/dev/null | grep -vE '"dependencies"|"devDependencies"|"scripts"|"name"|"version"' || true)
    fi

    if [[ -n "$added_deps" ]]; then
        echo -e "  ${YELLOW}新增依赖:${NC}"
        printf '%s\n' "$added_deps" | sed 's/^/    /'

        echo ""
        echo -e "  ${YELLOW}⚠️ 请评估这些依赖的体积影响:${NC}"
        echo "    1. 使用 bundlephobia.com 查询包体积"
        echo "    2. 检查是否有更轻量的替代方案"
        echo "    3. 确认 tree-shaking 支持"

        # 尝试检测大依赖（常见的大包）
        large_packages=("lodash" "moment" "jquery" "@material-ui" "antd" "echarts" "three")
        for pkg in "${large_packages[@]}"; do
            if printf '%s\n' "$added_deps" | grep -qi "$pkg"; then
                echo -e "    ${RED}🔴 注意: ${pkg} 是已知的大体积依赖${NC}"
            fi
        done
    else
        echo -e "  ${GREEN}✅ 无新增依赖${NC}"
    fi
fi

echo ""

# 检测构建产物
if [[ -d "dist" ]] || [[ -d "build" ]] || [[ -d ".next" ]]; then
    echo -e "${CYAN}【构建产物体积】${NC}"

    BUILD_DIR=""
    [[ -d "dist" ]] && BUILD_DIR="dist"
    [[ -d "build" ]] && BUILD_DIR="build"
    [[ -d ".next" ]] && BUILD_DIR=".next"

    if [[ -n "$BUILD_DIR" ]]; then
        # 计算产物总体积
        total_size=$(du -sh "$BUILD_DIR" 2>/dev/null | cut -f1 || echo "unknown")
        echo "  产物目录: $BUILD_DIR"
        echo "  总体积: $total_size"

        # 找出最大的文件
        echo ""
        echo "  最大文件 TOP 5:"
        find "$BUILD_DIR" -type f -exec du -h {} + 2>/dev/null | sort -rh | head -5 | sed 's/^/    /'

        # 检测 JS 文件是否过大（> threshold MB）
        large_js=$(find "$BUILD_DIR" -name "*.js" -size +${THRESHOLD_MB}M 2>/dev/null || true)
        if [[ -n "$large_js" ]]; then
            echo ""
            echo -e "  ${RED}🔴 以下 JS 文件超过 ${THRESHOLD_MB}MB:${NC}"
            printf '%s\n' "$large_js" | while read -r f; do
                size=$(du -h "$f" 2>/dev/null | cut -f1)
                echo "    ${size}  ${f}"
            done
            echo ""
            echo -e "  ${YELLOW}建议: 开启代码分割 (code splitting) 或懒加载${NC}"
        fi
    fi
else
    echo -e "  ${YELLOW}未找到构建产物目录 (dist/build/.next)${NC}"
fi

echo ""
echo -e "${CYAN}【体积优化建议】${NC}"
echo "  - 使用 import { specific } 替代 import * from 'lodash'"
echo "  - 配置 webpack/vite 的 splitChunks"
echo "  - 图片资源使用 WebP/AVIF 格式"
echo "  - 开启 Gzip/Brotli 压缩"
echo "  - 使用动态 import() 实现路由懒加载"
