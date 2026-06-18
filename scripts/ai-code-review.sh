#!/bin/bash
# AI 深度代码审查
# 调用 Anthropic Claude API 对代码进行结构化审查，输出 Markdown 格式报告

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

TARGET_DIR="${1:-.}"
FILE_PATH="${2:-}"
DEPTH="${3:-standard}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE=".ai-review-report-${TIMESTAMP}.md"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 解析可选参数
SUMMARY_MODE=0
for arg in "$@"; do
    case "$arg" in
        --summary) SUMMARY_MODE=1 ;;
    esac
done

# Dashboard 安静模式：只输出报告内容，减少进度信息
QUIET=0
if [[ "${DASHBOARD_QUIET:-}" == "1" ]]; then
    QUIET=1
fi

# 进度输出（quiet 模式下跳过）
progress() {
    if [[ "$QUIET" == "1" ]]; then
        return
    fi
    echo -e "$@"
}

# ═══════════════════════════════════════════════════════════════
# 多平台 API Key 自动检测
# 支持: Anthropic(Claude)、OpenAI(Codex)、Kimi、DeepSeek、DashScope(通义千问)
# ═══════════════════════════════════════════════════════════════

API_TYPE=""       # anthropic | openai
API_KEY=""        # 实际使用的 Key
API_URL=""        # 完整的 API 端点
API_MODEL=""      # 对应模型名称
API_PROVIDER=""   # 显示名称

# ── 辅助函数：从 .env 文件读取指定 key ──
read_env_key() {
    local file="$1" key="$2"
    if [[ -f "$file" ]]; then
        grep -E "^${key}=" "$file" | sed 's/^[^=]*=//' | sed 's/["'"'"']//g' | head -1
    fi
}

# ── 检测顺序（优先级从高到低）──

# 1. Anthropic / Claude Code
if [[ -n "${ANTHROPIC_API_KEY:-}" || -n "${ANTHROPIC_AUTH_TOKEN:-}" ]]; then
    API_TYPE="anthropic"
    API_KEY="${ANTHROPIC_API_KEY:-${ANTHROPIC_AUTH_TOKEN:-}}"
    API_URL="${ANTHROPIC_BASE_URL:-https://api.anthropic.com/v1/messages}"
    API_MODEL="claude-sonnet-4-6"
    API_PROVIDER="Anthropic (Claude)"
fi

# 2. OpenAI / Codex
if [[ -z "$API_KEY" && -n "${OPENAI_API_KEY:-}" ]]; then
    API_TYPE="openai"
    API_KEY="$OPENAI_API_KEY"
    API_URL="${OPENAI_BASE_URL:-https://api.openai.com/v1/chat/completions}"
    API_MODEL="gpt-4o"
    API_PROVIDER="OpenAI"
fi

# 3. Kimi / Moonshot
if [[ -z "$API_KEY" && ( -n "${KIMI_API_KEY:-}" || -n "${MOONSHOT_API_KEY:-}" ) ]]; then
    API_TYPE="openai"
    API_KEY="${KIMI_API_KEY:-${MOONSHOT_API_KEY:-}}"
    API_URL="${KIMI_BASE_URL:-${MOONSHOT_BASE_URL:-https://api.moonshot.cn/v1/chat/completions}}"
    API_MODEL="kimi-for-coding"
    API_PROVIDER="Kimi"
fi

# 4. DeepSeek
if [[ -z "$API_KEY" && -n "${DEEPSEEK_API_KEY:-}" ]]; then
    API_TYPE="openai"
    API_KEY="$DEEPSEEK_API_KEY"
    API_URL="${DEEPSEEK_BASE_URL:-https://api.deepseek.com/v1/chat/completions}"
    API_MODEL="deepseek-chat"
    API_PROVIDER="DeepSeek"
fi

# 5. DashScope / 通义千问
if [[ -z "$API_KEY" && ( -n "${DASHSCOPE_API_KEY:-}" || -n "${QWEN_API_KEY:-}" ) ]]; then
    API_TYPE="openai"
    API_KEY="${DASHSCOPE_API_KEY:-${QWEN_API_KEY:-}}"
    API_URL="${DASHSCOPE_BASE_URL:-https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions}"
    API_MODEL="qwen-max"
    API_PROVIDER="通义千问"
fi

# ── 从 .env 文件补充检测（环境变量未设置时）──
if [[ -z "$API_KEY" ]]; then
    for env_file in "$SCRIPT_DIR/../.env" "$SCRIPT_DIR/../../.env" "$HOME/.env"; do
        if [[ -f "$env_file" ]]; then
            # Anthropic
            k=$(read_env_key "$env_file" "ANTHROPIC_API_KEY")
            [[ -z "$k" ]] && k=$(read_env_key "$env_file" "ANTHROPIC_AUTH_TOKEN")
            if [[ -n "$k" ]]; then
                API_TYPE="anthropic"; API_KEY="$k"
                API_URL="https://api.anthropic.com/v1/messages"
                API_MODEL="claude-sonnet-4-6"
                API_PROVIDER="Anthropic (Claude)"
                break
            fi
            # OpenAI
            k=$(read_env_key "$env_file" "OPENAI_API_KEY")
            if [[ -n "$k" ]]; then
                API_TYPE="openai"; API_KEY="$k"
                API_URL="https://api.openai.com/v1/chat/completions"
                API_MODEL="gpt-4o"
                API_PROVIDER="OpenAI"
                break
            fi
            # Kimi
            k=$(read_env_key "$env_file" "KIMI_API_KEY")
            [[ -z "$k" ]] && k=$(read_env_key "$env_file" "MOONSHOT_API_KEY")
            if [[ -n "$k" ]]; then
                API_TYPE="openai"; API_KEY="$k"
                API_URL="https://api.moonshot.cn/v1/chat/completions"
                API_MODEL="kimi-for-coding"
                API_PROVIDER="Kimi"
                break
            fi
            # DeepSeek
            k=$(read_env_key "$env_file" "DEEPSEEK_API_KEY")
            if [[ -n "$k" ]]; then
                API_TYPE="openai"; API_KEY="$k"
                API_URL="https://api.deepseek.com/v1/chat/completions"
                API_MODEL="deepseek-chat"
                API_PROVIDER="DeepSeek"
                break
            fi
            # DashScope
            k=$(read_env_key "$env_file" "DASHSCOPE_API_KEY")
            [[ -z "$k" ]] && k=$(read_env_key "$env_file" "QWEN_API_KEY")
            if [[ -n "$k" ]]; then
                API_TYPE="openai"; API_KEY="$k"
                API_URL="https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions"
                API_MODEL="qwen-max"
                API_PROVIDER="通义千问"
                break
            fi
        fi
    done
fi

progress "${CYAN}${BOLD}🤖 AI Code Review / AI 智能代码审查${NC}"
progress "=============================================="
progress ""

# ===== 检查环境 =====

if [[ -z "$API_KEY" ]]; then
    echo -e "${RED}❌ 错误: 未检测到可用的 AI API Key${NC}" >&2
    echo "" >&2
    echo -e "${YELLOW}Dashboard 会自动继承启动它的智能体的环境变量。${NC}" >&2
    echo -e "${YELLOW}如果你使用的是以下智能体，请确保已登录:${NC}" >&2
    echo "" >&2
    echo "  • Claude Code  → 自动继承 ANTHROPIC_AUTH_TOKEN" >&2
    echo "  • Codex (OpenAI) → 自动继承 OPENAI_API_KEY" >&2
    echo "  • Kimi Code    → 自动继承 KIMI_API_KEY" >&2
    echo "  • DeepSeek     → 自动继承 DEEPSEEK_API_KEY" >&2
    echo "  • 通义千问(Qwen) → 自动继承 DASHSCOPE_API_KEY" >&2
    echo "" >&2
    echo -e "${CYAN}如果智能体未暴露环境变量，可手动在 ~/.env 中配置:${NC}" >&2
    echo "  ANTHROPIC_API_KEY=your-key" >&2
    echo "  或 OPENAI_API_KEY=your-key" >&2
    echo "  或 KIMI_API_KEY=your-key" >&2
    exit 1
fi

if ! command -v python3 &>/dev/null; then
    echo -e "${RED}❌ 错误: 未找到 python3，需要用于 JSON 处理${NC}" >&2
    exit 1
fi

if ! command -v python3 &>/dev/null; then
    echo -e "${RED}❌ 错误: 未找到 python3，需要用于 JSON 处理${NC}" >&2
    exit 1
fi

# 验证 depth 参数
case "$DEPTH" in
    quick|standard|deep) ;;
    *)
        progress "${YELLOW}⚠️  无效的 depth 参数: ${DEPTH}，使用默认值 standard${NC}"
        DEPTH="standard"
        ;;
esac

cd "$TARGET_DIR"

# ===== 根据深度选择模型和参数 =====

case "$DEPTH" in
    quick)
        if [[ "$API_TYPE" == "anthropic" ]]; then
            MODEL="claude-3-5-haiku-20241022"
        else
            MODEL="$API_MODEL"
        fi
        MAX_TOKENS=2048
        CONTEXT_LINES=50
        MAX_FILES=5
        ;;
    standard|deep)
        MODEL="$API_MODEL"
        MAX_TOKENS=8192
        CONTEXT_LINES=1000
        MAX_FILES=5
        if [[ "$DEPTH" == "deep" ]]; then
            CONTEXT_LINES=500
            MAX_FILES=10
        fi
        ;;
esac

progress "${BLUE}【配置】${NC}"
progress "  深度: ${DEPTH}"
progress "  模型: ${MODEL}"
progress "  最大文件数: ${MAX_FILES}"
progress "  每文件最大行数: ${CONTEXT_LINES}"
progress ""

# ═══════════════════════════════════════════════════════════════
# 项目自定义规则提前发现（exclude_patterns 需在文件收集前生效）
# ═══════════════════════════════════════════════════════════════

discover_rules_file() {
    local dir="$1"
    while [[ "$dir" != "/" ]]; do
        if [[ -f "$dir/.review-rules.yml" ]]; then
            echo "$dir/.review-rules.yml"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    return 1
}

# 解析 .review-rules.yml：优先 PyYAML，否则使用独立 fallback 脚本
parse_review_rules() {
    local file="$1"
    python3 "$SCRIPT_DIR/parse_review_rules.py" "$file"
}

# 提前提取 exclude_patterns，供文件收集阶段过滤
RULES_FILE=$(discover_rules_file "$(cd "$TARGET_DIR" && pwd)" 2>/dev/null || true)
EXCLUDE_PATTERNS=""
if [[ -n "$RULES_FILE" ]]; then
    RULES_JSON_EARLY=$(parse_review_rules "$RULES_FILE" 2>/dev/null || echo '{"disable":[],"custom_rules":[],"behavior":{}}')
    EXCLUDE_PATTERNS=$(python3 -c '
import json, sys
data = json.loads(sys.argv[1])
patterns = data.get("behavior", {}).get("exclude_patterns", [])
print("\n".join(patterns))
' "$RULES_JSON_EARLY" 2>/dev/null || true)
fi

# ===== 收集代码上下文 =====

progress "${BLUE}【收集代码上下文】${NC}"

CODE_CONTEXT=""
FILE_COUNT=0

if [[ -n "$FILE_PATH" ]]; then
    # 审查指定文件
    if [[ ! -f "$FILE_PATH" ]]; then
        echo -e "${RED}❌ 错误: 文件不存在: ${FILE_PATH}${NC}" >&2
        exit 1
    fi

    # 跳过二进制文件
    file_type=$(file -b --mime-type "$FILE_PATH" 2>/dev/null || echo "application/octet-stream")
    case "$file_type" in
        text/*|application/javascript|application/json|application/xml)
            FILE_COUNT=1
            file_lines=$(wc -l < "$FILE_PATH" | tr -d ' ')
            if [[ "$file_lines" -gt "$CONTEXT_LINES" ]]; then
                progress "  ${YELLOW}⚠️  ${FILE_PATH} 超过 ${CONTEXT_LINES} 行，截取前 ${CONTEXT_LINES} 行${NC}"
                content=$(head -n "$CONTEXT_LINES" "$FILE_PATH")
            else
                content=$(cat "$FILE_PATH")
            fi
            CODE_CONTEXT="### File: ${FILE_PATH}
\`\`\`
${content}
\`\`\`

"
            progress "  ${GREEN}✓${NC} ${FILE_PATH} (${file_lines} 行)"
            ;;
        *)
            progress "  ${YELLOW}⚠️  跳过二进制文件: ${FILE_PATH}${NC}"
            exit 0
            ;;
    esac
else
    # 收集 git 变更文件
    CHANGED_FILES=$(git diff --name-only HEAD~1..HEAD 2>/dev/null || git diff --name-only 2>/dev/null || true)

    if [[ -z "$CHANGED_FILES" ]]; then
        progress "${YELLOW}无新提交变更，尝试工作区变更...${NC}"
        CHANGED_FILES=$(git diff --name-only HEAD 2>/dev/null || true)
    fi

    if [[ -z "$CHANGED_FILES" ]]; then
        progress "${YELLOW}无工作区变更，检查未跟踪文件...${NC}"
        CHANGED_FILES=$(git ls-files --others --exclude-standard 2>/dev/null | head -20 || true)
    fi

    if [[ -z "$CHANGED_FILES" ]]; then
        progress "${YELLOW}未检测到代码变更${NC}"
        exit 0
    fi

    # 检查文件是否匹配 .review-rules.yml 的 exclude_patterns（glob 语法）
    is_excluded_by_rules() {
        local file="$1"
        local patterns="$2"
        [[ -z "$patterns" ]] && return 1
        python3 -c '
import fnmatch, sys
file = sys.argv[1]
patterns = sys.argv[2].split("\n")
for p in patterns:
    p = p.strip()
    if not p:
        continue
    candidates = [p]
    if p.startswith("**/"):
        candidates.append(p[3:])
    for c in candidates:
        if fnmatch.fnmatch(file, c) or fnmatch.fnmatch(file, "*/" + c):
            sys.exit(0)
sys.exit(1)
' "$file" "$patterns" 2>/dev/null
    }

    # 处理每个变更文件
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        [[ -f "$file" ]] || continue

        # 根据 .review-rules.yml 的 exclude_patterns 跳过文件
        if is_excluded_by_rules "$file" "$EXCLUDE_PATTERNS"; then
            progress "  ${YELLOW}⏭️  ${file} 被项目规则排除${NC}"
            continue
        fi

        # 跳过二进制文件
        file_type=$(file -b --mime-type "$file" 2>/dev/null || echo "application/octet-stream")
        case "$file_type" in
            text/*|application/javascript|application/json|application/xml) ;;
            *) continue ;;
        esac

        # 跳过 lock 文件和生成文件
        case "$file" in
            *package-lock.json|*yarn.lock|*pnpm-lock.yaml|*Cargo.lock|*poetry.lock|*Gemfile.lock) continue ;;
            *.min.js|*.min.css|*.map|dist/*|build/*|node_modules/*|.git/*) continue ;;
        esac

        if [[ "$FILE_COUNT" -ge "$MAX_FILES" ]]; then
            progress "  ${YELLOW}... 已达到最大文件数限制 (${MAX_FILES})${NC}"
            break
        fi

        file_lines=$(wc -l < "$file" | tr -d ' ')
        if [[ "$file_lines" -gt "$CONTEXT_LINES" ]]; then
            progress "  ${YELLOW}⚠️  ${file} 超过 ${CONTEXT_LINES} 行，截取前 ${CONTEXT_LINES} 行${NC}"
            content=$(head -n "$CONTEXT_LINES" "$file")
        else
            content=$(cat "$file")
        fi

        CODE_CONTEXT="${CODE_CONTEXT}### File: ${file}
\`\`\`
${content}
\`\`\`

"
        FILE_COUNT=$((FILE_COUNT + 1))
        progress "  ${GREEN}✓${NC} ${file} (${file_lines} 行)"
    done <<< "$CHANGED_FILES"
fi

if [[ "$FILE_COUNT" -eq 0 ]]; then
    progress "${YELLOW}没有可审查的文件${NC}"
    exit 0
fi

progress ""
progress "${BLUE}共收集 ${FILE_COUNT} 个文件${NC}"
progress ""

# ═══════════════════════════════════════════════════════════════
# 项目自定义规则生成 prompt（函数定义已提前）
# ═══════════════════════════════════════════════════════════════

# 根据审查文件路径推断涉及的语言标签
detect_review_languages() {
    local files_input="$1"
    python3 -c '
import os, sys
files = sys.argv[1].split("\n")
EXT_TO_LANG = {
    ".java": "java", ".kt": "java",
    ".py": "python", ".ipynb": "python",
    ".js": "javascript", ".jsx": "javascript",
    ".ts": "typescript", ".tsx": "typescript", ".vue": "typescript",
    ".go": "go",
    ".php": "php",
    ".sql": "database", ".prisma": "database",
    ".yaml": "devops", ".yml": "devops", ".tf": "devops",
    ".swift": "mobile", ".m": "mobile", ".dart": "mobile",
    ".sol": "blockchain",
    ".h5": "aiml", ".onnx": "aiml",
}
langs = set()
for f in files:
    f = f.strip()
    if not f:
        continue
    base = os.path.basename(f)
    if base.startswith("Dockerfile"):
        langs.add("devops")
        continue
    ext = os.path.splitext(f)[1].lower()
    if ext in EXT_TO_LANG:
        langs.add(EXT_TO_LANG[ext])
print(",".join(sorted(langs)))
' "$files_input"
}

# 结构化生成 prompt 中的规则部分
build_structured_rules_prompt() {
    local json_data="$1"
    local detected_langs="${2:-}"
    python3 -c '
import json, sys
data = json.loads(sys.argv[1])
detected = set(sys.argv[2].split(",")) if sys.argv[2] else set()
disabled = data.get("disable", [])
custom_rules = data.get("custom_rules", [])
behavior = data.get("behavior", {})
languages = data.get("languages", {})

def rule_applies(rule):
    langs = rule.get("languages", [])
    if not langs:
        return True
    if not detected:
        return True
    return bool(set(langs) & detected)

parts = []

if disabled:
    parts.append("## Disabled Default Rules / 已禁用默认规则")
    parts.append("以下默认规则 ID 在本次审查中跳过不执行：")
    for r in disabled:
        parts.append(f"- {r}")
    parts.append("请确保审查输出中不包含这些规则的发现。")
    parts.append("")

filtered_rules = [r for r in custom_rules if rule_applies(r)]
if filtered_rules:
    parts.append("## Custom Rules / 自定义规则")
    if detected:
        parts.append("检测到当前审查涉及语言: " + ", ".join(sorted(detected)))
    parts.append("以下规则必须执行，问题标记前缀为 [ProjectRule:<id>]：")
    parts.append("")
    for rule in filtered_rules:
        rid = rule.get("id", "project:unknown")
        cat = rule.get("category", "Custom")
        sev = rule.get("severity", "suggestion")
        langs = rule.get("languages", [])
        msg = rule.get("message", "")
        chk = rule.get("check", "")
        parts.append(f"### [{rid}] — {cat} / {sev}")
        if langs:
            parts.append("- 适用语言: " + ", ".join(langs))
        if msg:
            parts.append("- 规则说明: " + msg)
        if chk:
            parts.append("- 检查方法: " + chk)
        parts.append("")

if behavior:
    parts.append("## Behavior Overrides / 审查行为覆盖")
    if "max_function_lines" in behavior:
        parts.append("- 函数最大行数: " + str(behavior["max_function_lines"]))
    if "project_context" in behavior:
        parts.append("- 项目上下文: " + behavior["project_context"])
    if "exclude_patterns" in behavior:
        parts.append("- 排除路径: " + ", ".join(behavior["exclude_patterns"]))
    parts.append("")

if languages:
    applicable = sorted([l for l in languages.keys() if not detected or l in detected])
    if applicable:
        parts.append("## Language-Specific Overrides / 语言专属覆盖")
        for lang in applicable:
            parts.append(f"### {lang}")
            lang_rules = languages[lang].get("custom_rules", [])
            lang_behavior = languages[lang].get("behavior", {})
            if lang_rules:
                parts.append("额外自定义规则：")
                for rule in lang_rules:
                    rid = rule.get("id", lang + ":unknown")
                    msg = rule.get("message", "")
                    parts.append(f"- [{rid}] {msg}")
            if lang_behavior:
                parts.append("行为覆盖：")
                for k, v in lang_behavior.items():
                    parts.append(f"- {k}: {v}")
        parts.append("")

print("\n".join(parts))
' "$json_data" "$detected_langs"
}

# 根据收集到的文件推断涉及的语言
DETECTED_LANGUAGES=""
if [[ -n "$FILE_PATH" ]]; then
    DETECTED_LANGUAGES=$(detect_review_languages "$FILE_PATH" 2>/dev/null || true)
elif [[ -n "$CHANGED_FILES" ]]; then
    DETECTED_LANGUAGES=$(detect_review_languages "$CHANGED_FILES" 2>/dev/null || true)
fi

RULES_FILE=$(discover_rules_file "$(cd "$TARGET_DIR" && pwd)" 2>/dev/null || true)

CUSTOM_RULES_SECTION=""
PROJECT_CONTEXT=""
if [[ -n "$RULES_FILE" ]]; then
    progress "${BLUE}【自定义规则】${NC}"
    progress "  发现项目规则文件: ${RULES_FILE}"

    RULES_JSON=$(parse_review_rules "$RULES_FILE" 2>/dev/null || echo '{"disable":[],"custom_rules":[],"behavior":{},"languages":{}}')
    CUSTOM_RULES_SECTION=$(build_structured_rules_prompt "$RULES_JSON" "$DETECTED_LANGUAGES" 2>/dev/null || echo "")

    PROJECT_CONTEXT=$(python3 -c '
import json, sys
data = json.loads(sys.argv[1])
print(data.get("behavior", {}).get("project_context", ""))
' "$RULES_JSON" 2>/dev/null || true)

    progress "  ${GREEN}✓${NC} 已加载并解析自定义规则"
    progress ""
fi

# 项目上下文注入项
PROJECT_CONTEXT_ITEM=""
if [[ -n "$PROJECT_CONTEXT" ]]; then
    PROJECT_CONTEXT_ITEM="- **Project Context**: ${PROJECT_CONTEXT}"
fi

# ===== 构建 Prompt =====

progress "${BLUE}【构建审查提示】${NC}"

case "$DEPTH" in
    quick)
        PROMPT_INSTRUCTIONS="执行快速代码审查。只关注关键问题和安全隐患。保持简洁。"
        ;;
    standard)
        PROMPT_INSTRUCTIONS="执行全面的代码审查。深度分析代码质量、安全性、性能、可维护性和潜在 Bug。对每个发现的问题，必须提供具体的代码位置、问题解释、影响分析，以及可直接应用的 Before/After 修复代码。"
        ;;
    deep)
        PROMPT_INSTRUCTIONS="执行深度全面的代码审查。分析架构、设计模式、边界情况、安全漏洞、性能瓶颈、测试覆盖率和可维护性。对每个问题提供详细解释、影响分析、以及可直接复制使用的 Before/After 代码修复方案。"
        ;;
esac

# 摘要模式覆盖详细说明
SUMMARY_HINT=""
if [[ "$SUMMARY_MODE" == "1" ]]; then
    PROMPT_INSTRUCTIONS="执行摘要式代码审查。只输出总体结论、问题数量统计、以及最多 5 个最关键问题的简要说明。"
    SUMMARY_HINT="

## 摘要模式约束
当前使用摘要模式（--summary），请严格遵守以下格式，忽略下方默认输出格式中的详细展开要求：
- 输出结构为：Context → Summary → Issue Statistics → Top Critical Issues（最多 5 条） → Top Warnings（最多 3 条，可选）
- Critical Issues 最多 5 条，Warnings 最多 3 条，不输出 Suggestions 和 Positive Notes
- 每条问题只需要问题标题、文件路径和行号、一句话描述，不要展开 Before/After 代码对比
- 不要输出详细修复方案、示例格式和 Positive Notes"
fi

PROMPT="你是一位拥有 10 年经验的资深代码审查专家。请对以下代码进行深度审查，输出结构化的 Markdown 格式审查报告。

## 审查要求
${PROMPT_INSTRUCTIONS}${SUMMARY_HINT}

## 输出格式（必须严格遵循）
请使用中文，按以下结构输出：

---

## Context
- **Intent**: 代码意图（这段代码要解决什么问题）
- **Scope**: 影响范围（涉及哪些文件、模块、页面）
- **Risk Level**: LOW / MEDIUM / HIGH / CRITICAL
${PROJECT_CONTEXT_ITEM}

## Summary
2-4 句总体评估。明确给出结论：Approve / Comment / Request Changes。

## Critical Issues 🔴
必须修复的关键问题（Bug、安全隐患、逻辑错误）。每个问题必须包含：
1. 问题标题
2. 文件路径和具体行号范围，格式如 [file.vue:249-255]
3. 问题描述：为什么会出现这个问题，有什么影响
4. 修复方案：提供可直接使用的 Before/After 代码对比

示例格式：
1. **单日期与日期范围条件可能同时生效** — 查询结果异常
   [list.vue:249-255, 339-342]
   handleDateSelected 会清空 departDates，但 handleDateRangeChange 不会清空 departDate。用户先选单日期再选范围时，后端会同时收到两个互斥条件。
   // 当前代码（Before）
   \`\`\`js
   const handleDateRangeChange = () => {
       queryParams.pageNum = 1;
       getList();
   };
   \`\`\`
   // 修复后（After）
   \`\`\`js
   const handleDateRangeChange = () => {
       queryParams.departDate = '';      // 清除单日期
       queryParams.pageNum = 1;
       getList();
   };
   \`\`\`

## Warnings 🟡
需要注意的警告（未使用的代码、潜在风险、不规范实践）。同样包含文件路径和具体建议。

## Suggestions 💡
改进建议（重构、优化、最佳实践）。例如：
- 文件过大建议拆分
- 内联样式建议提取为 CSS 类
- 通用函数建议提取到 utils
每个建议都要说明原因和具体做法。

## Positive Notes ✅
做得好的地方。至少列出 3-5 点具体优点，例如：
- 功能分区清晰
- 防抖处理到位
- 缓存机制完善
- 有降级方案
- 表单提交有 loading 状态

---

## 待审查代码

${CODE_CONTEXT}"

# 注入项目自定义规则
if [[ -n "$CUSTOM_RULES_SECTION" ]]; then
    PROMPT="${PROMPT}

${CUSTOM_RULES_SECTION}"
fi

progress "  ${GREEN}✓${NC} 提示构建完成"
if [[ "$SUMMARY_MODE" == "1" ]]; then
    progress "  ${BLUE}ℹ${NC} 摘要模式已启用（--summary）：只输出关键结论和统计"
fi
progress ""

# ===== 调用 API =====

# 在 quiet 模式下也显示分析提示（避免用户以为卡死）
echo -e "${YELLOW}⏳ 正在分析代码，可能需要 30-90 秒...${NC}"
progress ""

progress "${BLUE}API 提供商: ${API_PROVIDER} | 模型: ${MODEL}${NC}"
progress ""

API_START_TIME=$(date +%s)

RESPONSE_FILE=$(mktemp)

# 根据 API 类型构建请求
if [[ "$API_TYPE" == "anthropic" ]]; then
    # Anthropic Messages API 格式
    JSON_PAYLOAD=$(python3 -c "
import json, sys
prompt = sys.argv[1]
model = sys.argv[2]
max_tokens = int(sys.argv[3])
payload = {
    'model': model,
    'max_tokens': max_tokens,
    'messages': [{'role': 'user', 'content': prompt}]
}
print(json.dumps(payload))
" "$PROMPT" "$MODEL" "$MAX_TOKENS")

    # 确保 URL 以 /v1/messages 结尾
    API_ENDPOINT="$API_URL"
    if [[ "$API_ENDPOINT" != */v1/messages ]]; then
        API_ENDPOINT="${API_ENDPOINT%/}/v1/messages"
    fi

    HTTP_CODE=$(curl -s -w "%{http_code}" \
        --max-time 180 \
        --connect-timeout 30 \
        -X POST \
        -H "Content-Type: application/json" \
        -H "x-api-key: ${API_KEY}" \
        -H "anthropic-version: 2023-06-01" \
        -d "$JSON_PAYLOAD" \
        "$API_ENDPOINT" \
        -o "$RESPONSE_FILE" 2>/dev/null || echo "000")
else
    # OpenAI 兼容格式 (Kimi / DeepSeek / DashScope / OpenAI)
    JSON_PAYLOAD=$(python3 -c "
import json, sys
prompt = sys.argv[1]
model = sys.argv[2]
max_tokens = int(sys.argv[3])
payload = {
    'model': model,
    'max_tokens': max_tokens,
    'messages': [{'role': 'user', 'content': prompt}]
}
print(json.dumps(payload))
" "$PROMPT" "$MODEL" "$MAX_TOKENS")

    # 确保 URL 以 /v1/chat/completions 结尾
    API_ENDPOINT="$API_URL"
    if [[ "$API_ENDPOINT" != */v1/chat/completions ]]; then
        API_ENDPOINT="${API_ENDPOINT%/}/v1/chat/completions"
    fi

    HTTP_CODE=$(curl -s -w "%{http_code}" \
        --max-time 180 \
        --connect-timeout 30 \
        -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${API_KEY}" \
        -d "$JSON_PAYLOAD" \
        "$API_ENDPOINT" \
        -o "$RESPONSE_FILE" 2>/dev/null || echo "000")
fi

API_END_TIME=$(date +%s)
API_DURATION=$((API_END_TIME - API_START_TIME))

progress "${BLUE}API 响应耗时: ${API_DURATION} 秒${NC}"
progress ""

# ===== 解析响应 =====

if [[ "$HTTP_CODE" != "200" ]]; then
    echo -e "${RED}❌ API 请求失败 (HTTP ${HTTP_CODE})${NC}" >&2
    if [[ -s "$RESPONSE_FILE" ]]; then
        echo -e "${YELLOW}响应内容:${NC}" >&2
        cat "$RESPONSE_FILE" >&2
    fi
    rm -f "$RESPONSE_FILE"
    exit 1
fi

# 根据 API 类型解析响应
if [[ "$API_TYPE" == "anthropic" ]]; then
    REPORT_CONTENT=$(python3 -c "
import json, sys
try:
    with open(sys.argv[1], 'r') as f:
        data = json.load(f)
    if 'content' in data and len(data['content']) > 0:
        for block in data['content']:
            if block.get('type') == 'text':
                print(block.get('text', ''))
                break
    elif 'error' in data:
        print('API_ERROR: ' + str(data['error']))
    else:
        print('API_ERROR: 意外的响应结构')
except Exception as e:
    print('PARSE_ERROR: ' + str(e))
" "$RESPONSE_FILE")
else
    REPORT_CONTENT=$(python3 -c "
import json, sys
try:
    with open(sys.argv[1], 'r') as f:
        data = json.load(f)
    if 'choices' in data and len(data['choices']) > 0:
        choice = data['choices'][0]
        if 'message' in choice:
            print(choice['message'].get('content', ''))
        else:
            print(choice.get('text', ''))
    elif 'error' in data:
        print('API_ERROR: ' + str(data['error']))
    else:
        print('API_ERROR: 意外的响应结构')
except Exception as e:
    print('PARSE_ERROR: ' + str(e))
" "$RESPONSE_FILE")
fi

if [[ -z "$REPORT_CONTENT" ]]; then
    echo -e "${RED}❌ API 返回内容为空${NC}" >&2
    rm -f "$RESPONSE_FILE"
    exit 1
fi

case "$REPORT_CONTENT" in
    API_ERROR*|PARSE_ERROR*)
        echo -e "${RED}❌ 解析 API 响应失败: ${REPORT_CONTENT}${NC}" >&2
        rm -f "$RESPONSE_FILE"
        exit 1
        ;;
esac

progress "${GREEN}✅ 成功获取审查报告${NC}"
progress ""

# ===== 输出报告 =====

echo "$REPORT_CONTENT"
echo ""

# ===== 保存报告 =====

{
    echo "# AI 代码审查报告"
    echo ""
    echo "- **生成时间**: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "- **模型**: ${MODEL}"
    echo "- **深度**: ${DEPTH}"
    echo "- **审查文件数**: ${FILE_COUNT}"
    echo "- **API 耗时**: ${API_DURATION} 秒"
    echo ""
    echo "---"
    echo ""
    echo "$REPORT_CONTENT"
} > "$REPORT_FILE"

progress "${GREEN}✅ 报告已保存: ${REPORT_FILE}${NC}"
progress ""

# ===== 汇总 =====

progress "${CYAN}${BOLD}【完成】${NC}"
progress "  审查文件数: ${FILE_COUNT}"
progress "  API 耗时: ${API_DURATION} 秒"
progress "  报告文件: ${REPORT_FILE}"
progress ""

rm -f "$RESPONSE_FILE"
exit 0
