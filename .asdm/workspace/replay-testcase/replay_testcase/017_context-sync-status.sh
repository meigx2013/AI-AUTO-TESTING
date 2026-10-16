#!/bin/bash
# 由 017_context-sync-status.md 翻译而来（测试用例 markdown → agent-browser）
#
# 通用操作已抽取至 common.sh（快照 ref 驱动），本脚本仅保留用例业务步骤：
#   test01 登录 → 项目 → 资源库 → 知识空间 → 同步状态 → 触发同步 → 新增同步记录
#
# 前置条件（不自动级联，缺失即报错）：
#   1. 用户 test01@asdm.ai 已完成系统登录
#   2. 项目 "$PROJECT_NAME" 已创建（先执行 replay_testcase/010_create-project.sh）
#   3. 知识空间 "$KNOWLEDGE_NAME" 已创建（先执行 replay_testcase/015_create-context.sh）
#   4. 知识空间已配置知识源（先执行 replay_testcase/016_context-items.sh，
#      无知识源时触发同步无对象，可能失败）
#
# 运行：bash replay_testcase/017_context-sync-status.sh（默认显示浏览器窗口）
# 如需无头模式：HEADED=0 bash replay_testcase/017_context-sync-status.sh
#
# 翻译决断：
#   1. 用例原文项目名/空间名与 test-data.sh 批次数据不一致，统一使用
#      $PROJECT_NAME / $KNOWLEDGE_NAME（差异记入 test-plan §七）
#   2. "点击 [知识空间]名称" 决断为点击 015 创建的知识空间名称（同步状态挂在
#      具体空间下；依赖 015/016 先执行）
#   3. 预期"同步状态列表新增一条记录"：新记录特征文本（状态值）由翻译者按
#      平台常见同步状态文案编写轮询模式（同步中/排队/成功/失败任一命中即视为
#      已生成记录，§7.3），不来自用例原文

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
require_vars ASDM_USER ASDM_PASS ORG_NODE PROJECT_NAME KNOWLEDGE_NAME

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
# 资源库默认展示 [场景智能体] 子页，知识空间列表需先点击
# [知识空间] 子导航，否则 step 4 找不到知识空间
echo "[step 3] 点击 [知识空间] 子导航"
click_by_exact '知识空间' '知识空间子导航'
ab_wait 1000

# step 4: 点击知识空间 "$KNOWLEDGE_NAME"（015 创建），进入 [概览]
echo "[step 4] 点击知识空间: $KNOWLEDGE_NAME"
click_by_text "$KNOWLEDGE_NAME" '知识空间名称'
ab_wait 1500
assert_snapshot_contains '概览' '知识空间 [概览] 页面出现'

# step 5: 点击 [同步状态] 按钮，进入同步状态页面
echo "[step 5] 点击 [同步状态]"
click_by_exact '同步状态' '同步状态导航'
ab_wait 1000
assert_visible '同步状态' '[同步状态] 页面出现'

# step 6: 点击 [触发同步] 按钮
echo "[step 6] 点击 [触发同步]"
click_by_text '触发同步' '触发同步按钮'
ab_wait 1000

# ---------- 预期结果断言 ----------

# 预期结果 1: 同步状态列表页面新增一条记录（异步轮询，§7.3：
# 同步状态记录出现任一状态文案即视为已生成）
echo "[断言] 同步状态列表新增记录"
ok=""
for ((i = 0; i < 30; i++)); do
    snap=$(snap_i)
    case "$snap" in
        *'同步中'*|*'排队'*|*'同步成功'*|*'同步失败'*|*'执行中'*) ok=1; break;;
    esac
    sleep 1
done
if [ -n "$ok" ]; then
    echo "  [断言通过] 同步状态列表已生成同步记录"
else
    echo "  [断言失败] 同步状态列表未见新增记录" >&2
    WARN=$((WARN+1))
fi

# ---------- 收尾 ----------
finish
