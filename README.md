# Code Review Assistant / 代码审查助手

> English | [中文](#代码审查助手)

A universal code review toolkit for AI agents. Detects your tech stack and applies language-specific rules on top of universal best practices. Works with Claude Code, Cursor, Claude Desktop (MCP), Windsurf, VS Code + Copilot, Kimi, Qode, Codex, and any AI that supports shell commands or MCP.

**AI 通用代码审查工具包。自动检测技术栈，在通用最佳实践之上应用语言专项规则。支持 Claude Code、Cursor、Claude Desktop（MCP）、Windsurf、VS Code + Copilot、Kimi、Qode、Codex 及任何支持 shell 命令或 MCP 的 AI。**

## Quick Start / 快速开始

```bash
# 1. 安装 skill
git clone https://github.com/wzm111/code-review-assistant.git ~/.claude/skills/code-review-assistant

# 2. 在项目目录下执行定时审查（零配置，开箱即用）
cd /path/to/your-project
scheduled-review --now

# 3. 或在 Claude Code 中直接调用 skill
/code-review-assistant

# 4. 完整命令示例：安全扫描 + 影响分析 + 导出报告
scheduled-review --now --scan-secrets --scan-deps --impact --context --export markdown

# 5. 上线前深度检查
scheduled-review --now --db-migration --api-contract --error-handling --resource-leak \
  --config-drift --naming --codeowners --license

# 6. 摘要模式：快速获取关键结论和统计（适合大 PR 或 CI 门禁）
bash scripts/ai-code-review.sh . "" standard --summary

# 7. 安装定时任务（工作日每天 9:00 自动审查 + 飞书通知）
scheduled-review --install --time 09:00 --days 1-5 \
  --notify feishu --webhook "https://open.feishu.cn/open-apis/bot/v2/hook/xxx"
```

---

## Installation / 安装

### Universal Installer (Recommended) / 通用安装器（推荐）

**One command installs for any AI platform:**

```bash
git clone https://github.com/wzm111/code-review-assistant.git
cd code-review-assistant
bash install.sh
```

The installer will ask which platform you're using. Supports:
- **Claude Code** / **Claude Desktop** (via MCP)
- **Cursor** (MCP + `.cursorrules`)
- **VS Code + GitHub Copilot** (settings + review rules)
- **Generic CLI** (works with any AI that can run shell commands)

### Platform-Specific Quick Install / 各平台快速安装

| Platform | Install Command |
|----------|----------------|
| **Claude Code** | `bash install.sh --mode claude` |
| **Cursor** | `bash install.sh --mode cursor` |
| **Claude Desktop** | `bash install.sh --mode mcp` |
| **VS Code + Copilot** | `bash install.sh --mode vscode` |
| **Global CLI** | `bash install.sh --mode cli` |
| **All Platforms** | `bash install.sh --mode all` |

### Manual Install for Claude Code / 手动安装（Claude Code）

```bash
mkdir -p ~/.claude/skills/code-review-assistant
cp -r /path/to/this/repo/* ~/.claude/skills/code-review-assistant/
```

---

## Usage / 使用方法

### Claude Code
- **手动调用 / Manual invoke**: 输入 `/code-review-assistant`
- **自动触发 / Auto-trigger**: 说 "review this code" 或 "check this PR"

### Cursor (with MCP)
AI 自动发现所有审查工具。直接对话即可：
- "Scan this repo for secrets"
- "Check naming conventions in the src/ folder"
- "Run a full security review"

### VS Code + GitHub Copilot
Copilot 会读取 `.copilot-review-rules.md` 中的审查指令，自动在代码审查时应用。

### Generic CLI (任何 AI)
所有脚本可直接运行，AI 通过 shell tool 调用：
```bash
bash scripts/scan-secrets.sh . critical
bash scripts/naming-convention.sh src/
bash scripts/code-smell.sh .
```

### Scheduled Review / 定时审查
配置 `scheduled-review.yml` 并运行 `scripts/scheduled-review.sh`：
```bash
# 立即执行
scheduled-review --now

# 安装定时任务（工作日 9:00）
scheduled-review --install --time 09:00 --days 1-5
```

---

## Multi-Platform Support / 多平台支持

| Platform | Integration | How AI Uses It |
|----------|-------------|----------------|
| **Claude Code** | Native Skill | `/code-review-assistant` command |
| **Claude Desktop** | MCP Server | Auto-discovers 25+ review tools |
| **Cursor** | MCP + `.cursorrules` | Auto-discovers tools + rules file |
| **Windsurf** | MCP Server | Auto-discovers review tools |
| **VS Code + Copilot** | Settings + Rules | Copilot reads review rules |
| **Kimi / Qode / 通义** | CLI Scripts | AI runs bash scripts via tool call |
| **Codex (OpenAI)** | CLI Scripts | Via function calling or shell |
| **CI/CD (GitHub Actions)** | Direct Scripts | Run in pipeline steps |

### How It Works on Each Platform / 各平台适配原理

**Claude Code** — Uses the native `SKILL.md` skill format. The `install.sh` copies files to `~/.claude/skills/`, and Claude Code auto-registers the `/code-review-assistant` slash command.

**Claude Desktop / Cursor / Windsurf** — Uses the **MCP (Model Context Protocol)** standard. The `mcp/server.js` exposes 25+ review tools via stdio JSON-RPC. MCP-compatible clients auto-discover these tools and present them to the AI. Cursor additionally gets a `.cursorrules` file that teaches the AI when and how to invoke the scripts.

**VS Code + GitHub Copilot** — Generates `.copilot-review-rules.md` containing review instructions and priorities. Copilot reads this file during inline code review and chat, applying the rules without needing a plugin.

**Kimi / Qode / 通义 / Codex** — These AIs support **shell command execution** via tool calling or function calling. The `install.sh --mode cli` installs a `cra` wrapper command. The AI runs `cra scan-secrets .` or `bash scripts/code-smell.sh .` and receives plain-text results for analysis.

**GitHub Actions** — No AI integration needed. Copy `scripts/*.sh` into your workflow and run them as CI steps. Results are emitted as workflow logs.

**Other Platforms / 其他平台** — Also supports [阿里云效、腾讯云 CODING、Azure DevOps、Jenkins](docs/platform-adapters.md). The bash scripts are platform-agnostic; only the trigger YAML differs.

---

## Architecture / 架构

```
code-review-assistant/
├── install.sh                  # Universal installer for all platforms / 通用安装器
├── SKILL.md                    # Claude Code entry point / Claude Code 入口
├── mcp/
│   ├── package.json            # MCP server dependencies
│   └── server.js               # MCP server (Claude Desktop, Cursor, Windsurf)
├── scheduled-review.yml        # Timer configuration / 定时审查配置
├── .github/
│   └── workflows/
│       └── code-review.yml       # CI workflow for automated PR review / 自动化PR审查流水线
├── rules/                      # Language-specific review rules / 语言专项规则
│   ├── java.md
│   ├── frontend.md
│   ├── database.md
│   ├── python.md
│   ├── go.md
│   ├── php.md
│   ├── devops.md
│   ├── mobile.md
│   ├── bigdata.md
│   ├── aiml.md
│   ├── blockchain.md
│   └── security.md
├── examples/                   # CI/CD platform templates / 云平台流水线模板
│   ├── aliyun-flow.yml         # 阿里云效 Flow
│   ├── tencent-coding.yml      # 腾讯云 CODING
│   ├── azure-pipelines.yml     # Azure DevOps
│   └── Jenkinsfile             # Jenkins
├── docs/
│   └── platform-adapters.md    # Multi-cloud platform guide / 多云平台适配指南
└── scripts/                    # 40 review scripts + 8 notifiers
    ├── scheduled-review.sh
    ├── scan-secrets.sh
    ├── scan-deps.sh
    ├── naming-convention.sh
    ├── code-smell.sh
    ├── complexity-analysis.sh
    ├── concurrency-check.sh
    ├── error-handling.sh
    ├── resource-leak.sh
    ├── review-history.sh         # Review history tracking / 审查历史追踪
    ├── type-safety.sh
    ├── test-coverage.sh
    ├── test-quality.sh
    ├── api-contract.sh
    ├── db-migration.sh
    ├── architecture-check.sh
    ├── impact-analysis.sh
    ├── pii-scan.sh
    ├── supply-chain.sh
    ├── config-drift.sh
    ├── reuse-check.sh
    ├── bundle-size.sh
    ├── a11y-check.sh
    ├── i18n-check.sh
    ├── license-check.sh
    ├── lint-check.sh
    ├── commit-lint.sh
    ├── reviewer-assign.sh
    ├── export-report.sh
    ├── perf-benchmark.sh
    ├── changelog-gen.sh
    ├── codeowners-check.sh
    ├── feature-flag.sh
    ├── doc-quality.sh
    ├── severity-gate.sh          # Severity scoring + quality gate / 严重度评分+质量门禁
    ├── cross-file-context.sh     # Cross-file impact analysis / 跨文件上下文分析
    ├── pr-describe.sh            # PR description auto-generation / PR描述自动生成
    ├── pr-comment.sh             # PR inline comments / PR内联评论
    ├── pr-context.sh             # PR context reader / PR上下文读取
    ├── auto-fix.sh               # Auto-fix mode / 自动修复模式
    └── notifiers/
        ├── feishu.sh
        ├── dingtalk.sh
        ├── wecom.sh
        ├── slack.sh
        ├── telegram.sh
        ├── line.sh
        ├── whatsapp.sh
        └── email.sh
```

### Component Descriptions / 组件功能说明

#### Core / 核心组件
| Component | Description / 功能说明 |
|-----------|----------------------|
| `install.sh` | Universal installer supporting 6 platform modes (Claude Code, MCP, Cursor, VS Code, CLI, All) / 支持6种平台模式的通用安装器 |
| `SKILL.md` | Claude Code skill entry with language detection and review rules / 带语言检测和审查规则的Claude Code入口 |
| `mcp/server.js` | MCP server exposing 30+ review tools via stdio JSON-RPC / 通过stdio JSON-RPC暴露30+审查工具的MCP服务器 |
| `scheduled-review.yml` | Timer configuration for automated scheduled reviews / 定时自动审查的配置文件 |

#### Security & Safety / 安全与可靠性 (★★★★★)
| Script | Description / 功能说明 |
|--------|----------------------|
| `scan-secrets.sh` | Detect hardcoded API keys, tokens, passwords, private keys / 检测硬编码密钥、Token、密码、私钥 |
| `scan-deps.sh` | Check dependencies for known CVE vulnerabilities / 检查各语言依赖的已知CVE漏洞 |
| `pii-scan.sh` | Scan for personally identifiable information leaks / 扫描手机号、身份证、银行卡等个人信息泄露 |
| `concurrency-check.sh` | Detect race conditions, deadlocks, goroutine leaks / 检测死锁、竞态条件、协程泄露 |
| `error-handling.sh` | Find empty catches, swallowed errors, unhandled rejections / 检测空catch、异常吞没、未处理Promise |
| `resource-leak.sh` | Detect unclosed files, connections, timers, listeners / 检测未关闭的文件、连接、定时器、监听器 |
| `supply-chain.sh` | Detect typosquatting and malicious packages / 检测拼写劫持和恶意包 |

#### Code Quality / 代码质量 (★★★★☆)
| Script | Description / 功能说明 |
|--------|----------------------|
| `severity-gate.sh` | Weighted severity scoring with configurable quality gates / 加权严重度评分与可配置质量门禁 |
| `auto-fix.sh` | Auto-fix trailing whitespace, formatting, unused imports / 自动修复行尾空格、格式化、未使用导入 |
| `lint-check.sh` | Multi-language linting (ESLint, Prettier, Black, gofmt) / 多语言代码规范自动检查 |
| `code-smell.sh` | Detect god classes, long functions, deep nesting / 检测上帝类、长函数、深嵌套 |
| `type-safety.sh` | Check `any` abuse, missing type guards, `@ts-ignore` / 检测any滥用、类型收窄缺失、ts-ignore |
| `architecture-check.sh` | Check layer violations and circular dependencies / 检测分层违规、循环依赖、错误导入 |
| `naming-convention.sh` | Verify variable/function/file/directory naming conventions / 变量/函数/文件/目录命名规范检查 |
| `config-drift.sh` | Find configuration differences between environments / 检测环境间配置差异、硬编码密钥 |

#### Testing / 测试 (★★★☆☆)
| Script | Description / 功能说明 |
|--------|----------------------|
| `test-quality.sh` | Detect flaky tests, missing boundaries, no teardown / 检测脆弱测试、边界缺失、无清理 |
| `test-coverage.sh` | Analyze test coverage for new code / 新增代码的测试覆盖分析 |
| `cross-file-context.sh` | Cross-file caller/callee analysis and risk assessment / 跨文件调用链分析与风险评估 |
| `pr-describe.sh` | Auto-generate PR title and description from git diff / 从diff自动生成PR标题和描述 |
| `reuse-check.sh` | Find duplicate code and magic values / 检测重复代码、魔法值、相似函数 |
| `db-migration.sh` | Review migration safety (locks, drops, transactions) / 迁移安全：锁表、删除、事务 |
| `api-contract.sh` | Detect OpenAPI/Protobuf breaking changes / API契约变更与兼容性检测 |
| `impact-analysis.sh` | Analyze module/API/DB impact with risk rating / 模块/API/数据库影响与风险评级 |

#### CI/CD & Automation / 持续集成与自动化 (★★☆☆☆)
| Script | Description / 功能说明 |
|--------|----------------------|
| `pr-comment.sh` | Post review findings as inline GitHub PR comments / 将审查结果发布为PR行级评论 |
| `.github/workflows/code-review.yml` | Full CI pipeline with gates, auto-fix, and comments / 自动化PR审查流水线 |
| `perf-benchmark.sh` | Detect performance benchmark regressions / 性能基准测试回归分析 |
| `bundle-size.sh` | Analyze dependency and build artifact size / 依赖体积与构建产物分析 |
| `doc-quality.sh` | Check missing JSDoc, stale comments, TODO tracking / 缺文档、过时注释、TODO追踪 |
| `commit-lint.sh` | Validate Conventional Commits format / 提交信息格式检查 |
| `codeowners-check.sh` | Verify CODEOWNERS coverage for critical paths / 关键路径的代码所有者匹配 |
| `license-check.sh` | Check license compliance and GPL/AGPL risks / 许可证合规与传染性风险检测 |

#### Utilities / 工具 (★☆☆☆☆)
| Script | Description / 功能说明 |
|--------|----------------------|
| `scheduled-review.sh` | Configurable timer for recurring code reviews / 可配置的定时审查调度器 |
| `pr-context.sh` | Read PR commit context, change stats, linked issues / PR提交上下文、变更统计、关联Issue |
| `review-history.sh` | Save and compare review results over time / 保存并对比历史审查结果 |
| `export-report.sh` | Export reviews to Markdown or HTML / Markdown/HTML报告导出 |
| `complexity-analysis.sh` | Cyclomatic complexity and code duplication analysis / 圈复杂度、函数长度、重复检测 |
| `changelog-gen.sh` | Auto-generate changelog from commits / 基于提交规范自动生成变更日志 |
| `feature-flag.sh` | Detect stale feature flag cleanup opportunities / 过期功能开关代码清理 |
| `reviewer-assign.sh` | Auto-recommend reviewers by code familiarity / 按代码熟悉度自动推荐Reviewer |
| `i18n-check.sh` | Find hardcoded text and missing i18n keys / 硬编码文案与缺失i18n key |
| `a11y-check.sh` | Check accessibility issues (alt, keyboard, contrast) / 缺alt、无键盘支持、对比度 |

#### Notifications / 通知渠道
| Script | Channel | Description / 功能说明 |
|--------|---------|----------------------|
| `feishu.sh` | 飞书 Lark | Send review results to Feishu groups |
| `dingtalk.sh` | 钉钉 | Send review results to DingTalk groups |
| `wecom.sh` | 企业微信 | Send review results to WeCom groups |
| `slack.sh` | Slack | Send review results to Slack channels |
| `telegram.sh` | Telegram | Send review results via Telegram Bot |
| `line.sh` | LINE Notify | Send review results to LINE |
| `whatsapp.sh` | WhatsApp | Send review results via Twilio WhatsApp |
| `email.sh` | Email | Send review results via SMTP |

---

## Supported Languages & Frameworks / 支持的语言与框架

| Language/Framework | Rules File | Key Checks / 核心检查点 |
|-------------------|-----------|------------------------|
| **Java / Spring** | `rules/java.md` | Concurrency, Spring tx, try-with-resources / 并发集合、Spring事务、资源管理 |
| **JS / TS / Frontend + Node.js** | `rules/frontend.md` | React hooks, Vue key, XSS, lazy loading / ReactHooks、VueKey、XSS防护、懒加载 |
| **Node.js / Express / Koa** | `rules/frontend.md` | Graceful shutdown, EventEmitter leaks, Stream backpressure / 优雅退出、EventEmitter泄漏、Stream背压 |
| **Python** | `rules/python.md` | Mutable defaults, GIL, type hints, pandas / 可变默认参数、GIL、类型注解、向量化 |
| **Go** | `rules/go.md` | Goroutine leaks, error wrapping, defer / Goroutine泄漏、错误包装、defer顺序 |
| **PHP / Laravel** | `rules/php.md` | Eloquent N+1, CSRF, PSR-12, opcache / N+1查询、CSRF、代码规范、缓存 |
| **SQL / Database** | `rules/database.md` | Index usage, query plans, N+1, DECIMAL / 索引失效、执行计划、金额精度 |
| **DevOps** | `rules/devops.md` | Multi-stage Docker, K8s probes, Terraform / 多阶段构建、探针、状态管理 |
| **Mobile** | `rules/mobile.md` | iOS weak self, Android coroutines, Flutter / 循环引用、协程、状态管理 |
| **Big Data** | `rules/bigdata.md` | Spark shuffle, Flink watermark, Hive partitions / 数据倾斜、水位线、分区裁剪 |
| **AI / ML** | `rules/aiml.md` | Data leakage, AMP, model versioning, SHAP / 数据泄漏、混合精度、模型版本、可解释性 |
| **Blockchain** | `rules/blockchain.md` | Reentrancy, gas optimization, proxy pattern / 重入攻击、Gas优化、代理模式 |
| **Security Deep-Dive** | `rules/security.md` | OWASP Top 10, pentest, crypto, compliance / 渗透测试、加密算法、合规审计 |

---

## Review Output Format / 审查输出格式

| Severity / 严重级别 | Icon / 图标 | Action / 处理建议 |
|-------------------|------------|------------------|
| Critical / 严重 | :red_circle: | Must fix before merge / 合并前必须修复 |
| Warning / 警告 | :yellow_circle: | Should address / 建议处理 |
| Suggestion / 建议 | :bulb: | Nice-to-have / 可选优化 |
| Positive / 亮点 | :white_check_mark: | What was done well / 做得好的地方 |

Findings are prefixed with their domain / 发现问题带有领域前缀：
- `[General]` / `[通用]` — Universal checks / 通用检查
- `[Specialist:Java]` / `[专项:Java]` — Java-specific / Java专项
- `[Specialist:Frontend]` / `[专项:前端]` — Frontend-specific / 前端专项
- `[Specialist:Security]` / `[专项:安全]` — Security-specific / 安全专项

---

## Review Categories / 审查类别

### Universal (All Languages) / 通用（所有语言）

| Category / 类别 | Description / 说明 |
|----------------|-------------------|
| **Correctness** / 正确性 | Logic errors, null derefs, race conditions / 逻辑错误、空指针、竞态条件 |
| **Security** / 安全性 | Injection, hardcoded secrets, input validation / 注入攻击、硬编码密钥、输入验证 |
| **Performance** / 性能 | Complexity, memory leaks, unnecessary computation / 复杂度、内存泄漏、冗余计算 |
| **Maintainability** / 可维护性 | Function length > 50 lines, magic numbers / 函数过长、魔法数字 |
| **Style** / 代码风格 | Dead code, unused imports, formatting / 死代码、未使用导入、格式 |

---

## Scheduled Review / 定时审查

**Zero-config command-line timer / 零配置命令行定时器**

### Quick Start / 快速开始

```bash
cd /path/to/your-project

# 立即审查当前目录（零配置，开箱即用）
~/.claude/skills/code-review-assistant/scripts/scheduled-review.sh

# 或简写（如果你把脚本加入 PATH）
scheduled-review --now
```

### Common Commands / 常用命令

| Command / 命令 | Description / 说明 |
|---------------|-------------------|
| `scheduled-review --now` | Review immediately / 立即审查 |
| `bash scripts/ai-code-review.sh . "" standard --summary` | Summary mode / 摘要模式，只输出关键结论和统计 |
| `scheduled-review --install --time 09:00` | Daily at 9AM / 每天上午9点 |
| `scheduled-review --install --days 1-5 --time 09:00,18:00` | Twice on weekdays / 工作日早晚各一次 |
| `scheduled-review --install --days all --time 09:00` | Every day / 每天 |
| `scheduled-review --status` | Check installed jobs / 查看已安装任务 |
| `scheduled-review --uninstall` | Remove all jobs / 卸载所有任务 |
| `scheduled-review --path /other/project --now` | Review other repo / 审查其他仓库 |
| `scheduled-review --now --scan-secrets --scan-deps` | Full security scan / 全面安全扫描 |
| `scheduled-review --now --impact` | Impact analysis / 变更影响分析 |
| `scheduled-review --now --context` | PR context + review / PR上下文审查 |

### One-Line Install / 一行命令安装

```bash
# 工作日每天上午9点自动审查
scheduled-review --install --time 09:00 --days 1-5

# 审查深度模式: quick | standard | deep
scheduled-review --install --time 09:00 --depth deep
```

### What It Does / 脚本功能

The script automatically / 脚本自动：
- Detects changed files since last review / 检测上次审查以来的变更文件
- Counts added/deleted lines / 统计增删行数
- Shows commit history / 显示提交记录
- Generates a ready-to-paste Claude prompt / 生成可直接粘贴给 Claude 的提示语
- Tags the review checkpoint / 标记审查检查点

### Enhanced Review Features / 增强审查功能

```bash
# 全面安全扫描（密钥 + 依赖漏洞）
scheduled-review --now --scan-secrets --scan-deps

# 变更影响分析（模块、API、数据库、风险评级）
scheduled-review --now --impact

# PR 上下文读取（提交信息 + 变更统计 + 影响范围）
scheduled-review --now --context

# 全套审查（安全 + 依赖 + 影响 + 上下文）
scheduled-review --now --scan-secrets --scan-deps --impact --context

# 代码复杂度 + 规范检查 + Reviewer推荐
scheduled-review --now --complexity --lint --commit-lint --reviewer

# 全套审查 + 导出报告
scheduled-review --now --scan-secrets --scan-deps --impact --complexity --lint --export markdown

# 安全 + 隐私 + 依赖 + 并发 全面扫描
scheduled-review --now --scan-secrets --pii --scan-deps --concurrency

# 上线前检查 (数据库 + API + Bundle + i18n + 许可证)
scheduled-review --now --db-migration --api-contract --bundle-size --i18n --license --codeowners

# 发版前全套检查 (覆盖率 + 性能 + Changelog + Feature Flag 清理)
scheduled-review --now --test-coverage --perf --changelog --feature-flag

# 命名规范检查 (变量/函数/文件/目录)
scheduled-review --now --naming

# 严重度评分 + 质量门禁（CI 阻断用）
bash scripts/severity-gate.sh . high

# 跨文件影响分析（接口变更、调用链追踪）
bash scripts/cross-file-context.sh . HEAD~1

# 自动修复简单问题（预览模式）
bash scripts/auto-fix.sh .
# 应用修复
bash scripts/auto-fix.sh . --apply

# 自动生成 PR 描述并更新到当前 PR
bash scripts/pr-describe.sh .

# 发布审查结果为 PR 内联评论
bash scripts/scan-secrets.sh . | bash scripts/pr-comment.sh . 42

# 按严重级别过滤审查（只执行高优先级检查）
scheduled-review --now --severity critical   # 仅5星: 安全/隐私/并发/错误/泄露 (6项)
scheduled-review --now --severity high       # 4星+5星: 包含规范/架构/命名 (12项)
scheduled-review --now --severity medium     # 3星+4星+5星: 包含测试/迁移/API (19项)
# 默认不指定 --severity 则执行所有已启用的检查（等同于 --severity all）
```

| Priority / 优先级 | Feature / 功能 | Script / 脚本 | Description / 说明 |
|:-----------------:|---------------|--------------|-------------------|
| ★★★★★ | **Secret Scan** / 密钥扫描 | `scripts/scan-secrets.sh` | Detect hardcoded keys, tokens, passwords / 检测硬编码密钥、Token、密码 |
| ★★★★★ | **Dependency Scan** / 依赖扫描 | `scripts/scan-deps.sh` | Check npm/pip/maven/go/cargo for CVEs / 检查各语言依赖漏洞 |
| ★★★★★ | **PII Scan** / 隐私扫描 | `scripts/pii-scan.sh` | Phone/ID/bank card leak detection / 手机号/身份证/银行卡泄露检测 |
| ★★★★★ | **Concurrency** / 并发安全 | `scripts/concurrency-check.sh` | Deadlock/race/goroutine leak scan / 死锁/竞态/协程泄露检测 |
| ★★★★★ | **Error Handling** / 错误处理 | `scripts/error-handling.sh` | Empty catch / missing throws / async handling / 空catch/异常吞没/异步处理 |
| ★★★★★ | **Resource Leak** / 资源泄露 | `scripts/resource-leak.sh` | Unclosed files / connections / timers / listeners / 未关闭文件/连接/定时器 |
| ★★★★☆ | **Severity Gate** / 严重度门禁 | `scripts/severity-gate.sh` | Weighted scoring + configurable quality gates / 加权评分+可配置质量门禁 |
| ★★★★☆ | **Auto-Fix** / 自动修复 | `scripts/auto-fix.sh` | Trailing whitespace, format, unused import fixes / 行尾空格/格式化/未使用import修复 |
| ★★★★☆ | **Lint Check** / 规范检查 | `scripts/lint-check.sh` | ESLint/Prettier/Black/gofmt auto-check / 多语言代码规范自动检查 |
| ★★★★☆ | **Code Smell** / 代码异味 | `scripts/code-smell.sh` | God class / long function / deep nesting / 上帝类/长函数/深嵌套 |
| ★★★★☆ | **Type Safety** / 类型安全 | `scripts/type-safety.sh` | `any` abuse / missing guards / `@ts-ignore` / any滥用/类型收窄缺失 |
| ★★★★☆ | **Architecture** / 架构合规 | `scripts/architecture-check.sh` | Layer violations / circular deps / wrong imports / 分层违规/循环依赖 |
| ★★★★☆ | **Naming Convention** / 命名规范 | `scripts/naming-convention.sh` | Variable/function/file/dir naming checks / 变量/函数/文件/目录命名规范检查 |
| ★★★★☆ | **Config Drift** / 配置漂移 | `scripts/config-drift.sh` | Hardcoded secrets / missing keys / wrong env / 硬编码密钥/缺失配置/环境错误 |
| ★★★☆☆ | **Cross-File Context** / 跨文件分析 | `scripts/cross-file-context.sh` | Callers/callees + imports + risk assessment / 调用链+导入依赖+风险评估 |
| ★★★☆☆ | **PR Describe** / PR描述生成 | `scripts/pr-describe.sh` | Auto-generate PR title+description from git diff / 从diff自动生成PR标题和描述 |
| ★★★☆☆ | **Test Quality** / 测试质量 | `scripts/test-quality.sh` | Flaky tests / missing boundaries / no teardown / 脆弱测试/边界缺失/无清理 |
| ★★★☆☆ | **Test Coverage** / 测试覆盖 | `scripts/test-coverage.sh` | Coverage analysis for new code / 新增代码的测试覆盖分析 |
| ★★★☆☆ | **Impact Analysis** / 影响分析 | `scripts/impact-analysis.sh` | Module/API/DB impact + risk rating / 模块/API/数据库影响 + 风险评级 |
| ★★★☆☆ | **Reuse** / 代码复用性 | `scripts/reuse-check.sh` | Duplicate code + magic values + similar functions / 重复代码/魔法值/相似函数 |
| ★★★☆☆ | **DB Migration** / 数据库迁移 | `scripts/db-migration.sh` | Migration safety: locks, drops, transactions / 迁移安全:锁表/删除/事务 |
| ★★★☆☆ | **API Contract** / API契约 | `scripts/api-contract.sh` | OpenAPI/Protobuf breaking changes / API契约变更与兼容性检测 |
| ★★★☆☆ | **Supply Chain** / 供应链 | `scripts/supply-chain.sh` | Typosquatting / malicious packages / 拼写劫持/恶意包 |
| ★★☆☆☆ | **PR Comment** / PR内联评论 | `scripts/pr-comment.sh` | Post review findings as inline PR comments / 将审查结果发布为PR行级评论 |
| ★★☆☆☆ | **GitHub Actions** / CI集成 | `.github/workflows/code-review.yml` | Automated PR review pipeline with gates / 自动化PR审查流水线 |
| ★★☆☆☆ | **Performance** / 性能基准 | `scripts/perf-benchmark.sh` | Benchmark regression detection / 性能基准测试回归分析 |
| ★★☆☆☆ | **Bundle Size** / 包体积 | `scripts/bundle-size.sh` | Dependency size + build artifact analysis / 依赖体积与构建产物分析 |
| ★★☆☆☆ | **Doc Quality** / 文档质量 | `scripts/doc-quality.sh` | Missing JSDoc / stale comments / TODO tracking / 缺文档/过时注释/TODO追踪 |
| ★★☆☆☆ | **Commit Lint** / 提交规范 | `scripts/commit-lint.sh` | Conventional Commits format check / 提交信息格式检查 |
| ★★☆☆☆ | **CODEOWNERS** / 代码所有者 | `scripts/codeowners-check.sh` | Owner matching for critical paths / 关键路径的代码所有者匹配 |
| ★★☆☆☆ | **License Check** / 许可证 | `scripts/license-check.sh` | GPL/AGPL risk detection / 许可证合规与传染性风险检测 |
| ★☆☆☆☆ | **i18n Check** / 国际化 | `scripts/i18n-check.sh` | Hardcoded text + missing keys / 硬编码文案与缺失i18n key |
| ★☆☆☆☆ | **A11y** / 无障碍 | `scripts/a11y-check.sh` | Missing alt / no keyboard / low contrast / 缺alt/无键盘/对比度 |
| ★☆☆☆☆ | **Feature Flag** / 功能开关 | `scripts/feature-flag.sh` | Stale flag cleanup detection / 过期功能开关代码清理 |
| ★☆☆☆☆ | **Changelog** / 变更日志 | `scripts/changelog-gen.sh` | Auto-generate from Conventional Commits / 基于提交规范自动生成 |
| ★☆☆☆☆ | **Reviewer** / Reviewer推荐 | `scripts/reviewer-assign.sh` | Auto-assign by code familiarity / 按代码熟悉度自动推荐 |
| ★☆☆☆☆ | **Export Report** / 报告导出 | `scripts/export-report.sh` | Markdown/HTML report export / Markdown/HTML报告导出 |
| ★☆☆☆☆ | **PR Context** / PR上下文 | `scripts/pr-context.sh` | Commit context + change stats + linked issues / 提交上下文 + 变更统计 + 关联Issue |
| ★☆☆☆☆ | **History Track** / 历史追踪 | `scripts/review-history.sh` | Save & compare review results / 保存并对比审查结果 |
| ★☆☆☆☆ | **Complexity** / 复杂度 | `scripts/complexity-analysis.sh` | Cyclomatic complexity + function length + duplication / 圈复杂度 + 函数长度 + 重复检测 |

### Notification Channels / 通知推送

Send review results to IM or email / 将审查结果推送到即时通讯或邮件：

#### Supported Channels / 支持的渠道

| Channel / 渠道 | Setup / 配置方式 | Required / 必填凭证 | Command / 命令 |
|---------------|-----------------|-------------------|---------------|
| **Feishu / 飞书** | 1. 飞书群 → 设置 → 添加机器人 → 自定义机器人<br>2. 复制 Webhook URL（含 `hook-xxxx` token）<br>3. 安全设置可选：IP 白名单 / 关键字 | `FEISHU_WEBHOOK` | `--notify feishu --webhook "URL"` |
| **DingTalk / 钉钉** | 1. 钉钉群 → 群设置 → 智能群助手 → 添加机器人<br>2. 选择「自定义」机器人，复制 Webhook URL<br>3. 安全设置：加签 / 关键字 / IP 白名单 | `DINGTALK_WEBHOOK` | `--notify dingtalk --webhook "URL"` |
| **WeCom / 企业微信** | 1. 企业微信 → 应用管理 → 创建应用 或 群机器人<br>2. 群机器人：群设置 → 添加群机器人 → 复制 Webhook URL<br>3. 应用消息：获取 AgentID + Secret + 企业ID | `WECOM_WEBHOOK` | `--notify wecom --webhook "URL"` |
| **Slack** | 1. Slack App → Incoming Webhooks → Add to Slack<br>2. 选择目标频道，复制 Webhook URL<br>3. 或使用 Slack API Token（需 `chat:write` 权限） | `SLACK_WEBHOOK` | `--notify slack --webhook "URL"` |
| **Telegram** | 1. 找 @BotFather → /newbot → 获取 Bot Token<br>2. 给机器人发一条消息获取 Chat ID<br>3. 或用 @userinfobot 获取用户/频道 ID | `TELEGRAM_BOT_TOKEN`<br>`TELEGRAM_CHAT_ID` | `--notify telegram` |
| **LINE** | 1. 访问 [notify-bot.line.me](https://notify-bot.line.me/)<br>2. 登录 → 我的页面 → 发行权杖（Token）<br>3. 选择要接收通知的聊天群组 | `LINE_NOTIFY_TOKEN` | `--notify line` |
| **WhatsApp** | 1. 注册 [Twilio](https://www.twilio.com/) 账号<br>2. 获取 Account SID + Auth Token<br>3. 购买 Twilio 电话号码，开启 WhatsApp Sandbox | `TWILIO_SID`<br>`TWILIO_TOKEN`<br>`WHATSAPP_FROM` | `--notify whatsapp --to "+86..."` |
| **Email / 邮件** | 1. 准备 SMTP 服务器（如 Gmail/163/自建）<br>2. 获取 SMTP 地址、端口、用户名、密码/授权码<br>3. Gmail 需开启「两步验证」并生成应用专用密码 | `SMTP_HOST`<br>`SMTP_PORT`<br>`SMTP_USER`<br>`SMTP_PASS` | `--notify email --to "user@example.com"` |

#### Quick Setup / 快速配置

**方式一：.env 文件（推荐）**

```bash
# 1. 复制模板并编辑
cp .env.example .env
vim .env
```

`.env` 完整配置示例：

```bash
# ========== 飞书 / Feishu ==========
# 飞书群机器人 Webhook URL
# 获取方式：飞书群 → 设置 → 添加机器人 → 自定义机器人 → 复制 Webhook URL
FEISHU_WEBHOOK="https://open.feishu.cn/open-apis/bot/v2/hook/YOUR-FEISHU-TOKEN"

# ========== 钉钉 / DingTalk ==========
# 钉钉群机器人 Webhook URL
# 获取方式：钉钉群 → 群设置 → 智能群助手 → 添加机器人 → 自定义 → 复制 Webhook
DINGTALK_WEBHOOK="https://oapi.dingtalk.com/robot/send?access_token=YOUR-DINGTALK-TOKEN"

# ========== 企业微信 / WeCom ==========
# 企业微信群机器人 Webhook URL
# 获取方式：群设置 → 添加群机器人 → 复制 Webhook Key
WECOM_WEBHOOK="https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=YOUR-WECOM-KEY"

# ========== Slack ==========
# Slack Incoming Webhook URL
# 获取方式：Slack App → Incoming Webhooks → Add to Slack → 复制 URL
SLACK_WEBHOOK="https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"

# ========== Telegram ==========
# 1. 找 @BotFather 发送 /newbot 创建机器人，获取 Token
# 2. 给机器人发一条消息，访问 https://api.telegram.org/bot<Token>/getUpdates 获取 chat_id
TELEGRAM_BOT_TOKEN="YOUR-TELEGRAM-BOT-TOKEN"
TELEGRAM_CHAT_ID="YOUR-CHAT-ID"

# ========== LINE Notify ==========
# 访问 https://notify-bot.line.me/ → 登录 → 发行权杖
LINE_NOTIFY_TOKEN="YOUR-LINE-NOTIFY-TOKEN"

# ========== WhatsApp (Twilio) ==========
# 注册 https://www.twilio.com/ → Console → 获取 Account SID 和 Auth Token
TWILIO_SID="YOUR-TWILIO-SID"
TWILIO_TOKEN="YOUR-TWILIO-TOKEN"
# Twilio 购买的电话号码（含国家码）
WHATSAPP_FROM="YOUR-TWILIO-PHONE-NUMBER"

# ========== 邮件 / Email SMTP ==========
# SMTP 服务器地址
SMTP_HOST="smtp.gmail.com"        # Gmail 示例
# SMTP_HOST="smtp.163.com"        # 163 邮箱示例
# SMTP_HOST="smtp.qq.com"         # QQ 邮箱示例
# SMTP_HOST="smtp.exmail.qq.com"  # 企业微信邮箱示例

# SMTP 端口（SSL: 465, TLS: 587）
SMTP_PORT="587"

# SMTP 用户名（通常是邮箱地址）
SMTP_USER="your-email@gmail.com"

# SMTP 密码 / 授权码
# Gmail: 开启两步验证 → 生成应用专用密码（不是登录密码）
# 163/QQ: 邮箱设置 → 开启 SMTP → 获取授权码
SMTP_PASS="your-app-password-or-auth-code"
```

**方式二：命令行直接传入**

```bash
# 飞书
FEISHU_WEBHOOK="https://open.feishu.cn/..." scheduled-review --now --notify feishu

# 钉钉
DINGTALK_WEBHOOK="https://oapi.dingtalk.com/..." scheduled-review --now --notify dingtalk

# 企业微信
WECOM_WEBHOOK="https://qyapi.weixin.qq.com/..." scheduled-review --now --notify wecom

# 邮件
SMTP_HOST="smtp.gmail.com" SMTP_PORT="587" SMTP_USER="you@gmail.com" SMTP_PASS="xxx" \
  scheduled-review --now --notify email --to "team@example.com"
```

**方式三：命令行参数（不需要 .env）**

```bash
# Webhook 类渠道
scheduled-review --now --notify feishu --webhook "https://open.feishu.cn/..."
scheduled-review --now --notify slack --webhook "https://hooks.slack.com/..."

# 邮件
scheduled-review --now --notify email --to "team@example.com"

# WhatsApp
scheduled-review --now --notify whatsapp --to "+86YOURPHONE"
```

#### Auto-notify with scheduled reviews / 定时审查自动推送

```bash
# Daily review + Feishu notification / 每日审查 + 飞书推送
scheduled-review --install --time 09:00 --notify feishu --webhook "https://open.feishu.cn/..."

# Workdays review + Email / 工作日审查 + 邮件
scheduled-review --install --days 1-5 --time 09:00 --notify email --to "team@example.com"
```

### Alternative: Claude Code Native / Claude Code 原生方式

```
# Simplest: auto-review every day / 最简单：每天自动审查
/loop 1d /code-review-assistant

# Or with specific directory / 或指定目录
/loop 1d review the code changes in src/ since last review
```

---

## Extending / 扩展

To add a new language / 添加新语言：

1. Create `rules/<language>.md` with checklists / 创建规则文件
2. Add detection pattern to `SKILL.md` / 在 SKILL.md 添加检测模式
3. Update this README's Supported Languages table / 更新README支持语言表
4. Submit PR or use locally / 提交PR或本地使用

---

## Custom Rules / 自定义规则

在项目根目录创建 `.review-rules.yml`，审查时自动与 Skill 默认规则合并。

### Quick Start

```bash
# 复制模板到项目根目录
cp /path/to/code-review-assistant/.review-rules.yml.template .review-rules.yml
```

编辑文件，取消注释并修改需要的规则：

```yaml
version: "1.0"

custom_rules:
  - id: "myproject:no-raw-sql-in-controller"
    category: "Architecture"
    severity: "critical"
    languages: ["java"]
    message: "Controller 禁止包含原始 SQL，必须使用 Repository 层"
    check: "标记 @RestController 中的所有 SQL 字符串"

behavior:
  project_context: |
    本项目是 Spring Boot 微服务，使用 PostgreSQL，所有 API 响应包装为 Result<T>。
  exclude_patterns:
    - "**/generated/**"
```

### 规则 ID 索引

`disable` 列表需要引用规则 ID。所有默认规则都在 `rules/*.md` 中以 `[id: 领域:规则名]` 标记，例如：

```markdown
- [id: frontend:react-hooks-exhaustive-deps] [ ] `useEffect` 依赖数组是否完整？
- [id: java:try-with-resources] [ ] `try-with-resources` 是否用于 `AutoCloseable`？
- [id: security:owasp-a06-cve] [ ] 依赖项是否存在已知 CVE？
```

按领域的规则数量统计：

| 领域 | 规则文件 | 规则数量 |
| ------ | --------- | ---------: |
| AI / ML | `rules/aiml.md` | 35 |
| Big Data | `rules/bigdata.md` | 29 |
| Blockchain | `rules/blockchain.md` | 29 |
| Database | `rules/database.md` | 25 |
| DevOps | `rules/devops.md` | 25 |
| Frontend / Node.js | `rules/frontend.md` | 47 |
| Go | `rules/go.md` | 20 |
| Java | `rules/java.md` | 28 |
| Mobile | `rules/mobile.md` | 39 |
| PHP | `rules/php.md` | 23 |
| Python | `rules/python.md` | 24 |
| Security | `rules/security.md` | 30 |

要禁用某条规则，直接复制其 `[id: ...]` 到 `disable` 列表即可。完整的规则清单请查看对应 `rules/*.md` 文件。

### 可配置项

| 字段 | 说明 | 示例 |
| ------ | --------- | --------- |
| `disable` | 禁用默认规则（按规则 ID） | `["frontend:react-hooks-exhaustive-deps"]` |
| `custom_rules` | 添加项目专属检查 | 见上方示例 |
| `custom_rules[].languages` | 限定规则适用的语言 | `["java", "php"]` |
| `behavior.project_context` | 附加到每次审查的上下文 | 技术栈、约定说明 |
| `behavior.exclude_patterns` | 排除路径（glob） | `["**/*.generated.ts"]` |
| `languages.<lang>` | 语言专属覆盖 | `languages.python.custom_rules` |

### 合并逻辑

1. **发现**：脚本从目标目录向上查找 `.review-rules.yml`
2. **结构化解析**：优先使用 PyYAML，无 PyYAML 时使用内置轻量级解析器
3. **禁用生效**：`disable` 中的规则 ID 在 prompt 中明确列出，AI 跳过
4. **语言检测**：脚本根据变更文件的扩展名推断涉及语言（如 `java`、`typescript`、`python`）
5. **自定义规则过滤**：`custom_rules` 中带有 `languages` 的规则，只有在与检测语言匹配时才会注入
6. **自定义规则追加**：匹配的 `custom_rules` 按 `[ProjectRule:<id>]` 格式注入
7. **语言专属覆盖**：`languages.<lang>` 下定义的 custom_rules 和 behavior 仅在该语言被检测到时注入
8. **行为覆盖**：`project_context` 附加到 Context，`exclude_patterns` 过滤文件，`max_function_lines` 更新阈值

---

## Context Management / 上下文管理

在连续进行多轮深度审查或处理大型 PR 时，Claude Code 的上下文可能会变得非常长，导致响应变慢或关键信息被截断。

建议在这些场景下执行 Claude Code 的 `/compact` 命令：

- 连续运行 3 次以上 `ai-code-review.sh` 深度审查后
- 审查涉及超过 10 个文件或单文件超过 500 行
- 对话中积累了大量审查输出、修复建议和讨论

`/compact` 会压缩并保留关键上下文，让后续审查保持高效。

---

## Roadmap / 路线图

| 阶段 | 方向 | 目标 | 状态 |
| ------ | ------ | ------ | ------ |
| P1 | **端到端集成验证** | 用真实混合语言 PR 验证 `--summary`、`languages` 过滤、`.review-rules.yml` 注入是否真正生效 | ✅ 已完成 |
| P1 | **规则 ID 规范化** | 给 `rules/*.md` 补全正式 `[id: 领域:规则名]` 标记，让 `disable` 可校验、可自动补全 | ✅ 已完成 |
| P2 | **多云/云厂商无关的 CI 模板** | 提供 Dockerfile + entrypoint.sh，以及阿里云效、腾讯云 CODING、Jenkins 等通用接入示例 | 待开始 |
| P2 | **`--fix` 自动应用补丁** | 从“AI 生成 patch 文本”升级为“脚本解析 diff 并可选自动应用” | 待开始 |
| P3 | **审查报告结构化持久化** | 输出 JSON/SARIF 格式报告，保存历史，支持 `--history-compare` | 待开始 |

> 注：GitHub Actions 工作流暂不在路线图中，项目实际运行环境以阿里云、腾讯云等国内云厂商为主。

---

## License / 许可证

MIT
