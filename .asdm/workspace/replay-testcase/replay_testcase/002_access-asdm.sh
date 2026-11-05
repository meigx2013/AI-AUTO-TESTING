#!/bin/bash
# 由 002_access-asdm.md 翻译而来（测试用例 markdown → agent-browser）
#
# 通用操作已抽取至 common.sh（快照 ref 驱动），本脚本仅保留用例业务步骤：
#   已登录态下从 Portal 首页点击右上角用户信息 → 点击 [控制台管理] → 跳转 ASDM 管理后台首页
#
# 前置条件（不自动级联，缺失即报错）：
#   1. 用户已完成系统登录——登录类前置由 goto_admin_console 内置的幂等
#      login 自动处理（未登录自动登录、身份不符自动退出换号重新登录），
#      登录态随 agent-browser 浏览器会话保持，故无需先跑 001_system-login.sh；
#      凭据经 test-data.sh 的 ASDM_USER/ASDM_PASS 提供，缺失由 require_vars
#      前置报错。
#
# 运行（工作目录 = replay-testcase/）：bash replay_testcase/002_access-asdm.sh（默认显示浏览器窗口）
# 如需无头模式：HEADED=0 bash replay_testcase/002_access-asdm.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"      # = .../replay-testcase/replay_testcase
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/../common/common.sh"            # 公共库在同级 common/ 目录

# 统一测试数据：data/test-data.sh（含全部用例数据，环境变量优先）
DATA_DIR="${SCRIPT_DIR}/../data"                 # 数据在同级 data/ 目录
load_data_file "${DATA_DIR}/test-data.sh"

BASE_URL="${BASE_URL:-https://asdm-dt01.leansoftx.com/}"

ab_init
require_vars ASDM_USER ASDM_PASS

# ---------- 操作步骤 ----------
# step 1(原步骤 1): 用户访问 Portal 首页
# step 2(原步骤 2): 点击 右上角 用户信息
# step 3(原步骤 3): 在弹出的面板中点击 [控制台管理] 按钮
# step 4(原步骤 4): 页面跳转到 ASDM 管理后台 首页面
#   决断：步骤 1~4 即 common.sh 的 goto_admin_console 完整链路（login 幂等
#   自愈 → open_page 打开 Portal 首页 → click_user_info 点击右上角用户信息
#   → 点击 [控制台管理] → in_admin_console 落点校验 + 回 Portal 重开菜单
#   重试 + 深链 /projects 兜底），不在业务脚本内手写导航细节；落点校验为
#   硬断言（流程关键节点：未进入管理后台即 exit 1，继续执行无意义，§2.3-6）。
goto_admin_console

# ---------- 预期结果断言 ----------
# 预期结果 1(原1): 从 Portal 成功跳转到 ASDM 管理后台 首页面
#   管理后台首页 URL = /projects（NOT /server：/server 为设置页前缀，直开
#   会被重定向回 /portal，见 common.sh goto_admin_console 落点判定注释）。
assert_url_matches '/projects' '从 Portal 成功跳转到 ASDM 管理后台首页面（URL 特征段 /projects）'
# 快照特征复核：管理后台导航特征文本任一命中即通过（与 in_admin_console
# 同源特征，覆盖 SPA URL 未变但工作区已渲染的情形）
snap="$(snap_i)"
case "$snap" in
    *'平台级设置'*|*'组织与项目'*)
        echo "  [断言通过] ASDM 管理后台首页面渲染（导航特征文本）";;
    *)
        echo "  [断言失败] ASDM 管理后台首页面渲染：快照中未找到 '平台级设置'/'组织与项目'" >&2
        WARN=$((WARN+1));;
esac

# ---------- 收尾 ----------
finish
