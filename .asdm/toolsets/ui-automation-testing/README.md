---
registryId: ui-automation-testing
name: ui-automation-testing
description: 'toolset-id: ui-automation-testing toolset-name: UI Automation Testing
  version: 0.1.0 updated-date: 2026-07-24 toolset-description: 面向 Web 应用的 UI 自动化测试工具集，按照《外网AI自动化测试方案
  v1.1》实现「人工录制脚本 + AI 负责转换与保鲜」路线：以 Chrome Dev Tools Recorder 录制 json 为唯一脚本来源，AI 转换为
  agent-browser 主产物脚本（Playwright 为降级产物），并支持执行报告与定时保鲜巡检。'
version: 1.0.0
guid: eab51b77-cdbe-4d25-8773-a1e52565fc97
entryPoint: README.md
configType: toolset
---
# ASDM Toolset - UI Automation Testing

toolset-id: ui-automation-testing
toolset-name: UI Automation Testing
version: 0.1.0
updated-date: 2026-07-24
toolset-description: 面向 Web 应用的 UI 自动化测试工具集，按照《外网AI自动化测试方案 v1.1》实现「人工录制脚本 + AI 负责转换与保鲜」路线：以 Chrome Dev Tools Recorder 录制 json 为唯一脚本来源，AI 转换为 agent-browser 主产物脚本（Playwright 为降级产物），并支持执行报告与定时保鲜巡检。

## Overview

UI Automation Testing（toolset-id: ui-automation-testing）是一个 ASDM 工具集，面向 Web 应用，遵循《外网AI自动化测试方案 v1.1》的 **「人工录制 + AI 转换与保鲜」** 轻量化路线。核心设计原则：

- **唯一脚本来源**：Chrome DevTools Recorder JSON（测试人员录制，`recordings/` 归档）
- **双产物策略**：转换生成 **agent-browser `.sh`（主产物，必须）** + **Playwright `.js`（降级产物）**
- **AI 自愈闭环**：执行期自愈 + 保鲜巡检自愈，共用一份自愈规范（6 类可自愈 / 5 类不自愈，2 次失败转人工）
- **机械逻辑固化**：6 个 Node 固化脚本（`scripts/`）处理录制转换、脚手架、校验、报告汇总，AI 仅处理语义判断，降低 token 消耗

### 四个核心 action

| Action | 功能 | 输入 | 产出 |
|--------|------|------|------|
| `asdm-ui-test-step-design` | **测试步骤设计**：需求 → 测试步骤文档 + 录制计划 | PRD 或需求描述 | `test-step-design.md`、`recording-checklist.md`、`data/` |
| `asdm-ui-test-design-generate` | **设计与编码**：读取录制脚本 → 双产物转换 + 自然语言标注 | 一句话需求 | `.sh`/`.js` 脚本、`annotations.json`、`data/`、`overview.md` |
| `asdm-ui-test-run` | **执行与报告**：执行脚本 → 执行期自愈 → 断言报告，失败转人工 | 用例文件夹 | `report.md`（含断言覆盖、自愈记录、转人工清单） |
| `asdm-ui-test-freshness` | **保鲜巡检**：覆盖检测 → 健康巡检 → AI 自愈/变更更新 → 重跑验证 | 巡检范围（或"全部"） | `freshness-report-<日期>.md` |

### 结构速览

工具集约含 **6 个固化脚本**（`scripts/`）、**10 个规范文档**（`spec/`）、**8 个模板**（`templates/`）、**1 份最佳实践指南**（`guides/`），按 v1.0 规划合并版构建。已通过 2026-07-24 逻辑验证报告验证闭环可跑通（真实数据集：用户创建与令牌管理，覆盖登录 → 建用户 → 新用户登录 → 建令牌全链路）。

### 安装

将以下提示复制粘贴到 AI 编码工具的聊天窗口即可初始化：

```shell
Follow instructions in .asdm/toolsets/ui-automation-testing/INSTALL.md
```

## Features

### Common features

- 「人工录制 + AI 转换与保鲜」轻量化路线（方案 v1.1）
- Chrome Dev Tools Recorder 录制 json 为唯一脚本来源（`recordings/`）
- 双产物脚本：**agent-browser（主产物，必须）** + **Playwright（降级产物，低优先级）**
- 自然语言标注（`annotations.json`）：支撑后续 AI 维护脚本（自愈、变更更新）
- 断言策略：断言全部来源于录制脚本，转换时保证不丢失
- 测试数据管理：数据与脚本分离（账号池 / 业务数据 / 环境配置，`data/` 目录）
- 人工兜底流程：失败/自愈超限/定位缺失时输出结构化转人工清单
- 自愈共享规范：执行期（`run`）与保鲜期（`freshness`）共用 `ui-test-self-healing-spec.md`，定义 6 类可自愈 / 5 类不自愈范围、选择器替换策略与边界保护规则，同一脚本连续失败 2 次转人工
- 固化脚本（Helper Scripts）：机械逻辑（录制转换 `convert-recording.js`、数据集脚手架 `bootstrap-scenario.js`、数据集校验 `lint-dataset.js`、批量执行报告 `collect-report.js`、录制清单 `generate-tree.js`/`check.js`）已由 `scripts/` 下 Node 脚本实现，对应 action 指令优先调用脚本、AI 仅处理语义判断部分，降低 token 消耗

### 测试步骤设计（asdm-ui-test-step-design）

根据 PRD 或一句话需求，生成结构化的测试步骤文档和录制计划，驱动人工精准录制。

- 解析 PRD 文档或需求文本，自动拆分测试场景
- 按页面分段生成详细的测试步骤文档（操作描述、测试数据、预期结果、元素描述）
- 规划 `recordings/` 目录结构，标记录制脚本与场景的映射关系
- 生成可视化的录制清单（Recording Checklist），驱动人工使用 Chrome DevTools Recorder 补充录制
- 🔴/🟡/⚪ 三级录制优先级标记，明确哪些步骤必须录制、哪些建议录制
- 生成测试数据骨架文件（env.json / accounts.json / business.json）
- 产出物为后续 `asdm-ui-test-design-generate` 提供精确的录制基础

**输入**：PRD 文档路径或一句话需求描述（如"测试医生排班管理功能"）
**输出**：`.asdm/workspace/ui-test/<用例名称>_<YYYYMMDDHHmmss>/` 目录，含 `test-step-design.md`（测试步骤文档）、`recording-checklist.md`（录制清单）、`data/`（数据骨架）
**使用场景**：在功能开发完成后、人工录制之前使用，明确"录什么"

### 设计与编码（asdm-ui-test-design-generate）

根据一句话需求描述，完成场景设计、元素定位检测和双产物脚本生成的一体化流程。**前置依赖 `recordings/` 目录中已有录制脚本**（可先使用 `asdm-ui-test-step-design` 规划录制）。

- 解析需求文本，自动拆分测试场景（简单需求 1 个场景，复杂需求 3-5 个场景）
- 读取 `recordings/` 目录下的录制 json，建立元素定位映射表
- 逐一检测每个场景的元素定位可用性（✅ 可定位 / ⚠️ 需确认 / ❌ 无法定位）
- 对可定位场景生成 agent-browser 脚本（主）与 Playwright 脚本（降级），不可定位的反馈用户补充录制
- 生成自然语言标注 `annotations.json` 与测试数据文件 `data/`
- 输出结构化的 `overview.md`（含场景设计、执行计划、数据依赖声明、任务清单）

**输入**：一句话需求描述（如"测试用户登录功能，包括正常登录和密码错误场景"）
**输出**：`.asdm/workspace/ui-test/<用例名称>_<YYYYMMDDHHmmss>/` 目录，含各场景 `.sh`/`.js` 脚本、`annotations.json`、`data/`、`overview.md`
**使用场景**：在功能开发完成后，需要快速生成 UI 自动化测试脚本时使用

### 执行与报告（asdm-ui-test-run）

读取 `overview.md` 中的执行计划，按顺序运行各场景脚本，并将执行结果输出到 `report.md`。

- 支持完整文件夹名或前缀匹配定位用例文件夹
- agent-browser `.sh` 优先执行，`.js` 降级
- 执行前自动清理 `data.json`（场景间运行时变量），确保每次执行数据干净
- 报告含断言覆盖情况（断言步骤数 / 操作步骤数）
- **执行期自愈**：脚本因元素定位失败时，AI 从 `# Recorder selectors:` 注释提取录制原始选择器尝试替换重跑，复用 `ui-test-self-healing-spec.md` 共享规范，同一脚本连续失败 2 次转人工，报告含「自愈记录」章节
- 失败场景记录报错原因与上下文日志，按人工兜底流程输出转人工清单

**输入**：用例文件夹路径（完整名称或前缀匹配）
**输出**：用例文件夹下的 `report.md`（含执行摘要、断言覆盖情况、转人工清单）
**使用场景**：在脚本生成完成后，需要执行测试并查看运行结果时使用

### 保鲜巡检（asdm-ui-test-freshness）

检测新需求相关的自动化测试脚本，将失效、缺失、过期的脚本恢复可用。

- 覆盖检测：比对需求环节与现有录制脚本，输出缺失环节清单（缺什么、应补录哪个）
- 健康检测：巡检执行存量脚本，收集失败项及报错日志
- AI 自愈：结合报错日志 + recorder json + 自然语言标注修复失败脚本（同一脚本连续失败 2 次即转人工）
- 变更更新：基于人工录入的需求描述更新语义过期脚本，人工确认后入库
- 重跑验证：自愈/更新后重跑，通过入库，不通过转人工
- 输出保鲜报告：巡检范围、发现问题、处理结果、缺失环节清单、转人工清单

**输入**：巡检范围（用例文件夹或"全部"）+ 可选的人工录入需求描述
**输出**：`freshness-report-<日期>.md` 保鲜报告
**使用场景**：定时巡检、需求变更后的脚本保鲜

## Toolset Installation Process

`INSTALL.md` 将按照以下步骤安装工具集：

- 创建 `.asdm/workspace/ui-test` 与 `recordings` 工作区目录
- 检测当前 `Agentic Engine` 提供商（Claude Code / GitHub Copilot / Tencent CodeBuddy）
- 在对应提供商的入口目录中创建快捷命令

## Toolset Workflow

安装完成后，用户可以使用以下命令完成端到端工作流：

1. **`/asdm-ui-test-step-design`**：根据 PRD/需求，设计测试步骤 + 生成录制计划
2. **`/asdm-ui-test-design-generate`**：根据录制脚本，设计场景 + 生成双产物脚本
3. **`/asdm-ui-test-run`**：执行脚本，输出执行报告（`report.md`）
4. **`/asdm-ui-test-freshness`**：定时巡检 + AI 自愈，输出保鲜报告

### 完整端到端工作流示例

```
# 新建功能 → 清晰设计 → 精准录制 → 自动生成脚本 → 执行验证 → 定期保鲜

# Step 0: 接收 PRD/需求，设计测试步骤和录制计划（新增前置步骤）
/asdm-ui-test-step-design 测试医生排班管理功能，包括添加排班和删除排班

# Step 1: 人工根据 recording-checklist.md 使用 Chrome DevTools Recorder 录制
#         将录制文件保存到 recordings/schedule/schedule-add-schedule.json
#         将录制文件保存到 recordings/schedule/schedule-delete-schedule.json

# Step 2: 录制完毕后，基于录制脚本生成自动化测试脚本
/asdm-ui-test-design-generate 测试医生排班管理功能

# Step 3: 执行脚本 + 生成报告
/asdm-ui-test-run 排班管理测试

# Step 4: 定时保鲜巡检
/asdm-ui-test-freshness 全部
```

## Toolset Structure

UI Automation Testing 工具集的结构如下：

```
.asdm/
└── toolsets/
    └── ui-automation-testing/
        ├── INSTALL.md
        ├── README.md
        ├── manifest.json
        ├── 整体规划-v1.0.md                         ## 整体规划（合并 v1.1 + v2.0，标注已实现项）
        ├── 整体规划-逻辑验证报告-20260724.md         ## 整体规划逻辑验证报告（契约类漏洞清单）
        ├── TODO.md                                 ## 待办与待拍板分歧点
        ├── actions/
        │   ├── asdm-ui-test-step-design.md       ## 测试步骤设计：需求→测试步骤文档→录制计划
        │   ├── asdm-ui-test-design-generate.md   ## 设计与编码：场景设计 + 双产物脚本生成
        │   ├── asdm-ui-test-run.md               ## 执行：脚本运行 + 报告 + 执行期自愈 + 失败转人工
        │   └── asdm-ui-test-freshness.md         ## 保鲜：巡检 + AI 自愈 + 保鲜报告
        ├── scripts/                              ## 固化脚本（机械逻辑，减少 AI 消耗）
        │   ├── generate-tree.js                  ## 需求 → 录制清单 tree.json
        │   ├── check.js                          ## 录制完成度检测 + 录制清单生成
        │   ├── convert-recording.js             ## 录制 JSON → stepDesign.md + annotations.json（step-design 阶段）
        │   ├── bootstrap-scenario.js            ## 用例数据集脚手架：文件夹 + data/ + .sh/.js 骨架（design-generate 阶段）
        │   ├── lint-dataset.js                   ## 数据集规范校验（design-generate / freshness 阶段）
        │   └── collect-report.js                 ## 批量执行 + 报告汇总（run 阶段）
        ├── guides/                              ## 最佳实践指南
        │   └── agent-browser-best-practices.md  ## agent-browser 使用最佳实践
        ├── templates/                           ## 模板文件
        │   ├── annotations-template.json        ## 自然语言标注模板
        │   ├── overview-template.md              ## 场景设计总览模板
        │   ├── execution-plan-template.md        ## 执行计划模板
        │   ├── summary-template.md               ## 摘要模板
        │   ├── task-list-template.md             ## 任务清单模板
        │   ├── recording-checklist-template.md   ## 录制清单模板
        │   ├── playwright-script-template.js     ## Playwright 降级脚本模板
        │   └── variable-templates.js            ## 变量机制模板
        └── spec/
            ├── ui-test-step-design-spec.md        ## 测试步骤设计规范
            ├── ui-test-design-generate-spec.md    ## 设计与脚本生成工作流规范（含自然语言标注）
            ├── ui-test-agent-browser-spec.md      ## agent-browser 脚本规范（主产物）
            ├── ui-test-script-spec.md             ## Playwright 降级脚本代码规范
            ├── ui-test-run-report-spec.md         ## 执行与报告规范（含断言覆盖情况）
            ├── ui-test-freshness-spec.md          ## 保鲜工作流规范
            ├── ui-test-manual-fallback-spec.md    ## 人工兜底流程规范
            ├── ui-test-data-spec.md               ## 测试数据管理规范
            ├── ui-test-case-spec.md               ## 测试用例设计规范
            └── ui-test-self-healing-spec.md      ## 自愈共享规范（执行期自愈 + 保鲜自愈共用）
```

> **说明**：`ui-test-self-healing-spec.md` 为执行期（`run`）与保鲜期（`freshness`）共用的自愈规范，定义了 6 类可自愈 / 5 类不自愈范围、自愈流程、选择器替换策略与边界保护规则。

## Toolset Workspace

UI Automation Testing 工具集的工作区结构：

```
recordings/                               ## 录制脚本归档（唯一脚本来源）
└── <模块>/<模块>-<场景简称>.json

.asdm/workspace/ui-test/
└── <用例名称>_<YYYYMMDDHHmmss>/          ## 每次设计生成一个时间戳文件夹
    ├── overview.md                       ## 场景设计摘要、执行计划、任务清单
    ├── test-step-design.md               ## 测试步骤设计文档（step-design 阶段产出，作为 design-generate 的 SSoT）
    ├── recording-checklist.md            ## 录制清单（step-design 阶段产出，驱动人工补充录制）
    ├── report.md                         ## 执行报告（执行后生成）
    ├── freshness-report-<YYYYMMDD>.md    ## 保鲜报告（巡检后生成）
    ├── annotations.json                  ## 步骤自然语言标注（供 AI 自愈）
    ├── data/                             ## 测试数据（账号池/业务数据/环境配置）
    │   ├── env.json
    │   ├── accounts.json
    │   └── business.json
    ├── data.json                         ## 场景间变量传递（执行时自动管理）
    ├── <模块>-<场景简称>.sh               ## agent-browser 脚本（主产物）
    └── <模块>-<场景简称>.js               ## Playwright 脚本（降级产物）
```

## Copyright & License

Copyright (c) 2026 LeansoftX.com & iSoftStone. All rights reserved.

Licensed under the PROPRIETARY SOFTWARE LICENSE. See [LICENSE](LICENSE) in the project root for license information.
