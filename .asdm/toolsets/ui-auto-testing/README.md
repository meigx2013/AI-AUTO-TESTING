---
registryId: ui-auto-testing
name: ui-auto-testing
description: '面向 ASDM（及同类 Web 平台）的 UI 回放测试工具集：以三段式测试用例 markdown 为输入，翻译为 agent-browser 驱动的 bash 回放脚本，配合批次数据刷新与测试计划生成，支持单任务执行、全量回归与断点续跑。'
version: 0.1.0
guid: 83d1bae9-0592-400c-800e-b2309281f5b3
entryPoint: README.md
configType: toolset
---
# ASDM Toolset - ui-auto-testing

toolset-id: ui-auto-testing
toolset-name: ui-auto-testing
version: 0.1.0
updated-date: 2026-10-16
toolset-description: 面向 ASDM（及同类 Web 平台）的 UI 回放测试工具集：以三段式测试用例 markdown 为输入，翻译为 agent-browser 驱动的 bash 回放脚本，配合批次数据刷新与测试计划生成，支持单任务执行、全量回归与断点续跑。

## Overview

ui-auto-testing（toolset-id: ui-auto-testing）是一个 ASDM 工具集，面向 ASDM 平台（及同类 Web 平台）的端到端 UI 回放测试。核心设计原则：

- **用例即脚本来源**：三段式测试用例 markdown（操作步骤 / 预期结果 / 前置条件）是唯一输入，AI 按通用转换规范（动词识别表 → 翻译模板）翻译为可执行 bash 回放脚本，不绑定任何具体用例内容
- **公共库沉淀**：`common/common.sh` 一次生成、全部脚本 source 复用——业务脚本只写"做什么"，公共库管"怎么驱动浏览器"；通用能力（快照定位 / JS 优先点击 / 轮询等待 / 软硬断言分级）单点沉淀、全脚本共享
- **批次数据机制**：名称类测试数据带 `TEST_TS` 时间戳后缀，每批回放在平台生成全新数据互不冲突；同批次依赖链字面对齐（下游引用与上游产物字面一致）
- **静态快照 + 生成逻辑分离**：`data/test-data.sh`、`task/test-plan.md`、`task/run-all.sh` 均为生成产出的静态实例，生成逻辑唯一来源在 `actions/` 指令文档，需要更新时重新执行对应指令

### 三个核心 action

| Action | 功能 | 输入 | 产出 |
|--------|------|------|------|
| `testcase-to-sh` | **用例转换**：测试用例 md → agent-browser 回放脚本 | 单个用例文件或用例目录 | `replay_testcase/<NNN>_<名称>.sh`、`common/common.sh`、`data/test-data.sh` 分节追加 |
| `generate-test-data` | **数据刷新**：按命名规则刷新批次名称类数据 | 无需输入（时间戳现场生成，可选 `TEST_TS` 锁定批次） | 刷新 `data/test-data.sh` 中名称类变量值 |
| `generate-test-plan` | **计划生成**：扫描脚本集合 → 测试计划 + 全量编排脚本 | `.asdm/workspace/replay-testcase/` 目录扫描 | `task/test-plan.md`、`task/run-all.sh` |

### 结构速览

工具集含 **3 个指令文档**（`actions/`）、**1 个公共方法库脚本**（`scripts/`）、**2 个规范文档**（`spec/`）。

### 安装

将以下提示复制粘贴到 AI 编码工具的聊天窗口即可初始化：

```shell
Follow instructions in .asdm/toolsets/ui-auto-testing/INSTALL.md
```

## Features

### Common features

- 通用转换规范：动词识别总表（20+ 步骤模式 → 翻译模板），任意测试用例 md 均可转换，语义决断写入脚本注释
- 快照 ref 铁律：ref 仅对当次快照有效，改变页面结构的操作后重新取快照；库函数内部自行定位，调用方不跨步持有 ref
- JS 优先点击：agent-browser 坐标点击对部分 SPA 元素静默失效，统一 `el.click()`（文本经 base64 传递，无注入风险）；命中 disabled/notfound 时轮询等待
- 软硬断言分级：预期结果校验用软断言（WARN 累计、finish 汇总），流程性关键节点用硬断言立即失败
- 轮询代替固定等待：页面渲染、URL 跳转、异步结果一律 `wait_for_*` 轮询
- 批次数据机制：`TEST_TS`（MMDDHHmmss）时间戳后缀防重名；依赖链对齐规则保证下游变量与上游产物字面一致；环境变量优先于 test-data.sh 默认值
- 敏感数据纪律：回放脚本内不出现明文密码/Token，一律经 test-data.sh 或环境变量；落盘凭据文件 chmod 600，禁止提交版本库
- 平台行为特性清单：12 类"不报错、静默无效"的平台陷阱及内置对策（提交按钮静默拦截、输入超长静默截断、浮层下拉 CDP 错误、角色与描述不符等）
- 豁免机制：外部依赖不满足（上传文件不存在、Token 为占位符）的任务自动跳过并记"豁免"，环境变量传入真实值即解除
- 失败策略：单任务失败不中断，继续执行剩余任务；失败后补跑用断点续跑（从失败任务起单任务执行），禁止整批重跑（创建类用例不幂等）

### 用例转换（testcase-to-sh）

将测试用例 markdown（操作步骤 / 预期结果 / 前置条件 三段式）翻译为可直接执行的 bash 回放脚本，驱动 agent-browser 完成端到端 UI 自动化。

- 单文件转换 / 目录批量转换（按 `NNN_名称.md` 命名过滤，编号序即依赖序）
- 首次转换生成公共库 `common/common.sh` 与统一数据文件 `data/test-data.sh`
- 步骤文本规范化：编号错乱/重复/跳号重排，引用型步骤展开，复合步骤拆分
- 前置条件翻译为脚本头注释 + `require_vars` 校验 + 运行时守卫
- 预期结果 → 断言序列（页面跳转 / 列表增加记录 / 状态变更 / 异步轮询等 9 类映射）
- 验证闭环：`bash -n` 语法检查 → 平台可达性检查 → 实跑验证

**输入**：单个用例文件（`NNN_名称.md`）或整个用例目录（批量转换）
**输出**：`.asdm/workspace/replay-testcase/` 下的回放脚本、公共库、数据文件分节
**使用场景**：拿到测试用例 markdown，需要生成可回放自动化脚本时使用

### 数据刷新（generate-test-data）

按命名规则（`<前缀> + MMDDHHmmss`）刷新 `data/test-data.sh` 中名称类测试数据，供整批回放使用。

- 13 类名称数据（测试用户/组织/项目/空间/知识源/分身/令牌等）统一时间戳后缀
- 依赖链对齐：下游变量与上游产物字面一致（PARENT_ORG=ORG_NAME、NEW_USER_ORG=SUB_ORG_NAME 等）
- 独立创建类 / 挂链创建类用例同批刷新，防止上一批同名残留
- 刷新后自动验证：语法检查 + 依赖链字面一致性 + export 清单对齐
- 刷新时机：每批新回放前刷新一次；同一批回放内禁止刷新

**输入**：无需输入（时间戳现场生成）；可选环境变量级指定 `TEST_TS` 锁定批次
**输出**：刷新 `data/test-data.sh` 中名称类变量值
**使用场景**：新一轮回放前刷新批次数据，或平台已有同名残留导致创建类用例失败时

### 计划生成（generate-test-plan）

扫描 `replay_testcase/` 下的回放脚本（数量不限，记为 N）与用例源文件，生成测试计划与全量编排脚本。

- 目录布局自动判定（定版 `replay_testcase/` + `common/` / 历史平铺布局）
- 逐脚本提取任务四要素（前置依赖 / 必需数据 / 落盘产出 / 登录身份），全部以脚本实际内容为准
- 依赖链动态构建：从脚本前置注释提取依赖边构 DAG，拓扑排序得执行顺序；无环、无悬空、无孤立任务校验
- 数据就绪三态判定：就绪 / 豁免-缺外部数据 / 阻塞-缺前置产出
- 生成 `task/run-all.sh`：编号序串行执行、豁免判定、单任务失败不中断、日志落盘 `result/`、综合汇总

**输入**：`.asdm/workspace/replay-testcase/` 目录扫描 + `test-cases/*.md`
**输出**：`task/test-plan.md` + `task/run-all.sh`
**使用场景**：脚本集合变化、数据批次刷新、目录布局迁移后重新生成计划

## Toolset Installation Process

`INSTALL.md` 将按照以下步骤安装工具集：

- 创建 `.asdm/workspace/replay-testcase` 工作区五目录（`common` / `replay_testcase` / `data` / `task` / `result`）
- 检测当前 `Agentic Engine` 提供商（Claude Code / GitHub Copilot / Tencent CodeBuddy）
- 在对应提供商的入口目录中创建快捷命令

## Toolset Workflow

安装完成后，用户可以使用以下命令完成端到端工作流：

1. **`/testcase-to-sh`**：测试用例 md → 回放脚本 + 公共库 + 数据文件
2. **`/generate-test-data`**：刷新批次名称类数据（TEST_TS 时间戳）
3. **`/generate-test-plan`**：扫描脚本集合 → 测试计划 + 全量编排脚本
4. **执行**：`bash .asdm/workspace/replay-testcase/task/run-all.sh`（全量）/ 单任务 / 断点续跑

### 完整端到端工作流示例

```
# 用例 markdown 就绪（test-cases/NNN_名称.md，三段式）→ 转换 → 刷新数据 → 生成计划 → 执行

# Step 1: 批量转换用例（生成 replay_testcase/*.sh + common/common.sh + data/test-data.sh）
/testcase-to-sh test-cases/

# Step 2: 刷新批次数据（每批新回放前一次）
/generate-test-data

# Step 3: 生成测试计划与全量编排脚本
/generate-test-plan

# Step 4: 执行（全量回归）
bash .asdm/workspace/replay-testcase/task/run-all.sh
#     （单任务调试：bash .asdm/workspace/replay-testcase/replay_testcase/001_system-login.sh）
#     （断点续跑：从失败任务起单任务执行，禁止整批重跑）
```

## Toolset Structure

ui-auto-testing 工具集的结构如下：

```
.asdm/
└── toolsets/
    └── ui-auto-testing/
        ├── INSTALL.md                        ## 安装指南
        ├── README.md                         ## 本文件
        ├── manifest.json                     ## 工具集清单
        ├── actions/                          ## 指令文档（生成逻辑唯一来源）
        │   ├── testcase-to-sh.md             ## 用例转换：测试用例 md → agent-browser 回放脚本
        │   ├── generate-test-data.md         ## 数据刷新：批次名称类数据 TEST_TS 时间戳
        │   └── generate-test-plan.md         ## 计划生成：测试计划 + run-all.sh 全量编排
        ├── scripts/                          ## 公共方法库
        │   └── agent-browser-lib.sh          ## agent-browser 回放公共库（eval 驱动 iframe 操作框架）
        └── spec/
            ├── agent-browser-spec.md         ## agent-browser CLI 能力规范（安装/平台兼容/子命令）
            └── directory-structure-spec.md   ## 回放测试目录结构与落盘规则
```

## Toolset Workspace

ui-auto-testing 工具集的工作区结构（`.asdm/workspace/replay-testcase/`，五目录布局）：

```
.asdm/workspace/replay-testcase/            # 回放测试根目录
├── common/                                 # 公共方法库
│   └── common.sh                           # 唯一一份，全部回放脚本 source 复用
├── replay_testcase/                        # 回放脚本（每用例一个，编号序即依赖序）
│   └── <NNN>_<名称>.sh                     # 如 001_system-login.sh
├── data/                                   # 测试数据
│   ├── test-data.sh                        # 统一测试数据（generate-test-data 刷新）
│   └── <中间数据>.txt                      # 跨用例传递（如 pat.txt，chmod 600）
├── task/                                   # 任务编排
│   ├── run-all.sh                          # 全量串联执行编排脚本
│   └── test-plan.md                        # 测试计划静态实例
└── result/                                 # 执行结果（日志 + 截图 + 汇总报告）
    └── <NNN>_<名称>.log
```

## Copyright & License

Copyright (c) 2026 LeansoftX.com & iSoftStone. All rights reserved.

Licensed under the PROPRIETARY SOFTWARE LICENSE. See [LICENSE](LICENSE) in the project root for license information.
