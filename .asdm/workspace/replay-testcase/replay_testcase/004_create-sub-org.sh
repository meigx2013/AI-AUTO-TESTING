#!/bin/bash
# 由 004_create-sub-org.md 翻译而来（测试用例 markdown → agent-browser）
#
# 通用操作已抽取至 common.sh（快照 ref 驱动），本脚本仅保留用例业务步骤：
#   管理后台 → 平台级设置 → 组织 → 父组织行 ... → 创建子组织
#
# 前置条件（登录自愈；业务数据缺失即报错并指引）：
#   1. 登录态：goto_admin_console 内置 login 自愈（未登录自动登录、
#      身份不符自动退出换号），可独立执行，无需先跑 001
#   2. 已创建父组织 "$PARENT_ORG"（先执行 replay_testcase/003_create-org.sh；
#      缺失时 step 4 报错并给出指引）
#
# 运行：bash replay_testcase/004_create-sub-org.sh（默认显示浏览器窗口）
# 如需无头模式：HEADED=0 bash replay_testcase/004_create-sub-org.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/../common/common.sh"

# 统一测试数据：data/test-data.sh（含全部用例数据，环境变量优先）
DATA_DIR="${SCRIPT_DIR}/../data"
load_data_file "${DATA_DIR}/test-data.sh"


ab_init
require_vars ASDM_USER ASDM_PASS PARENT_ORG SUB_ORG_NAME

# ---------- 操作步骤 ----------

# step 1: 用户进入 ASDM管理后台 首页
goto_admin_console

# step 2: 点击左下角 [平台级设置] 按钮
echo "[step 2] 进入 [平台级设置]"
goto_platform_settings

# step 3: 点击 [组织] Tab页签（精确匹配优先）
echo "[step 3] 点击 [组织] Tab页签"
click_tab '组织'

# step 4: 点击父组织 "$PARENT_ORG" 行内的 [...] 操作按钮，展开操作菜单
echo "[step 4] 点击父组织行内 [...] 按钮"
ref=$(snapshot_line_after "$PARENT_ORG" 'button') \
    || { echo "  [失败] 未找到父组织行内操作按钮: $PARENT_ORG" >&2
         echo "         若父组织尚未创建，请先执行: bash ${SCRIPT_DIR}/replay_testcase/003_create-org.sh" >&2
         exit 1; }
agent-browser click "@${ref}" >/dev/null
ab_wait 500

# step 5: 在弹出的操作菜单中点击 [创建子组织]
echo "[step 5] 点击 [创建子组织]"
click_by_text '创建子组织' '创建子组织菜单项'
assert_visible '创建子组织' '[创建子组织] 弹窗出现'

# step 6: [创建子组织] 信息录入 —— 子组织名称
echo "[step 6] 录入子组织名称: $SUB_ORG_NAME"
fill_by_label '组织名称' "$SUB_ORG_NAME" '子组织名称输入框'

# step 7: 点击 [创建] 按钮，保存后刷新列表
echo "[step 7] 点击 [创建]"
click_by_exact '创建' '创建按钮'
ab_wait 2000
agent-browser reload >/dev/null 2>&1
ab_wait 2000

# ---------- 预期结果断言 ----------

# 预期结果 1: 组织层级树中出现子组织 "$SUB_ORG_NAME"
echo "[断言] 组织树中出现子组织: $SUB_ORG_NAME"
expand_all_tree
wait_for_text "$SUB_ORG_NAME" 8 1
assert_snapshot_contains "$SUB_ORG_NAME" "组织树中出现 $SUB_ORG_NAME"

# ---------- 收尾（§8.3） ----------
finish
