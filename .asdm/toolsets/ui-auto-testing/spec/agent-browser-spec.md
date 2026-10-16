# agent-browser 工具集转移规格说明

> 目标：将 `agent-browser` 的浏览器自动化能力转移到当前技能体系中，作为录制功能的新实现方案。

## 一、背景

当前技能使用 AppleScript + JavaScript 实现页面操作与录制，存在以下局限：

| 维度 | 现状（AppleScript） | 目标（agent-browser） |
| --- | --- | --- |
| 平台 | 仅 macOS | 跨平台（macOS/Linux/Windows） |
| 浏览器 | 依赖 Chrome AppleScript 接口 | 通过 CDP 直连浏览器 |
| 录制能力 | DOM 事件监听注入 | 原生事件 + 网络拦截 + 快照 |
| 元素定位 | CSS/XPath | CSS/XPath/@ref（快照引用） |
| 输出格式 | 自定义 JSON | 结构化 JSON + 快照 + 录屏 |

## 二、平台兼容性

agent-browser 提供原生 Rust 二进制，支持以下平台（依据官方 README）：

| 平台 | 架构 | 支持情况 |
| --- | --- | --- |
| macOS | ARM64（Apple Silicon）/ x64（Intel） | ✅ 原生支持 |
| Linux | ARM64 / x64 | ✅ 原生支持 |
| Windows | x64 | ✅ 原生支持 |

### 2.1 各平台安装方式

```bash
npm install -g agent-browser        # npm（全平台通用，推荐）
brew install agent-browser          # macOS Homebrew
cargo install agent-browser         # Cargo（Rust）
agent-browser install               # 首次使用需下载 Chrome for Testing
agent-browser install --with-deps   # Linux 额外安装系统依赖
```

### 2.2 Windows 特别注意事项

1. **Chrome 配置文件锁定**：使用 `--profile <名称>` 复用 Chrome 登录态时，需先关闭正在运行的 Chrome（部分配置文件可能被锁定）
2. **WebGPU 截图限制**：WebGPU 页面在无头模式下截图会捕获为黑色（上游限制），需在已登录的桌面会话中使用 `--headed` 模式运行

### 2.3 平台差异点

| 能力 | macOS | Linux | Windows |
| --- | --- | --- | --- |
| 核心命令（open/click/snapshot 等） | ✅ | ✅ | ✅ |
| iOS 模拟器（`-p ios`） | ✅（需 Xcode + Appium） | ❌ | ❌ |
| AppleScript 降级路径 | ✅ | ❌ | ❌ |

> 说明：转移后 Windows/Linux 不可用时无 AppleScript 降级方案，依赖检测失败应直接报错提示安装 agent-browser。

## 三、转移范围

### 3.1 需要转移的命令

| 原命令（AppleScript） | agent-browser 对应 | 说明 |
| --- | --- | --- |
| 打开页面 | `agent-browser open <url>` | 导航到 URL |
| 点击元素 | `agent-browser click <sel>` | 支持 CSS 选择器或 @ref |
| 输入文本 | `agent-browser fill <sel> <text>` | 清空后填充 |
| 获取文本 | `agent-browser get text <sel>` | 提取元素文本 |
| 截图 | `agent-browser screenshot [path]` | 页面截图 |
| 快照 | `agent-browser snapshot` | 可访问性树（含 @ref） |
| 执行 JS | `agent-browser eval <js>` | 页面上下文执行 |
| 等待元素 | `agent-browser wait <sel>` | 元素出现等待 |
| 网络拦截 | `agent-browser network route` | 请求 mock/阻断 |
| 录制视频 | `agent-browser record start/stop` | 原生录屏（WebM） |

### 3.2 不转移的部分

- AppleScript 特有的窗口管理逻辑（activate、window bounds）
- 与 macOS 系统事件相关的辅助函数

## 四、转移规则

1. **选择器兼容**：优先使用 `@ref`（快照引用），回退到 CSS 选择器
2. **录制数据格式**：保持现有 JSON 结构，新增 `source: "agent-browser"` 字段
3. **错误处理**：agent-browser 命令失败时，macOS 下降级到原有 AppleScript 路径；Windows/Linux 无降级方案，直接报错
4. **依赖检测**：执行前检查 `agent-browser` 是否可用（macOS/Linux 用 `which agent-browser`，Windows 用 `where agent-browser`）

---

## 五、agent-browser 命令说明与示例

> 以下命令说明基于 `agent-browser --help` 实际输出整理，与 CLI 版本保持一致。

### 5.1 核心命令（Core Commands）

| 命令 | 说明 |
| --- | --- |
| `open <url>` | 导航到指定 URL |
| `click <sel>` | 点击元素（支持 CSS 选择器或 snapshot 返回的 `@ref`） |
| `dblclick <sel>` | 双击元素 |
| `type <sel> <text>` | 向元素输入文本（逐字符） |
| `fill <sel> <text>` | 清空后填充文本 |
| `press <key>` | 按键（Enter、Tab、Control+a 等） |
| `keyboard type <text>` | 以真实按键输入文本（无需选择器） |
| `keyboard inserttext <text>` | 直接插入文本（不触发按键事件） |
| `hover <sel>` | 悬停元素 |
| `focus <sel>` | 聚焦元素 |
| `check <sel>` / `uncheck <sel>` | 勾选 / 取消勾选复选框 |
| `select <sel> <val...>` | 选择下拉框选项 |
| `drag <src> <dst>` | 拖拽元素 |
| `upload <sel> <files...>` | 上传文件 |
| `download <sel> <path>` | 点击元素下载文件到指定路径 |
| `scroll <dir> [px]` | 滚动页面（up/down/left/right） |
| `scrollintoview <sel>` | 滚动使元素可见 |
| `wait <sel\|ms>` | 等待元素出现或等待指定毫秒 |
| `screenshot [path]` | 截图 |
| `pdf <path>` | 保存页面为 PDF |
| `snapshot` | 输出可访问性树（含 `@ref`，供 AI 使用） |
| `eval <js>` | 执行 JavaScript |
| `connect <port\|url>` | 通过 CDP 连接已有浏览器 |
| `close [--all]` | 关闭浏览器（`--all` 关闭所有会话） |

```bash
agent-browser open example.com
agent-browser snapshot -i                     # 只列出可交互元素
agent-browser click @e2                       # 点击 snapshot 中的 @e2 元素
agent-browser fill @e3 "test@example.com"
agent-browser press Enter
agent-browser wait 2000                       # 等待 2 秒
agent-browser wait "#result"                  # 等待元素出现
```

### 5.2 导航命令（Navigation）

| 命令 | 说明 |
| --- | --- |
| `back` | 后退 |
| `forward` | 前进 |
| `reload` | 刷新页面 |

### 5.3 信息获取（Get Info）

格式：`agent-browser get <what> [selector]`

可选值：`text`、`html`、`value`、`attr <name>`、`title`、`url`、`count`、`box`、`styles`、`cdp-url`

```bash
agent-browser get text @e1            # 获取元素文本
agent-browser get url                 # 获取当前 URL
agent-browser get attr href "a.link"  # 获取元素属性
agent-browser get count ".item"       # 统计匹配元素数量
```

### 5.4 状态检查（Check State）

格式：`agent-browser is <what> <selector>`

可选值：`visible`、`enabled`、`checked`

```bash
agent-browser is visible "#modal"
agent-browser is checked "#agree"
```

### 5.5 元素查找（Find Elements）

格式：`agent-browser find <locator> <value> <action> [text]`

定位方式：`role`、`text`、`label`、`placeholder`、`alt`、`title`、`testid`、`first`、`last`、`nth`

```bash
agent-browser find role button click --name Submit
agent-browser find text "登录" click
agent-browser find placeholder "请输入账号" fill "admin"
```

### 5.6 鼠标操作（Mouse）

格式：`agent-browser mouse <action> [args]`

动作：`move <x> <y>`、`down [btn]`、`up [btn]`、`wheel <dy> [dx]`

```bash
agent-browser mouse move 100 200
agent-browser mouse wheel 500         # 向下滚轮
```

### 5.7 浏览器设置（Browser Settings）

格式：`agent-browser set <setting> [value]`

可选值：`viewport <w> <h>`、`device <name>`、`geo <lat> <lng>`、`offline [on|off]`、`headers <json>`、`credentials <user> <pass>`、`media [dark|light] [reduced-motion]`

```bash
agent-browser set viewport 1920 1080
agent-browser set device "iPhone 15"
agent-browser set media dark
```

### 5.8 网络控制（Network）

| 命令 | 说明 |
| --- | --- |
| `network route <url> [--abort\|--body <json>] [--resource-type <csv>]` | 拦截请求（中止或 mock 响应） |
| `network unroute [url]` | 取消拦截 |
| `network requests [--clear] [--filter <pattern>]` | 查看网络请求 |
| `network har <start\|stop> [path]` | 录制 HAR 文件 |

```bash
agent-browser network route "**/api/user" --body '{"name":"mock"}'
agent-browser network requests --filter "api"
```

### 5.9 存储管理（Storage）

| 命令 | 说明 |
| --- | --- |
| `cookies [get\|set\|clear]` | 管理 Cookie（set 支持 `--url`、`--domain`、`--httpOnly`、`--secure`、`--sameSite`、`--expires` 等） |
| `cookies set --curl <file>` | 从文件导入 Cookie（自动识别 JSON/cURL/Cookie-header 格式） |
| `storage <local\|session>` | 管理 localStorage / sessionStorage |

```bash
agent-browser cookies get
agent-browser storage local get token
```

### 5.10 标签页（Tabs）

```bash
agent-browser tab new                # 新建标签页
agent-browser tab list               # 列出标签页
agent-browser tab 2                  # 切换到第 2 个标签页
agent-browser tab close              # 关闭当前标签页
```

### 5.11 对比（Diff）

```bash
agent-browser diff snapshot                  # 对比当前与上一次 snapshot
agent-browser diff screenshot --baseline     # 对比基线截图
agent-browser diff url <u1> <u2>             # 对比两个页面
```

### 5.12 调试（Debug）

| 命令 | 说明 |
| --- | --- |
| `trace start\|stop [path]` | 录制 Chrome DevTools trace |
| `profiler start\|stop [path]` | 录制性能 profile |
| `record start <path> [url]` / `record stop` | 录制页面视频（WebM） |
| `console [--clear]` | 查看控制台日志 |
| `errors [--clear]` | 查看页面错误 |
| `highlight <sel>` | 高亮元素 |
| `inspect` | 打开 Chrome DevTools |
| `clipboard <op> [text]` | 读写剪贴板（read/write/copy/paste） |

```bash
agent-browser console
agent-browser record start ./demo.webm https://example.com
agent-browser record stop
```

### 5.13 流式传输（Streaming）

```bash
agent-browser stream enable            # 开启运行时 WebSocket 流（自动选端口）
agent-browser stream status            # 查看流状态
agent-browser stream disable           # 关闭流
```

### 5.14 React 调试（需 `open --enable react-devtools`）

| 命令 | 说明 |
| --- | --- |
| `react tree` | 输出完整 React 组件树 |
| `react inspect <id>` | 查看单个 fiber 的 props/hooks/state/源码 |
| `react renders start` / `react renders stop [--json]` | 录制重渲染 |
| `react suspense [--only-dynamic] [--json]` | 遍历 Suspense 边界并输出分类报告 |

### 5.15 性能（Performance）

```bash
agent-browser vitals                   # 输出 Core Web Vitals（LCP/CLS/TTFB/FCP/INP）
agent-browser vitals --json
```

### 5.16 SPA 导航

```bash
agent-browser pushstate /dashboard     # SPA 客户端跳转（自动识别 Next.js 路由）
```

### 5.17 批量执行（Batch）

```bash
agent-browser batch "open example.com" "snapshot -i" "screenshot"
agent-browser batch --bail "open example.com" "click @e1"   # 出错即停止
```

### 5.18 认证仓库（Auth Vault）

```bash
agent-browser auth save mysite --url https://x.com/login --username u --password p
agent-browser auth login mysite        # 使用已存凭证自动登录
agent-browser auth list
agent-browser auth delete mysite
```

### 5.19 会话管理（Sessions）

```bash
agent-browser session                  # 显示当前会话名
agent-browser session list             # 列出活跃会话
agent-browser --session-name myapp open example.com   # 自动保存/恢复登录状态
```

### 5.20 AI 对话（Chat）

```bash
agent-browser chat "open google.com and search for cats"   # 单发指令
agent-browser chat                                          # 交互式 REPL
agent-browser -q chat "summarize this page"                # 静默模式（仅文本）
```

### 5.21 仪表盘与安装维护（Dashboard & Setup）

```bash
agent-browser dashboard start --port 4848   # 启动可观测性仪表盘
agent-browser dashboard stop
agent-browser install                       # 首次下载 Chrome
agent-browser upgrade                       # 升级到最新版
agent-browser doctor --fix                  # 诊断安装并清理过期文件
agent-browser profiles                      # 列出 Chrome 用户配置
```

### 5.22 snapshot 常用选项

| 选项 | 说明 |
| --- | --- |
| `-i, --interactive` | 只输出可交互元素 |
| `-c, --compact` | 移除空结构元素 |
| `-d, --depth <n>` | 限制树深度 |
| `-s, --selector <sel>` | 限定在某个 CSS 选择器范围内 |

### 5.23 全局常用选项

| 选项 | 说明 |
| --- | --- |
| `--session <name>` | 隔离会话（或环境变量 `AGENT_BROWSER_SESSION`） |
| `--profile <name\|path>` | 复用 Chrome 登录态 / 持久化自定义配置 |
| `--state <path>` | 从 JSON 文件加载 cookies + storage |
| `--auto-connect` | 连接正在运行的 Chrome（复用其登录态） |
| `--headers <json>` | 设置 HTTP 头（限定 URL 源，如 Authorization） |
| `--cdp <port>` | 通过 CDP 端口连接浏览器 |
| `--executable-path <path>` | 自定义浏览器可执行文件 |
| `--proxy <server>` / `--proxy-bypass <hosts>` | 代理设置（支持认证代理） |
| `--user-agent <ua>` | 自定义 User-Agent |
| `--args <args>` | 浏览器启动参数（如 `--no-sandbox`） |
| `--ignore-https-errors` | 忽略 HTTPS 证书错误 |
| `--json` | JSON 格式输出 |
| `--annotate` | 截图加编号标注（供视觉模型使用） |

```bash
agent-browser --cdp 9222 snapshot                       # 连接 CDP 端口
agent-browser --auto-connect snapshot                   # 自动发现运行中的 Chrome
agent-browser --profile Default open gmail.com          # 复用 Chrome 登录态
agent-browser --color-scheme dark open example.com      # 深色模式
```

### 5.24 命令链（Command Chaining）

浏览器通过 daemon 保持，可用 `&&` 在一次 shell 调用中串联命令：

```bash
agent-browser open example.com && agent-browser snapshot -i
agent-browser fill @e1 "user@example.com" && agent-browser fill @e2 "pass" && agent-browser click @e3
```

### 5.25 内置技能（Skills，供 AI 代理使用）

```bash
agent-browser skills list                # 列出可用技能
agent-browser skills get core            # 核心使用指南（概览 + 常见模式）
agent-browser skills get core --full     # 含完整命令参考和模板
agent-browser skills get <name>          # 加载专项技能（electron、slack 等）
```

> 建议 AI 代理优先执行 `agent-browser skills get core --full` 获取与 CLI 版本匹配的工作流模式、ref/选择器用法和可复制的示例，而非仅凭 flag 文档猜测命令。

---

## 附录：现有工具集对应关系

| 现有文件 | 转移后职责 |
| --- | --- |
| `frame_capture.py` | 保留，作为 DOM 树抓取的降级方案 |
| `frame_tree_cdp.py` | 保留，CDP 直连逻辑可参考 |
| `replay/*.sh` | 重写为 agent-browser 命令序列 |
| `web/*.html` | 录制结果预览页，格式不变 |
