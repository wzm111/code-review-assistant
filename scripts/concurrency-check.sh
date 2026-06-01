#!/bin/bash
# 并发安全深度检测
# 检测死锁、竞态条件、goroutine 泄露等并发问题

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

TARGET_DIR="${1:-.}"

echo -e "${CYAN}🔀 Concurrency / 并发安全深度检测${NC}"
echo "=========================================="
echo ""

cd "$TARGET_DIR"

CHANGED_FILES=$(git diff --name-only HEAD~1..HEAD 2>/dev/null | grep -E '\.(go|rs|java|kt|cpp|c|h)$' || true)

if [[ -z "$CHANGED_FILES" ]]; then
    echo -e "${YELLOW}无并发相关语言文件变更${NC}"
    exit 0
fi

critical_issues=()
warnings=()

while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    [[ -f "$file" ]] || continue

    content=$(cat "$file" 2>/dev/null || true)
    [[ -z "$content" ]] && continue

    # ===== Go 并发检测 =====
    if [[ "$file" =~ \.go$ ]]; then
        # 1. Goroutine 泄露：启动 goroutine 但没有对应的 channel/WaitGroup 等待
        go_count=$(printf '%s\n' "$content" | grep -c 'go ' || true)
        wg_count=$(printf '%s\n' "$content" | grep -c 'sync.WaitGroup' || true)
        if [[ "$go_count" -gt 0 && "$wg_count" -eq 0 ]]; then
            warnings+=("$file: 启动 goroutine 但未使用 WaitGroup，可能泄露")
        fi

        # 2. Channel 关闭安全
        if printf '%s\n' "$content" | grep -q 'close(' && ! printf '%s\n' "$content" | grep -q 'sync.Once'; then
            warnings+=("$file: channel 关闭逻辑可能存在竞态 (建议用 sync.Once)")
        fi

        # 3. map 并发访问
        if printf '%s\n' "$content" | grep -q 'map\['; then
            if ! printf '%s\n' "$content" | grep -q 'sync\.RWMutex\|sync\.Mutex\|sync\.Map'; then
                warnings+=("$file: map 操作缺少锁保护，并发不安全")
            fi
        fi

        # 4. defer 在循环中
        if printf '%s\n' "$content" | grep -q 'for ' && printf '%s\n' "$content" | grep -q 'defer '; then
            warnings+=("$file: defer 在循环内使用可能导致资源堆积")
        fi
    fi

    # ===== Rust 并发检测 =====
    if [[ "$file" =~ \.rs$ ]]; then
        # 检测 unsafe 块
        unsafe_count=$(printf '%s\n' "$content" | grep -c 'unsafe' || true)
        if [[ "$unsafe_count" -gt 0 ]]; then
            warnings+=("$file: 包含 $unsafe_count 处 unsafe 代码，需手动审查安全性")
        fi

        # 检测裸指针
        if printf '%s\n' "$content" | grep -qE '\*mut |\*const '; then
            warnings+=("$file: 使用裸指针，需确保内存安全")
        fi
    fi

    # ===== Java / Kotlin 并发检测 =====
    if [[ "$file" =~ \.(java|kt)$ ]]; then
        # 1. synchronized 嵌套（死锁风险）
        sync_count=$(printf '%s\n' "$content" | grep -c 'synchronized' || true)
        if [[ "$sync_count" -gt 1 ]]; then
            warnings+=("$file: 多处 synchronized，注意锁顺序避免死锁")
        fi

        # 2. 未使用线程池直接 new Thread
        if printf '%s\n' "$content" | grep -q 'new Thread(' && ! printf '%s\n' "$content" | grep -q 'ExecutorService\|ThreadPool'; then
            warnings+=("$file: 直接 new Thread()，建议使用线程池管理")
        fi

        # 3. volatile 误用
        if printf '%s\n' "$content" | grep -q 'volatile' && printf '%s\n' "$content" | grep -qE '\+\+|\-\-|\+='; then
            warnings+=("$file: volatile + 复合操作非原子，考虑 AtomicXXX")
        fi
    fi

    # ===== C/C++ 并发检测 =====
    if [[ "$file" =~ \.(cpp|c|h)$ ]]; then
        # pthread 锁顺序
        lock_count=$(printf '%s\n' "$content" | grep -cE 'pthread_mutex_lock|lock_guard|unique_lock' || true)
        if [[ "$lock_count" -gt 1 ]]; then
            warnings+=("$file: 多把锁，确保全局一致的加锁顺序")
        fi

        # 原子操作检测
        if printf '%s\n' "$content" | grep -qE '\+\+|\-\-' && ! printf '%s\n' "$content" | grep -qE 'atomic|std::atomic'; then
            warnings+=("$file: 自增/自减非原子，并发下可能丢失更新")
        fi
    fi

done <<< "$CHANGED_FILES"

# 输出结果
echo -e "${CYAN}【检测结果】${NC}"
echo ""

if [[ ${#critical_issues[@]} -gt 0 ]]; then
    echo -e "${RED}🔴 严重并发问题:${NC}"
    for issue in "${critical_issues[@]}"; do
        echo "  - $issue"
    done
    echo ""
fi

if [[ ${#warnings[@]} -gt 0 ]]; then
    echo -e "${YELLOW}🟡 并发风险警告:${NC}"
    for w in "${warnings[@]}"; do
        echo "  - $w"
    done
    echo ""
fi

if [[ ${#critical_issues[@]} -eq 0 && ${#warnings[@]} -eq 0 ]]; then
    echo -e "  ${GREEN}✅ 未检测到明显的并发安全问题${NC}"
fi

echo -e "${CYAN}【并发安全最佳实践】${NC}"
echo "  1. Go: 使用 errgroup 管理 goroutine 生命周期"
echo "  2. Java: 使用 j.u.c 包，避免手写 wait/notify"
echo "  3. Rust: 优先使用 safe 抽象，unsafe 需详细注释"
echo "  4. 所有语言: 保持全局一致的锁获取顺序"
echo "  5. 使用静态分析工具: Go race detector, ThreadSanitizer"

if [[ ${#critical_issues[@]} -gt 0 ]]; then
    exit 1
fi
