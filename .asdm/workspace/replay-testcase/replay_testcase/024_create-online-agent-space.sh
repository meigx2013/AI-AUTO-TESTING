#!/bin/bash
# 由 024_create-online-agent-space.md 翻译而来（测试用例 markdown → agent-browser）
#
# 通用操作已抽取至 common.sh（快照 ref 驱动），本脚本仅保留用例业务步骤：
#   test01 登录 → 组织与项目 → 项目 → 智能体空间 → 新建智能体空间（在线）→ 进入详情
#
# 前置条件（不自动级联，缺失即报错）：
#   1. 用户 test01@asdm.ai 已完成系统登录（先执行 replay_testcase/005_create-user.sh）
#   2. 项目 "$PROJECT_NAME" 已创建（先执行 replay_testcase/010_create-project.sh）
#
# 运行：bash replay_testcase/024_create-online-agent-space.sh（默认显示浏览器窗口）
# 如需无头模式：HEADED=0 bash replay_testcase/024_create-online-agent-space.sh
#
# 翻译决断：
#   1. 用例原文项目名与 test-data.sh 批次数据不一致，按规范以 test-data.sh
#      统一，使用 $PROJECT_NAME（差异记入 test-plan §七）
#   2. 用例步骤 2 省略了组织导航，按 010/012 已实测验证路径展开：
#      [组织与项目] → 组织树节点 "$ORG_NODE" → 点击项目名称
#   3. 登录身份决断为 test01（智能体空间挂靠项目，项目为 test01 创建，
#      与 012 一致）
#   4. 用例按钮称谓与 012 实测不一致：用例写入口 [创建智能体空间] /
#      提交 [创建]，012 实跑核对的同一功能实际按钮为 入口 [新建智能体空间] /
#      提交 [创建智能体空间]——按 012 实测文案执行（同一创建弹窗流程）
#   5. 类型下拉按 012 实测为原生 select（浮层两步法报 CDP box model 错误），
#      直接 select_by_native；用例写 [在线]，按 012 选项后缀规律（用例
#      [普通] → 实际 '普通类'）推断选项文本为 '在线类'，数据值存
#      ONLINE_WORKSPACE_TYPE，实跑若失配更新 test-data.sh 值即可
#   6. "列表中增加一条记录"不产生动作，并入预期结果断言（§4.1）
#   7. 名称 "在线智能体空间" 为创建类数据（不幂等），按 §5.2 带批次
#      时间戳后缀防重名

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
require_vars ASDM_USER ASDM_PASS ORG_NODE PROJECT_NAME ONLINE_WORKSPACE_NAME ONLINE_WORKSPACE_TYPE

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

# step 4(决断修正): 点击 [新建智能体空间] 按钮，打开创建窗口
# （用例写 [创建智能体空间]，按 012 实测入口按钮文案执行，见翻译决断 4）
echo "[step 4] 点击 [新建智能体空间]"
click_by_text '新建智能体空间' '新建智能体空间按钮'
assert_visible '新建智能体空间' '[新建智能体空间] 弹窗出现'

# step 5: [创建智能体空间] 信息录入 —— 名称 / 类型（在线）
echo "[step 5] 信息录入: 名称=$ONLINE_WORKSPACE_NAME 类型=$ONLINE_WORKSPACE_TYPE"
fill_by_any_label "$ONLINE_WORKSPACE_NAME" '名称'
# 类型为原生 select combobox（012 实测结论：浮层两步法点击报 CDP box model
# 错误——类型未选上导致提交无效；直接 select_by_native）
type_cb=$(ref_by_label '类型') || type_cb=$(ref_by_text '类型')
[ -n "$type_cb" ] || { echo "  [失败] 未找到类型下拉框" >&2; exit 1; }
select_by_native "$type_cb" "$ONLINE_WORKSPACE_TYPE" '类型下拉框'

# step 6: 点击 [创建智能体空间] 按钮（提交，012 实测文案）
# 空状态引导按钮与弹窗提交按钮同文本（DOM 前者靠前），须用
# ab_click_last_exact 取最后一个匹配（弹窗提交按钮 DOM 靠后）
echo "[step 6] 点击 [创建智能体空间]"
ab_click_last_exact '创建智能体空间' '创建智能体空间按钮（弹窗内）'
ab_wait 2000

# ---------- 预期结果断言 ----------

# 预期结果 1: 智能体空间列表新增一条记录 "$ONLINE_WORKSPACE_NAME"
# 注意：必须匹配实体行（heading/cell/link），创建失败弹窗停留时输入框残留值
# 会造成假阳性
echo "[断言] 智能体空间出现: $ONLINE_WORKSPACE_NAME"
shown=1
for ((i = 0; i < 10; i++)); do
    snap=$(snap_i)
    case "$snap" in
        *"heading \"$ONLINE_WORKSPACE_NAME\""*|*"cell \"$ONLINE_WORKSPACE_NAME\""*|*"- link \"$ONLINE_WORKSPACE_NAME\""*) shown=0; break;;
        *) ab_wait 500;;
    esac
done
if [ "$shown" -eq 0 ]; then
    echo "  [断言通过] 智能体空间 $ONLINE_WORKSPACE_NAME 已创建"
else
    echo "  [断言失败] 智能体空间 $ONLINE_WORKSPACE_NAME 未创建" >&2; WARN=$((WARN+1))
fi

# ---------- 操作步骤（续） ----------

# step 7: 点击该记录，进入 在线智能体空间
echo "[step 7] 点击进入智能体空间: $ONLINE_WORKSPACE_NAME"
# 空间名 heading 对 JS 合成 click 不响应，须用 click_by_heading 坐标点击
click_by_heading "$ONLINE_WORKSPACE_NAME" '智能体空间记录'

# 预期结果 2: 成功进入 在线智能体空间 页面（流程关键节点，硬断言）
# 快照特征文本已随平台改版移除——改为 URL 匹配（详情页
# .../workspaces/<id>，列表页无尾斜杠）
echo "[断言] 在线智能体空间详情页出现"
ws_detail=""
for ((i = 0; i < 20; i++)); do
    case "$(agent-browser get url 2>/dev/null)" in
        *_workspaces/workspaces/*) ws_detail=1; break;;
        *) ab_wait 1000;;
    esac
done
if [ -n "$ws_detail" ]; then
    echo "  [断言通过] 已成功进入在线智能体空间"
else
    echo "  [失败] 未进入智能体空间详情页（持续加载中或点击未生效）" >&2; exit 1
fi

# ---------- 收尾 ----------
finish
