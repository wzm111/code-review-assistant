#!/bin/bash
# API 契约变更检测
# 检测 OpenAPI/Swagger/Protobuf 的 breaking changes

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

TARGET_DIR="${1:-.}"

echo -e "${CYAN}🔗 API Contract / API 契约变更检测${NC}"
echo "=========================================="
echo ""

cd "$TARGET_DIR"

# 检测 API 定义文件
API_FILES=""

# OpenAPI / Swagger
if [[ -f "openapi.yaml" ]] || [[ -f "openapi.json" ]] || [[ -f "swagger.yaml" ]] || [[ -f "swagger.json" ]]; then
    API_FILES=$(find . -maxdepth 3 -name "openapi.*" -o -name "swagger.*" 2>/dev/null | head -5)
fi

# Protobuf
PROTO_FILES=$(git diff --name-only HEAD~1..HEAD 2>/dev/null | grep '\.proto$' || true)

# GraphQL schema
GQL_FILES=$(git diff --name-only HEAD~1..HEAD 2>/dev/null | grep -E '\.graphql$|schema\.gql' || true)

# gRPC / Thrift
GRPC_FILES=$(git diff --name-only HEAD~1..HEAD 2>/dev/null | grep -E '\.proto$' || true)

if [[ -z "$API_FILES" && -z "$PROTO_FILES" && -z "$GQL_FILES" ]]; then
    echo -e "${YELLOW}未检测到 API 定义文件变更${NC}"
    exit 0
fi

echo -e "${CYAN}【检测到的 API 变更】${NC}"

breaking_changes=()
warnings=()

# 分析 OpenAPI 变更
if [[ -n "$API_FILES" ]]; then
    echo -e "  ${CYAN}OpenAPI / Swagger:${NC}"

    changed_api=$(git diff --name-only HEAD~1..HEAD 2>/dev/null | grep -E 'openapi|swagger' || true)
    if [[ -n "$changed_api" ]]; then
        # 检测 breaking changes
        diff_output=$(git diff HEAD~1..HEAD -- $changed_api 2>/dev/null || true)

        # 检测路径删除
        if printf '%s\n' "$diff_output" | grep -q '^-.*paths:' || printf '%s\n' "$diff_output" | grep -q '^-  "/'; then
            breaking_changes+=("删除了 API 路径")
        fi

        # 检测 required 字段新增
        if printf '%s\n' "$diff_output" | grep -q '^+.*required:'; then
            breaking_changes+=("新增 required 字段（破坏向后兼容）")
        fi

        # 检测响应字段删除
        if printf '%s\n' "$diff_output" | grep -q '^-.*type:' && printf '%s\n' "$diff_output" | grep -q 'responses'; then
            breaking_changes+=("删除了响应字段")
        fi

        # 检测 HTTP 方法变更
        if printf '%s\n' "$diff_output" | grep -qE '^-(\s+get:|\s+post:|\s+put:|\s+delete:)'; then
            breaking_changes+=("HTTP 方法变更")
        fi

        echo "    变更文件:"
        printf '%s\n' "$changed_api" | sed 's/^/      /'
    fi
fi

# 分析 Protobuf 变更
if [[ -n "$PROTO_FILES" ]]; then
    echo -e "  ${CYAN}Protobuf:${NC}"

    for proto in $PROTO_FILES; do
        echo "    $proto"

        diff_output=$(git diff HEAD~1..HEAD -- "$proto" 2>/dev/null || true)

        # 字段编号变更 = breaking
        if printf '%s\n' "$diff_output" | grep -qE '^[+-].*= [0-9]+'; then
            breaking_changes+=("Protobuf 字段编号变更: $proto")
        fi

        # 字段删除
        if printf '%s\n' "$diff_output" | grep -qE '^-\s+(string|int|bool|bytes|repeated|optional|required)' && \
           ! printf '%s\n' "$diff_output" | grep -qE '^\+\s+(string|int|bool|bytes|repeated|optional|required)'; then
            breaking_changes+=("Protobuf 字段删除: $proto")
        fi

        # reserved 字段变更
        if printf '%s\n' "$diff_output" | grep -qE '^[+-].*reserved'; then
            warnings+=("reserved 字段变更: $proto")
        fi
    done
fi

# 分析 GraphQL 变更
if [[ -n "$GQL_FILES" ]]; then
    echo -e "  ${CYAN}GraphQL:${NC}"

    for gql in $GQL_FILES; do
        echo "    $gql"

        diff_output=$(git diff HEAD~1..HEAD -- "$gql" 2>/dev/null || true)

        # 字段删除
        if printf '%s\n' "$diff_output" | grep -qE '^-\s+\w+:' && printf '%s\n' "$diff_output" | grep -q 'type '; then
            breaking_changes+=("GraphQL 字段删除: $gql")
        fi
    done
fi

echo ""

# 输出结果
if [[ ${#breaking_changes[@]} -gt 0 ]]; then
    echo -e "${RED}🔴 Breaking Changes (必须处理):${NC}"
    for change in "${breaking_changes[@]}"; do
        echo "  - $change"
    done
    echo ""
fi

if [[ ${#warnings[@]} -gt 0 ]]; then
    echo -e "${YELLOW}🟡 警告:${NC}"
    for w in "${warnings[@]}"; do
        echo "  - $w"
    done
    echo ""
fi

if [[ ${#breaking_changes[@]} -eq 0 && ${#warnings[@]} -eq 0 ]]; then
    echo -e "${GREEN}✅ 未检测到 Breaking Changes${NC}"
fi

echo -e "${CYAN}【建议】${NC}"
echo "  1. API 变更需同步更新文档"
echo "  2. Breaking change 需通知调用方"
echo "  3. 考虑 API 版本控制 (/v1/ → /v2/)"
echo "  4. 使用兼容性测试验证客户端"

if [[ ${#breaking_changes[@]} -gt 0 ]]; then
    exit 1
fi
