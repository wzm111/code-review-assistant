#!/usr/bin/env python3
"""
Code Review Assistant Dashboard Server
========================================
零依赖的轻量级 Web 服务，提供脚本的可视化执行界面。

使用方式:
    python3 server.py              # 默认端口 8080
    python3 server.py --port 9000  # 指定端口
    bash launcher.sh               # 一键启动

API:
    GET  /api/scripts              列出所有可用脚本
    POST /api/run                  运行脚本（SSE 流式输出）
    GET  /api/history              获取历史记录列表
    GET  /api/history/<id>         获取单次运行详情
"""

import argparse
import html
import json
import os
import re
import subprocess
import sys
import threading
import time
import uuid
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import parse_qs, urlparse

# ── 配置 ──────────────────────────────────────────────────────────────
SCRIPT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scripts")
HISTORY = []           # 运行历史（内存存储，重启清空）
HISTORY_LOCK = threading.Lock()
MAX_HISTORY = 50       # 最多保留 50 条记录


# ── 脚本元数据（从脚本文件名和简单注释提取）────────────────────────────
SCRIPT_META = {
    "scan-secrets.sh": {
        "name": "密钥扫描",
        "desc": "扫描代码中的敏感信息泄露（API Key、Token、密码等）",
        "icon": "🔐",
        "args": [{"name": "path", "default": ".", "desc": "扫描路径"},
                 {"name": "severity", "default": "critical", "desc": "严重级别", "options": ["critical", "high", "medium", "all"]}],
        "category": "security"
    },
    "scan-deps.sh": {
        "name": "依赖漏洞扫描",
        "desc": "检测 package.json、requirements.txt 等依赖中的已知漏洞",
        "icon": "📦",
        "args": [{"name": "path", "default": ".", "desc": "扫描路径"}],
        "category": "security"
    },
    "code-smell.sh": {
        "name": "代码异味检测",
        "desc": "检测代码中的坏味道（过长函数、重复代码、魔法数字等）",
        "icon": "👃",
        "args": [{"name": "path", "default": ".", "desc": "扫描路径"}],
        "category": "quality"
    },
    "naming-convention.sh": {
        "name": "命名规范检查",
        "desc": "检查变量、函数、类命名是否符合规范",
        "icon": "📝",
        "args": [{"name": "path", "default": ".", "desc": "扫描路径"}],
        "category": "quality"
    },
    "lint-check.sh": {
        "name": "代码规范检查",
        "desc": "运行 ESLint、Stylelint 等工具检查代码规范",
        "icon": "📏",
        "args": [{"name": "path", "default": ".", "desc": "扫描路径"}],
        "category": "quality"
    },
    "severity-gate.sh": {
        "name": "质量门禁",
        "desc": "综合评分，判断是否允许合并（失败会返回非 0）",
        "icon": "🚦",
        "args": [{"name": "path", "default": ".", "desc": "扫描路径"},
                 {"name": "severity", "default": "high", "desc": "门禁阈值", "options": ["critical", "high", "medium", "all"]}],
        "category": "gate"
    },
    "complexity-analysis.sh": {
        "name": "复杂度分析",
        "desc": "计算圈复杂度，识别需要重构的复杂函数",
        "icon": "📊",
        "args": [{"name": "path", "default": ".", "desc": "扫描路径"}],
        "category": "quality"
    },
    "test-coverage.sh": {
        "name": "测试覆盖率",
        "desc": "检查测试覆盖率是否达标",
        "icon": "🧪",
        "args": [{"name": "path", "default": ".", "desc": "扫描路径"}],
        "category": "test"
    },
    "type-safety.sh": {
        "name": "类型安全检测",
        "desc": "检查 TypeScript 类型定义是否完整",
        "icon": "🔒",
        "args": [{"name": "path", "default": ".", "desc": "扫描路径"}],
        "category": "quality"
    },
    "resource-leak.sh": {
        "name": "资源泄漏检测",
        "desc": "检测未关闭的文件、连接、定时器等资源泄漏",
        "icon": "💧",
        "args": [{"name": "path", "default": ".", "desc": "扫描路径"}],
        "category": "quality"
    },
    "perf-benchmark.sh": {
        "name": "性能基准测试",
        "desc": "运行性能基准测试并与历史数据对比",
        "icon": "⚡",
        "args": [{"name": "path", "default": ".", "desc": "扫描路径"}],
        "category": "perf"
    },
    "a11y-check.sh": {
        "name": "无障碍检查",
        "desc": "检查前端代码的无障碍访问（a11y）合规性",
        "icon": "♿",
        "args": [{"name": "path", "default": ".", "desc": "扫描路径"}],
        "category": "frontend"
    },
    "auto-fix.sh": {
        "name": "自动修复",
        "desc": "自动应用安全修复建议（建议先在分支上试用）",
        "icon": "🔧",
        "args": [{"name": "path", "default": ".", "desc": "扫描路径"}],
        "category": "tool"
    },
    "review-history.sh": {
        "name": "审查历史",
        "desc": "查看历史审查记录和趋势分析",
        "icon": "📈",
        "args": [{"name": "path", "default": ".", "desc": "扫描路径"}],
        "category": "tool"
    },
    "pr-context.sh": {
        "name": "PR 上下文分析",
        "desc": "分析 PR 的变更范围和影响面",
        "icon": "🔍",
        "args": [{"name": "path", "default": ".", "desc": "扫描路径"}],
        "category": "tool"
    },
}


def get_available_scripts():
    """扫描 scripts 目录，返回可用的脚本列表（带元数据）。"""
    scripts = []
    if not os.path.isdir(SCRIPT_DIR):
        return scripts

    for fname in sorted(os.listdir(SCRIPT_DIR)):
        if fname.endswith(".sh") and os.path.isfile(os.path.join(SCRIPT_DIR, fname)):
            meta = SCRIPT_META.get(fname, {
                "name": fname.replace(".sh", ""),
                "desc": "",
                "icon": "📄",
                "args": [{"name": "path", "default": ".", "desc": "扫描路径"}],
                "category": "other"
            })
            scripts.append({
                "id": fname.replace(".sh", ""),
                "file": fname,
                **meta
            })
    return scripts


# ── 请求处理器 ────────────────────────────────────────────────────────
class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        # 简化日志输出
        print(f"[{time.strftime('%H:%M:%S')}] {args[0]}")

    def _send_json(self, data, status=200):
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def _send_sse_start(self):
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream; charset=utf-8")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "keep-alive")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()

    def _sse(self, event, data):
        payload = json.dumps(data, ensure_ascii=False)
        self.wfile.write(f"event: {event}\ndata: {payload}\n\n".encode("utf-8"))
        self.wfile.flush()

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path

        # ── 静态文件 ─────────────────────────────────────────────
        if path == "/" or path == "/index.html":
            self._serve_file("index.html", "text/html; charset=utf-8")
            return
        if path.startswith("/static/"):
            fname = path[1:]  # remove leading /
            ctype = "text/css" if fname.endswith(".css") else "application/javascript"
            self._serve_file(fname, ctype + "; charset=utf-8")
            return

        # ── API: 脚本列表 ────────────────────────────────────────
        if path == "/api/scripts":
            scripts = get_available_scripts()
            # 按 category 分组
            categories = {}
            for s in scripts:
                cat = s["category"]
                if cat not in categories:
                    categories[cat] = {"label": self._cat_label(cat), "scripts": []}
                categories[cat]["scripts"].append(s)
            self._send_json({"scripts": scripts, "categories": categories})
            return

        # ── API: 历史记录 ────────────────────────────────────────
        if path == "/api/history":
            with HISTORY_LOCK:
                self._send_json({"history": list(reversed(HISTORY))})
            return

        # ── API: 单次历史详情 ────────────────────────────────────
        m = re.match(r"^/api/history/([^/]+)$", path)
        if m:
            hid = m.group(1)
            with HISTORY_LOCK:
                for h in HISTORY:
                    if h["id"] == hid:
                        self._send_json(h)
                        return
            self._send_json({"error": "未找到记录"}, 404)
            return

        self._send_json({"error": "Not Found"}, 404)

    def do_POST(self):
        parsed = urlparse(self.path)
        path = parsed.path

        # ── API: 运行脚本 ────────────────────────────────────────
        if path == "/api/run":
            self._handle_run()
            return

        self._send_json({"error": "Not Found"}, 404)

    def _serve_file(self, relpath, ctype):
        fpath = os.path.join(os.path.dirname(os.path.abspath(__file__)), relpath)
        if not os.path.isfile(fpath):
            self._send_json({"error": "Not Found"}, 404)
            return
        with open(fpath, "rb") as f:
            data = f.read()
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _cat_label(self, cat):
        mapping = {
            "security": "🔐 安全扫描",
            "quality": "✨ 代码质量",
            "gate": "🚦 质量门禁",
            "test": "🧪 测试相关",
            "perf": "⚡ 性能分析",
            "frontend": "🎨 前端专用",
            "tool": "🛠️ 工具脚本",
            "other": "📄 其他"
        }
        return mapping.get(cat, cat)

    def _handle_run(self):
        # 读取请求体
        cl = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(cl).decode("utf-8")
        try:
            req = json.loads(body)
        except json.JSONDecodeError:
            self._send_json({"error": "无效的 JSON"}, 400)
            return

        script_id = req.get("script", "")
        args = req.get("args", {})

        # 查找脚本
        scripts = get_available_scripts()
        target = next((s for s in scripts if s["id"] == script_id), None)
        if not target:
            self._send_json({"error": f"脚本不存在: {script_id}"}, 404)
            return

        script_path = os.path.join(SCRIPT_DIR, target["file"])
        if not os.path.isfile(script_path):
            self._send_json({"error": f"脚本文件不存在: {target['file']}"}, 404)
            return

        # 构建命令行参数
        cmd = ["bash", script_path]
        for arg_def in target.get("args", []):
            val = args.get(arg_def["name"], arg_def.get("default", ""))
            if val:
                cmd.append(str(val))

        run_id = str(uuid.uuid4())[:8]
        start_time = time.time()

        # 记录到历史
        record = {
            "id": run_id,
            "script": script_id,
            "script_name": target["name"],
            "script_icon": target["icon"],
            "command": " ".join(cmd),
            "start_time": time.strftime("%Y-%m-%d %H:%M:%S"),
            "status": "running",
            "output": []
        }
        with HISTORY_LOCK:
            HISTORY.append(record)
            if len(HISTORY) > MAX_HISTORY:
                HISTORY.pop(0)

        # SSE 流式输出
        self._send_sse_start()
        self._sse("start", {"id": run_id, "command": " ".join(cmd), "script": target["name"]})

        # 执行脚本
        proc = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            cwd=os.path.dirname(os.path.abspath(__file__))
        )

        full_output = []
        try:
            for line in proc.stdout:
                clean = line.rstrip("\n\r")
                full_output.append(clean)
                self._sse("output", {"text": clean})
        except (BrokenPipeError, ConnectionResetError):
            pass

        proc.wait()
        elapsed = round(time.time() - start_time, 2)
        exit_code = proc.returncode

        # 更新记录
        with HISTORY_LOCK:
            for h in HISTORY:
                if h["id"] == run_id:
                    h["status"] = "success" if exit_code == 0 else "failed"
                    h["exit_code"] = exit_code
                    h["elapsed"] = elapsed
                    h["output"] = full_output
                    break

        self._sse("end", {
            "id": run_id,
            "exit_code": exit_code,
            "status": "success" if exit_code == 0 else "failed",
            "elapsed": elapsed
        })


# ── 入口 ──────────────────────────────────────────────────────────────
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Code Review Assistant Dashboard")
    parser.add_argument("--port", type=int, default=8080, help="服务端口（默认 8080）")
    parser.add_argument("--host", default="127.0.0.1", help="绑定地址（默认 127.0.0.1）")
    args = parser.parse_args()

    server = HTTPServer((args.host, args.port), Handler)
    print(f"""
╔══════════════════════════════════════════════════════════════╗
║     🔍 Code Review Assistant Dashboard                       ║
║                                                              ║
║     本地地址: http://{args.host}:{args.port:<5}                        ║
║                                                              ║
║     按 Ctrl+C 停止服务                                       ║
╚══════════════════════════════════════════════════════════════╝
""")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n👋 服务已停止")
        sys.exit(0)
