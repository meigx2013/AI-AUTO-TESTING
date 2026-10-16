# ASDM 回放测试计划（测试任务）

> 【静态实例】本文件由 .asdm/toolsets/transfer/generate-test-plan.md 生成，不含生成逻辑；
> 需要新计划时重新执行该文档，禁止在本文件内手写生成规则。
>
> - 最近生成：2026-09-01 17:37　数据批次：TEST_TS=0901085429
> - 目录布局：**定版布局**——脚本集中 `replay_testcase/<编号_用例名>.sh`、公共库 `common/common.sh`
>   （2026-09-01 由根目录平铺迁移而来，见 §七 差异 16；`spec/directory-structure-spec.md`
>   的 `sh/<编号_用例名>/` 案例子目录为更远期目标态，未采用）
> - 任务数量：28 个（27 个脚本文件，其中 012 编号含双脚本，由目录扫描决定）
> - 日志目录：result/（**去时间戳·固定名覆盖式**：任务 = `<任务>.log`，汇总 = `run-all.log`；历史归档 result/history/）
> - **执行约束：同一时间仅允许一个 run-all.sh 实例运行（多实例并发会互相干扰测试状态）。run-all.sh 已于 2026-09-01 完成执行增强——Ctrl+C 优雅中断、依赖失败级联跳过、逐任务/总体耗时统计；中断或失败后重跑即断点续跑（已通过任务自动跳过），详见 §四与 §七 差异 15**

## 一、批次与环境

| 项 | 值 |
| --- | --- |
| 数据批次 TEST_TS | 0901085429 |
| BASE_URL | https://platform-sit01.asdm.ai/ |
| 回放前是否需刷新数据 | **是**：TEST_TS=0901085429 批次已于 2026-09-01 16:23-16:40 全量执行过一轮（通过 24 / 失败 2 / 级联跳过 1，见 §八），创建类数据（组织/子组织/用户/PAT/项目/空间/知识空间/知识源等）已在平台落库。再次全量回放需先执行 generate-test-data.md 刷新批次；或**断点续跑**直接重跑 run-all.sh 补跑 022/023/026（已通过任务自动跳过，且不重复创建） |
| 跨脚本落盘数据现状 | data/pat.txt 存在且非空（47 字节，`pat_CQ9E…`，006 于 16:28 产出，007 消费就绪） |
| 外部凭据变量现状 | GH_TOKEN、AGENT_ORBIT_KEY 本批次均已填入真实值 → **上批 7 项豁免全部解除，本批无豁免任务**（见 §七 差异 17） |

## 二、任务清单（共 28 个）

> 任务行由生成器按 §3.1/§3.3/§3.4 逐脚本填充（说明列取 test-cases 用例一句话概要）；
> 全部 27 个任务的 `require_vars` 变量在 test-data.sh 均有非空且非占位符默认值 → 状态全部「就绪」。

| # | 任务 | 说明 | 执行入口 | 身份 | 前置 | 数据依赖 | 产出 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 001_system-login | 系统登录：Portal 首页登录，断言进入已登录首页 | replay_testcase/001_system-login.sh | super-admin | — | ASDM_USER / ASDM_PASS | 登录态 | 就绪 |
| 2 | 002_access-asdm | 进入 ASDM 管理后台（用户信息 → 控制台管理） | replay_testcase/002_access-asdm.sh | super-admin | 001 | — | — | 就绪 |
| 3 | 003_create-org | 创建顶层组织 | replay_testcase/003_create-org.sh | super-admin | 001 | ORG_NAME | 顶层组织 | 就绪 |
| 4 | 004_create-sub-org | 创建子组织（父组织行 … → 创建子组织） | replay_testcase/004_create-sub-org.sh | super-admin | 001、003 | PARENT_ORG、SUB_ORG_NAME | 子组织 | 就绪 |
| 5 | 005_create-user | 创建用户（含角色映射） | replay_testcase/005_create-user.sh | super-admin | 001 | NEW_USER_EMAIL / _PASS / _ROLE / _ORG / _LAST / _FIRST | test01 账号 | 就绪 |
| 6 | 006_generate-pat | 生成 PAT 令牌并落盘 data/pat.txt | replay_testcase/006_generate-pat.sh | super-admin | 001 | PAT_NAME、PAT_EXPIRY | data/pat.txt | 就绪 |
| 7 | 007_pipeline-config | 添加流水线配置（Jenkins 型，读取 data/pat.txt） | replay_testcase/007_pipeline-config.sh | super-admin | 001、006 | PIPELINE_NAME、JENKINS_URL / _CRED、data/pat.txt | 流水线配置 | 就绪 |
| 8 | 008_feature-flag | 特性开关批量编辑为全量开放 | replay_testcase/008_feature-flag.sh | super-admin | 001 | FEATURE_FLAGS、FLAG_STATUS | — | 就绪 |
| 9 | 009_resource-management-toolset | 上传场景智能体资源包 | replay_testcase/009_resource-management-toolset.sh | super-admin | 001 | UPLOAD_FILE、RES_SCOPE / _TYPE / _CATEGORY | 平台场景智能体资源 | 就绪 |
| 10 | 010_create-project | 创建项目（test01 身份） | replay_testcase/010_create-project.sh | test01（脚本内置切换） | 001、004、005 | ORG_NODE、PROJECT_NAME | 项目 | 就绪 |
| 11 | 011_project-config | 项目仓库配置（添加仓库 → 检测可用性） | replay_testcase/011_project-config.sh | test01（脚本内置切换） | 001、010 | REPO_URL、REPO_BRANCH、REPO_NAME、GH_TOKEN | 项目仓库配置 | 就绪 |
| 12 | 012_create-workspace | 创建智能体空间（普通类） | replay_testcase/012_create-workspace.sh | test01（脚本内置切换） | 001、005、010 | WORKSPACE_NAME / _TYPE / _DESC | 智能体空间 | 就绪 |
| 13 | 013_workspace-resources | 空间关联场景智能体资源 | replay_testcase/013_workspace-resources.sh | test01（脚本内置切换） | 001、009、010、012_create-workspace | UPLOAD_FILE | 空间已关联资源 | 就绪 |
| 14 | 014_workspace-runs | 触发空间运行，生成执行历史 | replay_testcase/014_workspace-runs.sh | test01（脚本内置切换） | 001、010、012_create-workspace、013 | RUN_PROMPT | 执行历史记录 | 就绪 |
| 15 | 015_create-context | 创建知识空间（个人空间） | replay_testcase/015_create-context.sh | test01（脚本内置切换） | 001、010 | KNOWLEDGE_NAME、KNOWLEDGE_DESC | 知识空间 | 就绪 |
| 16 | 016_context-items | 知识空间添加知识源（单步自动化构建） | replay_testcase/016_context-items.sh | test01（脚本内置切换） | 001、010、015 | CONTEXT_BUILD_MODE / _SOURCE_NAME / _REPO_URL / _AGENT / _CMD | 知识源 | 就绪 |
| 17 | 017_context-sync-status | 知识空间触发同步，新增同步记录 | replay_testcase/017_context-sync-status.sh | test01（脚本内置切换） | 001、010、015、016 | — | 同步记录 | 就绪 |
| 18 | 018_agentorbit-config | 配置 AgentOrbit 连接密钥 | replay_testcase/018_agentorbit-config.sh | super-admin | 001 | AGENT_ORBIT_KEY | AgentOrbit 连接配置 | 就绪 |
| 19 | 019_hide-digidev-icon | 隐藏 DigiDev 图标（特性开关） | replay_testcase/019_hide-digidev-icon.sh | super-admin | 001 | HIDE_DIGIDEV_FLAG、FLAG_STATUS | — | 就绪 |
| 20 | 020_asdm-org-agent | 组织 Agent 设置（顶层组织代跑） | replay_testcase/020_asdm-org-agent.sh | super-admin | 001 | ASDM_ORG_NAME | — | 就绪 |
| 21 | 021_organization-agent-config | 组织 Agent 配置（顶层组织代跑） | replay_testcase/021_organization-agent-config.sh | super-admin | 001 | ORG_CONFIG_NAME | — | 就绪 |
| 22 | 022_personal-avatar | 创建个人数字分身 | replay_testcase/022_personal-avatar.sh | super-admin | 001 | AVATAR_NAME、AGENT_ORBIT_KEY | 个人数字分身 | 就绪 |
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

**校验结论**：28 个任务全部在链上（无孤立任务）；依赖无环（全部引用编号 ≤ 自身，012_create-workspace 与 012_system-logout 互不依赖）；无悬空依赖（被引用的 slug 全部存在）；012_system-logout 为收尾类脚本置尾；022 → 023 为新增数据链（022 产出分身 → 023 校验创建成功提示）；099 内含三角色身份切换（super-admin + test01 + project-admin），项目管理员部分凭据为空时脚本内置豁免逻辑跳过。

## 四、执行方式

> 【并发约束·2026-09-01 调整】同一时间仅允许一个 run-all.sh 实例（多实例并发会互相
> 干扰测试状态）；人工逐任务执行期间请勿同时启动 run-all.sh。原「禁止调用
> run-all.sh」约束随本次执行增强（§七 差异 15）调整为上述单实例约束。

- **全量编排**：bash .asdm/workspace/replay-testcase/task/run-all.sh
  - **Ctrl+C 优雅中断**：SIGINT/SIGTERM 触发后当前任务停止并记「中断」（任务日志留痕），
    未开始任务记「未执行」，输出已执行汇总与耗时统计后以退出码 130 退出；
    中断后直接重跑本脚本 = 断点续跑（已通过任务自动跳过，从中断/失败任务继续）
  - **依赖失败级联跳过**：任一任务失败后，DEPS 依赖表（取自 §二「前置」列）中依赖
    该任务的后继任务不再执行，标记「级联跳过」并注明根因链（本批实测：
    022 失败 → 023 级联跳过，原因「前置 022_personal-avatar 失败」）；
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
| 无 | — | 本批次 test-data.sh 全部必需变量均为非空且非占位符真实值，27 个任务全部就绪 | — |

> 【条件豁免规则（当前未触发）】run-all.sh 的 EXEMPT_RULES 保留 7 条**条件守卫**
> （011/014/016/017 → GH_TOKEN；018/022/023 → AGENT_ORBIT_KEY）：本批次两个外部
> 凭据变量已填入真实值，规则均不触发；若后续刷新 test-data.sh 时变量回退为空或
> 含占位符特征（PLACEHOLDER=xxx），对应任务**自动重新判定为豁免**并留痕，
> 无需重新生成编排脚本。
>
> 【上批豁免解除说明】上一批（0827092838）7 项豁免（011/014/016/017=GH_TOKEN 链，
> 018/022/023=AGENT_ORBIT_KEY）随本批数据补齐而全部解除——011 已于 16:31 通过，
> 其级联的 014/016/017 亦全部通过，018 于 16:34 通过（详见 §八 与 §七 差异 17）。

## 七、差异备注（脚本 vs README / 环境）

| # | 差异 | 处理 |
| --- | --- | --- |
| 1 | 目录布局为定版布局（脚本集中 `replay_testcase/<编号_用例名>.sh`、公共库 `common/common.sh`），非 spec 的 `sh/<编号_用例名>/` 案例子目录 | 执行入口按实际路径书写（`replay_testcase/<slug>.sh`）；再次迁移布局时重新生成本计划 |
| 2 | 012 编号重号：012_create-workspace（现役用例）与 012_system-logout（历史脚本） | 按用例名升序、以 slug 全名区分任务；logout 语义为收尾，执行序置尾 |
| 3 | README §用例总览仅列 001-011（11 用例），当前脚本集合 26 个（27 任务） | README 未随脚本集合更新，以脚本实际内容为准 |
| 4 | test-cases/ 无 012_system-logout.md（历史脚本无用例源文件） | 脚本存在即可执行，任务保留 |
| 5 | 020/021 用例前置组织（ASDM-Org / organization）在平台不存在 | 以现存顶层组织代跑验证流程（ASDM_ORG_NAME / ORG_CONFIG_NAME 默认 `测试组织0901085429`，随批次同步；平台创建 ASDM-Org 后可用环境变量覆盖） |
| 6 | 012/013/015/016/017/024/025/026 用例原文项目名/空间名与 test-data.sh 批次数据不一致 | 按规范以 test-data.sh 统一（$PROJECT_NAME / $WORKSPACE_NAME / $KNOWLEDGE_NAME 等） |
| 7 | TEST_TS=0901085429 批次已于 2026-09-01 16:23-16:40 执行过一轮（通过 24 / 失败 2 / 级联跳过 1） | 全量重放前刷新批次（generate-test-data.md）；补跑用断点续跑，见 §一 与 §八 |
| 8 | 门户首页改版为「AI资源中心」（URL /portal/）：未登录态页面仅含[登录]按钮，无用户信息区域/控制台管理入口；叠加 012_system-logout 收尾登出清场，单任务补跑时无登录态 → 首轮多任务失败共因 | common.sh `login()` 增加"登录表单未渲染时直达 /signin"兜底修复；006/007/008/009 补幂等 `login` 前置 |
| 9 | 资源管理列表资源名 = 上传文件名（context-builder-8.zip），且列表**不随提交自动刷新**（需整页重载才可见新记录） | 009 断言默认值改为 `$fname` 并在第 6 轮整页重载；013 关联目标同步修正，幂等分支复跑验证通过 |
| 10 | bash（macOS UTF-8 locale）下 `$VAR` 紧跟全角括号时被并入变量名报 unbound variable | 编码规范项：引用变量的 echo 字符串内一律用 `${VAR}` 显式界定边界 |
| 11 | 平台组织树变化：用例原文的 ASDM-Org / organization / AI开发运维板块 均不存在，现存顶层组织 = 本批 `测试组织0901085429`（随 TEST_TS 变化） | test-data.sh 的 ASDM_ORG_NAME / ORG_CONFIG_NAME 默认值随批次同步为 `测试组织0901085429`（上批为 测试组织0827143340） |
| 12 | 知识空间详情 URL 实测形态 `/proj-<ts>/_library/contexts/<id>`；旧特征文本『查看知识空间详情、知识源和配置』已随平台改版移除 | 016 已改用[知识源]入口软断言；025 改 URL 校验；026 详情页判定同款修正 |
| 13 | **编排日志去时间戳**（2026-08-27 决策）：任务日志统一 `result/<任务>.log` 覆盖式、汇总 `result/run-all.log`；断点依据改为任务日志内 `[结果] 通过` 记录 | run-all.sh 已改（固定名输出+结果记录+失败重测），§八证据列已切换新路径 |
| 14 | **run-all.sh 执行增强**（2026-09-01）：① Ctrl+C/SIGTERM 优雅中断（trap）；② 依赖失败级联跳过（DEPS 表）；③ 耗时统计 | run-all.sh 已实现；§四「禁止调用 run-all.sh」同步调整为单实例约束；重新生成 run-all.sh 时需回填（同 §六 条件豁免规则回填要求） |
| 15 | **目录布局迁移**（2026-09-01）：脚本由 `replay-testcase/replay_testcase_<slug>.sh` 平铺改为 `replay_testcase/<slug>.sh`，`common.sh` 移入 `common/` | 27 个脚本头部三处同步更新（source / DATA_DIR / 注释脚本名）；`run-all.sh` 入口改 `${ROOT_DIR}/replay_testcase/${tc}.sh`；`bash -n` 全量通过 |
| 16 | 022/023 依赖链形态：023 头部前置声明依赖 018（AgentOrbit 连接配置），脚本内另有 AGENT_ORBIT_KEY 前置守卫；022 未声明对 023 的供给关系但为同链上游 | 依赖链按脚本声明 + 数据链补齐 022 → 023；DEPS 表已加入该边（本批实测生效：022 失败 → 023 级联跳过） |
| 17 | **新批次数据变化**（2026-09-01 刷新）：TEST_TS 0827092838 → **0901085429**；BASE_URL platform-dt01 → **platform-sit01**；GH_TOKEN 由占位符 ghp_xxx 补为真实 Token；AGENT_ORBIT_KEY 由空补为真实密钥 | 上批 7 项豁免全部解除（011/014/016/017/018/022/023），本批 27 任务全部就绪；计划头部批次、§一、§六、run-all.sh 头部同步更新 |
| 18 | README §测试环境平台地址写 `https://platform-dt02.asdm.ai/`，与 test-data.sh 的 `platform-sit01` 不一致 | 以 test-data.sh 为准（回放实际执行环境为 sit01）；README 未同步更新 |
| 19 | 本批实测失败 2 项：022 用户集合无个人数字分身创建权限（平台配置，非脚本缺陷）；026 兜底添加知识源成功后知识源列表未刷新 → [构建] 按钮未找到 | 见 §八 执行记录；断点续跑补跑这两项（023 随 022 恢复自动解禁） |
| 20 | 依赖链 README 兜底：002/003/004/005/012_system-logout 及全部 test01 类任务的脚本「前置条件」节声明为"登录自愈，可独立执行"，未引用 001 | 依赖链以脚本为准（不引入脚本未声明的硬依赖），仅按 README 依赖树兜底补 001 登录态边，保证编排顺序与级联判定完整；冲突记录于此 |
| 21 | 009 脚本「前置条件」节仅声明 001，但 step 3 注释说明 [资源管理] Tab 依赖 008 开启的 `hide_admin_resource_management` 开关 | 属功能隐性依赖（非前置条件节声明）：前置列按 §2.2 规则仅记 001，此处登记；008 失败时 009 会连带失败 |
| 22 | **资源页面/管理场景智能体弹窗改版**（2026-09-07 实测，TEST_TS=0907113119 批次）：资源页新增"资源类型"分组（场景智能体/知识空间/规约/技能 计数按钮）并直接展示场景智能体列表；弹窗"已关联"区资源名不再进交互快照（generic 汇总行 name 文本被截断）——013 旧断言 `grep '- generic "…已关联…"'` 必然落空，09-07 14:06 首跑假失败（实际 step 6 新增已生效） | 013 已改（DOM innerText 口径）：① 幂等检查前移至资源页面场景智能体列表（已含目标资源即视为完成，不打开弹窗）；② 新增关联后显式关闭弹窗（step 7，Close 精确匹配 + Escape 兜底 + dialog_open 校验）；③ 断言定版为"资源页面场景智能体列表出现资源名"唯一口径（弹窗内文本不作断言依据，防弹窗未关时 body.innerText 假阳性；第 6 轮未命中整页重载兜底）。新增路径（32s）与幂等路径（20s）均实测通过 |
| 23 | **资源管理列表默认视图不展示新上传记录**（2026-09-07 15:30 实测，TEST_TS=0907152255 批次）：009 上传提交后，裸列表 + 整页重载轮询 12 轮均未见 context-builder-8.zip——差异 9 的整页重载方案失效（疑似列表分页/默认过滤变化）。操作记录（`Recording 2026_9_7 at 16_03_04.json`）证实：须输入查询资源名称 + 资源类型=场景智能体（原生 select 值 toolset）+ 状态=正常（原生 select 值 Active）→ 点[搜索] 后列表方展示目标行 | 009 断言改搜索驱动：等弹窗关闭（超时打印弹窗文本摘要）→ 整页重载 ResourceManager → eval 按选项值特征（toolset/Active）识别两个无标签原生 select 并打 data-asdm-f 标签 → fill 名称 + select 类型/状态 + click [搜索] → 轮询匹配列表行（快照 cell/link，DOM innerText 兜底防 generic 行不进快照）；全名未命中退化为去 .zip 基名搜索（与 013/016 版本低适配口径一致） |

## 八、执行记录（执行时填写）

> 历史执行①：旧 22 任务编排（2026-08-27 09:40），见 run-all-20260827_094037.log（旧批次汇总，文件未随本轮 result/ 留存）。
> 历史执行②：27 任务版编排（2026-08-27 14:39 起，批次 0827092838）：通过 20 / 豁免 7 / 已修待验 1。
>
> **本批（TEST_TS=0901085429）执行③：2026-09-01 16:23-16:40**
> 001-004 先行单跑通过后，16:27:11 起由 run-all.sh 编排执行（前 4 项命中"已有通过记录"跳过）。
> **汇总：通过 24（含跳过-已有通过 4）/ 失败 2（022、026）/ 级联跳过 1（023）/ 豁免 0；
> 总耗时 12m48s，任务执行耗时合计 12m46s**（起止 16:27:11 → 16:39:59）。
> 逐任务耗时见各任务日志尾部 [耗时] 行与 run-all.log 逐任务明细表（耗时列）。
>
> 遗留待办：① 022 需平台开通"用户所在集合的个人数字分身创建权限"（或分身实例数配额）后补跑；
> ② 026 需修复"知识源创建后列表未刷新即定位 [构建] 按钮"的时序问题后补跑；
> ③ 023 在 022 通过后随断点续跑自动解禁。
> 【补跑命令】bash .asdm/workspace/replay-testcase/task/run-all.sh（已通过任务自动跳过，
> 仅重测 022/023/026）。

| 任务 | 执行时间（含耗时） | 结果（通过/失败/豁免/阻塞/级联跳过/中断/未执行） | 日志/证据 | 备注 |
| --- | --- | --- | --- | --- |
| 001_system-login | 09-01 16:23（单跑） | 通过 | 001_system-login.log | 编排内命中已有通过记录跳过 |
| 002_access-asdm | 09-01 16:24（单跑） | 通过 | 002_access-asdm.log | 同上 |
| 003_create-org | 09-01 16:24（单跑） | 通过 | 003_create-org.log | 创建 测试组织0901085429 |
| 004_create-sub-org | 09-01 16:25（单跑） | 通过 | 004_create-sub-org.log | 创建 测试组织sub0901085429 |
| 005_create-user | 09-01 16:27（29s） | 通过 | 005_create-user.log | test01 = test0901085429@asdm.ai 已建成 |
| 006_generate-pat | 09-01 16:27（44s） | 通过 | 006_generate-pat.log | PAT 已落盘 data/pat.txt（47 字节） |
| 007_pipeline-config | 09-01 16:28（40s） | 通过 | 007_pipeline-config.log | 消费 006 新产出 PAT |
| 008_feature-flag | 09-01 16:29（52s） | 通过 | 008_feature-flag.log | 3 开关编辑 + 复核全过 |
| 009_resource-management-toolset | 09-01 16:29（51s） | 通过 | 009_resource-management-toolset.log | 上传 context-builder-8.zip；断言用上传文件名 + 整页重载 |
| 010_create-project | 09-01 16:30（38s） | 通过 | 010_create-project.log | 测试组织sub0901085429-项目 |
| 011_project-config | 09-01 16:31（23s） | 通过 | 011_project-config.log | **GH_TOKEN 补齐，上批豁免解除** |
| 012_create-workspace | 09-01 16:31（20s） | 通过 | 012_create-workspace.log | — |
| 013_workspace-resources | 09-01 16:32（21s） | 通过 | 013_workspace-resources.log | 全局共享资源已关联，命中幂等分支 |
| 014_workspace-runs | 09-01 16:32（24s） | 通过 | 014_workspace-runs.log | **上批"流水线服务器不可用"豁免解除**，执行历史已生成 |
| 015_create-context | 09-01 16:32（21s） | 通过 | 015_create-context.log | — |
| 016_context-items | 09-01 16:33（29s） | 通过 | 016_context-items.log | **上批"仓库下拉无可选项"豁免解除**（级联 011 打通） |
| 017_context-sync-status | 09-01 16:33（23s） | 通过 | 017_context-sync-status.log | **上批"无知识源可同步"豁免解除**（级联 016 打通） |
| 018_agentorbit-config | 09-01 16:34（37s） | 通过 | 018_agentorbit-config.log | **AGENT_ORBIT_KEY 补齐，上批豁免解除** |
| 019_hide-digidev-icon | 09-01 16:34（53s） | 通过 | 019_hide-digidev-icon.log | — |
| 020_asdm-org-agent | 09-01 16:35（40s） | 通过 | 020_asdm-org-agent.log | 顶层组织代跑（§七 差异 5/11） |
| 021_organization-agent-config | 09-01 16:36（40s） | 通过 | 021_organization-agent-config.log | 同 020 |
| 022_personal-avatar | 09-01 16:36（39s） | 失败 | 022_personal-avatar.log | [跳过] 用户所在集合无个人数字分身创建权限（AgentOrbit 连接已保存但用户无创建权限/实例数为 0），平台配置问题非脚本缺陷；需管理员开通权限后补跑 |
| 023_digital-avatar-created-successfully | 09-01 16:37 | 级联跳过 | run-all.log | 前置 022_personal-avatar 失败，依赖未就绪不执行；022 通过后重跑自动恢复 |
| 024_create-online-agent-space | 09-01 16:37（44s） | 通过 | 024_create-online-agent-space.log | — |
| 025_online-knowledge-space | 09-01 16:38（33s） | 通过 | 025_online-knowledge-space.log | 含多步知识源创建 |
| 026_multi-step-build | 09-01 16:38（59s） | 失败 | 026_multi-step-build.log | step 4 兜底添加知识源后弹窗已关闭，但知识源列表未刷新 → [构建] 按钮未找到；待补刷新/重试定位后复跑 |
| 012_system-logout | 09-01 16:39（6s） | 通过 | 012_system-logout.log | 收尾清场正常（亦是后续单任务补跑无登录态的原因之一，见 §七 差异 8） |
