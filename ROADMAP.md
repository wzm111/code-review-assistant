# Roadmap / 路线图

本文档记录 `code-review-assistant` 的阶段性规划和当前进度。

## 当前版本

**v1.0.0** — 见根目录 [`VERSION`](../VERSION) 文件。

## 规划概览

| 阶段 | 方向 | 目标 | 状态 | 对应 PR / Commit |
|------|------|------|------|------------------|
| P1 | **端到端集成验证** | 用真实混合语言 PR 验证 `--summary`、`languages` 过滤、`.review-rules.yml` 注入是否真正生效 | ✅ 已完成 | `96dc2cc` |
| P1 | **规则 ID 规范化** | 给 `rules/*.md` 补全正式 `[id: 领域:规则名]` 标记，让 `disable` 可校验、可自动补全 | ✅ 已完成 | 已存在于 `rules/*.md` |
| P2 | **多云/云厂商无关的 CI 模板** | 提供 `Dockerfile` + `docker-entrypoint.sh`，以及阿里云效、腾讯云 CODING、Jenkins 等通用接入示例 | ✅ 已完成 | `1243e3b` |
| P2 | **`--fix` 自动应用补丁** | 从“AI 生成 patch 文本”升级为“脚本解析 diff 并可选自动应用” | 待开始 | — |
| P3 | **审查报告结构化持久化** | 输出 JSON/SARIF 格式报告，保存历史，支持 `--history-compare` | 待开始 | — |

> 注：GitHub Actions 工作流暂不在路线图中，项目实际运行环境以阿里云、腾讯云等国内云厂商为主。

## 已完成

### P1 端到端集成验证

验证范围：
- [x] `.review-rules.yml` 的 `disable` 列表正确注入 prompt
- [x] `custom_rules` 的 `languages` 字段按检测语言过滤
- [x] `languages.<lang>` 覆盖只在对应语言检测到时注入
- [x] `--summary` 模式正确覆盖 prompt 输出要求
- [x] `exclude_patterns` 正确过滤匹配文件

修复的问题：
- `detect_review_languages()` 函数调用位置在函数定义之前，导致语言检测失效（`96dc2cc`）。

### P1 规则 ID 规范化

- [x] 12 个 `rules/*.md` 文件全部使用 `[id: 领域:规则名]` 格式
- [x] 所有规则 ID 领域前缀与文件一致
- [x] 无重复 ID
- [x] README 已添加「规则 ID 索引」说明

### P2 多云/云厂商无关的 CI 模板

新增文件：
- [x] [`Dockerfile`](../Dockerfile) — 基于 alpine 的通用审查镜像
- [x] [`docker-entrypoint.sh`](../docker-entrypoint.sh) — 统一入口脚本，支持 `SEVERITY` / `SCAN_SECRET` / `SCAN_DEPS` / `SCAN_QUALITY`
- [x] [`examples/docker-compose.yml`](../examples/docker-compose.yml) — 本地测试
- [x] [`examples/aliyun-flow-docker.yml`](../examples/aliyun-flow-docker.yml) — 阿里云效 Docker 模板
- [x] [`examples/tencent-coding-docker.yml`](../examples/tencent-coding-docker.yml) — 腾讯云 CODING Docker 模板
- [x] [`examples/Jenkinsfile-docker`](../examples/Jenkinsfile-docker) — Jenkins Docker agent 模板
- [x] [`docs/platform-adapters.md`](../docs/platform-adapters.md) — 文档已更新 Docker-first 章节

## 待开始

### P2 `--fix` 自动应用补丁

目标：让 `--fix` 模式真正修改文件，而不仅仅是生成 patch 文本。

关键任务：
- 定义 AI 输出 patch 的统一格式（unified diff 或结构化 JSON）
- 在 `scripts/ai-code-review.sh` 或新增 `scripts/apply-fix.sh` 中解析 patch
- 提供 `--dry-run` 预览模式
- 提供 `--apply` 确认应用模式
- 处理冲突和回滚机制

### P3 审查报告结构化持久化

目标：让审查结果可被机器读取、存档和对比。

关键任务：
- 定义 JSON/SARIF 输出格式
- 在 `scripts/ai-code-review.sh` 中支持 `--output-format json|sarif`
- 实现 `--save-report` 保存历史报告
- 实现 `--history-compare` 对比两次审查结果的变化
- 与 `scripts/review-history.sh` 打通

## 如何提议新方向

如果你希望新增路线：

1. 在 ROADMAP.md 中按 `P?` 阶段新增一行
2. 简要描述目标、关键任务和预期收益
3. 提交 PR 或在 Issue 中讨论

## 变更记录

| 日期 | 变更 |
|------|------|
| 2026-06-18 | 建立 `VERSION` 和 `docs/release-process.md`，创建独立 `ROADMAP.md` |
| 2026-06-18 | P2 多云 CI 模板完成 |
| 2026-06-18 | P1 端到端集成验证完成，修复语言检测函数调用顺序 |
| 2026-06-18 | P1 规则 ID 规范化完成 |
