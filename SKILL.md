---
name: code-review-assistant
description: Automatically review code changes for bugs, style issues, security vulnerabilities, and optimization opportunities. Supports 12+ languages, auto-fix mode, secret scanning, dependency vulnerability checks, impact analysis, and multi-channel notifications (Feishu/DingTalk/WeCom/Slack/Email/Line/WhatsApp/Telegram). Trigger when user asks for code review, PR review, or asks to check/fix code quality.
user-invocable: true
---

# Code Review Assistant

## Purpose
Provide thorough, actionable code reviews for diffs, files, or snippets. Focus on correctness, security, performance, maintainability, and style consistency.

## Instructions

### Language & Domain Detection
Before reviewing, detect the dominant language/tech stack from file extensions and content. Apply the matching专项规则:

| 检测特征 | 加载专项规则 |
|---------|-------------|
| `.java`, `.kt`, Spring annotations | [rules/java.md](rules/java.md) |
| `.js`, `.ts`, `.jsx`, `.tsx`, `.vue` | [rules/frontend.md](rules/frontend.md) |
| Express/Koa/Fastify imports, `package.json` (Node.js server) | [rules/frontend.md](rules/frontend.md) |
| `.sql`, `.prisma`, ORM queries | [rules/database.md](rules/database.md) |
| `.py`, Django/Flask imports | [rules/python.md](rules/python.md) |
| `.go` | [rules/go.md](rules/go.md) |
| `.php`, Laravel/Symfony | [rules/php.md](rules/php.md) |
| `Dockerfile`, `.yaml` (k8s), `.tf` | [rules/devops.md](rules/devops.md) |
| `.swift`, `.m`, iOS 框架 | [rules/mobile.md](rules/mobile.md) |
| `.dart`, Flutter imports | [rules/mobile.md](rules/mobile.md) |
| `.scala`, `.py` (Spark/Pandas), `.sql` (Hive) | [rules/bigdata.md](rules/bigdata.md) |
| `.py` (PyTorch/TF), `.ipynb`, `.h5`, `.onnx` | [rules/aiml.md](rules/aiml.md) |
| `.sol`, `.vy`, Web3 调用 | [rules/blockchain.md](rules/blockchain.md) |
| 涉及加密/认证/授权逻辑 | 额外叠加 [rules/security.md](rules/security.md) |
| 安全审计专项请求 | 深度执行 [rules/security.md](rules/security.md) |

### Project Custom Rules (项目自定义规则)
审查前，从目标目录向上查找 `.review-rules.yml`。脚本会解析该文件并把以下三部分结构化地加入审查提示词：

1. **禁用规则**：`disable` 列表中的规则 ID 会被明确列出，审查时跳过
2. **自定义规则**：`custom_rules` 中的规则按 `[ProjectRule:<id>]` 格式执行
3. **行为覆盖**：`behavior.max_function_lines`、`behavior.project_context`、`behavior.exclude_patterns` 等会覆盖默认值

规则 ID 格式为 `领域:规则名`，例如 `frontend:react-hooks-exhaustive-deps`、`java:try-with-resources`、`security:owasp-a06-cve`。所有默认规则都在 `rules/*.md` 中以 `[id: ...]` 标记，可直接复制到 `disable` 列表中。

AI 只需按提示词中已结构化的规则执行，不需要自行解析或合并 YAML。
For every review, systematically check:

1. **Correctness Bugs**
   - Logic errors, off-by-one errors, null/undefined dereferences
   - Race conditions, async/await misuse
   - Error handling gaps

2. **Security**
   - Injection vulnerabilities (SQL, XSS, command injection)
   - Hardcoded secrets or credentials
   - Unsafe eval() or dynamic code execution
   - Missing input validation

3. **Performance**
   - O(n²) loops that could be O(n)
   - Unnecessary re-renders or recomputations
   - Memory leaks, large object duplication
   - N+1 query problems

4. **Maintainability**
   - Functions over 50 lines (suggest splitting)
   - Magic numbers without constants
   - Inconsistent naming conventions
   - Missing types or type safety gaps

5. **Style & Best Practices**
   - Dead code, unused imports/variables
   - Console.log statements left in production code
   - Inconsistent formatting
   - Missing error messages or logging

### 专项规则加载说明
当检测到特定语言或技术栈时，除了通用检查清单外，还必须执行对应专项规则文件中的全部检查项。将专项发现标记为 `[专项:Java]`、`[专项:前端]`、`[专项:数据库]` 等前缀。

### Output Format
Structure your review as:

```
## Summary
Brief overview of the change and overall assessment (Approve / Request Changes / Needs Discussion)

## Critical Issues 🔴
Must fix before merge.
- [File:Line] Description + suggested fix

## Warnings 🟡
Should address, but not blockers.
- [File:Line] Description + suggestion

## Suggestions 💡
Nice-to-have improvements.
- [File:Line] Description

## Positive Notes ✅
What was done well (don't skip this).
```

### Rules
- Always cite specific file and line numbers using `[filename.ts:42]` format
- Provide concrete code suggestions, not vague complaints
- If no issues found, explicitly say "No issues found" and explain what was done well
- For large diffs (>200 lines), focus on the most impactful issues first
- Never suggest changes that break existing functionality without clear justification
- Be direct but constructive - no passive-aggressive tone

### Auto-Fix Mode (--fix)
When user requests fixes or passes `--fix` flag, generate **ready-to-apply patches**:

1. **For each issue found, provide:**
   - The exact code block to replace (with `// before` and `// after` comments)
   - Or a `diff` format patch
   - Or the complete corrected function/file section

2. **Fix priority order:**
   - Critical security issues first (injection, secrets, XSS)
   - Then correctness bugs (null checks, race conditions)
   - Then performance issues
   - Finally style/maintainability

3. **Format:**
   ```
   ## Auto-Fix Patch for [filename.ts:42]
   
   ```diff
   - const password = 'hardcoded123';
   + const password = process.env.DB_PASSWORD;
   ```
   
   Or:
   
   ```typescript
   // Before (line 42-45):
   function fetchData() {
     return axios.get(url);  // missing error handling
   }
   
   // After:
   async function fetchData() {
     try {
       return await axios.get(url);
     } catch (error) {
       console.error('Fetch failed:', error);
       throw new AppError('FETCH_FAILED', error);
     }
   }
   ```

### PR Context Reading
When reviewing a PR (not just a snippet), try to gather context:

1. **From PR description**: What is the intent? What problem does it solve?
2. **From linked issues**: What requirements/constraints exist?
3. **From previous reviewer comments**: What was already discussed?
4. **From commit messages**: What is the logical flow of changes?

If context is available, prepend the review with:
```
## Context
- **Intent**: (what the PR aims to do)
- **Scope**: (files/modules affected)
- **Risk Level**: (Low/Medium/High based on changed critical paths)
```

Then align your review focus with the PR's stated intent.

### Security Secret Scanning (Pre-Review)
Before any code review, always scan for:
- Hardcoded passwords, API keys, tokens, secrets
- Private keys (RSA, SSH, PEM)
- Database connection strings with credentials
- OAuth client secrets
- AWS/Azure/GCP access keys

If secrets found, immediately flag as **CRITICAL** and request rotation + `.gitignore` + secret management tool.

### Dependency Vulnerability Check
When package manager files changed (`package.json`, `pom.xml`, `requirements.txt`, `go.mod`, `Cargo.toml`):
- Note any new dependencies added
- Flag known vulnerable versions
- Suggest `npm audit`, `snyk`, `dependabot`, or `osv-scanner` if appropriate

### Scheduled Review (定时审查)
支持通过配置文件设置定时自动审查:

1. **配置文件**: [scheduled-review.yml](scheduled-review.yml) — 设置时间、目标仓库、审查深度
2. **执行脚本**: [scripts/scheduled-review.sh](scripts/scheduled-review.sh) — 计算变更范围并输出审查上下文
3. **定时方式**:
   - **crontab** (推荐): `crontab -e` 添加 `0 9 * * 1-5 /path/to/scripts/scheduled-review.sh`
   - **Claude Code /loop**: `/loop 1d /code-review-assistant`
   - **CI/CD**: GitHub Actions / GitLab CI 中配置定时触发

当执行定时审查时，脚本会:
- 检查配置的执行时间和周期
- 获取自上次审查以来的 git 变更
- 生成包含变更文件列表和提交记录的审查上下文
- 输出提示语供用户粘贴到 Claude Code 执行 `/code-review-assistant`

## Examples

### Example 1: React Component Review
```tsx
// User submits this code:
function UserList({ users }) {
  const [filter, setFilter] = useState('');
  
  const filtered = users.filter(u => u.name.includes(filter));
  
  return (
    <div>
      <input onChange={e => setFilter(e.target.value)} />
      {filtered.map(u => <div>{u.name}</div>)}
    </div>
  );
}
```

Review:
- [UserList.tsx:1] Missing TypeScript types for props - add interface
- [UserList.tsx:5] No `key` prop in list rendering - add unique key
- [UserList.tsx:3] `useMemo` could optimize filtering for large lists
- [UserList.tsx:8] Missing `value` prop on controlled input
```

## Scripts Toolbox / 脚本工具箱

The following helper scripts are available in `scripts/`:

| Script / 脚本 | Purpose / 用途 | Usage / 用法 |
|--------------|---------------|-------------|
| `scheduled-review.sh` | Scheduled review with cron / 定时审查 | `--install --time 09:00` |
| `scan-secrets.sh` | Scan for hardcoded secrets / 扫描硬编码密钥 | `[dir] [all|critical|high]` |
| `scan-deps.sh` | Dependency vulnerability scan / 依赖漏洞扫描 | `[dir]` |
| `impact-analysis.sh` | Change impact + risk rating / 变更影响分析 | `[dir] [base_ref]` |
| `pr-context.sh` | PR context reader / PR 上下文读取 | `[dir]` |
| `review-history.sh` | Review history tracking / 审查历史追踪 | `[dir] [list|show|diff|stats]` |
| `complexity-analysis.sh` | Code complexity + duplication / 代码复杂度 + 重复检测 | `[dir] [quick|standard|deep]` |
| `lint-check.sh` | Code style auto-check / 代码规范自动检查 | `[dir]` |
| `commit-lint.sh` | Commit message lint / 提交信息规范检查 | `[dir] [base_ref]` |
| `reviewer-assign.sh` | Auto reviewer assignment / 自动推荐 Reviewer | `[dir]` |
| `export-report.sh` | Report export / 报告导出 | `[dir] [markdown|html] [output]` |
| `test-coverage.sh` | Test coverage analysis / 测试覆盖率分析 | `[dir] [threshold]` |
| `api-contract.sh` | API contract breaking changes / API 契约变更检测 | `[dir]` |
| `bundle-size.sh` | Bundle size analysis / 构建产物体积分析 | `[dir] [threshold_mb]` |
| `db-migration.sh` | DB migration safety / 数据库迁移安全审查 | `[dir]` |
| `i18n-check.sh` | i18n completeness / 国际化完整性检查 | `[dir]` |
| `pii-scan.sh` | PII data leak scan / 敏感个人信息扫描 | `[dir] [severity]` |
| `feature-flag.sh` | Feature flag cleanup / 功能开关清理检测 | `[dir]` |
| `codeowners-check.sh` | CODEOWNERS matching / 代码所有者检查 | `[dir]` |
| `license-check.sh` | License compliance / 许可证合规检查 | `[dir]` |
| `perf-benchmark.sh` | Performance regression / 性能基准回归分析 | `[dir] [regression_threshold]` |
| `changelog-gen.sh` | Changelog generation / 变更日志自动生成 | `[dir] [since_tag]` |
| `concurrency-check.sh` | Concurrency safety / 并发安全深度检测 | `[dir]` |
| `reuse-check.sh` | Code reuse / 代码复用性检查 | `[dir] [min_lines]` |
| `error-handling.sh` | Error handling / 错误处理完整性 | `[dir]` |
| `resource-leak.sh` | Resource leak / 资源泄露扫描 | `[dir]` |
| `type-safety.sh` | Type safety / 类型安全深度检查 | `[dir] [any_threshold]` |
| `architecture-check.sh` | Architecture / 架构合规检查 | `[dir]` |
| `test-quality.sh` | Test quality / 测试质量检查 | `[dir]` |
| `code-smell.sh` | Code smell / 代码异味检测 | `[dir]` |
| `doc-quality.sh` | Doc quality / 注释文档质量 | `[dir]` |
| `a11y-check.sh` | Accessibility / 无障碍检查 | `[dir]` |
| `config-drift.sh` | Config drift / 配置漂移检测 | `[dir]` |
| `supply-chain.sh` | Supply chain / 供应链安全 | `[dir]` |
| `naming-convention.sh` | Naming convention / 命名规范检查 | `[dir]` |
| `severity-gate.sh` | Severity scoring + quality gate / 严重度评分+质量门禁 | `[dir] [critical|high|medium|low]` |
| `cross-file-context.sh` | Cross-file impact analysis / 跨文件上下文分析 | `[dir] [base_ref]` |
| `pr-describe.sh` | PR description auto-generation / PR描述自动生成 | `[dir] [pr_number]` |
| `pr-comment.sh` | PR inline comments / PR内联评论 | `[dir] [pr_number] [review_file]` |
| `auto-fix.sh` | Auto-fix mode / 自动修复模式 | `[dir] [--apply]` |

### GitHub Actions / CI 集成

| Workflow | Purpose / 用途 |
|----------|---------------|
| `.github/workflows/code-review.yml` | Automated PR review with severity gates, auto-fix, and inline comments / 自动PR审查，含质量门禁、自动修复、内联评论 |

### Notification Scripts / 通知脚本 (in `scripts/notifiers/`)

| Script / 脚本 | Channel / 渠道 |
|--------------|---------------|
| `feishu.sh` | 飞书 Lark |
| `dingtalk.sh` | 钉钉 |
| `wecom.sh` | 企业微信 |
| `slack.sh` | Slack |
| `telegram.sh` | Telegram |
| `line.sh` | LINE Notify |
| `whatsapp.sh` | WhatsApp (Twilio) |
| `email.sh` | Email SMTP |
