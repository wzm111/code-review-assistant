# Release Process / 版本发布流程

本文档定义 `code-review-assistant` 的版本号管理和发布规范。

## 版本号文件

项目版本号统一由根目录 [`VERSION`](../VERSION) 文件管理：

```text
1.0.0
```

子模块版本号需与根版本保持一致：

- [`mcp/package.json`](../mcp/package.json) → `version`
- [`dashboard/package.json`](../dashboard/package.json) → `version`

## 版本号规则

遵循 [Semantic Versioning 2.0.0](https://semver.org/lang/zh-CN/)：

| 版本位 | 变更场景 | 示例 |
| ------ | -------- | ---- |
| **MAJOR** | 不兼容的 API / 接口 / 命令变更 | `1.x.x` → `2.0.0` |
| **MINOR** | 新增功能，向下兼容 | `1.0.x` → `1.1.0` |
| **PATCH** | Bug 修复、文档改进、性能优化 | `1.0.0` → `1.0.1` |

## 发布步骤

每次完成一个发布单元（feature 开发完毕、测试通过、文档更新），按以下顺序执行：

### 1. 确认当前版本

```bash
cat VERSION
```

### 2. 更新版本号

编辑以下文件，保持版本一致：

```bash
# 根版本
vim VERSION

# 子模块
vim mcp/package.json
vim dashboard/package.json
```

### 3. 运行测试

```bash
# Python 解析器测试
cd tests
python3 -m unittest test_parse_review_rules -v

# Bash 脚本语法检查
bash -n scripts/ai-code-review.sh
bash -n scripts/scheduled-review.sh
bash -n scripts/scan-secrets.sh
```

### 4. 更新文档

- [`README.md`](../README.md) — 顶部版本号徽章、Changelog 或功能列表
- [`SKILL.md`](../SKILL.md) — 如有新增 skill 行为或参数，同步更新
- [`ROADMAP.md`](../ROADMAP.md) — 勾选/移动已完成的阶段

### 5. 提交并推送

```bash
git add VERSION mcp/package.json dashboard/package.json README.md SKILL.md ROADMAP.md
git commit -m "release: vX.Y.Z - <一句话描述核心变更>"
git push origin main
```

### 6. 创建记忆文件（推荐）

在会话记忆目录创建 `code-review-assistant-vX.Y.Z.md`，记录本次发布核心内容，并更新 `MEMORY.md` 索引。

## 注意事项

1. **版本号必须一致**：根 `VERSION` 与所有子模块 `package.json` 的 `version` 字段必须相同。
2. **测试优先**：任何改动在发布前必须通过单元测试和关键脚本语法检查。
3. **文档同步**：新增功能必须同步更新 `README.md`、`SKILL.md` 和 `ROADMAP.md`。
4. **Git 提交规范**：使用 `release: vX.Y.Z - <描述>` 作为发布提交信息。

## 历史版本

| 版本 | 日期 | 核心变更 |
|------|------|----------|
| 1.0.0 | 2026-06-18 | 建立版本号规范、Docker 多云 CI 模板、规则 ID 索引 |
