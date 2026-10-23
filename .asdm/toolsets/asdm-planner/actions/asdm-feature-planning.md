# Plan Feature

## Metadata

```json
{
  "guid": "f8a9b0c1-d2e3-4f5a-6b7c-8d9e0f1a2b3c",
  "name": "asdm-feature-planning",
  "displayName": "Plan Feature",
  "description": "规划 ASDM 产品特性，生成结构化的完整特性规划文档并更新产品规划总览",
  "toolset": {
    "guid": "e5f6a7b8-c9d0-1e2f-3a4b5c6d7e8f",
    "id": "asdm-planner",
    "name": "ASDM Planner Toolset",
    "version": "1.0.0"
  },
  "scenario": "full-planning"
}
```

## Description
规划 ASDM 产品特性。支持自然语言输入，根据用户描述创建结构化的特性规划文档并更新产品规划总览。支持两种场景：创建全新特性（完整规划流程）或基于已有特性编码创建特性文档。

## Usage
```
/asdm-feature-planning <自然语言描述>
```

用户可以用自然语言描述特性信息，AI 将自动提取所需参数。如缺少必要信息，AI 会向用户询问确认。

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

用户描述一个全新的特性需求，AI 执行完整的特性规划流程：

1. 从自然语言中提取参数（name, module, description 等）
2. 如缺少必填参数，向用户询问确认
3. 校验模块编号存在、特性名称唯一
4. 分配下一个 FT-XXX 编号
5. 在 `docs/planning/Feat/FT-XXX-{name}/` 目录生成特性文档
6. 在 `ASDM-ProductPlanning.md` 特性清单中新增条目
7. 返回规划结果

**示例输入**：
```
/asdm-feature-planning 我需要为资源库模块做一个 MCP 注册表功能，优先级高，要补齐同步、公开 API 和前端管理页面
```

```
/asdm-feature-planning 想给认证模块加个第三方登录集成，支持 GitHub 和 Google，优先级 P2
```

```
/asdm-feature-planning MCP Hosting 需要一个访问控制功能，和认证系统集成，提供 API Key 管理，依赖 FT-003 用户个人令牌
```

### 场景2：基于已有特性编码创建文档

用户给出已在 `ASDM-ProductPlanning.md` 中登记的特性编码，AI 从规划文档读取已有信息并生成特性文档：

1. 识别用户输入中的特性编码（FT-XXX 格式）
2. 从 `ASDM-ProductPlanning.md` 读取该特性的名称、说明、模块、优先级等信息
3. 补充用户可能提供的额外描述
4. 在 `docs/planning/Feat/FT-XXX-{name}/` 目录生成特性文档
5. 如特性已在规划文档中但尚未创建文档目录，则创建；如已存在，提示用户

**示例输入**：
```
/asdm-feature-planning FT-004
```

```
/asdm-feature-planning 帮我创建 FT-022 的特性文档
```

```
/asdm-feature-planning FT-024 MCP Hosting 访问控制，需要和认证系统集成提供 API Key 管理
```

## Process

本操作采用**两阶段模式**，将代码调研与正式规划分离，避免单次会话上下文过载导致规划质量下降。

---

### 阶段一：调研阶段（Code Research）

> 目标：使用 code-explorer 对相关代码库进行完整扫描，将检查结构写成总结 MD 文件，写入对应的特性目录。完成后提示用户创建新会话进入阶段二。

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

4. **确定需要扫描的代码库清单**：
   - 根据特性描述和归属模块，列出需要扫描的所有代码库（如 asdm-admin、asdm-agentorbit、asdm-openclaw-channel 等）
   - 每个代码库对应一个独立的调研总结文件
   - 向用户展示扫描计划，确认代码库清单无遗漏

5. **逐库代码扫描与调研总结**（两种场景均必须执行，**按代码库逐个进行**）：
   
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

6. **阶段一完成提示**：
   - 向用户明确汇报阶段一已完成，列出所有调研总结文件路径
   - **必须提示用户**：请创建新的会话（清空上下文），在新会话中再次执行 `/asdm-feature-planning` 命令（携带相同的特性描述或 FT-XXX 编号），系统将自动进入阶段二
   - 提示示例：
     ```
     ✅ 阶段一（调研阶段）已完成！共扫描 N 个代码库：
     - asdm-admin → docs/planning/Feat/FT-XXX-{name}/FT-XXX-{name}-CodeResearch-asdm-admin.md
     - asdm-agentorbit → docs/planning/Feat/FT-XXX-{name}/FT-XXX-{name}-CodeResearch-asdm-agentorbit.md
     - ...
     
     ⚠️ 请创建新的会话以继续阶段二（正式规划）：
     在新会话中执行 /asdm-feature-planning <相同描述或 FT-XXX 编号>
     系统将检测到已有调研文件，直接进入正式规划阶段。
     ```

---

### 阶段二：正式规划阶段（Formal Planning）

> 目标：检查调研总结文件是否就位，基于调研结果编写完整的特性规划文档。

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

3. **解析输入与参数校验**：
   - 从用户输入中提取参数（与阶段一相同规则）
   - 如用户在阶段二输入中补充了新信息，与调研总结合并

4. **场景1 - 创建新特性**：
   a. 读取 `ASDM-ProductPlanning.md`，确定下一个可用 FT-XXX 编号
   b. 确认特性归属模块，记录预期变更描述
   c. 基于调研总结文件中的上下文，按 `.asdm/toolsets/asdm-planner/specs/templates/Feature-Template.md` 模板生成特性文档到 `docs/planning/Feat/FT-XXX-{name}/FT-XXX-{name}-Feature.md`
   d. 在 `ASDM-ProductPlanning.md` 对应的特性列表中新增条目（根据优先级放入"列表1"或"列表2"），**特性名称列必须包含指向特性文档的 Markdown 链接**，格式为 `[特性名称](./Feat/FT-XXX-{name}/FT-XXX-{name}-Feature.md)`

5. **场景2 - 基于已有特性创建文档**：
   a. 从 `ASDM-ProductPlanning.md` 读取特性信息（名称、说明、模块、优先级、Release、状态、依赖）
   b. 如用户提供了额外描述，与已有信息合并
   c. 检查 `docs/planning/Feat/FT-XXX-{name}/` 目录是否已存在
      - 不存在：创建目录和特性文档
      - 已存在：提示用户文档已存在，询问是否覆盖
   d. 基于调研总结文件中的上下文，按 `.asdm/toolsets/asdm-planner/specs/templates/Feature-Template.md` 模板生成特性文档
   e. **不重复添加** ASDM-ProductPlanning.md 条目（已存在）
   f. **更新特性名称链接**：检查 `ASDM-ProductPlanning.md` 中该特性条目的名称列，如尚未包含指向特性文档的 Markdown 链接，则更新为链接格式 `[特性名称](./Feat/FT-XXX-{name}/FT-XXX-{name}-Feature.md)`

6. **粗体格式检查**（写入文件前必须执行）：按照 `specs4shared.md` 9.4 节规范，逐项检查 B1-B5（粗体内不含句末标点、不包裹长句、无多余空格等），自动修复问题后报告结果。

7. **返回结果**

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
- [Feature-Template.md](../specs/templates/Feature-Template.md) - 特性文档标准模板

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

### 阶段二输出（正式规划完成）
```json
{
  "phase": "planning",
  "scenario": "new_feature | existing_feature",
  "status": "success",
  "feature_id": "FT-XXX",
  "feature_name": "string",
  "module": "number",
  "priority": "P1|P2|P3",
  "release": "string|null",
  "document_path": "docs/planning/Feat/FT-XXX-name/FT-XXX-name-Feature.md",
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
- `planning_updated`：场景1 为 true（新增条目），场景2 为 false（不重复添加条目）
- `planning_link_updated`：如更新了 `ASDM-ProductPlanning.md` 中特性名称的链接则为 true（场景1 新增条目自带链接恒为 true；场景2 如原条目无链接则更新为 true，已有链接则仍为 true）
