---
registryId: asdm-planner
name: asdm-planner
description: 'ASDM 产品规划与文档工具集：提供特性想法记录、特性规划、规格审查、进展检查、模块功能文档编写和场景化操作手册编写的标准化操作，覆盖特性从想法到实现的完整生命周期。'
version: 1.0.0
guid: e5f6a7b8-c9d0-1e2f-3a4b5c6d7e8f
entryPoint: README.md
configType: toolset
---

# ASDM Planner Toolset

## Metadata

```json
{
  "guid": "e5f6a7b8-c9d0-1e2f-3a4b5c6d7e8f",
  "name": "asdm-planner",
  "displayName": "ASDM Planner Toolset",
  "description": "ASDM 产品规划与文档工具集，提供特性规划、规格审查、进展检查、模块文档编写和场景化操作手册编写的标准化操作",
  "version": "1.0.0"
}
```

## Overview

ASDM Planner 为产品团队和 AI 助手提供一套标准化的规划与文档操作，帮助：

- **想法记录**：快速记录新特性想法，分配编号、创建初始文档
- **特性规划**：基于代码扫描，生成结构化的特性规划文档
- **规格审查**：检查特性规格的完整性、一致性和可追溯性
- **迭代管理**：生成迭代计划、跟踪特性状态和依赖关系
- **文档编写**：基于代码扫描生成面向用户的模块功能说明文档和操作手册

## Components

### Actions

Actions 被转换为 AI 编码工具的斜杠命令。参见 `actions/` 目录。

| 命令 | 用途 | 文档深度 | 代码扫描 |
|------|------|----------|:--------:|
| `/asdm-feature-idea` | 快速记录特性想法 | 仅概述 + 待澄清问题 | ❌ |
| `/asdm-feature-planning-lite` | 轻量特性规划 | 6 章精简文档 | ✅ |
| `/asdm-feature-planning` | 完整特性规划 | 14 章完整文档 | ✅ |
| `/asdm-feature-review` | 规格审查 | 审查报告 | ✅ |
| `/asdm-feature-progress` | 进展检查 | 进展报告 | ✅ |
| `/asdm-docs-module-update` | 模块功能文档 | 面向用户的模块说明 | ✅ |
| `/asdm-docs-manual-update` | 场景化操作手册 | 面向用户的操作手册 | ✅ |

### Specs

Specifications 提供工具集的规则、指南和模板。参见 `specs/` 目录。

- `specs/` - 规范目录
  - `specs4shared.md` - 共享规范（校验规则、路径约束、编写要点）
  - `specs4asdm-feature-idea.md` - 特性想法记录行为规范
  - `specs4asdm-feature-planning.md` - 特性规划行为规范
  - `specs4asdm-feature-review.md` - 规格审查行为规范
  - `specs4asdm-feature-progress.md` - 进展检查行为规范
  - `specs4docs-module-update.md` - 模块文档编写行为规范
  - `specs4docs-manual-update.md` - 场景化操作手册编写行为规范
  - `templates/` - 模板目录
    - `Feature-Template.md` - 特性文档14章标准结构
    - `Progress-Report-Template.md` - 进展报告标准结构
    - `Module-Doc-Template.md` - 模块功能说明文档标准结构
    - `Manual-Doc-Template.md` - 场景化操作手册标准结构

### Tools

Tools 是为 CLI 环境设计的实用工具。参见 `tools/` 目录。

## Installation

参见 [INSTALL.md](INSTALL.md) 获取安装说明。

## Usage

### 特性生命周期全流程

ASDM Planner 覆盖特性从想法到实现的完整生命周期。以下是推荐的使用流程：

```
 ┌─────────────────────────────────────────────────────────────────────────────────┐
 │                           ASDM 研发工艺流程                                       │
 ├─────────────────────────────────────────────────────────────────────────────────┤
 │                                                                                 │
 │  ┌───────────┐     ┌───────────────┐     ┌─────────────────────────────────┐   │
 │  │ 💡 想法记录 │────→│ 🎤 需求访谈    │────→│         📝 特性规划               │   │
 │  │  /idea     │     │   /askme      │     │                                 │   │
 │  │  (可选)    │     │  (必须前置)    │     │  ┌───────────────────────────┐  │   │
 │  └─────┬─────┘     └───────┬───────┘     │  │ 阶段一：代码调研 (Research) │  │   │
 │        │ 产出:              │ 产出:        │  │  逐库 code-explorer 扫描   │  │   │
 │        │ · Idea文档         │ · AskMe文档  │  │  → CodeResearch-*.md      │  │   │
 │        │ · 规划条目          │ · 决策点确认  │  │  完成后创建新会话 ──────┐   │  │   │
 │        └──(跳过)──→─────────┘              │  └───────────────────────────┘  │   │
 │                                            │               │ 新会话           │   │
 │                                            │  ┌────────────▼──────────────┐  │   │
 │                                            │  │ 阶段二：正式规划 (Planning) │  │   │
 │                                            │  │                            │  │   │
 │                                            │  │  ┌──────────┐ ┌──────────┐│  │   │
 │                                            │  │  │/planning │ │/planning ││  │   │
 │                                            │  │  │  -lite   │ │ (full)   ││  │   │
 │                                            │  │  │最小骨架+  │ │14章完整  ││  │   │
 │                                            │  │  │自由扩展   │ │固定模板  ││  │   │
 │                                            │  │  └──────────┘ └──────────┘│  │   │
 │                                            │  └───────────────────────────┘  │   │
 │                                            └───────────────┬─────────────────┘   │
 │                                               产出:        │                     │
 │                                               · Feature.md │                     │
 │                                               · 规划更新    │                     │
 │                                                            │                     │
 │                                             ┌──────────────▼──────────────────┐  │
 │                                             │      🔍 规格审查 /review         │  │
 │                                             │  completeness · consistency ·    │  │
 │                                             │  traceability + 粗体格式检查     │  │
 │                                             └──────────────┬──────────────────┘  │
 │                                                            │                     │
 │                                                ┌───────────▼───────────┐        │
 │                                                │    🔨 开发实现         │        │
 │                                                └───────────┬───────────┘        │
 │                                                            │                     │
 │                                             ┌──────────────▼──────────────────┐  │
 │                                             │     📊 进展检查 /progress        │  │
 │                                             │  更新submodule → 代码扫描 →      │  │
 │                                             │  逐项对照DoD(✅🟡❌)评估完成度    │  │
 │                                             │  → 生成进展报告                  │  │
 │                                             └──────────────┬──────────────────┘  │
 │                                                            │                     │
 │                                             ┌──────────────▼──────────────────┐  │
 │                                             │       📚 文档编写                │  │
 │                                             │  /docs-module-update            │  │
 │                                             │  /docs-manual-update            │  │
 │                                             └────────────────────────────────┘  │
 └─────────────────────────────────────────────────────────────────────────────────┘
```

### 阶段 1：想法记录 → `/asdm-feature-idea`

**适用场景**：团队产生新特性想法，需要快速记录，避免灵感流失。

**执行效果**：
- 基于自然语言描述进行语义分析
- 分配 FT-XXX 编号
- 创建特性目录 `docs/planning/Feat/FT-XXX-{名称}/`
- 生成 v0.1 想法文档（仅概述 + 待澄清问题）
- 插入 `ASDM-ProductPlanning.md` 特性列表2（规划中）顶部

**使用示例**：
```
/asdm-feature-idea 想给平台加个通知中心，用户能收到系统消息和协作通知
```

**交互流程**：
1. AI 解析输入，提取特性名称、模块、描述等参数
2. 如缺少必填信息，AI 向用户询问确认
3. AI 进行语义分析，生成 3-7 个待澄清问题
4. 创建想法文档并写入文件系统
5. 更新 `ASDM-ProductPlanning.md` 特性列表
6. 向用户展示待澄清问题清单，引导逐一回答
7. 用户每回答一个问题，AI 即时更新文档（状态 ✅ 已澄清 + 澄清记录）

**产出物**：
- `docs/planning/Feat/FT-XXX-{名称}/FT-XXX-{名称}-Feature.md`（v0.1，💡 想法记录）
- `ASDM-ProductPlanning.md` 特性列表2 新增条目

### 阶段 2：特性规划 → `/asdm-feature-planning` 或 `/asdm-feature-planning-lite`

**适用场景**：特性进入正式规划，需要深度分析和完整文档。

**选择依据**：

| 维度 | `/asdm-feature-planning-lite` | `/asdm-feature-planning` |
|------|:-----------------------------:|:------------------------:|
| 特性规模 | 中小特性 | 大型特性 |
| 文档章节 | 6 章（概述+DoD+领域设计+实现计划+测试计划+相关文档） | 14 章（完整结构） |
| 代码扫描 | ✅ 两阶段 | ✅ 两阶段 |
| 适用场景 | 快速规划，聚焦核心 | 深度规划，全面覆盖 |

**执行效果**：
- 两阶段代码扫描（阶段一：调研扫描 → 阶段二：正式规划）
- 生成特性文档（lite: 6 章 / full: 14 章）
- 更新 `ASDM-ProductPlanning.md` 特性状态

**使用示例**：
```
/asdm-feature-planning-lite FT-040 为资源库模块做 MCP 注册表
/asdm-feature-planning 为平台构建统一通知中心，涉及认证集成和实时推送
```

**两阶段流程**：

```
阶段一：调研扫描
─────────────────
1. 确定需要扫描的代码库清单
2. 逐库执行 code-explorer 扫描
3. 每库生成独立调研总结文件
4. 所有代码库扫描完成
5. 提示用户创建新会话，进入阶段二

        ↓ 新会话

阶段二：正式规划
─────────────────
1. 校验调研总结文件完整性
2. 基于调研结果生成特性文档
3. 写入文件系统
4. 更新 ASDM-ProductPlanning.md
```

**产出物**：
- `docs/planning/Feat/FT-XXX-{名称}/FT-XXX-{名称}-Feature.md`（v1.0+，📝 规划中）
- `FT-XXX-{名称}-CodeResearch-{代码库名}.md`（每库一份调研总结）
- `ASDM-ProductPlanning.md` 特性状态更新

### 阶段 3：规格审查 → `/asdm-feature-review`

**适用场景**：特性文档编写完成后，需要检查完整性、一致性和可追溯性。

**执行效果**：
- 基于代码扫描验证文档内容
- 检查三大维度：完整性（completeness）、一致性（consistency）、可追溯性（traceability）
- 生成审查报告，标注 error / warning / info
- 支持严格模式（warning 视为 error）

**使用示例**：
```
/asdm-feature-review 审查 FT-003 的完整性
/asdm-feature-review 严格审查 FT-026
```

**审查维度**：

| 维度 | 检查内容 |
|------|----------|
| 完整性 | 文档章节是否完整、必填项是否缺失、DoD 是否覆盖所有需求 |
| 一致性 | 模块归属是否正确、依赖关系是否双向一致、状态标记是否统一 |
| 可追溯性 | 需求→DoD→测试用例是否可追溯、代码引用是否有效 |

**产出物**：
- 对话中输出审查报告（error / warning / info 列表）
- 如需修改文档，AI 会提出修改建议

### 阶段 4：进展检查 → `/asdm-feature-progress`

**适用场景**：特性进入开发后，需要检查实现进展、对照 DoD 评估完成度。

**执行效果**：
- 扫描代码库，逐项对照 DoD 检查实现状态
- 检查 release 分支上的实现情况
- 生成标准进展报告，包含 DoD 逐项状态、完成度计算、代码清单

**使用示例**：
```
/asdm-feature-progress 检查 FT-040 的实现进展
/asdm-feature-progress 检查 FT-003，scope=all
```

**产出物**：
- `docs/planning/Feat/FT-XXX-{名称}/FT-XXX-{名称}-特性实现进展报告.md`

### 辅助：文档编写 → `/asdm-docs-module-update` 和 `/asdm-docs-manual-update`

**适用场景**：需要为 ASDM 文档站点编写面向用户的文档。

| 命令 | 文档类型 | 存放位置 |
|------|----------|----------|
| `/asdm-docs-module-update` | 模块功能说明 | `asdm-docs/public/docs/zh-cn/content/platform/modules/` |
| `/asdm-docs-manual-update` | 场景化操作手册 | `asdm-docs/public/docs/zh-cn/content/platform/manual/` |

**使用示例**：
```
/asdm-docs-module-update 编写组织结构管理模块的文档
/asdm-docs-manual-update 编写用户注册和登录的操作手册
```

## 推荐工作流

### 工作流 A：新特性从想法到实现

```
Step 1: /asdm-feature-idea 想给平台加个通知中心
        → 创建 FT-042 通知中心，v0.1 想法文档
        → 回答待澄清问题（Q1-Q5）
        → 文档更新至 v0.1.5

Step 2: /asdm-feature-planning-lite FT-042
        → 阶段一：代码扫描调研
        → 阶段二：生成 6 章精简文档
        → 文档升级至 v1.0

Step 3: /asdm-feature-review 审查 FT-042
        → 检查完整性、一致性、可追溯性
        → 修复审查发现的问题

Step 4: (开发实现中...)

Step 5: /asdm-feature-progress 检查 FT-042
        → 对照 DoD 逐项检查实现状态
        → 生成进展报告

Step 6: /asdm-docs-module-update 编写通知中心模块文档
        → 生成面向用户的功能说明文档
```

### 工作流 B：快速规划中小特性

```
Step 1: /asdm-feature-planning-lite 为资源库添加标签功能，模块4，P2
        → 跳过想法阶段，直接进入规划
        → 两阶段代码扫描 + 6 章文档

Step 2: /asdm-feature-review 审查 FT-043
        → 快速审查

Step 3: (开发 + 进展跟踪)
```

### 工作流 C：大型特性深度规划

```
Step 1: /asdm-feature-idea 构建过程集成框架，涉及工作项/迭代/看板/流水线多个模块
        → 记录想法，澄清关键问题

Step 2: /asdm-feature-planning FT-044
        → 阶段一：多代码库深度调研
        → 阶段二：14 章完整文档

Step 3: /asdm-feature-review 严格审查 FT-044
        → 严格模式审查

Step 4: (分阶段开发 + 定期进展检查)
```

## 核心概念

### 特性编号

格式 `FT-XXX`（三位数字，左补零），顺序递增，自动跳过已使用的编号。示例：FT-003、FT-040、FT-099。

### 特性状态流转

```
🔵 规划中 → 🟠 设计中 → 🟡 实现中 → ✅ 已实现
    │          │          │
    └──────────┴──────────┴──→ ❌ 已废弃
```

### 模块归属

特性归属于 ASDM Platform 的功能模块（编号 1-15），参见 `docs/planning/ASDM-ProductPlanning.md` 模块清单：

| 编号 | 模块名称 | 编号 | 模块名称 |
|:----:|----------|:----:|----------|
| 1 | 认证与用户管理 | 9 | 制品管理 |
| 2 | 组织与项目管理 | 10 | 代码评审 |
| 3 | 项目空间 | 11 | 知识库 |
| 4 | 资源库管理 | 12 | AI 能力 |
| 5 | 工作项管理 | 13 | MCP Hosting |
| 6 | 迭代与看板 | 14 | 部署运维 |
| 7 | CI/CD 流水线 | 15 | AgentOrbit 集成 |
| 8 | 测试管理 | | |

### 文件结构

```
docs/planning/
├── ASDM-ProductPlanning.md          ← 产品规划总览
└── Feat/
    ├── FT-003-用户个人令牌/
    │   ├── FT-003-用户个人令牌-Feature.md              ← 特性文档
    │   ├── FT-003-用户个人令牌-CodeResearch-asdm-admin.md  ← 调研总结
    │   └── FT-003-用户个人令牌-特性实现进展报告.md        ← 进展报告
    └── FT-040-MCP注册表/
        ├── FT-040-MCP注册表-Feature.md
        └── ...
```

## 关键文档索引

| 文档 | 路径 | 用途 |
|------|------|------|
| 产品规划总览 | `docs/planning/ASDM-ProductPlanning.md` | 模块定义、特性清单、编号分配 |
| 特性文档模板 | `specs/templates/Feature-Template.md` | 特性文档14章标准结构 |
| 进展报告模板 | `specs/templates/Progress-Report-Template.md` | 进展报告标准结构 |
| 共享规范 | `specs/specs4shared.md` | 校验规则、路径约束、编写要点 |

## Notes

- 命令文件仅包含引用指引，不包含 action 完整内容，避免重复和版本不一致
- AI 执行时会读取 action 文件，action 文件会进一步引用 specs 文档和产品规划文档
- 更新 action 或 specs 时无需重新安装，AI 每次执行都会读取最新版本
