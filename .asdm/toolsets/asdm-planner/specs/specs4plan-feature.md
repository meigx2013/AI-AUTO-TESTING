# Specifications for Plan Feature

## Purpose
本文档定义 `plan-feature` 操作的行为规范，约束特性规划流程的输入解析、场景区分、代码扫描和文档生成逻辑。

## Shared Specifications
共享规范（关键文档引用、数据校验规则、路径约束、可靠性规则）详见 [specs4shared.md](./specs4shared.md)。

## Two-Phase Model

本操作采用**两阶段模式**，将代码调研与正式规划分离，避免单次会话上下文过载导致规划质量下降：

| 阶段 | 名称 | 目标 | 产出 |
|:----:|------|------|------|
| 阶段一 | 调研阶段（Code Research） | 使用 code-explorer 逐库扫描相关代码库，每库撰写独立调研总结文件 | `FT-XXX-{name}-CodeResearch-{repo}.md`（每代码库一个） |
| 阶段二 | 正式规划阶段（Formal Planning） | 基于调研结果编写完整特性规划文档 | `FT-XXX-{name}-Feature.md` |

**多代码库扫描规则**：
- 如涉及多个代码库（如 asdm-admin、asdm-agentorbit、asdm-openclaw-channel），**逐个代码库依次扫描**，每完成一个即撰写该库的调研总结文件
- 每个代码库对应独立的调研总结文件：`FT-XXX-{name}-CodeResearch-{repo-name}.md`
- 单次只扫描一个代码库，避免上下文混淆

**阶段切换**：阶段一完成后（所有代码库均已扫描），提示用户创建新会话（清空上下文），在新会话中再次执行命令自动进入阶段二。

**阶段检测**：阶段二启动时，检查特性目录下是否存在所有需要的调研总结文件——全部存在则进入阶段二；存在缺失则仅扫描缺失的代码库。

## Functional Requirements

### Input Parsing

- 用户以自然语言输入所有参数，AI 自动提取
- 支持混合格式：特性编码（FT-XXX）、模块编号、优先级标记、自由文本描述
- 参数提取规则详见 `actions/plan-feature.md` 的"参数提取规则"章节

### Scenario Detection

根据输入中是否包含已有特性编码，区分两种场景：

| 判定条件 | 场景 | 流程 |
|----------|------|------|
| 输入包含 `FT-\d{3}` 且编码在 `ASDM-ProductPlanning.md` 中存在 | 场景2：已有特性 | 读取已有信息 → 代码扫描 → 创建文档（不重复添加规划条目） |
| 输入无特性编码，或编码不存在 | 场景1：新特性 | 完整规划流程（分配编号 → 代码扫描 → 创建文档 → 更新规划） |

### Phase 1: Code Research (Required for Both Scenarios)

在编写特性文档之前，**必须**先完成调研阶段，使用 code-explorer 对已有代码进行完整扫描。**涉及多个代码库时，逐库扫描并撰写独立调研总结文件**。

1. 根据特性描述和归属模块，确定需要扫描的代码库清单
2. 向用户展示扫描计划，确认代码库清单无遗漏
3. 对清单中的**每个代码库**，依次执行以下步骤（一次只扫描一个代码库）：
   a. 使用 code-explorer 对当前代码库执行扫描，覆盖：
      - 代码库的目录结构和文件组织
      - 与特性描述相关的现有实现（API 端点、Service 层、Controller、前端组件、配置等）
      - 数据库 migration 脚本和数据模型定义
      - 配置文件、环境变量和基础设施定义
      - 与其他代码库的交互接口（API 调用、事件、共享类型等）
   b. 将扫描结果整理为结构化的调研总结文件，写入特性目录：`docs/planning/Feat/FT-XXX-{name}/FT-XXX-{name}-CodeResearch-{repo-name}.md`
   c. 单个代码库的调研总结文件内容包括：
      - 代码库名称和路径
      - 目录结构和关键文件列表
      - 现有实现分析（API 端点、Service 层、数据模型、前端组件等）
      - 关键发现和缺失项（编号格式：`{repo简称}-G1, {repo简称}-G2, ...`，确保跨库编号不冲突）
      - 与其他代码库的交互接口
      - 待确认问题清单（如有）
   d. 当前代码库扫描完成后，向用户简要汇报进度（已完成 X/Y 个代码库），继续扫描下一个
4. **歧义澄清**：如扫描中发现任何不清晰的部分，**必须向用户提出问题确认**，包括但不限于：
   - 模块边界模糊（特性影响范围不确定）
   - 代码逻辑不明（现有实现与预期不一致）
   - 依赖关系不确定（跨模块调用链不清晰）
   - 数据流向不明确（数据在模块间的流转路径）
5. **阶段一完成**：所有代码库扫描完成后，提示用户创建新会话，在新会话中再次执行命令进入阶段二

### Phase 2: Formal Planning

阶段二启动时，首先校验调研完整性：

1. **调研完整性检查**：读取特性目录下所有 `FT-XXX-{name}-CodeResearch-*.md` 文件，检查是否覆盖所有需要的代码库
   - 如调研文件不存在或未覆盖所有代码库 → 自动回退到阶段一，仅扫描缺失的代码库
   - 如部分调研信息不完整 → 向用户报告缺失项并建议重新扫描该代码库
2. 基于所有调研总结文件中的上下文，编写完整的特性规划文档

**文档生成规则**：

- **主文档**（`FT-XXX-{name}-Feature.md`）：仅包含分析结论概述，不内嵌详细代码分析。§3 现有代码分析仅保留每个代码库 1-2 句结论概述 + 关键缺失项数量汇总，并链接到独立代码分析文件
- **代码分析附件**（`FT-XXX-{name}-CodeAnalysis.md`）：包含完整的代码库现状分析（已实现模块、未实现模块、数据库迁移、关键缺失项详细列表）。此文件为主文档 §3 的详细版本，从调研总结文件中提取并结构化

### Scenario 1: New Feature

**阶段一**：
1. 解析输入，提取参数
2. 校验所有输入参数（校验规则见 `specs4shared.md` Data Validation Rules）
3. 分配下一个可用的 FT-XXX 编号（顺序递增），创建特性目录
4. 确定需要扫描的代码库清单，向用户确认
5. 逐库使用 code-explorer 执行代码上下文扫描，每库撰写独立调研总结文件 `FT-XXX-{name}-CodeResearch-{repo-name}.md`
6. 提示用户创建新会话进入阶段二

**阶段二**：
1. 校验所有调研总结文件完整性
2. 读取 `.asdm/toolsets/asdm-planner/specs/templates/Feature-Template.md`，基于所有调研上下文生成：
   - **代码分析附件** `FT-XXX-{name}-CodeAnalysis.md`：包含完整的已实现模块、未实现模块、数据库迁移、关键缺失项详细列表
   - **主特性文档** `FT-XXX-{name}-Feature.md`：§3 现有代码分析仅保留概述结论 + 链接到 CodeAnalysis 文件
3. 在 `ASDM-ProductPlanning.md` 对应的特性列表中新增条目（P1→列表1，P2/P3→列表2），**特性名称列必须包含指向特性文档的 Markdown 链接**，格式为 `[特性名称](./Feat/FT-XXX-{name}/FT-XXX-{name}-Feature.md)`
4. 返回生成结果

### Scenario 2: Existing Feature

**阶段一**：
1. 从输入中识别特性编码（FT-XXX）
2. 从 `ASDM-ProductPlanning.md` 读取该特性的已有信息
3. 如用户提供了额外描述，与已有信息合并
4. 创建特性目录（如不存在）
5. 确定需要扫描的代码库清单，向用户确认
6. 逐库使用 code-explorer 执行代码上下文扫描，每库撰写独立调研总结文件 `FT-XXX-{name}-CodeResearch-{repo-name}.md`
7. 提示用户创建新会话进入阶段二

**阶段二**：
1. 校验所有调研总结文件完整性
2. 检查文档目录是否已存在（不存在→创建；已存在→提示用户确认是否覆盖）
3. 读取 `.asdm/toolsets/asdm-planner/specs/templates/Feature-Template.md`，基于所有调研上下文生成：
   - **代码分析附件** `FT-XXX-{name}-CodeAnalysis.md`：包含完整的已实现模块、未实现模块、数据库迁移、关键缺失项详细列表
   - **主特性文档** `FT-XXX-{name}-Feature.md`：§3 现有代码分析仅保留概述结论 + 链接到 CodeAnalysis 文件
4. **不重复添加** `ASDM-ProductPlanning.md` 条目
5. **更新特性名称链接**：检查 `ASDM-ProductPlanning.md` 中该特性条目的名称列，如尚未包含指向特性文档的 Markdown 链接，则更新为链接格式 `[特性名称](./Feat/FT-XXX-{name}/FT-XXX-{name}-Feature.md)`
6. 返回生成结果

### Output Format

**阶段一输出**：
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

**阶段二输出**：
```json
{
  "phase": "planning",
  "scenario": "new_feature | existing_feature",
  "status": "success | error",
  "feature_id": "FT-XXX",
  "feature_name": "string",
  "module": "number",
  "priority": "P1|P2|P3",
  "release": "string|null",
  "document_path": "string",
  "code_analysis_path": "string",
  "research_paths": [
    "docs/planning/Feat/FT-XXX-name/FT-XXX-name-CodeResearch-asdm-admin.md",
    "docs/planning/Feat/FT-XXX-name/FT-XXX-name-CodeResearch-asdm-agentorbit.md"
  ],
  "planning_updated": true,
  "planning_link_updated": true,
  "timestamp": "ISO 8601 datetime"
}
```

- `phase`：区分阶段一（research）和阶段二（planning）
- `repo_count`：阶段一扫描的代码库数量
- `research_paths`：所有调研总结文件的路径列表（每代码库一个文件）
- `document_path`：主特性文档路径
- `code_analysis_path`：代码分析附件路径（`FT-XXX-{name}-CodeAnalysis.md`）
- `scenario`：区分创建新特性（new_feature）和已有特性创建文档（existing_feature）
- `planning_updated`：场景1 为 true，场景2 为 false
- `planning_link_updated`：如更新了 `ASDM-ProductPlanning.md` 中特性名称的链接则为 true

## Non-Functional Requirements

### Usability
- 自然语言输入应被宽容解析，尽量理解用户意图
- 模糊匹配模块名称时，列出候选供用户选择
- 错误消息应包含具体的修复建议
- 编号分配应自动跳过已使用的编号
- 缺失参数一次性确认，不逐个追问
