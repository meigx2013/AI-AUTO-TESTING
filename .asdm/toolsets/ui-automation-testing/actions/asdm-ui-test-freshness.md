---
registryId: ui-automation-testing
---
# Instructions for asdm-ui-test-freshness action

## Purpose

This instruction guides the AI model to perform script freshness maintenance (保鲜指令). It detects coverage gaps against requirement descriptions, runs health checks on existing scripts, performs AI self-healing on failed scripts (bounded by a retry threshold), updates semantically outdated scripts based on requirement changes, re-runs verification, and outputs a freshness report. Scripts that cannot be recovered are handed over to manual fallback.

## Language Setting

默认使用**中文（简体中文）**作为输出语言。

## Context Injection

Before performing freshness maintenance, the AI model should read the following context:

1. **Freshness Workflow Spec** (Required)
   - Path: `.asdm/toolsets/ui-automation-testing/spec/ui-test-freshness-spec.md`
   - Purpose: 遵循保鲜工作流规范（五步流程、边界保护、保鲜报告模板）

2. **Manual Fallback Spec** (Required)
   - Path: `.asdm/toolsets/ui-automation-testing/spec/ui-test-manual-fallback-spec.md`
   - Purpose: 转人工时按兜底清单模板输出

3. **Agent-Browser Script Spec** (Required)
   - Path: `.asdm/toolsets/ui-automation-testing/spec/ui-test-agent-browser-spec.md`
   - Purpose: 了解 `@step` 注释与 `[STEP]` 标记格式，用于失败步骤定位与自愈

4. **Test Data Spec** (Required)
   - Path: `.asdm/toolsets/ui-automation-testing/spec/ui-test-data-spec.md`
   - Purpose: 数据问题自愈时更新 `data/` 数据文件而非脚本

5. **脚本库与标注** (Required)
   - 脚本库：`.asdm/workspace/ui-test/` 下各用例文件夹的 `.sh` / `.js` 脚本
   - 录制脚本：`recordings/<模块>/*.json`
   - 自然语言标注：用例文件夹下 `annotations.json`
   - 历史报告：用例文件夹下 `report.md`

6. **固化脚本（优先调用，减少 AI 消耗）** (Recommended)
   - `scripts/collect-report.js`：可复用其"按执行计划批量运行 + 标记解析"能力完成健康检测（步骤 3）的机械运行部分
   - `scripts/lint-dataset.js`：自愈/变更更新后（步骤 6 重跑前）机械校验数据集结构完整性

---

## Steps to Perform Freshness Maintenance

### 1. 接收巡检范围与需求输入

从用户输入中获取：

- **巡检范围**：指定用例文件夹（完整名或前缀），或"全部"（巡检 `.asdm/workspace/ui-test/` 下所有用例）
- **需求描述**（可选）：人工录入的新需求/变更描述，用于覆盖检测与变更更新

### 2. 覆盖检测

按 [ui-test-freshness-spec.md#步骤-1覆盖检测](../spec/ui-test-freshness-spec.md) 执行：

- 比对需求涉及的业务环节与 `recordings/` 下现有录制脚本
- 输出缺失环节清单：缺什么环节、应补录哪个录制脚本（目标路径）
- 存在缺失 → 按 [ui-test-manual-fallback-spec.md](../spec/ui-test-manual-fallback-spec.md) 输出补录清单，转入人工兜底流程

### 3. 健康检测

对巡检范围内的存量脚本执行巡检：

- **（机械，优先脚本）** 优先调用 `scripts/collect-report.js <用例名>` 批量执行并汇聚每个场景的成功/失败/跳过结果（其会解析 `[STEP:*:START/OK]` 标记、判定 ❌ 断言失败），AI 读取其输出/报告定位失败 stepId；或逐脚本执行：`bash "<脚本>.sh"`（`.sh` 缺失时降级执行 `.js`）。
- 逐脚本执行：`bash "<脚本>.sh"`（`.sh` 缺失时降级执行 `.js`）。agent-browser 默认无头，如需有头模式查看执行过程，脚本模板已内置 `HEADED_FLAG="--headed"`。
- 记录每个脚本结果：通过 / 失败、失败 stepId（最后一个有 `[STEP:<id>:START]` 无 `[STEP:<id>:OK]` 的步骤）、报错信息

### 4. 失效修复（AI 自愈）

对失败脚本，结合**报错日志 + 对应 recorder json + annotations.json** 自愈，按 [ui-test-freshness-spec.md#步骤-3失效修复](../spec/ui-test-freshness-spec.md) 的失效原因分类处理：

- 选择器失效 → 换用 recorder json 中的备选选择器；仍失败则 `agent-browser snapshot` 重新定位
- 断言内容变化 → 确认页面变更后更新断言期望值
- 页面流程变化 → 按标注的语义描述调整步骤
- 环境/数据问题 → 更新 `data/` 数据文件，不改脚本

每次自愈修改在脚本对应 `@step` 注释旁追加 `# @healed <日期>: <修改说明>`，并同步更新 `annotations.json`。

**边界保护**：同一脚本自愈连续失败达到 **2 次**即停止自动尝试，转人工兜底。

### 5. 变更更新

对因需求变更导致语义过期的脚本（能跑通但不符合新需求）：

- 基于人工录入的需求描述识别受影响场景与步骤
- 更新脚本与 `annotations.json`
- 以 diff 摘要形式提交测试人员**人工确认后入库**

### 6. 重跑验证

对自愈/更新后的脚本重跑验证：

- 通过 → 入库
- 不通过 → 计入自愈失败次数；未达阈值回到步骤 4，达到阈值转人工

### 6b. 数据集校验（机械，优先调用固化脚本）

自愈/变更更新后、重跑验证前，调用 `scripts/lint-dataset.js` 机械校验数据集结构仍符合要求：

```bash
node .asdm/toolsets/ui-automation-testing/scripts/lint-dataset.js <用例名或前缀>
```

- 校验项：`.sh` 标记（`set -e`/`[EXEC:START]`/`[EXEC:END]`/`@step`）是否完整、`annotations.json` 步骤字段是否补齐、依赖顺序是否一致。
- 脚本退出码 1 表示存在错误。**AI 仅处理 ❌ 错误项**，⚠️ 警告可标注后交人工审阅，确认无误再进入重跑验证。

### 7. 生成保鲜报告

按 [ui-test-freshness-spec.md#输出保鲜报告](../spec/ui-test-freshness-spec.md) 的模板生成保鲜报告：

- 指定用例巡检 → 写入用例文件夹下 `freshness-report-<YYYYMMDD>.md`
- 全库巡检 → 写入 `.asdm/workspace/ui-test/freshness-report-<YYYYMMDD>.md`

报告包含：巡检范围、覆盖检测（缺失环节清单）、健康检测、处理结果（自愈成功/待人工）、转人工清单。

---

## Execution Guidelines

### When to Use This Action

Use this action when:
- 定时巡检存量测试脚本（v1.0 触发方式）
- 收到新需求/需求变更，需要检测脚本覆盖缺口与失效情况
- 上次执行报告存在失败场景，需要尝试 AI 自愈

### Self-Healing Guidelines

1. **先定位再修复**：必须先从执行日志定位失败 stepId，读取对应标注与录制步骤，再决定修复动作
2. **最小修改**：自愈只修改失效的步骤，不重构无关部分
3. **不改录制源文件**：recorder json 只能由人工补录更新，自愈不得修改
4. **留痕**：每次自愈动作必须写入 `@healed` 注释与保鲜报告
5. **阈值保护**：连续失败 2 次即转人工，避免走错方向无限重试

### 常见失效原因及自愈对照（实践经验）

| 报错日志特征 | 失效类型 | 自愈处理方式 |
|------------|---------|-------------|
| `Element not found` + `aria/` 选择器 | 选择器格式错误 | `aria/xxx` 不是有效 CSS，改为 `agent-browser find placeholder/role/text` |
| `Unknown command: change` | 命令名错误 | `change` 命令不存在，输入框改为 `fill`，下拉框改为 `select` |
| `Unexpected token "/"` | CSS 解析错误 | `text/xxx` 改为 `agent-browser find text 'xxx'` |
| `checkbox` 选择器找不到 | 元素无显式 role | `find role checkbox` 不稳定，改用录制中的 CSS 选择器如 `form > div > div.flex input` |
| 登录页 Tab button 点击失败 | 冗余步骤 | URL 已含 tab 参数（如 `?tab=Users`）时跳过 Tab 点击 |
| 下拉框选择不生效 | 缺少确认步骤 | 在选择后补充点击下拉框外部区域以关闭下拉确认选择 |

### Error Handling

| 错误情况 | 处理方式 |
|---------|---------|
| 巡检范围文件夹不存在 | 提示并列出可用用例文件夹 |
| annotations.json 缺失 | 自愈时降级为仅用 recorder json + 报错日志，报告中标注标注缺失 |
| recorder json 缺失 | 该脚本无法自愈，直接转人工（建议补录） |
| 自愈达到阈值（2 次） | 停止自动尝试，输出兜底清单 |
| 重跑验证不通过 | 计入自愈失败次数，按阈值规则处理 |

---

## Usage

To use this instruction, the AI model should:

1. 接收巡检范围与可选的需求描述
2. 按 [覆盖检测](../spec/ui-test-freshness-spec.md) 比对需求环节与录制脚本，输出缺失清单
3. 执行健康检测（**可优先调用 `scripts/collect-report.js <用例名>` 机械批量执行并汇聚失败场景**，再由 AI 读取控制台/报告定位失败 stepId），收集失败脚本与报错日志；自愈/变更更新后再调用 `scripts/lint-dataset.js <用例名>` 校验数据集结构
4. 对失败脚本执行 AI 自愈（≤2 次），对语义过期脚本执行变更更新（人工确认）
5. 重跑验证，通过入库、不通过转人工
6. 按 [保鲜报告模板](../spec/ui-test-freshness-spec.md) 输出保鲜报告

---

## Output Summary

执行完成后产出：

```
.asdm/workspace/ui-test/<用例文件夹>/
├── freshness-report-<YYYYMMDD>.md   # 保鲜报告（指定用例巡检）
├── <脚本>.sh / <脚本>.js            # 自愈/更新后的脚本（含 @healed 注释）
├── annotations.json                 # 同步更新的标注
└── data/                            # 更新后的数据文件（如涉及）

.asdm/workspace/ui-test/
└── freshness-report-<YYYYMMDD>.md   # 保鲜报告（全库巡检）
```

| 产出物 | 说明 |
|--------|------|
| `freshness-report-<YYYYMMDD>.md` | 保鲜报告：巡检范围、发现问题、处理结果、缺失环节清单、转人工清单 |
| 自愈后的脚本 | 含 `@healed` 修改记录 |
| 转人工清单 | 按兜底清单模板输出，供测试人员介入 |

---

## 固化脚本（优先调用，减少 AI 消耗）

本 action 的机械部分已由固化脚本实现，**执行时应优先调用脚本，AI 仅处理需语义判断的部分**（失败归因、选择器自愈、变更更新、报告撰写）：

- `scripts/collect-report.js`：复用其"按执行计划批量运行 + 标记解析"能力完成健康检测（步骤 3）的机械运行与结果汇聚。AI 仅读取其输出定位失败 stepId。
  - 调用：`node scripts/collect-report.js <用例名或前缀>`
- `scripts/lint-dataset.js`：自愈/变更更新后（步骤 6b）机械校验数据集结构完整性，避免自愈引入结构错误。
  - 调用：`node scripts/lint-dataset.js <用例名或前缀>`

---

## 相关规范文档

| 规范文档 | 用途 |
|---------|------|
| [ui-test-freshness-spec.md](../spec/ui-test-freshness-spec.md) | 保鲜工作流规范（五步流程、边界保护、报告模板） |
| [ui-test-manual-fallback-spec.md](../spec/ui-test-manual-fallback-spec.md) | 人工兜底流程规范 |
| [ui-test-agent-browser-spec.md](../spec/ui-test-agent-browser-spec.md) | agent-browser 脚本规范（@step 与断言格式） |
| [ui-test-data-spec.md](../spec/ui-test-data-spec.md) | 测试数据管理规范 |
| [ui-test-design-generate-spec.md](../spec/ui-test-design-generate-spec.md) | 自然语言标注规范（annotations.json） |
