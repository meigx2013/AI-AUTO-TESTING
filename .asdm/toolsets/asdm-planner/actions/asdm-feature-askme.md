# ASDM Action: Feature Ask Me

## Metadata

```json
{
  "guid": "a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d",
  "name": "asdm-feature-askme",
  "displayName": "Feature Ask Me",
  "description": "Interview the user to understand, clarify, and refine a feature requirement through targeted questioning, reaching a complete and actionable feature specification",
  "toolset": {
    "guid": "e5f6a7b8-c9d0-1e2f-3a4b5c6d7e8f",
    "id": "asdm-planner",
    "name": "ASDM Planner Toolset",
    "version": "1.0.0"
  },
  "scenario": "feature-elicitation"
}
```

## Main Workflow

Ask me everything you need to know about this feature until we have a complete, unambiguous, and actionable specification. Systematically explore every dimension of the requirement — user stories, acceptance criteria, edge cases, dependencies, constraints, and success metrics.

If information can be found by exploring the codebase (existing patterns, similar features, APIs, data models), explore the codebase first before asking.

For each question, provide your recommended answer based on context.

### When No Feature Is Specified

If the user invokes this action **without** specifying a new feature idea or an existing feature to refine:

1. Read `docs/planning/ASDM-ProductPlanning.md` to understand the current product roadmap
2. Review the feature lists:
   - **设计中/实现中 (Designing/Implementing)** — features currently in progress
   - **规划中 (Planned)** — identified but not yet designed
   - **已实现 (Implemented)** — already delivered
3. Analyze gaps between planned capabilities and the product vision:
   - Are there unaddressed user needs in existing modules?
   - Do any modules have significant 🔵 planned items that could be consolidated into a new feature?
   - Are there cross-cutting concerns not covered by existing features?
4. Propose candidate new features to the user based on gap analysis, including:
   - Which module(s) the feature belongs to
   - Why it's needed (business value / problem statement)
   - Suggested priority relative to existing roadmap items
5. Let the user choose which candidate to explore, then proceed with the standard elicitation flow

### When a New Feature Is Specified

If the user invokes this action **with** a new feature idea (not an existing FT-xxx identifier):

1. **Determine Feature ID**: Read `docs/planning/ASDM-ProductPlanning.md` to find the next available FT-xxx ID (current highest is FT-059, so next would be FT-060 if not already used — check both 设计中/实现中 and 规划中 lists to confirm)
2. **Confirm responsible person**: If the user has not specified a responsible person (负责人), **必须询问用户**指定负责人姓名后再继续
3. **Create the feature directory**: `docs/planning/Feat/FT-{id}-{name}/`
4. **Create the AskMe document** at: `docs/planning/Feat/FT-{id}-{name}/FT-{id}-{name}-AskMe.md` using the template below
5. **Register in ProductPlan**: 在 `docs/planning/ASDM-ProductPlanning.md` 的「特性列表1 - 设计中/实现中」表格**顶部**插入新特性行，格式如下：
   - 编号：`FT-{id}`
   - 分类：`0-通用`（除非用户指定其他分类）
   - 特性名称：`[{name}](./Feat/FT-{id}-{name}/FT-{id}-{name}-AskMe.md)`（链接到 AskMe 文档）
   - 优先级：`P1`（除非用户指定其他优先级）
   - 版本：当前迭代版本
   - 负责人：用户指定的负责人
   - 状态：`🟣 澄清中`
   - 特性说明：从用户描述中提取的一句话摘要
6. Proceed with the standard elicitation flow (Steps 1–6), and **continuously update the AskMe document** as each question is answered:
   - Update the 背景摘要 as understanding deepens
   - Add new 决策点 for each unclear decision point, with options table and recommendation
   - Update the 决策汇总 table when decision points are added or resolved
   - Record confirmed answers in the 回答记录 section with date
   - Update branch 状态 from `⏳ 待确认` to `✅ 已确认` when answered
   - Update the top-level 状态 field accordingly

#### AskMe Document Template（结构化模板）

Agent **必须**遵循以下模板结构生成 AskMe 文档。保留章节（背景摘要、决策点、决策汇总、回答记录、关联文档、文档元信息）为必填项，但每个章节内部的子节（如背景摘要中的二级标题、决策点的具体内容）可根据特性需要自由组织。

```markdown
# FT-{id} {Feature Name} — 需求访谈追问

> 本文档记录对 FT-{id} {Feature Name} 特性的逐问题追问，用于澄清需求模糊点后制定最终特性规格。

**创建日期**：{YYYY-MM-DD}
**状态**：待回答

---

## 背景摘要

<!-- Agent 在此撰写特性背景。可包含但不限于以下子节：-->

### 核心价值

<!-- 描述该特性要解决的核心问题和业务价值 -->

### 变更范围

| 变更模块 | 变更内容 |
|----------|----------|
| <!-- 模块名 --> | <!-- 变更描述 --> |

### 已澄清问题（来自 Idea 文档）

| 编号 | 问题 | 澄清结论 |
|:----:|------|----------|
| Q1 | <!-- 问题 --> | <!-- 结论 --> |

---

## 决策点

<!-- 逐个决策点，每个决策点遵循以下结构 -->

### 决策点 {N}：{决策标题}

**问题**：{需要决策的核心问题}

**背景**：
- {补充决策所需的上下文信息}

**选项**：

| 选项 | 描述 | 优点 | 缺点 |
|------|------|------|------|
| A | {选项描述} | {优点} | {缺点} |
| B | {选项描述} | {优点} | {缺点} |

**推荐**：✅ 选项 X — {推荐方案简述}

**确认理由**：
1. {理由1}
2. {理由2}

**状态**：⏳ 待确认 | ✅ 已确认

---

## 决策汇总

| # | 决策 | 推荐方案 | 状态 |
|---|------|---------|------|
| 1 | {决策标题} | {推荐方案} | ⏳ 待确认 |

---

## 回答记录

> 以下由用户逐一回答后填写

### 决策点 {N} 回答

**回答**：✅ {回答内容}
**日期**：{YYYY-MM-DD}

---

## 关联文档

- [{文档名}]({路径}) — {说明}

---

**文档版本**：0.1
**创建日期**：{YYYY-MM-DD}
**最后更新**：{YYYY-MM-DD}
**维护者**：AI Planner
```

##### 模板使用规则

1. **标题格式**：`# FT-{id} {Feature Name} — 需求访谈追问`，副标题统一使用"需求访谈追问"
2. **引用块**：标题下方的引用块固定描述文档用途，不可省略
3. **创建日期与状态**：紧跟引用块，状态可选值为 `待回答` / `进行中` / `已完成`
4. **背景摘要**：必填，至少包含特性背景概述；`核心价值`、`变更范围`、`已澄清问题` 子节按需使用
5. **决策点**：核心章节，每个待澄清的决策点必须按模板结构组织（问题→背景→选项表→推荐→确认理由→状态）
6. **决策汇总表**：必填，所有决策点的概览，便于快速浏览
7. **回答记录**：必填，用户确认后逐条记录回答内容和日期
8. **关联文档**：必填，列出相关的 idea、feature、规划等文档链接
9. **文档元信息**：必填，包含版本、创建日期、最后更新、维护者

### When an Existing Feature Is Specified

If the user specifies an existing feature by FT-xxx identifier:

1. Locate and read the existing feature documents in `docs/planning/Feat/FT-{id}-{name}/`
2. Check if an `-AskMe.md` already exists; if so, resume from where it left off
3. If no `-AskMe.md` exists, create one initialized from the existing Feature/Idea content
4. Focus elicitation on gaps, ambiguities, or new requirements since the last specification

### Purpose

- Elicit complete feature requirements through structured interviewing
- Clarify ambiguities and resolve contradictions in user intent
- Identify edge cases, constraints, and non-functional requirements
- Produce an actionable feature specification ready for implementation planning
- Leverage existing codebase knowledge to reduce redundant questions

### Steps

1. Understand the user's initial feature idea or description
2. Explore the codebase for context: existing patterns, related features, data models
3. Structure unclear points as **决策点** in the AskMe document, each with:
   - A clear **问题** statement
   - **背景** information to help the user make an informed decision
   - An **选项** table (with 描述/优点/缺点 columns) presenting viable alternatives
   - A **推荐** option with **确认理由** based on codebase evidence and best practices
   - A **状态** field (⏳ 待确认 → ✅ 已确认)
4. Present decisions to the user one by one (or in batches if related), get confirmation or alternative choice
5. Record each confirmed answer in the **回答记录** section, update the **决策汇总** table
6. Surface edge cases and error handling requirements as additional 决策点
7. When all decisions are resolved, synthesize findings into a complete feature specification

### Input

- User's feature description or idea (can be rough or detailed) — **or empty if no feature is specified**
- Existing FT-xxx identifier (if refining an existing feature)
- Workspace context for codebase exploration
- Product planning document: `docs/planning/ASDM-ProductPlanning.md` (used when no feature is specified)

## Output

### 访谈进行中输出（持续更新）
```json
{
  "phase": "elicitation",
  "status": "in_progress",
  "feature_id": "FT-XXX",
  "feature_name": "string",
  "document_path": "docs/planning/Feat/FT-XXX-name/FT-XXX-name-AskMe.md",
  "questions_asked": 5,
  "questions_answered": 3,
  "questions_pending": 2,
  "open_issues": [
    { "id": "Q1", "question": "string", "status": "resolved | pending" }
  ],
  "timestamp": "ISO 8601 datetime"
}
```

### 访谈完成输出
```json
{
  "phase": "elicitation",
  "status": "completed",
  "feature_id": "FT-XXX",
  "feature_name": "string",
  "document_path": "docs/planning/Feat/FT-XXX-name/FT-XXX-name-AskMe.md",
  "total_questions": 8,
  "resolved_questions": 8,
  "key_decisions": ["decision 1", "decision 2"],
  "user_stories": [
    { "id": "US1", "title": "string", "acceptance_criteria": ["criterion 1", "criterion 2"] }
  ],
  "next_steps": [
    "执行 /asdm-feature-planning-lite-overall FT-XXX 进入概要设计（推荐）",
    "执行 /asdm-feature-planning-lite FT-XXX 进入轻量规划（一站式）",
    "执行 /asdm-feature-planning FT-XXX 进入完整规划"
  ],
  "timestamp": "ISO 8601 datetime"
}
```

- `phase`：固定为 "elicitation"（需求访谈阶段）
- `status`：区分 "in_progress"（访谈进行中）和 "completed"（访谈完成）
- `questions_asked/answered/pending`：访谈进行中时的问答进度统计
- `open_issues`：尚未解决的待澄清问题清单
- `key_decisions`：访谈过程中确认的关键技术决策
- `user_stories`：整理出的用户故事及验收标准
- `next_steps`：访谈完成后建议的下一步操作（推荐优先执行 `/asdm-feature-planning-lite-overall` 进入概要设计）

## Downstream Flow

本 action 完成后的推荐下游流程：

```
/asdm-feature-askme          ← 当前步骤：需求访谈
        │
        ▼
/asdm-feature-planning-lite-overall   ← 概要设计（总体概述 + 使用场景，无需 Code Research）
        │
        ▼
/asdm-feature-planning-lite-detailed  ← 详细设计（Agent 自由扩展区 + DoD，需 Code Research）
        │
        ▼
/asdm-feature-breakdown               ← 实施计划拆解
```

### 分阶段 Lite 规划流程（推荐）

1. **需求访谈**：`/asdm-feature-askme` → 生成 AskMe 文档
2. **概要设计**：`/asdm-feature-planning-lite-overall` → 生成 `FT-XXX-{name}-Feature-Overall.md`
3. **详细设计**：`/asdm-feature-planning-lite-detailed` → 生成 `FT-XXX-{name}-Feature-Detailed.md`
4. **实施拆解**：`/asdm-feature-breakdown` → 生成 `FT-XXX-{name}-Plan.md`

> 分阶段模式将概要设计（无需代码调研，快速产出）与详细设计（需代码调研，深度分析）分离，避免单次会话上下文过载。
