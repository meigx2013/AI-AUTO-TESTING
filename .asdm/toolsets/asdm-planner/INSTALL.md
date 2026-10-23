# ASDM Planner Toolset Installation

**Toolset ID:** `asdm-planner`

## Overview
ASDM Planner 为产品团队和 AI 助手提供标准化的特性规划、规格审查和文档编写操作，包括特性文档生成、产品规划更新、规格审查和模块功能文档编写。

## AI Guided Installation
使用 AI 引导安装时，将以下提示复制到 AI 编码工具的聊天窗口：

```shell
Follow instructions in .asdm/toolsets/asdm-planner/INSTALL.md
```

## Installation Steps

### 1. Detect the current Agentic Engine provider

检测当前 AI 编码助手的提供者：

- 若 `.claude` 目录存在 → `Claude Code`
- 若 `.github` 目录存在 → `GitHub Copilot`
- 若 `.codebuddy` 目录存在 → `Tencent CodeBuddy` / `Qoder`
- 若 `.qoder` 目录存在 → `Qoder`
- 若均未找到 → 提示用户手动选择

### 2. Register shortcut commands for ASDM Planner

在 Agentic Engine 的命令入口中注册快捷命令。**不再复制 action 文件内容**，而是注入一个引用指引，让 AI 读取 toolset 中的原始 action 文件。这样做的好处：
- 避免内容重复，更新 action 时无需同步多处
- AI 直接读取最新版本，不会因缓存导致使用旧版指令

#### For Claude Code (`.claude/commands/`):

```bash
mkdir -p .claude/commands/

# asdm-feature-idea command
cat > .claude/commands/asdm-feature-idea.md << 'EOF'
---
description: "快速记录新特性想法，分配编号、创建初始概述文档"
argument-hint: "[特性想法描述，如：想给平台加个通知中心]"
---

Follow .asdm/toolsets/asdm-planner/actions/asdm-feature-idea.md
EOF

# asdm-feature-planning command
cat > .claude/commands/asdm-feature-planning.md << 'EOF'
---
description: "规划 ASDM 产品特性，生成结构化的特性规划文档"
argument-hint: "[特性描述或特性编码，如：FT-004 或 为资源库模块做 MCP 注册表]"
---

Follow .asdm/toolsets/asdm-planner/actions/asdm-feature-planning.md
EOF

# asdm-feature-review command
cat > .claude/commands/asdm-feature-review.md << 'EOF'
---
description: "审查 ASDM 特性规格文档，检查完整性、一致性和可追溯性"
argument-hint: "[特性编号或名称，如：FT-003 或 数据上报API]"
---

Follow .asdm/toolsets/asdm-planner/actions/asdm-feature-review.md
EOF

# asdm-feature-progress command
cat > .claude/commands/asdm-feature-progress.md << 'EOF'
---
description: "检查 ASDM 特性实现进展，生成标准进展报告"
argument-hint: "[特性编号，如：FT-040]"
---

Follow .asdm/toolsets/asdm-planner/actions/asdm-feature-progress.md
EOF

# asdm-docs-module-update command
cat > .claude/commands/asdm-docs-module-update.md << 'EOF'
---
description: "编写或更新 ASDM 模块功能说明文档"
argument-hint: "[模块名称和描述，如：编写组织结构管理模块的文档]"
---

Follow .asdm/toolsets/asdm-planner/actions/asdm-docs-module-update.md
EOF

# asdm-docs-manual-update command
cat > .claude/commands/asdm-docs-manual-update.md << 'EOF'
---
description: "编写或更新 ASDM 场景化操作手册"
argument-hint: "[场景名称和描述，如：编写用户注册和登录的操作手册]"
---

Follow .asdm/toolsets/asdm-planner/actions/asdm-docs-manual-update.md
EOF

# asdm-feature-planning-lite command
cat > .claude/commands/asdm-feature-planning-lite.md << 'EOF'
---
description: "轻量版特性规划，生成精简特性文档（完成规范+实现计划+测试计划）"
argument-hint: "[特性描述或特性编码，如：FT-004 或 为资源库模块做 MCP 注册表]"
---

Follow .asdm/toolsets/asdm-planner/actions/asdm-feature-planning-lite.md
EOF

# asdm-feature-planning-lite-overall command
cat > .claude/commands/asdm-feature-planning-lite-overall.md << 'EOF'
---
description: "轻量版特性规划 - 概要设计阶段，输出总体概述与使用场景（无需代码调研）"
argument-hint: "[特性描述或特性编码，如：FT-004 或 为资源库模块做 MCP 注册表]"
---

Follow .asdm/toolsets/asdm-planner/actions/asdm-feature-planning-lite-overall.md
EOF

# asdm-feature-planning-lite-detailed command
cat > .claude/commands/asdm-feature-planning-lite-detailed.md << 'EOF'
---
description: "轻量版特性规划 - 详细设计阶段，基于概要设计输出扩展章节和完成规范（需代码调研）"
argument-hint: "[特性描述或特性编码，如：FT-004 或 为资源库模块做 MCP 注册表]"
---

Follow .asdm/toolsets/asdm-planner/actions/asdm-feature-planning-lite-detailed.md
EOF

# asdm-feature-askme command
cat > .claude/commands/asdm-feature-askme.md << 'EOF'
---
description: "通过提问引导用户完善特性需求，形成完整可执行的需求规格"
argument-hint: "[特性描述或问题，如：我想做个消息通知功能]"
---

Follow .asdm/toolsets/asdm-planner/actions/asdm-feature-askme.md
EOF

# asdm-toolset-showcase-generator command
cat > .claude/commands/asdm-toolset-showcase-generator.md << 'EOF'
---
description: "根据 toolset 目录自动生成标准化市场价值展示文档（showcase），含 Mermaid 图验证"
argument-hint: "[toolset目录路径，如：.asdm/toolsets/req-analyzer]"
---

Follow .asdm/toolsets/asdm-planner/actions/asdm-toolset-showcase-generator.md
EOF

# asdm-feature-breakdown command
cat > .claude/commands/asdm-feature-breakdown.md << 'EOF'
---
description: "将已完成设计的 Feature 文档拆分为具体的实施步骤和任务，生成结构化的实施计划文档（Plan）"
argument-hint: "[特性编号或描述，如：FT-041 或 把 FT-060 的设计文档拆成实施计划]"
---

Follow .asdm/toolsets/asdm-planner/actions/asdm-feature-breakdown.md
EOF

# asdm-stats command
cat > .claude/commands/asdm-stats.md << 'EOF'
---
description: "统计 ASDM 产品线所有进展情况，生成代码库统计、提交频率、模块与特性数据图表并更新 README.md"
argument-hint: ""
---

Follow .asdm/toolsets/asdm-planner/actions/asdm-stats.md
EOF
```

#### For GitHub Copilot (`.github/prompts/`):

```bash
mkdir -p .github/prompts/

# asdm-feature-idea prompt
cat > .github/prompts/asdm-feature-idea.prompt.md << 'EOF'
---
agent: 'agent'
description: '快速记录新特性想法，分配编号、创建初始概述文档'
argument-hint: '输入特性想法描述，如：想给平台加个通知中心'
---

Follow .asdm/toolsets/asdm-planner/actions/asdm-feature-idea.md
EOF

# asdm-feature-planning prompt
cat > .github/prompts/asdm-feature-planning.prompt.md << 'EOF'
---
agent: 'agent'
description: '规划 ASDM 产品特性，生成结构化的特性规划文档'
argument-hint: '输入特性描述或特性编码，如：FT-004 或 为资源库模块做 MCP 注册表'
---

Follow .asdm/toolsets/asdm-planner/actions/asdm-feature-planning.md
EOF

# asdm-feature-review prompt
cat > .github/prompts/asdm-feature-review.prompt.md << 'EOF'
---
agent: 'agent'
description: '审查 ASDM 特性规格文档，检查完整性、一致性和可追溯性'
argument-hint: '输入特性编号或名称，如：FT-003 或 数据上报API'
---

Follow .asdm/toolsets/asdm-planner/actions/asdm-feature-review.md
EOF

# asdm-feature-progress prompt
cat > .github/prompts/asdm-feature-progress.prompt.md << 'EOF'
---
agent: 'agent'
description: '检查 ASDM 特性实现进展，生成标准进展报告'
argument-hint: '输入特性编号，如：FT-040'
---

Follow .asdm/toolsets/asdm-planner/actions/asdm-feature-progress.md
EOF

# asdm-docs-module-update prompt
cat > .github/prompts/asdm-docs-module-update.prompt.md << 'EOF'
---
agent: 'agent'
description: '编写或更新 ASDM 模块功能说明文档'
argument-hint: '输入模块名称和描述，如：编写组织结构管理模块的文档'
---

Follow .asdm/toolsets/asdm-planner/actions/asdm-docs-module-update.md
EOF

# asdm-docs-manual-update prompt
cat > .github/prompts/asdm-docs-manual-update.prompt.md << 'EOF'
---
agent: 'agent'
description: '编写或更新 ASDM 场景化操作手册'
argument-hint: '输入场景名称和描述，如：编写用户注册和登录的操作手册'
---

Follow .asdm/toolsets/asdm-planner/actions/asdm-docs-manual-update.md
EOF

# asdm-feature-planning-lite prompt
cat > .github/prompts/asdm-feature-planning-lite.prompt.md << 'EOF'
---
agent: 'agent'
description: '轻量版特性规划，生成精简特性文档（完成规范+实现计划+测试计划）'
argument-hint: '输入特性描述或特性编码，如：FT-004 或 为资源库模块做 MCP 注册表'
---

Follow .asdm/toolsets/asdm-planner/actions/asdm-feature-planning-lite.md
EOF

# asdm-feature-planning-lite-overall prompt
cat > .github/prompts/asdm-feature-planning-lite-overall.prompt.md << 'EOF'
---
agent: 'agent'
description: '轻量版特性规划 - 概要设计阶段，输出总体概述与使用场景（无需代码调研）'
argument-hint: '输入特性描述或特性编码，如：FT-004 或 为资源库模块做 MCP 注册表'
---

Follow .asdm/toolsets/asdm-planner/actions/asdm-feature-planning-lite-overall.md
EOF

# asdm-feature-planning-lite-detailed prompt
cat > .github/prompts/asdm-feature-planning-lite-detailed.prompt.md << 'EOF'
---
agent: 'agent'
description: '轻量版特性规划 - 详细设计阶段，基于概要设计输出扩展章节和完成规范（需代码调研）'
argument-hint: '输入特性描述或特性编码，如：FT-004 或 为资源库模块做 MCP 注册表'
---

Follow .asdm/toolsets/asdm-planner/actions/asdm-feature-planning-lite-detailed.md
EOF

# asdm-feature-askme prompt
cat > .github/prompts/asdm-feature-askme.prompt.md << 'EOF'
---
agent: 'agent'
description: '通过提问引导用户完善特性需求，形成完整可执行的需求规格'
argument-hint: '输入特性描述或问题，如：我想做个消息通知功能'
---

Follow .asdm/toolsets/asdm-planner/actions/asdm-feature-askme.md
EOF

# asdm-toolset-showcase-generator prompt
cat > .github/prompts/asdm-toolset-showcase-generator.prompt.md << 'EOF'
---
agent: 'agent'
description: '根据 toolset 目录自动生成标准化市场价值展示文档（showcase），含 Mermaid 图验证'
argument-hint: '输入 toolset 目录路径，如：.asdm/toolsets/req-analyzer'
---

Follow .asdm/toolsets/asdm-planner/actions/asdm-toolset-showcase-generator.md
EOF

# asdm-feature-breakdown prompt
cat > .github/prompts/asdm-feature-breakdown.prompt.md << 'EOF'
---
agent: 'agent'
description: '将已完成设计的 Feature 文档拆分为具体的实施步骤和任务，生成结构化的实施计划文档（Plan）'
argument-hint: '输入特性编号或描述，如：FT-041 或 把 FT-060 的设计文档拆成实施计划'
---

Follow .asdm/toolsets/asdm-planner/actions/asdm-feature-breakdown.md
EOF

# asdm-stats prompt
cat > .github/prompts/asdm-stats.prompt.md << 'EOF'
---
agent: 'agent'
description: '统计 ASDM 产品线所有进展情况，生成代码库统计、提交频率、模块与特性数据图表并更新 README.md'
argument-hint: '无需参数，直接执行即可'
---

Follow .asdm/toolsets/asdm-planner/actions/asdm-stats.md
EOF
```

#### For Tencent CodeBuddy / Qoder (`.codebuddy/commands/`):

```bash
mkdir -p .codebuddy/commands/

# asdm-feature-idea command
cat > .codebuddy/commands/asdm-feature-idea.md << 'EOF'
Follow .asdm/toolsets/asdm-planner/actions/asdm-feature-idea.md
EOF

# asdm-feature-planning command
cat > .codebuddy/commands/asdm-feature-planning.md << 'EOF'
Follow .asdm/toolsets/asdm-planner/actions/asdm-feature-planning.md
EOF

# asdm-feature-review command
cat > .codebuddy/commands/asdm-feature-review.md << 'EOF'
Follow .asdm/toolsets/asdm-planner/actions/asdm-feature-review.md
EOF

# asdm-feature-progress command
cat > .codebuddy/commands/asdm-feature-progress.md << 'EOF'
Follow .asdm/toolsets/asdm-planner/actions/asdm-feature-progress.md
EOF

# asdm-docs-module-update command
cat > .codebuddy/commands/asdm-docs-module-update.md << 'EOF'
Follow .asdm/toolsets/asdm-planner/actions/asdm-docs-module-update.md
EOF

# asdm-docs-manual-update command
cat > .codebuddy/commands/asdm-docs-manual-update.md << 'EOF'
Follow .asdm/toolsets/asdm-planner/actions/asdm-docs-manual-update.md
EOF

# asdm-feature-planning-lite command
cat > .codebuddy/commands/asdm-feature-planning-lite.md << 'EOF'
Follow .asdm/toolsets/asdm-planner/actions/asdm-feature-planning-lite.md
EOF

# asdm-feature-planning-lite-overall command
cat > .codebuddy/commands/asdm-feature-planning-lite-overall.md << 'EOF'
Follow .asdm/toolsets/asdm-planner/actions/asdm-feature-planning-lite-overall.md
EOF

# asdm-feature-planning-lite-detailed command
cat > .codebuddy/commands/asdm-feature-planning-lite-detailed.md << 'EOF'
Follow .asdm/toolsets/asdm-planner/actions/asdm-feature-planning-lite-detailed.md
EOF

# asdm-feature-askme command
cat > .codebuddy/commands/asdm-feature-askme.md << 'EOF'
Follow .asdm/toolsets/asdm-planner/actions/asdm-feature-askme.md
EOF

# asdm-toolset-showcase-generator command
cat > .codebuddy/commands/asdm-toolset-showcase-generator.md << 'EOF'
Follow .asdm/toolsets/asdm-planner/actions/asdm-toolset-showcase-generator.md
EOF

# asdm-feature-breakdown command
cat > .codebuddy/commands/asdm-feature-breakdown.md << 'EOF'
Follow .asdm/toolsets/asdm-planner/actions/asdm-feature-breakdown.md
EOF

# asdm-stats command
cat > .codebuddy/commands/asdm-stats.md << 'EOF'
Follow .asdm/toolsets/asdm-planner/actions/asdm-stats.md
EOF
```

### 3. Manual Usage for Other Providers

如果你的 AI 编码助手不在上述检测范围内，可以直接在聊天窗口中输入指引：

```
Follow .asdm/toolsets/asdm-planner/actions/asdm-feature-idea.md
```

或

```
Follow .asdm/toolsets/asdm-planner/actions/asdm-feature-planning.md
```

或

```
Follow .asdm/toolsets/asdm-planner/actions/asdm-feature-review.md
```

或

```
Follow .asdm/toolsets/asdm-planner/actions/asdm-feature-progress.md
```

或

```
Follow .asdm/toolsets/asdm-planner/actions/asdm-docs-module-update.md
```

或

```
Follow .asdm/toolsets/asdm-planner/actions/asdm-docs-manual-update.md
```

或

```
Follow .asdm/toolsets/asdm-planner/actions/asdm-feature-planning-lite.md
```

或

```
Follow .asdm/toolsets/asdm-planner/actions/asdm-feature-planning-lite-overall.md
```

或

```
Follow .asdm/toolsets/asdm-planner/actions/asdm-feature-planning-lite-detailed.md
```

或

```
Follow .asdm/toolsets/asdm-planner/actions/asdm-feature-askme.md
```

或

```
Follow .asdm/toolsets/asdm-planner/actions/asdm-toolset-showcase-generator.md
```

或

```
Follow .asdm/toolsets/asdm-planner/actions/asdm-feature-breakdown.md
```

或

```
Follow .asdm/toolsets/asdm-planner/actions/asdm-stats.md
```

## Available Commands

安装后可使用以下命令：

| 命令 | 说明 | 示例 |
|------|------|------|
| `/asdm-feature-idea` | 快速记录新特性想法 | `/asdm-feature-idea 想给平台加个通知中心` |
| `/asdm-feature-idea` | 基于已有编码创建初始文档 | `/asdm-feature-idea FT-004` |
| `/asdm-feature-planning` | 规划 ASDM 产品特性 | `/asdm-feature-planning 为资源库模块做 MCP 注册表，优先级高` |
| `/asdm-feature-planning` | 基于已有编码创建文档 | `/asdm-feature-planning FT-004` |
| `/asdm-feature-review` | 审查特性规格文档 | `/asdm-feature-review 审查 FT-003 的完整性` |
| `/asdm-feature-review` | 严格模式审查 | `/asdm-feature-review 严格审查 FT-026` |
| `/asdm-feature-progress` | 检查特性实现进展 | `/asdm-feature-progress 检查 FT-040 的实现进展` |
| `/asdm-feature-progress` | 更新进展报告 | `/asdm-feature-progress 检查 FT-040，更新报告` |
| `/asdm-docs-module-update` | 编写模块功能文档 | `/asdm-docs-module-update 编写组织结构管理模块的文档` |
| `/asdm-docs-module-update` | 更新模块功能文档 | `/asdm-docs-module-update 更新实例管理模块文档，补充操作说明` |
| `/asdm-docs-manual-update` | 编写场景化操作手册 | `/asdm-docs-manual-update 编写用户注册和登录的操作手册` |
| `/asdm-docs-manual-update` | 更新场景化操作手册 | `/asdm-docs-manual-update 更新用户注册登录手册，补充第三方登录截图` |
| `/asdm-feature-planning-lite` | 轻量版特性规划（精简文档） | `/asdm-feature-planning-lite 为资源库模块做 MCP 注册表，优先级高` |
| `/asdm-feature-planning-lite` | 基于已有编码创建精简文档 | `/asdm-feature-planning-lite FT-004` |
| `/asdm-feature-planning-lite-overall` | 轻量版特性规划 - 概要设计（总体概述+使用场景，无需代码调研） | `/asdm-feature-planning-lite-overall 为资源库模块做 MCP 注册表` |
| `/asdm-feature-planning-lite-overall` | 基于已有编码创建概要设计文档 | `/asdm-feature-planning-lite-overall FT-004` |
| `/asdm-feature-planning-lite-detailed` | 轻量版特性规划 - 详细设计（扩展章节+DoD，需代码调研） | `/asdm-feature-planning-lite-detailed FT-004` |
| `/asdm-feature-planning-lite-detailed` | 基于概要设计文档深入设计 | `/asdm-feature-planning-lite-detailed 为资源库模块做 MCP 注册表` |
| `/asdm-feature-askme` | 通过提问引导完善特性需求 | `/asdm-feature-askme 我想做个消息通知功能` |
| `/asdm-feature-askme` | 深入探索特性细节和边界情况 | `/asdm-feature-askme FT-040 的权限模型需要细化` |
| `/asdm-toolset-showcase-generator` | 生成 toolset 标准化 showcase 文档 | `/asdm-toolset-showcase-generator .asdm/toolsets/req-analyzer` |
| `/asdm-toolset-showcase-generator` | 生成含 Mermaid 验证的 showcase | `/asdm-toolset-showcase-generator .asdm/toolsets/context-builder` |
| `/asdm-feature-breakdown` | 将 Feature 设计文档拆解为实施计划 | `/asdm-feature-breakdown FT-041` |
| `/asdm-feature-breakdown` | 基于设计文档生成任务清单 | `/asdm-feature-breakdown 把 FT-060 的设计文档拆成实施计划` |
| `/asdm-stats` | 统计 ASDM 产品线进展，生成 SVG 图表并更新 README.md | `/asdm-stats` |

## Key Documents

AI 执行操作时会自动读取以下文档：

| 文档 | 路径 | 用途 |
|------|------|------|
| 产品规划总览 | `docs/planning/ASDM-ProductPlanning.md` | 模块定义、特性清单、编号分配 |
| 特性文档模板 | `.asdm/toolsets/asdm-planner/specs/templates/Feature-Template.md` | 特性文档14章标准结构 |
| 进展报告模板 | `.asdm/toolsets/asdm-planner/specs/templates/Progress-Report-Template.md` | 进展报告标准结构 |
| 共享规范 | `.asdm/toolsets/asdm-planner/specs/specs4shared.md` | 校验规则、路径约束、编写要点 |
| asdm-feature-idea 规范 | `.asdm/toolsets/asdm-planner/specs/specs4asdm-feature-idea.md` | 想法记录行为规范 |
| asdm-feature-planning 规范 | `.asdm/toolsets/asdm-planner/specs/specs4asdm-feature-planning.md` | 特性规划行为规范 |
| asdm-feature-review 规范 | `.asdm/toolsets/asdm-planner/specs/specs4asdm-feature-review.md` | 规格审查行为规范 |
| asdm-feature-progress 规范 | `.asdm/toolsets/asdm-planner/specs/specs4asdm-feature-progress.md` | 进展检查行为规范 |
| asdm-docs-module-update 规范 | `.asdm/toolsets/asdm-planner/specs/specs4docs-module-update.md` | 模块文档编写行为规范 |
| asdm-docs-manual-update 规范 | `.asdm/toolsets/asdm-planner/specs/specs4docs-manual-update.md` | 场景化操作手册编写行为规范 |
| 模块文档模板 | `.asdm/toolsets/asdm-planner/specs/templates/Module-Doc-Template.md` | 模块功能说明文档标准结构 |
| 操作手册模板 | `.asdm/toolsets/asdm-planner/specs/templates/Manual-Doc-Template.md` | 场景化操作手册标准结构 |

## Verification

安装后验证：

1. 快捷命令已创建在对应 provider 目录中
2. 命令文件内容为 `Follow .asdm/toolsets/asdm-planner/actions/{action-name}.md` 引用格式
3. toolset 文件位于 `.asdm/toolsets/asdm-planner/`

## Notes

- 命令文件仅包含引用指引，不包含 action 完整内容，避免重复和版本不一致
- AI 执行时会读取 action 文件，action 文件会进一步引用 specs 文档和产品规划文档
- 更新 action 或 specs 时无需重新安装，AI 每次执行都会读取最新版本

## License
Copyright (c) 2026 LeansoftX.com & iSoftStone. All rights reserved.
