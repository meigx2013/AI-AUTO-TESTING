# Plan Feature Lite - Detailed (详细设计)

> **🔗 前置文档引用**：本工具的输入依赖于 **Feature-Overall 文档**（`FT-XXX-{name}-Feature-Overall.md`），即通过 `/asdm-feature-planning-lite-overall` 产出的概要设计文档。Overall 文档中的总体概述、使用场景、核心概念等是详细设计的直接输入来源。前置条件检查会验证 Overall 文档的存在。

## Metadata

```json
{
  "guid": "b2c3d4e5-f6a7-8b9c-0d1e-2f3a4b5c6d7e",
  "name": "asdm-feature-planning-lite-detailed",
  "displayName": "Plan Feature Lite - Detailed",
  "description": "轻量版特性规划 - 详细设计阶段，基于概要设计文档输出 Agent 自由扩展区，需进行代码调研",
  "toolset": {
    "guid": "e5f6a7b8-c9d0-1e2f-3a4b5c6d7e8f",
    "id": "asdm-planner",
    "name": "ASDM Planner Toolset",
    "version": "1.0.0"
  },
  "scenario": "lite-planning-detailed"
}
```

## Description
轻量版特性规划 - 详细设计阶段，基于概要设计文档（Overall），输出**Agent 自由扩展区**（领域设计、接口设计、数据模型、依赖关系等可选章节）及**完成规范 (DoD)**。此阶段**必须进行 Code Research**。

> **⚠️ 前置条件**：必须先通过 `/asdm-feature-planning-lite-overall` 完成概要设计，生成 Overall 文档。如 Overall 文档不存在，将终止执行并提示用户。

## Usage
```
/asdm-feature-planning-lite-detailed <自然语言描述 或 FT-XXX 编码>
```

用户可以用自然语言描述特性信息，或直接提供已有的 FT-XXX 特性编码，AI 将自动检测 Overall 文档并进入详细设计流程。

## Parameters

所有参数均可通过自然语言输入，AI 自动提取。若必填参数缺失，AI 须向用户询问。

| 参数 | 必填 | 说明 | 示例 |
|------|:----:|------|------|
| `name` | ❌ | 特性名称（可从 Overall 文档读取） | "MCP 注册表" |
| `module` | ❌ | 归属模块编号（可从 Overall 文档读取） | 4、13 |
| `feature_id` | ✅ | 特性编码（FT-XXX 格式） | FT-004、FT-022 |

## Process

---

### ⛔ 前置条件检查（Preconditions Check）

> **此步骤在流程开始前必须执行。**
> 目标：确保概要设计文档（Overall）已存在，避免在缺少概要设计的情况下直接进入详细设计。

1. **确定特性目录路径**：
   - 从用户输入中提取特性编码（FT-XXX 格式）或特性名称
   - 如已有 FT-XXX 编号 → 特性目录为 `docs/planning/Feat/FT-XXX-{name}/`
   - 如无编码但提供了名称 → 尝试匹配 `ASDM-ProductPlanning.md` 中的已有条目确定编号

2. **检查 Overall 文档是否存在**：
   - 检查特性目录下是否存在 `FT-XXX-{name}-Feature-Overall.md` 文件
   - **如不存在** → **终止当前流程**，提示用户：
     ```
     ❌ 前置条件不满足：未找到概要设计文档。

     特性目录: docs/planning/Feat/FT-XXX-{name}/
     缺失文件: FT-XXX-{name}-Feature-Overall.md

     请先执行 /asdm-feature-planning-lite-overall <特性描述或 FT-XXX 编码>
     完成概要设计后再执行本详细设计工具。
     ```

3. **读取 Overall 文档内容**：
   - 读取 `FT-XXX-{name}-Feature-Overall.md` 的完整内容
   - 提取总体概述、使用场景等核心信息
   - 作为详细设计的输入上下文

4. **前置检查通过提示**：
   ```
   ✅ 前置条件检查通过：
   ✓ Overall 文档存在: docs/planning/Feat/FT-XXX-{name}/FT-XXX-{name}-Feature-Overall.md
   ✓ 总体概述: {概述摘要}
   ✓ 使用场景数: N 个

   继续进入详细设计流程（含代码调研）...
   ```

---

### 阶段一：调研阶段（Code Research）

> 目标：使用 code-explorer 对相关代码库进行完整扫描，将检查结构写成总结 MD 文件，写入对应的特性目录。完成后提示用户创建新会话进入阶段二。

1. **确定需要扫描的代码库清单**：
   - 基于 Overall 文档中的特性描述、归属模块和变更范围，列出需要扫描的所有代码库（如 asdm-admin、asdm-agentorbit、asdm-openclaw-channel 等）
   - 每个代码库对应一个独立的调研总结文件
   - 向用户展示扫描计划，确认代码库清单无遗漏

2. **逐库代码扫描与调研总结**（**按代码库逐个进行**）：
   
   对清单中的**每个代码库**，依次执行以下步骤（一次只扫描一个代码库，完成后再扫描下一个）：
   
   a. 使用 code-explorer 对当前代码库进行**完整扫描**
   b. 扫描范围包括：
      - 代码库的目录结构和文件组织
      - 与特性描述相关的现有实现（API、Service、Controller、前端组件等）
      - 数据库 migration 脚本和数据模型定义
      - 配置文件和环境变量
      - 与其他代码库的交互接口（API 调用、事件、共享类型等）
   c. 如扫描中发现任何不清晰的部分（如模块边界模糊、代码逻辑不明、依赖关系不确定），**必须向用户提出问题确认**，不可凭推测编写
   d. 将扫描结果整理为结构化的总结文档，写入特性目录：`docs/planning/Feat/FT-XXX-{name}/FT-XXX-{name}-CodeResearch-{repo-name}.md`
      - `{repo-name}` 为代码库目录名（如 `asdm-admin`、`asdm-agentorbit`）
      - 每个代码库一个独立文件，避免单文件过大或上下文混淆
   e. 单个代码库的调研总结文件内容应包括：
      - 代码库名称和路径
      - 目录结构和关键文件列表
      - 现有实现分析（API 端点、Service 层、数据模型、前端组件等）
      - 关键发现和缺失项（编号格式：`{repo简称}-G1, {repo简称}-G2, ...`，如 `admin-G1`、`orbit-G2`，确保跨库编号不冲突）
      - 与其他代码库的交互接口
      - 待确认问题清单（如有）
   f. 当前代码库扫描完成后，向用户简要汇报进度（已完成 X/Y 个代码库），继续扫描下一个代码库

3. **阶段一完成提示**：
   - 向用户明确汇报阶段一已完成，列出所有调研总结文件路径
   - **必须提示用户**：请创建新的会话（清空上下文），在新会话中再次执行 `/asdm-feature-planning-lite-detailed` 命令（携带相同的特性描述或 FT-XXX 编号），系统将自动进入阶段二
   - 提示示例：
     ```
     ✅ 阶段一（调研阶段）已完成！共扫描 N 个代码库：
     - asdm-admin → docs/planning/Feat/FT-XXX-{name}/FT-XXX-{name}-CodeResearch-asdm-admin.md
     - asdm-agentorbit → docs/planning/Feat/FT-XXX-{name}/FT-XXX-{name}-CodeResearch-asdm-agentorbit.md
     - ...
     
     ⚠️ 请创建新的会话以继续阶段二（详细设计）：
     在新会话中执行 /asdm-feature-planning-lite-detailed <相同描述或 FT-XXX 编号>
     系统将检测到已有调研文件，直接进入详细设计阶段。
     ```

---

### 阶段二：详细设计阶段（Detailed Design）

> 目标：检查调研总结文件是否就位，基于 Overall 文档和调研结果编写详细设计文档。

1. **检测阶段标识**：
   - 读取特性目录 `docs/planning/Feat/FT-XXX-{name}/` 下是否存在 `FT-XXX-{name}-CodeResearch-*.md` 调研总结文件（可多个）
   - **如调研文件存在且覆盖所有需要的代码库** → 确认进入阶段二，继续以下步骤
   - **如调研文件不存在或未覆盖所有代码库** → 自动回退到阶段一（调研阶段），仅扫描缺失的代码库

2. **校验调研完整性**：
   - 读取所有调研总结文件，检查以下必要信息是否完整：
     - 每个代码库的目录结构和关键文件列表
     - 现有实现分析
     - 关键发现和缺失项
   - 如部分代码库的调研信息不完整（如关键代码库未扫描、分析过于简略），**向用户报告缺失项并建议重新扫描该代码库**

3. **编写详细设计文档**：
   - 读取 Overall 文档内容作为上下文基础
   - 读取所有调研总结文件，提取技术实现细节
   - 按「详细设计文档模板」生成文档，输出到 `docs/planning/Feat/FT-XXX-{name}/FT-XXX-{name}-Feature-Detailed.md`
   - 文档结构：Overall 文档内容（修订记录、目录、总体概述、使用场景）+ Agent 自由扩展区 + 完成规范 (DoD)

4. **更新 `ASDM-ProductPlanning.md` 链接**：
   - 检查 `ASDM-ProductPlanning.md` 中该特性条目的名称列
   - 如链接指向 Overall 文档，更新为指向最终 Detailed 文档：`[特性名称](./Feat/FT-XXX-{name}/FT-XXX-{name}-Feature-Detailed.md)`

5. **粗体格式检查**（写入文件前必须执行）：按照 `specs4shared.md` 9.4 节规范，逐项检查 B1-B5（粗体内不含句末标点、不包裹长句、无多余空格等），自动修复问题后报告结果。

6. **完成提示**：
   - 向用户汇报详细设计已完成，列出文档路径
   - 提示示例：
     ```
     ✅ 详细设计已完成！

     📄 概要设计文档: docs/planning/Feat/FT-XXX-{name}/FT-XXX-{name}-Feature-Overall.md
     📄 详细设计文档: docs/planning/Feat/FT-XXX-{name}/FT-XXX-{name}-Feature-Detailed.md
     📄 调研总结: N 个代码库

     📋 ASDM-ProductPlanning.md 链接已更新为 Feature-Detailed 文档。
     ```

---

## Related Specifications
- [specs4shared.md](../specs/specs4shared.md) - 共享规范（关键文档、校验规则、路径约束、编写要点）
- [specs4plan-feature.md](../specs/specs4plan-feature.md) - plan-feature 专属规范
- [Feature-Template.md](../specs/templates/Feature-Template.md) - 完整特性文档标准模板（Lite 版仅使用其子集）

## Output

### 阶段一输出（调研阶段完成）
```json
{
  "phase": "research",
  "status": "success",
  "feature_id": "FT-XXX",
  "feature_name": "string",
  "repo_count": 3,
  "research_paths": [
    "docs/planning/Feat/FT-XXX-name/FT-XXX-name-CodeResearch-asdm-admin.md",
    "docs/planning/Feat/FT-XXX-name/FT-XXX-name-CodeResearch-asdm-agentorbit.md",
    "docs/planning/Feat/FT-XXX-name/FT-XXX-name-CodeResearch-asdm-openclaw-channel.md"
  ],
  "message": "阶段一完成，请创建新会话执行阶段二",
  "timestamp": "ISO 8601 datetime"
}
```

### 阶段二输出（详细设计完成）
```json
{
  "phase": "detailed",
  "status": "success",
  "feature_id": "FT-XXX",
  "feature_name": "string",
  "module": "number",
  "priority": "P1|P2|P3",
  "release": "string|null",
  "overall_path": "docs/planning/Feat/FT-XXX-name/FT-XXX-name-Feature-Overall.md",
  "feature_path": "docs/planning/Feat/FT-XXX-name/FT-XXX-name-Feature-Detailed.md",
  "research_paths": [
    "docs/planning/Feat/FT-XXX-name/FT-XXX-name-CodeResearch-asdm-admin.md",
    "docs/planning/Feat/FT-XXX-name/FT-XXX-name-CodeResearch-asdm-agentorbit.md"
  ],
  "planning_link_updated": true,
  "timestamp": "ISO 8601 datetime"
}
```

- `phase`：区分阶段一（research）和阶段二（detailed）
- `repo_count`：阶段一扫描的代码库数量
- `research_paths`：所有调研总结文件的路径列表（每代码库一个文件）
- `overall_path`：概要设计文档路径
- `feature_path`：最终特性文档路径
- `planning_link_updated`：如更新了 `ASDM-ProductPlanning.md` 中特性名称的链接则为 true

---

## 详细设计文档模板

> 以下为详细设计阶段的最终特性文档模板。包含 Overall 文档的固定骨架内容，以及 Agent 自由扩展区和完成规范。

### 固定骨架（必须保留，内容从 Overall 文档继承）

```markdown
# FT-XXX {特性名称}特性文档

> **🔗 前置文档引用**：本文档基于 [FT-XXX-{name}-Feature-Overall.md](./FT-XXX-{name}-Feature-Overall.md)（概要设计文档）编写。Overall 中的总体概述、使用场景、核心概念等是本详细设计的直接输入来源。

> 最后更新：{YYYY-MM-DD}

---

## 修订记录

| 版本 | 日期 | 修订人 | 修订内容 |
|------|------|--------|----------|
| 1.0.0 | {YYYY-MM-DD} | {修订人} | 初始版本 |

---

## 目录

<!-- 目录由 Agent 根据实际生成的章节自动生成，至少包含以下固定章节的锚点链接 -->
- [1. 总体概述](#1-总体概述)
- [2. 使用场景](#2-使用场景)
<!-- Agent 自由扩展章节的目录项由 Agent 根据实际添加的章节生成 -->
- [N. 完成规范 (DoD)](#n-完成规范-dod)

---

## 1. 总体概述

<!-- 从 Overall 文档继承，可根据调研结果进行补充和修正 -->

---

## 2. 使用场景

<!-- 从 Overall 文档继承，可根据调研结果进行补充和修正 -->
```

### Agent 自由扩展区（基于 Code Research 产出）

除上述固定骨架外，**Agent 应根据特性实际复杂度和 Code Research 结果自行决定是否添加以下类型的章节**：

| 可选章节类型 | 适用场景示例 |
|-------------|-------------|
| 领域设计 / 技术方案 | 需要深入描述认证流程、存储方案、状态机、数据同步等核心领域逻辑 |
| 接口设计 / API 规格 | 特性涉及新增或修改 API 端点 |
| 数据模型 | 特性涉及数据库 schema 变更或新表设计 |
| 依赖关系 | 特性依赖其他未完成特性或外部服务 |
| 相关文档 | 关联 AskMe 文档、CodeResearch 文档、其他 Feature 文档等 |

**编写规则**：
- 可选章节的**标题、子节结构、内容格式均由 Agent 自行决定**
- 章节顺序由 Agent 根据逻辑合理性排列（通常放在「使用场景」之后、「完成规范」之前）
- **目录必须与实际生成的章节保持一致**
- 如特性足够简单，可以不添加任何可选章节，仅保留固定骨架 + 完成规范即可

### 完成规范 (DoD)（必须保留）

```markdown
## N. 完成规范 (DoD)

> **状态说明**：
> - **已完成**：✅ 该功能点已实现，无需额外开发
> - **部分完成**：🟡 该功能点部分实现，需进一步完善
> - **待实现**：❌ 该功能点尚未实现，需要在开发阶段实现

<!-- Agent 按需拆分 DoD 子节（如核心功能、数据一致性、用户体验、安全性等） -->
<!-- 每个子节使用表格格式：编号 | 完成点 | 说明 | 状态 | 完成状态说明 -->
```

---

## Lite 版与完整版差异

| 维度 | 完整版 (`asdm-feature-planning`) | Lite 版 (`asdm-feature-planning-lite`) |
|------|------|------|
| 文档模式 | 固定模板（14 章） | **概要设计 + 详细设计（最小骨架 + Agent 自由扩展）** |
| 阶段划分 | 单阶段 | **两步：Overall（无需 Code Research）→ Detailed（需 Code Research）** |
| 固定章节 | 14 章全部固定 | Overall：修订记录、目录、总体概述、使用场景；Detailed：继承 Overall + DoD |
| 可选章节 | 无（全部必填） | Agent 根据特性复杂度自行决定（领域设计、接口设计、数据模型等） |
| 内容灵活性 | 低（严格按模板填充） | **高**（Agent 自由决定结构、格式、深度） |
| 适用场景 | 大型特性、跨多模块、需正式评审 | 中小特性、快速规划、单一模块 |
