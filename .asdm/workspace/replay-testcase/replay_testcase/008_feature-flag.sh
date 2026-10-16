#!/bin/bash
# 由 008_feature-flag.md 翻译而来（测试用例 markdown → agent-browser）
#
# 通用操作已抽取至 common.sh（快照 ref 驱动），本脚本仅保留用例业务步骤：
#   管理后台 → 平台级设置 → 特性开关 → 逐个搜索/编辑/设为全量开放/保存 → 复核
#
# 前置条件（不自动级联，缺失即报错）：
#   1. 用户已完成系统登录（先执行 replay_testcase/001_system-login.sh）
#   2. 特性开关项 "$FEATURE_FLAGS" 已存在
#
# 运行：bash replay_testcase/008_feature-flag.sh（默认显示浏览器窗口）
# 如需无头模式：HEADED=0 bash replay_testcase/008_feature-flag.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/../common/common.sh"

# 统一测试数据：data/test-data.sh（含全部用例数据，环境变量优先）
DATA_DIR="${SCRIPT_DIR}/../data"
load_data_file "${DATA_DIR}/test-data.sh"


ab_init
require_vars ASDM_USER ASDM_PASS FLAG_STATUS

# ---------- 操作步骤 ----------

# step 1: 用户进入 ASDM管理后台 首页
# 单任务补跑/会话过期时可能无登录态，先幂等登录 super-admin
login
goto_admin_console

# step 2: 点击左下角 [平台级设置] 按钮
echo "[step 2] 进入 [平台级设置]"
goto_platform_settings

# step 3: 点击 [特性开关] Tab页签
echo "[step 3] 点击 [特性开关] Tab页签"
click_tab '特性开关'

# step 4: 逐个特性开关：搜索 → 编辑 → 状态设为全量开放 → 保存
echo "[step 4] 编辑特性开关状态 → $FLAG_STATUS"
for flag in $FEATURE_FLAGS; do
    echo "  ── 处理特性开关: $flag"
    search_and_filter "$flag" || exit 1

    click_by_exact '编辑' '编辑按钮'
    assert_visible '编辑特性开关' "[编辑特性开关] 弹窗出现: $flag"

    click_radio "$FLAG_STATUS" '状态单选'
    click_by_exact '保存' '保存按钮'
    ab_wait 1000

    # 软断言：当前行状态列已变为 FLAG_STATUS
    status=$(cell_after "$flag" 1)
    case "$status" in
        *"$FLAG_STATUS"*)
            echo "  [断言通过] $flag 状态已更新为 $FLAG_STATUS";;
        *)
            echo "  [断言失败] $flag 状态未更新，当前状态列: ${status:-空}" >&2; WARN=$((WARN+1));;
    esac
    clear_search_box
done

# step 5: 复核所有开关状态均为 FLAG_STATUS
echo "[step 5] 复核特性开关状态"
for flag in $FEATURE_FLAGS; do
    search_and_filter "$flag" || exit 1
    status=$(cell_after "$flag" 1)
    case "$status" in
        *"$FLAG_STATUS"*)
            echo "  [断言通过] 复核 $flag: $FLAG_STATUS";;
        *)
            echo "  [断言失败] 复核 $flag 状态异常，当前状态列: ${status:-空}" >&2; WARN=$((WARN+1));;
    esac
    clear_search_box
done

# ---------- 收尾（§8.3） ----------
finish
