#!/bin/bash
# 由 012_system-logout.md 翻译而来（测试用例 markdown → agent-browser）
#
# 通用操作已抽取至 common.sh（快照 ref 驱动），本脚本仅保留用例业务步骤：
#   Portal 首页 → 用户信息 → 退出登录 → 确认 → 断言回到未登录首页
#
# 前置条件：
#   1. 登录态：未登录时自动登录（login 自愈），可独立执行
#
# 运行：bash replay_testcase/012_system-logout.sh（默认显示浏览器窗口）
# 如需无头模式：HEADED=0 bash replay_testcase/012_system-logout.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/../common/common.sh"

# 统一测试数据：data/test-data.sh（含全部用例数据，环境变量优先）
DATA_DIR="${SCRIPT_DIR}/../data"
load_data_file "${DATA_DIR}/test-data.sh"


ab_init
require_vars ASDM_USER ASDM_PASS

# ---------- 操作步骤 ----------

# step 1: 打开 Portal 首页
echo "[step 1] 访问 Portal 首页: $BASE_URL"
open_page

# step 2: 确保登录态（未登录时自动登录，保证本用例可独立执行）
echo "[step 2] 确保登录态"
if ! is_logged_in; then
    echo "  当前未登录，自动登录: $ASDM_USER"
    login
fi

# step 3: 点击右上角用户信息区域；若弹出 [控制台管理] 说明已进入管理后台，回到 Portal 再操作
echo "[step 3] 点击用户信息区域"
click_user_info
snap=$(snap_i)
case "$snap" in
    *'控制台管理'*)
        click_by_text '控制台管理' '控制台管理入口'
        ab_wait 1500
        click_user_info
        ;;
esac

# step 4: 点击 [退出登录]
echo "[step 4] 点击 [退出登录]"
click_by_exact '退出登录' '退出登录菜单项'

# step 5: 处理二次确认弹窗（存在 确定/确认/取消 时点击确认）
echo "[step 5] 确认退出"
click_confirm_if_present

# step 6: 轮询等待退出完成（URL 回到登录页，或快照出现 邮箱/密码/登录）
echo "[step 6] 等待退出完成"
for ((i = 0; i < 15; i++)); do
    url=$(agent-browser get url 2>/dev/null)
    case "$url" in
        *signin*|*login*|*Login*) break;;
    esac
    snap=$(snap_i)
    case "$snap" in
        *'邮箱'*|*'密码'*|*'登录'*) break;;
    esac
    ab_wait 1000
done

# ---------- 预期结果断言 ----------

# 预期结果 1: URL 位于登录页或 Portal 首页
echo "[断言] 已回到登录页"
url=$(agent-browser get url 2>/dev/null)
case "$url" in
    *signin*|*login*|*Login*|*portal*)
        echo "  [断言通过] 已回到登录页: $url";;
    *)
        echo "  [断言失败] 退出登录未完成，当前 URL: $url" >&2; WARN=$((WARN+1));;
esac

# 预期结果 2: 页面出现登录入口（平台退出后回未登录 Portal 首页，而非 /signin 登录页）
echo "[断言] 登录入口出现"
snap=$(snap_i)
case "$snap" in
    *'- button "登录"'*)
        echo "  [断言通过] 页面出现【登录】按钮（登录态已清除）";;
    *)
        echo "  [断言失败] 页面未出现【登录】入口" >&2; WARN=$((WARN+1));;
esac

# 预期结果 3: 用户信息区域不再可见
# 【勿用全页快照子串】Portal"热门推荐"资源卡片为整卡可点 button，文本含
# 作者名 "Admin Super"（实测 top~1087 主内容区），全快照匹配 *'Admin Super'*
# 必误命中，把已退出误判为"用户信息仍可见"（首轮失败根因：断言 1/2 均通过、
# 退出本身成功）。改用 is_logged_in 否定判定——其内部快照特征不含 Admin
# Super，JS 检测已限定 header/顶部区域，资源卡片不再干扰。
echo "[断言] 用户信息区域不可见"
if is_logged_in; then
    echo "  [断言失败] 用户信息区域仍可见" >&2; WARN=$((WARN+1))
else
    echo "  [断言通过] 用户信息区域已消失"
fi

# ---------- 收尾（§8.3） ----------
finish
