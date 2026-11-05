# ASDM 回放测试计划（测试任务）

> 【静态实例】本文件由 .asdm/toolsets/ui-auto-testing/actions/generate-test-plan.md 生成，不含生成逻辑；
> 需要新计划时重新执行该文档，禁止在本文件内手写生成规则。
>
> - 最近生成：2026-11-05 16:13　数据批次：BATCH_ID=T001
> - 目录布局：**定版布局**——脚本集中 `replay_testcase/<编号_用例名>.sh`、公共库 `common/common.sh`
>   （2026-09-01 由根目录平铺迁移而来，见 §七 差异 16；`spec/directory-structure-spec.md`
>   的 `sh/<编号_用例名>/` 案例子目录为更远期目标态，未采用）
> - 任务数量：28 个（27 个脚本文件，其中 012 编号含双脚本，由目录扫描决定）
> - 日志目录：result/（**去时间戳·固定名覆盖式**：任务 = `<任务>.log`，汇总 = `run-all.log`；历史归档 result/history/）
> - **执行约束：同一时间仅允许一个 run-all.sh 实例运行（多实例并发会互相干扰测试状态）。run-all.sh 已于 2026-09-01 完成执行增强——Ctrl+C 优雅中断、依赖失败级联跳过、逐任务/总体耗时统计；中断或失败后重跑即断点续跑（已通过任务自动跳过），详见 §四与 §七 差异 15**

## 一、批次与环境

| 项 | 值 |
| --- | --- |
| 数据批次 BATCH_ID | T001（批次号机制首个批次，2026-11-05 由 `/generate-test-data T001` 生成） |
| BASE_URL | https://asdm-dt01.leansoftx.com/ |
| 回放前是否需刷新数据 | 否：T001 批次未在平台执行过，直接回放即可；同一批回放内禁止再次生成数据（依赖链断裂）；若创建类用例遇重名失败，换下一批次号执行 `/generate-test-data T002` 重新生成 |
| 跨脚本落盘数据现状 | data/pat.txt 缺失（将由 006 于本轮执行时产出；007 按依赖序消费，006 先行即就绪） |
| 外部凭据变量现状 | GH_TOKEN 为占位符 ghp_xxx → **011/014/016/017 豁免-缺外部数据**（`GH_TOKEN=...` 注入真实值即解除）；AGENT_ORBIT_KEY 已填真实值 → 018/022/023 就绪；PROJECT_ADMIN_USER/PASS 为空 → 099 内置豁免逻辑跳过项目管理员验证部分 |

## 二、任务清单（共 28 个）

> 任务行由生成器按 §3.1/§3.3/§3.4 逐脚本填充（说明列取 test-cases 用例一句话概要）；
> T001 批次下除 011/014/016/017（GH_TOKEN 占位符 ghp_xxx）判定豁免-缺外部数据外，
> 其余任务的 `require_vars` 变量在 test-data.sh 均有非空且非占位符默认值 → 状态「就绪」
> （099 的 PROJECT_ADMIN_* 为空，由脚本内置豁免逻辑处理，不占 EXEMPT_RULES）。

| # | 任务 | 说明 | 执行入口 | 身份 | 前置 | 数据依赖 | 产出 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 001_system-login | 系统登录：Portal 首页登录，断言进入已登录首页 | replay_testcase/001_system-login.sh | super-admin | — | ASDM_USER / ASDM_PASS | 登录态 | 就绪 |
| 2 | 002_access-asdm | 进入 ASDM 管理后台（用户信息 → 控制台管理） | replay_testcase/002_access-asdm.sh | super-admin | 001 | — | — | 就绪 |
| 3 | 003_create-org | 创建顶层组织 | replay_testcase/003_create-org.sh | super-admin | 001 | ORG_NAME | 顶层组织 | 就绪 |
| 4 | 004_create-sub-org | 创建子组织（父组织行 … → 创建子组织） | replay_testcase/004_create-sub-org.sh | super-admin | 001、003 | PARENT_ORG、SUB_ORG_NAME | 子组织 | 就绪 |
| 5 | 005_create-user | 创建用户（含角色映射） | replay_testcase/005_create-user.sh | super-admin | 001 | NEW_USER_EMAIL / _PASS / _ROLE / _ORG / _LAST / _FIRST | test01 账号 | 就绪 |
| 6 | 006_generate-pat | 生成 PAT 令牌并落盘 data/pat.txt | replay_testcase/006_generate-pat.sh | super-admin | 001 | PAT_NAME、PAT_EXPIRY | data/pat.txt | 就绪 |
| 7 | 007_pipeline-config | 添加流水线配置（Jenkins 型，读取 data/pat.txt） | replay_testcase/007_pipeline-config.sh | super-admin | 001、006 | PIPELINE_NAME、JENKINS_URL / _CRED、data/pat.txt | 流水线配置 | 就绪（pat.txt 由前置 006 本轮产出） |
| 8 | 008_feature-flag | 特性开关批量编辑为全量开放 | replay_testcase/008_feature-flag.sh | super-admin | 001 | FEATURE_FLAGS、FLAG_STATUS | — | 就绪 |
| 9 | 009_resource-management-toolset | 上传场景智能体资源包 | replay_testcase/009_resource-management-toolset.sh | super-admin | 001 | UPLOAD_FILE、RES_SCOPE / _TYPE / _CATEGORY | 平台场景智能体资源 | 就绪（资源包缺失待放置，见 §七 差异 26） |
| 10 | 010_create-project | 创建项目（test01 身份） | replay_testcase/010_create-project.sh | test01（脚本内置切换） | 001、004、005 | ORG_NODE、PROJECT_NAME | 项目 | 就绪 |
| 11 | 011_project-config | 项目仓库配置（添加仓库 → 检测可用性） | replay_testcase/011_project-config.sh | test01（脚本内置切换） | 001、010 | REPO_URL、REPO_BRANCH、REPO_NAME、GH_TOKEN | 项目仓库配置 | 豁免-缺外部数据（GH_TOKEN 占位符） |
| 12 | 012_create-workspace | 创建智能体空间（普通类） | replay_testcase/012_create-workspace.sh | test01（脚本内置切换） | 001、005、010 | WORKSPACE_NAME / _TYPE / _DESC | 智能体空间 | 就绪 |
| 13 | 013_workspace-resources | 空间关联场景智能体资源 | replay_testcase/013_workspace-resources.sh | test01（脚本内置切换） | 001、009、010、012_create-workspace | UPLOAD_FILE | 空间已关联资源 | 就绪 |
| 14 | 014_workspace-runs | 触发空间运行，生成执行历史 | replay_testcase/014_workspace-runs.sh | test01（脚本内置切换） | 001、010、012_create-workspace、013 | RUN_PROMPT | 执行历史记录 | 豁免-缺外部数据（GH_TOKEN 级联链） |
| 15 | 015_create-context | 创建知识空间（个人空间） | replay_testcase/015_create-context.sh | test01（脚本内置切换） | 001、010 | KNOWLEDGE_NAME、KNOWLEDGE_DESC | 知识空间 | 就绪 |
| 16 | 016_context-items | 知识空间添加知识源（单步自动化构建） | replay_testcase/016_context-items.sh | test01（脚本内置切换） | 001、010、015 | CONTEXT_BUILD_MODE / _SOURCE_NAME / _REPO_URL / _AGENT / _CMD | 知识源 | 豁免-缺外部数据（GH_TOKEN 级联链） |
| 17 | 017_context-sync-status | 知识空间触发同步，新增同步记录 | replay_testcase/017_context-sync-status.sh | test01（脚本内置切换） | 001、010、015、016 | — | 同步记录 | 豁免-缺外部数据（GH_TOKEN 级联链） |
| 18 | 018_agentorbit-config | 配置 AgentOrbit 连接密钥 | replay_testcase/018_agentorbit-config.sh | super-admin | 001 | AGENT_ORBIT_KEY | AgentOrbit 连接配置 | 就绪 |
| 19 | 019_hide-digidev-icon | 隐藏 DigiDev 图标（特性开关） | replay_testcase/019_hide-digidev-icon.sh | super-admin | 001 | HIDE_DIGIDEV_FLAG、FLAG_STATUS | — | 就绪 |
| 20 | 020_asdm-org-agent | 组织 Agent 设置（顶层组织代跑） | replay_testcase/020_asdm-org-agent.sh | super-admin | 001 | ASDM_ORG_NAME | — | 就绪 |
| 21 | 021_organization-agent-config | 组织 Agent 配置（顶层组织代跑） | replay_testcase/021_organization-agent-config.sh | super-admin | 001 | ORG_CONFIG_NAME | — | 就绪 |
| 22 | 022_personal-avatar | 创建个人数字分身 | replay_testcase/022_personal-avatar.sh | super-admin | 001 | AVATAR_NAME、AGENT_ORBIT_KEY | 个人数字分身 | 就绪（平台分身创建权限待开通，见 §七 差异 19） |
| 23 | 023_digital-avatar-created-successfully | 数字分身创建成功验证 | replay_testcase/023_digital-avatar-created-successfully.sh | super-admin | 001、018、022 | DIGITAL_AVATAR_NAME、AGENT_ORBIT_KEY | — | 就绪 |
| 24 | 024_create-online-agent-space | 创建在线智能体空间 | replay_testcase/024_create-online-agent-space.sh | test01（脚本内置切换） | 001、005、010 | ONLINE_WORKSPACE_NAME / _TYPE | 在线智能体空间 | 就绪 |
| 25 | 025_online-knowledge-space | 创建在线知识空间（含多步知识源） | replay_testcase/025_online-knowledge-space.sh | test01（脚本内置切换） | 001、005、010 | ONLINE_KNOWLEDGE_NAME / _TYPE、MULTI_CONTEXT_BUILD_MODE / _NAME | 在线知识空间 + 知识源 | 就绪 |
| 26 | 026_multi-step-build | 多步构建并验证 MD 产出 | replay_testcase/026_multi-step-build.sh | test01（脚本内置切换） | 001、005、010、025 | MULTI_CONTEXT_NAME、MULTI_CONTEXT_BUILD_MODE | MD 文档产出 | 就绪 |
| 27 | 099_efficiency-insights | 效能洞察：三角色数据权限级别验证 | replay_testcase/099_efficiency-insights.sh | super-admin + test01 + project-admin | 001、005 | ORG_NAME、SUB_ORG_NAME、PROJECT_NAME、PROJECT_ADMIN_USER/PASS（项目管理员凭据为空时跳过） | — | 就绪（项目管理员部分豁免） |
| 28 | 012_system-logout | 退出登录（收尾任务，清除登录态） | replay_testcase/012_system-logout.sh | super-admin | 001 | — | 清除登录态 | 就绪 |

> 【前置列口径】前置含两类：① 脚本头部「前置条件」节声明的 `replay_testcase/…` 引用；
> ② 脚本未声明（登录自愈、可独立执行）时按 README 依赖树兜底的 001 登录态依赖
> （002/003/004/005/012_system-logout 及全部 test01 类任务，见 §七 差异 20）。
> 冲突一律以脚本为准（§2.2 补充规则）。

## 三、依赖链（执行顺序）

按脚本头部「前置条件」引用 + README 兜底（§七 差异 20）构建的有向图
（编号序即依赖序，无逆序依赖、无环、无悬空）：

```
001_system-login（根节点）
├─ 002_access-asdm
├─ 003_create-org ── 004_create-sub-org
├─ 005_create-user
├─ 006_generate-pat ── 007_pipeline-config（数据链：006 产出 data/pat.txt → 007 消费）
├─ 008_feature-flag
├─ 009_resource-management-toolset（UPLOAD_FILE 就绪；功能上依赖 008 的
│                                   hide_admin_resource_management 开关，见 §七 差异 21）
├─ 010_create-project ── 011_project-config
│                    ├─ 012_create-workspace ── 013_workspace-resources ── 014_workspace-runs
│                    ├─ 015_create-context ── 016_context-items ── 017_context-sync-status
│                    ├─ 024_create-online-agent-space
│                    ├─ 025_online-knowledge-space ── 026_multi-step-build
│                    └─（test01 身份由 005 传递供给）
├─ 018_agentorbit-config
├─ 019_hide-digidev-icon
├─ 020_asdm-org-agent ── 021_organization-agent-config
├─ 022_personal-avatar ── 023_digital-avatar-created-successfully（依赖 018 配置成功 + 022 产出分身）
├─ 099_efficiency-insights（三角色数据权限验证，test01 身份由 005 传递）
└─ 012_system-logout（收尾任务，仅依赖根登录态，执行序置尾）
```

**拓扑执行顺序（28 个，仅供逐任务单脚本执行时排序参考）**：

001 → 002 → 003 → 004 → 005 → 006 → 007 → 008 → 009 → 010 → 011 → 012_create-workspace → 013 → 014 → 015 → 016 → 017 → 018 → 019 → 020 → 021 → 022 → 023 → 024 → 025 → 026 → 099 → 012_system-logout

**校验结论**：28 个任务全部在链上（无孤立任务）；依赖无环（全部引用编号 ≤ 自身，012_create-workspace 与 012_system-logout 互不依赖）；无悬空依赖（被引用的 slug 全部存在）；012_system-logout 为收尾类脚本置尾；022 → 023 为数据链（022 产出分身 → 023 校验创建成功提示）；099 内含三角色身份切换（super-admin + test01 + project-admin），项目管理员部分凭据为空时脚本内置豁免逻辑跳过。

## 四、执行方式

> 【并发约束·2026-09-01 调整】同一时间仅允许一个 run-all.sh 实例（多实例并发会互相
> 干扰测试状态）；人工逐任务执行期间请勿同时启动 run-all.sh。原「禁止调用
> run-all.sh」约束随执行增强（§七 差异 15）调整为上述单实例约束。

- **全量编排**：bash .asdm/workspace/replay-testcase/task/run-all.sh
  - **Ctrl+C 优雅中断**：SIGINT/SIGTERM 触发后当前任务停止并记「中断」（任务日志留痕），
    未开始任务记「未执行」，输出已执行汇总与耗时统计后以退出码 130 退出；
    中断后直接重跑本脚本 = 断点续跑（已通过任务自动跳过，从中断/失败任务继续）
  - **依赖失败级联跳过**：任一任务失败后，DEPS 依赖表（取自 §二「前置」列）中依赖
    该任务的后继任务不再执行，标记「级联跳过」并注明根因链（历史实测：时间戳批次
    0901085429 中 022 失败 → 023 级联跳过，原因「前置 022_personal-avatar 失败」）；
    豁免与已有通过记录不级联；修复前置后重跑，级联任务自动恢复执行
  - **耗时统计**：逐任务执行时长记入任务日志尾部 [耗时] 行与 run-all.log 逐任务
    明细表（耗时列），结束输出起止时间、总耗时、任务执行耗时合计
- 单任务：bash .asdm/workspace/replay-testcase/<执行入口>
  （需身份覆盖的任务按 §3.3 传环境变量；010-017、024-026 脚本内置 test01 切换，无需传参）
- 断点续跑：直接重跑 run-all.sh（任务日志含 [结果] 通过 自动跳过，从首个未通过任务
  继续），或从失败任务起按依赖序单任务执行；禁止删除已通过任务日志整批重跑
  （创建类用例不幂等）

## 五、通过标准

- 任务级：退出码 0 且日志无 [失败] / [断言失败]
- 计划级：全部 28 个任务通过或豁免/级联跳过留痕（级联跳过须注明根因），无未处理阻塞

## 六、豁免与阻塞记录

| 任务 | 类型 | 原因 | 解除条件 |
| --- | --- | --- | --- |
| 011_project-config | 豁免-缺外部数据 | GH_TOKEN 默认值为占位符 ghp_xxx | `GH_TOKEN=...` 环境变量注入真实 Token（环境变量优先于 test-data.sh，注入后自动解除，无需重新生成） |
| 014_workspace-runs | 豁免-缺外部数据 | 同上（GH_TOKEN 级联链：项目无 GitHub 仓库/CI 时无法执行） | 同上 |
| 016_context-items | 豁免-缺外部数据 | 同上（GH_TOKEN 级联链） | 同上 |
| 017_context-sync-status | 豁免-缺外部数据 | 同上（GH_TOKEN 级联链） | 同上 |
| 099_efficiency-insights（项目管理员部分） | 内置豁免（脚本内逻辑） | PROJECT_ADMIN_USER / PASS 默认值为空 | 创建项目管理员用户后将凭据写入变量或环境变量覆盖（脚本内置豁免，不占 EXEMPT_RULES） |

> 【条件豁免守卫（当前未触发）】run-all.sh 的 EXEMPT_RULES 保留 018/022/023 →
> AGENT_ORBIT_KEY 共 3 条**条件守卫**：本批次该变量已填真实值，规则不触发；若后续
> 刷新 test-data.sh 时变量回退为空或含占位符特征（PLACEHOLDER=xxx），对应任务**自动
> 重新判定为豁免**并留痕，无需重新生成编排脚本。
>
> 【豁免变化说明】上一时间戳批次（0901085429）曾因 GH_TOKEN / AGENT_ORBIT_KEY 补齐
> 而当批 7 项豁免全部解除（§七 差异 17）；本批 T001 数据重新生成后 GH_TOKEN 回退为
> 占位符 → 011/014/016/017 豁免恢复，AGENT_ORBIT_KEY 保留真实值 → 018/022/023 不受影响。

## 七、差异备注（脚本 vs README / 环境）

| # | 差异 | 处理 |
| --- | --- | --- |
| 1 | 目录布局为定版布局（脚本集中 `replay_testcase/<编号_用例名>.sh`、公共库 `common/common.sh`），非 spec 的 `sh/<编号_用例名>/` 案例子目录 | 执行入口按实际路径书写（`replay_testcase/<slug>.sh`）；再次迁移布局时重新生成本计划 |
| 2 | 012 编号重号：012_create-workspace（现役用例）与 012_system-logout（历史脚本） | 按用例名升序、以 slug 全名区分任务；logout 语义为收尾，执行序置尾 |
| 3 | README §用例总览仅列 001-011（11 用例），当前脚本集合为 28 任务 | README 未随脚本集合更新，以脚本实际内容为准 |
| 4 | test-cases/ 无 012_system-logout.md（历史脚本无用例源文件） | 脚本存在即可执行，任务保留 |
| 5 | 020/021 用例前置组织（ASDM-Org / organization）在平台不存在 | 以本批顶层组织代跑验证流程（ASDM_ORG_NAME / ORG_CONFIG_NAME 默认 `T001_组织01`，随批次实例同步；平台创建 ASDM-Org 后可用环境变量覆盖） |
| 6 | 012/013/015/016/017/024/025/026 用例原文项目名/空间名与 test-data.sh 批次数据不一致 | 按规范以 test-data.sh 统一（$PROJECT_NAME / $WORKSPACE_NAME / $KNOWLEDGE_NAME 等） |
| 7 | 旧时间戳批次 0901085429 已于 2026-09-01 16:23-16:40 全量执行过一轮（通过 24 / 失败 2 / 级联跳过 1） | 旧批次数据随批次号机制改造废止（平台时间戳残留按既有清理纪律处理）；本批 T001 为新批次直接回放，见 §一 与 §八 |
| 8 | 门户首页改版为「AI资源中心」（URL /portal/）：未登录态页面仅含[登录]按钮，无用户信息区域/控制台管理入口；叠加 012_system-logout 收尾登出清场，单任务补跑时无登录态 → 首轮多任务失败共因 | common.sh `login()` 增加"登录表单未渲染时直达 /signin"兜底修复；006/007/008/009 补幂等 `login` 前置 |
| 9 | 资源管理列表资源名 = 上传文件名（context-builder-8.zip），且列表**不随提交自动刷新**（需整页重载才可见新记录） | 009 断言默认值改为 `$fname` 并在第 6 轮整页重载；013 关联目标同步修正，幂等分支复跑验证通过 |
| 10 | bash（macOS UTF-8 locale）下 `$VAR` 紧跟全角括号时被并入变量名报 unbound variable | 编码规范项：引用变量的 echo 字符串内一律用 `${VAR}` 显式界定边界 |
| 11 | 平台组织树变化：用例原文的 ASDM-Org / organization / AI开发运维板块 均不存在，现存顶层组织随批次变化（本批为 `T001_组织01`） | test-data.sh 的 ASDM_ORG_NAME / ORG_CONFIG_NAME 默认值随批次实例同步（本批 `T001_组织01`，旧时间戳批次为 `测试组织0901085429`） |
| 12 | 知识空间详情 URL 实测形态 `/proj-<ts>/_library/contexts/<id>`；旧特征文本『查看知识空间详情、知识源和配置』已随平台改版移除 | 016 已改用[知识源]入口软断言；025 改 URL 校验；026 详情页判定同款修正 |
| 13 | **编排日志去时间戳**（2026-08-27 决策）：任务日志统一 `result/<任务>.log` 覆盖式、汇总 `result/run-all.log`；断点依据改为任务日志内 `[结果] 通过` 记录 | run-all.sh 已改（固定名输出+结果记录+失败重测），历史执行记录以注记形式保留于 §八 |
| 14 | **run-all.sh 执行增强**（2026-09-01）：① Ctrl+C/SIGTERM 优雅中断（trap）；② 依赖失败级联跳过（DEPS 表）；③ 耗时统计 | run-all.sh 已实现；§四「禁止调用 run-all.sh」同步调整为单实例约束；重新生成 run-all.sh 时需回填（同 §六 条件豁免规则回填要求） |
| 15 | **目录布局迁移**（2026-09-01）：脚本由 `replay-testcase/replay_testcase_<slug>.sh` 平铺改为 `replay_testcase/<slug>.sh`，`common.sh` 移入 `common/` | 27 个脚本头部三处同步更新（source / DATA_DIR / 注释脚本名）；`run-all.sh` 入口改 `${ROOT_DIR}/replay_testcase/${tc}.sh`；`bash -n` 全量通过 |
| 16 | 022/023 依赖链形态：023 头部前置声明依赖 018（AgentOrbit 连接配置），脚本内另有 AGENT_ORBIT_KEY 前置守卫；022 未声明对 023 的供给关系但为同链上游 | 依赖链按脚本声明 + 数据链补齐 022 → 023；DEPS 表已加入该边（历史实测生效：022 失败 → 023 级联跳过） |
| 17 | **旧批次数据变化**（2026-09-01 刷新，历史记录）：时间戳批次 0827092838 → 0901085429；BASE_URL platform-dt01 → platform-sit01；GH_TOKEN 占位符补为真实 Token；AGENT_ORBIT_KEY 由空补为真实密钥 | 当批 7 项豁免全部解除（011/014/016/017/018/022/023）；本批 T001 重新生成数据后 GH_TOKEN 回退占位符 → 4 项豁免恢复，见差异 24 与 §六 |
| 18 | README §测试环境平台地址写 `https://platform-dt02.asdm.ai/`，与 test-data.sh 不一致（本批为 asdm-dt01） | 以 test-data.sh 为准（回放实际执行环境）；README 未同步更新 |
| 19 | 历史实测失败 2 项：022 用户集合无个人数字分身创建权限（平台配置，非脚本缺陷）；026 兜底添加知识源成功后知识源列表未刷新 → [构建] 按钮未找到 | 平台侧问题，对 T001 批次仍可能复现；022 需平台开通权限后执行，026 待修复时序问题后执行（执行时在 §八 留痕） |
| 20 | 依赖链 README 兜底：002/003/004/005/012_system-logout 及全部 test01 类任务的脚本「前置条件」节声明为"登录自愈，可独立执行"，未引用 001 | 依赖链以脚本为准（不引入脚本未声明的硬依赖），仅按 README 依赖树兜底补 001 登录态边，保证编排顺序与级联判定完整；冲突记录于此 |
| 21 | 009 脚本「前置条件」节仅声明 001，但 step 3 注释说明 [资源管理] Tab 依赖 008 开启的 `hide_admin_resource_management` 开关 | 属功能隐性依赖（非前置条件节声明）：前置列按 §2.2 规则仅记 001，此处登记；008 失败时 009 会连带失败 |
| 22 | **资源页面/管理场景智能体弹窗改版**（2026-09-07 实测，时间戳批次 0907113119）：资源页新增"资源类型"分组（场景智能体/知识空间/规约/技能 计数按钮）并直接展示场景智能体列表；弹窗"已关联"区资源名不再进交互快照（generic 汇总行 name 文本被截断）——013 旧断言 `grep '- generic "…已关联…"'` 必然落空，09-07 14:06 首跑假失败（实际 step 6 新增已生效） | 013 已改（DOM innerText 口径）：① 幂等检查前移至资源页面场景智能体列表（已含目标资源即视为完成，不打开弹窗）；② 新增关联后显式关闭弹窗（step 7，Close 精确匹配 + Escape 兜底 + dialog_open 校验）；③ 断言定版为"资源页面场景智能体列表出现资源名"唯一口径（弹窗内文本不作断言依据，防弹窗未关时 body.innerText 假阳性；第 6 轮未命中整页重载兜底）。新增路径（32s）与幂等路径（20s）均实测通过 |
| 23 | **资源管理列表默认视图不展示新上传记录**（2026-09-07 15:30 实测，时间戳批次 0907152255）：009 上传提交后，裸列表 + 整页重载轮询 12 轮均未见 context-builder-8.zip——差异 9 的整页重载方案失效（疑似列表分页/默认过滤变化）。操作记录（`Recording 2026_9_7 at 16_03_04.json`）证实：须输入查询资源名称 + 资源类型=场景智能体（原生 select 值 toolset）+ 状态=正常（原生 select 值 Active）→ 点[搜索] 后列表方展示目标行 | 009 断言改搜索驱动：等弹窗关闭（超时打印弹窗文本摘要）→ 整页重载 ResourceManager → eval 按选项值特征（toolset/Active）识别两个无标签原生 select 并打 data-asdm-f 标签 → fill 名称 + select 类型/状态 + click [搜索] → 轮询匹配列表行（快照 cell/link，DOM innerText 兜底防 generic 行不进快照）；全名未命中退化为去 .zip 基名搜索（与 013/016 版本低适配口径一致） |
| 24 | **T001 批次刷新**（2026-11-05，批次号机制改造后首批）：批次标识由时间戳改为 BATCH_ID=T001；名称类变量全部批次实例化（T001_组织01/02、T001_USER01@asdm.ai、T001_PAT01、T001_项目01、T001_智能体空间01/02、T001_知识空间01/02、T001_知识源01/02、T001_分身01/02）；PIPELINE_NAME 由固定值 `pipeline` 转批次实例 `T001_流水线01`（幂等守卫"同名跳过"随批次名每批真实执行创建）；BASE_URL platform-sit01 → **asdm-dt01**；GH_TOKEN 回退占位符 ghp_xxx | 计划头部/§一/§六、run-all.sh 头部与横幅同步更新；020/021 代跑组织随批次同步为 `T001_组织01`；平台残留数据按 `T0xx_` 前缀辨识清理 |
| 25 | `replay_testcase/` 目录当前为空：28 个回放脚本曾随 c50db51 提交入库、后被 218f1ee（2026-11-05「删除用例回放脚本」）整批删除，当前工作区与 HEAD 均无脚本，本轮计划生成无法实地扫描（初判"git 亦无跟踪记录"有误，任务 6 核实 git 历史后更正于此） | 任务四要素/依赖链沿用上一版计划快照（脚本集合无变化信号，任务数 N=28 维持）；任务 6 已从 git 历史 `218f1ee^` 流式读取 28 脚本完成纸面验证（见差异 27）；脚本恢复入工作区后需重新执行 generate-test-plan.md 复核 |
| 26 | 009 上传资源包 `data/context-builder-8.zip` 当前缺失（data/ 下仅 test-data.sh） | 执行 009 前将场景智能体资源包放置为 `data/context-builder-8.zip`，或 `UPLOAD_FILE=...` 环境变量指向既有资源包（013 关联 / 016 下拉引用链字面 = 文件名，覆盖时需同步） |
| 27 | **任务 6 端到端验证降级为纸面验证**（2026-11-05，用户决策：回放脚本不从 git 历史恢复入工作区）→ 平台侧实跑（001/003/005/006/007/010 抽样）未执行，批次机制的平台约束项（`T001_USER01@asdm.ai` 邮箱可注册性、`T001_组织01` 等名称唯一性、PAT 同名 409 兜底、T002 重跑防重名、断点续跑同批禁生成）均未实测 | 已完成纸面等价验证：① 数据闭环——source 后 59 变量全过（名称类 `^T001_` 前缀、邮箱格式、4 组依赖链字面对齐、PROJECT_NAME 8 字符 ≤20、凭据/占位符未被批次化、定义 vs export diff 为空）；② 28 脚本（git `218f1ee^` 版）`bash -n` 全过 + `require_vars` 变量全部可在 test-data.sh/运行产物（PAT）解析 + 无时间戳字面量残留；③ 抽样 6 脚本（001/003/005/006/007/010）名称类变量 `$VAR` 引用齐全、无硬编码批次值；④ T002 换批次临时副本推导验证（批次号替换后依赖链字面一致、凭据不随批次变化，T001 产物未动）；⑤ 豁免链路回归——run-all.sh `is_exempt` 判定演练 7 条全符预期（011/014/016/017 豁免、018/022/023 就绪）+ GH_TOKEN 注入解除 / AGENT_ORBIT_KEY 回退守卫生效演练通过；⑥ 工具集 `grep -r TEST_TS` 零命中。附注：019 脚本（git 历史版）注释含历史修复记录字样「失败批次 TEST_TS=0902105235」，属描述性引用非机制残留；3 个 `.bak-ts*` 旧时间戳备份经与 git 218f1ee 版 diff 确认内容一致后按清理纪律删除。平台实跑待回放脚本恢复入工作区后按 §三 拓扑序补做，结果记入 §八 |

## 八、执行记录（执行时填写）

> 历史执行①：旧 22 任务编排（2026-08-27 09:40），汇总日志未随工作区留存。
> 历史执行②：27 任务版编排（2026-08-27 14:39 起，时间戳批次 0827092838）：通过 20 / 豁免 7 / 已修待验 1。
> 历史执行③：时间戳批次 0901085429（2026-09-01 16:23-16:40）：通过 24（含跳过-已有通过 4）/ 失败 2（022、026）/ 级联跳过 1（023）/ 豁免 0；总耗时 12m48s。
> 历史遗留待办（平台侧，对 T001 仍可能复现）：① 022 需平台开通"用户所在集合的个人数字分身创建权限"（或分身实例数配额）；② 026 需修复"知识源创建后列表未刷新即定位 [构建] 按钮"的时序问题。

**本批（BATCH_ID=T001）：待执行**（2026-11-05 任务 6 已完成批次机制**纸面验证**，各项结论见 §七 差异 27；平台实跑待回放脚本恢复入工作区后按 §三 拓扑序执行，逐任务结果记入下表）

> 纸面验证摘要（2026-11-05）：数据闭环 / 计划闭环 / 脚本静态校验（bash -n × 28）/ require_vars 对照 /
> T002 换批次推导 / 豁免链路回归共 6 项全部通过；平台侧约束实测（邮箱注册、名称唯一性、409 兜底、
> 重名换批次、断点续跑）未执行，属降级范围。

| 任务 | 执行时间（含耗时） | 结果（通过/失败/豁免/阻塞/级联跳过/中断/未执行） | 日志/证据 | 备注 |
| --- | --- | --- | --- | --- |
| … | … | … | … | … |
