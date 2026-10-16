#!/bin/bash
# ============================================================================
# test-data.sh — ASDM 回放测试统一测试数据（静态实例）
# ============================================================================
# 【实例数据】本文件是 generate-test-data.md 刷新产出的静态数据快照，
#         不含运行时生成逻辑；需要新数据时执行
#         .asdm/toolsets/transfer/generate-test-data.md 重新刷新。
# 【数据批次】TEST_TS=0907152255（2026-09-07）
# 【加载】测试脚本统一加载（common/common.sh 的 load_data_file）：
#         DATA_DIR="${SCRIPT_DIR}/../data"; load_data_file "${DATA_DIR}/test-data.sh"
#         （脚本在 replay_testcase/ 子目录，公共库在 common/，两者同级的 ../data 即本目录）
# 【优先级】环境变量 > 本文件（: "${VAR:=...}" 仅当变量未设置时才赋值）
# 【分节】公共配置 → 身份凭据 → 各用例业务数据（按用例编号）
# ============================================================================

# ---------- 公共配置（所有用例共享） ----------
: "${BASE_URL:=https://platform-sit01.asdm.ai/}"   # 平台首页地址
: "${HEADED:=1}"                                   # 1=显示浏览器窗口，0=无头模式

# ---------- 身份凭据 ----------
# 超级管理员（001-009、012 用例登录用）
: "${ASDM_USER:=super-admin@asdm.ai}"              # 超级管理员邮箱
: "${ASDM_PASS:=superadmin@20260214}"              # 超级管理员密码
# test01（010-011 用例登录用，005 用例创建的用户）
# 创建规则：test + MMDDHHmmss + @asdm.ai
: "${TEST01_USER:=test0907152255@asdm.ai}"         # test01 邮箱
: "${TEST01_PASS:=admin@2026}"                     # test01 密码

# ---------- 用例 003：创建顶层组织 ----------
# 创建规则：测试组织 + MMDDHHmmss
: "${ORG_NAME:=测试组织0907152255}"                 # 待创建的顶层组织名称

# ---------- 用例 004：创建子组织 ----------
# 创建规则：测试组织sub + MMDDHHmmss（PARENT_ORG 必须与 ORG_NAME 字面一致）
: "${PARENT_ORG:=测试组织0907152255}"               # 父组织名称（=用例003产物）
: "${SUB_ORG_NAME:=测试组织sub0907152255}"          # 待创建的子组织名称

# ---------- 用例 005：创建用户 ----------
: "${NEW_USER_ROLE:=组织管理员}"                    # 角色映射：角色
: "${NEW_USER_ORG:=测试组织sub0907152255}"          # 角色映射：组织（=用例004产物）
: "${NEW_USER_EMAIL:=test0907152255@asdm.ai}"      # 新用户邮箱（=TEST01_USER，010 用例登录复用）
: "${NEW_USER_PASS:=admin@2026}"                   # 新用户初始密码（=TEST01_PASS，010 用例登录复用）
: "${NEW_USER_LAST:=测试}"                          # 新用户姓
: "${NEW_USER_FIRST:=一}"                           # 新用户名

# ---------- 用例 006：生成 PAT ----------
# 创建规则：asdm-pat + MMDDHHmmss（创建类不幂等，带批次时间戳防重名）
# 【平台约束】名称输入框 maxlength=64；平台对令牌名称唯一性校验，
#            同名创建返回 409（脚本内置同名清理，见 006 脚本 §step 3.5）
: "${PAT_NAME:=asdm-pat0907152255}"                # 令牌名称
: "${PAT_EXPIRY:=30 天}"                          # 令牌有效期（选项文本带空格）

# ---------- 用例 007：流水线配置 ----------
# Jenkins sit 环境账号/地址：登录凭证与 JENKINS_CRED 一致
: "${JENKINS_URL:=https://platform-sit01.asdm.ai/_jenkins}"   # Jenkins 地址（sit）
: "${JENKINS_USER:=admin}"                                    # Jenkins 登录账号
: "${JENKINS_PASS:=AsdmJenkins2025}"                          # Jenkins 登录密码
: "${PIPELINE_NAME:=pipeline}"                     # 流水线配置名称
: "${JENKINS_CRED:=admin:11f054f0964f8cb86a627b296929b9df59}"   # Jenkins 凭证
# ASDM API PAT 不在此硬编码：由脚本从 data/pat.txt（006 用例产出）读取，或传入 PAT=...

# ---------- 用例 008：特性开关 ----------
# 待处理的特性开关列表（空格分隔）
: "${FEATURE_FLAGS:=hide_admin_resource_management minio_storage_enabled hide_mcp_management}"
: "${FLAG_STATUS:=全量开放}"                        # 目标状态

# ---------- 用例 009：资源管理 ----------
: "${RES_SCOPE:=全局}"                              # 上传范围
: "${RES_TYPE:=场景智能体}"                         # 资源类型
: "${RES_CATEGORY:=上下文管理}"                     # 分类
# 待上传文件绝对路径（用例原文为 Windows 路径 D:\TEST01\toolset，回放环境不可用，
# 默认指向 data/ 下生成的场景智能体示例包，可用 UPLOAD_FILE=... 覆盖）
: "${UPLOAD_FILE:=${DATA_DIR}/context-builder-8.zip}"

# ---------- 用例 010：创建项目 ----------
: "${ORG_NODE:=测试组织sub0907152255}"              # 目标组织节点（=用例004产物）
# 项目名称：平台限制最大 20 字符（超出会被输入框静默截断导致断言失败）。
# 本批次实际创建的项目名为截断后的 20 字符值（原规则 ORG_NODE+"-项目01" 生成 22 字符超限）。
: "${PROJECT_NAME:=测试组织sub0907152255-项目}"     # 项目名称（≤20 字符）

# ---------- 用例 011：项目配置 ----------
: "${REPO_URL:=https://github.com/meigx2013/Ai-Fast}"       # 仓库 URL
: "${REPO_BRANCH:=develop}"                                 # 仓库分支
# GitHub Token：用例原文为占位符 ghp_xxx，必须覆盖为真实 Token（test-data.sh 或 GH_TOKEN=...）
: "${REPO_NAME:=meigx2013/Ai-Fast}"                    # 仓库名称/路径
: "${GH_TOKEN:=ghp_xxx}"   # GitHub Token（占位符：执行前用 GH_TOKEN=... 环境变量注入真实值，勿提交真实 Token）

# ---------- 用例 012：创建智能体空间（批次 0827084804 增补） ----------
# 创建规则：工作空间 + MMDDHHmmss（创建类不幂等，带批次时间戳防重名）
: "${WORKSPACE_NAME:=工作空间0907152255}"
: "${WORKSPACE_TYPE:=普通类}"
: "${WORKSPACE_DESC:=好好工作}"

# ---------- 用例 013：智能体空间资源关联 ----------
# 关联目标 = 009 上传的场景智能体资源（资源名 = UPLOAD_FILE 文件名，字面对齐）
# 无新增变量，复用 UPLOAD_FILE

# ---------- 用例 014：触发空间运行 ----------
: "${RUN_PROMPT:=生成README.md到 .workspace 目录下。}"

# ---------- 用例 015：新建知识空间（批次 0827084804 增补） ----------
# 创建规则：个人空间 + MMDDHHmmss（创建类不幂等，带批次时间戳防重名）
: "${KNOWLEDGE_NAME:=个人空间0907152255}"
: "${KNOWLEDGE_DESC:=努力挣钱}"

# ---------- 用例 016：添加知识源（批次 0827084804 增补） ----------
# 知识源名称为创建类数据，带批次时间戳防重名
# 场景智能体下拉选项文本 = "资源名 (版本)"格式（版本号浮动）——按资源名前缀匹配
# 场景智能体须与 009 实际上传的 UPLOAD_FILE 字面对齐；命令 = asdm-context-build
# （该包 actions/asdm-context-build.md，与用例原文一致）
: "${CONTEXT_BUILD_MODE:=单步自动化构建}"
: "${CONTEXT_SOURCE_NAME:=代码类仓库0907152255}"
: "${CONTEXT_REPO_URL:=https://github.com/meigx2013/asdm-core-assets-mcp}"
: "${CONTEXT_AGENT:=context-builder-8.zip}"
: "${CONTEXT_CMD:=asdm-context-build}"

# ---------- 用例 019：hide_digidev_icon 特性开关 ----------
: "${HIDE_DIGIDEV_FLAG:=hide_digidev_icon}"          # 目标特性开关（状态复用 FLAG_STATUS）

# ---------- 用例 020：ASDM-Org Agent 设置（现存组织代跑） ----------
# 用例原文组织 "ASDM-Org" 在当前平台不存在，以本批顶层组织代跑（=ORG_NAME 值）；
# 平台创建 ASDM-Org 后可 ASDM_ORG_NAME=ASDM-Org 覆盖
: "${ASDM_ORG_NAME:=测试组织0907152255}"

# ---------- 用例 021：organization Agent 配置 ----------
# 同 020："organization"/"AI开发运维板块" 均不在当前平台组织树，
# 以现存顶层组织代跑验证流程；平台创建 organization 后可覆盖
: "${ORG_CONFIG_NAME:=测试组织0907152255}"

# ---------- 用例 022：创建个人数字分身（批次 0827084804 增补） ----------
# 创建规则：个人数字分身 + MMDDHHmmss（创建类不幂等，带批次时间戳防重名）
: "${AVATAR_NAME:=个人数字分身0907152255}"
# AgentOrbit 连接密钥（外部凭据类，§5.1）：数字分身为 AgentOrbit 在线能力，
# 未配置时 [创建新分身] 按钮禁用——留空则 run-all.sh 豁免 022（§九）；
# 平台级设置 → AgentOrbit 页签配置密钥并保存后，可将密钥写入此变量解除豁免
: "${AGENT_ORBIT_KEY:=4dd99ff9-5b0c-4742-87a1-228760dd96de}"

# ---------- 用例 018：AgentOrbit 连接配置（批次 0827092838 增补） ----------
# 无新增变量：连接密钥复用 022 的 AGENT_ORBIT_KEY（外部凭据类，§5.1）——
# 018 配置写入密钥并保存后，022/023 的豁免即可同步解除（同一变量对齐链）

# ---------- 用例 023：数字分身创建成功（批次 0827092838 增补） ----------
# 创建规则：数字分身 + MMDDHHmmss（创建类不幂等，带批次时间戳防重名；
# 与 022 的 AVATAR_NAME 区分为两个分身）
: "${DIGITAL_AVATAR_NAME:=数字分身0907152255}"

# ---------- 用例 024：创建在线智能体空间（批次 0827092838 增补） ----------
# 创建规则：在线智能体空间 + MMDDHHmmss（创建类不幂等，带批次时间戳防重名）
: "${ONLINE_WORKSPACE_NAME:=在线智能体空间0907152255}"
# 类型下拉实际选项仅 CODE"代码类" / NORMAL"普通类"——用例原文 [在线] 选项
# 不存在（"在线"为组织 Agent 设置层的功能概念，非空间类型枚举）；以"普通类"
# 代跑验证创建流程（差异记入 test-plan §七）
: "${ONLINE_WORKSPACE_TYPE:=普通类}"

# ---------- 用例 025/026：在线知识空间与多步构建（批次 0827092838 增补） ----------
# 创建规则：在线知识空间 / 多步知识源 + MMDDHHmmss（创建类不幂等，防重名；
# 026 复用 025 的同名字面数据进入，不重复创建）
# 构建模式为 radio 单选组，实际选项文本为"多步交互构建"（用例原文 [多步构建]，
# 差异记录 test-plan §七）
: "${ONLINE_KNOWLEDGE_NAME:=在线知识空间0907152255}"
: "${ONLINE_KNOWLEDGE_TYPE:=在线}"
: "${MULTI_CONTEXT_BUILD_MODE:=多步交互构建}"
: "${MULTI_CONTEXT_NAME:=多步知识源0907152255}"

# ---------- 用例 099：效能洞察 ----------
# 项目管理员凭据（外部凭据类，§5.1）：未配置时脚本内置豁免逻辑跳过验证；
# 创建项目管理员用户后可将邮箱/密码写入此变量解除豁免
: "${PROJECT_ADMIN_USER:=}"                        # 项目管理员邮箱（占位，环境变量覆盖）
: "${PROJECT_ADMIN_PASS:=}"                        # 项目管理员密码（占位，环境变量覆盖）

export BASE_URL HEADED \
       ASDM_USER ASDM_PASS TEST01_USER TEST01_PASS \
       ORG_NAME PARENT_ORG SUB_ORG_NAME \
       NEW_USER_ROLE NEW_USER_ORG NEW_USER_EMAIL NEW_USER_PASS NEW_USER_LAST NEW_USER_FIRST \
       PAT_NAME PAT_EXPIRY \
       JENKINS_URL JENKINS_USER JENKINS_PASS \
       PIPELINE_NAME JENKINS_CRED \
       FEATURE_FLAGS FLAG_STATUS \
       RES_SCOPE RES_TYPE RES_CATEGORY UPLOAD_FILE \
       ORG_NODE PROJECT_NAME \
       REPO_URL REPO_NAME REPO_BRANCH GH_TOKEN \
       WORKSPACE_NAME WORKSPACE_TYPE WORKSPACE_DESC \
       RUN_PROMPT \
       KNOWLEDGE_NAME KNOWLEDGE_DESC \
       CONTEXT_BUILD_MODE CONTEXT_SOURCE_NAME CONTEXT_REPO_URL CONTEXT_AGENT CONTEXT_CMD \
       HIDE_DIGIDEV_FLAG \
       ASDM_ORG_NAME \
       ORG_CONFIG_NAME \
       AVATAR_NAME \
       AGENT_ORBIT_KEY \
       DIGITAL_AVATAR_NAME \
       ONLINE_WORKSPACE_NAME ONLINE_WORKSPACE_TYPE \
       ONLINE_KNOWLEDGE_NAME ONLINE_KNOWLEDGE_TYPE \
       MULTI_CONTEXT_BUILD_MODE MULTI_CONTEXT_NAME \
       PROJECT_ADMIN_USER PROJECT_ADMIN_PASS
