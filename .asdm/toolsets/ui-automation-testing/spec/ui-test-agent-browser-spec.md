# agent-browser 脚本规范

## 概述

本规范定义了 agent-browser 测试脚本的代码标准。agent-browser 脚本是本工具集的**主产物**（方案 v1.1 客户要求），由 `/asdm-ui-test-design-generate` action 根据 Chrome Dev Tools Recorder 录制的 json 转换生成；Playwright 脚本为降级产物，规范见 `ui-test-script-spec.md`。

脚本形式为自包含的 bash 脚本（`.sh`），逐行调用 `agent-browser` CLI 完成浏览器操作。

## 前置依赖

- `agent-browser` CLI 已安装并可用（`agent-browser --version`）
- Chrome / Chromium 浏览器已安装

## 脚本模板

```bash
#!/bin/bash
# ============================================================
# 测试场景: <场景编号> <场景名称>
# 来源录制: recordings/<模块>/<录制文件名>.json
# 生成时间: <YYYY-MM-DD HH:mm:ss>
# 脚本类型: agent-browser（主产物）
#
# 运行方式:
#   bash <脚本名>.sh
#   BROWSER=chromium bash <脚本名>.sh     # 指定浏览器（默认 chrome）
#   HEADED=0 bash <脚本名>.sh             # 无头模式（默认有头）
# ============================================================

set -e

# ==================== 配置 ====================
HEADED_FLAG="--headed"    # agent-browser 默认无头，需显式指定有头
DATA_DIR="$(cd "$(dirname "$0")" && pwd)/data"

# 从 data/ 文件读取环境配置（数据与脚本分离，见 ui-test-data-spec.md）
# 注意：Git Bash 下需使用 cygpath -m 将 Unix 路径转为 Windows 正斜杠路径
BASE_URL=$(node -e "console.log(require('$(cygpath -m ${DATA_DIR}/env.json)').baseUrl)" 2>/dev/null || echo "${BASE_URL}")

echo "[EXEC:START] <场景编号> | <场景名称>"

# ==================== 启动 ====================
echo "[CMD] agent-browser ${HEADED_FLAG} open \"${BASE_URL}<起始路径>\" --browser=${BROWSER}"
agent-browser ${HEADED_FLAG} open "${BASE_URL}<起始路径>" --browser=${BROWSER}
agent-browser set viewport <宽度> <高度>
sleep 2

# ==================== 步骤 ====================
# @step step-<n> | <操作类型>: <页面名> — <自然语言描述>
# Recorder selectors:
#   - aria/<文本描述>
#   - <CSS选择器>
#   - xpath/<xpath表达式>
echo "[STEP:step-<n>:START] <操作类型>: <自然语言描述>"
echo "  → <自然语言描述>"
agent-browser <命令> <参数>
sleep 0.5
echo "[STEP:step-<n>:OK]"

# ... 重复步骤块 ...

# ==================== 断言步骤 ====================
# @step assert-<n> | 断言: <页面名> — <断言描述>
# Recorder selectors:
#   - <录制中该断言的原始选择器>
echo "[STEP:assert-<n>:START] 断言: <断言描述>"
TEXT_CONTENT=$(agent-browser eval "document.body.innerText")
if ! echo "${TEXT_CONTENT}" | grep -q "<期望文本>"; then
  echo "❌ 断言失败: <断言描述>（期望：<期望文本>）"
  exit 1
fi
echo "✅ 断言通过: <断言描述>"
echo "[STEP:assert-<n>:OK]"

echo "✅ <场景编号> <场景名称> - 执行成功！"
echo "[EXEC:END] <场景编号> | 成功"
```

## 脚本格式要素

| 要素 | 说明 |
|------|------|
| `set -e` | 遇错即停，失败的步骤即失败点 |
| `# @step <stepId>` 注释 | 每个步骤的锚点：`# @step <stepId> \| <操作类型>: <页面名> — <自然语言描述>`。stepId 在同一脚本内唯一，供保鲜/执行自愈时定位步骤 |
| `# Recorder selectors:` 注释 | **紧跟在 `@step` 注释之后**，列出该步骤在录制 JSON 中的所有原始选择器（`selectors` 数组），以列表形式展示。用途：执行失败时 AI 可直接参考原始选择器备选方案进行自愈，无需回读录制文件 |
| `[STEP:<id>:START/OK]` 标记 | 执行日志标记，执行失败时从日志定位失败步骤 |
| 自然语言描述 | 每个 `@step` 注释必须包含中文语义描述（做什么、目标元素、预期），与 `annotations.json` 中的 stepId 一一对应，支撑 AI 自愈（见 `ui-test-freshness-spec.md`） |
| `HEADED_FLAG` | agent-browser 默认无头模式。添加 `HEADED_FLAG="--headed"` 变量并传给所有 `agent-browser` 命令以启用有头模式，便于人工观察执行过程 |
| 数据引用 | 账号、URL、业务值一律从 `data/` 数据文件读取，禁止硬编码（见 `ui-test-data-spec.md`） |

---

## 登录保障模式（ensure_login）

### 概述

凡需要登录态的测试用例，首个场景必须使用本函数模板实现登录检测与登录。后续场景**不再内嵌** `ensure_login`。

### 设计依据

登录页可能以两种方式呈现：
1. **URL 重定向**：访问 `/` 时服务器返回 `302 → /signin`
2. **同路径渲染**：访问 `/` 时直接渲染登录页（URL 不变，但标题为 `"ASDM | Sign In"`）

两种场景下 cookie 均为空。本函数通过**三路探测**覆盖所有情况。

### agent-browser 主产物标准实现

```bash
# ==================== 配置 ====================
DATA_DIR="$(cd "$(dirname "$0")" && pwd)/data"
BASE_URL=$(node -e "console.log(require('$(cygpath -m ${DATA_DIR}/env.json)').baseUrl)")
SUPER_ADMIN_EMAIL=$(node -e "console.log(require('$(cygpath -m ${DATA_DIR}/accounts.json)').accounts.superAdmin.username)")
SUPER_ADMIN_PASSWORD=$(node -e "console.log(require('$(cygpath -m ${DATA_DIR}/accounts.json)').accounts.superAdmin.password)")

# ==================== 登录保障 ====================
# 三路探测：cookie → 页面标题 → URL 兜底
# 检测到登录页后在当前页直接填写表单登录（不重复导航）
ensure_login() {
  # 清理残留 daemon
  agent-browser close 2>/dev/null || true
  sleep 1
  echo "[LOGIN:CHECK] 打开平台首页并检测登录态..."
  agent-browser ${HEADED_FLAG:-""} open "${BASE_URL}/" --browser=${BROWSER:-chrome}
  sleep 2

  local current_url
  current_url=$(agent-browser eval "window.location.href")
  local page_title
  page_title=$(agent-browser eval "document.title")
  local cookie_str
  cookie_str=$(agent-browser eval "document.cookie")
  local detected
  detected=$(echo "${cookie_str}" | grep -oiE "(session|sid|token|auth|jwt|connect\.sid)" | tr '\n' ' ')

  echo "  URL:  ${current_url}"
  echo "  title: ${page_title}"
  echo "  cookies: ${cookie_str:-(空)}"

  if [ -n "${detected}" ]; then
    echo "[LOGIN:SKIP] ✅ cookie 检测到会话 (${detected})，已登录"
  elif echo "${page_title}" | grep -qi "sign" || echo "${current_url}" | grep -qi "signin"; then
    echo "[LOGIN:NEED] ❌ 检测到登录页（title: ${page_title}），执行登录..."
    agent-browser find placeholder '请输入邮箱地址' fill "${SUPER_ADMIN_EMAIL}"
    agent-browser press Tab
    agent-browser find placeholder '请输入您的密码' fill "${SUPER_ADMIN_PASSWORD}"
    agent-browser click "form > div > div.flex input"
    agent-browser find role button click --name '登录'
    sleep 5
    echo "[LOGIN:OK] 登录完成"
  else
    echo "[LOGIN:SKIP] ✅ cookie(HttpOnly)不可见但页面正常，视为已登录"
  fi
}
```

### Playwright 降级脚本标准实现

```javascript
async function ensureLogin(page) {
  // 三路探测：cookie → 页面标题 → URL 兜底
  await page.goto(env.baseUrl + '/', { waitUntil: 'networkidle', timeout: 30000 });
  const currentUrl = page.url();
  const pageTitle = await page.title();
  // page.context().cookies() 可获取全部 cookie（含 HttpOnly）
  const cookies = await page.context().cookies();
  const authCookies = cookies.filter(c =>
    /session|sid|token|auth|jwt|connect\.sid/i.test(c.name)
  );
  console.log('  URL: ' + currentUrl);
  console.log('  title: ' + pageTitle);
  console.log('  cookies: ' + (cookies.length ? cookies.map(c => c.name).join(', ') : '(空)'));

  if (authCookies.length > 0) {
    console.log('[登录] ✅ cookie 检测到会话 (' + authCookies.map(c => c.name).join(', ') + ')，已登录');
  } else if (/sign/i.test(pageTitle) || /signin/i.test(currentUrl)) {
    console.log('[登录] ❌ 检测到登录页，执行登录...');
    const email = accounts.accounts.superAdmin.username;
    const password = accounts.accounts.superAdmin.password;
    await page.getByPlaceholder('请输入邮箱地址').fill(email);
    await page.keyboard.press('Tab');
    await page.getByPlaceholder('请输入您的密码').fill(password);
    await page.locator('form > div > div.flex input').click();
    await page.getByRole('button', { name: '登录' }).click();
    await page.waitForTimeout(5000);
    console.log('[登录] 登录完成');
  } else {
    console.log('[登录] ✅ cookie(HttpOnly)不可见但页面正常，视为已登录');
  }
}
```

### 使用方式

在首个场景脚本的 `# 配置` 段之后、业务步骤之前调用：

```bash
# 登录保障（首个场景，检测登录态并登录）
ensure_login

# 业务步骤（无需再关心登录）
agent-browser find role button click --name '创建顶层组织'
```

---

## 录制 json → agent-browser 命令转换表

## 录制 json → agent-browser 命令转换表

| 录制步骤 type | 转换目标 | 示例 |
|--------------|---------|------|
| `setViewport` | `agent-browser set viewport <w> <h>` | `agent-browser set viewport 1478 366` |
| `navigate` | `agent-browser open "<url>"`（首个 navigate）或注释标记页面跳转 | `agent-browser open "${BASE_URL}/signin"` |
| `click` | `agent-browser click '<选择器>'` | `agent-browser click 'button[type="submit"]'` |
| `change`（输入框） | `agent-browser fill '<选择器>' '<值>'`（值从数据文件读取） | `agent-browser fill '#username' "${USERNAME}"` |
| `change`（下拉框） | `agent-browser select '<选择器>' '<值>'` | `agent-browser select '#city' '北京'` |
| `change`（复选框） | `agent-browser check '<选择器>'` / `agent-browser uncheck '<选择器>'` | `agent-browser check 'input[type="checkbox"]'` |
| `keyDown`/`keyUp`（Enter/Tab 等） | `agent-browser press <键名>`；连续 keyUp 单字符（逐字输入噪声）忽略，以最终 `change` 值为准 | `agent-browser press Enter` |
| `scroll` | `agent-browser scroll <方向> [px]` / `agent-browser scrollintoview '<选择器>'` | `agent-browser scroll down 500` |
| 等待（录制间隙） | `sleep <秒>` 或 `agent-browser wait <毫秒>` | `sleep 2` |
| 断言步骤（录制时加入） | 见下节「断言转换规范」 | — |

## 选择器转换规范

### 核心原则

从录制步骤的 `selectors` 数组（多重选择器：`aria/...`、CSS、`xpath/...`、`pierce/...`）按以下优先级提取。

⚠️ **重要**：`aria/` 前缀（如 `aria/请输入邮箱地址`）是 Chrome DevTools Recorder 的专有格式，**不是**有效的 CSS 选择器，`agent-browser click "aria/..."` 会报 `Element not found`。必须使用 `agent-browser find` 命令或 CSS 选择器代替。

### 优先级表

| 优先级 | 录制 selectors 示例 | 转换目标 | 说明 |
|--------|--------------------|---------|------|
| 1（最优先） | `aria/请输入邮箱地址`（输入框） | `agent-browser find placeholder '请输入邮箱地址' fill '<值>'` | 使用 `find placeholder` 定位输入框，`fill` 填入值。不保证所有输入框都有 placeholder，失败时降级为 CSS |
| 1 | `aria/登录`（按钮 — 中文/提交类） | **`agent-browser click '<CSS>'`** | **中文 `find role --name` 常 `✓ Done` 不触发，优先使用录制中的 CSS 选择器**（如 `button.bg-brand-600`、`div.fixed button.inline-flex`、`form button`） |
| 1 | `aria/[role="checkbox"]` | ⚠️ 不推荐。`find role checkbox click` 常因元素缺少显式 role 而找不到。**建议优先使用 CSS 备选选择器** | 改用录制中的 CSS 选择器如 `form > div > div.flex input` |
| 2 | `aria/登录`（按钮 — 英文/纯字母） | `agent-browser find role button click --name '按钮文字'` | 英文/无中文的按钮文本匹配稳定，可使用 `find role` |
| 2 | CSS 稳定选择器（id、语义 class、`form button`） | `agent-browser click '<css>'` | 带 `#id` 的 CSS 最可靠。录制 selectors 数组中第二个元素通常即为 CSS 选择器 |
| 3 | `text/xxx`（如 `text/super-admin@asdm.ai`） | `agent-browser find text 'xxx' click` | `text/` 前缀也不是有效 CSS，需用 `find text` |
| 4 | `xpath//...` / `pierce/...` | `agent-browser click 'xpath=...'`（仅兜底，注释标注 ⚠️ 选择器不稳定） | 不稳定，仅在无其他选择器时使用 |

### find 命令用法速查

agent-browser 的 `find` 命令格式为：

```
agent-browser find <locator_type> '<value>' <action> [options]
```

| 场景 | 命令 |
|------|------|
| 点击按钮 | `agent-browser find role button click --name '按钮文本'` |
| 输入框填入 | `agent-browser find placeholder '占位文本' fill '值'` |
| 勾选复选框 | `agent-browser click '<CSS选择器>'`（find role checkbox 不稳定） |
| 选择下拉项 | `agent-browser select '<CSS选择器>' '值'` |
| 点击文本元素 | `agent-browser find text '元素文本' click` |
| 按键盘键 | `agent-browser press <键名>`（如 Tab/Enter） |

### 规则

- 同一脚本内同一元素的选择器写法保持一致。
- 使用兜底 xpath 的步骤必须在 `@step` 注释中标注 `⚠️ 选择器不稳定`，保鲜指令巡检时列为高风险步骤。
- 选择器语义优先级与 `ui-test-script-spec.md#选择器规范` 保持一致。
- 生成脚本后推荐先尝试执行验证选择器有效性，根据实际报错调整。常见报错及修复（来自实际调试经验）：

| 问题模式 | 症状 | 修复方式 | 涉及场景类型 |
|---------|------|---------|------------|
| `aria/` 前缀 | `Element not found` | 改 `agent-browser find placeholder/role/text` | 所有元素 |
| `text/` 前缀 | CSS 解析错误 | 改 `agent-browser find text 'xxx'` | 文本元素 |
| `find role checkbox` | 元素找不到 | 改 CSS 如 `form > div > div.flex input` | 复选框 |
| `change` 命令 | `Unknown command: change` | 下拉框改 `agent-browser select`，输入框改 `fill` | 下拉框/输入框 |
| `find role button click --name 'xxx'` | `✓ Done` 但无动作（表单不提交） | 改 CSS 如 `click "button.bg-brand-600"` | 提交/创建按钮 |
| `find role link click --name '中文'` | `Element not found`，但快照中元素存在 | 改 CSS 如 `li:nth-of-type(N) > a` | 下拉菜单链接 |
| `--headed` 与 daemon 冲突 | 脚本内点击失败，手动点成功 | 仅 `open` 用 `--headed`，后续命令不加 | 所有脚本 |
| URL 含 tab 参数 | Tab 按钮找不到 | 跳过此步骤（URL 已指定 Tab） | 设置页 Tab |
| Git Bash + `node -e "require(...)"` | `require` 找不到文件 | 用 `cygpath -m` 将 Unix 路径转 Windows 正斜杠 | 数据读取 |

## 断言转换规范

- **断言不丢失**：录制 json 中包含的断言步骤必须全部转换为脚本中的断言步骤；任一断言丢失视为该场景生成失败，在任务清单中备注原因。
- 断言实现方式：

| 断言类型 | 实现 |
|---------|------|
| 元素可见 | `agent-browser is visible '<选择器>'`（非零退出即失败） |
| 文本包含 | `TEXT=$(agent-browser eval "document.body.innerText")` + `echo "${TEXT}" \| grep -q "<期望文本>"` |
| 页面跳转 | `agent-browser get url` + 比对期望 URL 关键字 |
| 元素数量 | `agent-browser get count '<选择器>'` + 数值比对 |

- 断言失败必须 `echo "❌ 断言失败: <描述>"` 并 `exit 1`；断言成功必须 `echo "✅ 断言通过: <描述>"`。
- 断言步骤的 stepId 使用 `assert-<n>` 前缀，便于报告统计断言覆盖率（见 `ui-test-run-report-spec.md`）。

## 命名与存放

- 文件名：`<序号>-<模块>-<场景简称>.sh`
  - 序号为两位数字（`01`、`02`…），对应执行计划中的执行顺序，按依赖关系排列。如 SC-001 → `01-`，SC-002 → `02-`。
  - Playwright 降级脚本同基名：`<序号>-<模块>-<场景简称>.js`
- 存放路径：`.asdm/workspace/ui-test/<用例名称抽象>_<YYYYMMDDHHmmss>/`（与其他产物同级）。
- 序号编排原则：
  - P0 场景优先编号
  - 有依赖关系的场景按依赖链编号（如 SC-001 依赖无 → SC-002 依赖 SC-001 → SC-003 依赖 SC-002）
  - 无依赖的场景按优先级从高到低排列
- 生成后执行 `chmod +x`（非必需，`bash <脚本>` 可直接运行）。

## 质量检查清单

- [ ] 脚本包含 `set -e` 与 `[EXEC:START]`/`[EXEC:END]` 标记
- [ ] 每个步骤有 `# @step <stepId>` 注释和 `[STEP]` 日志标记，stepId 唯一
- [ ] 每个 `@step` 注释含中文自然语言描述，且已同步写入 `annotations.json`
- [ ] 每个步骤的 `@step` 注释后紧跟着 `# Recorder selectors:` 注释，列出该步骤录制 JSON 中的全部原始选择器
- [ ] 账号、URL、业务值均从 `data/` 数据文件读取，无硬编码
- [ ] 录制 json 中的断言步骤全部转换，无丢失
- [ ] xpath 兜底选择器已标注 ⚠️
- [ ] 脚本可通过 `bash <脚本名>.sh` 独立运行

---

## 相关文档

- **Spec**: `ui-test-design-generate-spec.md` - 设计与脚本生成工作流规范
- **Spec**: `ui-test-freshness-spec.md` - 保鲜工作流规范（自愈依赖 `@step` 与标注）
- **Spec**: `ui-test-data-spec.md` - 测试数据管理规范
- **Spec**: `ui-test-script-spec.md` - Playwright 降级脚本规范与选择器规范
