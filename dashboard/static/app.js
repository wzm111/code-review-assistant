/**
 * Code Review Assistant Dashboard - Frontend
 * ==========================================
 * 纯原生 JS，无需任何框架或构建工具。
 */

// ── 状态 ────────────────────────────────────────────────────────────
const state = {
  scripts: [],
  categories: {},
  selected: null,
  selectedIds: new Set(),   // 多选状态
  running: false,
  batchRunning: false,      // 批量执行中
  history: [],
  view: 'dashboard',
  evtSource: null
};

// ── DOM 引用 ────────────────────────────────────────────────────────
const $ = id => document.getElementById(id);

// ── 初始化 ──────────────────────────────────────────────────────────
async function init() {
  await loadScripts();
  renderScriptList();
  await loadNotifyConfig();
  loadVersion();
  bindEvents();
  await loadHistory();
  loadSchedules();
}

// ── 加载通知配置 ────────────────────────────────────────────────────
async function loadNotifyConfig() {
  try {
    const res = await fetch('/api/notify-config');
    const data = await res.json();

    // 填充渠道下拉框
    const select = $('notifyChannel');
    if (select && data.channels) {
      select.innerHTML = '<option value="">关闭通知</option>';
      data.channels.forEach(ch => {
        const opt = document.createElement('option');
        opt.value = ch.key;
        opt.textContent = `${ch.icon} ${ch.name}`;
        select.appendChild(opt);
      });
    }

    // 填充已保存的配置
    if (data.config) {
      if ($('notifyChannel')) $('notifyChannel').value = data.config.channel || '';
      if ($('notifyWebhook')) $('notifyWebhook').value = data.config.webhook || '';
      if ($('notifySecret')) $('notifySecret').value = data.config.secret || '';
    }
  } catch (err) {
    console.error('加载通知配置失败:', err);
  }
}

// ── 加载版本号 ────────────────────────────────────────────────────────
async function loadVersion() {
  const el = document.getElementById('versionBadge');
  if (el) el.textContent = 'v…';
  try {
    const res = await fetch('/api/version');
    const data = await res.json();
    if (el && data.version) {
      el.textContent = 'v' + data.version;
    }
  } catch (err) {
    console.error('加载版本号失败:', err);
    if (el) el.textContent = 'v?.?.?';
  }
}

// ── 保存通知配置 ────────────────────────────────────────────────────
async function saveNotifyConfig() {
  const config = {
    enabled: !!$('notifyChannel').value,
    channel: $('notifyChannel').value,
    webhook: $('notifyWebhook').value.trim(),
    secret: $('notifySecret').value.trim(),
  };

  const statusEl = $('notifySaveStatus');
  statusEl.textContent = '保存中...';
  statusEl.className = 'notify-status';

  try {
    const res = await fetch('/api/notify-config', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(config)
    });
    const data = await res.json();
    if (data.success) {
      statusEl.textContent = '✅ 已保存';
      setTimeout(() => { statusEl.textContent = ''; }, 3000);
    } else {
      statusEl.textContent = '❌ 保存失败';
      statusEl.className = 'notify-status error';
    }
  } catch (err) {
    statusEl.textContent = '❌ 网络错误';
    statusEl.className = 'notify-status error';
  }
}

async function loadScripts() {
  try {
    const res = await fetch('/api/scripts');
    const data = await res.json();
    state.scripts = data.scripts || [];
    state.categories = data.categories || {};
  } catch (err) {
    console.error('加载脚本列表失败:', err);
    showToast('加载脚本列表失败，请刷新页面重试', 'error');
  }
}

// ── 优先级标签 ──────────────────────────────────────────────────────
function priorityBadge(priority) {
  const p = priority || 1;
  const stars = '★'.repeat(p) + '☆'.repeat(5 - p);
  return `<span class="priority-badge priority-p${p}" title="优先级 ${p}/5">${stars}</span>`;
}

// ── 严重级别过滤 ──────────────────────────────────────────────────────
let currentSeverityFilter = 'all';

function filterScriptsBySeverity(scripts, severity) {
  if (severity === 'all' || !severity) return scripts;
  const minPriority = severity === 'critical' ? 5 : severity === 'high' ? 4 : severity === 'medium' ? 3 : 1;
  return scripts.filter(s => s.priority >= minPriority);
}

function runSeverityFilter(severity) {
  currentSeverityFilter = severity;
  // 自动选中对应优先级的脚本
  const allScripts = [];
  Object.values(state.categories).forEach(cat => {
    allScripts.push(...cat.scripts);
  });
  const filtered = filterScriptsBySeverity(allScripts, severity);
  state.selectedIds.clear();
  filtered.forEach(s => state.selectedIds.add(s.id));
  if (filtered.length === 1) {
    state.selected = filtered[0];
  } else {
    state.selected = null;
  }
  renderScriptList($('searchInput').value);
  updateConfigPanel();
}

// ── 渲染脚本列表 ────────────────────────────────────────────────────
function renderScriptList(filter = '') {
  const container = $('scriptList');
  container.innerHTML = '';

  const filterLower = filter.toLowerCase();

  // 批量操作栏
  const batchBar = document.createElement('div');
  batchBar.className = 'batch-bar';
  batchBar.id = 'batchBar';
  batchBar.style.display = state.selectedIds.size > 0 ? 'flex' : 'none';
  batchBar.innerHTML = `
    <span class="batch-count">已选择 <strong id="batchCount">${state.selectedIds.size}</strong> 个</span>
    <button class="btn btn-batch" id="batchRunBtn">▶️ 批量运行</button>
    <button class="btn btn-batch btn-batch-secondary" id="batchClearBtn">清空</button>
  `;
  container.appendChild(batchBar);

  // 绑定批量按钮事件
  setTimeout(() => {
    const runBtn = $('batchRunBtn');
    const clearBtn = $('batchClearBtn');
    if (runBtn) runBtn.addEventListener('click', (e) => { e.stopPropagation(); runBatch(); });
    if (clearBtn) clearBtn.addEventListener('click', (e) => { e.stopPropagation(); clearSelection(); });
  }, 0);

  Object.entries(state.categories).forEach(([catKey, catData]) => {
    let filtered = filterScriptsBySeverity(catData.scripts, currentSeverityFilter);
    filtered = filtered.filter(s =>
      s.name.toLowerCase().includes(filterLower) ||
      s.desc.toLowerCase().includes(filterLower) ||
      s.id.toLowerCase().includes(filterLower)
    );
    if (filtered.length === 0) return;

    const catEl = document.createElement('div');
    catEl.className = 'category';

    const label = document.createElement('div');
    label.className = 'category-label';
    label.textContent = catData.label;
    catEl.appendChild(label);

    filtered.forEach(script => {
      const item = document.createElement('div');
      const isChecked = state.selectedIds.has(script.id);
      const isActive = state.selected?.id === script.id;
      item.className = 'script-item' + (isActive && state.selectedIds.size <= 1 ? ' active' : '');
      item.dataset.id = script.id;
      const p = script.priority || 1;
      item.innerHTML = `
        <div class="checkbox ${isChecked ? 'checked' : ''}" data-id="${script.id}"></div>
        <span class="icon">${script.icon}</span>
        <div class="info">
          <div class="name">
            <span class="name-text">${escapeHtml(script.name)}</span>
            ${priorityBadge(script.priority)}
          </div>
          <div class="meta">
            <span class="meta-priority" title="优先级 ${p}/5">${'★'.repeat(p)}${'☆'.repeat(5 - p)} 优先级 ${p}/5</span>
            <span class="meta-sep">·</span>
            <span class="meta-feature" title="功能">${escapeHtml(script.name)}</span>
          </div>
          <div class="desc">${escapeHtml(script.desc)}</div>
        </div>
      `;

      // 点击复选框
      const cb = item.querySelector('.checkbox');
      cb.addEventListener('click', (e) => {
        e.stopPropagation();
        toggleScript(script.id);
      });

      // 点击整行（单选/多选）
      item.addEventListener('click', (e) => {
        if (e.shiftKey) {
          // Shift + 点击 = 多选切换
          toggleScript(script.id);
        } else {
          // 普通点击 = 单选
          selectScript(script);
        }
      });

      catEl.appendChild(item);
    });

    container.appendChild(catEl);
  });
}

// ── 多选切换 ────────────────────────────────────────────────────────
function toggleScript(scriptId) {
  if (state.selectedIds.has(scriptId)) {
    state.selectedIds.delete(scriptId);
  } else {
    state.selectedIds.add(scriptId);
  }
  // 如果只有一个选中，也设为单选态
  if (state.selectedIds.size === 1) {
    const sid = Array.from(state.selectedIds)[0];
    state.selected = state.scripts.find(s => s.id === sid) || null;
  } else if (state.selectedIds.size === 0) {
    state.selected = null;
  }
  renderScriptList($('searchInput').value);
  updateConfigPanel();
}

function clearSelection() {
  state.selectedIds.clear();
  state.selected = null;
  renderScriptList($('searchInput').value);
  updateConfigPanel();
}

// ── 选择脚本 ────────────────────────────────────────────────────────
function selectScript(script) {
  state.selected = script;
  state.selectedIds.clear();
  state.selectedIds.add(script.id);
  renderScriptList($('searchInput').value);
  updateConfigPanel();
}

// ── 更新配置面板 ────────────────────────────────────────────────────
function updateConfigPanel() {
  const argsContainer = $('scriptArgs');
  argsContainer.innerHTML = '';

  if (state.selectedIds.size === 0) {
    $('selectedScriptName').textContent = '请选择一个脚本';
    $('selectedScriptDesc').textContent = '从左侧列表选择一个要执行的审查脚本';
    $('runBtn').disabled = true;
    $('runBtn').textContent = '▶️ 运行脚本';
    return;
  }

  if (state.selectedIds.size === 1) {
    const script = state.selected;
    $('selectedScriptName').textContent = `${script.icon} ${script.name}`;
    $('selectedScriptDesc').textContent = script.desc;
    $('runBtn').disabled = false;
    $('runBtn').textContent = '▶️ 运行脚本';

    // 渲染参数表单
    if (script.args && script.args.length > 0) {
      const row = document.createElement('div');
      row.className = 'form-row';

      script.args.forEach(arg => {
        const group = document.createElement('div');
        group.className = 'form-group';

        const label = document.createElement('label');
        label.textContent = arg.desc;
        group.appendChild(label);

        if (arg.options) {
          const select = document.createElement('select');
          select.dataset.name = arg.name;
          arg.options.forEach(opt => {
            const option = document.createElement('option');
            option.value = opt;
            option.textContent = opt;
            if (opt === arg.default) option.selected = true;
            select.appendChild(option);
          });
          group.appendChild(select);
        } else {
          const inputWrap = document.createElement('div');
          inputWrap.style.display = 'flex';
          inputWrap.style.gap = '0.5rem';

          const input = document.createElement('input');
          input.type = 'text';
          input.dataset.name = arg.name;
          // 优先使用 localStorage 中保存的值
          const saved = localStorage.getItem('arg_' + arg.name);
          input.value = saved !== null ? saved : (arg.default || '');
          input.placeholder = arg.desc;
          input.style.flex = '1';
          // 实时保存到 localStorage
          input.addEventListener('input', () => {
            localStorage.setItem('arg_' + arg.name, input.value);
          });
          inputWrap.appendChild(input);

          group.appendChild(inputWrap);
        }

        row.appendChild(group);
      });

      argsContainer.appendChild(row);
    }
  } else {
    // 多选状态
    const selectedScripts = Array.from(state.selectedIds)
      .map(id => state.scripts.find(s => s.id === id))
      .filter(Boolean);
    const names = selectedScripts.map(s => `${s.icon} ${s.name}`).join('、');
    $('selectedScriptName').textContent = `已选择 ${state.selectedIds.size} 个脚本`;
    $('selectedScriptDesc').textContent = names;
    $('runBtn').disabled = false;
    $('runBtn').textContent = '▶️ 批量运行';

    // 批量扫描路径（所有脚本共用）
    const hasPathArg = selectedScripts.every(s => s.args && s.args.some(a => a.name === 'path'));
    if (hasPathArg) {
      const row = document.createElement('div');
      row.className = 'form-row';
      const group = document.createElement('div');
      group.className = 'form-group';
      const label = document.createElement('label');
      label.textContent = '扫描路径';
      group.appendChild(label);
      const input = document.createElement('input');
      input.type = 'text';
      input.id = 'batchPathInput';
      input.dataset.batchArg = 'path';
      const savedPath = localStorage.getItem('arg_path');
      input.value = savedPath !== null ? savedPath : '.';
      input.placeholder = '扫描路径';
      input.addEventListener('input', () => {
        localStorage.setItem('arg_path', input.value);
      });
      group.appendChild(input);
      row.appendChild(group);
      argsContainer.appendChild(row);
    }
  }
}

// ── 运行脚本 ────────────────────────────────────────────────────────
async function runScript() {
  if (state.selectedIds.size === 0) return;
  if (state.selectedIds.size > 1) {
    runBatch();
    return;
  }
  if (!state.selected || state.running) return;

  const script = state.selected;
  const args = {};

  // 收集参数
  $('scriptArgs').querySelectorAll('input, select').forEach(el => {
    args[el.dataset.name] = el.value;
  });

  state.running = true;
  $('runBtn').disabled = true;
  $('runBtn').textContent = '⏳ 运行中...';

  // 清空三个输出面板
  clearAllPanels();
  hideEmptyState();

  appendLine(`$ bash scripts/${script.file} ${Object.values(args).filter(Boolean).join(' ')}`, 'info', 'process');
  appendLine('─'.repeat(60), '', 'process');

  updateStatus('running', `正在执行: ${script.name}...`);

  runWithFetch(script.id, args);
}

// ── 批量执行 ────────────────────────────────────────────────────────
async function runBatch() {
  if (state.selectedIds.size === 0 || state.batchRunning) return;

  const ids = Array.from(state.selectedIds);
  const scripts = ids.map(id => state.scripts.find(s => s.id === id)).filter(Boolean);

  state.batchRunning = true;
  state.running = true;
  $('runBtn').disabled = true;
  $('runBtn').textContent = '⏳ 批量运行中...';

  clearAllPanels();
  hideEmptyState();

  appendLine(`$ 批量执行 ${scripts.length} 个脚本`, 'info', 'process');
  appendLine('='.repeat(60), '', 'process');

  let hasError = false;

  for (let i = 0; i < scripts.length; i++) {
    const script = scripts[i];
    const args = {};

    // 收集当前脚本的参数
    const argEls = document.querySelectorAll(`[data-script-arg="${script.id}"]`);
    argEls.forEach(el => {
      args[el.dataset.name] = el.value;
    });
    // 如果没有专用参数，检查批量参数（如扫描路径）
    if (argEls.length === 0 && script.args) {
      const batchPath = $('batchPathInput');
      script.args.forEach(arg => {
        if (batchPath && arg.name === 'path') {
          args[arg.name] = batchPath.value || arg.default || '';
        } else {
          args[arg.name] = arg.default || '';
        }
      });
    }

    appendLine('', '', 'process');
    appendLine(`[${i + 1}/${scripts.length}] 🔷 ${script.icon} ${script.name}`, 'info', 'process');
    appendLine('─'.repeat(50), '', 'process');

    updateStatus('running', `批量执行中: ${script.name} (${i + 1}/${scripts.length})`);

    const result = await runSingleScript(script.id, args);
    if (result && result.status !== 'success') {
      hasError = true;
    }
  }

  state.batchRunning = false;
  state.running = false;
  $('runBtn').disabled = false;
  $('runBtn').textContent = '▶️ 批量运行';

  appendLine('', '', 'process');
  appendLine('='.repeat(60), '', 'process');
  if (hasError) {
    appendLine(`❌ 批量执行完成（部分失败）`, 'error', 'fail');
    updateStatus('failed', '批量执行完成，部分脚本失败');
  } else {
    appendLine(`✅ 批量执行完成（全部成功）`, 'success', 'result');
    updateStatus('success', '批量执行完成');
  }

  loadHistory();
}

// ── 执行单个脚本（返回 Promise）─────────────────────────────────────
function runSingleScript(scriptId, args) {
  return new Promise((resolve) => {
    const script = state.scripts.find(s => s.id === scriptId);
    if (!script) {
      resolve({ status: 'failed', error: '脚本不存在' });
      return;
    }

    fetch('/api/run', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ script: scriptId, args })
    }).then(async res => {
      if (!res.ok) {
        const err = await res.json().catch(() => ({ error: '运行失败' }));
        appendLine(`❌ ${script.name}: ${err.error}`, 'error', 'fail');
        resolve({ status: 'failed', error: err.error });
        return;
      }

      const reader = res.body.getReader();
      const decoder = new TextDecoder();
      let buffer = '';
      let result = { status: 'success' };

      try {
        while (true) {
          const { done, value } = await reader.read();
          if (done) break;

          buffer += decoder.decode(value, { stream: true });
          const lines = buffer.split('\n\n');
          buffer = lines.pop() || '';

          for (const chunk of lines) {
            const parsed = parseSSEChunkRaw(chunk);
            if (parsed && parsed.event === 'output') {
              appendLine(parsed.data.text, '', parsed.data.type);
            }
            if (parsed && parsed.event === 'end') {
              result = parsed.data;
            }
          }
        }

        if (buffer.trim()) {
          const parsed = parseSSEChunkRaw(buffer);
          if (parsed && parsed.event === 'end') {
            result = parsed.data;
          }
        }
      } catch (e) {
        appendLine(`❌ ${script.name} 读取流失败`, 'error', 'fail');
        result = { status: 'failed' };
      }

      resolve(result);
    }).catch(err => {
      appendLine(`❌ ${script.name}: ${err.message}`, 'error', 'fail');
      resolve({ status: 'failed', error: err.message });
    });
  });
}

function parseSSEChunkRaw(chunk) {
  const lines = chunk.split('\n');
  let event = 'message';
  let data = '';

  for (const line of lines) {
    if (line.startsWith('event:')) {
      event = line.slice(6).trim();
    } else if (line.startsWith('data:')) {
      data = line.slice(5).trim();
    }
  }

  if (!data) return null;

  try {
    return { event, data: JSON.parse(data) };
  } catch {
    return { event, data };
  }
}

async function runWithFetch(scriptId, args) {
  try {
    const res = await fetch('/api/run', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ script: scriptId, args })
    });

    if (!res.ok) {
      const err = await res.json();
      throw new Error(err.error || '运行失败');
    }

    const reader = res.body.getReader();
    const decoder = new TextDecoder();
    let buffer = '';

    while (true) {
      const { done, value } = await reader.read();
      if (done) break;

      buffer += decoder.decode(value, { stream: true });
      const lines = buffer.split('\n\n');
      buffer = lines.pop() || '';

      for (const chunk of lines) {
        parseSSEChunk(chunk);
      }
    }

    // 处理剩余缓冲
    if (buffer.trim()) {
      parseSSEChunk(buffer);
    }

  } catch (err) {
    appendLine(`❌ 错误: ${err.message}`, 'error', 'fail');
    updateStatus('failed', '执行出错');
    state.running = false;
    $('runBtn').disabled = false;
    $('runBtn').textContent = state.selectedIds.size > 1 ? '▶️ 批量运行' : '▶️ 运行脚本';
  }
}

function parseSSEChunk(chunk) {
  const lines = chunk.split('\n');
  let event = 'message';
  let data = '';

  for (const line of lines) {
    if (line.startsWith('event:')) {
      event = line.slice(6).trim();
    } else if (line.startsWith('data:')) {
      data = line.slice(5).trim();
    }
  }

  if (!data) return;

  try {
    const payload = JSON.parse(data);

    switch (event) {
      case 'start':
        updateStatus('running', `运行中: ${payload.script}`);
        break;

      case 'output':
        appendLine(payload.text, '', payload.type);
        break;

      case 'end':
        state.running = false;
        $('runBtn').disabled = false;
        $('runBtn').textContent = state.selectedIds.size > 1 ? '▶️ 批量运行' : '▶️ 运行脚本';

        const isSuccess = payload.status === 'success';
        updateStatus(isSuccess ? 'success' : 'failed',
          isSuccess
            ? `✅ 完成 (${payload.elapsed}s)`
            : `❌ 失败 (exit ${payload.exit_code}, ${payload.elapsed}s)`
        );

        appendLine('', '', 'process');
        appendLine(
          isSuccess
            ? `✅ 执行完成 | 耗时: ${payload.elapsed}s | exit code: ${payload.exit_code}`
            : `❌ 执行失败 | 耗时: ${payload.elapsed}s | exit code: ${payload.exit_code}`,
          isSuccess ? 'success' : 'error',
          isSuccess ? 'result' : 'fail'
        );

        loadHistory();
        break;
    }
  } catch (e) {
    // 非 JSON 数据，直接输出
    appendLine(data, '', 'process');
  }
}

// ── Markdown 渲染状态 ───────────────────────────────────────────────
let mdState = {
  inCodeBlock: false,
  codeBlockLang: '',
};

// ── Markdown 行内渲染 ───────────────────────────────────────────────
function renderMarkdownInline(text) {
  let html = escapeHtml(text);
  // 粗体: **text**
  html = html.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
  // 行内代码: `code`
  html = html.replace(/`([^`]+)`/g, '<code class="md-inline-code">$1</code>');
  return html;
}

// ── 智能输出分流 ────────────────────────────────────────────────────
function detectOutputType(text, className = '') {
  if (className === 'error') return 'fail';
  if (className === 'success') return 'result';
  const t = text.toLowerCase();

  // Markdown 报告内容归入结果面板（AI 审查脚本输出）
  if (/^#{1,6}\s+/.test(text)) return 'result';
  if (/^```/.test(text)) return 'result';
  if (/^\s*[-*]\s+/.test(text)) return 'result';   // Markdown 列表项
  if (/^\s*>\s/.test(text)) return 'result';        // Markdown 引用块

  // 明确的失败标记（以 ❌ 开头）
  if (/^\s*❌/.test(text)) return 'fail';

  // 脚本执行完成的总结行（由 Dashboard 框架输出）
  if (text.startsWith('✅ 执行完成') || text.startsWith('❌ 执行失败')) return 'result';

  // 其他内容默认归为过程面板，避免传统脚本的输出混入扫描报告
  return 'process';
}

function appendLine(text, className = '', type) {
  let outputType = type || detectOutputType(text, className);
  // stderr 的错误才放到「失败信息」面板
  // stdout 输出的 fail 类型（如 commit-lint 的格式错误报告）属于扫描结果
  const isStderr = type === 'error';
  const panelId = outputType === 'result' ? 'terminalResult'
    : (outputType === 'fail' && isStderr) ? 'terminalFail'
    : outputType === 'fail' ? 'terminalResult'
    : 'terminalProcess';
  const panel = $(panelId);
  if (!panel) return;

  const line = document.createElement('div');

  // 自动为明显的错误行添加 error class（红色高亮）
  let finalClassName = className;
  if (!finalClassName && (
    /^\s*✗/.test(text) ||
    text.includes('格式错误:') ||
    text.includes('💡 原因:') ||
    /^\s*❌/.test(text)
  )) {
    finalClassName = 'error';
  }
  line.className = 'line' + (finalClassName ? ' ' + finalClassName : '');

  const trimmed = text.trim();
  let html = '';

  // ── Markdown 渲染 ────────────────────────────────────────────────

  // 分隔线
  if (trimmed === '---' || trimmed === '***' || trimmed === '___') {
    line.className += ' md-hr';
    html = '<hr>';
    line.innerHTML = html;
    panel.appendChild(line);
    panel.scrollTop = panel.scrollHeight;
    return;
  }

  // 代码块边界
  if (trimmed.startsWith('```')) {
    const lang = trimmed.substring(3).trim();
    if (mdState.inCodeBlock) {
      mdState.inCodeBlock = false;
      mdState.codeBlockLang = '';
      line.className += ' md-code-block-end';
      html = '</code></pre></div>';
    } else {
      mdState.inCodeBlock = true;
      mdState.codeBlockLang = lang;
      line.className += ' md-code-block-start';
      html = '<div class="md-code-block' + (lang ? ' md-code-lang-' + escapeHtml(lang) : '') + '"><pre class="md-code-pre">';
    }
    line.innerHTML = html;
    panel.appendChild(line);
    panel.scrollTop = panel.scrollHeight;
    return;
  }

  // 代码块内部：原样输出（保留空格和格式），强制路由到扫描报告
  if (mdState.inCodeBlock) {
    const resultPanel = $('terminalResult');
    if (!resultPanel) return;
    html = escapeHtml(text);
    line.className += ' md-code-line';
    line.innerHTML = html;
    resultPanel.appendChild(line);
    resultPanel.scrollTop = resultPanel.scrollHeight;
    return;
  }

  // Markdown 标题
  if (trimmed.startsWith('### ')) {
    line.className += ' md-h3';
    html = '<h3>' + renderMarkdownInline(trimmed.substring(4)) + '</h3>';
    line.innerHTML = html;
    panel.appendChild(line);
    panel.scrollTop = panel.scrollHeight;
    return;
  }
  if (trimmed.startsWith('## ')) {
    line.className += ' md-h2';
    html = '<h2>' + renderMarkdownInline(trimmed.substring(3)) + '</h2>';
    line.innerHTML = html;
    panel.appendChild(line);
    panel.scrollTop = panel.scrollHeight;
    return;
  }
  if (trimmed.startsWith('# ')) {
    line.className += ' md-h1';
    html = '<h1>' + renderMarkdownInline(trimmed.substring(2)) + '</h1>';
    line.innerHTML = html;
    panel.appendChild(line);
    panel.scrollTop = panel.scrollHeight;
    return;
  }

  // 列表项
  if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
    line.className += ' md-list-item';
    html = '<span class="md-list-bullet">•</span> ' + renderMarkdownInline(trimmed.substring(2));
    line.innerHTML = html;
    panel.appendChild(line);
    panel.scrollTop = panel.scrollHeight;
    return;
  }

  // 普通行：先尝试 Markdown 行内渲染，再处理 ANSI 颜色
  html = renderMarkdownInline(text);

  // 如果行内渲染没有改变内容（没有 Markdown 语法），做 ANSI 转换
  if (html === escapeHtml(text)) {
    html = html
      .replace(/\x1b\[(?:0;)?31m/g, '<span class="ansi-red">')
      .replace(/\x1b\[(?:0;)?32m/g, '<span class="ansi-green">')
      .replace(/\x1b\[(?:0;)?33m/g, '<span class="ansi-yellow">')
      .replace(/\x1b\[(?:0;)?34m/g, '<span class="ansi-blue">')
      .replace(/\x1b\[(?:0;)?35m/g, '<span class="ansi-magenta">')
      .replace(/\x1b\[(?:0;)?36m/g, '<span class="ansi-cyan">')
      .replace(/\x1b\[1;33m/g, '<span class="ansi-yellow ansi-bold">')
      .replace(/\x1b\[1m/g, '<span class="ansi-bold">')
      .replace(/\x1b\[0m/g, '</span>');

    // 关闭未闭合的标签
    const openSpans = (html.match(/<span/g) || []).length;
    const closeSpans = (html.match(/<\/span>/g) || []).length;
    for (let i = 0; i < openSpans - closeSpans; i++) {
      html += '</span>';
    }
  }

  line.innerHTML = html;
  panel.appendChild(line);
  panel.scrollTop = panel.scrollHeight;
}

function clearAllPanels() {
  ['terminalProcess', 'terminalResult', 'terminalFail'].forEach(id => {
    const el = $(id);
    if (el) el.innerHTML = '';
  });
  // 重置 Markdown 状态
  mdState = { inCodeBlock: false, codeBlockLang: '' };
  const empty = $('emptyState');
  if (empty) empty.classList.remove('hidden');
  const legend = $('reviewLegend');
  if (legend) legend.classList.remove('visible');
}

function hideEmptyState() {
  const empty = $('emptyState');
  if (empty) empty.classList.add('hidden');
  const legend = $('reviewLegend');
  if (legend) legend.classList.add('visible');
}

function updateStatus(status, detail) {
  const dot = $('statusDot');
  const text = $('statusText');
  const detailEl = $('statusDetail');

  dot.className = 'status-dot ' + status;
  text.textContent = status === 'running' ? '运行中' : status === 'success' ? '成功' : status === 'failed' ? '失败' : '就绪';
  detailEl.textContent = detail;
}

// ── 历史记录 ────────────────────────────────────────────────────────
async function loadHistory() {
  try {
    const res = await fetch('/api/history');
    const data = await res.json();
    state.history = data.history || [];
    renderHistory();
  } catch (err) {
    console.error('加载历史失败:', err);
  }
}

function renderHistory() {
  const tbody = $('historyBody');
  tbody.innerHTML = '';

  if (state.history.length === 0) {
    const tr = document.createElement('tr');
    tr.innerHTML = `<td colspan="5" style="text-align: center; padding: 2rem; color: var(--text-secondary);">暂无执行记录</td>`;
    tbody.appendChild(tr);
    return;
  }

  state.history.forEach(h => {
    const tr = document.createElement('tr');
    const statusClass = h.status === 'success' ? 'badge-success' : h.status === 'failed' ? 'badge-failed' : 'badge-running';
    const statusIcon = h.status === 'success' ? '✅' : h.status === 'failed' ? '❌' : '⏳';

    tr.innerHTML = `
      <td>${escapeHtml(h.start_time)}</td>
      <td>${h.script_icon} ${escapeHtml(h.script_name)}</td>
      <td><span class="badge ${statusClass}">${statusIcon} ${h.status}</span></td>
      <td>${h.elapsed ? h.elapsed + 's' : '-'}</td>
      <td>
        <button class="action-btn" data-id="${h.id}">查看输出</button>
      </td>
    `;

    tr.querySelector('.action-btn').addEventListener('click', () => showHistoryDetail(h));
    tbody.appendChild(tr);
  });
}

function showHistoryDetail(record) {
  $('modalTitle').textContent = `${record.script_icon} ${record.script_name} - 输出详情`;
  $('modalContent').textContent = record.output?.join('\n') || '无输出';
  $('modalOverlay').classList.add('active');
}

// ── 事件绑定 ────────────────────────────────────────────────────────
function bindEvents() {
  // 搜索
  $('searchInput').addEventListener('input', e => {
    renderScriptList(e.target.value);
  });

  // 严重级别过滤
  document.querySelectorAll('.severity-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.severity-btn').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      runSeverityFilter(btn.dataset.severity);
    });
  });

  // 运行
  $('runBtn').addEventListener('click', runScript);

  // 清空
  $('clearBtn').addEventListener('click', () => {
    clearAllPanels();
    updateStatus('ready', '就绪');
  });

  // 视图切换
  document.querySelectorAll('.nav-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      const view = btn.dataset.view;
      state.view = view;

      document.querySelectorAll('.nav-btn').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');

      $('dashboardView').style.display = view === 'dashboard' ? '' : 'none';
      $('historyView').style.display = view === 'history' ? '' : 'none';
      $('scheduleView').style.display = view === 'schedule' ? '' : 'none';

      if (view === 'history') {
        loadHistory();
      } else if (view === 'schedule') {
        loadSchedules();
      }
    });
  });

  // 通知配置保存
  if ($('notifySaveBtn')) {
    $('notifySaveBtn').addEventListener('click', saveNotifyConfig);
  }

  // Ctrl+C 终止运行
  document.addEventListener('keydown', e => {
    if (e.ctrlKey && e.key === 'c' && state.running) {
      e.preventDefault();
      killRunning();
    }
  });

  // 弹窗关闭
  $('closeModal').addEventListener('click', () => {
    $('modalOverlay').classList.remove('active');
  });
  $('modalOverlay').addEventListener('click', e => {
    if (e.target === $('modalOverlay')) {
      $('modalOverlay').classList.remove('active');
    }
  });

  // ESC 关闭弹窗
  document.addEventListener('keydown', e => {
    if (e.key === 'Escape') {
      $('modalOverlay').classList.remove('active');
    }
  });

  // 定时任务
  if ($('addScheduleBtn')) {
    $('addScheduleBtn').addEventListener('click', showScheduleForm);
  }
  if ($('cancelScheduleBtn')) {
    $('cancelScheduleBtn').addEventListener('click', hideScheduleForm);
  }
  if ($('saveScheduleBtn')) {
    $('saveScheduleBtn').addEventListener('click', saveSchedule);
  }
  if ($('scheduleMode')) {
    $('scheduleMode').addEventListener('change', updateScheduleFormMode);
  }
}

// ── 工具函数 ────────────────────────────────────────────────────────
function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

async function killRunning() {
  if (!state.running) return;
  appendLine('', '', 'process');
  appendLine('⚠️ 收到 Ctrl+C，尝试终止...', 'warn', 'process');
  try {
    await fetch('/api/kill', { method: 'POST' });
  } catch (err) {
    appendLine('❌ 终止请求失败', 'error', 'fail');
  }
}

// ── 定时任务 ──────────────────────────────────────────────────────────
let schedules = [];
let editingScheduleId = null;

async function loadSchedules() {
  try {
    const res = await fetch('/api/schedule');
    const data = await res.json();
    schedules = data.tasks || [];
    renderSchedules();
  } catch (err) {
    console.error('加载定时任务失败:', err);
  }
}

function renderSchedules() {
  const container = $('scheduleList');
  if (!container) return;

  if (schedules.length === 0) {
    container.innerHTML = `
      <div class="empty-state">
        <div class="icon">⏰</div>
        <p>暂无定时任务，点击「新建任务」创建一个</p>
      </div>
    `;
    return;
  }

  container.innerHTML = '';
  schedules.forEach(task => {
    const card = document.createElement('div');
    card.className = 'schedule-card' + (task.enabled ? '' : ' disabled');
    const modeText = task.severity
      ? `按级别: ${task.severity === 'critical' ? '5星' : task.severity === 'high' ? '4星+' : task.severity === 'medium' ? '3星+' : '全部'}`
      : `指定脚本 (${(task.scriptIds || []).length}个)`;
    const lastRunText = task.lastRun
      ? new Date(task.lastRun).toLocaleString('zh-CN', { month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit' })
      : '从未';
    card.innerHTML = `
      <div class="schedule-info">
        <div class="schedule-name">${escapeHtml(task.name)} ${task.enabled ? '🟢' : '⚪'}</div>
        <div class="schedule-meta">
          <span>📋 ${modeText}</span>
          <span>⏰ ${escapeHtml(task.cron)}</span>
          <span>🔔 ${task.notify ? '通知开启' : '通知关闭'}</span>
          <span>🕐 上次: ${lastRunText}</span>
        </div>
      </div>
      <div class="schedule-actions">
        <button data-id="${task.id}" class="btn-edit">编辑</button>
        <button data-id="${task.id}" class="btn-danger btn-delete">删除</button>
      </div>
    `;
    card.querySelector('.btn-edit').addEventListener('click', () => editSchedule(task.id));
    card.querySelector('.btn-delete').addEventListener('click', () => deleteSchedule(task.id));
    container.appendChild(card);
  });
}

function showScheduleForm() {
  $('scheduleFormPanel').style.display = '';
  $('scheduleList').style.display = 'none';
  $('addScheduleBtn').style.display = 'none';
  editingScheduleId = null;
  // 重置表单
  $('scheduleName').value = '';
  $('scheduleMode').value = 'severity';
  $('scheduleSeverity').value = 'critical';
  $('scheduleCron').value = '0 9 * * *';
  $('scheduleNotify').checked = false;
  $('scheduleEnabled').checked = true;
  updateScheduleFormMode();
  renderScheduleScriptSelect();
}

function hideScheduleForm() {
  $('scheduleFormPanel').style.display = 'none';
  $('scheduleList').style.display = '';
  $('addScheduleBtn').style.display = '';
  editingScheduleId = null;
}

function updateScheduleFormMode() {
  const mode = $('scheduleMode').value;
  $('scheduleSeverityGroup').style.display = mode === 'severity' ? '' : 'none';
  $('scheduleScriptsGroup').style.display = mode === 'scripts' ? '' : 'none';
}

function renderScheduleScriptSelect() {
  const container = $('scheduleScriptSelect');
  if (!container) return;
  container.innerHTML = '';
  const allScripts = [];
  Object.values(state.categories).forEach(cat => allScripts.push(...cat.scripts));
  allScripts.forEach(script => {
    const row = document.createElement('label');
    row.className = 'script-checkbox';
    row.innerHTML = `
      <input type="checkbox" value="${script.id}" class="schedule-script-cb">
      <span>${script.icon} ${escapeHtml(script.name)} ${priorityBadge(script.priority)}</span>
    `;
    container.appendChild(row);
  });
}

async function saveSchedule() {
  const mode = $('scheduleMode').value;
  const scriptIds = mode === 'scripts'
    ? Array.from(document.querySelectorAll('.schedule-script-cb:checked')).map(cb => cb.value)
    : [];
  const task = {
    id: editingScheduleId || undefined,
    name: $('scheduleName').value.trim() || '未命名任务',
    severity: mode === 'severity' ? $('scheduleSeverity').value : '',
    scriptIds,
    cron: $('scheduleCron').value.trim(),
    enabled: $('scheduleEnabled').checked,
    notify: $('scheduleNotify').checked,
  };
  try {
    const res = await fetch('/api/schedule', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(task)
    });
    const data = await res.json();
    if (data.success) {
      showToast('定时任务已保存', 'success');
      hideScheduleForm();
      loadSchedules();
    } else {
      showToast('保存失败', 'error');
    }
  } catch (err) {
    showToast('保存失败: ' + err.message, 'error');
  }
}

function editSchedule(id) {
  const task = schedules.find(t => t.id === id);
  if (!task) return;
  editingScheduleId = id;
  $('scheduleName').value = task.name;
  $('scheduleMode').value = task.severity ? 'severity' : 'scripts';
  $('scheduleSeverity').value = task.severity || 'critical';
  $('scheduleCron').value = task.cron;
  $('scheduleNotify').checked = task.notify;
  $('scheduleEnabled').checked = task.enabled;
  updateScheduleFormMode();
  renderScheduleScriptSelect();
  // 选中已有脚本
  if (task.scriptIds) {
    document.querySelectorAll('.schedule-script-cb').forEach(cb => {
      cb.checked = task.scriptIds.includes(cb.value);
    });
  }
  $('scheduleFormPanel').style.display = '';
  $('scheduleList').style.display = 'none';
  $('addScheduleBtn').style.display = 'none';
}

async function deleteSchedule(id) {
  if (!confirm('确定要删除这个定时任务吗？')) return;
  try {
    const res = await fetch('/api/schedule', {
      method: 'DELETE',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ id })
    });
    const data = await res.json();
    if (data.success) {
      showToast('定时任务已删除', 'success');
      loadSchedules();
    }
  } catch (err) {
    showToast('删除失败: ' + err.message, 'error');
  }
}

function showToast(message, type = 'info') {
  // 简单的 toast 提示
  const toast = document.createElement('div');
  toast.style.cssText = `
    position: fixed;
    top: 20px;
    right: 20px;
    padding: 12px 20px;
    border-radius: 8px;
    background: ${type === 'error' ? 'var(--accent-red)' : 'var(--accent-blue)'};
    color: white;
    font-size: 0.875rem;
    z-index: 1000;
    animation: slideIn 0.3s ease;
  `;
  toast.textContent = message;
  document.body.appendChild(toast);
  setTimeout(() => {
    toast.style.animation = 'slideOut 0.3s ease';
    setTimeout(() => toast.remove(), 300);
  }, 3000);
}

// ── 启动 ────────────────────────────────────────────────────────────
init();
