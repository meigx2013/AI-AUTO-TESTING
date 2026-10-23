# Asdm Feature Progress

## Metadata

```json
{
  "guid": "a9b0c1d2-e3f4-5a6b-7c8d-9e0f1a2b3c4d",
  "name": "asdm-feature-progress",
  "displayName": "Asdm Feature Progress",
  "description": "检查 ASDM 特性实现进展，对特定特性进行代码扫描并生成标准的进展报告",
  "toolset": {
    "guid": "e5f6a7b8-c9d0-1e2f-3a4b5c6d7e8f",
    "id": "asdm-planner",
    "name": "ASDM Planner Toolset",
    "version": "1.0.0"
  },
  "scenario": "dod-check"
}
```

## Description
检查 ASDM 特性实现进展，对特定特性进行代码扫描并生成标准的进展报告。支持按特性编号或文档路径检查实现状态，逐项对照 DoD（完成规范）评估完成度。报告包含：代码实现检查、DoD 逐项状态、缺失组件分析、实施建议等标准章节。

> **⚠️ 重要：报告输出规范**
> 
> **必须** 将生成的进展报告写入标准文件路径：
> `docs/planning/Feat/FT-XXX-{特性名称}/FT-XXX-{特性名称}-特性实现进展报告.md`
> 
> 不得仅在对话中输出报告结果，必须使用 write_to_file 工具将报告持久化到文件系统。

## Usage
```
/asdm-feature-progress <自然语言描述>
```

用户可以用自然语言描述检查目标，AI 自动提取所需参数。如缺少必要信息，AI 会向用户询问确认。

## Parameters

所有参数均可通过自然语言输入，AI 自动提取。若必填参数缺失，AI 须向用户询问。

| 参数 | 必填 | 说明 | 示例 |
|------|:----:|------|------|
| `feature_id` | ✅ | 特性编号 | FT-003、FT-040 |
| `branch` | ❌ | 检查的 git 分支（默认：仅 release/* 分支） | releases/release-r03 |
| `scope` | ❌ | 检查范围：release_only / all（默认：release_only） | release_only |
| `dod_items` | ❌ | DoD 检查项数组，默认全部检查 | ["2.1.1", "2.2.1"] |
| `update_doc` | ❌ | ~~是否更新进展报告文档~~（**已废弃，始终写入文件**） | true |

## Examples

### 自然语言输入
```
/asdm-feature-progress 检查 FT-040 特性的实现进展
```

```
/asdm-feature-progress FT-040 多库资源管理混合存储，只看 release 分支
```

```
/asdm-feature-progress 帮我检查 FT-038 的完成度
```

> **注意**：进展报告将自动写入文件，无需额外指定"更新报告"

## Process

### 1. 解析输入

从自然语言中提取参数：
- **特性编号**：匹配 `FT-\d{3}` 格式
- **特性名称**：模糊匹配（如"多库资源管理混合存储"→FT-040），需在 `ASDM-ProductPlanning.md` 中查找确认
- **分支范围**：语义映射（"只看 release 分支"→release_only，"检查所有分支"→all）
- **分支名称**：匹配 `releases/.*`、`feat/.*` 等格式
- **更新文档**：语义映射（"更新报告"→update_doc=true）

若无法确定检查目标（既无编号也无明确的特性名称），向用户询问确认。

### 1.1 更新 git submodule（必须执行）

**检查前必须确保相关 git submodule 的 releases 分支代码最新**。

#### 更新步骤

1. **识别相关代码库**：根据特性归属模块确定需要更新的 submodule
   - asdm-admin：管理后台相关特性
   - asdm-agentorbit：实例管理相关特性  
   - asdm-official-website：官网相关特性

2. **执行更新命令**：
```bash
# 进入 workspace 根目录
cd /home/azureuser/source/asdm-product-management

# 更新所有 submodule 的远程分支信息
git submodule foreach 'git fetch origin'

# 切换到 releases 分支并拉取最新代码
git submodule foreach 'git checkout releases/release-r03 && git pull origin releases/release-r03'

# 验证分支状态
git submodule status
```

3. **异常处理**：
- 如果某个 submodule 不存在 releases/release-r03 分支，检查其他 release 分支
- 如果更新失败，记录警告并继续检查，但需要在报告中标注"代码可能不是最新"

#### 验证更新结果

- 检查 `git submodule status` 输出，确认所有 submodule 处于正确的 commits
- 记录更新的时间戳和版本信息

### 2. 分支检查（按 scope 执行）

**scope=release_only（默认）**：
- 仅检查 `releases/*` 分支的实现情况
- 忽略 main、feat/*、dt/* 等分支的检查
- 聚焦于已合并到 release 分支的代码

**scope=all**：
- 检查所有相关分支
- 在报告中标注各分支的实现状态
- 区分"已合并"和"开发中"的实现

> **注意**：执行前已通过 [1.1 更新 git submodule](#11-更新-git-submodule必须执行) 确保 releases 分支代码最新。

### 3. 代码上下文扫描（必须执行）

**检查前必须使用 code-explorer 对相关代码进行扫描**，确保所有检查结论基于代码实际情况。

> **前提条件**：已通过 [1.1 更新 git submodule](#11-更新-git-submodule必须执行) 确保代码最新。

扫描范围（根据 scope 确定分支）：
- 归属模块对应的代码目录和文件结构
- 特性文档中声称已实现的 API、Service、Controller 等
- 特性文档中描述的数据模型、数据库表的实际定义
- 数据库 migration 脚本
- 前端组件和页面
- 配置文件和环境变量

扫描结果用于：
- 验证文档中声称的实现状态（✅/❌）是否与代码实际情况吻合
- 发现文档中未记录的已实现功能
- 识别实际存在但文档未更新的功能

### 4. 执行 DoD 逐项检查

读取特性文档中的 DoD（完成规范）章节，按项逐条检查：

| 状态 | 含义 | 判断标准 |
|:----:|------|----------|
| ✅ 已完成 | 该功能点已实现，无需额外开发 | 代码扫描确认功能完整存在 |
| 🟡 部分完成 | 该功能点部分实现，需进一步完善 | 代码扫描确认部分功能存在 |
| ❌ 待实现 | 该功能点尚未实现，需要在开发阶段实现 | 代码扫描确认功能不存在 |

### 4.1 路径验证（必须执行）

**在列出文件路径之前，必须使用路径验证工具验证文件路径的正确性**。

#### 验证工具

使用 `asdm-planner/tools/path-validator` 工具进行路径验证：

```bash
# 进入路径验证工具目录
cd /home/azureuser/source/asdm-product-management/.asdm/toolsets/asdm-planner/tools/path-validator

# 验证单个文件路径
python main.py --validate /home/azureuser/source/asdm-product-management/asdm-admin/.../文件名.java

# 验证并生成 Markdown 链接
python main.py --validate-and-link /home/azureuser/source/asdm-product-management/asdm-admin/.../文件名.java

# 批量验证（推荐）
python main.py --batch files.json
```

#### 确认路径正确性后生成链接

- 仅在文件存在且路径正确时才生成链接
- 对于不存在的文件，标注为"文件不存在"而非生成无效链接

### 5. 生成进展报告

按标准章节结构生成报告（参见 Report Structure）：

### 6. 粗体格式检查（必须执行）

**写入文件前必须执行粗体格式检查**，按照 `specs4shared.md` 9.4 节规范逐项检查 B1-B5，自动修复问题后报告结果。

### 7. 写入进展报告文件（必须执行）

**每次检查完成后必须将报告写入文件系统**，不得仅在对话中输出。

- 检查 `docs/planning/Feat/FT-XXX-{name}/` 目录下是否存在进展报告
- 若存在，更新"检查时间"和最新检查结果
- 若不存在，创建新的进展报告文件
- 标准文件命名：`FT-XXX-{特性名称}-特性实现进展报告.md`
- 报告内容按 [Report Structure](#report-structure) 标准格式生成

### 8. 输出结果

返回结构化的检查结果和建议。

## Report Structure

标准进展报告包含以下章节：

### 报告概述
```
**检查时间**：ISO 8601 datetime
**检查范围**：asdm-admin、asdm-agentorbit 等主要代码库
**检查分支**：releases/release-r03（仅检查 release 分支）
**代码更新状态**：✅ 已更新 / ⚠️ 部分更新 / ❌ 未更新
**状态**：🟢 已完成 / 🟡 部分实现 / 🔴 尚未实现
```

### 报告目录
自动生成的目录导航

### 1. 当前实现状态概览
- **总体完成度**：百分比
- **当前状态**：简要描述
- **代码更新状态**：git submodule 更新结果
- **主要发现**：关键实现点列表

### 2. 代码更新状态检查

**必须记录 git submodule 更新结果**，确保检查基于最新代码。

#### 更新状态分类

| 状态 | 含义 | 报告标注 |
|------|------|----------|
| ✅ 已更新 | 所有相关 submodule 成功更新到 releases 分支最新版本 | 代码已更新到最新 |
| ⚠️ 部分更新 | 部分 submodule 更新失败，但大部分已更新 | 代码可能不是最新 |
| ❌ 未更新 | 所有 submodule 更新失败 | 检查结果可能过时 |

#### 更新结果记录

- **更新时间**：ISO 8601 datetime
- **更新命令**：执行的 git 命令
- **更新结果**：每个 submodule 的更新状态
- **异常情况**：更新失败的原因和影响

### 3. 分支检查结果（按 scope）
各分支的实现状态列表

### 3. DoD 逐项检查
按 DoD 章节逐项检查：
- 核心功能
- 数据一致性
- 用户体验
- 安全性
- 兼容性
- 完成度汇总表

### 4. 关键缺失组件分析
未实现的关键组件列表及影响分析

### 5. 实施建议
- 高优先级事项
- 中优先级事项
- 低优先级事项
- 预计开发周期

### 附录
- **检查的文件清单**：按 DoD 验收点逐一列出，每个验收点一个表格，仅显示文件名
- **相关文档链接**：指向特性文档和产品规划的链接
- **检查工具和时间戳**：生成工具和检查时间

#### 代码清单格式

```markdown
### {验收点编号} {验收点名称}

| 文件名 | 链接 |
|-------|------|
| `PersonalAccessTokenController.java` | [查看代码](../../../../asdm-admin/asdm-admin-services/asdm-admin-services-core/src/main/java/ai/asdm/admin/core/controller/auth/PersonalAccessTokenController.java) |
| `PersonalAccessTokenService.java` | [查看代码](../../../../asdm-admin/asdm-admin-services/asdm-admin-services-core/src/main/java/ai/asdm/admin/core/service/auth/PersonalAccessTokenService.java) |
```

#### DoD 分类与代码清单对应

| DoD 分类 | 对应代码类型 |
|----------|--------------|
| 核心功能 | Controller、Service、实体类、数据库迁移、前端组件 |
| 安全要求 | Entity、Repository、Security 配置、前端安全组件 |
| 数据一致性 | 数据库迁移脚本、Entity、DTO、Validation |
| 接口完整性 | Controller、API Client、前端 API 服务、国际化文件 |
| 待完善项 | 测试目录、配置目录（如无相关文件则标注） |
| 部署要求 | 数据库迁移脚本、配置文件 |

## Parameter Extraction Rules

AI 应从自然语言中智能提取以下信息：

- **特性编号**：匹配 `FT-\d{3}` 格式
- **特性名称**：关键词匹配 `ASDM-ProductPlanning.md` 特性清单
- **分支范围**：
  - "只看 release 分支" / "仅 release" → release_only
  - "检查所有分支" / "全面检查" → all
- **分支名称**：匹配 `releases/.*`、`origin/releases/.*` 格式
- **更新文档**："更新报告" / "更新文档" → update_doc=true
- **DoD 检查项**：匹配章节编号格式（如"2.1.1"、"核心功能"）

### 缺失参数确认

当必填参数缺失时，一次性列出缺失项向用户确认：

```
请指定检查目标：
1. 特性编号：如 FT-003、FT-040
2. 或特性名称：可在 ASDM-ProductPlanning.md 中查找
```

> **注意**：`update_doc` 参数已废弃。进展报告将**始终**写入文件系统，无需用户确认。

## Related Specifications
- [specs4shared.md](../specs/specs4shared.md) - 共享规范（关键文档、校验规则、路径约束、编写要点）
- [specs4asdm-feature-progress.md](../specs/specs4asdm-feature-progress.md) - asdm-feature-progress 专属规范
- [Feature-Template.md](../specs/templates/Feature-Template.md) - 特性文档标准模板
- [Progress-Report-Template.md](../specs/templates/Progress-Report-Template.md) - 进展报告标准模板

## Output

### 进展检查输出
```json
{
  "phase": "progress",
  "status": "success",
  "feature_id": "FT-XXX",
  "feature_name": "string",
  "branch_scope": "release_only | all",
  "branches_checked": ["releases/release-r03"],
  "dod_summary": {
    "total_items": 22,
    "completed": 2,
    "partial": 11,
    "not_started": 9,
    "completion_rate": "17%"
  },
  "report_path": "docs/planning/Feat/FT-XXX-name/FT-XXX-name-特性实现进展报告.md",
  "report_updated": true,
  "next_steps": [
    "Create asset items tables",
    "Implement AssetStorageService"
  ],
  "estimated_effort": "4-6 weeks",
  "timestamp": "ISO 8601 datetime"
}
```

- `phase`：固定为 "progress"（进展检查阶段）
- `branch_scope`：区分 "release_only"（仅检查 release 分支）和 "all"（检查所有分支）
- `dod_summary`：DoD 完成规范逐项检查的汇总统计
- `report_path`：进展报告文件的写入路径
- `report_updated`：恒为 true（报告始终写入文件系统）
- `next_steps`：基于缺失组件分析的建议实施步骤
- `estimated_effort`：预计剩余开发周期

### 报告文件路径规范
- **目录**：`docs/planning/Feat/FT-XXX-{特性中文名}/`
- **文件名**：`FT-XXX-{特性中文名}-特性实现进展报告.md`
- **示例**：`docs/planning/Feat/FT-019-数据上报API/FT-019-数据上报API-特性实现进展报告.md`
