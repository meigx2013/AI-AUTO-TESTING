#!/bin/bash
# 由 003_create-org.md 翻译而来（测试用例 markdown → agent-browser）
#
# 通用操作已抽取至 common.sh（快照 ref 驱动），本脚本仅保留用例业务步骤：
#   管理后台 → 平台级设置 → 组织 Tab → 创建顶层组织（组织树新增节点）
#
# 前置条件（不自动级联，缺失即报错）：
#   1. 超级管理员用户已完成系统登录——登录类前置由 goto_admin_console 内置
#      的幂等 login 自动处理（未登录自动登录、身份不符自动退出换号重新登录），
#      凭据经 test-data.sh 的 ASDM_USER/ASDM_PASS 提供，缺失由 require_vars
#      前置报错，可独立执行。
#   2. 幂等性：创建类用例不幂等——同批次（BATCH_ID=T001）重跑会因组织
#      重名失败，重跑须换批次号（generate-test-data T002）或平台侧先清理
#      同名组织（T0xx_ 前缀辨识）。
#
# 运行（工作目录 = replay-testcase/）：bash replay_testcase/003_create-org.sh（默认显示浏览器窗口）
# 如需无头模式：HEADED=0 bash replay_testcase/003_create-org.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"      # = .../replay-testcase/replay_testcase
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/../common/common.sh"            # 公共库在同级 common/ 目录

# 统一测试数据：data/test-data.sh（含全部用例数据，环境变量优先）
DATA_DIR="${SCRIPT_DIR}/../data"                 # 数据在同级 data/ 目录
load_data_file "${DATA_DIR}/test-data.sh"

BASE_URL="${BASE_URL:-https://asdm-dt01.leansoftx.com/}"

ab_init
require_vars ASDM_USER ASDM_PASS ORG_NAME

# ---------- 操作步骤 ----------

# step 1(原步骤 1): 用户进入 ASDM管理后台 首页
#   决断：goto_admin_console 完整链路（login 幂等自愈 → Portal → 控制台管理），
#   落点 /projects 校验为硬断言（未进入后台即 exit 1）。
goto_admin_console

# step 2~3(原步骤 2、3): 点击左下角 [平台级设置]，右侧工作区打开平台级设置页面
#   决断：两步合并为 goto_platform_settings（点击 + /server/_settings 落点硬校验）。
echo "[step 2~3] 进入 [平台级设置]"
goto_platform_settings

# step 4(原步骤 4): 点击 [组织] Tab页签（精确匹配优先，防前缀歧义）
echo "[step 4] 点击 [组织] Tab页签"
click_tab '组织'

# step 5(原步骤 5): 点击 [创建顶层组织] 按钮，打开 [创建顶层组织] 窗口
#   决断：入口按钮与弹窗标题同文本，assert_visible 快照文本匹配会误命中按钮
#   造成假阳性（022/023 实测教训）——改用 wait_for_dialog 检测 dialog/modal
#   元素真实打开，硬断言（流程关键节点，弹窗未开即 exit 1）。
echo "[step 5] 点击 [创建顶层组织]，等待弹窗"
click_by_text '创建顶层组织' '创建顶层组织按钮'
wait_for_dialog 10 1000 \
    || { echo "  [失败] [创建顶层组织] 弹窗未出现" >&2; exit 1; }
echo "  [断言通过] [创建顶层组织] 弹窗已打开（dialog 元素检测）"

# step 6(原步骤 6): [创建顶层组织] 信息录入 —— 组织名称
#   决断：用例原文值 "测试组织01" 以批次实例 ORG_NAME=T001_组织01 取代
#   （批次机制：每批全新数据规避创建类不幂等的重名冲突，§5.2）。
echo "[step 6] 录入组织名称: $ORG_NAME"
fill_by_label '组织名称' "$ORG_NAME" '组织名称输入框'

# step 7(原步骤 7): 点击 [创建] 按钮
#   提交静默拦截显性化（平台特性 2/12）：创建后弹窗应关闭；仍打开时可能为
#   必填静默拦截或弹窗不自动关——两种情形均经 reload 收敛，真实结果一律以
#   reload 后的树节点断言判定（软断言汇总，不在此硬断言误杀）。
echo "[step 7] 点击 [创建]"
click_by_exact '创建' '创建按钮'
ab_wait 2000
if dialog_open; then
    echo "  [提示] 创建弹窗未自动关闭（静默拦截或平台特性 12），reload 收敛后以树节点断言为准" >&2
fi

# step 8(原步骤 8): 组织树增加一个节点 "$ORG_NAME"
#   决断：按 §4.1 "列表/树增加一条记录" 不翻译为动作，并入预期结果断言（§七）。

# ---------- 预期结果断言 ----------

# 预期结果 1(原 1): 组织树增加一个节点 "$ORG_NAME"
#   创建后列表/树刷新时序不可靠（平台特性 12）——reload 兜底重开页面 +
#   expand_all_tree 展开全树（顶层节点创建后通常自动可见，展开兜底防折叠态）
#   + 轮询断言（软断言，失败 WARN 由 finish 汇总）。
echo "[断言] 组织树中出现组织: $ORG_NAME"
agent-browser reload >/dev/null 2>&1
ab_wait 2000
expand_all_tree
if wait_for_text "$ORG_NAME" 10 1; then
    assert_snapshot_contains "$ORG_NAME" "组织树中出现 $ORG_NAME"
else
    echo "  [断言失败] 组织树中未出现 $ORG_NAME（创建提交可能被静默拦截，检查组织名称必填/长度）" >&2
    WARN=$((WARN+1))
fi

# ---------- 收尾 ----------
finish
