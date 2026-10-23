# Plan Feature Lite - Overall (概要设计)

> **🔗 前置文档引用**：本工具的输入依赖于 **AskMe 文档**（`FT-XXX-{name}-AskMe.md`），即通过 `/asdm-feature-askme` 产出的需求访谈文档。AskMe 文档中的已确认决策、变更范围、用户故事等是概要设计的直接输入来源。前置条件检查会验证 AskMe 文档的存在和完成状态。

## Metadata

```json
{
  "guid": "a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d",
  "name": "asdm-feature-planning-lite-overall",
  "displayName": "Plan Feature Lite - Overall",
  "description": "轻量版特性规划 - 概要设计阶段，输出总体概述与使用场景，无需代码调研",
  "toolset": {
    "guid": "e5f6a7b8-c9d0-1e2f-3a4b5c6d7e8f",
    "id": "asdm-planner",
    "name": "ASDM Planner Toolset",
    "version": "1.0.0"
  },
  "scenario": "lite-planning-overall"
}
```

## Description
轻量版特性规划 - 概要设计阶段，仅输出**总体概述**和**使用场景**两个章节。此阶段**无需进行 Code Research**，聚焦于需求理解和场景梳理。

支持两种场景：创建全新特性或基于已有特性编码创建特性文档。

> **⚠️ 前置条件**：使用本工具前，**必须先通过 `/asdm-feature-askme` 完成需求访谈**，生成对应的 AskMe 文档并确保所有待澄清问题已解决。详见 Process 章节的「前置条件检查」。

## Usage
```
/asdm-feature-planning-lite-overall <自然语言描述 或 FT-XXX 编码>
```

用户可以用自然语言描述特性信息，或直接提供已有的 FT-XXX 特性编码，AI 将自动提取所需参数。如缺少必要信息，AI 会向用户询问确认。

> **⚠️ 前置条件**：执行本命令前，请确保已通过 `/asdm-feature-askme` 完成了需求访谈，且对应 Feat 目录下存在状态为「✅ 访谈完成」的 AskMe 文档。

## Parameters

所有参数均可通过自然语言输入，AI 自动提取。若必填参数缺失，AI 须向用户询问。

| 参数 | 必填 | 说明 | 示例 |
|------|:----:|------|------|
| `name` | ✅ | 特性名称 | "MCP 注册表"、"用户个人令牌" |
| `module` | ✅ | 归属模块编号（参考 ASDM-ProductPlanning.md 模块清单） | 4（资源库管理）、13（MCP Hosting） |
| `description` | ✅ | 特性简要描述 | "补齐 MCP 注册表同步、公开 API 和前端管理页面" |
| `priority` | ❌ | 优先级 P1/P2/P3（默认：P2） | P1 |
| `release` | ❌ | 目标发布版本 | R03、R04 |
| `depends` | ❌ | 依赖的特性编号，逗号分隔 | FT-003、FT-003,FT-019 |
| `feature_id` | ❌ | 已有特性编码（场景2专用） | FT-004、FT-022 |

## Two Usage Scenarios

### 场景1：创建新特性

用户描述一个全新的特性需求，AI 执行概要设计流程：

1. 从自然语言中提取参数（name, module, description 等）
2. 如缺少必填参数，向用户询问确认
3. 校验模块编号存在、特性名称唯一
4. 分配下一个 FT-XXX 编号
5. 在 `docs/planning/Feat/FT-XXX-{name}/` 目录生成概要设计文档
6. 在 `ASDM-ProductPlanning.md` 特性清单中新增条目
7. 返回概要设计结果

**示例输入**：
```
/asdm-feature-planning-lite-overall 我需要为资源库模块做一个 MCP 注册表功能，优先级高，要补齐同步、公开 API 和前端管理页面
```

### 场景2：基于已有特性编码创建文档

用户给出已在 `ASDM-ProductPlanning.md` 中登记的特性编码，AI 从规划文档读取已有信息并生成概要设计文档：

1. 识别用户输入中的特性编码（FT-XXX 格式）
2. 从 `ASDM-ProductPlanning.md` 读取该特性的名称、说明、模块、优先级等信息
3. 补充用户可能提供的额外描述
4. 在 `docs/planning/Feat/FT-XXX-{name}/` 目录生成概要设计文档
5. 如特性已在规划文档中但尚未创建文档目录，则创建；如已存在，提示用户

**示例输入**：
```
/asdm-feature-planning-lite-overall FT-004
```

## Process

---

### ⛔ 前置条件检查（Preconditions Check）

> **此步骤在流程开始前必须执行。**
> 目标：确保用户已完成需求访谈，所有关键问题已澄清，避免基于模糊需求进行规划导致返工。

1. **确定特性目录路径**：
   - 从用户输入中提取特性编码（FT-XXX 格式）或特性名称
   - 如已有 FT-XXX 编号 → 特性目录为 `docs/planning/Feat/FT-XXX-{name}/`
   - 如无编码但提供了名称 → 先尝试匹配 `ASDM-ProductPlanning.md` 中的已有条目；如为新特性且尚未分配编号，提示用户**必须先执行 `/asdm-feature-askme` 获取编号和目录**

2. **检查 AskMe 文档是否存在**：
   - 检查特性目录下是否存在 `FT-XXX-{name}-AskMe.md` 文件
   - **如不存在** → **终止当前流程**，提示用户：
     ```
     ❌ 前置条件不满足：未找到需求访谈文档。

     特性目录: docs/planning/Feat/FT-XXX-{name}/
     缺失文件: FT-XXX-{name}-AskMe.md

     请先执行 /asdm-feature-askme <特性描述> 完成需求访谈，
     生成 AskMe 文档后再执行本规划工具。
     ```

3. **检查 AskMe 文档的完成状态**：
   - 读取 `FT-XXX-{name}-AskMe.md` 的完整内容
   - **检查文档状态标记**：文档头部应包含类似 `> 文档状态：✅ 需求访谈完成` 或 `🎤 需求访谈中进行` 的标记
   - **检查待澄清问题清单**：扫描文档中的待澄清问题/Q&A 表格，确认是否所有问题均已标记为"已解决"或"已确认"
   
   a. **如文档状态为"进行中"或有未解决的问题** → **终止当前流程**，提示用户：
      ```
      ⚠️ 前置条件不满足：需求访谈尚未完成。

      AskMe 文档: docs/planning/Feat/FT-XXX-{name}/FT-XXX-{name}-AskMe.md
      当前状态: 🎤 访谈进行中
      未解决问题数: N 个

      未解决的问题：
      1. {问题描述1} — 状态：待回答
      2. {问题描述2} — 状态：待回答

      请继续执行 /asdm-feature-askme FT-XXX 完成剩余问题的澄清，
      所有问题解决后再执行本规划工具。
      ```

   b. **如文档状态为"已完成"且所有问题已解决** → 通过前置检查，输出确认信息并继续后续流程：
      ```
      ✅ 前置条件检查通过：
      ✓ AskMe 文档存在: docs/planning/Feat/FT-XXX-{name}/FT-XXX-{name}-AskMe.md
      ✓ 文档状态: ✅ 需求访谈完成
      ✓ 待澄清问题: 0 个未解决

      继续进入概要设计流程...
      ```

4. **提取 AskMe 关键信息供规划使用**：
   - 从 AskMe 文档中提取以下信息，作为规划的输入上下文：
     - 特性概述（背景、目标、核心概念）
     - 归属模块、优先级、目标 Release、依赖关系
     - 变更范围和影响模块
     - 用户故事和验收标准
     - 已确认的技术决策
   - 将这些信息与用户的自然语言输入合并，作为规划的完整输入

---

### 概要设计阶段

> 目标：基于 AskMe 文档和用户输入，生成仅包含「总体概述」和「使用场景」的概要设计文档。**此阶段无需进行 Code Research。**

1. **解析输入**：从用户的自然语言描述中提取参数
   - 识别特性编码（FT-XXX 格式）→ 进入场景2
   - 无特性编码 → 进入场景1
   - 场景2 中用户可补充额外描述，与已有信息合并

2. **参数校验与确认**：
   - 必填参数缺失时，向用户询问（一次列出所有缺失项）
   - 校验模块编号是否在 `ASDM-ProductPlanning.md` 模块清单中
   - 校验特性名称不与现有特性重复（场景1）
   - 校验依赖的特性编号存在
   - 将用户模糊描述映射到具体模块编号（如"认证模块"→1、"资源库"→4）

3. **确定特性目录**：
   - 场景1：读取 `ASDM-ProductPlanning.md`，确定下一个可用 FT-XXX 编号，确认特性目录为 `docs/planning/Feat/FT-XXX-{name}/`
   - 场景2：从 `ASDM-ProductPlanning.md` 读取特性信息，确认特性目录为 `docs/planning/Feat/FT-XXX-{name}/`
   - 创建特性目录（如不存在）

4. **编写概要设计文档**：
   - 基于 AskMe 文档和用户输入，按本文档「概要设计文档模板」生成文档
   - 输出到 `docs/planning/Feat/FT-XXX-{name}/FT-XXX-{name}-Feature-Overall.md`
   - 文档仅包含：修订记录、目录、总体概述、使用场景

5. **场景1 - 创建新特性**：
   a. 读取 `ASDM-ProductPlanning.md`，确定下一个可用 FT-XXX 编号
   b. 确认特性归属模块，记录预期变更描述
   c. 生成概要设计文档
   d. 在 `ASDM-ProductPlanning.md` 对应的特性列表中新增条目（根据优先级放入"列表1"或"列表2"），**特性名称列必须包含指向特性文档的 Markdown 链接**，格式为 `[特性名称](./Feat/FT-XXX-{name}/FT-XXX-{name}-Feature-Overall.md)`

6. **场景2 - 基于已有特性创建文档**：
   a. 从 `ASDM-ProductPlanning.md` 读取特性信息（名称、说明、模块、优先级、Release、状态、依赖）
   b. 如用户提供了额外描述，与已有信息合并
   c. 检查 `docs/planning/Feat/FT-XXX-{name}/` 目录是否已存在 Overall 文档
      - 不存在：创建概要设计文档
      - 已存在：提示用户文档已存在，询问是否覆盖
   d. **不重复添加** ASDM-ProductPlanning.md 条目（已存在）
   e. **更新特性名称链接**：检查 `ASDM-ProductPlanning.md` 中该特性条目的名称列，如尚未包含指向文档的 Markdown 链接，则更新为链接格式

7. **粗体格式检查**（写入文件前必须执行）：按照 `specs4shared.md` 9.4 节规范，逐项检查 B1-B5（粗体内不含句末标点、不包裹长句、无多余空格等），自动修复问题后报告结果。

8. **完成提示**：
   - 向用户汇报概要设计已完成，列出文档路径
   - **必须提示用户**：可执行 `/asdm-feature-planning-lite-detailed` 进入详细设计阶段
   - 提示示例：
     ```
     ✅ 概要设计已完成！

     📄 概要设计文档: docs/planning/Feat/FT-XXX-{name}/FT-XXX-{name}-Feature-Overall.md

     👉 下一步：执行 /asdm-feature-planning-lite-detailed <相同描述或 FT-XXX 编号>
     系统将基于此概要设计文档进入详细设计阶段（含代码调研）。
     ```

### 参数提取规则

AI 应从自然语言中智能提取以下信息：

- **特性编码**：匹配 `FT-\d{3}` 格式
- **模块编号/名称**：
  - 数字（如"模块4"、"4"）→ 直接映射
  - 名称关键词（如"认证"、"资源库"、"MCP Hosting"）→ 查找模块清单映射
- **优先级**：匹配"P1"/"P2"/"P3"或语义（"高优先级"→P1，"低优先级"→P3）
- **Release**：匹配"R\d+"格式或语义（"下个版本"需确认）
- **依赖**：匹配"FT-\d{3}"格式，或语义（"依赖xxx"→查找对应特性编号）
- **特性名称和描述**：剩余的自然语言内容

### 缺失参数确认

当必填参数缺失时，AI 应一次性列出所有缺失项向用户确认，格式示例：

```
请补充以下必要信息：
1. 特性名称：请提供特性的简短名称（2-50字符）
2. 归属模块：请指定特性归属的模块（可选：1-认证与用户管理、4-资源库管理、13-MCP Hosting ...）
3. 特性描述：请简要描述特性的目标和范围
```

## Related Specifications
- [specs4shared.md](../specs/specs4shared.md) - 共享规范（关键文档、校验规则、路径约束、编写要点）
- [specs4plan-feature.md](../specs/specs4plan-feature.md) - plan-feature 专属规范
- [Feature-Template.md](../specs/templates/Feature-Template.md) - 完整特性文档标准模板（Lite 版仅使用其子集）

## Output

### 概要设计输出
```json
{
  "phase": "overall",
  "scenario": "new_feature | existing_feature",
  "status": "success",
  "feature_id": "FT-XXX",
  "feature_name": "string",
  "module": "number",
  "priority": "P1|P2|P3",
  "release": "string|null",
  "overall_path": "docs/planning/Feat/FT-XXX-name/FT-XXX-name-Feature-Overall.md",
  "planning_updated": true,
  "planning_link_updated": true,
  "timestamp": "ISO 8601 datetime"
}
```

- `phase`：`overall` 表示概要设计阶段
- `overall_path`：概要设计文档路径
- `planning_updated`：场景1 为 true（新增条目），场景2 为 false（不重复添加条目）
- `planning_link_updated`：如更新了 `ASDM-ProductPlanning.md` 中特性名称的链接则为 true

---

## 概要设计文档模板

> 以下为概要设计阶段专用文档模板，仅包含「总体概述」和「使用场景」两个核心章节。

```markdown
# FT-XXX {特性名称} - 概要设计

> **🔗 前置文档引用**：本文档基于 [FT-XXX-{name}-AskMe.md](./FT-XXX-{name}-AskMe.md)（需求访谈文档）编写。AskMe 中的已确认决策、变更范围、用户故事等是本概要设计的直接输入来源。

> 最后更新：{YYYY-MM-DD}

---

## 修订记录

| 版本 | 日期 | 修订人 | 修订内容 |
|------|------|--------|----------|
| 1.0.0 | {YYYY-MM-DD} | {修订人} | 初始版本 |

---

## 目录

- [1. 总体概述](#1-总体概述)
- [2. 使用场景](#2-使用场景)

---

## 1. 总体概述

<!-- Agent 自由撰写：背景、目标、核心概念、变更范围等 -->
<!-- 可根据需要拆分为 1.1、1.2... 子节，结构不限 -->

---

## 2. 使用场景

<!-- Agent 自由撰写：按需添加 2.1、2.2... 场景 -->
<!-- 每个场景包含操作步骤和预期结果 -->
```
