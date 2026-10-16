#!/bin/bash
# 由 001_system-login.md 翻译而来（测试用例 markdown → agent-browser）
#
# 通用操作已抽取至 common.sh（快照 ref 驱动），本脚本仅保留用例业务步骤：
#   登录 → 断言进入未登录首页 → 登录 → 断言进入已登录首页
#
# 前置条件（不自动级联，缺失即报错）：
#   1. 用户凭据（ASDM_USER/ASDM_PASS）已提供
#
# 运行：bash replay_testcase/001_system-login.sh（默认显示浏览器窗口）
# 如需无头模式：HEADED=0 bash replay_testcase/001_system-login.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/../common/common.sh"

# 统一测试数据：data/test-data.sh（含全部用例数据，环境变量优先）
DATA_DIR="${SCRIPT_DIR}/../data"
load_data_file "${DATA_DIR}/test-data.sh"


ab_init
require_vars ASDM_USER ASDM_PASS

# ---------- 操作步骤 ----------

# step 1: 打开 Portal 首页（已登录时会进入已登录首页，未登录时进入登录页）
echo "[step 1] 访问 Portal 首页: $BASE_URL"
open_page

# step 2: 未登录状态下首页出现【登录】按钮（SPA 轮询，严禁全树兜底）
echo "[step 2] 轮询等待【登录】按钮出现"
ref=$(wait_for_ref_by_text '登录' 15) || {
    # 找不到登录按钮可能是已有登录态，校验快照中是否已有用户信息
    if is_logged_in; then
        echo "  已存在登录态，跳过登录"
    else
        echo "  [失败] 未找到【登录】按钮且无登录态" >&2
        exit 1
    fi
}

# step 3: 点击【登录】按钮 → 跳转登录页（SPA 轮询邮箱输入框）
echo "[step 3] 点击【登录】"
if [ -n "$ref" ]; then
    agent-browser click "@${ref}" >/dev/null
    ref=$(wait_for_ref_by_label '邮箱' 15) || {
        # 冷启动兜底：SPA 首帧未挂载事件时首次点击可能丢失；按当前 URL 分派重试
        url=$(agent-browser get url 2>/dev/null)
        case "$url" in
            *signin*)  # 已跳转登录页但表单渲染慢，延长等待
                ref=$(wait_for_ref_by_label '邮箱' 15);;
            *)         # 仍停留首页：点击丢失，重新定位【登录】按钮再点
                echo "  首次点击可能丢失（仍在 ${url}），重新定位【登录】按钮重试"
                ref=$(wait_for_ref_by_text '登录' 8) || ref=""
                if [ -n "$ref" ]; then
                    agent-browser click "@${ref}" >/dev/null
                    ref=$(wait_for_ref_by_label '邮箱' 15)
                fi;;
        esac
    }
    [ -n "$ref" ] || { echo "  [失败] 登录页未渲染（未出现邮箱输入框）" >&2; exit 1; }
fi

# step 4: 填写邮箱 / 密码
echo "[step 4] 填写邮箱 / 密码"
if [ -n "$ref" ]; then
    agent-browser fill "@${ref}" "$ASDM_USER" >/dev/null
    fill_by_label '密码' "$ASDM_PASS" '密码输入框'
fi

# step 5: 点击登录按钮，提交登录
echo "[step 5] 点击【登录】提交"
if [ -n "$ref" ]; then
    click_by_text '登录' '登录按钮'
    # 等待登录完成跳回 Portal 首页：轮询直至 URL 离开 /signin
    wait_for_url_gone 'signin' 15 1000
fi

# ---------- 预期结果断言 ----------

# 预期结果 1: 成功登录进入已登录首页（URL 不位于登录页且回到 portal）
echo "[断言] 已进入 Portal 首页（登录态）"
url=$(agent-browser get url 2>/dev/null)
case "$url" in
    *signin*|*login*|*Login*)
        echo "  [断言失败] 登录未完成，当前 URL: $url" >&2; WARN=$((WARN+1));;
    *portal*)
        echo "  [断言通过] 已回到 Portal 首页: $url";;
    *)
        echo "  [断言通过] 已离开登录页: $url";;
esac

# 预期结果 2: 用户信息区域出现（登录态标志）
echo "[断言] 用户信息区域出现"
if is_logged_in; then
    echo "  [断言通过] 首页出现用户信息区域（登录成功）"
else
    echo "  [断言失败] 首页未出现用户信息区域（登录态特征缺失: ${ASDM_USER%%@*} / Admin Super）" >&2
    WARN=$((WARN+1))
fi

# ---------- 收尾（§8.3） ----------
finish
