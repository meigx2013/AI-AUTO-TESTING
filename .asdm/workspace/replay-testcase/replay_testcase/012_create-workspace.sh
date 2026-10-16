#!/bin/bash
# 由 012_create-workspace.md 翻译而来（测试用例 markdown → agent-browser）
#
# 通用操作已抽取至 common.sh（快照 ref 驱动），本脚本仅保留用例业务步骤：
#   test01 登录 → 组织与项目 → 项目 → 智能体空间 → 新建智能体空间（普通）→ 进入概览
#
# 前置条件（不自动级联，缺失即报错）：
#   1. 用户 test01@asdm.ai 已完成系统登录（先执行 replay_testcase/005_create-user.sh）
#   2. 项目 "$PROJECT_NAME" 已创建（先执行 replay_testcase/010_create-project.sh）
#
# 运行：bash replay_testcase/012_create-workspace.sh（默认显示浏览器窗口）
# 如需无头模式：HEADED=0 bash replay_testcase/012_create-workspace.sh
#
# 翻译决断：
#   1. 用例原文项目名 "测试组织0101-项目01" 与 test-data.sh 批次数据不一致，
#      按规范以 test-data.sh 统一，使用 $PROJECT_NAME（差异记入 test-plan §七）
#   2. 用例步骤 2"点击项目列表中项目名称"省略了组织导航，按 010 已实测验证
#      路径展开：[组织与项目] → 组织树节点 "$ORG_NODE" → 点击项目名称
#   3. 名称 "工作空间" 为创建类数据（不幂等），按 §5.2 带批次时间戳后缀防重名
#   4. "类型：选择[普通]" 按下拉两步法翻译（select_option）；若浮层选项点击
#      报 CDP box model 错误，实跑时降级 select_by_native（§4.4）

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/../common/common.sh"

# 统一测试数据：data/test-data.sh（含全部用例数据，环境变量优先）
DATA_DIR="${SCRIPT_DIR}/../data"
load_data_file "${DATA_DIR}/test-data.sh"


ab_init
# 本用例以 test01 身份登录（公共凭据为超级管理员，此处切换；可用 TEST01_USER/TEST01_PASS 覆盖）
ASDM_USER="${TEST01_USER:-test01@asdm.ai}"
ASDM_PASS="${TEST01_PASS:-admin@2026}"
require_vars ASDM_USER ASDM_PASS ORG_NODE PROJECT_NAME WORKSPACE_NAME WORKSPACE_TYPE WORKSPACE_DESC

# ---------- 操作步骤 ----------

# step 1: 以 test01 完成系统登录（已存在登录态则幂等跳过）
echo "[step 1] test01 登录"
login

# step 2: 进入 ASDM 管理后台 → 组织与项目 → 组织节点 → 项目页面
goto_admin_console
goto_org_project
click_tree_node "$ORG_NODE" || exit 1
echo "[step 2] 点击项目: $PROJECT_NAME"
click_by_text "$PROJECT_NAME" '项目名称'
ab_wait 1500

# step 3: 右侧工作区打开 [智能体空间] 页面
# 精确匹配优先：避免"智能体空间"作为 [新建智能体空间] 按钮的子串被误点
echo "[step 3] 打开 [智能体空间] 页面"
click_by_exact '智能体空间' '智能体空间导航'
ab_wait 1000

# step 4: 点击 [新建智能体空间] 按钮
echo "[step 4] 点击 [新建智能体空间]"
click_by_text '新建智能体空间' '新建智能体空间按钮'
assert_visible '新建智能体空间' '[新建智能体空间] 弹窗出现'

# step 5: [新建智能体空间] 信息录入 —— 名称 / 类型 / 描述
echo "[step 5] 信息录入: 名称=$WORKSPACE_NAME 类型=$WORKSPACE_TYPE"
fill_by_any_label "$WORKSPACE_NAME" '名称'
# 类型为原生 select combobox（浮层两步法点击会报 CDP box model 错误且
# 选项文本匹配落空——类型未选上导致提交无效；按翻译决断 4 /
# §4.4 降级 select_by_native，数据值同步对齐实际选项文本"普通类"）
type_cb=$(ref_by_label '类型') || type_cb=$(ref_by_text '类型')
[ -n "$type_cb" ] || { echo "  [失败] 未找到类型下拉框" >&2; exit 1; }
select_by_native "$type_cb" "$WORKSPACE_TYPE" '类型下拉框'
fill_by_any_label "$WORKSPACE_DESC" '描述'

# step 6: 点击 [创建智能体空间] 按钮
# 页面空状态引导按钮与弹窗提交按钮同文本"创建智能体空间"（DOM 前者靠前），
# click_by_exact 取首个匹配会点到弹窗外引导按钮——提交从未发生（弹窗停留、
# 表单已填而列表为空）；必须用 ab_click_last_exact 取最后一个匹配
# （弹窗提交按钮 DOM 靠后）
echo "[step 6] 点击 [创建智能体空间]"
ab_click_last_exact '创建智能体空间' '创建智能体空间按钮（弹窗内）'
ab_wait 2000

# step 7: 进入智能体空间 [概览]
echo "[step 7] 等待进入智能体空间 [概览]"
wait_for_text '概览' 10 || true

# ---------- 预期结果断言 ----------

# 预期结果 1: 智能体空间列表新增一条记录
echo "[断言] 智能体空间出现: $WORKSPACE_NAME"
# 注意：必须匹配实体行（heading/cell/link），创建失败弹窗停留时输入框残留值
# 会造成假阳性（同 010 修复防护）
shown=1
for ((i = 0; i < 10; i++)); do
    snap=$(snap_i)
    case "$snap" in
        *"heading \"$WORKSPACE_NAME\""*|*"cell \"$WORKSPACE_NAME\""*|*"- link \"$WORKSPACE_NAME\""*) shown=0; break;;
        *) ab_wait 500;;
    esac
done
if [ "$shown" -eq 0 ]; then
    echo "  [断言通过] 智能体空间 $WORKSPACE_NAME 已创建"
else
    echo "  [断言失败] 智能体空间 $WORKSPACE_NAME 未创建" >&2; WARN=$((WARN+1))
fi

# ---------- 收尾 ----------
finish
