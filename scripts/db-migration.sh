#!/bin/bash
# 数据库迁移安全审查
# 检测可能导致线上故障的 migration 操作

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

TARGET_DIR="${1:-.}"

echo -e "${CYAN}🗄️ DB Migration / 数据库迁移安全审查${NC}"
echo "=========================================="
echo ""

cd "$TARGET_DIR"

# 检测 migration 文件变更
MIGRATION_FILES=$(git diff --name-only HEAD~1..HEAD 2>/dev/null | grep -iE 'migration|migrate|schema' | grep -E '\.(sql|py|rb|js|ts|go|php)$' || true)

# 常见框架的 migration 目录
if [[ -z "$MIGRATION_FILES" ]]; then
    MIGRATION_FILES=$(git diff --name-only HEAD~1..HEAD 2>/dev/null | grep -E 'db/migrate|migrations|alembic|flyway|liquibase' || true)
fi

if [[ -z "$MIGRATION_FILES" ]]; then
    echo -e "${YELLOW}未检测到数据库迁移文件变更${NC}"
    exit 0
fi

echo -e "${CYAN}【变更的迁移文件】${NC}"
printf '%s\n' "$MIGRATION_FILES" | sed 's/^/  /'
echo ""

critical_issues=()
warnings=()

while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    [[ -f "$file" ]] || continue

    content=$(cat "$file" 2>/dev/null || true)
    [[ -z "$content" ]] && continue

    content_lower=$(printf '%s\n' "$content" | tr '[:upper:]' '[:lower:]')

    # --- CRITICAL 级别 ---

    # 1. 无事务包裹
    if ! printf '%s\n' "$content_lower" | grep -qE 'begin|transaction|start transaction'; then
        critical_issues+=("$file: 未使用事务包裹 (可能导致部分执行)")
    fi

    # 2. 大表 ALTER（没有在线 DDL）
    if printf '%s\n' "$content_lower" | grep -qE 'alter\s+table'; then
        if ! printf '%s\n' "$content_lower" | grep -qE 'algorithm=.*inplace|lock=.*none|pt-online-schema|gh-ost|concurrently'; then
            critical_issues+=("$file: ALTER TABLE 缺少在线 DDL 策略，大表会锁表")
        fi
    fi

    # 3. DROP COLUMN / DROP TABLE
    if printf '%s\n' "$content_lower" | grep -qE 'drop\s+(column|table)'; then
        critical_issues+=("$file: 包含 DROP COLUMN/TABLE（数据丢失风险）")
    fi

    # 4. DELETE / TRUNCATE 无 WHERE
    if printf '%s\n' "$content_lower" | grep -qE 'delete\s+from' && ! printf '%s\n' "$content_lower" | grep -qE 'delete\s+from.*where'; then
        critical_issues+=("$file: DELETE 缺少 WHERE 条件")
    fi
    if printf '%s\n' "$content_lower" | grep -qE 'truncate\s+table'; then
        critical_issues+=("$file: TRUNCATE TABLE（数据全部清空）")
    fi

    # 5. 索引变更风险
    if printf '%s\n' "$content_lower" | grep -qE 'drop\s+index|drop\s+key'; then
        warnings+=("$file: 删除索引可能影响查询性能")
    fi

    # 6. 外键约束变更
    if printf '%s\n' "$content_lower" | grep -qE 'add\s+foreign\s+key|drop\s+foreign\s+key'; then
        warnings+=("$file: 外键变更可能影响写入性能")
    fi

    # 7. 没有 DOWN / rollback
    if [[ "$file" =~ \.(rb|py|js|ts)$ ]]; then
        if ! printf '%s\n' "$content" | grep -qiE 'def\s+down|down\s*\(|rollback|revert'; then
            warnings+=("$file: 缺少 down/rollback 方法")
        fi
    fi

    # 8. 长时间运行的操作提示
    if printf '%s\n' "$content_lower" | grep -qE 'update.*set|insert\s+into.*select'; then
        warnings+=("$file: 包含批量 UPDATE/INSERT，可能长时间运行")
    fi

done <<< "$MIGRATION_FILES"

# 输出结果
echo -e "${CYAN}【审查结果】${NC}"
echo ""

if [[ ${#critical_issues[@]} -gt 0 ]]; then
    echo -e "${RED}🔴 严重问题 (上线前必须修复):${NC}"
    for issue in "${critical_issues[@]}"; do
        echo "  - $issue"
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

if [[ ${#critical_issues[@]} -eq 0 && ${#warnings[@]} -eq 0 ]]; then
    echo -e "  ${GREEN}✅ 迁移文件安全检查通过${NC}"
fi

echo -e "${CYAN}【DB Migration 最佳实践】${NC}"
echo "  1. 大表 ALTER 使用 pt-online-schema-change 或 gh-ost"
echo "  2. 所有 migration 必须包裹在事务中"
echo "  3. 禁止直接 DELETE/TRUNCATE，使用软删除"
echo "  4. 上线前在 staging 环境预执行"
echo "  5. 添加索引选择低峰期，避免锁表"
echo "  6. 保留 rollback/down 脚本"

if [[ ${#critical_issues[@]} -gt 0 ]]; then
    exit 1
fi
