#!/bin/bash
# 由 004_create-sub-org.md 翻译而来（测试用例 markdown → agent-browser）
#
# 通用操作已抽取至 common.sh（快照 ref 驱动），本脚本仅保留用例业务步骤：
#   管理后台 → 平台级设置 → 组织 Tab → 父组织行 [...] → 创建子组织（树新增子节点）
#
# 前置条件（不自动级联，缺失即报错）：
#   1. 超级管理员用户已完成系统登录——登录类前置由 goto_admin_console 内置
#      的幂等 login 自动处理（未登录自动登录、身份不符自动退出换号重新登录），
#      凭据经 test-data.sh 的 ASDM_USER/ASDM_PASS 提供，缺失由 require_vars
#      前置报错，可独立执行。
#   2. 已创建顶层组织 PARENT_ORG（=T001_组织01，用例 003 产物）——前置用例
#      未执行时组织树中不存在父组织行，[...] 行内按钮定位失败即硬报错退出；
#      状态类依赖不自动级联，须先执行 replay_testcase/003_create-org.sh。
#   3. 幂等性：创建类用例不幂等——同批次（BATCH_ID=T001）重跑会因子组织
#      重名失败，重跑须换批次号（generate-test-data T002）或平台侧先清理
#      同名组织（T0xx_ 前缀辨识）。
#
# 运行（工作目录 = replay-testcase/）：bash replay_testcase/004_create-sub-org.sh（默认显示浏览器窗口）
# 如需无头模式：HEADED=0 bash replay_testcase/004_create-sub-org.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"      # = .../replay-testcase/replay_testcase
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/../common/common.sh"            # 公共库在同级 common/ 目录

# 统一测试数据：data/test-data.sh（含全部用例数据，环境变量优先）
DATA_DIR="${SCRIPT_DIR}/../data"                 # 数据在同级 data/ 目录
load_data_file "${DATA_DIR}/test-data.sh"

BASE_URL="${BASE_URL:-https://asdm-dt01.leansoftx.com/}"

ab_init
require_vars ASDM_USER ASDM_PASS PARENT_ORG SUB_ORG_NAME

# ---------- 操作步骤 ----------

# step 0(隐含导航): 管理后台 → 平台级设置 → 组织 Tab（组织树所在页）
#   决断：用例步骤 1 直接从"组织树"开始，未写导航链路——按 003 同源链路
#   补 goto_admin_console（login 幂等自愈 → /projects 落点硬校验）→
#   goto_platform_settings（/server/_settings 落点硬校验）→ click_tab '组织'。
echo "[step 0] 导航至 平台级设置 → [组织] Tab"
goto_admin_console
goto_platform_settings
click_tab '组织'

# step 1(原步骤 1): 组织树中点击组织节点 "测试组织01" 右边的 [...]
#   决断 1：用例原文组织 "测试组织01" 以批次实例 PARENT_ORG=T001_组织01 取代
#   （批次机制：与 003 创建的顶层组织字面对齐，§5.2 引用链）。
#   决断 2："..." 为树节点行内隐藏操作按钮，按 §4.3 行内操作模式——
#   snapshot_line_after 取父组织行之后第一个 button 的 ref 再点击；
#   ref 快照失效风险由"取后立即点击"规避（§2.3 快照 ref 铁律）。
#   顶层节点创建后自动可见，无需 expand_all_tree（父组织即树根级）。
echo "[step 1] 点击组织节点 '$PARENT_ORG' 行内的 [...] 按钮"
dots_ref=""
for ((i = 0; i < 10; i++)); do
    dots_ref=$(snapshot_line_after "$PARENT_ORG" 'button')
    [ -n "$dots_ref" ] && break
    sleep 1
done
if [ -n "$dots_ref" ]; then
    agent-browser click "@${dots_ref}" >/dev/null
    ab_wait 1000
else
    echo "  [失败] 组织树中未找到 '$PARENT_ORG' 行的 [...] 按钮（父组织不存在？先执行 003_create-org.sh）" >&2
    exit 1
fi

# step 2(原步骤 2): 打开 [创建子组织] 窗口
#   决断：[...] 点击后弹出操作菜单，菜单项 [创建子组织] 再打开窗口——
#   两级交互合并为一步翻译（菜单项精确点击 + 弹窗硬断言）。
#   弹窗判定用 wait_for_dialog（dialog 元素检测，防入口/标题同文本假阳性）。
echo "[step 2] 点击菜单项 [创建子组织]，等待弹窗"
click_by_exact '创建子组织' '创建子组织菜单项'
wait_for_dialog 10 1000 \
    || { echo "  [失败] [创建子组织] 弹窗未出现" >&2; exit 1; }
echo "  [断言通过] [创建子组织] 弹窗已打开（dialog 元素检测）"

# step 3(原步骤 3): [创建子组织] 信息录入 —— 组织名称
#   决断：用例原文值 "测试组织0101" 以批次实例 SUB_ORG_NAME=T001_组织02 取代
#   （批次机制：每批全新数据规避创建类不幂等的重名冲突，§5.2）。
echo "[step 3] 录入子组织名称: $SUB_ORG_NAME"
fill_by_label '组织名称' "$SUB_ORG_NAME" '子组织名称输入框'

# step 4(原步骤 4): 点击 [创建] 按钮
#   提交静默拦截显性化（平台特性 2/12）：创建后弹窗应关闭；仍打开时可能为
#   必填静默拦截或弹窗不自动关——两种情形均经 reload 收敛，真实结果一律以
#   reload 后的树节点断言判定（软断言汇总，不在此硬断言误杀）。
echo "[step 4] 点击 [创建]"
click_by_exact '创建' '创建按钮'
ab_wait 2000
if dialog_open; then
    echo "  [提示] 创建弹窗未自动关闭（静默拦截或平台特性 12），reload 收敛后以树节点断言为准" >&2
fi

# step 5(原步骤 5): "测试组织01"节点 增加一个子节点 "测试组织0101"
#   决断：按 §4.1 "列表/树增加一条记录" 不翻译为动作，并入预期结果断言（§七）。

# ---------- 预期结果断言 ----------

# 预期结果 1(原 1): "$PARENT_ORG" 节点增加一个子节点 "$SUB_ORG_NAME"
#   创建后树刷新时序不可靠（平台特性 12）——reload 兜底重开页面 +
#   expand_all_tree 展开全树（子节点默认折叠在父节点下、懒渲染，必须展开
#   才可见）+ 轮询断言（软断言，失败 WARN 由 finish 汇总）。
echo "[断言] 组织树 '$PARENT_ORG' 下出现子组织: $SUB_ORG_NAME"
agent-browser reload >/dev/null 2>&1
ab_wait 2000
expand_all_tree
if wait_for_text "$SUB_ORG_NAME" 10 1; then
    assert_snapshot_contains "$SUB_ORG_NAME" "组织树中出现子组织 $SUB_ORG_NAME"
else
    echo "  [断言失败] 组织树中未出现子组织 $SUB_ORG_NAME（创建提交可能被静默拦截，检查组织名称必填/长度）" >&2
    WARN=$((WARN+1))
fi

# ---------- 收尾 ----------
finish
