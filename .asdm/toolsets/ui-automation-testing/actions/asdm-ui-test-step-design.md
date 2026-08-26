---
registryId: ui-automation-testing
---
# asdm-ui-test-step-design 操作指令

## Purpose

本指令指导 AI 模型根据 PRD 文档或一句话需求描述，进行**测试步骤设计**，生成结构化的测试步骤文档和录制计划。这是 `asdm-ui-test-design-generate` 的前置步骤——产出清晰的测试步骤文档，驱动人工使用 Chrome DevTools Recorder 精准录制，从而提升后续自动化脚本的准确性。

> **核心原则**：
> - 测试步骤文档是"录制蓝图"——告诉人工**录什么、在哪里录、预期看到什么**
> - 录制计划是"任务清单"——按页面和操作列出每个需要录制的步骤，提供可视化清单
> - 人工补录完成后，`asdm-ui-test-design-generate` 基于完整的 `recordings/` 生成脚本，准确性大幅提升

---

## 完整工作流定位

本指令为 UI 自动化测试工作流的前置步骤：
- **asdm-ui-test-step-design**（本指令）：需求/PRD → 测试步骤文档 + 录制计划 → 人工录制
- **asdm-ui-test-design-generate**：读取 recordings/ → 检测元素定位 → 生成双产物脚本
- **asdm-ui-test-run**：执行脚本 → 输出报告 → 失败转人工兜底
- **asdm-ui-test-freshness**：定时巡检 → AI 自愈 → 保鲜报告

---

## Language Setting

默认使用**中文（简体中文）**作为输出语言。所有生成的内容均使用中文，并遵循中文写作规范。

---

## Context Injection

执行前，AI 模型按需读取以下上下文文件：

### 必需读取（Phase 1 — 规范与脚本）

1. **测试步骤设计规范**（必需）
   - 路径：`.asdm/toolsets/ui-automation-testing/spec/ui-test-step-design-spec.md`
   - 用途：遵循测试步骤设计规范，包括场景设计要素、测试步骤文档模板、录制计划模板

2. **测试用例文档模板规范**（必需）
   - 路径：`.asdm/toolsets/ui-automation-testing/spec/ui-test-case-spec.md`
   - 用途：遵循场景编号规范（`<模块缩写>-<序号>`）、优先级定义（P0/P1/P2）

3. **录制清单工具脚本**（必需）
   - 路径：`.asdm/toolsets/ui-automation-testing/scripts/generate-tree.js`
   - 路径：`.asdm/toolsets/ui-automation-testing/scripts/check.js`
   - 用途：生成 `structure/tree.json` 和 `recording-checklist.md`，检测录制完成度
   - 路径：`.asdm/toolsets/ui-automation-testing/scripts/convert-recording.js`
   - 用途：固化转换——录制 JSON → `stepDesign.md` + `annotations.json`（解析步骤、按 type 分类、@符号元素探测均为确定性逻辑，AI 无需逐条解析）

### 按需读取（Phase 2 — 按场景需要）

4. **录制文件参考**（可选 — 如 `recordings/` 目录已有录制，读取以了解选择器风格）
   - 路径：`recordings/**/*.json`（如存在）
   - 用途：了解已有的录制文件命名风格和目录结构，保持一致

5. **测试数据管理规范**（如涉及复杂数据配置）
   - 路径：`.asdm/toolsets/ui-automation-testing/spec/ui-test-data-spec.md`
   - 用途：了解测试数据的分类和引用方式，确保测试步骤中的数据描述与数据规范一致

---

## Steps to Execute

### 1. 接收需求输入

从用户输入中获取测试需求。输入可以是以下形式之一：

| 输入类型 | 示例 |
|---------|------|
| **一句话需求** | "测试医生排班管理功能，包括添加排班、查看排班、删除排班" |
| **PRD 文档路径** | 用户提供 PRD 文档路径，需 `read_file` 读取 |
| **详细需求描述** | 用户输入多段需求文本 |

如果用户提供的需求过于模糊，引导用户补充以下关键信息：
- **目标页面/模块**：被测功能的名称和菜单路径
- **核心操作流程**：用户的主要操作路径
- **测试场景**：需要覆盖哪些场景（正常流程、异常流程、边界条件）
- **测试环境**：URL、账号等

### 1b. 澄清环节（Clarification Loop）

在进入场景设计之前，AI 模型必须对需求进行自检，识别是否存在无法理解或无法推导的模糊点，并主动向用户发起澄清。

#### 何时触发澄清

在以下情况下，必须暂停下一步流程，主动向用户提问澄清：

| 触发条件 | 示例 |
|---------|------|
| **业务概念不明确** | 需求提到"排班类型"但未说明有哪些类型值（如上午/下午/全天） |
| **操作流程不完整** | 描述"用户提交预约"但未说明提交后是否需确认支付 |
| **页面/元素不可推断** | 需求说"点击列表中的操作按钮"但未说明按钮名称或位置 |
| **数据格式不清晰** | 需求说"输入日期"但未说明日期格式（yyyy-MM-dd / MM/dd/yyyy） |
| **角色/权限不明确** | 需求提到"管理员操作"但未说明管理员与普通用户的页面差异 |
| **多条路径混淆** | 需求同时描述多个不同流程但未区分哪些是独立场景、哪些是分支 |
| **PRD 文档内容矛盾** | PRD 中前后描述的功能逻辑不一致 |

#### 澄清提问方式

每次澄清提问应结构化，遵循以下格式：

```
❓ 需要澄清：<问题主题>

需求中提到了 <问题描述>，我有以下理解：
1. <理解方案A>
2. <理解方案B>

请问应该采用哪种理解？
```

**提问原则**：
- **每次最多提 3 个问题**，避免一次性轰炸用户
- **每个问题提供至少 2 个可选理解方案**（A/B 选择），降低用户回答成本
- **优先澄清影响场景拆分和步骤设计的关键问题**，次要问题可暂放
- 如果用户回答了部分问题，继续用新问题跟进未澄清的部分

#### 多轮澄清流程

```
接收需求 → [需要澄清?] ─是→ 输出澄清问题 → 等待用户回复
         │                     ↑
         否                    └── 根据用户回答更新理解
         ↓                           │
    进入场景设计          ←── 还有未澄清点? ── 是 → 继续提问
                                 否 → 进入场景设计
```

#### 澄清结果处理

- 用户澄清后，将澄清内容更新到需求理解中，标注为"已澄清"
- 如果用户表示"按默认理解"或"你自己决定"，AI 按最合理的方案推进并在输出中标明"待确认"
- 记录所有澄清问题和用户回复，作为测试步骤文档的附录内容

---

### 2. 分析需求并设计测试场景

#### 2.1 需求分析

解析需求文本，提取关键信息：
- 业务模块名称
- 核心业务流程
- 涉及的页面
- 关键数据要素

#### 2.2 场景拆分

按 [ui-test-design-generate-spec.md#场景拆分原则](../spec/ui-test-design-generate-spec.md#场景拆分原则) 进行场景拆分：

| 需求复杂度 | 场景数 | 说明 |
|-----------|--------|------|
| 简单（单一操作路径） | 1 个场景 | 如"登录功能" |
| 中等（2-3 个操作路径） | 2-3 个场景 | 如"添加/编辑/删除排班" |
| 复杂（多分支、多模块） | 3-5 个场景 | 如"完整的预约挂号流程" |

场景编号按 [ui-test-case-spec.md#场景编号规范](../spec/ui-test-case-spec.md#场景编号规范) 格式：
`<模块缩写>-<序号>`，如 `SCHEDULE-001`、`SCHEDULE-002`

优先级按 [ui-test-case-spec.md#优先级定义](../spec/ui-test-case-spec.md#优先级定义)：
P0（核心路径）、P1（重要功能）、P2（辅助功能/边界条件）

#### 2.3 输出场景设计摘要

```markdown
## 测试场景设计摘要

| 编号 | 场景名称 | 优先级 | 类型 | 前置条件 | 涉及页面 | 数据依赖 |
|------|---------|--------|------|---------|---------|---------|
| SCHEDULE-001 | 添加完整排班时段 | P0 | 功能 | 医生已登录 | 诊室页面、排班弹窗 | 无 |
| SCHEDULE-002 | 删除已有排班 | P0 | 功能 | 存在排班记录 | 诊室页面 | 依赖 SCHEDULE-001 |
```

### 3. 生成测试步骤文档

对每个场景，按照 [ui-test-step-design-spec.md#测试步骤文档结构](../spec/ui-test-step-design-spec.md#测试步骤文档结构) 生成详细的测试步骤文档。

**步骤 3.1 — 页面分段**

分析场景涉及的用户操作，按页面进行分段。每个页面包含：
- 页面名称（与步骤文档中的 `### 页面N: <名称>` 一致）
- 页面 URL 或弹窗定位方式
- 该页面下的操作步骤列表

**步骤 3.2 — 逐步骤设计**

为每个步骤设计以下内容：

| 字段 | 说明 | 生成规则 |
|------|------|---------|
| **步骤编号** | 从 1 开始递增 | 每个页面独立编号 |
| **操作描述** | 具体的用户操作 | 使用清晰的动词+目标描述，如"点击排班管理Tab"、"输入用户名" |
| **测试数据** | 操作所需的数据 | 具体值，如 "dr-zhang-wei"、"09:00" |
| **预期结果** | 操作后的预期状态 | 可验证的描述，如"弹出添加排班对话框" |
| **元素描述** | 目标元素的中文描述 | 用于人工录制时的视觉参照，如"排班管理Tab按钮" |
| **元素定位建议** | 推荐的选择器方向 | 如 `button:contains("排班管理")`、`[role="dialog"]` |

**步骤 3.3 — 标记录制需求**

为每个步骤标记录制需求的紧迫程度：

| 标记 | 含义 | 建议 |
|------|------|------|
| 🔴 **必须录制** | 核心交互步骤，直接影响脚本生成 | 务必录制 |
| 🟡 **建议录制** | 辅助验证步骤，可增强脚本健壮性 | 尽量录制 |
| ⚪ **可选录制** | 等待/加载/纯验证步骤 | 可不录制 |

### 4. 生成录制结构清单（tree.json）

本环节以**原子操作**为最小录制单元，使用工具集脚本生成 `structure/tree.json`，作为录制清单的单一事实来源。

#### 4.1 准备功能清单

在 recording-checklist 工作区（如 `.asdm/workspace/ui-test/<用例名>/recording-checklist/` 或项目根目录的 `recording-checklist/`）创建 `feature-list.txt`，每行一个原子操作：

```
common|登录系统
common|退出登录
project|创建项目
project|删除项目
```

格式：`<模块键>|<原子操作中文描述>`

可用模块键：`common`、`project`、`repository`、`pipeline`、`issue`、`wiki`、`test`、`deploy`、`monitor`、`setting`。

#### 4.2 生成 tree.json

运行工具集脚本：

```bash
# 基础用法
node .asdm/toolsets/ui-automation-testing/scripts/generate-tree.js feature-list.txt <workspace>

# 自定义模块映射
node .asdm/toolsets/ui-automation-testing/scripts/generate-tree.js feature-list.txt <workspace> --module-map=module-map.json
```

- `<workspace>`：recording-checklist 工作区目录路径（可选，默认为当前目录）
- `--module-map=<file>`：自定义模块映射 JSON 文件（可选）
- 输出：`structure/tree.json`

**模块映射加载优先级（后覆盖前）**：
1. 内置默认映射（`00-common` ~ `09-setting`）
2. 工作区已有 `structure/tree.json` 中的模块定义（跟随系统已有结构）
3. `--module-map` 指定的自定义映射文件（最高优先级）

对于未定义的模块键，脚本会自动分配下一个可用的编号目录（如 `10-xxx`、`11-yyy`），无需提前配置。

生成的 `tree.json` 包含：
- 模块分组（如 `00-common`、`01-project`）
- 每个原子操作的文件名、描述、`required` 标记
- `dependencies` / `dependents`：原子操作级依赖与被依赖关系

#### 4.3 录制脚本与原子操作的映射

输出录制脚本与原子操作的对应关系表：

| 录制脚本文件 | 对应原子操作 | 包含步骤数 | 涉及页面 | 前置条件 |
|-------------|-------------|-----------|---------|---------|
| `recordings/01-project/create-project.json` | 创建项目 | N 步 | 项目列表页、创建弹窗 | 已登录 |
| `recordings/01-project/delete-project.json` | 删除项目 | 3 步 | 项目列表页 | 已登录、存在项目 |

### 5. 生成录制清单（Recording Checklist）

基于 `structure/tree.json`，运行工具集脚本生成可视化的录制清单 `recording-checklist.md`，驱动人工录制。这是本动作最关键的产出物。

运行命令：

```bash
node .asdm/toolsets/ui-automation-testing/scripts/check.js <workspace> --all --recordings=<recordings-path>
```

- `<workspace>`：recording-checklist 工作区目录路径（可选，默认为当前目录）
- `--recordings=<path>`：录制文件根目录（可选，默认为 `<workspace>/recordings`）。当实际录制文件位于项目根目录的 `recordings/` 而非 `recording-checklist/recordings/` 时，使用此参数指定
- `--all`：同时更新 `recording-checklist.md` 并生成 HTML 检测报告

#### 5.1 录制总览

`check.js` 生成的 Markdown 包含：

```markdown
## 录制总览

| 模块 | 已录制 | 待补充 | 总计 | 完成度 |
|------|--------|--------|------|--------|
| 公共操作 | 1/3 | 2 | 3 | 33% |
| 项目管理 | 1/5 | 4 | 5 | 20% |
| **合计** | **2/8** | **6** | **8** | **25%** |
```

#### 5.2 原子操作录制指引与录制补完检查表

原子操作录制指引模板和录制补完检查表模板见 [templates/recording-checklist-template.md](../templates/recording-checklist-template.md)。每个原子操作是独立可录制的单元，步骤需**完整、可执行**（面向人工，不使用引用占位）。模板包含：
- **原子操作录制指引**：按"产品功能特性 → 原子操作"组织，含前置状态、保存路径、步骤表格、断言建议、工具操作指引
- **录制补完检查表**：录制脚本补完状态和确认项

### 6. 生成测试数据预填

根据测试步骤文档中的测试数据，生成数据文件骨架（`data/` 目录），供后续 `asdm-ui-test-design-generate` 使用：

**data/accounts.json**（账号数据）：
```json
{
  "doctor": {
    "username": "dr-zhang-wei",
    "password": "<需要补充>"
  }
}
```

**data/business.json**（业务数据）：
```json
{
  "scheduleDate": "<明天日期，动态计算>",
  "startTime": "09:00",
  "endTime": "12:00",
  "maxAppointments": 10
}
```

**data/env.json**（环境配置）：
```json
{
  "baseUrl": "http://localhost:5173",
  "targetUrl": "http://localhost:5173/doctor/room/dr-zhang-wei"
}
```

### 7. 组装输出并写入文件

产出物分两处存放：

**项目根目录（跨用例共享）**：
- `recording-checklist/` — 录制清单工作区（见 `spec/ui-test-step-design-spec.md#产出物目录结构`）
- `recordings/` — 录制文件

**用例文件夹下（用例专属）**：
```
.asdm/workspace/ui-test/<用例名称抽象>_<YYYYMMDDHHmmss>/
├── test-step-design.md              # 测试步骤设计文档（完整的需求→步骤文档）
└── data/                            # 测试数据骨架
    ├── env.json                     # 环境配置（需人工确认）
    ├── accounts.json                # 账号数据（需人工补充密码等敏感信息）
    └── business.json                # 业务数据
```

**工具集脚本引用方式**（默认在项目根目录运行，`<workspace>` 默认为当前目录）：

```bash
# 生成 tree.json（feature-list.txt 需在 recording-checklist/ 下）
node .asdm/toolsets/ui-automation-testing/scripts/generate-tree.js feature-list.txt recording-checklist/

# 检测录制完成度并生成清单（recordings/ 路径自动从 recordings-path 参数推断）
node .asdm/toolsets/ui-automation-testing/scripts/check.js recording-checklist/ --all --recordings=./recordings
```

写入完成后，输出总览摘要。

---

## 输出摘要

输出总览摘要模板见 [templates/summary-template.md](../templates/summary-template.md)。模板包含：
- 场景/页面/步骤数量统计
- 录制清单工作区状态
- 数据骨架文件清单
- 下一步操作指引

---

## Execution Guidelines

### 何时使用本指令

在以下情况使用本指令：
- 有一个新的功能需求（PRD/一句话需求），需要设计 UI 自动化测试
- 需要在人工录制前明确"录什么"，避免录制遗漏或多余操作
- 希望生成的自动化脚本更准确、覆盖率更高

### 设计原则

1. **以用户视角设计步骤**：操作描述使用业务语言，如"点击排班管理Tab"而非"点击 div[3]"
2. **元素描述要可识别**：元素描述要让人工在页面上能直接找到，如"页面右上角的'添加排班'蓝色按钮"
3. **录制粒度适中**：每个录制脚本对应一个**原子操作**，不拆分过细也不合并过多
4. **断言建议要恰当**：在每个关键状态变化点建议添加断言（弹窗出现、数据更新、页面跳转）
5. **依赖操作先录**：有依赖关系的原子操作（如 `login.json` 被多个操作依赖），优先安排在前录制

### 步骤类型与录制优先级

| 步骤类型 | 录制优先级 | 说明 |
|---------|-----------|------|
| 点击交互（按钮/Tab/链接） | 🔴 必须 | 核心操作，必须录制 |
| 输入填充（输入框/选择器） | 🔴 必须 | 数据录入，必须录制 |
| 页面导航 | 🔴 必须 | 页面跳转，必须录制 |
| 验证/断言 | 🟡 建议 | 增强脚本鲁棒性 |
| 等待/加载 | ⚪ 可选 | 可自动处理，不强制录制 |

### 错误处理

参见 [ui-test-step-design-spec.md](#) 中的错误处理规范。常见场景：
- 需求模糊 → 通过澄清环节逐轮提问
- PRD 不存在 → 提示确认路径或改用文本
- 场景过多（>5个） → 合并相似场景，优先覆盖 P0
- 多次澄清仍不明确 → 按合理假设推进，标注"待确认"

---

## Usage

使用本指令时，AI 模型应：

1. 接收用户输入的需求（PRD 文档路径或一句话描述）
2. 读取测试步骤设计规范和测试用例文档规范
3. 分析需求，拆分测试场景
4. 对每个场景生成详细的测试步骤文档（页面分段、操作步骤、元素描述、测试数据）
5. 将场景拆分为**原子操作**，生成 `feature-list.txt`，调用 `scripts/generate-tree.js` 生成 `structure/tree.json`
6. 调用 `scripts/check.js` 扫描录制完成度，生成可视化的录制清单 `recording-checklist.md`
7. 生成测试数据骨架文件
8. 产出物分两处写入：`test-step-design.md` + `data/` 写入 `.asdm/workspace/ui-test/<用例名称抽象>_<时间戳>/`；录制清单相关文件写入项目根目录的 `recording-checklist/` 工作区

### 依赖

依赖与上下文文件已在「Context Injection」中列出，主要包括 `ui-test-step-design-spec.md`、`ui-test-case-spec.md`、`ui-test-data-spec.md` 以及 `scripts/generate-tree.js`、`scripts/check.js`。

### 产出物

产出物规范见 [ui-test-step-design-spec.md#产出物目录结构](../spec/ui-test-step-design-spec.md#产出物目录结构)。

---

## 固化脚本（优先调用，减少 AI 消耗）

本 action 的机械部分已由固化脚本实现，**执行时应优先调用脚本，AI 仅处理需语义判断的部分**（场景拆分、业务模块映射）：

- `scripts/convert-recording.js`：将单个录制 JSON 转换为 `stepDesign.md` + `annotations.json`。
  - 调用：`node scripts/convert-recording.js recordings/<模块>/<文件>.json --out=<用例目录> --case=<名> --index=<场景序号> --module=<模块>`
  - 若 `<用例目录>/annotations.json` 已存在，脚本会**合并**当前场景而不覆盖其他场景。
  - AI 在脚本产出后，仅补充：场景拆分说明、业务模块归属、以及对 ⚠️/❌ 定位状态步骤的人工确认。

---

## 相关规范文档

| 规范文档 | 用途 |
|---------|------|
| [ui-test-step-design-spec.md](../spec/ui-test-step-design-spec.md) | 测试步骤设计规范（模板与格式） |
| [ui-test-case-spec.md](../spec/ui-test-case-spec.md) | 场景编号规范与优先级定义 |
| [ui-test-data-spec.md](../spec/ui-test-data-spec.md) | 测试数据管理规范 |
