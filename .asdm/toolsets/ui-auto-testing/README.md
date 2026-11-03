---
registryId: ui-auto-testing
name: ui-auto-testing
description: '面向 ASDM（及同类 Web 平台）的 UI 回放测试工具集'
version: 0.1.0
guid: 83d1bae9-0592-400c-800e-b2309281f5b3
entryPoint: README.md
configType: toolset
---
# ASDM Toolset - ui-auto-testing

toolset-id: ui-auto-testing
toolset-name: ui-auto-testing
version: 0.1.0
updated-date: 2026-11-03
toolset-description: 面向 ASDM（及同类 Web 平台）的 UI 回放测试工具集：以三段式测试用例 markdown 为输入，翻译为 agent-browser 驱动的 bash 回放脚本，配合批次数据刷新与测试计划生成，支持单任务执行、全量回归与断点续跑。

## Overview

ui-auto-testing（toolset-id: ui-auto-testing）是一个 ASDM 工具集，面向 ASDM 平台（及同类 Web 平台）的端到端 UI 回放测试。核心设计原则：

- **用例即脚本来源**：三段式测试用例 markdown（操作步骤 / 预期结果 / 前置条件）是唯一输入，AI 按通用转换规范（动词识别表 → 翻译模板）翻译为可执行 bash 回放脚本，不绑定任何具体用例内容
- **公共库沉淀**：`common/common.sh` 一次生成、全部脚本 source 复用——业务脚本只写"做什么"，公共库管"怎么驱动浏览器"；通用能力（快照定位 / JS 优先点击 / 轮询等待 / 软硬断言分级）单点沉淀、全脚本共享
- **批次数据机制**：名称类测试数据带 `TEST_TS` 时间戳后缀，每批回放在平台生成全新数据互不冲突；同批次依赖链字面对齐（下游引用与上游产物字面一致）
- **静态快照 + 生成逻辑分离**：`data/test-data.sh`、`task/test-plan.md`、`task/run-all.sh` 均为生成产出的静态实例，生成逻辑唯一来源在 `actions/` 指令文档，需要更新时重新执行对应指令，禁止在实例文件内手写生成规则
- **编号序即依赖序**：用例/脚本文件名 `NNN_名称` 的 3 位编号承担排序、依赖、执行三重语义；依赖链由脚本头部注释动态推导（DAG + 拓扑序），替代固定骨架

### 三个核心 action

| Action | 功能 | 输入 | 产出 | 执行时机 |
|--------|------|------|------|----------|
| `testcase-to-sh` | **用例转换**：测试用例 md → agent-browser 回放脚本 | 单个用例文件或用例目录 | `replay_testcase/<NNN>_<名称>.sh`、`common/common.sh`、`data/test-data.sh` 分节追加 | 首次建立回放体系 / 用例集变化时 |
| `generate-test-data` | **数据刷新**：按命名规则刷新批次名称类数据 | 无需输入（时间戳现场生成，可选 `TEST_TS` 锁定批次） | 刷新 `data/test-data.sh` 中名称类变量值 | 每批新回放前刷新一次 |
| `generate-test-plan` | **计划生成**：扫描脚本集合 → 测试计划 + 全量编排脚本 | `.asdm/workspace/replay-testcase/` 目录扫描 | `task/test-plan.md`、`task/run-all.sh` | 脚本集合变化 / 数据批次刷新 / 布局迁移后 |

### 整体执行流程（三文档协作）

```
test-cases/<NNN>_<名称>.md（用例源，三段式）
        │
        ▼
① testcase-to-sh：转换规范
   首次转换生成 common.sh + test-data.sh；批量转换生成/刷新 task/ 编排
        │
        ▼
replay_testcase/<NNN>_<名称>.sh × N
        │
        ▼
② generate-test-data：刷新名称类数据（新 TEST_TS 批次）
        │
        ▼
data/test-data.sh（新批次静态快照）
        │
        ▼
③ generate-test-plan：扫描 N 个脚本 → test-plan.md + run-all.sh（依赖拓扑序 + 豁免规则）
        │
        ▼
④ 执行（run-all.sh 全量 / 单任务调试 / 断点续跑）→ result/ 日志落盘
```

**典型一轮完整回放的操作序列**：转换（用例变化时）→ 刷新数据 → 同步计划 → 执行（全量跑，失败任务从断点单任务补跑）。

**约束**：同一批回放内禁止再次刷新数据（依赖链会断裂）；断点续跑/回放历史批次不刷新。三个文档间存在显式引用：`testcase-to-sh` 全量转换时按 `generate-test-plan` 生成编排，数据刷新走 `generate-test-data`，下游执行由 `execute-test-task.md`（另文）驱动。

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

- 单文件转换 / 目录批量转换（按 `NNN_名称.md` 命名过滤，编号序即依赖序）；无效输入报错终止，不做猜测
- 首次转换生成公共库 `common/common.sh` 与统一数据文件 `data/test-data.sh`（已存在时直接复用不重生成）
- 步骤文本规范化：编号错乱/重复/跳号重排，引用型步骤展开或抽象为 for 循环，复合步骤拆分；语义决断点写入脚本注释留痕
- 前置条件翻译为脚本头注释 + `require_vars` 校验（仅列本用例实际用到的变量）+ 依赖脚本提示
- 预期结果 → 断言序列（页面跳转 / 列表增加记录 / 树增加节点 / 异步轮询 / 弹窗出现等映射，异步特征任一命中即止、超时计失败）
- 验证闭环：`bash -n` 语法检查 → 平台可达性检查（`curl -sI`）→ 实跑验证；定位失败用 `agent-browser snapshot -i` 比对修正
- 批量转换单个失败不中断批次，验证分级（`bash -n` 全量，实跑按编号序串行抽样）

**翻译铁律（关键设计决策）**：

1. **快照 ref 铁律**：ref 仅对当次快照有效，任何改变页面结构的操作后必须重新取快照
2. **点击走 `ab_click`，JS 优先、快照 ref 兜底**：坐标点击对 SPA 元素会静默失效；JS 内文本经 base64 传递；命中 disabled/notfound 时轮询等待，上限 8 次
3. **soft 模式**：未命中仅告警不退出——用于"可能出现也可能不出现"的确认弹窗链（幂等）
4. **精确匹配优先**：前缀歧义场景必须 `click_by_exact`/`ref_by_exact`，防子串错点
5. **轮询代替固定等待**：SPA 渲染/跳转/异步结果一律 `wait_for_*` 轮询
6. **软硬断言分级**：预期结果软断言（WARN 累计，finish 汇总）；流程关键节点硬断言立即 exit 1
7. **文本进正则有风险**：元字符敏感场景走 JS 字面比较或 `case` 字面匹配

**公共库 `common.sh` 提供 11 个方法族**：初始化（`ab_init`/`load_data_file`/`require_vars`）、快照定位、等待轮询、元素操作（`ab_click` 核心）、下拉框、上传/取值、树/搜索、iframe 穿透（`act_in_frame`）、断言（软/硬分级）、登录导航、收尾（`finish`）。修复与增强单点沉淀、全脚本共享；通用新能力先沉淀进库再调用，禁止在业务脚本内复制库函数。

**数据机制**：全部用例共用 `data/test-data.sh`（`: "${VAR:=默认值}"` 形式，环境变量优先），新用例数据分节追加、禁止独立数据文件；变量命名约定——凭据类 `<角色>_USER/_PASS`、名称类 `<实体>_NAME`（时间戳后缀）、运行产物类走 `data/` 落盘文件。

**幂等分级**：登录/导航类天然幂等；配置变更类收敛到目标状态；上传/更新类经"确认覆盖"弹窗链幂等；**创建类不幂等**——依赖时间戳新批次数据或断点续跑。

**输入**：单个用例文件（`NNN_名称.md`）或整个用例目录（批量转换）
**输出**：`.asdm/workspace/replay-testcase/` 下的回放脚本、公共库、数据文件分节
**使用场景**：拿到测试用例 markdown，需要生成可回放自动化脚本时使用

### 数据刷新（generate-test-data）

按命名规则（`<前缀> + MMDDHHmmss`）刷新 `data/test-data.sh` 中名称类测试数据，供整批回放使用。

- 13 类名称数据（测试用户/组织/项目/空间/知识源/分身/令牌等）统一时间戳后缀；固定数据（密码、角色等）不走创建规则保持静态值，外部凭据留空由 run-all.sh 豁免
- 依赖链对齐：同一 `TEST_TS` 贯穿整条依赖链，下游变量与上游产物**字面一致**（写入静态值，不用变量引用）：

```
主链：003 创建顶层组织 → 004 创建子组织 → 005 创建用户 → 010 创建项目 → 011 项目设置
（024/025/026 挂靠 010 项目；006/012/015/016/022/023 独立创建类同批刷新防同名残留）
```

| 下游变量 | 必须等于 |
|----------|----------|
| `PARENT_ORG` | `ORG_NAME` 的值（003 产物） |
| `NEW_USER_ORG` / `ORG_NODE` | `SUB_ORG_NAME` 的值（004 产物） |
| `NEW_USER_EMAIL` | `TEST01_USER` 的值（005 产物，010/011 登录复用） |
| `PROJECT_NAME` | `SUB_ORG_NAME` 的值 + `-项目` |

任何一环时间戳不一致，后续用例都会因找不到上游数据（组织/用户不存在、登录失败）而失败。

- 刷新后自动验证：`bash -n` 语法 + `source` 后输出全部变量核对字面一致性 + export 清单对齐
- 刷新时机：每批新回放前刷新一次；同一批回放内禁止刷新（003 已按旧数据创建后再刷新，004 起引用的就是平台上不存在的新数据）；断点续跑不刷新
- 限制：`TEST_TS` 秒级精度禁止并发执行；每批回放在平台留下带时间戳的数据（不自动清理），需定期清理；`test-data.sh` 含明文凭据禁止提交版本库

**输入**：无需输入（时间戳现场生成）；可选环境变量级指定 `TEST_TS` 锁定批次
**输出**：刷新 `data/test-data.sh` 中名称类变量值
**使用场景**：新一轮回放前刷新批次数据，或平台已有同名残留导致创建类用例失败时

### 计划生成（generate-test-plan）

扫描 `replay_testcase/` 下的回放脚本（数量不限，记为 N）与用例源文件，生成测试计划与全量编排脚本。

- 目录布局自动判定（定版 `replay_testcase/` + `common/` / 历史平铺布局，历史布局照常生成并标注迁移提示）
- 逐脚本提取任务四要素（前置依赖 / 必需数据 / 落盘产出 / 登录身份），全部以脚本实际内容为准，禁止凭用例 md 臆造；README 依赖树仅作校验参照，冲突时以脚本为准并记差异
- 依赖链动态构建：从脚本前置注释提取依赖边汇总构成有向图 → 执行顺序 = 依赖拓扑序（同层按编号升序）；N 任务齐、无环、无悬空依赖校验，任一失败终止生成并报告
- 数据就绪判定（豁免/阻塞）：

| 判定条件 | 状态 |
|----------|------|
| `require_vars` 全部变量有非空默认值 | 就绪 |
| 某必需变量为空或占位符 | 豁免-缺外部数据（任务保留，执行时跳过留痕） |
| 跨脚本落盘数据缺失（如 `data/pat.txt` 不存在） | 阻塞-缺前置产出（标注先执行哪个脚本） |
| 同 `TEST_TS` 批次已在平台执行过 | 提示回放前刷新数据 |

- 生成验证：任务行数 = 脚本数 N、执行入口路径全部 `test -f` 核验、`bash -n` 语法校验、豁免/阻塞留痕齐全
- **通过标准**：任务级 = 退出码 0 且日志无 `[失败]`/`[断言失败]`；计划级 = 全部 N 任务通过或豁免留痕，无未处理阻塞

**run-all.sh 编排逻辑**（生成器仅替换「生成器写入区」：`TASKS` 数组 = 拓扑执行顺序、`EXEMPT_RULES` 豁免任务及变量、`PLACEHOLDER` 占位符特征，其余为通用框架）：

- 运行环境守卫：依赖 bash 专属特性（进程替换/数组/`${!var}`），被 sh/dash/zsh 调用时自动 `exec bash` 重执行
- 豁免判定：任务对应变量为空或含占位符 → 跳过并记「豁免」（环境变量传入真实值即解除）
- 失败策略：单任务失败不中断，继续执行剩余任务直至全部完成（下游依赖任务可能连锁失败，属预期留痕）；补跑用断点续跑
- 日志：每任务 `result/<NNN>_<名称>.log`（固定名覆盖式，tee 同步控制台）；整轮输出 + 汇总表落 `result/run-all-<时间戳>.log`
- 身份切换零感知：需切换身份的脚本内置凭据覆盖，编排器无需传环境变量
- 退出码：存在失败任务 → 1（CI 判定依据）

**重新生成时机**：脚本集合变化（N 变化）、刷新数据批次、目录布局迁移、脚本头部变更（前置/`require_vars`/产出）、test-data.sh 变量变化——任一发生时 `test-plan.md` 与 `run-all.sh` 必须同步重新生成；同一批执行中断后不重新生成（保持断点续跑上下文）。

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

### 贯穿全流程的核心机制

| 机制 | 说明 | 落地点 |
|------|------|--------|
| 时间戳批次 | 名称类数据带 `TEST_TS` 后缀，每批全新数据规避创建类重名 | test-data.sh / generate-test-data |
| 字面对齐链 | 下游引用变量与上游产物字面一致（不用变量引用） | test-data.sh |
| 编号序即依赖序 | NNN 编号承担排序/依赖/执行三重语义；依赖链由脚本注释动态推导（DAG + 拓扑序） | testcase-to-sh / generate-test-plan |
| 幂等分级 | 登录/配置类幂等；上传类弹窗链幂等；创建类不幂等 → 靠新批次数据 | testcase-to-sh |
| 豁免机制 | 外部凭据/文件缺失时任务保留、执行时跳过、留痕可解除 | run-all.sh EXEMPT_RULES |
| 断点续跑 | 失败后从失败任务起单任务执行，禁止整批重跑 | test-plan / run-all.sh |
| 软硬断言 | 预期结果软断言（WARN 累计，finish 汇总 exit 1）；流程关键节点硬断言立即失败 | common.sh |
| 快照 ref 铁律 | ref 仅当次快照有效，结构变化后必重新取快照；JS 点击优先 | common.sh ab_click |
| 生成逻辑单源 | Action 文档 = 唯一规则来源；产物 = 静态快照，禁止手写生成规则 | 三个文档共同约定 |
| 凭据安全 | 脚本无明文密码；落盘 chmod 600；test-data.sh 与 result/ 禁止入库 | testcase-to-sh |

### 关键禁止事项

- 禁止在 `test-data.sh` / `test-plan.md` / `run-all.sh` 内手写生成逻辑或运行时生成逻辑
- 禁止在同一批回放内刷新数据（依赖链断裂）
- 禁止创建类用例整批无脑重跑（重名必失败）
- 禁止并发刷新数据（`TEST_TS` 秒级精度撞名）
- 禁止在业务脚本内复制库函数（通用能力沉淀进 common.sh）
- 禁止将用例 md 原文 URL/OS 路径直接带入脚本（必须参数化，以 test-data.sh 的 `BASE_URL` 等为准）

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
        ├── docs/                             ## 参考文档
        │   └── ui-auto-testing-execution-logic.md  ## 三个 Action 的执行逻辑梳理
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
