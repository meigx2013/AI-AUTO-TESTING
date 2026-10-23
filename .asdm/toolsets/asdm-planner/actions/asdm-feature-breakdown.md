# ASDM Action: Feature Breakdown — 将特性设计文档拆解为实施计划

## Metadata

```json
{
  "guid": "b5d3e4f6-a7b8-9c0d-1e2f3a4b5c6d",
  "name": "asdm-feature-breakdown",
  "displayName": "Feature Breakdown",
  "description": "将已完成设计的 Feature 文档拆分为具体的实施步骤和任务，生成结构化的实施计划文档（Plan）",
  "toolset": {
    "guid": "e5f6a7b8-c9d0-1e2f-3a4b5c6d7e8f",
    "id": "asdm-planner",
    "name": "ASDM Planner Toolset",
    "version": "1.0.0"
  },
  "scenario": "feature-planning"
}
```

## Description

读取一个已完成的特性设计文档（Feature-Overall + Feature-Detailed），分析其内容，将其中的「实施计划」章节或整体设计方案拆解为**可执行、可验证的细粒度任务清单**，生成一份标准化的实施计划文档（Plan）。

> **⚠️ 前置条件**：使用本工具前，**必须先通过 `/asdm-feature-planning-lite-overall` 和 `/asdm-feature-planning-lite-detailed` 完成概要设计和详细设计**，生成对应的 Feature-Overall.md 和 Feature-Detailed.md 文档。如这两个文件不存在，将终止执行并提示用户。

生成的 Plan 文档包含：
- **进度概要表**：Phase → 任务 → 状态 → 交付物
- **逐任务分解**：每个任务包含部署要求/工程属性、核心逻辑/校验范围、具体交付物
- **验证步骤**：每个任务附带 checkbox 列表格式的验证项（含操作描述 + 预期结果 + 验证命令），**验证步骤即该任务的验收标准**

## Usage

```
/asdm-feature-breakdown <自然语言描述>
```

用户可以用自然语言指定目标特性。AI 自动定位对应的 Feature 文档并执行拆解。

## Parameters

所有参数均可通过自然语言输入，AI 自动提取。若必填参数缺失，AI 须向用户询问。

| 参数 | 必填 | 说明 | 示例 |
|------|:----:|------|------|
| `feature_id` | ✅ | 特性编号，匹配 `FT-\d{3}` 格式 | FT-041、FT-060 |
| `feature_doc_path` | ❌ | Feature 文档路径（自动推断） | `docs/planning/Feat/FT-041-数据上报2.0/FT-041-数据上报2.0-Feature.md` |
| `output_path` | ❌ | 输出 Plan 文件路径（自动生成） | `docs/planning/Feat/FT-041-数据上报2.0/FT-041-数据上报2.0-Plan.md` |

## Examples

### 自然语言输入
```
/asdm-feature-breakdown 把 FT-041 数据上报2.0 的 Feature 拆成实施计划
```

```
/asdm-feature-breakdown FT-041
```

```
/asdm-feature-breakdown 帮我拆解 FT-060 的设计文档为任务清单
```

## Process

### 0. ⛔ 前置条件检查（Preconditions Check）

> **此步骤在流程开始前必须执行。**
> 目标：确保概要设计文档（Feature-Overall）和详细设计文档（Feature-Detailed）均已存在，避免在缺少设计文档的情况下进行拆解。

1. **确定特性目录路径**：
   - 从用户输入中提取 `feature_id`（匹配 `FT-\d{3}` 格式）或特性名称
   - 如已有 FT-XXX 编号 → 特性目录为 `docs/planning/Feat/FT-XXX-{name}/`
   - 如无编码但提供了名称 → 尝试匹配 `ASDM-ProductPlanning.md` 中的已有条目确定编号

2. **检查 Feature-Overall 文档是否存在**：
   - 检查特性目录下是否存在 `FT-XXX-{name}-Feature-Overall.md` 文件
   - **如不存在** → **终止当前流程**，提示用户：
     ```
     ❌ 前置条件不满足：未找到概要设计文档。

     特性目录: docs/planning/Feat/FT-XXX-{name}/
     缺失文件: FT-XXX-{name}-Feature-Overall.md

     请先执行 /asdm-feature-planning-lite-overall <特性描述或 FT-XXX 编码>
     完成概要设计后再执行本拆解工具。
     ```

3. **检查 Feature-Detailed 文档是否存在**：
   - 检查特性目录下是否存在 `FT-XXX-{name}-Feature-Detailed.md` 文件
   - **如不存在** → **终止当前流程**，提示用户：
     ```
     ❌ 前置条件不满足：未找到详细设计文档。

     特性目录: docs/planning/Feat/FT-XXX-{name}/
     缺失文件: FT-XXX-{name}-Feature-Detailed.md

     请先执行 /asdm-feature-planning-lite-detailed <特性描述或 FT-XXX 编码>
     完成详细设计后再执行本拆解工具。
     ```

4. **前置检查通过提示**：
   ```
   ✅ 前置条件检查通过：
   ✓ 概要设计文档: docs/planning/Feat/FT-XXX-{name}/FT-XXX-{name}-Feature-Overall.md
   ✓ 详细设计文档: docs/planning/Feat/FT-XXX-{name}/FT-XXX-{name}-Feature-Detailed.md

   继续进入拆解流程...
   ```

### 1. 定位并读取 Feature 文档

#### 1.1 参数解析与文件定位

从用户输入中提取 `feature_id`（匹配 `FT-\d{3}` 格式）。

根据 feature_id 推断 Feature 文档路径，优先使用分阶段文档（Feature-Overall + Feature-Detailed），回退到单文件 Feature 文档：

**优先路径（分阶段文档）**：
```
docs/planning/Feat/FT-{XXX}-{特性名称}/FT-{XXX}-{特性名称}-Feature-Overall.md
docs/planning/Feat/FT-{XXX}-{特性名称}/FT-{XXX}-{特性名称}-Feature-Detailed.md
```

**回退路径（单文件文档）**：
```
docs/planning/Feat/FT-{XXX}-{特性名称}/FT-{XXX}-{特性名称}-Feature.md
```

定位策略（按优先级尝试）：
1. 用户显式指定的路径
2. 根据 feature_id 在 `docs/planning/Feat/` 下搜索匹配目录
3. 在 `ASDM-ProductPlanning.md` 中查找该特性的文档引用

#### 1.2 读取并理解 Feature 文档

根据定位到的文档类型，执行不同的读取策略：

**分阶段文档模式（Feature-Overall + Feature-Detailed）**：

1. 读取 `FT-{XXX}-{name}-Feature-Overall.md` 的完整内容（概要设计：总体概述、使用场景）
2. 读取 `FT-{XXX}-{name}-Feature-Detailed.md` 的完整内容（详细设计：Agent 自由扩展区、完成规范 DoD）
3. 将两份文档内容合并作为完整的设计输入

**单文件文档模式（Feature.md）**：

完整读取 Feature 文档全部内容。

> **关键约束：不得对 Feature 文档的章节结构做任何假设。**
>
> 不同 Feature 文档可能采用完全不同的章节组织方式（如有的按模块分章、有的按阶段分章、有的混排），因此 AI 必须基于**实际文档内容**而非预设章节名来工作。
> 对于分阶段文档，Overall 和 Detailed 可能采用不同的结构组织，需分别理解后综合分析。

**正确的处理方式**：

1. **扫描文档的全部标题层级**（`#` / `##` / `###`），建立该文档的实际目录结构
2. **通过语义理解**（非关键词匹配）从全文中定位以下几类信息，无论它们出现在哪个章节：
   - 变更范围 / 受影响模块 / 涉及的系统或组件
   - 技术方案 / 设计决策 / 架构描述
   - API 定义 / 接口设计 / 协议规范
   - 数据模型 / DDL / 存储结构
   - 基础设施需求 / 环境依赖 / 部署要求
   - 已有（如有）的实施计划 / 阶段划分 / 任务列表
   - MCP Server / CLI / 前端等端侧相关内容
   - 配置文件 / 规则文件的变更说明
3. **若文档中已包含某种形式的任务分解或阶段规划**，将其作为主要输入参考但**不照搬**——需重新组织为 Plan 标准格式并补充验证步骤
4. **若文档中完全没有任务分解信息**，则基于全文的技术方案内容自行推导合理的 Phase 划分和任务分解

### 2. 分析 Feature 内容并规划 Phase 结构

#### 2.1 识别变更模块

**基于全文的语义理解识别所有受影响的模块、组件和系统**。

> **不得假设 Feature 文档中存在任何特定格式的内容**——没有「变更范围表」、没有「模块清单」、没有固定的数据结构。
>
> 不同 Feature 文档对变更范围的呈现方式差异极大：
> - 有的用表格罗列受影响的模块
> - 有的在技术方案段落中散落描述
> - 有的只隐含在设计决策中
> - 有的甚至完全不做显式归纳

**正确的处理方式**：

1. **通读全文**，从整体上理解该特性要做什么、涉及哪些系统
2. **通过语义推断**而非模式匹配来识别变更面——例如文档提到"需要在 MCP Server 中新增一个上报工具"，即使没有单独列出"asdm-mcp-server"作为变更模块，也应将其识别为受影响模块
3. **将识别出的变更项按其自然属性归类**用于后续 Phase 规划，但此分类是 AI 内部推理步骤，**不要求 Feature 文档本身提供此类分类**

若文档中确实包含某种形式的变更范围总结（无论何种格式），可参考以避免遗漏，但仍需结合全文做交叉验证。

#### 2.2 规划 Phase 划分原则

> **不得预设任何特定领域的 Phase 模板。**
>
> 不同特性的实施路径差异极大——有的纯后端、有的纯前端、有的涉及硬件部署、有的只是配置变更。Phase 划分必须**完全基于当前 Feature 的实际内容**推导得出。

**通用划分方法论**（按优先级组合使用）：

1. **依赖关系优先**：被其他任务依赖的先做（如数据库 DDL → API → 上游消费）
2. **技术层次排序**：底层基础 → 中层服务 → 上层集成 → 前端展示
3. **风险前置**：高风险 / 不确定性的任务尽早启动，为问题暴露留出时间
4. **可交付性**：每个 Phase 结束时应有可验证的中间产出，而非全部做完才可见

**具体操作**：

1. 先列出从 §2.1 识别出的所有变更项
2. 分析它们之间的依赖关系（哪些必须先完成）
3. 按**依赖链**自然分组，每组即为一个 Phase
4. 给每个 Phase 起一个能概括其内容的名称（名称应反映该 Phase 的实际工作内容，而非套用固定模板）

若 Feature 文档中已有某种阶段/阶段规划描述（无论以何种形式呈现），将其作为重要参考，但仍需用上述方法做合理性检验和补充。

#### 2.3 任务粒度原则

| 原则 | 说明 |
|------|------|
| 单一职责 | 每个任务只做一件事（如「eventType 注册表落地」而非「API 实现」）|
| 可验证 | 每个任务必须有明确的交付物和可执行的验证命令 |
| 1~3 天工作量 | 单个任务的理想工作量，过大的任务需继续拆分 |
| 依赖清晰 | 任务间的依赖关系应可在同 Phase 内线性排列 |

### 3. 生成任务分解

对每个 Phase 中的事项，拆解为**编号任务**（格式 `{Phase}.{Task序号}`）。

#### 3.1 每个任务的标准结构

每个任务必须包含以下子节：

##### （A）任务标题

格式：`### 任务 {P.T}: {简短名称}`

示例：`### 任务 1.1: ClickHouse 部署与初始化`

##### （B）部署要求 / 工程属性 / 核心逻辑 / 校验范围

根据任务类型选择合适的描述表格：

| 任务类型 | 使用的子节标题 | 内容形式 |
|----------|--------------|---------|
| 基础设施部署 | `#### 部署要求` | 属性值表格（角色、版本、端口等）|
| 微服务/模块新建 | `#### 工程属性` | groupId/artifactId/包路径/端口/技术栈表格 |
| 功能实现 | `#### 核心逻辑` | 处理流程文字描述 + 伪代码/序列图 |
| 校验/验证类 | `#### 校验范围` | 字段→校验规则对照表 |
| 配置变更 | `#### 配置要点` | 变量名/用途/必填 表格 |

**关键要求**：此处的具体参数值、DDL 语句、Nginx 配置、YAML 片段等，**必须直接从 Feature 文档中提取**，不得凭空编造。

##### （C）交付物

`#### 交付物` 子节，列出具体的、可检验的产出物清单（无序列表）。

##### （D）验证步骤

`#### 验证步骤` 子节，使用 **checkbox 列表格式**（非表格）：

```markdown
- [ ] **V{P.T.{N}}** {操作描述} → {预期结果}
  `{验证命令}`
```

验证步骤编写规范：

| 规范项 | 要求 |
|--------|------|
| 编号格式 | `V{Phase}.{Task}.{序号}`，如 V1.1.1、V2.3.4 |
| 格式 | checkbox 列表（`- [ ]`），**禁止使用 Markdown 表格** |
| 内容结构 | 操作描述 → 预期结果（一句话），换行后缩进 2 空格跟验证命令 |
| 验证命令 | 优先使用可复制的 shell 命令（curl/clickhouse-client/docker/mvn/npm 等）|
| 数量 | 每个任务建议 4~8 条验证步骤 |
| 覆盖面 | 覆盖：正常路径、异常路径、边界条件、安全/认证场景 |

### 4. 组装完整的 Plan 文档

#### 4.1 Plan 文档标准结构

```markdown
# FT-{XXX} {特性名称} 实施计划

## 项目概述
（2~3 句话概述本计划的目标和核心工作项，编号列表）

### 前置依赖
（列表）

### 后续依赖
（列表）

---

## 进度概要
（总表：Phase → 任务 → 状态(⏳) → 交付物）

---

## Phase {N}: {Phase 名称}

### 目标
（1~2 句话）

### 任务 {P.T}: {任务名}
（部署要求/工程属性/核心逻辑...）
#### 交付物
#### 验证步骤
（checkbox 列表）

...（更多任务）

---

## Phase {N+1}: ...
...

## 实施顺序建议
（编号列表）

## 风险与挑战
（表格：风险 | 影响 | 应对措施）

## 变更模块总览
（表格：变更模块 | 涉及Phase | 核心变更）
```

#### 4.2 输出路径规范

| 项目 | 规范 |
|------|------|
| **目录** | 与 Feature 文档同级目录：`docs/planning/Feat/FT-{XXX}-{名称}/` |
| **文件名** | `FT-{XXX}-{名称}-Plan.md` |
| **示例** | `docs/planning/Feat/FT-041-数据上报2.0/FT-041-数据上报2.0-Plan.md` |

#### 4.3 写入文件（必须执行）

**每次拆解完成后必须将 Plan 写入文件系统**，不得仅在对话中输出。

- 使用 `write_to_file` 工具写入到上述路径
- 若文件已存在，提醒用户确认是否覆盖

### 5. 语言检测

在生成任何内容前，检测并使用当前环境的响应语言：

1. **检测响应语言**：分析 Feature 文档的主要编写语言
2. **应用语言一致性**：Plan 文档的所有内容（任务描述、验证步骤、注释等）使用与 Feature 文档一致的语言
3. **支持语言**：中文（zh）/ English（en）

### 6. 输出结果

返回结构化的拆解结果：

### Breakdown 输出
```json
{
  "phase": "planning",
  "scenario": "existing_feature",
  "status": "success",
  "feature_id": "FT-041",
  "feature_name": "string",
  "source_docs": {
    "overall_path": "docs/planning/Feat/FT-XXX-name/FT-XXX-name-Feature-Overall.md",
    "detailed_path": "docs/planning/Feat/FT-XXX-name/FT-XXX-name-Feature-Detailed.md",
    "feature_path": null
  },
  "phases": [
    {
      "phase_number": 1,
      "phase_name": "基础设施搭建与服务连通性",
      "task_count": 6,
      "tasks": ["1.1", "1.2", ..., "1.6"]
    }
  ],
  "total_tasks": 25,
  "total_verification_items": 150,
  "plan_path": "docs/planning/Feat/FT-041-xxx/FT-041-xxx-Plan.md",
  "timestamp": "ISO 8601 datetime"
}
```

- `phase`：固定为 `"planning"`（规划阶段）
- `scenario`：`"existing_feature"`（已有 Feature 文档的场景）；若 Feature 文档中无任何形式的任务/阶段分解信息且完全由 AI 推导则为 `"new_feature"`
- `source_docs`：设计文档来源
  - `overall_path`：概要设计文档路径（分阶段模式时有值）
  - `detailed_path`：详细设计文档路径（分阶段模式时有值）
  - `feature_path`：单文件 Feature 文档路径（非分阶段模式时有值，分阶段模式为 null）
- `total_verification_items`：全部验证步骤 checkbox 总数
- `plan_path`：生成的 Plan 文件路径

## 任务拆解方法论

### 核心原则：纵向拆分（Vertical Slicing）

**必须采用纵向拆分方式组织任务，禁止按技术层次横向分层。**

| 对比维度 | 横向拆分（❌ 禁止） | 纵向拆分（✅ 必须） |
|----------|-------------------|-------------------|
| 拆分维度 | 按技术层（DB → Service → Controller → Client） | 按用户可感知的能力 / 可验证的功能单元 |
| 单个任务产出 | 一个中间层（如"DTO 校验层"），用户不可见 | **一个端到端可验证的功能**（如"事件上报 API 可接收并写入"） |
| 验证时机 | 多个任务完成后才能端到端验证 | **每个任务完成即可验证** |
| 交付价值 | 前期任务无外部可验证产出 | **每个任务都有独立可演示的价值** |

### 什么是「纵向切片」？

一个纵向切片 = **从用户视角出发的一个完整功能闭环**。它穿过所有必要的技术层次，但范围被限定在一个**具体的、可命名的、可验证的用户能力上**。

示例（以一个数据上报系统为例）：

| ❌ 横向拆分（按层） | ✅ 纵向拆分（按能力） |
|--------------------|----------------------|
| T1: ClickHouse DDL 和连接配置 | T1: **事件上报接口可接收请求并写入 ClickHouse**（含 DDL + Service + Controller + 校验 + 一条 curl 验证）|
| T2: Telemetry Service 业务逻辑 | T2: **上报接口支持 JWT 认证和 m2m 调用**（含 Filter + SecurityConfig + 认证相关校验 + curl 带/不带 token 验证）|
| T3: Telemetry Controller | T3: **MCP 工具可调用上报接口并返回结果**（含 Tool 注册 + 参数 schema + HTTP 转发 + MCP session 验证）|
| T4: DTO 校验框架 | T4: **CLI 安装后自动上报安装事件**（含 CLI 模块 + Hook + 字段组装 + 日志验证）|

注意：每个 ✅ 任务都对应一条**用户可见的验收路径**（curl / CLI 执行 / Agent 调用），完成后立即可验证。

### 拆解操作步骤

1. **从 Feature 文档中识别所有「用户可见能力」**
   - 用户（或下游系统 / Agent / CLI）能直接调用的功能点
   - 每个 API 端点是一个候选能力
   - 每个 MCP 工具是一个候选能力
   - 每个 CLI 命令行为是一个候选能力
   - 每个可观察的系统行为（如事件触发、规则生效）是一个候选能力

2. **按依赖关系排序**这些能力——被其他能力依赖的先做

3. **对每个能力，确认其纵向范围**：
   - 从入口（API / 工具 / 命令 / 事件）到出口（存储 / 响应 / 副作用）
   - 包含该能力所需的所有层：数据结构 → 服务逻辑 → 接口暴露 → 校验 → 错误处理

4. **评估粒度**（见下方粒度控制标准）

5. **无法纵向化的纯基础设施工作**（如 DDL 部署、Docker 编排）归入 P1 作为前置任务，但应尽量少且快速过渡到纵向任务

### 粒度控制标准

| 标准 | 要求 |
|------|------|
| **可独立验证** | 完成后能通过一条命令或操作确认其正常工作 |
| **1~3 天工作量** | 单任务的理想工作量 |
| **单一能力** | 每个任务只交付一种用户可见能力，不要把多个不相关的 API 合成一个任务 |
| **不过度拆分** | 不要将一个自然能力的内部步骤（如"DDL"和"Service 编写"）拆成两个任务——它们合在一起才能验证 |
| **不过度合并** | 不要把两个独立的 API 或工具塞进一个任务——它们应该各自可独立验证 |

### 纵向拆分示例

以下示例展示同一特性在两种拆分方式下的差异，供参考理解：

#### 示例：新增一个带认证的数据上报微服务

```
P1 基础设施（少量纯基础工作，尽快进入纵向任务）

  任务 1.1: 存储就绪与工程骨架
  （ClickHouse DDL + Maven 子模块骨架 + application.yml + 启动验证）
  → 验证：服务启动成功 + 表存在

P2 核心能力（每个任务 = 一个完整的端到端能力）

  任务 2.1: 事件上报 API — 基础通路
  （Controller 端点 → Service 写入逻辑 → Repository → ClickHouse 插入 + 基础校验）
  → 验证：curl POST → HTTP 200 + CK 中有数据

  任务 2.2: 事件上报 API — 请求校验与错误处理
  （DTO Validation 注解 → 全局异常处理器 → 错误码枚举 → 标准 Error 响应格式）
  → 验证：curl 缺字段 → HTTP 400 + 错误码正确；curl 异常 payload → HTTP 422

  任务 2.3: 事件上报 API — 幂等与去重
  （去重键策略 → 唯一索引 / 缓存去重 → 重复请求返回已存在结果）
  → 验证：相同请求发两次 → 第二次返回幂等响应 + CK 中只有一条记录

  任务 2.4: 上报接口 — 认证鉴权集成
  （JWT Filter / m2m API Key → SecurityConfig → 无 token 拒绝 / 过期拒绝）
  → 验证：curl 带 token → 200；不带 token → 401；过期 token → 401

P3 端侧打通（每个任务 = 一种调用方完整跑通）

  任务 3.1: MCP 工具 — 事件上报工具可用
  （Tool 定义注册 → 参数 schema → tools/list 发现 → MCP 层校验 → HTTP 转发到 API）
  → 验证：MCP tools/list 含该工具 → 调用该工具 → API 收到请求 → 返回结果给 Agent

  任务 3.2: Default Rules — 上报动作协议段生效
  （alwaysApply 配置 → 三步协议执行顺序 → 触发条件判断 → 降级策略）
  → 验证：Agent 执行匹配命令 → 自动触发上报 → CK 中有对应记录

  任务 3.3: CLI — 安装后自动上报安装事件
  （CLI HTTP 模块 → postinstall Hook → 事件字段组装 → Token 获取 → 失败静默）
  → 验证：执行 npm install → CK 中出现 install 事件；断网时不影响退出码
```

> 以上仅为示例中的具体内容参考。**实际拆解时必须基于目标 Feature 文档的实际内容**，不得套用上述具体任务名或技术细节。

## Verification Step Catalog（验证步骤常用模式）

以下是在编写验证步骤时可复用的**常用验证模式**：

### 进程/服务类
```markdown
- [ ] **Vx.y.z** 检查 {进程名} 状态 → 运行中
  `docker ps | grep {name}` 或 `systemctl status {service}`
```

### 端口监听类
```markdown
- [ ] **Vx.y.z** 端口 {port} 监听中 → LISTEN 状态
  `lsof -i :{port} | grep LISTEN`
```

### HTTP 接口类
```markdown
- [ ] **Vx.y.z** GET/POST {path} → HTTP {code} + {字段断言}
  `curl -s {method} {url} {headers} | jq '{expr}'`
```

### 数据库/存储类
```markdown
- [ ] **Vx.y.z** 验证 {table} 存在且结构正确 → DESCRIBE 输出含目标列
  `{client} --query "DESCRIBE TABLE {db}.{table} FORMAT PrettyCompact"`
```

### 编译/构建类
```markdown
- [ ] **Vx.y.z** {构建工具} 编译成功 → BUILD SUCCESS
  `cd {project} && {build_cmd}`
```

### 单元测试类
```markdown
- [ ] **Vx.y.z** 单元测试覆盖率 ≥ {N}% → 查看 JaCoCo / Istanbul 报告
  `{test_cmd} --coverage`
```

### Docker 类
```markdown
- [ ] **Vx.y.z** Compose 一键拉起 → 所有服务 running/healthy
  `docker compose -f {file} up -d && sleep {wait}s && docker compose -f {file} ps`
```

### 认证/鉴权类
```markdown
- [ ] **Vx.y.z** 带 {token_type} token 请求 → 放行 → HTTP 200
  `curl ... -H "{token_header}: {token}" ...`
- [ ] **Vx.y.z** 不带 token 请求 → 拒绝 → HTTP 401
  `curl ... -o /dev/null -w "%{http_code}" ...`
```

## Related Specifications
- [specs4shared.md](../specs/specs4shared.md) - 共享规范（关键文档、校验规则、路径约束、编写要点）
- [specs4asdm-feature-breakdown.md](../specs/specs4asdm-feature-breakdown.md) - asdm-feature-breakdown 专属规范（如有）
- [Feature-Template.md](../specs/templates/Feature-Template.md) - 特性文档标准模板
- [Plan-Template.md](../specs/templates/Plan-Template.md) - 实施计划标准模板（如有）
