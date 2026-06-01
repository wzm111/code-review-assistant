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

    # 处理每个变更文件
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        [[ -f "$file" ]] || continue

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
# 项目自定义规则发现（从目标目录向上查找 .review-rules.yml）
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

RULES_FILE=$(discover_rules_file "$(cd "$TARGET_DIR" && pwd)" 2>/dev/null || true)

CUSTOM_RULES_SECTION=""
if [[ -n "$RULES_FILE" ]]; then
    progress "${BLUE}【自定义规则】${NC}"
    progress "  发现项目规则文件: ${RULES_FILE}"
    RULES_CONTENT=$(cat "$RULES_FILE" | sed 's/^/    /')
    CUSTOM_RULES_SECTION="
## Project Custom Rules / 项目自定义规则
以下规则来自项目根目录的 .review-rules.yml 文件，请与默认规则合并执行：

${RULES_CONTENT}

请在审查输出中，对来自自定义规则的问题使用 [ProjectRule:<规则ID>] 前缀标记。
"
    progress "  ${GREEN}✓${NC} 已加载自定义规则"
    progress ""
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

PROMPT="你是一位拥有 10 年经验的资深代码审查专家。请对以下代码进行深度审查，输出结构化的 Markdown 格式审查报告。

## 审查要求
${PROMPT_INSTRUCTIONS}

## 输出格式（必须严格遵循）
请使用中文，按以下结构输出：

---

## Context
- **Intent**: 代码意图（这段代码要解决什么问题）
- **Scope**: 影响范围（涉及哪些文件、模块、页面）
- **Risk Level**: LOW / MEDIUM / HIGH / CRITICAL

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
