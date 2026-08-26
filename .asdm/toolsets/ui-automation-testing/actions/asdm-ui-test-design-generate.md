---
registryId: ui-automation-testing
---
# Instructions for asdm-ui-test-design-generate action

## Purpose

This instruction guides the AI model to design test scenarios and generate test scripts based on **three types of input**: PRD document, requirement description, or direct test case description. For complex requirements, it splits them into multiple scenarios with minimal data dependencies between scenarios. Each scenario produces dual outputs: an **agent-browser script (`.sh`, primary, required)** and a **Playwright script (`.js`, fallback, low priority)**, plus natural-language annotations (`annotations.json`). When recordings are incomplete, it outputs a list of JSON files that need to be supplemented via Chrome DevTools Recorder. A task checklist is output to track progress, with failure reasons noted for any incomplete items.

> **前置依赖**：本 action 依赖 `recordings/` 目录下的录制脚本（Chrome DevTools Recorder JSON）。
> 如果录制脚本尚未准备，建议先运行 `/asdm-ui-test-step-design` 生成测试步骤文档和录制计划，
> 完成人工录制后再运行本 action。更多信息见 [asdm-ui-test-step-design.md](./asdm-ui-test-step-design.md)。

## Language Setting

默认使用**中文（简体中文）**作为输出语言。所有生成的内容均使用中文，并遵循中文写作规范。

如需切换语言，可在工作区根目录创建 `.asdm/config.json` 配置：
```json
{
  "language": "zh"
}
```
支持的语言：`zh`（中文，默认）、`en`（英文）。

## Context Injection

Before designing and generating test scripts, the AI model should read and understand the project context. 按分阶段渐进加载策略读取，避免一次性加载所有文件。

### Progressive Context Loading Strategy

1. **Phase 1 — 录制与已有设计**（MUST be read first）
   - 读取 `recordings/**/*.json`，建立元素定位映射表
   - 若用例文件夹下存在 `test-step-design.md`，以其为场景/步骤单一事实来源（SSoT），直接消费，不再基于需求重新推导

2. **Phase 2 — 工作流规范**（Required - Workflow Standard）
   - 读取 `ui-test-design-generate-spec.md`，了解完整工作流规范（场景设计、定位检测、脚本生成、执行计划、任务清单）

3. **Phase 3 — 按需精读录制**：根据需求涉及模块，精读对应的录制文件内容

4. **Phase 4 — 按需读取其他规范文档**（仅当前步骤需要时读取）：
   - 生成 agent-browser 脚本时 → 读 `ui-test-agent-browser-spec.md`
   - 生成 Playwright 降级脚本时 → 读 `ui-test-script-spec.md`
   - 配置测试数据时 → 读 `ui-test-data-spec.md`
   - 确定编号/优先级时 → 读 `ui-test-case-spec.md`

5. **Phase 5 — 测试风格参考**（Optional）：读取 `tests/**/*.js`，保持脚本风格一致

---

## Steps to Design and Generate Test Scripts

### 1. 接收需求（支持三种输入类型）

本 action 支持以下三种输入类型，AI 模型需自动识别用户输入属于哪种类型并执行对应的处理逻辑：

#### 类型一：PRD 文档路径

用户提供 PRD 文档的文件路径（如 `@./docs/prd-appointment.md`）。

**处理逻辑**：
1. 使用 `read_file` 工具读取 PRD 文档内容
2. 解析 PRD，提取关键信息：业务模块名称、核心业务流程、涉及页面、关键数据要素
3. **先检查当前用例文件夹是否已有 `test-step-design.md`**：若存在，直接以其为场景/步骤设计的单一来源，跳过"基于 PRD 重新设计"；若不存在，再基于 PRD 内容设计测试场景并生成测试步骤文档
4. 对照 `recordings/` 检查已有录制脚本的覆盖情况
5. **仅当存在缺失/无法定位的录制时才生成 `recordings-checklist.json`**；录制完整则不生成该空文件

> **输入示例**：`@c:/Users/xxx/docs/prd-appointment-booking.md`

#### 类型二：需求描述

用户直接输入多段需求文本（内容与 PRD 等价，但以文本形式提供而非文件路径）。

**处理逻辑**：
1. 直接将用户输入的需求文本作为分析依据
2. 解析需求描述，提取关键信息（同类型一）
3. **先检查当前用例文件夹是否已有 `test-step-design.md`**：若存在，直接以其为场景/步骤设计的单一来源，跳过"基于需求重新设计"；若不存在，再基于需求内容设计测试场景并生成测试步骤文档
4. 对照 `recordings/` 检查已有录制脚本覆盖情况
5. **仅当存在缺失/无法定位的录制时才生成 `recordings-checklist.json`**；录制完整则不生成该空文件

> **输入示例**："测试在线预约挂号功能，用户可选择科室、医生、时间段，填写就诊人信息后提交预约"

#### 类型三：测试用例描述

用户直接提供具体的测试用例描述信息，包含明确的场景、步骤和预期结果。

**处理逻辑**：
1. 直接使用用户提供的测试用例描述，跳过 PRD/需求分析阶段
2. 将用户描述的用例结构化（编号、优先级、步骤、预期结果）
3. **若用例文件夹已存在 `test-step-design.md`，以其为步骤明细来源，不再重复结构化**
4. 对照 `recordings/` 检查已有录制脚本覆盖情况
5. **仅当存在缺失/无法定位的录制时才生成 `recordings-checklist.json`**；录制完整则不生成该空文件
6. 对已有完整录制的场景直接生成脚本

> **输入示例**：
> ```
> 场景1：正常预约挂号
>   - 搜索"内科"科室
>   - 选择医生"张三"
>   - 选择日期"2026-07-23"
>   - 选择时间段"09:00-09:30"
>   - 填写就诊人"李四"
>   - 提交预约 → 预期：显示"预约成功"
>
> 场景2：预约当天号源已满
>   - 搜索已满科室
>   - 预期：显示"号源已满"提示
> ```

#### 通用判断与兜底

- 如果用户提供的需求过于模糊（无法确定页面、操作流程、场景），引导用户补充关键信息：
  - **目标页面/模块**：被测功能的名称和菜单路径
  - **核心操作流程**：用户的主要操作路径
  - **测试场景**：需要覆盖哪些场景（正常流程、异常流程、边界条件）
  - **测试环境**：URL、账号等

### 2. 分析需求与场景拆分

根据需求复杂度进行场景分析和拆分。

**拆分原则**：参见 [ui-test-design-generate-spec.md#场景拆分原则](../spec/ui-test-design-generate-spec.md#场景拆分原则)

**场景设计要素**：每个场景需包含场景名称、编号、优先级、测试类型、前置条件、测试步骤、预期结果、测试数据。详细定义参见 [ui-test-design-generate-spec.md#场景设计要素](../spec/ui-test-design-generate-spec.md#场景设计要素)。场景编号规范参见 [ui-test-case-spec.md#场景编号规范](../spec/ui-test-case-spec.md#场景编号规范)，优先级定义参见 [ui-test-case-spec.md#优先级定义](../spec/ui-test-case-spec.md#优先级定义)。

**输出格式**：按 [ui-test-design-generate-spec.md#场景设计摘要输出格式](../spec/ui-test-design-generate-spec.md#场景设计摘要输出格式) 输出场景设计摘要表格。

### 3. 检测元素定位

对每个场景，逐一检测是否能够确定所有操作步骤所需的元素定位。

**录制文件检查**：参见 [ui-test-design-generate-spec.md#录制文件检查规范](../spec/ui-test-design-generate-spec.md#录制文件检查规范)

**场景-录制步骤匹配**：参见 [ui-test-design-generate-spec.md#场景-录制步骤匹配规范](../spec/ui-test-design-generate-spec.md#场景-录制步骤匹配规范)

**定位可用性判定**：按 ✅/⚠️/❌ 三重标准判定，详见 [ui-test-design-generate-spec.md#定位可用性判定标准](../spec/ui-test-design-generate-spec.md#定位可用性判定标准)

**输出格式**：按 [ui-test-design-generate-spec.md#元素定位检测报告输出格式](../spec/ui-test-design-generate-spec.md#元素定位检测报告输出格式) 输出检测报告。

### 4. 反馈与补充录制

如果元素定位检测发现无法定位的步骤（状态为 ❌ 或 ⚠️），需要向用户反馈。

**反馈格式**：按 [ui-test-design-generate-spec.md#反馈内容格式](../spec/ui-test-design-generate-spec.md#反馈内容格式) 输出定位缺失反馈。

**处理策略**：按 [ui-test-design-generate-spec.md#处理策略](../spec/ui-test-design-generate-spec.md#处理策略) 分情况处理：
- 部分可定位 → 先生成可定位场景的脚本，不可定位的输出反馈
- 全部不可定位 → 仅输出反馈，不生成脚本
- 全部可定位 → 跳过反馈，直接进入脚本生成

### 5. 生成测试脚本（双产物）

#### 5a. 生成数据集脚手架（机械，优先调用固化脚本）

先调用 `scripts/bootstrap-scenario.js` 机械创建用例文件夹与脚本/数据骨架，**避免 AI 逐文件手工创建**：

```bash
# 方式一：从录制清单 tree.json 自动推导场景
node .asdm/toolsets/ui-automation-testing/scripts/bootstrap-scenario.js \
  --case=<用例名> --from-tree=recording-checklist/structure/tree.json [--base-url=<被测URL>]

# 方式二：从显式场景清单 JSON 推导
node .asdm/toolsets/ui-automation-testing/scripts/bootstrap-scenario.js \
  --case=<用例名> --manifest=<场景清单>.json [--base-url=<被测URL>]
```

脚本产出 `.asdm/workspace/ui-test/<用例名>_<时间戳>/`，含：
- `data/{env.json, accounts.json, business.json, variables.js}` 骨架
- 每个场景的 `NN-<模块>-<场景>.sh`（agent-browser 主产物骨架，内置 `set -e`/`[EXEC:START]`/`[EXEC:END]` 标记）与 `NN-<模块>-<场景>.js`（Playwright 降级骨架）

> AI 后续**只需在 `.sh` 骨架内填充业务步骤**（`# @step` + `# Recorder selectors:`），不重写脚手架与数据文件结构；场景序号与依赖顺序由脚本按 `tree.json`/清单自动编排。

对每个定位可用（✅）的场景，在脚手架基础上补充两个脚本产物（而非从零创建）：

- **agent-browser 脚本（主产物，必须）**：按 [ui-test-agent-browser-spec.md](../spec/ui-test-agent-browser-spec.md) 在 `.sh` 骨架填充 `<模块>-<场景简称>.sh`
- **Playwright 脚本（降级产物，低优先级）**：按 [ui-test-design-generate-spec.md#脚本模板](../spec/ui-test-design-generate-spec.md#脚本模板) 在 `.js` 骨架填充 `<模块>-<场景简称>.js`

**生成原则**：参见 [ui-test-design-generate-spec.md#脚本生成原则](../spec/ui-test-design-generate-spec.md#脚本生成原则)

**存放路径**：遵循 [ui-test-design-generate-spec.md#脚本存放路径规范](../spec/ui-test-design-generate-spec.md#脚本存放路径规范)，所有脚本存放在 `.asdm/workspace/ui-test/<用例名称抽象>_<时间戳>/` 目录下。

**选择器转换**：从录制文件提取选择器时，严格按 [ui-test-design-generate-spec.md#录制选择器转换规范](../spec/ui-test-design-generate-spec.md#录制选择器转换规范) 的优先级和规则进行转换。通用选择器规范参考 [ui-test-script-spec.md#选择器规范](../spec/ui-test-script-spec.md#选择器规范)。

**原始选择器保留**：每个步骤转换后，在 `@step` 注释之后追加 `# Recorder selectors:` 注释块，将该步骤在录制 JSON 中 `selectors` 数组的全部选择器逐行列出来。即便最终脚本未使用某些选择器（如只用了 CSS 而没用到 `aria/`），也要全部列出。断言的原始选择器同样保留。

**断言保留**：录制 json 中的断言步骤必须全部转换到脚本中，不得丢失；丢失视为该场景生成失败，在任务清单备注原因。

**数据分离**：账号、URL、业务值从 `data/` 数据文件读取（`env.json` / `accounts.json` / `business.json`），按 [ui-test-data-spec.md](../spec/ui-test-data-spec.md) 生成或复用数据文件，脚本中禁止硬编码。

### 5b. 生成自然语言标注（annotations.json）

为每个步骤生成中文语义描述，写入用例文件夹下的 `annotations.json`，格式见 [ui-test-design-generate-spec.md#自然语言标注规范](../spec/ui-test-design-generate-spec.md#自然语言标注规范)。标注是保鲜指令 AI 自愈的关键输入。

### 6. 生成总体文档（overview.md）

所有脚本生成完成后，生成一份总体 MD 文档，作为该测试用例的概览入口。

**文档模板**：按 [ui-test-design-generate-spec.md#总体文档模板](../spec/ui-test-design-generate-spec.md#总体文档模板) 生成，包含以下五个章节：

> **避免重复原则**：`overview.md` 是概览入口，**不重复罗列已在 `test-step-design.md`（若存在）或 `annotations.json` 中完整记录的操作步骤明细**。场景设计摘要、元素定位详情等章节按规范引用上述文件，仅补充本阶段独有的"来源录制文件 / 定位状态 / 执行顺序 / 任务清单"等信息。

1. **测试场景设计**：场景划分说明 + 场景设计摘要表格（格式参考 [场景设计摘要输出格式](../spec/ui-test-design-generate-spec.md#场景设计摘要输出格式)）
   - **重要：每个场景必须在表格中关联其来源录制脚本文件路径（sourceRecording）**
2. **元素定位检测报告**：检测概况 + 各场景定位详情（格式参考 [元素定位检测报告输出格式](../spec/ui-test-design-generate-spec.md#元素定位检测报告输出格式)）
   - **重要：各场景定位详情中必须标明该场景引用的录制文件路径**
3. **定位缺失反馈**（如有）：缺失录制脚本清单和操作指引（格式参考 [反馈内容格式](../spec/ui-test-design-generate-spec.md#反馈内容格式)）
4. **执行计划**：脚本执行顺序 + 变量传递说明（格式参考 [执行计划输出格式](../spec/ui-test-design-generate-spec.md#执行计划输出格式)）
   - **重要：执行顺序表格中必须注明各场景的来源录制文件**
5. **任务清单**：三阶段任务清单（格式参考 [任务清单格式](../spec/ui-test-design-generate-spec.md#任务清单格式)）
   - **重要：阶段 2 场景脚本生成表格中必须注明各场景关联的录制文件**

**存放路径**：与脚本同级，存放在 `.asdm/workspace/ui-test/<用例名称抽象>_<时间戳>/overview.md`，详见 [总体文档路径](../spec/ui-test-design-generate-spec.md#总体文档路径)。

**任务清单中的失败原因**：未完成项必须按 [ui-test-design-generate-spec.md#失败原因规范](../spec/ui-test-design-generate-spec.md#失败原因规范) 备注失败原因和建议操作。

### 6b. 数据集校验（机械，优先调用固化脚本）

脚本与 `overview.md` 生成后，调用 `scripts/lint-dataset.js` 机械校验数据集是否符合规范：

```bash
node .asdm/toolsets/ui-automation-testing/scripts/lint-dataset.js <用例名或前缀>
```

- 校验项：文件夹命名、overview.md 执行计划、`data/*.json` 合法性、`annotations.json` 完整性与步骤字段、`.sh` 骨架标记（`set -e`/`[EXEC:START]`/`[EXEC:END]`/`@step`）、录制源存在性。
- 脚本以退出码 1 表示存在错误。**AI 仅处理 ❌ 错误项**（如缺失的 `steps`、`expectedResult`、`recordingStepIndex`），⚠️ 警告可标注后交人工审阅。

### 7. 输出审阅提示

所有产出物写入完成后，在输出摘要中明确提示用户执行 **人工审阅** 后再运行 `/asdm-ui-test-run`，审阅清单见 [下一步：人工审阅](#下一步人工审阅生成后的必要步骤)。输出格式：

```
✅ 脚本生成完成！生成路径：.asdm/workspace/ui-test/<用例名>_<时间戳>/

⚠️ 请先完成以下人工审阅后再运行 /asdm-ui-test-run：
  1. 确认 data/accounts.json 中的账号密码是否有效（AI 生成的密码可能为示例值）
  2. 审阅 annotations.json 中的步骤描述和预期结果是否准确
  3. 确认脚本中中文按钮选择器是否已使用 CSS 而非 find role --name
  4. 审阅确认后，执行：/asdm-ui-test-run <用例名>
```

---

## Execution Guidelines

### When to Use This Action

Use this action when:
- 用户提供了 UI 自动化测试的需求（PRD 文档路径 / 需求描述文本 / 测试用例描述）
- 需要从需求直接生成可执行的 Playwright 测试脚本
- 需要检测元素定位的完整性并给出补充录制建议
- 复杂需求需要拆分为多个独立场景

### Design Guidelines

场景设计时需遵循 [ui-test-design-generate-spec.md#场景拆分原则](../spec/ui-test-design-generate-spec.md#场景拆分原则)：
1. **最小依赖原则**：每个场景的数据相关性越小越好，场景之间尽量独立运行
2. **路径覆盖**：优先覆盖核心路径（P0），其次覆盖异常路径（P1），最后覆盖边界条件（P2）
3. **可追溯性**：每个场景都要有明确的编号、步骤和预期结果
4. **录制脚本驱动**：场景设计必须基于已有的录制脚本，避免凭空假设页面元素

### Script Generation Guidelines

脚本生成时需遵循 [ui-test-design-generate-spec.md#脚本生成原则](../spec/ui-test-design-generate-spec.md#脚本生成原则)：
1. **选择器优先级**：严格按 [ui-test-design-generate-spec.md#录制选择器转换规范](../spec/ui-test-design-generate-spec.md#录制选择器转换规范) 转换
2. **错误处理**：每个脚本必须包含 try-catch，输出明确的成功/失败信息
3. **可维护性**：使用有意义的注释和变量名，标注每个步骤
4. **独立性**：脚本可单独运行，不依赖其他脚本的执行结果

### 脚本生成经验要点（实践总结）

生成 agent-browser `.sh` 脚本时，以下为本次对话中验证的关键要点：

**选择器转换要点**：
- `aria/` 和 `text/` 前缀 **不是有效 CSS 选择器**，`agent-browser click "aria/xxx"` 会报 `Element not found`。
- 输入框 → 用 `agent-browser find placeholder 'xxx' fill '值'`
- 按钮（中文/提交类） → **优先用录制中的 CSS 选择器**如 `click "button.bg-brand-600"`（`find role --name '中文'` 常 `✓ Done` 不触发）
- 按钮（英文/纯字母） → 用 `agent-browser find role button click --name '确定'`
- 文本元素 → 用 `agent-browser find text '文字' click`
- 下拉框 → 用 `agent-browser select 'CSS选择器' '值'`（`change` 命令不存在）
- 复选框 → 用录制中的 CSS 备选选择器如 `form > div > div.flex input`（`find role checkbox` 常失效）

**易错点（常见问题速查表详见 [ui-test-agent-browser-spec.md#选择器转换规范](../spec/ui-test-agent-browser-spec.md#选择器转换规范)）**：
- **`find role button click --name` 提交不触发**：`✓ Done` 但弹窗不关闭、表单不提交→改为 `click "button.bg-brand-600"`
- **`find role link click --name '中文'` 找不到**：中文匹配不稳定→改为 CSS 选择器如 `li:nth-of-type(N) > a`
- **`--headed` daemon 冲突**：仅脚本内失败、手动执行成功→只给第一个 `open` 加 `--headed`，后续命令去掉

**冗余步骤处理**：
- URL 中已含 tab 参数（如 `?tab=Users`）时，页面加载后该 Tab 已激活，不要再添加 Tab 点击步骤（`find role button` 找不到已激活按钮）

**脚本命名**：
- 文件名加两位数序号前缀：`01-模块-场景简称.sh`、`02-模块-场景简称.sh`...
- 序号按执行顺序编排（有依赖的场景按依赖链排列）

**数据读取（Windows Git Bash 兼容）**：
- 路径必须使用 `cygpath -m` 转换：`$(node -e "console.log(require('$(cygpath -m ${DATA_DIR}/xxx.json)').xxx)")`
- 直接 `require('${DATA_DIR}/...')` 在 Git Bash 中不可用（Unix 路径不被 Node.js 识别）

### Error Handling

| 错误情况 | 处理方式 |
|---------|---------|
| 需求输入无法识别为三种类型之一 | 提示用户明确输入类型：PRD 文档路径、需求描述文本或测试用例描述 |
| 无录制文件 | 提示用户先进行录制，输出待补充录制 JSON 清单，不生成脚本 |
| 录制文件选择器不完整 | 标记为 ⚠️，尝试用备选选择器生成，但标注风险 |
| 场景所有步骤均无法定位 | 标记为 ❌，按 [反馈内容格式](../spec/ui-test-design-generate-spec.md#反馈内容格式) 反馈并暂停该场景 |
| 录制文件 JSON 解析失败 | 报告错误，建议用户重新录制 |
| 脚本写入文件失败 | 报告错误路径和原因 |

---

## Usage

执行流程按上述「Steps to Design and Generate Test Scripts」中的步骤 1-8 依次执行。关键要点：
- `recordings-checklist.json` 仅在检测到缺失录制时生成，完整时跳过
- 步骤 5a **优先调用 `scripts/bootstrap-scenario.js`** 生成数据集脚手架；步骤 6b **调用 `scripts/lint-dataset.js`** 校验
- 所有产出物写入 `.asdm/workspace/ui-test/<用例名称抽象>_<时间戳>/`

---

## Output Summary

After completing the design and generation, the following artifacts will be generated under `.asdm/workspace/ui-test/<用例名称抽象>_<时间戳>/`：

```
.asdm/workspace/ui-test/<用例名称抽象>_<YYYYMMDDHHmmss>/
├── overview.md                      # 总体文档（场景设计 + 检测报告 + 反馈 + 执行计划 + 任务清单）
├── annotations.json                 # 步骤自然语言标注（供保鲜指令自愈）
├── data/                            # 测试数据（env.json / accounts.json / business.json）
├── data.json                        # 场景间变量共享存储文件（如无依赖则不需要）
├── recordings-checklist.json        # 待补充录制 JSON 清单（仅当存在缺失录制时生成；录制完整则不生成）
├── <模块>-<场景简称>.sh              # agent-browser 场景脚本（主产物）
├── <模块>-<场景简称>.js              # Playwright 场景脚本（降级产物）
└── ...
```

各产出物的说明与参考规范详见 [ui-test-design-generate-spec.md](../spec/ui-test-design-generate-spec.md)。

> **路径规范**：详见 [脚本存放路径规范](../spec/ui-test-design-generate-spec.md#脚本存放路径规范)

---

## 下一步：人工审阅（生成后的必要步骤）

脚本生成完毕 **不可直接执行**，需人工审阅以下内容后，再运行 `/asdm-ui-test-run`：

### 1. 测试数据审阅（data/）

| 文件 | 审阅要点 |
|------|---------|
| `data/accounts.json` | **密码等敏感信息是否准确**；账号在当前环境是否有效；是否需要补充更多账号 |
| `data/env.json` | 环境 URL、timeout等配置是否正确 |
| `data/business.json` | 业务数据（如组织名、项目名）是否符合本次测试预期；依赖关系是否准确 |

> ⚠️ AI 生成的 `accounts.json` 中的密码字段可能为占位值或示例值，**必须由人工确认后**再执行脚本。

### 2. 自然语言标注审阅（annotations.json）

| 审阅项 | 说明 |
|--------|------|
| 步骤描述是否准确 | `annotations.json` 中每个步骤的 `description` 字段是否与实际操作一致 |
| 期望结果是否合理 | `expectedResult` 是否反映了正确的预期状态 |
| 断言标记是否完整 | `isAssertion` 为 true 的步骤是否覆盖了所有关键校验点 |

### 3. 脚本选择器确认（*.sh）

| 审阅项 | 说明 |
|--------|------|
| 中文按钮选择器 | 脚本中对中文提交按钮是否已使用 CSS 选择器（如 `button.bg-brand-600`）而非 `find role --name`（后者常 `✓ Done` 但不触发），如未使用建议在运行前手动调整 |
| `# Recorder selectors:` 注释 | 脚本中是否包含录制原始选择器注释，便于执行时自愈 |

### 4. 审阅完成确认清单

- [ ] `data/` 目录下的测试数据已确认（尤其是账号密码）
- [ ] `annotations.json` 中的步骤描述和预期结果已审阅
- [ ] 脚本中的选择器已确认无误（中文按钮等关键选择器）
- [ ] 确认完毕后，运行 `/asdm-ui-test-run` 执行测试

---

## 固化脚本（优先调用，减少 AI 消耗）

本 action 的机械部分已由固化脚本实现，**执行时应优先调用脚本，AI 仅处理需语义判断的部分**（选择器转换、业务步骤逻辑、断言文案、自愈）：

- `scripts/bootstrap-scenario.js`：机械搭建用例数据集脚手架（文件夹 + `data/` + `.sh`/`.js` 骨架），按 `tree.json` 或场景清单自动编排场景序号与依赖。AI 仅填充业务步骤，不手工创建文件结构。
  - 调用：`node scripts/bootstrap-scenario.js --case=<用例名> --from-tree=recording-checklist/structure/tree.json [--base-url=<URL>]`
- `scripts/lint-dataset.js`：机械校验数据集是否符合规范（命名、overview.md、data JSON、annotations.json 完整性、`.sh` 标记、录制源存在性），退出码 1 表示存在错误。AI 仅处理 ❌ 错误项，⚠️ 警告可交人工审阅。
  - 调用：`node scripts/lint-dataset.js <用例名或前缀>`
- `scripts/convert-recording.js`（在 step-design 阶段调用）：将录制 JSON 转换为 `annotations.json` 步骤标注，本 action 直接消费其产物，无需重新解析录制。

---

## 相关规范文档

| 规范文档 | 用途 |
|---------|------|
| [ui-test-design-generate-spec.md](../spec/ui-test-design-generate-spec.md) | 设计与脚本生成工作流规范（场景拆分、定位检测、脚本生成、任务清单） |
| [ui-test-agent-browser-spec.md](../spec/ui-test-agent-browser-spec.md) | agent-browser 脚本规范（主产物） |
| [ui-test-data-spec.md](../spec/ui-test-data-spec.md) | 测试数据管理规范 |
| [ui-test-case-spec.md](../spec/ui-test-case-spec.md) | UI 测试用例文档模板规范 |
| [ui-test-script-spec.md](../spec/ui-test-script-spec.md) | Playwright 降级脚本代码规范 |
