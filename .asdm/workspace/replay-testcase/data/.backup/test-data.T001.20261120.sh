#!/bin/bash
# ============================================================================
# test-data.sh — ASDM 回放测试统一测试数据（静态实例）
# ============================================================================
# 【实例数据】本文件是 generate-test-data.md 生成产出的静态数据快照，
#         不含运行时生成逻辑；需要新数据时（换批次号）执行
#         .asdm/toolsets/ui-auto-testing/actions/generate-test-data.md 重新生成
#         （按登记表"赋值规则"列对全部定义域变量整体重写）。
# 【数据批次】BATCH_ID=T001（2026-11-06）
# 【加载】测试脚本统一加载（common/common.sh 的 load_data_file）：
#         DATA_DIR="${SCRIPT_DIR}/../data"; load_data_file "${DATA_DIR}/test-data.sh"
#         （脚本在 replay_testcase/ 子目录，公共库在 common/，两者同级的 ../data 即本目录）
# 【优先级】环境变量 > 本文件（: "${VAR:=...}" 仅当变量未设置时才赋值）
# 【分节】公共配置 → 身份凭据 → 各用例业务数据（按用例编号）
# 【裁剪记录 2026-11-20】现役脚本集为 001~005 五个脚本，本文件与登记表同步裁剪：
#         仅保留 5 脚本关联变量（require_vars 直接消费 + common.sh 消费 +
#         ref 链目标锚点）共 15 个；006~099 用例相关 44 个变量已随登记表条目
#         一并移除。后续用例脚本恢复时按 testcase-to-sh.md §五
#         "提取 → 登记 → 追加"三步走重新登记并入。
# ============================================================================

# ---------- 公共配置（所有用例共享） ----------
# 初始值(用例输入): https://asdm-sit.leansoftx.com/（001 原文）  赋值规则: fixed:https://asdm-dt01.leansoftx.com/（sit→dt01 环境迁移，规则显式当前值防求值回退）
: "${BASE_URL:=https://asdm-dt01.leansoftx.com/}"   # 平台首页地址
# 初始值(用例输入): （缺）（公共配置无用例原文）  赋值规则: fixed:1
: "${HEADED:=1}"                                   # 1=显示浏览器窗口，0=无头模式

# ---------- 身份凭据 ----------
# 超级管理员（001~005 现役全部用例登录用）
# 初始值(用例输入): super-admin@asdm.ai（001 原文）  赋值规则: env:super-admin@（非占位态原样保留）
: "${ASDM_USER:=super-admin@asdm.ai}"              # 超级管理员邮箱
# 初始值(用例输入): superadmin@20260214（001 原文）  赋值规则: env:superadmin@（非占位态原样保留）
: "${ASDM_PASS:=superadmin@20260214}"              # 超级管理员密码
# test01（005 用例创建的用户；NEW_USER_EMAIL/NEW_USER_PASS 的 ref 目标锚点，
# 010/011 脚本恢复后登录复用）
# 初始值(用例输入): test01@asdm.ai（005 原文）  赋值规则: （空，批次兜底：批次号_USER+序号01）
: "${TEST01_USER:=T001_USER01@asdm.ai}"            # test01 邮箱
# 初始值(用例输入): admin@2026（005"初始密码"原文）  赋值规则: fixed:admin@2026
: "${TEST01_PASS:=admin@2026}"                     # test01 密码

# ---------- 用例 003：创建顶层组织 ----------
# 初始值(用例输入): 测试组织01（003 原文）  赋值规则: （空，批次兜底：批次号_组织+序号01）
: "${ORG_NAME:=T001_组织01}"                       # 待创建的顶层组织名称

# ---------- 用例 004：创建子组织 ----------
# 初始值(用例输入): 测试组织01（004 前置引用原文）  赋值规则: ref:ORG_NAME（003 产物）
: "${PARENT_ORG:=T001_组织01}"                     # 父组织名称（=用例003产物）
# 初始值(用例输入): 测试组织0101（004 原文）  赋值规则: （空，批次兜底：批次号_组织+序号02）
: "${SUB_ORG_NAME:=T001_组织02}"                   # 待创建的子组织名称

# ---------- 用例 005：创建用户 ----------
# 初始值(用例输入): 组织管理员（005 下拉原文）  赋值规则: fixed:组织管理员
: "${NEW_USER_ROLE:=组织管理员}"                    # 角色映射：角色
# 初始值(用例输入): 测试组织01（005 原文）  赋值规则: ref:SUB_ORG_NAME（批次对齐决断：004 产物）
: "${NEW_USER_ORG:=T001_组织02}"                   # 角色映射：组织（=用例004产物，引用组织02）
# 初始值(用例输入): test01@asdm.ai（005 同一输入）  赋值规则: ref:TEST01_USER
: "${NEW_USER_EMAIL:=T001_USER01@asdm.ai}"         # 新用户邮箱（=TEST01_USER）
# 初始值(用例输入): admin@2026（005 同一输入）  赋值规则: ref:TEST01_PASS
: "${NEW_USER_PASS:=admin@2026}"                   # 新用户初始密码（=TEST01_PASS）
# 初始值(用例输入): 测试（005 原文）  赋值规则: fixed:测试
: "${NEW_USER_LAST:=测试}"                          # 新用户姓
# 初始值(用例输入): 一（005 原文）  赋值规则: fixed:一
: "${NEW_USER_FIRST:=一}"                           # 新用户名

export BASE_URL HEADED \
       ASDM_USER ASDM_PASS TEST01_USER TEST01_PASS \
       ORG_NAME PARENT_ORG SUB_ORG_NAME \
       NEW_USER_ROLE NEW_USER_ORG NEW_USER_EMAIL NEW_USER_PASS NEW_USER_LAST NEW_USER_FIRST
