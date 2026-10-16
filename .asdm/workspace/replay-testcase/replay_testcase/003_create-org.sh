#!/bin/bash
# 由 003_create-org.md 翻译而来（测试用例 markdown → agent-browser）
#
# 通用操作已抽取至 common.sh（快照 ref 驱动），本脚本仅保留用例业务步骤：
#   管理后台 → 平台级设置 → 组织 → 创建顶层组织
#
# 前置条件（不自动级联，缺失即报错）：
#   1. 登录态：goto_admin_console 内置 login 自愈（未登录自动登录、
#      身份不符自动退出换号），可独立执行
#
# 运行：bash replay_testcase/003_create-org.sh（默认显示浏览器窗口）
# 如需无头模式：HEADED=0 bash replay_testcase/003_create-org.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/../common/common.sh"

# 统一测试数据：data/test-data.sh（含全部用例数据，环境变量优先）
DATA_DIR="${SCRIPT_DIR}/../data"
load_data_file "${DATA_DIR}/test-data.sh"


ab_init
require_vars ASDM_USER ASDM_PASS ORG_NAME

# ---------- 操作步骤 ----------

# step 1: 用户进入 ASDM管理后台 首页
goto_admin_console

# step 2: 点击左下角 [平台级设置] 按钮
echo "[step 2] 进入 [平台级设置]"
goto_platform_settings

# step 3: 点击 [组织] Tab页签（精确匹配优先，避免前缀歧义）
echo "[step 3] 点击 [组织] Tab页签"
click_tab '组织'

# step 4: 点击 [+创建顶层组织] 按钮，打开 [创建顶层组织] 窗口
echo "[step 4] 点击 [+创建顶层组织]"
click_by_text '创建顶层组织' '创建顶层组织按钮'
assert_visible '创建顶层组织' '[创建顶层组织] 弹窗出现'

# step 5: [创建顶层组织] 信息录入 —— 组织名称
echo "[step 5] 录入组织名称: $ORG_NAME"
fill_by_label '组织名称' "$ORG_NAME" '组织名称输入框'

# step 6: 点击 [创建] 按钮
echo "[step 6] 点击 [创建]"
click_by_exact '创建' '创建按钮'
ab_wait 1500

# ---------- 预期结果断言 ----------

# 预期结果 1: 组织层级树中出现新组织 "$ORG_NAME"
echo "[断言] 组织树中出现组织: $ORG_NAME"
assert_snapshot_contains "$ORG_NAME" "组织树中出现 $ORG_NAME"

# ---------- 收尾（§8.3） ----------
finish
