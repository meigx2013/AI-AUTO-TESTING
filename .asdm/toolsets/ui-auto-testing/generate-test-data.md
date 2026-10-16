# generate-test-data：刷新 test-data.sh 名称类测试数据

> **执行本文档即刷新测试数据**：大模型按 §三 步骤操作，按 §一/§二 生成规则
> 将一批新的名称类测试数据（测试用户 / 顶层组织 / 子组织及其下游引用，
> 以及 012/015/016/022/023/024/025 独立与挂链创建类名称、020/021 现存组织引用）写入 `data/test-data.sh`，
> 供 003→004→005→010→011 依赖链（含 024/025/026 挂链创建类）及独立创建类
> 用例整批回放使用。
>
> - 输入：无需任何输入（时间戳现场生成）；可选环境变量级指定 `TEST_TS` 锁定批次
> - 输出：刷新 `.asdm/workspace/replay-testcase/data/test-data.sh` 中名称类变量值
>   （含 006 令牌名称 `PAT_NAME`，2026-08-31 补入刷新范围）
> - 定位：`test-data.sh` 是**静态实例**（数据快照），本文件是**唯一生成逻辑来源**；
>   需要新数据时重新执行本文件，禁止在 `test-data.sh` 内写运行时生成逻辑
> - 自给自足：本文档内联全部规则与目标文件模板（§四），不依赖外部文件

## 前置条件

- 目标文件存在：`.asdm/workspace/replay-testcase/data/test-data.sh`（不存在时按 §四模板新建）
- 仅需 `date` 与 `bash`（验证用）；不依赖被测平台可达

## 一、创建规则（命名约定）

名称类数据一律以时间戳 `TEST_TS`（MMDDHHmmss）为后缀，保证每批回放在平台上
生成全新数据、互不冲突：

| 数据类别 | 创建规则 | 变量 | 示例（TEST_TS=0824145422） |
| --- | --- | --- | --- |
| 测试用户邮箱 | `test` + MMDDHHmmss + `@asdm.ai` | `TEST01_USER`、`NEW_USER_EMAIL` | `test0824145422@asdm.ai` |
| 顶层组织名 | `测试组织` + MMDDHHmmss | `ORG_NAME`、`PARENT_ORG` | `测试组织0824145422` |
| 子组织名 | `测试组织sub` + MMDDHHmmss | `SUB_ORG_NAME`、`NEW_USER_ORG`、`ORG_NODE` | `测试组织sub0824145422` |
| 项目名称 | 子组织名 + `-项目` | `PROJECT_NAME` | `测试组织sub0824145422-项目` |
| 智能体空间名 | `工作空间` + MMDDHHmmss | `WORKSPACE_NAME` | `工作空间0824145422` |
| 知识空间名 | `个人空间` + MMDDHHmmss | `KNOWLEDGE_NAME` | `个人空间0824145422` |
| 知识源名称 | `代码类仓库` + MMDDHHmmss | `CONTEXT_SOURCE_NAME` | `代码类仓库0824145422` |
| 个人数字分身名称 | `个人数字分身` + MMDDHHmmss | `AVATAR_NAME` | `个人数字分身0824145422` |
| 数字分身名称 | `数字分身` + MMDDHHmmss | `DIGITAL_AVATAR_NAME` | `数字分身0824145422` |
| 在线智能体空间名 | `在线智能体空间` + MMDDHHmmss | `ONLINE_WORKSPACE_NAME` | `在线智能体空间0824145422` |
| 在线知识空间名 | `在线知识空间` + MMDDHHmmss | `ONLINE_KNOWLEDGE_NAME` | `在线知识空间0824145422` |
| 多步知识源名称 | `多步知识源` + MMDDHHmmss | `MULTI_CONTEXT_NAME` | `多步知识源0824145422` |
| 令牌名称 | `asdm-pat` + MMDDHHmmss | `PAT_NAME` | `asdm-pat0824145422` |

项目名称受平台 20 字符上限约束（超长会被输入框静默截断导致断言失败），故规则为
子组织名 + `-项目`（整 20 字符），不使用 `-项目01`（22 字符超限）。

固定数据不走创建规则，保持静态值：`TEST01_PASS` / `NEW_USER_PASS` = `admin@2026`、
`NEW_USER_ROLE` = `组织管理员`、`NEW_USER_LAST` = `测试`、`NEW_USER_FIRST` = `一`、
`WORKSPACE_TYPE` = `普通类`（012 实测选项文本，非用例原文"普通"）、
`WORKSPACE_DESC` = `好好工作`、`KNOWLEDGE_DESC` = `努力挣钱`、
016 固定配置（`CONTEXT_BUILD_MODE` = `单步自动化构建` / `CONTEXT_REPO_URL` /
`CONTEXT_AGENT` = `context-builder-8` / `CONTEXT_CMD` = `asdm-context-build`）、
024/025 固定选项（`ONLINE_WORKSPACE_TYPE` = `普通类`、`ONLINE_KNOWLEDGE_TYPE` = `在线`、
`MULTI_CONTEXT_BUILD_MODE` = `多步交互构建`）。
`AGENT_ORBIT_KEY`（018/022/023 共用）为外部凭据，留空由 run-all.sh 豁免，不参与刷新。

024/025 固定选项均经实跑核对（2026-08-27，差异记 test-plan §七）：024 类型下拉实际仅
CODE"代码类" / NORMAL"普通类"两个选项，无用例原文 [在线]（"在线"为组织 Agent 设置层
概念，非空间类型枚举），以"普通类"代跑；025 构建模式为 radio 单选组，实际选项文本为
"多步交互构建"（用例原文 [多步构建] 失配）。

020/021 组织引用走现存组织代跑：用例原文组织 "ASDM-Org" / "organization" 在当前平台
组织树不存在，`ASDM_ORG_NAME` / `ORG_CONFIG_NAME` = `ORG_NAME` 的值（本批 003 创建的
顶层组织，随主链同批刷新；平台创建对应组织后可用环境变量覆盖）。

## 二、依赖链对齐规则（处理流程正确性）

同一 `TEST_TS` 必须贯穿整条依赖链，下游变量值必须与上游产物**字面一致**
（写入静态值，不用变量引用）：

| 下游变量 | 必须等于 | 上游用例产物 |
| --- | --- | --- |
| `PARENT_ORG` | `ORG_NAME` 的值 | 003 创建的顶层组织 |
| `NEW_USER_ORG` | `SUB_ORG_NAME` 的值 | 004 创建的子组织 |
| `NEW_USER_EMAIL` | `TEST01_USER` 的值 | 005 创建的用户（010/011 登录账号） |
| `NEW_USER_PASS` | `TEST01_PASS` 的值 | 同上 |
| `ORG_NODE` | `SUB_ORG_NAME` 的值 | 010 项目所在组织节点 |
| `PROJECT_NAME` | `SUB_ORG_NAME` 的值 + `-项目` | 010 项目名 |

依赖链：`003 创建顶层组织 → 004 创建子组织 → 005 创建用户 → 010 创建项目 → 011 项目设置`
（024 在线智能体空间 / 025 在线知识空间 / 026 多步构建挂靠 010 项目，见下"挂链创建类"）。
任何一环时间戳不一致，后续用例都会因找不到上游数据（组织不存在 / 用户不存在 /
登录失败）而失败。

### 独立创建类用例（不在主链，同批刷新）

以下用例与主链无上下游引用，但同为创建类（不幂等），必须与主链**同一 TEST_TS**
刷新，防止上一批同名残留导致重名失败：

| 用例 | 创建类变量 | 创建规则 |
| --- | --- | --- |
| 006 生成 PAT | `PAT_NAME` | `asdm-pat` + MMDDHHmmss |
| 012 创建智能体空间 | `WORKSPACE_NAME` | `工作空间` + MMDDHHmmss |
| 015 新建知识空间 | `KNOWLEDGE_NAME` | `个人空间` + MMDDHHmmss |
| 016 添加知识源 | `CONTEXT_SOURCE_NAME` | `代码类仓库` + MMDDHHmmss |
| 022 创建个人数字分身 | `AVATAR_NAME` | `个人数字分身` + MMDDHHmmss |
| 023 数字分身创建成功 | `DIGITAL_AVATAR_NAME` | `数字分身` + MMDDHHmmss |

补充对齐：013 空间资源关联复用 009 上传的场景智能体资源（资源名 = `UPLOAD_FILE`
文件名，字面对齐）；018 AgentOrbit 连接配置与 022/023 数字分身共用
`AGENT_ORBIT_KEY`（外部凭据，留空则 run-all.sh 豁免 018/022/023，不参与刷新）；
020/021 组织 Agent 设置以现存顶层组织代跑（`ASDM_ORG_NAME` / `ORG_CONFIG_NAME` =
`ORG_NAME` 的值，随主链同批刷新，见 §一）。

### 挂链创建类用例（依赖 010 项目，同批刷新）

024/025 为创建类（不幂等）且引用主链产物（项目名 `$PROJECT_NAME`），必须与主链
**同一 TEST_TS** 刷新，否则找不到项目或重名失败；026 复用 025 的同名变量
（026 脚本内置幂等兜底，不独立创建）：

| 用例 | 创建类变量 | 创建规则 | 依赖 |
| --- | --- | --- | --- |
| 024 创建在线智能体空间 | `ONLINE_WORKSPACE_NAME` | `在线智能体空间` + MMDDHHmmss | 010 `$PROJECT_NAME` |
| 025 在线知识空间-多步构建 | `ONLINE_KNOWLEDGE_NAME`、`MULTI_CONTEXT_NAME` | `在线知识空间` / `多步知识源` + MMDDHHmmss | 010 `$PROJECT_NAME` |
| 026 多步构建-多文件MD生成 | （复用 025 同名变量） | 不重复创建 | 025 |

## 三、执行步骤（刷新数据）

**step 1：生成批次时间戳**

```bash
date +%m%d%H%M%S    # → TEST_TS，如 0824145422
```

（可选）用户指定了锁定批次时直接采用用户给定的 `TEST_TS` 值。

**step 2：按创建规则计算全部变量值**

以 `TEST_TS=0824145422` 为例：

```
TEST01_USER     = test0824145422@asdm.ai
ORG_NAME        = 测试组织0824145422
PARENT_ORG      = 测试组织0824145422
SUB_ORG_NAME    = 测试组织sub0824145422
NEW_USER_ORG    = 测试组织sub0824145422
NEW_USER_EMAIL  = test0824145422@asdm.ai
ORG_NODE        = 测试组织sub0824145422
PROJECT_NAME    = 测试组织sub0824145422-项目
WORKSPACE_NAME  = 工作空间0824145422
KNOWLEDGE_NAME  = 个人空间0824145422
CONTEXT_SOURCE_NAME = 代码类仓库0824145422
AVATAR_NAME     = 个人数字分身0824145422
DIGITAL_AVATAR_NAME = 数字分身0824145422
PAT_NAME        = asdm-pat0824145422
ASDM_ORG_NAME    = 测试组织0824145422
ORG_CONFIG_NAME  = 测试组织0824145422
ONLINE_WORKSPACE_NAME = 在线智能体空间0824145422
ONLINE_KNOWLEDGE_NAME = 在线知识空间0824145422
MULTI_CONTEXT_NAME = 多步知识源0824145422
```

令牌名称 `PAT_NAME` 不参与依赖链对齐（006 产出的令牌值本身写入 `data/pat.txt`，
007 从文件读取而非按名引用），但**必须随本批 TEST_TS 刷新**：平台对令牌名称
唯一性校验，同名创建返回 409，上一批残留同名令牌会导致 006 重跑失败。
（006 脚本已内置同名令牌清理作为兜底，见 `.asdm/workspace/replay-testcase/
replay_testcase/006_generate-pat.sh` §step 3.5）

**step 3：写入 `data/test-data.sh`**

- 按 §四 模板中「名称类数据」各行的**静态具体值**替换为 step 2 计算结果，
  保持 `: "${VAR:=值}"` 形式与环境变量优先级不变
- 固定数据、凭据、其余用例（007-009、011、013-014、019）数据一律不动
  （006 `PAT_NAME` / 023/024/025 的名称类变量属刷新对象；006 的 `PAT_EXPIRY`
  为固定选项值不参与刷新；023/024/025 的固定选项值如 `ONLINE_WORKSPACE_TYPE`、
  `MULTI_CONTEXT_BUILD_MODE` 不参与刷新，仅在平台选项文案变更时人工更新；
  020/021 的组织引用值 `ASDM_ORG_NAME` / `ORG_CONFIG_NAME` = `ORG_NAME`，随主链同批刷新）
- 文件头注释中的「最近刷新」记录更新为本批次时间戳与日期
- 纯名称类刷新（不增删变量）时文件尾部 `export` 清单保持不动；若本批**新增或调整
  定义变量**（如新增用例变量），必须同步加入该清单，保持「定义变量 = export 变量」
  一致——历史教训（2026-08-27）：`AGENT_ORBIT_KEY`（018/022/023 共用）此前定义但
  未 export，已补入 `AVATAR_NAME` 与 `DIGITAL_AVATAR_NAME` 之间

**step 4：验证**

```bash
bash -n data/test-data.sh                                    # 语法
bash -c 'source data/test-data.sh; \
  echo "$TEST01_USER / $ORG_NAME / $SUB_ORG_NAME / $NEW_USER_ORG / $ORG_NODE / $PROJECT_NAME"; \
  echo "$WORKSPACE_NAME / $KNOWLEDGE_NAME / $CONTEXT_SOURCE_NAME / $AVATAR_NAME"; \
  echo "$DIGITAL_AVATAR_NAME / $ONLINE_WORKSPACE_NAME / $ONLINE_KNOWLEDGE_NAME / $MULTI_CONTEXT_NAME"; \
  echo "$PAT_NAME / $ASDM_ORG_NAME / $ORG_CONFIG_NAME"'
# 预期：全部输出 step 2 计算的值，且 PARENT_ORG=ORG_NAME、NEW_USER_ORG=ORG_NODE=SUB_ORG_NAME、
#       NEW_USER_EMAIL=TEST01_USER、ASDM_ORG_NAME=ORG_CONFIG_NAME=ORG_NAME 字面一致；
#       012/015/016/022/023/024/025 时间戳与本批 TEST_TS 一致
# 可选：验证 export 清单与定义变量对齐（新增定义变量后必查，防止漏 export）：
#   diff <(grep -oE '^: "\$\{[A-Z_][A-Z0-9_]*:=' data/test-data.sh | sed -E 's/^: "\$\{//; s/:=$//' | sort -u) \
#        <(sed -n '/^export /,/MULTI_CONTEXT_NAME$/p' data/test-data.sh | tr -d '\\' | tr ' \t\n' '\n' | grep -E '^[A-Z_][A-Z0-9_]*$' | sort -u)
#   预期：无差异输出（定义 = export）
```

**step 5：报告**

向用户报告：本次 `TEST_TS`、被更新的变量清单、依赖链一致性结论。

## 四、目标文件模板（data/test-data.sh）

```bash
#!/bin/bash
# ============================================================================
# test-data.sh — ASDM 回放测试统一测试数据（静态实例）
# ============================================================================
# 【实例数据】本文件是 generate-test-data.md 刷新产出的静态数据快照，
#         不含运行时生成逻辑；需要新数据时执行
#         .asdm/toolsets/transfer/generate-test-data.md 重新刷新。
# 【最近刷新】TEST_TS=0824145422（2026-08-24）
# 【加载】测试脚本统一加载（common/common.sh 的 load_data_file）：
#         DATA_DIR="${SCRIPT_DIR}/../data"; load_data_file "${DATA_DIR}/test-data.sh"
#         （脚本在 replay_testcase/ 子目录，公共库在 common/，两者同级的 ../data 即本目录）
# 【优先级】环境变量 > 本文件（: "${VAR:=...}" 仅当变量未设置时才赋值）
# 【分节】公共配置 → 身份凭据 → 各用例业务数据（按用例编号）
# ============================================================================
```

名称类数据行模板（刷新对象）：

```bash
# test01（010-011 用例登录用，005 用例创建的用户）
# 创建规则：test + MMDDHHmmss + @asdm.ai
: "${TEST01_USER:=test0824145422@asdm.ai}"         # test01 邮箱

# ---------- 用例 003：创建顶层组织 ----------
# 创建规则：测试组织 + MMDDHHmmss
: "${ORG_NAME:=测试组织0824145422}"                 # 待创建的顶层组织名称

# ---------- 用例 004：创建子组织 ----------
# 创建规则：测试组织sub + MMDDHHmmss（PARENT_ORG 必须与 ORG_NAME 字面一致）
: "${PARENT_ORG:=测试组织0824145422}"               # 父组织名称（=用例003产物）
: "${SUB_ORG_NAME:=测试组织sub0824145422}"          # 待创建的子组织名称

# ---------- 用例 005：创建用户 ----------
: "${NEW_USER_ROLE:=组织管理员}"                    # 角色映射：角色
: "${NEW_USER_ORG:=测试组织sub0824145422}"          # 角色映射：组织（=用例004产物）
: "${NEW_USER_EMAIL:=test0824145422@asdm.ai}"      # 新用户邮箱（=TEST01_USER，010 用例登录复用）
: "${NEW_USER_PASS:=admin@2026}"                   # 新用户初始密码（=TEST01_PASS）

# ---------- 用例 006：生成 PAT ----------
# 创建规则：asdm-pat + MMDDHHmmss（创建类不幂等，带批次时间戳防重名）
# 【平台约束】名称输入框 maxlength=64；平台对令牌名称唯一性校验，
#            同名创建返回 409（脚本内置同名清理，见 006 脚本 §step 3.5）
: "${PAT_NAME:=asdm-pat0824145422}"                # 令牌名称

# ---------- 用例 010：创建项目 ----------
: "${ORG_NODE:=测试组织sub0824145422}"              # 目标组织节点（=用例004产物）
: "${PROJECT_NAME:=测试组织sub0824145422-项目}"     # 项目名称（=组织节点名 + -项目，≤20 字符）

# ---------- 用例 012：创建智能体空间 ----------
# 创建规则：工作空间 + MMDDHHmmss（创建类不幂等，带批次时间戳防重名）
: "${WORKSPACE_NAME:=工作空间0824145422}"

# ---------- 用例 015：新建知识空间 ----------
# 创建规则：个人空间 + MMDDHHmmss（创建类不幂等，带批次时间戳防重名）
: "${KNOWLEDGE_NAME:=个人空间0824145422}"

# ---------- 用例 016：添加知识源 ----------
# 创建规则：代码类仓库 + MMDDHHmmss（创建类不幂等，带批次时间戳防重名）
: "${CONTEXT_SOURCE_NAME:=代码类仓库0824145422}"

# ---------- 用例 020：ASDM-Org Agent 设置（现存组织代跑） ----------
# 用例原文组织 "ASDM-Org" 当前平台不存在，以本批顶层组织代跑（=ORG_NAME 值）
: "${ASDM_ORG_NAME:=测试组织0824145422}"

# ---------- 用例 021：organization Agent 配置（现存组织代跑） ----------
# 同 020，以本批顶层组织代跑（=ORG_NAME 值）
: "${ORG_CONFIG_NAME:=测试组织0824145422}"

# ---------- 用例 022：创建个人数字分身 ----------
# 创建规则：个人数字分身 + MMDDHHmmss（创建类不幂等，带批次时间戳防重名）
: "${AVATAR_NAME:=个人数字分身0824145422}"

# ---------- 用例 023：数字分身创建成功 ----------
# 创建规则：数字分身 + MMDDHHmmss（创建类不幂等，带批次时间戳防重名；
# 与 022 的 AVATAR_NAME 区分为两个分身）
: "${DIGITAL_AVATAR_NAME:=数字分身0824145422}"

# ---------- 用例 024：创建在线智能体空间（挂链 010 项目） ----------
# 创建规则：在线智能体空间 + MMDDHHmmss（创建类不幂等，带批次时间戳防重名）
: "${ONLINE_WORKSPACE_NAME:=在线智能体空间0824145422}"

# ---------- 用例 025/026：在线知识空间与多步构建（挂链 010 项目） ----------
# 创建规则：在线知识空间 / 多步知识源 + MMDDHHmmss（创建类不幂等，防重名；
# 026 复用 025 的同名变量字面进入，不重复创建）
: "${ONLINE_KNOWLEDGE_NAME:=在线知识空间0824145422}"
: "${MULTI_CONTEXT_NAME:=多步知识源0824145422}"
```

### 文件尾部 export 清单（维护规则）

`test-data.sh` 尾部 `export` 块导出**全部统一测试数据**（名称类 + 固定数据 + 凭据，
含 `AGENT_ORBIT_KEY`，位于 `AVATAR_NAME` 与 `DIGITAL_AVATAR_NAME` 之间）。规则：

- **新增定义变量时必须同步加入 export 清单**，保持「定义变量 = export 变量」一致
  （历史遗漏：`AGENT_ORBIT_KEY` 定义但未 export，已于 2026-08-27 补齐）
- 纯名称类刷新（不增删变量）时 export 块保持不动
- 对齐验证见 §三 step 4 可选命令

## 五、刷新时机

- **每批新回放前刷新一次**：上一批已在平台留下同名组织/用户/项目/空间（含在线
  智能体空间）/知识空间（含在线知识空间）/知识源/分身时，不刷新重跑会因重名失败
  （组织已存在 / 邮箱已注册 / 名称重复）
- **同一批回放内禁止刷新**：003 已按旧数据创建组织后再刷新，004 起引用的就是
  平台上不存在的新数据，依赖链断裂
- 断点续跑 / 回放历史批次：**不刷新**，保持文件中既有实例数据

## 已知限制

- 每批回放都会在平台上留下带时间戳的 用户/组织/项目/空间/知识空间/知识源/分身
  （含 023 数字分身、024 在线空间、025 在线知识空间与多步知识源，不自动清理），需定期清理
- `TEST_TS` 精度为秒：同一秒内刷新两批会撞名，禁止并发执行
- 修改创建规则（命名格式）须同步更新本文件 §一/§二/§四 模板
- `data/test-data.sh` 含明文凭据，禁止提交版本库（`chmod 600`，同 §directory-structure-spc）
