#!/bin/bash
# 由 002_access-asdm.md 翻译而来（测试用例 markdown → agent-browser）
#
# 通用操作已抽取至 common.sh（快照 ref 驱动），本脚本仅保留用例业务步骤：
#   Portal 首页 → 用户信息 → 控制台管理 → 进入 ASDM 管理后台
#
# 前置条件（不自动级联，缺失即报错）：
#   1. 登录态：goto_admin_console 内置 login 自愈（未登录自动登录、
#      身份不符自动退出换号），可独立执行
#
# 运行：bash replay_testcase/002_access-asdm.sh（默认显示浏览器窗口）
# 如需无头模式：HEADED=0 bash replay_testcase/002_access-asdm.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/../common/common.sh"

# 统一测试数据：data/test-data.sh（含全部用例数据，环境变量优先）
DATA_DIR="${SCRIPT_DIR}/../data"
load_data_file "${DATA_DIR}/test-data.sh"


ab_init
require_vars ASDM_USER ASDM_PASS

# ---------- 操作步骤 ----------

# step 1: 用户进入 ASDM管理后台 首页（Portal → 控制台管理）
goto_admin_console

# ---------- 预期结果断言 ----------

# 预期结果 1: 跳转到 ASDM 管理后台（URL 或页面特征文本）
echo "[断言] 已进入 ASDM 管理后台"
url=$(agent-browser get url 2>/dev/null)
case "$url" in
    *console*|*admin*|*projects*)
        echo "  [断言通过] 已跳转到管理后台: $url";;
    *)
        snap=$(snap_i)
        case "$snap" in
            *平台级设置*|*组织与项目*)
                echo "  [断言通过] 已进入管理后台（快照含特征文本）: $url";;
            *)
                echo "  [断言失败] 未跳转到管理后台，当前 URL: $url" >&2; WARN=$((WARN+1));;
        esac;;
esac

# ---------- 收尾（§8.3） ----------
finish
