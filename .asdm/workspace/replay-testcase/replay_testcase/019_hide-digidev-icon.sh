#!/bin/bash
# 由 019_hide-digidev-icon.md 翻译而来（测试用例 markdown → agent-browser）
#
# 通用操作已抽取至 common.sh（快照 ref 驱动），本脚本仅保留用例业务步骤：
#   管理后台 → 平台级设置 → 特性开关 → 编辑 hide_digidev_icon → 全量开放 → 首页图标隐藏
#
# 前置条件（不自动级联，缺失即报错）：
#   1. 用户已完成系统登录（先执行 replay_testcase/001_system-login.sh）
#   2. 特性开关项 "hide_digidev_icon" 已存在
#
# 运行：bash replay_testcase/019_hide-digidev-icon.sh（默认显示浏览器窗口）
# 如需无头模式：HEADED=0 bash replay_testcase/019_hide-digidev-icon.sh
#
# 翻译决断：
#   1. 用例未指明登录身份：特性开关管理属平台级设置，参照 008 决断为
#      超级管理员（公共凭据 ASDM_USER/ASDM_PASS）
#   2. 流程与 008（特性开关批量编辑，已实测通过）同构，复用其翻译模式：
#      搜索 → 编辑 → 状态单选 → 保存 → 状态列复核
#   3. 预期 2 "首页中 DigiDev 图标不再显示"：快照软断言不含 DigiDev 文本
#      （图标无可见文本时断言天然通过，文案改版需同步更新关键字，§已知限制）
#
# 修复记录（2026-09-02，失败批次 TEST_TS=0902105235）：
#   1. 复核 cell_after 取值加 15 次轮询兜底——重导航后表格渲染慢，一次性
#      取值取空误报"状态未更新"
#   2. common.sh search_and_filter 修 grep -q × pipefail bug（Broken pipe，
#      命中恒判失败）并放宽过滤等待窗口，见 common.sh 该函数注释

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/../common/common.sh"

# 统一测试数据：data/test-data.sh（含全部用例数据，环境变量优先）
DATA_DIR="${SCRIPT_DIR}/../data"
load_data_file "${DATA_DIR}/test-data.sh"


ab_init
require_vars ASDM_USER ASDM_PASS HIDE_DIGIDEV_FLAG FLAG_STATUS

# ---------- 操作步骤 ----------

# step 1: 用户进入 ASDM 管理后台 首页
# 编排中 010-017 会把浏览器身份切到 test01，此处先幂等恢复
# super-admin 登录态（当前身份不符时 login 自动退出重登），再进管理后台
login
goto_admin_console

# step 2: 点击左下角 [平台级设置]，右侧工作区打开平台级设置页面
echo "[step 2] 进入 [平台级设置]"
goto_platform_settings

# step 3: 点击 [特性开关] Tab页签
echo "[step 3] 点击 [特性开关] Tab页签"
click_tab '特性开关'
ab_wait 1000

# step 4: 搜索 → 点击记录 → [编辑] → [编辑特性开关] 窗口 → 状态全量开放 → [保存]
echo "[step 4] 编辑特性开关: $HIDE_DIGIDEV_FLAG → $FLAG_STATUS"
search_and_filter "$HIDE_DIGIDEV_FLAG" || exit 1

click_by_exact '编辑' '编辑按钮'
assert_visible '编辑特性开关' "[编辑特性开关] 窗口出现: $HIDE_DIGIDEV_FLAG"

click_radio "$FLAG_STATUS" '状态单选'
click_by_exact '保存' '保存按钮'
ab_wait 1000

# step 5: 返回首页，确认 DigiDev 图标已隐藏
echo "[step 5] 返回首页验证图标隐藏"
clear_search_box
open_page
ab_wait 2000

# ---------- 预期结果断言 ----------

# 预期结果 2: 首页中 DigiDev 图标不再显示
assert_snapshot_missing 'DigiDev' '首页 DigiDev 图标已隐藏'

# 预期结果 1: 特性开关项状态变为全量开放（重新进入特性开关页复核状态列）
# 列偏移与 008 一致（序号|名称|描述|状态|操作，skip=1 跳过描述列取状态）
echo "[断言] 复核特性开关状态: $HIDE_DIGIDEV_FLAG"
goto_admin_console
goto_platform_settings
click_tab '特性开关'
ab_wait 1000
search_and_filter "$HIDE_DIGIDEV_FLAG" || exit 1
# 复核取值轮询兜底：本段经历"回首页验证图标 → 重新导航设置页"全链路，平台需
# 重新拉取特性开关列表，慢平台下行渲染滞后于 search_and_filter 等待窗口，
# 一次性 cell_after 会取空误报"状态未更新"（2026-09-02 实测失败根因）
status=""
for ((i = 0; i < 15; i++)); do
    status=$(cell_after "$HIDE_DIGIDEV_FLAG" 1)
    [ -n "$status" ] && break
    ab_wait 1000
done
case "$status" in
    *"$FLAG_STATUS"*)
        echo "  [断言通过] $HIDE_DIGIDEV_FLAG 状态已更新为 $FLAG_STATUS";;
    *)
        echo "  [断言失败] $HIDE_DIGIDEV_FLAG 状态未更新，当前状态列: ${status:-空}" >&2
        WARN=$((WARN+1));;
esac
clear_search_box

# ---------- 收尾 ----------
finish
