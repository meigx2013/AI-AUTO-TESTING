# 执行时自愈规范

## 概述

本规范定义了 UI 自动化测试脚本执行过程中，AI 对元素定位失败进行自动修复的机制。自愈逻辑在 `asdm-ui-test-run`（执行时自愈）和 `asdm-ui-test-freshness`（保鲜自愈）中共用。

**核心原则**：自愈仅处理**元素定位相关**的失败。断言失败、环境问题、超时等直接转人工，不做自动修复。

---

## 自愈范围（Healing Scope）

| 序号 | 失败类型 | 报错日志特征 | 是否自愈 |
|------|---------|-------------|---------|
| 1 | **元素找不到** — 选择器格式错误 | `Element not found` + `aria/` 或 `text/` 前缀 | ✅ 自愈 |
| 2 | **元素找不到** — 选择器已失效 | `Element not found` + CSS 选择器（页面结构变化） | ✅ 自愈 |
| 3 | **命令不存在** | `Unknown command: change` 等 | ✅ 自愈 |
| 4 | **CSS 解析错误** | `Unexpected token "/" in css selector` | ✅ 自愈 |
| 5 | **按钮点击无响应** | `find role button click --name 'xxx'` 返回 `✓ Done` 但弹窗不关闭/表单不提交（无实际效果） | ✅ 自愈 |
| 6 | **复选框找不到** | `find role checkbox` 返回 `Element not found` | ✅ 自愈 |
| — | **断言失败** | `❌ 断言失败: xxx` | ❌ 不自愈，直接转人工 |
| — | **超时** | 脚本执行超过 5 分钟 | ❌ 不自愈，直接转人工 |
| — | **网络/环境错误** | `ERR_CONNECTION_REFUSED`、`ECONNREFUSED` 等 | ❌ 不自愈，直接转人工 |
| — | **脚本本身语法错误** | bash 语法错误、变量未定义、`command not found` | ❌ 不自愈，直接转人工 |
| — | **agent-browser 未安装** | `bash: agent-browser: command not found` | ❌ 不自愈，直接转人工 |
| — | **其他非定位类异常** | 无法归入以上 1~6 类的任何报错 | ❌ 不自愈，直接转人工 |

---

## 自愈流程

```
脚本失败 → 匹配自愈范围？
  ├─ ❌ 不匹配 → 直接转人工兜底
  └─ ✅ 匹配 → 进入自愈：
      1. 从执行日志中定位失败步骤的 stepId
      2. 读取脚本中该步骤的 `# Recorder selectors:` 注释，获取录制原始选择器列表
      3. 按 [ui-test-agent-browser-spec.md#选择器转换规范] 的优先级表，选择当前未使用过的备选选择器
      4. 修改脚本中的对应命令（替换选择器或命令类型），保留 `# Recorder selectors:` 注释不变
      5. 在失败步骤的 `@step` 注释旁追加 `# @healed <日期>: <修改说明>`
      6. 记录自愈动作到执行报告或保鲜报告的「自愈记录」章节
      7. 重跑该脚本（从该脚本开头重新执行，而非从失败步骤恢复）
```

---

## 自愈选择器替换策略

根据失败类型，从 `# Recorder selectors:` 中选择替代方案：

| 原始命令（失败） | 报错特征 | 替代策略 |
|-----------------|---------|---------|
| `agent-browser find role button click --name '中文'` | `✓ Done` 但无实际效果 | 从 Recorder selectors 中取 CSS 选择器 → `agent-browser click '<CSS>'` |
| `agent-browser find role checkbox click` | `Element not found` | 从 Recorder selectors 中取 CSS 选择器 → `agent-browser click '<CSS>'` |
| `agent-browser find aria/xxx`（历史遗留） | `Element not found` | 改为 `agent-browser find placeholder/role/text` 或 CSS 选择器 |
| `agent-browser click "aria/xxx"` | `Element not found` | 改为 `agent-browser find placeholder 'xxx' fill ...` 或 `agent-browser find text 'xxx' click` 或 CSS |
| `agent-browser click "text/xxx"` | CSS 解析错误 | 改为 `agent-browser find text 'xxx' click` |
| CSS 选择器（`div.xxx > button`） | `Element not found` | 从 Recorder selectors 中选择另一个 CSS 选择器 或 aria label 对应命令 |
| `agent-browser change ...` | `Unknown command: change` | 输入框 → `fill`；下拉框 → `select` |

---

## 边界保护

- **同一脚本连续自愈失败达到 2 次**，立即停止自动尝试，转人工兜底
- 自愈仅修改脚本文件，**不修改录制 JSON 源文件**
- 执行时自愈（`asdm-ui-test-run`）：自愈后的脚本立即用于重跑，不经过人工确认
- 保鲜自愈（`asdm-ui-test-freshness`）：自愈后的脚本重跑验证，通过则入库，不通过转人工

---

## 自愈记录格式

自愈记录应至少包含以下字段，写入执行报告或保鲜报告的「自愈记录」章节：

| 字段 | 说明 | 示例 |
|------|------|------|
| 场景 | 触发自愈的场景编号 | `ORG-001` |
| 失败步骤 | stepId + 操作描述 | `step-001-2 — 点击「创建顶层组织」按钮` |
| 失败类型 | 对应自愈范围表中的序号 | 类型 5 — 按钮点击无响应 |
| 失败日志 | 原始报错信息 | `✓ Done` 但弹窗未弹出 |
| 原始命令 | 失败时的命令 | `agent-browser find role button click --name '创建顶层组织'` |
| 替换后命令 | 自愈后的命令 | `agent-browser click "div.space-y-2 > div.flex > button"` |
| 自愈结果 | 成功/失败 | ✅ 成功 |
| 重跑结果 | 重跑后的 exit code | `0` |

---

## 相关文档

| 文档 | 用途 |
|------|------|
| [ui-test-agent-browser-spec.md](./ui-test-agent-browser-spec.md) | agent-browser 命令格式与选择器转换规则 |
| [ui-test-run-report-spec.md](./ui-test-run-report-spec.md) | 执行报告模板（含自愈记录章节） |
| [ui-test-freshness-spec.md](./ui-test-freshness-spec.md) | 保鲜工作流规范（引用本规范的自愈规则） |
| [asdm-ui-test-run.md](../actions/asdm-ui-test-run.md) | 执行指令（引用本规范） |
| [asdm-ui-test-freshness.md](../actions/asdm-ui-test-freshness.md) | 保鲜指令（引用本规范） |
