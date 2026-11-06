#!/bin/bash
# 由 001_system-login.md 翻译而来（测试用例 markdown → agent-browser）
#
# 通用操作已抽取至 common.sh（快照 ref 驱动），本脚本仅保留用例业务步骤：
#   访问 ASDM 平台首页 → 右上角点击【登录】跳转登录页 → 输入邮箱/密码 → 点击【登录】完成登录
#
# 前置条件（不自动级联，缺失即报错）：
#   1. 用户已注册（super-admin 账号已存在于平台；凭据经 test-data.sh 的
#      ASDM_USER/ASDM_PASS 提供，缺失由 require_vars 前置报错）
#
# 运行（工作目录 = replay-testcase/）：bash replay_testcase/001_system-login.sh（默认显示浏览器窗口）
# 如需无头模式：HEADED=0 bash replay_testcase/001_system-login.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"      # = .../replay-testcase/replay_testcase
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/../common/common.sh"            # 公共库在同级 common/ 目录

# 统一测试数据：data/test-data.sh（含全部用例数据，环境变量优先）
DATA_DIR="${SCRIPT_DIR}/../data"                 # 数据在同级 data/ 目录
load_data_file "${DATA_DIR}/test-data.sh"

BASE_URL="${BASE_URL:-https://asdm-sit.leansoftx.com/}"

ab_init
require_vars ASDM_USER ASDM_PASS

# ---------- 操作步骤 ----------
# step 1(原步骤 1): 浏览器地址栏输入平台首页地址
#   用例原文 URL（https://asdm-sit.leansoftx.com/）与 test-data.sh 的
#   BASE_URL 一致，无差异；环境变量 BASE_URL=... 可覆盖。
# step 2(原步骤 2): portal 页面右上角点击【登录】，页面跳转到 ASDM 登录页
# step 3(原步骤 3): 输入邮箱地址（ASDM_USER）
# step 4(原步骤 4): 输入密码（ASDM_PASS）
# step 5(原步骤 5): 点击【登录】按钮，完成登录
#   决断：本用例即登录用例本身，完整链路（首页【登录】按钮轮询 → 登录表单
#   渲染等待 + /signin 兜底直达 → 填表提交 → 离开 /signin 判定）由 common.sh
#   的 login 幂等承载，含 SPA 冷启动对策，不在业务脚本内手写登录细节；
#   已登录且身份一致时幂等跳过（登录/导航类天然幂等，§六）。
login

# ---------- 预期结果断言 ----------
# 预期结果 1(原1): 页面跳转到 Portal 首页面
#   登录成功落点实测为 https://<host>/portal/（特征段 /portal/）。
wait_for_url_match '/portal' 20 || true   # SPA 路由跳转轮询（§2.3-5），跳转慢不立即判失败
assert_url_matches '/portal' '页面跳转到 Portal 首页（URL 特征段 /portal/）'
assert_url_not_matches 'signin' '已离开登录页（/signin）'
assert_snapshot_contains '热门推荐' 'Portal 首页渲染（热门推荐栏目）'
if is_logged_in; then
    echo "  [断言通过] 登录态出现（右上角用户信息区域）"
else
    echo "  [断言失败] 未检测到登录态（右上角用户信息区域）" >&2
    WARN=$((WARN+1))
fi

# ---------- 收尾 ----------
finish
