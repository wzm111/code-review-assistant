# 🔍 Dashboard / 可视化执行面板

> 通过网页界面选择、配置并运行审查脚本，实时查看执行结果。

## 功能特性

- 🎨 **深色主题** — GitHub Dark 风格，长时间使用不刺眼
- ⚡ **实时输出** — SSE 流式推送，像终端一样实时看日志
- 🗂️ **脚本分类** — 按安全、质量、门禁等类别分组展示
- 🔍 **参数配置** — 可视化表单配置脚本参数（路径、严重级别等）
- 📜 **执行历史** — 记录最近 50 次运行，随时回看输出
- 🚀 **零依赖** — Node.js 或 Python 标准库即可运行

## 快速启动

### 方式一：一键启动（推荐）

```bash
# 在仓库根目录执行
bash dashboard/launcher.sh

# 指定端口
bash dashboard/launcher.sh 9000
```

启动器会自动检测环境：优先使用 **Node.js**（≥14），回退到 **Python3**。

### 方式二：Node.js（推荐）

```bash
cd dashboard
npm start              # 默认端口 8080
node server.js --port 9000 --host 0.0.0.0
```

### 方式三：Python

```bash
cd dashboard
python3 server.py              # 默认端口 8080
python3 server.py --port 9000
```

### 访问

打开浏览器访问：http://localhost:8080

## 使用说明

1. **选择脚本** — 左侧面板按分类列出所有脚本，点击选择
2. **配置参数** — 右侧面板自动显示该脚本的参数表单
3. **运行** — 点击「▶️ 运行脚本」，下方终端实时输出结果
4. **查看历史** — 顶部「📜 历史」标签页可查看过往执行记录

## 目录结构

```
dashboard/
├── server.js          # Node.js 后端（推荐，零外部依赖）
├── server.py          # Python 后端（备选，零外部依赖）
├── launcher.sh        # 自动检测启动脚本
├── package.json       # npm 配置
├── index.html         # 前端页面
├── static/
│   ├── style.css      # 样式（GitHub Dark 主题）
│   └── app.js         # 前端逻辑（原生 JS，无框架）
└── README.md          # 本文档
```

## 技术栈

| 层 | 技术 | 说明 |
|---|---|---|
| 后端 | Node.js `http` / Python `http.server` | 零外部依赖 |
| 通信 | SSE (Server-Sent Events) | 单向流式推送 |
| 前端 | 原生 HTML5 + CSS3 + ES6 | 无构建工具、无框架 |

## 常见问题

### Q: 端口被占用？

```bash
# 换个端口
bash dashboard/launcher.sh 9000
```

### Q: 没有安装 Node.js 或 Python？

```bash
# macOS
brew install node

# Ubuntu/Debian
sudo apt update && sudo apt install nodejs npm

# Windows
# 下载安装: https://nodejs.org
```

### Q: 局域网内其他设备访问？

```bash
# 绑定到所有接口
node server.js --host 0.0.0.0 --port 8080
```

然后其他设备通过 `http://你的IP:8080` 访问。

### Q: 脚本列表不显示？

确保 `dashboard/` 目录与 `scripts/` 目录在同一仓库根目录下：

```
code-review-assistant/
├── scripts/           # ← 脚本目录
├── dashboard/         # ← Dashboard 目录
└── ...
```
