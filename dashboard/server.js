#!/usr/bin/env node
/**
 * Code Review Assistant Dashboard Server (Node.js)
 * =================================================
 * 零外部依赖，仅需 Node.js (≥14)。
 *
 * 使用方式:
 *     node server.js              # 默认端口 8080
 *     node server.js --port 9000  # 指定端口
 *     node server.js --host 0.0.0.0 --port 8080
 *     bash launcher.sh            # 一键启动（自动检测 Node.js/Python）
 */

const http = require("http");
const fs = require("fs");
const path = require("path");
const { spawn } = require("child_process");
const { URL } = require("url");

// ── 配置 ──────────────────────────────────────────────────────────────
const SCRIPT_DIR = path.resolve(__dirname, "..", "scripts");
const NOTIFIER_DIR = path.resolve(__dirname, "..", "scripts", "notifiers");
const MAX_HISTORY = 50;
let HISTORY = [];
const RUNNING_PROCS = new Map(); // runId -> { proc, scriptName }

// ── 错误日志 ──────────────────────────────────────────────────────────
const ERROR_LOG_FILE = path.join(__dirname, ".error-log.jsonl");
const ERROR_LOG_MAX_ENTRIES = 2000; // 最多保留条目数
const ERROR_LOG_MAX_DAYS = 7;       // 最多保留天数

function appendErrorLog(scriptName, runId, line) {
  try {
    const entry = JSON.stringify({
      timestamp: new Date().toISOString(),
      script: scriptName,
      runId,
      line,
    }) + "\n";
    fs.appendFileSync(ERROR_LOG_FILE, entry, "utf-8");
  } catch (e) {
    // 静默失败，避免日志系统本身导致崩溃
  }
}

function cleanupErrorLog() {
  try {
    if (!fs.existsSync(ERROR_LOG_FILE)) return;
    const content = fs.readFileSync(ERROR_LOG_FILE, "utf-8");
    const lines = content.split("\n").filter(l => l.trim() !== "");
    if (lines.length === 0) return;

    const cutoff = new Date();
    cutoff.setDate(cutoff.getDate() - ERROR_LOG_MAX_DAYS);
    const cutoffStr = cutoff.toISOString();

    let filtered = lines;
    // 按时间过滤
    filtered = filtered.filter(line => {
      try {
        const entry = JSON.parse(line);
        return entry.timestamp >= cutoffStr;
      } catch {
        return false;
      }
    });
    // 按数量限制
    if (filtered.length > ERROR_LOG_MAX_ENTRIES) {
      filtered = filtered.slice(filtered.length - ERROR_LOG_MAX_ENTRIES);
    }

    fs.writeFileSync(ERROR_LOG_FILE, filtered.join("\n") + "\n", "utf-8");
  } catch (e) {
    console.warn("[错误日志] 清理失败:", e.message);
  }
}

function readErrorLog(limit = 200, scriptFilter = "") {
  try {
    if (!fs.existsSync(ERROR_LOG_FILE)) return [];
    const content = fs.readFileSync(ERROR_LOG_FILE, "utf-8");
    const lines = content.split("\n").filter(l => l.trim() !== "");
    let entries = lines.map(l => {
      try { return JSON.parse(l); } catch { return null; }
    }).filter(Boolean);

    if (scriptFilter) {
      entries = entries.filter(e => e.script && e.script.includes(scriptFilter));
    }
    // 返回最新的
    return entries.slice(-limit);
  } catch (e) {
    console.warn("[错误日志] 读取失败:", e.message);
    return [];
  }
}

// 每天自动清理一次
setInterval(cleanupErrorLog, 24 * 60 * 60 * 1000);

// ── 版本号 ────────────────────────────────────────────────────────────
// 优先使用 git 最后一次提交时间，回退到本文件修改时间（确保重启不变）
let VERSION;
try {
  const { execSync } = require("child_process");
  const commitTime = execSync("git log -1 --format=%ci", {
    cwd: path.resolve(__dirname, ".."),
    encoding: "utf8",
    timeout: 5000,
  }).trim();
  VERSION = new Date(commitTime).toISOString().slice(0, 19).replace(/[-:T]/g, "");
} catch {
  const stats = fs.statSync(__filename);
  VERSION = stats.mtime.toISOString().slice(0, 19).replace(/[-:T]/g, "");
}
const BUILD_TIME = new Date();

// ── 通知配置 ──────────────────────────────────────────────────────────
// 内存存储，重启后重置。如需持久化可改为读写 JSON 文件。
let NOTIFY_CONFIG = {
  enabled: false,
  channel: "",      // feishu | dingtalk | wecom | slack | telegram | line | whatsapp | email
  webhook: "",      // webhook URL
  secret: "",       // 密钥（钉钉等需要）
};

const NOTIFY_CHANNELS = {
  feishu:   { name: "飞书",       icon: "📢", script: "feishu.sh" },
  dingtalk: { name: "钉钉",       icon: "💬", script: "dingtalk.sh" },
  wecom:    { name: "企业微信",   icon: "💼", script: "wecom.sh" },
  slack:    { name: "Slack",      icon: "💬", script: "slack.sh" },
  telegram: { name: "Telegram",   icon: "✈️", script: "telegram.sh" },
  line:     { name: "LINE",       icon: "📱", script: "line.sh" },
  whatsapp: { name: "WhatsApp",   icon: "📞", script: "whatsapp.sh" },
  email:    { name: "邮件",       icon: "📧", script: "email.sh" },
};

// 尝试从配置文件读取
const NOTIFY_CONFIG_PATH = path.join(__dirname, ".notify-config.json");
try {
  if (fs.existsSync(NOTIFY_CONFIG_PATH)) {
    NOTIFY_CONFIG = { ...NOTIFY_CONFIG, ...JSON.parse(fs.readFileSync(NOTIFY_CONFIG_PATH, "utf-8")) };
  }
} catch (e) {
  console.warn("通知配置读取失败:", e.message);
}

function saveNotifyConfig() {
  try {
    fs.writeFileSync(NOTIFY_CONFIG_PATH, JSON.stringify(NOTIFY_CONFIG, null, 2));
  } catch (e) {
    console.warn("通知配置保存失败:", e.message);
  }
}

// 发送通知
async function sendNotification(scriptName, status, output) {
  if (!NOTIFY_CONFIG.enabled || !NOTIFY_CONFIG.channel || !NOTIFY_CONFIG.webhook) return;

  const channel = NOTIFY_CHANNELS[NOTIFY_CONFIG.channel];
  if (!channel) return;

  const notifierPath = path.join(NOTIFIER_DIR, channel.script);
  if (!fs.existsSync(notifierPath)) {
    console.warn(`通知脚本不存在: ${notifierPath}`);
    return;
  }

  const statusEmoji = status === "success" ? "✅" : "❌";
  const statusText = status === "success" ? "通过" : "失败";
  const summary = output.slice(0, 20).join("\n");

  const message = `## Code Review Assistant 通知

**脚本**: ${scriptName}
**状态**: ${statusEmoji} ${statusText}
**时间**: ${new Date().toLocaleString("zh-CN")}

**摘要**:
\`\`\`
${summary}
\`\`\`
`;

  return new Promise((resolve) => {
    const env = { ...process.env };
    if (NOTIFY_CONFIG.webhook) env.WEBHOOK_URL = NOTIFY_CONFIG.webhook;
    if (NOTIFY_CONFIG.secret) env.WEBHOOK_SECRET = NOTIFY_CONFIG.secret;

    const proc = spawn("bash", [notifierPath, message], {
      env,
      stdio: ["pipe", "ignore", "ignore"],
    });
    proc.stdin.write(message);
    proc.stdin.end();
    proc.on("close", () => resolve());
    proc.on("error", () => resolve());
  });
}

// ── 定时任务 ──────────────────────────────────────────────────────────
const SCHEDULE_FILE = path.join(__dirname, ".schedule.json");
let SCHEDULES = [];

function loadSchedules() {
  try {
    if (fs.existsSync(SCHEDULE_FILE)) {
      SCHEDULES = JSON.parse(fs.readFileSync(SCHEDULE_FILE, "utf-8"));
      if (!Array.isArray(SCHEDULES)) SCHEDULES = [];
    }
  } catch (e) {
    console.warn("定时任务配置读取失败:", e.message);
    SCHEDULES = [];
  }
}

function saveSchedules() {
  try {
    fs.writeFileSync(SCHEDULE_FILE, JSON.stringify(SCHEDULES, null, 2));
  } catch (e) {
    console.warn("定时任务配置保存失败:", e.message);
  }
}

function parseCronField(field, max, min = 0) {
  if (field === "*") {
    const arr = [];
    for (let i = min; i <= max; i++) arr.push(i);
    return arr;
  }
  if (field.startsWith("*/")) {
    const step = parseInt(field.slice(2), 10);
    if (isNaN(step) || step <= 0) return [];
    const arr = [];
    for (let i = min; i <= max; i += step) arr.push(i);
    return arr;
  }
  if (field.includes("-")) {
    const [start, end] = field.split("-").map(Number);
    if (isNaN(start) || isNaN(end)) return [];
    const arr = [];
    for (let i = Math.max(start, min); i <= Math.min(end, max); i++) arr.push(i);
    return arr;
  }
  if (field.includes(",")) {
    return field.split(",").map(Number).filter(n => !isNaN(n) && n >= min && n <= max);
  }
  const n = parseInt(field, 10);
  return isNaN(n) || n < min || n > max ? [] : [n];
}

function matchesCron(date, cronExpr) {
  const parts = cronExpr.trim().split(/\s+/);
  if (parts.length !== 5) return false;
  const [minStr, hourStr, dayStr, monthStr, dowStr] = parts;
  const minutes = parseCronField(minStr, 59);
  const hours = parseCronField(hourStr, 23);
  const days = parseCronField(dayStr, 31, 1);
  const months = parseCronField(monthStr, 12, 1);
  const dows = parseCronField(dowStr, 7);
  return (
    minutes.includes(date.getMinutes()) &&
    hours.includes(date.getHours()) &&
    days.includes(date.getDate()) &&
    months.includes(date.getMonth() + 1) &&
    dows.includes(date.getDay())
  );
}

function getScriptsBySeverity(severity) {
  const scripts = getAvailableScripts();
  if (severity === "all" || !severity) return scripts;
  const minPriority = severity === "critical" ? 5 : severity === "high" ? 4 : severity === "medium" ? 3 : 1;
  return scripts.filter(s => s.priority >= minPriority);
}

async function executeSchedule(task) {
  const scripts = task.severity
    ? getScriptsBySeverity(task.severity)
    : getAvailableScripts().filter(s => (task.scriptIds || []).includes(s.id));

  if (scripts.length === 0) {
    console.warn(`[定时任务] ${task.name} 没有匹配的脚本`);
    return;
  }

  console.log(`[定时任务] 执行: ${task.name} (${scripts.length} 个脚本)`);

  for (const script of scripts) {
    const runId = Math.random().toString(36).substring(2, 10);
    const startTime = Date.now();
    const scriptPath = path.join(SCRIPT_DIR, script.file);

    const record = {
      id: runId,
      script: script.id,
      script_name: script.name,
      script_icon: script.icon,
      command: `bash ${script.file}`,
      start_time: new Date().toLocaleString("zh-CN", {
        year: "numeric", month: "2-digit", day: "2-digit",
        hour: "2-digit", minute: "2-digit", second: "2-digit",
      }),
      status: "running",
      output: [],
    };
    HISTORY.push(record);
    if (HISTORY.length > MAX_HISTORY) HISTORY.shift();

    try {
      // 传递多平台 API Key 环境变量给定时任务
      const scheduleEnv = {
        ...process.env,
        ANTHROPIC_API_KEY: process.env.ANTHROPIC_API_KEY || "",
        ANTHROPIC_AUTH_TOKEN: process.env.ANTHROPIC_AUTH_TOKEN || "",
        ANTHROPIC_BASE_URL: process.env.ANTHROPIC_BASE_URL || "",
        OPENAI_API_KEY: process.env.OPENAI_API_KEY || "",
        OPENAI_BASE_URL: process.env.OPENAI_BASE_URL || "",
        KIMI_API_KEY: process.env.KIMI_API_KEY || "",
        MOONSHOT_API_KEY: process.env.MOONSHOT_API_KEY || "",
        KIMI_BASE_URL: process.env.KIMI_BASE_URL || "",
        MOONSHOT_BASE_URL: process.env.MOONSHOT_BASE_URL || "",
        DEEPSEEK_API_KEY: process.env.DEEPSEEK_API_KEY || "",
        DEEPSEEK_BASE_URL: process.env.DEEPSEEK_BASE_URL || "",
        DASHSCOPE_API_KEY: process.env.DASHSCOPE_API_KEY || "",
        QWEN_API_KEY: process.env.QWEN_API_KEY || "",
        DASHSCOPE_BASE_URL: process.env.DASHSCOPE_BASE_URL || "",
      };
      if (script.file === "ai-code-review.sh") {
        scheduleEnv.DASHBOARD_QUIET = "1";
      }

      const proc = spawn("bash", [scriptPath], {
        cwd: path.resolve(__dirname, ".."),
        stdio: ["ignore", "pipe", "pipe"],
        env: scheduleEnv,
      });
      const fullOutput = [];
      proc.stdout.on("data", d => fullOutput.push(...d.toString("utf-8").split(/\r?\n/).filter(l => l !== "")));
      proc.stderr.on("data", d => fullOutput.push(...d.toString("utf-8").split(/\r?\n/).filter(l => l !== "")));

      await new Promise((resolve) => {
        proc.on("close", (code) => {
          const elapsed = ((Date.now() - startTime) / 1000).toFixed(2);
          const rec = HISTORY.find(h => h.id === runId);
          if (rec) {
            rec.status = code === 0 ? "success" : "failed";
            rec.exit_code = code;
            rec.elapsed = parseFloat(elapsed);
            rec.output = fullOutput;
          }
          resolve();
        });
        proc.on("error", () => {
          const rec = HISTORY.find(h => h.id === runId);
          if (rec) rec.status = "failed";
          resolve();
        });
      });
    } catch (e) {
      console.error(`[定时任务] ${script.name} 执行失败:`, e.message);
    }
  }

  task.lastRun = new Date().toISOString();
  saveSchedules();
  if (task.notify && NOTIFY_CONFIG.enabled) {
    await sendNotification(task.name, "success", [`定时任务 ${task.name} 执行完成`]);
  }
  console.log(`[定时任务] ${task.name} 执行完成`);
}

function checkSchedules() {
  const now = new Date();
  for (const task of SCHEDULES) {
    if (!task.enabled) continue;
    if (!task.cron) continue;
    const lastRun = task.lastRun ? new Date(task.lastRun) : null;
    if (lastRun && lastRun.getFullYear() === now.getFullYear() &&
        lastRun.getMonth() === now.getMonth() &&
        lastRun.getDate() === now.getDate() &&
        lastRun.getHours() === now.getHours() &&
        lastRun.getMinutes() === now.getMinutes()) {
      continue;
    }
    if (matchesCron(now, task.cron)) {
      executeSchedule(task).catch(err => console.error("[定时任务] 执行失败:", err));
    }
  }
}

function startScheduleLoop() {
  loadSchedules();
  checkSchedules();
  setInterval(checkSchedules, 60000);
  console.log(`[定时任务] 已加载 ${SCHEDULES.length} 个任务`);
}

// ── 脚本元数据 ────────────────────────────────────────────────────────
// priority: 5=最高(安全类) 4=高(质量类) 3=中(测试/性能) 2=低(工具类) 1=最低
const SCRIPT_META = {
  "scan-secrets.sh": {
    name: "密钥扫描",
    desc: "扫描代码中的敏感信息泄露（API Key、Token、密码等）",
    icon: "🔐",
    priority: 5,
    args: [
      { name: "path", default: ".", desc: "扫描路径" },
      {
        name: "severity",
        default: "critical",
        desc: "严重级别",
        options: ["critical", "high", "medium", "all"],
      },
    ],
    category: "security",
  },
  "scan-deps.sh": {
    name: "依赖漏洞扫描",
    desc: "检测 package.json、requirements.txt 等依赖中的已知漏洞",
    icon: "📦",
    priority: 5,
    args: [{ name: "path", default: ".", desc: "扫描路径" }],
    category: "security",
  },
  "supply-chain.sh": {
    name: "供应链安全",
    desc: "检测依赖供应链攻击风险（恶意包、 typosquatting）",
    icon: "🔗",
    priority: 3,
    args: [{ name: "path", default: ".", desc: "扫描路径" }],
    category: "security",
  },
  "pii-scan.sh": {
    name: "隐私数据扫描",
    desc: "检测代码中的 PII（个人身份信息）泄露",
    icon: "🛡️",
    priority: 5,
    args: [{ name: "path", default: ".", desc: "扫描路径" }],
    category: "security",
  },
  "code-smell.sh": {
    name: "代码异味检测",
    desc: "检测代码中的坏味道（过长函数、重复代码、魔法数字等）",
    icon: "👃",
    priority: 4,
    args: [{ name: "path", default: ".", desc: "扫描路径" }],
    category: "quality",
  },
  "naming-convention.sh": {
    name: "命名规范检查",
    desc: "检查变量、函数、类命名是否符合规范",
    icon: "📝",
    priority: 4,
    args: [{ name: "path", default: ".", desc: "扫描路径" }],
    category: "quality",
  },
  "lint-check.sh": {
    name: "代码规范检查",
    desc: "运行 ESLint、Stylelint 等工具检查代码规范",
    icon: "📏",
    priority: 4,
    args: [{ name: "path", default: ".", desc: "扫描路径" }],
    category: "quality",
  },
  "complexity-analysis.sh": {
    name: "复杂度分析",
    desc: "计算圈复杂度，识别需要重构的复杂函数",
    icon: "📊",
    priority: 1,
    args: [{ name: "path", default: ".", desc: "扫描路径" }],
    category: "quality",
  },
  "type-safety.sh": {
    name: "类型安全检测",
    desc: "检查 TypeScript 类型定义是否完整",
    icon: "🔒",
    priority: 4,
    args: [{ name: "path", default: ".", desc: "扫描路径" }],
    category: "quality",
  },
  "resource-leak.sh": {
    name: "资源泄漏检测",
    desc: "检测未关闭的文件、连接、定时器等资源泄漏",
    icon: "💧",
    priority: 5,
    args: [{ name: "path", default: ".", desc: "扫描路径" }],
    category: "quality",
  },
  "concurrency-check.sh": {
    name: "并发安全检查",
    desc: "检测竞态条件、死锁、线程安全问题",
    icon: "🧵",
    priority: 5,
    args: [{ name: "path", default: ".", desc: "扫描路径" }],
    category: "quality",
  },
  "error-handling.sh": {
    name: "错误处理检查",
    desc: "检查异常处理是否完善",
    icon: "🚨",
    priority: 5,
    args: [{ name: "path", default: ".", desc: "扫描路径" }],
    category: "quality",
  },
  "reuse-check.sh": {
    name: "代码复用检查",
    desc: "检测重复代码和可复用逻辑",
    icon: "♻️",
    priority: 4,
    args: [{ name: "path", default: ".", desc: "扫描路径" }],
    category: "quality",
  },
  "cross-file-context.sh": {
    name: "跨文件分析",
    desc: "分析跨文件依赖和影响范围",
    icon: "📂",
    priority: 3,
    args: [{ name: "path", default: ".", desc: "扫描路径" }],
    category: "quality",
  },
  "severity-gate.sh": {
    name: "质量门禁",
    desc: "综合评分，判断是否允许合并（失败会返回非 0）",
    icon: "🚦",
    priority: 4,
    args: [
      { name: "path", default: ".", desc: "扫描路径" },
      {
        name: "severity",
        default: "high",
        desc: "门禁阈值",
        options: ["critical", "high", "medium", "all"],
      },
    ],
    category: "gate",
  },
  "test-coverage.sh": {
    name: "测试覆盖率",
    desc: "检查测试覆盖率是否达标",
    icon: "🧪",
    priority: 3,
    args: [{ name: "path", default: ".", desc: "扫描路径" }],
    category: "test",
  },
  "test-quality.sh": {
    name: "测试质量检查",
    desc: "检查测试用例质量（断言完整性、独立性等）",
    icon: "✅",
    priority: 3,
    args: [{ name: "path", default: ".", desc: "扫描路径" }],
    category: "test",
  },
  "perf-benchmark.sh": {
    name: "性能基准测试",
    desc: "运行性能基准测试并与历史数据对比",
    icon: "⚡",
    priority: 2,
    args: [{ name: "path", default: ".", desc: "扫描路径" }],
    category: "perf",
  },
  "bundle-size.sh": {
    name: "包体积分析",
    desc: "分析前端打包体积，检测过大依赖",
    icon: "📦",
    priority: 2,
    args: [{ name: "path", default: ".", desc: "扫描路径" }],
    category: "perf",
  },
  "a11y-check.sh": {
    name: "无障碍检查",
    desc: "检查前端代码的无障碍访问（a11y）合规性",
    icon: "♿",
    priority: 1,
    args: [{ name: "path", default: ".", desc: "扫描路径" }],
    category: "frontend",
  },
  "i18n-check.sh": {
    name: "国际化检查",
    desc: "检查硬编码文案和国际化完整性",
    icon: "🌍",
    priority: 1,
    args: [{ name: "path", default: ".", desc: "扫描路径" }],
    category: "frontend",
  },
  "api-contract.sh": {
    name: "API 契约检查",
    desc: "检查 API 接口定义的一致性",
    icon: "📡",
    priority: 3,
    args: [{ name: "path", default: ".", desc: "扫描路径" }],
    category: "quality",
  },
  "db-migration.sh": {
    name: "数据库迁移检查",
    desc: "检查数据库迁移脚本的安全性",
    icon: "🗄️",
    priority: 3,
    args: [{ name: "path", default: ".", desc: "扫描路径" }],
    category: "quality",
  },
  "architecture-check.sh": {
    name: "架构规范检查",
    desc: "检查代码是否符合架构分层规范",
    icon: "🏗️",
    priority: 4,
    args: [{ name: "path", default: ".", desc: "扫描路径" }],
    category: "quality",
  },
  "impact-analysis.sh": {
    name: "影响面分析",
    desc: "分析代码变更的影响范围",
    icon: "🎯",
    priority: 3,
    args: [
      { name: "path", default: ".", desc: "扫描路径" },
      { name: "base", default: "HEAD~1", desc: "对比基准" },
    ],
    category: "quality",
  },
  "config-drift.sh": {
    name: "配置漂移检测",
    desc: "检测配置文件的意外变更",
    icon: "⚙️",
    priority: 4,
    args: [{ name: "path", default: ".", desc: "扫描路径" }],
    category: "quality",
  },
  "feature-flag.sh": {
    name: "功能开关检查",
    desc: "检查功能开关的使用规范性",
    icon: "🚩",
    priority: 1,
    args: [{ name: "path", default: ".", desc: "扫描路径" }],
    category: "quality",
  },
  "license-check.sh": {
    name: "许可证检查",
    desc: "检查依赖许可证兼容性",
    icon: "📋",
    priority: 2,
    args: [{ name: "path", default: ".", desc: "扫描路径" }],
    category: "quality",
  },
  "codeowners-check.sh": {
    name: "CodeOwners 检查",
    desc: "检查 CODEOWNERS 文件配置",
    icon: "👥",
    priority: 2,
    args: [{ name: "path", default: ".", desc: "扫描路径" }],
    category: "quality",
  },
  "commit-lint.sh": {
    name: "提交信息规范",
    desc: "检查 commit message 格式",
    icon: "💬",
    priority: 2,
    args: [
      { name: "path", default: ".", desc: "扫描路径" },
      { name: "base", default: "HEAD~10", desc: "检查范围" },
    ],
    category: "quality",
  },
  "doc-quality.sh": {
    name: "文档质量检查",
    desc: "检查代码注释和文档完整性",
    icon: "📖",
    priority: 2,
    args: [{ name: "path", default: ".", desc: "扫描路径" }],
    category: "quality",
  },
  "reviewer-assign.sh": {
    name: "Reviewer 推荐",
    desc: "根据代码变更自动推荐 Reviewer",
    icon: "👤",
    priority: 1,
    args: [{ name: "path", default: ".", desc: "扫描路径" }],
    category: "tool",
  },
  "export-report.sh": {
    name: "导出报告",
    desc: "将审查结果导出为多种格式",
    icon: "📄",
    priority: 1,
    args: [
      { name: "path", default: ".", desc: "扫描路径" },
      {
        name: "format",
        default: "markdown",
        desc: "导出格式",
        options: ["markdown", "json", "html", "sarif"],
      },
    ],
    category: "tool",
  },
  "changelog-gen.sh": {
    name: "变更日志生成",
    desc: "根据 commit 自动生成 changelog",
    icon: "📝",
    priority: 1,
    args: [{ name: "path", default: ".", desc: "扫描路径" }],
    category: "tool",
  },
  "pr-describe.sh": {
    name: "PR 描述生成",
    desc: "自动生成 PR 描述",
    icon: "🤖",
    priority: 3,
    args: [{ name: "path", default: ".", desc: "扫描路径" }],
    category: "tool",
  },
  "pr-comment.sh": {
    name: "PR 评论",
    desc: "生成 PR 内联评论",
    icon: "💬",
    priority: 2,
    args: [{ name: "path", default: ".", desc: "扫描路径" }],
    category: "tool",
  },
  "auto-fix.sh": {
    name: "自动修复",
    desc: "自动应用安全修复建议（建议先在分支上试用）",
    icon: "🔧",
    priority: 4,
    args: [{ name: "path", default: ".", desc: "扫描路径" }],
    category: "tool",
  },
  "ai-code-review.sh": {
    name: "AI 智能代码审查",
    desc: "调用 Claude API 进行深度代码审查，输出结构化 Markdown 报告（含严重问题、警告、建议、自动修复补丁）",
    icon: "🤖",
    priority: 4,
    args: [
      { name: "path", default: ".", desc: "扫描路径" },
      { name: "file", default: "", desc: "指定文件路径（可选，留空则审查 git diff）" },
      {
        name: "depth",
        default: "standard",
        desc: "审查深度",
        options: ["quick", "standard", "deep"],
      },
    ],
    category: "quality",
  },
  "review-history.sh": {
    name: "审查历史",
    desc: "查看历史审查记录和趋势分析",
    icon: "📈",
    priority: 1,
    args: [{ name: "path", default: ".", desc: "扫描路径" }],
    category: "tool",
  },
  "pr-context.sh": {
    name: "PR 上下文分析",
    desc: "分析 PR 的变更范围和影响面",
    icon: "🔍",
    priority: 1,
    args: [{ name: "path", default: ".", desc: "扫描路径" }],
    category: "tool",
  },
  "scheduled-review.sh": {
    name: "定时审查",
    desc: "按计划执行自动审查",
    icon: "⏰",
    priority: 1,
    args: [
      { name: "path", default: ".", desc: "扫描路径" },
      {
        name: "mode",
        default: "run",
        desc: "模式",
        options: ["run", "install", "uninstall"],
      },
    ],
    category: "tool",
  },
};

const CAT_LABEL = {
  security: "🔐 安全扫描",
  quality: "✨ 代码质量",
  gate: "🚦 质量门禁",
  test: "🧪 测试相关",
  perf: "⚡ 性能分析",
  frontend: "🎨 前端专用",
  tool: "🛠️ 工具脚本",
  other: "📄 其他",
};

// ── 工具函数 ──────────────────────────────────────────────────────────
function getAvailableScripts() {
  const scripts = [];
  if (!fs.existsSync(SCRIPT_DIR)) return scripts;

  for (const fname of fs.readdirSync(SCRIPT_DIR).sort()) {
    if (fname.endsWith(".sh")) {
      const meta = SCRIPT_META[fname] || {
        name: fname.replace(".sh", ""),
        desc: `执行 ${fname} 脚本进行代码审查`,
        icon: "📄",
        priority: 2,
        args: [{ name: "path", default: ".", desc: "扫描路径" }],
        category: "other",
      };
      scripts.push({
        id: fname.replace(".sh", ""),
        file: fname,
        ...meta,
      });
    }
  }
  return scripts;
}

function sendJSON(res, data, status = 200) {
  const body = JSON.stringify(data);
  res.writeHead(status, {
    "Content-Type": "application/json; charset=utf-8",
    "Access-Control-Allow-Origin": "*",
    "Content-Length": Buffer.byteLength(body),
  });
  res.end(body);
}

function sendSSE(res, event, data) {
  const payload = JSON.stringify(data);
  res.write(`event: ${event}\ndata: ${payload}\n\n`);
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let body = "";
    req.on("data", (chunk) => (body += chunk));
    req.on("end", () => {
      try {
        resolve(JSON.parse(body));
      } catch {
        reject(new Error("Invalid JSON"));
      }
    });
    req.on("error", reject);
  });
}

function serveFile(res, fpath, ctype) {
  if (!fs.existsSync(fpath)) {
    sendJSON(res, { error: "Not Found" }, 404);
    return;
  }
  const data = fs.readFileSync(fpath);
  res.writeHead(200, {
    "Content-Type": ctype,
    "Content-Length": data.length,
  });
  res.end(data);
}

// ── 路由处理 ──────────────────────────────────────────────────────────
async function handleRequest(req, res) {
  const url = new URL(req.url, `http://${req.headers.host}`);
  const pathname = url.pathname;
  const method = req.method;

  // CORS
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");

  if (method === "OPTIONS") {
    res.writeHead(204);
    res.end();
    return;
  }

  // ── 静态文件 ─────────────────────────────────────────────
  if (pathname === "/" || pathname === "/index.html") {
    serveFile(res, path.join(__dirname, "index.html"), "text/html; charset=utf-8");
    return;
  }
  if (pathname.startsWith("/static/")) {
    const fname = pathname.slice(1);
    const fpath = path.join(__dirname, fname);
    const ctype = fname.endsWith(".css")
      ? "text/css"
      : "application/javascript";
    serveFile(res, fpath, ctype + "; charset=utf-8");
    return;
  }

  // ── API: 脚本列表 ────────────────────────────────────────
  if (pathname === "/api/scripts" && method === "GET") {
    const scripts = getAvailableScripts();
    const categories = {};
    for (const s of scripts) {
      const cat = s.category;
      if (!categories[cat]) {
        categories[cat] = { label: CAT_LABEL[cat] || cat, scripts: [] };
      }
      categories[cat].scripts.push(s);
    }
    sendJSON(res, { scripts, categories });
    return;
  }

  // ── API: 历史记录 ────────────────────────────────────────
  if (pathname === "/api/history" && method === "GET") {
    sendJSON(res, { history: [...HISTORY].reverse() });
    return;
  }

  // ── API: 单次历史详情 ────────────────────────────────────
  const historyMatch = pathname.match(/^\/api\/history\/(.+)$/);
  if (historyMatch && method === "GET") {
    const hid = historyMatch[1];
    const record = HISTORY.find((h) => h.id === hid);
    if (record) {
      sendJSON(res, record);
    } else {
      sendJSON(res, { error: "未找到记录" }, 404);
    }
    return;
  }

  // ── API: 通知配置 ────────────────────────────────────────
  if (pathname === "/api/notify-config" && method === "GET") {
    sendJSON(res, {
      config: NOTIFY_CONFIG,
      channels: Object.entries(NOTIFY_CHANNELS).map(([key, val]) => ({
        key,
        ...val,
      })),
    });
    return;
  }

  if (pathname === "/api/notify-config" && method === "POST") {
    let body;
    try {
      body = await readBody(req);
    } catch {
      sendJSON(res, { error: "无效的 JSON" }, 400);
      return;
    }
    NOTIFY_CONFIG = {
      enabled: !!body.enabled,
      channel: String(body.channel || ""),
      webhook: String(body.webhook || ""),
      secret: String(body.secret || ""),
    };
    saveNotifyConfig();
    sendJSON(res, { success: true, config: NOTIFY_CONFIG });
    return;
  }

  // ── API: 终止运行 ────────────────────────────────────────
  if (pathname === "/api/kill" && method === "POST") {
    let killed = 0;
    for (const [runId, info] of RUNNING_PROCS) {
      try {
        info.proc.kill("SIGTERM");
        killed++;
      } catch (e) {
        console.warn(`终止 ${runId} 失败:`, e.message);
      }
    }
    sendJSON(res, { success: true, killed });
    return;
  }

  // ── API: 错误日志 ────────────────────────────────────────
  if (pathname === "/api/error-log" && method === "GET") {
    const limit = parseInt(url.searchParams.get("limit") || "200", 10);
    const scriptFilter = url.searchParams.get("script") || "";
    const entries = readErrorLog(limit, scriptFilter);
    sendJSON(res, { entries, total: entries.length });
    return;
  }

  if (pathname === "/api/error-log" && method === "DELETE") {
    try {
      if (fs.existsSync(ERROR_LOG_FILE)) {
        fs.writeFileSync(ERROR_LOG_FILE, "", "utf-8");
      }
      sendJSON(res, { success: true });
    } catch (e) {
      sendJSON(res, { error: e.message }, 500);
    }
    return;
  }

  // ── API: 版本号 ──────────────────────────────────────────
  if (pathname === "/api/version" && method === "GET") {
    sendJSON(res, { version: VERSION, buildTime: BUILD_TIME.toISOString() });
    return;
  }

  // ── API: 定时任务 ────────────────────────────────────────
  if (pathname === "/api/schedule" && method === "GET") {
    sendJSON(res, { tasks: SCHEDULES });
    return;
  }

  if (pathname === "/api/schedule" && method === "POST") {
    let body;
    try {
      body = await readBody(req);
    } catch {
      sendJSON(res, { error: "无效的 JSON" }, 400);
      return;
    }
    const task = {
      id: body.id || Math.random().toString(36).substring(2, 10),
      name: String(body.name || "未命名任务"),
      severity: body.severity || "",
      scriptIds: body.scriptIds || [],
      cron: String(body.cron || ""),
      enabled: !!body.enabled,
      notify: !!body.notify,
      createdAt: body.createdAt || new Date().toISOString(),
      lastRun: body.lastRun || null,
    };
    const idx = SCHEDULES.findIndex(t => t.id === task.id);
    if (idx >= 0) {
      SCHEDULES[idx] = task;
    } else {
      SCHEDULES.push(task);
    }
    saveSchedules();
    sendJSON(res, { success: true, task });
    return;
  }

  if (pathname === "/api/schedule" && method === "DELETE") {
    let body;
    try {
      body = await readBody(req);
    } catch {
      sendJSON(res, { error: "无效的 JSON" }, 400);
      return;
    }
    const id = body.id;
    if (!id) {
      sendJSON(res, { error: "缺少 id" }, 400);
      return;
    }
    SCHEDULES = SCHEDULES.filter(t => t.id !== id);
    saveSchedules();
    sendJSON(res, { success: true });
    return;
  }

  // ── API: 运行脚本（SSE）──────────────────────────────────
  if (pathname === "/api/run" && method === "POST") {
    await handleRun(req, res);
    return;
  }

  sendJSON(res, { error: "Not Found" }, 404);
}

// ── 运行脚本（SSE 流式输出）───────────────────────────────────────────
async function handleRun(req, res) {
  let body;
  try {
    body = await readBody(req);
  } catch {
    sendJSON(res, { error: "无效的 JSON" }, 400);
    return;
  }

  const scriptId = body.script || "";
  const args = body.args || {};

  const scripts = getAvailableScripts();
  const target = scripts.find((s) => s.id === scriptId);
  if (!target) {
    sendJSON(res, { error: `脚本不存在: ${scriptId}` }, 404);
    return;
  }

  const scriptPath = path.join(SCRIPT_DIR, target.file);
  if (!fs.existsSync(scriptPath)) {
    sendJSON(res, { error: `脚本文件不存在: ${target.file}` }, 404);
    return;
  }

  // 构建命令行参数
  const cmd = ["bash", scriptPath];
  for (const argDef of target.args || []) {
    const val = args[argDef.name] ?? argDef.default ?? "";
    if (val) cmd.push(String(val));
  }

  const runId = Math.random().toString(36).substring(2, 10);
  const startTime = Date.now();

  // 记录历史
  const record = {
    id: runId,
    script: scriptId,
    script_name: target.name,
    script_icon: target.icon,
    command: cmd.join(" "),
    start_time: new Date().toLocaleString("zh-CN", {
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
    }),
    status: "running",
    output: [],
  };
  HISTORY.push(record);
  if (HISTORY.length > MAX_HISTORY) HISTORY.shift();

  // SSE 响应头
  res.writeHead(200, {
    "Content-Type": "text/event-stream; charset=utf-8",
    "Cache-Control": "no-cache",
    "Connection": "keep-alive",
    "Access-Control-Allow-Origin": "*",
  });

  sendSSE(res, "start", {
    id: runId,
    command: cmd.join(" "),
    script: target.name,
  });

  // 执行脚本
  // 传递 API Key 环境变量（多平台支持）并启用 AI 审查脚本的安静模式
  const childEnv = {
    ...process.env,
    // Anthropic / Claude Code
    ANTHROPIC_API_KEY: process.env.ANTHROPIC_API_KEY || "",
    ANTHROPIC_AUTH_TOKEN: process.env.ANTHROPIC_AUTH_TOKEN || "",
    ANTHROPIC_BASE_URL: process.env.ANTHROPIC_BASE_URL || "",
    // OpenAI / Codex
    OPENAI_API_KEY: process.env.OPENAI_API_KEY || "",
    OPENAI_BASE_URL: process.env.OPENAI_BASE_URL || "",
    // Kimi / Moonshot
    KIMI_API_KEY: process.env.KIMI_API_KEY || "",
    MOONSHOT_API_KEY: process.env.MOONSHOT_API_KEY || "",
    KIMI_BASE_URL: process.env.KIMI_BASE_URL || "",
    MOONSHOT_BASE_URL: process.env.MOONSHOT_BASE_URL || "",
    // DeepSeek
    DEEPSEEK_API_KEY: process.env.DEEPSEEK_API_KEY || "",
    DEEPSEEK_BASE_URL: process.env.DEEPSEEK_BASE_URL || "",
    // DashScope / 通义千问
    DASHSCOPE_API_KEY: process.env.DASHSCOPE_API_KEY || "",
    QWEN_API_KEY: process.env.QWEN_API_KEY || "",
    DASHSCOPE_BASE_URL: process.env.DASHSCOPE_BASE_URL || "",
  };
  if (target.file === "ai-code-review.sh") {
    childEnv.DASHBOARD_QUIET = "1";
  }

  const proc = spawn("bash", [scriptPath, ...cmd.slice(2)], {
    cwd: path.resolve(__dirname, ".."),
    stdio: ["ignore", "pipe", "pipe"],
    env: childEnv,
  });

  // 注册到运行中进程
  RUNNING_PROCS.set(runId, { proc, scriptName: target.name });

  const fullOutput = [];

  function onStdout(data) {
    const lines = data.toString("utf-8").split(/\r?\n/);
    for (const line of lines) {
      if (line === "" && lines.indexOf(line) === lines.length - 1) continue;
      fullOutput.push(line);
      sendSSE(res, "output", { text: line });
    }
  }

  function onStderr(data) {
    const lines = data.toString("utf-8").split(/\r?\n/);
    for (const line of lines) {
      if (line === "" && lines.indexOf(line) === lines.length - 1) continue;
      fullOutput.push(line);
      // stderr 标记为 error 类型，同时写入错误日志
      sendSSE(res, "output", { text: line, type: "error" });
      appendErrorLog(target.file, runId, line);
    }
  }

  proc.stdout.on("data", onStdout);
  proc.stderr.on("data", onStderr);

  proc.on("close", async (exitCode) => {
    RUNNING_PROCS.delete(runId);
    const elapsed = ((Date.now() - startTime) / 1000).toFixed(2);
    const status = exitCode === 0 ? "success" : "failed";

    // 更新历史
    const rec = HISTORY.find((h) => h.id === runId);
    if (rec) {
      rec.status = status;
      rec.exit_code = exitCode;
      rec.elapsed = parseFloat(elapsed);
      rec.output = fullOutput;
    }

    sendSSE(res, "end", {
      id: runId,
      exit_code: exitCode,
      status,
      elapsed: parseFloat(elapsed),
    });
    res.end();

    // ── 自动通知 ─────────────────────────────────────────────
    try {
      await sendNotification(target.name, status, fullOutput);
    } catch (e) {
      console.warn("通知发送失败:", e.message);
    }
  });

  proc.on("error", (err) => {
    RUNNING_PROCS.delete(runId);
    fullOutput.push(`Error: ${err.message}`);
    sendSSE(res, "output", { text: `Error: ${err.message}` });

    const elapsed = ((Date.now() - startTime) / 1000).toFixed(2);
    const rec = HISTORY.find((h) => h.id === runId);
    if (rec) {
      rec.status = "failed";
      rec.exit_code = -1;
      rec.elapsed = parseFloat(elapsed);
      rec.output = fullOutput;
    }

    sendSSE(res, "end", {
      id: runId,
      exit_code: -1,
      status: "failed",
      elapsed: parseFloat(elapsed),
    });
    res.end();
  });
}

// ── 入口 ──────────────────────────────────────────────────────────────
function main() {
  const args = process.argv.slice(2);
  let port = 8080;
  let host = "127.0.0.1";

  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--port" && args[i + 1]) {
      port = parseInt(args[i + 1], 10);
      i++;
    } else if (args[i] === "--host" && args[i + 1]) {
      host = args[i + 1];
      i++;
    }
  }

  const server = http.createServer((req, res) => {
    handleRequest(req, res).catch((err) => {
      console.error("Request error:", err);
      sendJSON(res, { error: "Internal Server Error" }, 500);
    });
  });

  server.listen(port, host, () => {
    startScheduleLoop();
    console.log(`
╔══════════════════════════════════════════════════════════════╗
║     🔍 Code Review Assistant Dashboard                       ║
║     版本: v${VERSION}                                         ║
║                                                              ║
║     本地地址: http://${host}:${port}                          ║
║                                                              ║
║     按 Ctrl+C 停止服务                                       ║
╚══════════════════════════════════════════════════════════════╝
`);
  });

  server.on("error", (err) => {
    if (err.code === "EADDRINUSE") {
      console.error(`❌ 端口 ${port} 已被占用，请换端口重试: node server.js --port ${port + 1}`);
      process.exit(1);
    }
    throw err;
  });
}

main();
