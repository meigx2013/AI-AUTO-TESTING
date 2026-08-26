# 设计与脚本生成工作流规范

## 概述

本规范定义了 `/asdm-ui-test-design-generate` action 的工作流标准，涵盖场景设计、元素定位检测、脚本生成、执行计划和任务清单输出的规范与模板。

脚本采用双产物策略：**agent-browser 脚本（`.sh`）为主产物（必须生成）**，**Playwright 脚本（`.js`）为降级产物（低优先级）**；同时产出自然语言标注（`annotations.json`）支撑后续 AI 维护。录制脚本来源为 Chrome Dev Tools Recorder 导出的 json（归档于 `recordings/`），是唯一的脚本来源。

## 场景设计规范

### 场景拆分原则

根据需求复杂度进行场景拆分：

- **简单需求**（单一操作路径）：1 个场景即可
- **中等需求**（2-3 个操作路径）：拆分 2-3 个场景
- **复杂需求**（多分支、多模块）：拆分 3-5 个场景
- **核心原则**：每个场景之间的数据相关性越小越好，尽量做到场景独立可运行

### 输入来源（单一事实来源 SSoT）

为避免过度生成、重复产出文档，场景与步骤设计必须遵循以下输入优先级：

1. **前置步骤已产出 `test-step-design.md` 时**：本阶段**必须直接消费**该文档中的场景拆分、步骤描述、元素描述、测试数据映射，作为场景/步骤设计的**唯一事实来源**，**禁止基于需求重新推导一遍**（否则会与 `test-step-design.md` 重复）。
2. **仅当用户未运行 `/asdm-ui-test-step-design`（用例文件夹下无 `test-step-design.md`）时**：才基于需求/PRD/用例描述独立设计场景与步骤。
3. 录制文件的真实路径以 `recordings/` 目录中实际存在的文件为准，不依赖任何文档中计划的文件名。

### 场景设计要素

每个场景需明确以下要素：

| 要素 | 说明 |
|------|------|
| 场景名称 | 简明的中文描述 |
| 场景编号 | `<模块缩写>-<序号>`，如 `LOGIN-001`（参见 [ui-test-case-spec.md#场景编号规范](./ui-test-case-spec.md#场景编号规范)） |
| 优先级 | P0（核心路径）/ P1（重要功能）/ P2（边界条件）（参见 [ui-test-case-spec.md#优先级定义](./ui-test-case-spec.md#优先级定义)） |
| 测试类型 | 功能测试 / UI 测试 / 异常测试 |
| 前置条件 | 场景运行前需要满足的状态 |
| 测试步骤 | 具体的操作流程 |
| 预期结果 | 断言验证点 |
| 测试数据 | 需要的输入数据 |

### 登录保障模式

#### 设计原则

凡测试用例涉及登陆态操作，必须将**登录检测与登录**作为**第一个场景**（编号 `AUTH-001` 或 `场景缩写-001`，优先级 P0），排在所有业务场景之前。后续场景默认登录态已在首个场景中保障，**不再内嵌登录检测逻辑**。

#### 登录检测信号（三路探测）

`ensure_login` 函数使用三级信号判断登录态，按优先级依次检查：

| 优先级 | 信号 | 检查方式 | 结论 |
|--------|------|---------|------|
| 1 | Cookie 中存在会话类键名 | `document.cookie` / `page.context().cookies()` 匹配 `session\|sid\|token\|auth\|jwt\|connect.sid` | ✅ 已登录，跳过 |
| 2 | 页面标题含 "Sign" | `document.title` 匹配 `sign` | ❌ 未登录，执行登录流程 |
| 3（兜底） | URL 含 "signin" | `window.location.href` 匹配 `signin` | ❌ 未登录，执行登录流程 |

**任何信号吻合即触发对应结论**，互不冲突。

#### 执行流程

```text
agent-browser open "${BASE_URL}/"
  ├─ cookie 检测到会话键名 → [SKIP] 已登录
  ├─ cookie 空 → 检查页面标题/URL
  │   ├─ 标题含 "Sign" 或 URL 含 "signin" → [NEED] 在当前页直接填写表单登录
  │   └─ 标题不含 "Sign" 且 URL 不含 "signin" → [SKIP] HttpOnly cookie，视为已登录
```

> **不重复导航**：登录页可能在根路径 `/` 直接渲染（无 URL 重定向），也可能通过 `/signin` 提供。检测到登录页后，**直接在当前页面填写表单登录**，不再执行 `agent-browser open signinUrl` 二次导航（避免打开新窗口/丢失会话）。

#### 脚本实现

agent-browser 主产物脚本的标准实现见 [ui-test-agent-browser-spec.md#登录保障模式](./ui-test-agent-browser-spec.md#登录保障模式)。

#### 场景执行顺序

```
01-用户与登录-登录保障.sh    ← 首个场景：三路探测 + 登录
02-业务模块-场景一.sh        ← 后续场景：无登录检测
03-业务模块-场景二.sh        ← 后续场景：无登录检测
```

> **注意**：`agent-browser` daemon 每次 `bash <脚本>.sh` 为独立进程，cookie 不跨脚本共享。运行框架（`asdm-ui-test-run`）应在同一 daemon 会话中依次执行所有脚本，或利用 `agent-browser` 的持久化 session 机制确保后续脚本复用一个已登录的浏览器实例。具体实现见 [ui-test-run-report-spec.md](../spec/ui-test-run-report-spec.md)。

### 场景设计摘要输出格式

场景设计完成后，以 Markdown 表格输出所有场景的设计摘要：

```markdown
## 测试场景设计摘要

| 编号 | 场景名称 | 优先级 | 类型 | 数据依赖 | 脚本文件 | 来源录制文件 |
|------|---------|--------|------|---------|---------|-------------|
| LOGIN-001 | 正常登录 | P0 | 功能 | 无 | 登录-正常登录.js | recordings/登录/登录-正常登录.json |
| LOGIN-002 | 密码错误 | P1 | 异常 | 无 | 登录-密码错误.js | recordings/登录/登录-密码错误.json |
```

---

## 元素定位检测规范

### 录制文件检查规范

对 `recordings/` 目录下的录制文件进行检查：

1. 遍历 `recordings/` 目录，查找与当前需求模块相关的录制文件（`.json`）
2. 从录制文件的 `steps` 数组中提取每个操作步骤的 `selectors`
3. 录制文件中的 selectors 格式为多重选择器数组，通常包含四类：`aria/<描述>`、CSS 选择器、`xpath/...`、`pierce/...`

### 场景-录制步骤匹配规范

对每个场景的每个测试步骤，按以下维度匹配：

1. **操作类型匹配**：录制步骤的 `type` 字段对应测试步骤的操作类型
   | 录制 type | 测试步骤操作类型 |
   |-----------|----------------|
   | `navigate` | 页面导航 |
   | `click` | 点击操作 |
   | `change` | 输入/修改值 |
   | `keyDown` / `keyUp` | 键盘操作 |

2. **目标元素匹配**：录制步骤 selectors 中的 aria label 或 CSS 选择器对应测试步骤的目标元素

3. **选择器完整性验证**：确认录制步骤覆盖了测试场景所需的全部操作

### 定位可用性判定标准

对每个步骤的定位可用性按以下标准判定：

| 状态 | 标识 | 判定条件 |
|------|------|---------|
| 可直接定位 | ✅ | 录制文件中存在匹配的 selectors，且至少有 `aria/...` 或稳定的 CSS 选择器 |
| 需确认定位 | ⚠️ | 录制文件中存在匹配的 selectors，但仅有 `xpath/...` 或 `pierce/...` 等不稳定选择器 |
| 无法定位 | ❌ | 录制文件中没有对应的录制步骤 |

### 元素定位检测报告输出格式

```markdown
## 元素定位检测报告

### 场景：<场景编号> <场景名称>（来源录制：`recordings/<模块>/<录制文件名>.json`）

| 步骤 | 操作描述 | 目标元素 | 定位状态 | 可用选择器 | 来源录制步骤索引 |
|------|---------|---------|---------|-----------|----------------|
| 1 | <操作> | <元素> | ✅/⚠️/❌ | <选择器或 —> | <recordingStepIndex> |

**定位覆盖率**：<已定位数>/<总步骤数>（<百分比>%）
```

---

## 定位缺失反馈规范

### 反馈内容格式

当存在无法定位的步骤（❌ 或 ⚠️）时，按以下格式向用户反馈：

```markdown
## 定位缺失反馈

以下场景的元素定位无法确定，需要补充/更新录制脚本后才能生成测试脚本：

### 需要更新的录制脚本

| 录制脚本文件 | 缺失的场景 | 缺失步骤 | 建议操作 |
|-------------|-----------|---------|---------|
| `<文件路径>` | `<场景编号>` | <步骤描述> | <建议操作> |

### 操作指引

请使用 Chrome Dev Tools Recorder 执行以下操作以生成录制脚本：

1. **补充录制 - <场景名>**
   - 在 Chrome 中导航到目标页面
   - 打开 DevTools → Recorder 面板，新建录制并开始录制
   - 执行完整操作流程（可加入断言步骤）
   - 停止录制后导出为 json
   - 将录制结果保存到 `recordings/<模块>/<模块>-<场景简称>.json`

2. **新建录制 - <场景名>**
   - 同上步骤

> 录制完成后，请重新运行本指令以继续生成测试脚本。
```

### 处理策略

| 情况 | 处理方式 |
|------|---------|
| 部分场景可定位，部分不可定位 | 先为可定位的场景生成脚本；对不可定位的场景输出反馈，在任务清单中标记失败原因 |
| 全部场景不可定位 | 仅输出完整反馈，不生成任何脚本；在任务清单中标记所有场景为"待补充录制" |
| 全部场景可定位 | 跳过反馈步骤，直接进入脚本生成 |

---

## 脚本生成规范

### 脚本生成原则

1. 每个场景生成两个产物：
   - **agent-browser 脚本（`.sh`）— 主产物，必须生成**，规范见 [ui-test-agent-browser-spec.md](./ui-test-agent-browser-spec.md)
   - **Playwright 脚本（`.js`）— 降级产物，低优先级**，在用户明确要求或 agent-browser 不可用时生成，规范见 [ui-test-script-spec.md](./ui-test-script-spec.md)
2. 每个脚本包含完整的错误处理和友好的控制台输出
3. 脚本之间完全独立，数据相关性越小越好
4. **断言不丢失**：录制 json 中包含的断言步骤必须全部转换到脚本中；任一断言丢失视为该场景生成失败，在任务清单中备注原因（转换方式见 [ui-test-agent-browser-spec.md#断言转换规范](./ui-test-agent-browser-spec.md#断言转换规范)）
5. **数据与脚本分离**：账号、URL、业务值从 `data/` 数据文件读取，禁止硬编码（见 [ui-test-data-spec.md](./ui-test-data-spec.md)）
6. **自然语言标注**：转换时为每个步骤生成中文语义描述，写入脚本注释与 `annotations.json`（见 [自然语言标注规范](#自然语言标注规范)）
7. **原始选择器保留**：转换时在每个步骤的 `@step` 注释之后，以 `# Recorder selectors:` 注释块将录制 JSON 中该步骤的全部原始选择器（`selectors` 数组）逐行列出。支持 AI 在脚本执行失败时直接参考原始选择器备选方案进行自愈，无需回读录制文件

### 脚本存放路径规范

所有测试脚本存放在 `.asdm/workspace/ui-test/` 下，以测试用例名称抽象出文件夹名并附带时间戳：

```
.asdm/workspace/ui-test/<用例名称抽象>_<YYYYMMDDHHmmss>/
```

目录结构示例：

```
.asdm/workspace/ui-test/
└── 用户登录功能测试_20260716143022/
    ├── overview.md                          # 总体文档
    ├── annotations.json                     # 步骤自然语言标注（供保鲜自愈）
    ├── data/                                # 测试数据（见 ui-test-data-spec.md）
    │   ├── env.json
    │   ├── accounts.json
    │   └── business.json
    ├── data.json                            # 场景间变量共享存储（如有场景间依赖）
    ├── recordings-checklist.json            # 待补充录制 JSON 清单（★条件产出：仅当存在缺失/无法定位的录制时生成；全部可定位且无缺失时不生成此文件，避免空 []）
    ├── 登录-正常登录.sh                      # agent-browser 脚本（主产物）
    ├── 登录-正常登录.js                      # Playwright 脚本（降级产物）
    ├── 登录-密码错误.sh
    └── 登录-密码错误.js
```

**命名规则**：
- `<用例名称抽象>`：从用户需求中提炼的核心关键词，如 `用户登录功能测试`、`购物车完整流程`
- `<YYYYMMDDHHmmss>`：生成时刻的时间戳，精确到秒，如 `20260716143022`
- 每个测试用例的所有输出内容（总体文档 + 标注 + 数据 + 所有场景脚本）均存放在同一个用例文件夹下
- agent-browser 脚本与 Playwright 降级脚本同基名，扩展名区分 `.sh` / `.js`
- **脚本文件名加序号前缀**：按执行顺序编号为 `01-`、`02-`...（如 `01-登录-正常登录.sh`、`02-登录-密码错误.sh`），便于文件系统排序和人工按序执行

### 脚本模板

**agent-browser 脚本（主产物）**：模板与格式要素见 [ui-test-agent-browser-spec.md#脚本模板](./ui-test-agent-browser-spec.md#脚本模板)。

**Playwright 脚本（降级产物）**：模板见 [templates/playwright-script-template.js](../templates/playwright-script-template.js)。

### 录制选择器转换规范

从录制文件 `selectors` 数组提取优先选择器，按以下优先级转换。

⚠️ **重要**：agent-browser 的 `click`/`type` 命令只接受 **CSS 选择器**，不接受 `aria/` 或 `text/` 前缀。录制中的 `aria/xxx` 必须转为 `agent-browser find` 命令（详见 [ui-test-agent-browser-spec.md#find 命令用法速查](./ui-test-agent-browser-spec.md#find-命令用法速查)）。**切勿直接写 `agent-browser click "aria/xxx"`，这会导致 `Element not found` 错误。**

agent-browser 脚本的转换目标见 [ui-test-agent-browser-spec.md#选择器转换规范](./ui-test-agent-browser-spec.md#选择器转换规范)；Playwright 降级脚本的转换目标如下：

| 优先级 | 录制文件 selectors 示例 | Playwright 转换目标 |
|--------|----------------------|---------|
| 1（最优先） | `["aria/请输入邮箱地址"]` | `page.getByPlaceholder('请输入邮箱地址')` |
| 1 | `["aria/登录"]` | `page.getByRole('button', { name: '登录' })` |
| 1 | `["aria/请输入您的密码"]` | `page.getByPlaceholder('请输入您的密码')` |
| 2 | `["form button"]` | `page.locator('form button')` |
| 2 | `["input[type=\"password\"]"]` | `page.locator('input[type="password"]')` |
| 3 | `["xpath///*[@id=\"root\"]/..."]` | `page.locator('xpath=...')`（仅作备选） |

**转换规则**：
- `aria/<文本>` 且元素为输入框 → `page.getByPlaceholder('<文本>')` 或 `page.getByLabel('<文本>')`
- `aria/<文本>` 且元素为按钮 → `page.getByRole('button', { name: '<文本>' })`
- CSS 选择器 → `page.locator('<css>')`
- 选择器适配原则可参考 [ui-test-script-spec.md#选择器规范](./ui-test-script-spec.md#选择器规范)
- 双产物脚本中同一元素应使用一致的选择器语义，便于对照维护

---

## 自然语言标注规范

### 标注用途

录制脚本（recorder json）本身只含操作与选择器，缺少语义信息。为支撑后续 AI 维护脚本（自愈、变更更新），生成脚本时必须同步产出**自然语言标注**：为每个步骤生成中文语义描述。

### 标注产出

标注以两个载体同时存在，内容保持一致：

1. **脚本内注释**：agent-browser 脚本的 `# @step <stepId> | <操作类型>: <页面名> — <描述>` 注释（见 [ui-test-agent-browser-spec.md#脚本格式要素](./ui-test-agent-browser-spec.md#脚本格式要素)）
2. **标注文件**：用例文件夹下的 `annotations.json`

### annotations.json 格式

格式与要求见 [templates/annotations-template.json](../templates/annotations-template.json)。关键约束：
- stepId 与脚本 `@step` 注释一一对应
- `description` 使用中文，描述业务语义
- 断言步骤必须填写 `expectedResult`，且 `isAssertion: true`

---

## 执行计划规范

### 执行计划用途

执行计划定义各场景脚本的运行顺序、依赖关系和变量传递方式，确保脚本能按正确流程依次或独立执行。

### 执行顺序原则

1. 场景之间有数据依赖时，按依赖关系确定先后顺序
2. 无依赖的场景可并行或按优先级从高到低排列
3. P0（核心路径）优先于 P1，P1 优先于 P2
4. 异常场景建议在正常场景之后执行，以便先验证核心功能可用

### 变量保存规范

当场景之间存在数据依赖（如登录后的 token、创建订单后的订单号）时，通过变量保存和传递实现：

**保存方式**：

| 方式 | 适用场景 | 实现 |
|------|---------|------|
| 文件存储 | 跨脚本共享变量 | `fs.writeFileSync` / `fs.readFileSync` 写入/读取 JSON 文件 |
| 环境变量 | 简单键值传递 | `process.env.XXX` 设置/读取 |
| 脚本内变量 | 同一脚本内步骤间传递 | JavaScript 变量 |

**变量存储文件路径**：`data.json`，存放在用例文件夹下（与脚本同级）。

```
.asdm/workspace/ui-test/<用例名称抽象>_<YYYYMMDDHHmmss>/
├── overview.md
├── data.json                  # 变量共享存储文件
├── ...
```

**变量保存/读取模板**：见 [templates/variable-templates.js](../templates/variable-templates.js)

### 执行计划输出格式

执行计划作为总体文档的一个章节输出，模板见 [templates/execution-plan-template.md](../templates/execution-plan-template.md)。

---

## 总体文档规范

### 总体文档用途

每次 `/asdm-ui-test-design-generate` 执行后，生成一份总体 MD 文档（`overview.md`），作为该测试用例的概览入口。该文档存放在用例文件夹下，与各场景脚本同级。

### 总体文档路径

```
.asdm/workspace/ui-test/<用例名称抽象>_<YYYYMMDDHHmmss>/overview.md
```

### recordings-checklist.json 生成规则（条件产出）

`recordings-checklist.json` 仅在**检测到缺失或无法定位的录制脚本**时生成，列出待补充的录制文件路径及操作指引。当所有场景均可定位、录制文件完整时，**不生成该文件**（此前会输出空 `[]`，属冗余桩文件）。

### 总体文档模板

完整模板见 [templates/overview-template.md](../templates/overview-template.md)。模板包含以下五个章节：
1. **测试场景设计**：场景划分说明 + 场景设计摘要表格
2. **元素定位检测报告**：检测概况 + 各场景定位详情
3. **定位缺失反馈**（可选）：缺失录制脚本清单和操作指引
4. **执行计划**：执行顺序 + 变量传递说明 + 数据依赖声明
5. **任务清单**：三阶段任务清单 + 失败详情

---

## 任务清单规范

### 任务清单格式

任务清单作为总体文档（`overview.md`）的第五章节输出。三阶段格式模板见 [templates/task-list-template.md](../templates/task-list-template.md)。

### 失败原因规范

当任务清单中的某项未完成时，必须按以下格式备注明确的失败原因：

| 失败项 | 失败原因 | 影响范围 | 建议操作 |
|--------|---------|---------|---------|
| <场景编号> 脚本生成 | <具体原因，如：录制文件缺失某操作> | <影响的场景或模块> | <具体建议，含目标录制文件路径> |

常见失败原因类型及建议操作见 [templates/task-list-template.md#常见失败原因及建议操作](../templates/task-list-template.md#常见失败原因及建议操作)。

---

## 相关文档

- **Action**: `/asdm-ui-test-design-generate` - 使用本规范执行设计与脚本生成
- **Spec**: `ui-test-agent-browser-spec.md` - agent-browser 脚本规范（主产物）
- **Spec**: `ui-test-case-spec.md` - 测试用例文档模板规范
- **Spec**: `ui-test-script-spec.md` - Playwright 降级脚本代码规范
- **Spec**: `ui-test-data-spec.md` - 测试数据管理规范
- **Playwright 官方文档**: https://playwright.dev/docs/intro
