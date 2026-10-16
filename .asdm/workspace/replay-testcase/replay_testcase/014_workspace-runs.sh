#!/bin/bash
# 由 014_workspace-runs.md 翻译而来（测试用例 markdown → agent-browser）
#
# 通用操作已抽取至 common.sh（快照 ref 驱动），本脚本仅保留用例业务步骤：
#   test01 登录 → 项目 → 智能体空间 → 运行 → 触发运行（提示文本）→ 生成执行历史
#
# 前置条件（不自动级联，缺失即报错）：
#   1. 用户 test01@asdm.ai 已完成系统登录
#   2. 项目 "$PROJECT_NAME" 已创建（先执行 replay_testcase/010_create-project.sh）
#   3. 智能体空间 "$WORKSPACE_NAME" 已创建（先执行 replay_testcase/012_create-workspace.sh）
#   4. 空间已关联场景智能体资源（先执行 replay_testcase/013_workspace-resources.sh，
#      触发运行依赖可用资源；跳过 013 直接执行可能因空间无资源而失败）
#
# 运行：bash replay_testcase/014_workspace-runs.sh（默认显示浏览器窗口）
# 如需无头模式：HEADED=0 bash replay_testcase/014_workspace-runs.sh
#
# 翻译决断：
#   1. 用例原文项目名/空间名与 test-data.sh 批次数据不一致，统一使用
#      $PROJECT_NAME / $WORKSPACE_NAME（差异记入 test-plan §七）
#   2. "点击 [智能体空间]名称" 决断为点击 012 创建的空间名称（进入其概览）
#   3. 两次 [触发运行] 点击语义不同：第一次为打开触发页面，第二次为提交；
#      提示文本录入介于两者之间
#   4. 预期"运行页面生成一条执行历史记录"：运行构建为异步任务，仅断言历史
#      记录生成（特征文本"执行历史"），不断言运行最终状态（成功/失败）——
#      构建结果依赖远端资源，超出本用例验证范围

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
require_vars ASDM_USER ASDM_PASS ORG_NODE PROJECT_NAME WORKSPACE_NAME RUN_PROMPT

# ---------- 操作步骤 ----------

# step 1: test01 登录 → 管理后台 → 组织与项目 → 组织节点 → 项目页面
echo "[step 1] test01 登录"
login
goto_admin_console
goto_org_project
click_tree_node "$ORG_NODE" || exit 1
echo "[step 1] 点击项目: $PROJECT_NAME"
click_by_text "$PROJECT_NAME" '项目名称'
ab_wait 1500

# step 2: 右侧工作区打开 [智能体空间] 页面
# 精确匹配优先：避免"智能体空间"作为 [新建智能体空间] 按钮的子串被误点
echo "[step 2] 打开 [智能体空间] 页面"
click_by_exact '智能体空间' '智能体空间导航'
ab_wait 1000

# step 3: 点击 [智能体空间] 名称（012 创建），进入 [概览]
echo "[step 3] 点击智能体空间: $WORKSPACE_NAME"
# 空间名 heading 对 JS 合成 click 不响应（返回 ok 但不跳转），
# 须用 click_by_heading 走 agent-browser 坐标点击（真实鼠标事件）
click_by_heading "$WORKSPACE_NAME" '智能体空间名称'
# 详情页判定用 URL 匹配（列表页 .../workspaces 无尾斜杠，详情页
# .../workspaces/<id>）——快照特征文本已随平台改版移除
ws_detail=""
for ((i = 0; i < 20; i++)); do
    case "$(agent-browser get url 2>/dev/null)" in
        *_workspaces/workspaces/*) ws_detail=1; break;;
        *) ab_wait 1000;;
    esac
done
if [ -n "$ws_detail" ]; then
    echo "  [断言通过] 智能体空间详情页出现"
else
    echo "  [失败] 未进入智能体空间详情页（持续加载中或点击未生效）" >&2; exit 1
fi

# step 4: 点击 [运行] 按钮，进入运行页面
# 精确匹配优先："运行"短文本，防止误点含"运行"的其他元素
echo "[step 4] 点击 [运行]"
click_by_exact '运行' '运行导航'
ab_wait 1000

# step 5: 点击 [触发运行] 按钮，进入触发智能体空间运行页面
echo "[step 5] 点击 [触发运行]（进入触发页面）"
click_by_text '触发运行' '触发运行按钮'
ab_wait 1500

# step 6: 在 [提示文本] 框中输入运行指令
echo "[step 6] 录入提示文本"
fill_by_any_label "$RUN_PROMPT" '提示文本' '提示词'

# 【环境守卫】流水线服务器可用性检测（级联豁免显性化）：
# 触发运行依赖项目 GitHub 仓库配置（011）产出 GitHub Action 服务器；
# 011 因 GH_TOKEN 占位豁免时，此处 combobox 恒为"暂无可用的 GitHub Action
# 服务器"且提交按钮禁用——提前报错说明根因，避免提交静默无效后断言失败难排查
snap=$(snap_i)
if printf '%s' "$snap" | grep -q '暂无可用的 GitHub Action 服务器'; then
    echo "  [失败] 流水线服务器不可用（暂无 GitHub Action 服务器）——级联依赖 011 项目配置（GitHub 仓库 + GH_TOKEN），011 豁免时 014 无法触发运行" >&2
    WARN=$((WARN+1))
    finish
fi

# step 7: 点击 [触发运行] 按钮（提交运行）
echo "[step 7] 点击 [触发运行]（提交）"
click_by_text '触发运行' '触发运行提交按钮'
ab_wait 2000

# ---------- 预期结果断言 ----------

# 预期结果 1: 运行页面生成一条执行历史记录（异步轮询，§7.3）
echo "[断言] 运行页面生成执行历史记录"
ok=""
for ((i = 0; i < 30; i++)); do
    snap=$(snap_i)
    case "$snap" in
        *'执行历史'*) ok=1; break;;
    esac
    sleep 1
done
if [ -n "$ok" ]; then
    echo "  [断言通过] 运行页面已生成执行历史记录"
else
    echo "  [断言失败] 运行页面未见执行历史记录" >&2
    WARN=$((WARN+1))
fi

# ---------- 收尾 ----------
finish
