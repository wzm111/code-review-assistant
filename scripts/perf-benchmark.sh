#!/bin/bash
# 性能基准回归分析
# 对比性能测试结果，发现回归

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

TARGET_DIR="${1:-.}"
REGRESSION_THRESHOLD="${2:-10}"  # 性能下降超过 10% 视为回归

echo -e "${CYAN}⚡ Performance Benchmark / 性能基准回归分析${NC}"
echo "=========================================="
echo ""

cd "$TARGET_DIR"

# 检测基准测试文件
BENCH_FILES=$(git diff --name-only HEAD~1..HEAD 2>/dev/null | grep -iE 'bench|benchmark|perf|\.bench\.' || true)

# 检测各种语言的基准测试配置
BENCH_RESULTS=""

# Go benchmark
if find . -name "*.bench" -o -name "bench.out" 2>/dev/null | head -1 | grep -q .; then
    BENCH_RESULTS=$(find . -maxdepth 3 -name "*.bench" -o -name "bench.out" | head -5)
    echo -e "${CYAN}【Go Benchmark 结果】${NC}"
# JavaScript benchmark
elif [[ -f "benchmark-results.json" ]]; then
    BENCH_RESULTS="benchmark-results.json"
    echo -e "${CYAN}【JS Benchmark 结果】${NC}"
# Python benchmark
elif find . -name "benchmark_*.json" -o -name ".benchmarks" 2>/dev/null | head -1 | grep -q .; then
    BENCH_RESULTS=$(find . -maxdepth 3 -name "benchmark_*.json" | head -5)
    echo -e "${CYAN}【Python Benchmark 结果】${NC}"
fi

if [[ -z "$BENCH_RESULTS" && -z "$BENCH_FILES" ]]; then
    echo -e "${YELLOW}未检测到基准测试文件${NC}"
    echo "  建议集成基准测试:"
    echo "    Go:    go test -bench=. -benchmem"
    echo "    JS:    benchmark.js"
    echo "    Python: pytest-benchmark"
    exit 0
fi

# 检查变更是否涉及性能敏感代码
echo -e "${CYAN}【性能敏感变更】${NC}"

PERF_KEYWORDS='for\s*\(|while\s*\(|map\s*\(|filter\s*\(|reduce\s*\(|sort\s*\(|async\s|await|Promise\.all|setTimeout|setInterval|\.query\(|\.find\(|\.aggregate\('

perf_related_files=()
while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    [[ -f "$file" ]] || continue

    content=$(cat "$file" 2>/dev/null || true)
    [[ -z "$content" ]] && continue

    if printf '%s\n' "$content" | grep -qE "$PERF_KEYWORDS"; then
        # 额外检测 N+1、大循环等
        loop_count=$(printf '%s\n' "$content" | grep -cE 'for\s*\(|while\s*\(' || true)
        if [[ "$loop_count" -gt 2 ]]; then
            perf_related_files+=("$file (嵌套循环: $loop_count 处)")
        elif printf '%s\n' "$content" | grep -qE '\.query\(' && printf '%s\n' "$content" | grep -qE 'for\s*\('; then
            perf_related_files+=("$file (循环内查询 - N+1 风险)")
        else
            perf_related_files+=("$file (含性能敏感操作)")
        fi
    fi
done <<< "$(git diff --name-only HEAD~1..HEAD 2>/dev/null | grep -E '\.(js|ts|jsx|tsx|py|go|java|php)$' || true)"

if [[ ${#perf_related_files[@]} -gt 0 ]]; then
    for f in "${perf_related_files[@]}"; do
        echo "  - $f"
    done
    echo ""
    echo -e "${YELLOW}⚠️ 这些变更可能影响性能，建议运行基准测试验证${NC}"
else
    echo -e "  ${GREEN}✅ 未检测到明显的性能敏感变更${NC}"
fi

echo ""
echo -e "${CYAN}【性能优化建议】${NC}"
echo "  1. 添加/更新基准测试覆盖变更的代码路径"
echo "  2. 在 CI 中设置性能回归阈值 (建议 ${REGRESSION_THRESHOLD}%)"
echo "  3. 使用 pprof (Go) / Chrome DevTools (JS) 分析热点"
echo "  4. 关注算法复杂度变化 (O(n) → O(n²))"
echo "  5. 数据库查询添加 EXPLAIN 分析"
