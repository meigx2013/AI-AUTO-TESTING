# agent-browser 脚本调试最佳实践

> 基于实际调试经验总结，解决 `agent-browser` CLI 在中文页面下的常见失效问题。
> 生成时间：2026-07-23
> 关联规范：`ui-test-agent-browser-spec.md`、`ui-test-design-generate-spec.md`

---

## 一、点击操作的最佳实践

### 核心原则

不用裸 `click` 命令，优先 `eval` 兜底。

| 按钮类型 | 推荐方式 | 说明 |
|---------|---------|------|
| 英文/纯字母按钮（如 `Submit`） | `find role button click --name 'Submit'` | 英文匹配稳定，首选 |
| 中文/混合文本按钮（如 `测试连接`） | `scrollintoview` + `eval` JS 点击 | 中文 `find role` 常返回 ✓ Done 但不触发，`find text` 也不可靠 |
| 表单提交/创建按钮（如 `button.bg-brand-600`） | `scrollintoview` + `eval` JS 点击 | CSS 类名可能变化，且按钮在 modal 中可能被遮挡 |
| 同CSS选择器的多个按钮（如两个 `div.fixed button.bg-blue-500`） | `eval "Array.from(...).find(b => b.textContent.includes('文字')).click()"` | 用文本内容区分，避免点错 |

### 标准点击模式

```bash
agent-browser scrollintoview "<选择器>"
sleep 0.5
agent-browser eval "document.querySelector('<选择器>').click()"
```

### 同CSS选择器多按钮区分

```bash
agent-browser eval "Array.from(document.querySelectorAll('div.fixed button.bg-blue-500')).find(b => b.textContent.includes('下一步')).click()"
```

### 为什么 `eval` 更可靠

- 绕过元素可见性检测（被遮罩层遮挡也能触发点击）
- 绕过 CSS 类名动态变化（如 `bg-green-500` 可能变）
- `Array.find` 按文本精确匹配，同 CSS 选择器不混淆

---

## 二、页面导航的最佳实践

| 场景 | 推荐方式 |
|------|---------|
| 点击打开组织与项目导航按钮 | `find role button click --name '打开组织与项目导航'`（aria label 匹配稳定） |
| 在导航树中搜索组织/项目 | `fill "#org-tree-navigation-search"` → 搜索框填充 |
| 点击搜索结果 | `click "CSS选择器"` — 从录制JSON中提取结果按钮的CSS选择器，不用 `find text` |
| 点击组织展开按钮 | `click "div.max-h-[min(320px,45vh)] > div:nth-of-type(1) button.min-w-0"` |
| 点击项目链接进入 | `click "div.mb-3 > div > div > a"` |

### 导航树点击失效处理

当在组织/项目导航树中 `find text` 返回 ✓ Done 但页面不跳转时：
1. 改用搜索方式：`fill "#org-tree-navigation-search"` + 点击结果
2. 结果点击使用 CSS 选择器（从录制 JSON 提取），不用 `find text`

### 列表 / 树状 / 表格中的元素锁定：优先使用搜索框（通用快捷方式）

当目标元素位于**列表、树状结构或表格**中时，直接定位存在固有难点：
- 行序号不稳定（`li:nth-of-type(N)`、`tr:nth-child(N)` 随数据增删而漂移）
- 长列表存在分页/虚拟滚动，目标元素可能未渲染在 DOM 中
- 同类元素多，文本/CSS 选择器易混淆

**如果当前功能界面存在搜索框（或过滤输入框），优先使用搜索框缩小结果集，再锁定元素**——这是最快捷、最稳定的定位方式：

```bash
# 标准模式：搜索 → 等待过滤 → 锁定唯一/首个结果
agent-browser fill "<搜索框选择器>" "<目标关键词>"
sleep 1   # 等待前端过滤/请求完成
agent-browser click "<结果项CSS选择器>"   # 过滤后结果集小，nth-of-type(1) 也变得可靠
```

| 场景 | 无搜索框时 | 有搜索框时（推荐） |
|------|-----------|------------------|
| 组织/项目导航树 | 逐级展开 + 不稳定的行点击 | `fill "#org-tree-navigation-search"` + 点击结果 |
| 用户/成员列表 | 翻页遍历 + `nth-child` 定位 | 搜索用户名后点击首行 |
| 数据表格中的某行 | 行序号定位（数据变化即失效） | 按唯一字段（名称/ID）搜索后操作首行 |

要点：
- 搜索关键词应使用**唯一性强的字段**（如精确名称、编号），确保过滤后结果唯一
- 搜索后必须 `sleep` 等待过滤生效，再执行点击/断言
- 该模式同样降低自愈成本：列表结构变化时，搜索框选择器（通常有稳定 `#id`）比行选择器更不易失效
- 录制阶段也建议引导操作者优先走搜索路径，使录制 JSON 中直接包含搜索框选择器

---

## 三、选择器提取优先级（实测修正版）

从录制 JSON 的 `selectors` 数组提取时，按以下优先级：

| 优先级 | 选择器类型 | agent-browser 写法 | 说明 |
|--------|-----------|-------------------|------|
| 1 | `#id` | `click "#id"` | 最稳定，如 `#org-tree-navigation-search`、`#asdm-create-project-name` |
| 2 | CSS 稳定选择器 | `click "div.parent > div.child"` | 注意 bash 中转义 `[]`、`()` 等特殊字符 |
| 3 | `aria/xxx` 输入框 | `find placeholder 'xxx' fill` | placeholder 定位输入框 |
| 4 | `text/xxx` | ❌ 不推荐 click | `find text` 常返回 ✓ Done 但不触发导航 |
| 5 | `xpath/...` | ❌ 仅在兜底用 | 不稳定，需标注 ⚠️ |

### 常见选择器陷阱

| 问题 | 症状 | 修复 |
|------|------|------|
| `aria/` 前缀 | `Element not found` | 改 `find placeholder/role/text` 或提取 CSS |
| `text/` 前缀 | CSS 解析错误 | 改 `find text 'xxx'` 或提取对应 CSS |
| `find role button click --name '中文'` | ✓ Done 但无动作 | 改 CSS 如 `click "button.bg-brand-600"` 或 `eval` JS 点击 |
| `find role link click --name '中文'` | Element not found | 改 CSS 如 `li:nth-of-type(N) > a` |
| 转义字符 | bash 错误 | `[min(320px,45vh)]` 在 bash 中写为 `\\[min\\(320px\\,45vh\\)\\]` |

---

## 四、输入操作的最佳实践

| 操作 | 推荐方式 | 说明 |
|------|---------|------|
| 文本输入框 | `find placeholder 'xxx' fill "值"` | placeholder 定位最可靠 |
| 下拉选择 | `select "select" "值"` | select 标签直接用 |
| 密码/隐藏输入 | `find placeholder 'xxx' fill "值"` | 同文本输入框 |

### 录制噪声处理

录制 JSON 中连续 `keyUp` 单字符（逐字输入过程）**全部忽略**，只保留最终的 `change` 值。脚本只需：
```bash
# 直接填充最终值，跳过逐字输入过程
agent-browser find placeholder 'xxx' fill "最终值"
```

---

## 五、登录保障模式（标准模板实现）

```bash
ensure_login() {
  agent-browser close 2>/dev/null || true
  sleep 1
  agent-browser ${HEADED_FLAG:-""} open "${BASE_URL}/" --browser=${BROWSER:-chrome}
  sleep 2

  local current_url=$(agent-browser eval "window.location.href")
  local page_title=$(agent-browser eval "document.title")
  local cookie_str=$(agent-browser eval "document.cookie")
  local detected=$(echo "${cookie_str}" | grep -oiE "(session|sid|token|auth|jwt|connect\.sid)" | tr '\n' ' ')

  if [ -n "${detected}" ]; then
    echo "[LOGIN:SKIP] ✅ cookie 检测到会话，已登录"
  elif echo "${page_title}" | grep -qi "sign" || echo "${current_url}" | grep -qi "signin"; then
    echo "[LOGIN:NEED] ❌ 检测到登录页，执行登录..."
    agent-browser find placeholder '请输入邮箱地址' fill "${EMAIL}"
    agent-browser press Tab
    agent-browser find placeholder '请输入您的密码' fill "${PASSWORD}"
    agent-browser click "form > div > div.flex input"
    agent-browser find role button click --name '登录'
    sleep 5
    echo "[LOGIN:OK] 登录完成"
  else
    echo "[LOGIN:SKIP] ✅ cookie(HttpOnly)不可见但页面正常，视为已登录"
  fi
}
```

---

## 六、数据读取注意事项（Git Bash 环境）

```bash
# 必须使用 cygpath -m 将 Unix 路径转为 Windows 正斜杠路径
BASE_URL=$(node -e "console.log(require('$(cygpath -m ${DATA_DIR}/env.json)').baseUrl)")
```

在 Git Bash (Windows) 下，`node -e "require(...)"` 的参数必须是 Windows 格式路径（正斜杠），否则 `require` 找不到文件。

---

## 七、调试流程速查

当脚本执行失败时，按以下流程排查：

```
① 查看日志定位失败步骤 [STEP:xxx:START]
② 判断错误类型：
   ├─ "Element not found"
   │   └─ 选择器无效 → 换选择器（CSS > find > XPath）
   ├─ "✓ Done" 但页面无变化
   │   ├─ 中文按钮 → 改用 eval JS 点击
   │   └─ 导航树 → 改用搜索方式
   └─ 页面跳转到非预期页
       └─ 前一步未真正执行成功 → 检查前一步的点击/输入
③ 修复后重新执行 bash <脚本名>.sh
```

### 常见错误和修复速查

| 问题模式 | 症状 | 修复方式 |
|---------|------|---------|
| 中文按钮点击无效 | ✓ Done 但无动作 | `eval "document.querySelector('CSS').click()"` |
| 导航树展开失效 | 元素找不到 | 改用搜索 `fill "#org-tree-navigation-search"` |
| 列表/表格行定位失效 | 行序号漂移 / 目标未渲染（分页、虚拟滚动） | 改用搜索框过滤后锁定结果（见 §二 搜索框快捷方式） |
| 搜索结果不可点击 | ✓ Done 但不进入 | 改 CSS 点击，不用 `find text` |
| 被遮罩层遮挡 | Element not found | `scrollintoview` + `eval` |
| require 找不到文件 | Git Bash + node | 加 `cygpath -m` 转换路径 |

---

## 八、质量检查清单

生成脚本后检查：

- [ ] 中文按钮使用 `scrollintoview` + `eval` JavaScript 点击
- [ ] 同 CSS 选择器的多个按钮用 `Array.find` + `textContent` 区分
- [ ] 导航树展开使用搜索方式（`#org-tree-navigation-search`）
- [ ] 列表/树/表格中的元素锁定：功能存在搜索框时优先"搜索 → 等待 → 锁定结果"，避免 `nth-of-type` 行序号定位
- [ ] 输入框使用 `find placeholder` 定位
- [ ] 账户、URL、业务数据均从 `data/` 文件读取，无硬编码
- [ ] `aria/`、`text/` 前缀未出现在 `click`/`fill` 命令中
- [ ] 断言保留完整，无丢失
- [ ] 录制 JSON 中的逐字输入噪声已清理

---

> 本文档为 `ui-test-agent-browser-spec.md` 的补充最佳实践，不替代规范文档。
> 关联规范：`ui-test-agent-browser-spec.md` — agent-browser 脚本规范（主产物）
