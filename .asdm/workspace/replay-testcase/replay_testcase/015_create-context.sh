#!/bin/bash
# 由 015_create-context.md 翻译而来（测试用例 markdown → agent-browser）
#
# 通用操作已抽取至 common.sh（快照 ref 驱动），本脚本仅保留用例业务步骤：
#   test01 登录 → 项目 → 资源库 → 知识空间 → 新建知识空间（个人空间）→ 进入概览
#
# 前置条件（不自动级联，缺失即报错）：
#   1. 用户 test01@asdm.ai 已完成系统登录
#   2. 项目 "$PROJECT_NAME" 已创建（先执行 replay_testcase/010_create-project.sh）
#
# 运行：bash replay_testcase/015_create-context.sh（默认显示浏览器窗口）
# 如需无头模式：HEADED=0 bash replay_testcase/015_create-context.sh
#
# 翻译决断：
#   1. 用例原文项目名与 test-data.sh 批次数据不一致，统一使用 $PROJECT_NAME
#      （差异记入 test-plan §七）
#   2. 用例步骤 2 省略了组织导航，按 010 已实测验证路径展开：
#      [组织与项目] → 组织树节点 "$ORG_NODE" → 点击项目名称
#   3. 步骤 4 "点击 [知识空间]名称"：本用例创建前知识空间尚不存在，决断为
#      点击 [知识空间] 导航入口（进入知识空间列表页）；016/017 中同名步骤
#      则决断为点击本用例创建的 "$KNOWLEDGE_NAME"（进入具体空间）
#   4. 名称 "个人空间" 为创建类数据（不幂等），按 §5.2 带批次时间戳后缀防重名

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/../common/common.sh"

# 统一测试数据：data/test-data.sh（含全部用例数据，环境变量优先）
DATA_DIR="${SCRIPT_DIR}/../data"
load_data_file "${DATA_DIR}/test-data.sh"


ab_init
# 本用例以 test01 身份登录（公共凭据为超级管理员，此处切换；可用 TEST01_USER/TEST01_PASS 覆盖）
ASDM_USER="${TEST01_USER:-test01@asdm.ai}"
ASDM_PASS="${TEST01_PASS:-admin@2026}"
require_vars ASDM_USER ASDM_PASS ORG_NODE PROJECT_NAME KNOWLEDGE_NAME KNOWLEDGE_DESC

# ---------- 操作步骤 ----------

# step 1: test01 登录 → 管理后台 → 组织与项目 → 组织节点 → 项目页面
echo "[step 1] test01 登录"
login
goto_admin_console
goto_org_project
click_tree_node "$ORG_NODE" || exit 1
echo "[step 1] 点击项目: $PROJECT_NAME"
click_by_text "$PROJECT_NAME" '项目名称'
ab_wait 1500

# step 2: 右侧工作区打开 [资源库] 页面
echo "[step 2] 打开 [资源库] 页面"
click_by_text '资源库' '资源库导航'
ab_wait 1000

# step 3: 点击 [知识空间] 导航入口（创建前无具体空间可点）
# 精确匹配优先：避免"知识空间"作为 [新建知识空间] 按钮的子串被误点
echo "[step 3] 点击 [知识空间] 入口"
click_by_exact '知识空间' '知识空间导航'
ab_wait 1500

# step 4: 点击 [新建知识空间] 按钮
echo "[step 4] 点击 [新建知识空间]"
click_by_text '新建知识空间' '新建知识空间按钮'
assert_visible '新建知识空间' '[新建知识空间] 窗口出现'

# step 5: [新建知识空间] 信息录入 —— 名称 / 描述
echo "[step 5] 信息录入: 名称=$KNOWLEDGE_NAME"
fill_by_any_label "$KNOWLEDGE_NAME" '名称'
fill_by_any_label "$KNOWLEDGE_DESC" '描述'

# step 6: 点击 [创建] 按钮，进入概览页面
# （"创建"为"创建知识空间"等按钮文本的前缀风险低，精确优先 + 子串退化兜底）
echo "[step 6] 点击 [创建]"
click_by_exact '创建' '创建按钮'
ab_wait 2000

# ---------- 预期结果断言 ----------

# 预期结果 1: 知识空间列表页面新增一条记录（创建成功进入概览页，轮询 + 软断言）
echo "[断言] 知识空间出现: $KNOWLEDGE_NAME"
wait_for_text "$KNOWLEDGE_NAME" 10 || true
assert_snapshot_contains "$KNOWLEDGE_NAME" "知识空间 $KNOWLEDGE_NAME 已创建"

# ---------- 收尾 ----------
finish
