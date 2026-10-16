#!/bin/bash
# 由 021_organization-agent-config.md 翻译而来（测试用例 markdown → agent-browser）
#
# 通用操作已抽取至 common.sh（快照 ref 驱动），本脚本仅保留用例业务步骤：
#   管理员登录 → 管理后台 [组织] 菜单 → 组织树 organization → Agent设置 → 保存配置
#
# 前置条件（不自动级联，缺失即报错）：
#   1. 用户已完成系统登录（管理员身份，先执行 replay_testcase/001_system-login.sh）
#   2. 组织 "organization" 已存在
#
# 运行：bash replay_testcase/021_organization-agent-config.sh（默认显示浏览器窗口）
# 如需无头模式：HEADED=0 bash replay_testcase/021_organization-agent-config.sh
#
# 翻译决断：
#   1. 用例未指明登录身份：Agent 配置属组织管理功能，决断为超级管理员
#      （公共凭据 ASDM_USER/ASDM_PASS）
#   2. 用例前置"组织 organization 已存在"：当前平台组织树仅有顶层组织 rtdl
#      （实跑快照核对），organization 不存在——以现存顶层组织代跑验证流程，
#      ORG_CONFIG_NAME 默认 rtdl；平台创建 organization 后可覆盖（差异记入
#      test-plan §七）
#   3. "点击 [组织] 菜单"："组织"是侧边栏 [组织与项目] 的前缀，必须精确匹配
#      （click_by_exact）防止误点；实跑核对有效（点击后组织树渲染）
#   4. Agent设置入口与 020 同（实跑核对）：组织节点行内 [组织操作]（…）按钮
#      → 菜单 [Agent设置] 菜单项（点击节点本身会跳转组织单元页）
#   5. 用例步骤 5"配置 Agent 相关参数"未给具体值，与 020 同决断：仅软断言
#      关键配置项存在，保持现有配置直接保存以验证保存链路

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/../common/common.sh"

# 统一测试数据：data/test-data.sh（含全部用例数据，环境变量优先）
DATA_DIR="${SCRIPT_DIR}/../data"
load_data_file "${DATA_DIR}/test-data.sh"


ab_init
require_vars ASDM_USER ASDM_PASS ORG_CONFIG_NAME

# ---------- 操作步骤 ----------

# step 1: 用户进入 ASDM 管理后台 首页
# 编排中 010-017 会把浏览器身份切到 test01，此处先幂等恢复
# super-admin 登录态（当前身份不符时 login 自动退出重登），再进管理后台
login
goto_admin_console

# step 2(决断修正): 点击 [组织] 菜单，进入 组织 页面
# 实跑核对：管理后台无独立 [组织] 菜单（侧边栏仅 平台概览/效能洞察/邀请中心/
# 创建顶层组织/平台级设置；"组织与项目"抽屉的组织树无 [组织操作] 菜单）——
# 组织管理唯一入口为 平台级设置 → [组织] Tab，与 020 同路径（差异记入 test-plan）
echo "[step 2] 进入 [平台级设置] → [组织] Tab"
goto_platform_settings
click_tab '组织'
ab_wait 1500

# 预期结果 1: 成功从首页进入 组织 页面（组织树渲染出目标组织）
if wait_for_text "$ORG_CONFIG_NAME" 10; then
    echo "  [断言通过] 已进入组织页面（组织树含 ${ORG_CONFIG_NAME}）"
else
    echo "  [断言失败] 组织树未见 $ORG_CONFIG_NAME" >&2
    WARN=$((WARN+1))
fi

# step 3(决断修正): 定位组织节点行内 [组织操作]（…）按钮并展开菜单
# （不点击节点本身——点击会跳转组织单元页 /org-<名>；树默认折叠时先展开，
# 与 020 实跑核对结论一致）
expand_all_tree
ab_wait 1000
op=$(snapshot_line_after "$ORG_CONFIG_NAME" 'button') \
    || { echo "  [失败] 未找到 [$ORG_CONFIG_NAME] 行内 [组织操作] 按钮" >&2; exit 1; }
agent-browser click "@${op}" >/dev/null
ab_wait 800

# step 4(决断修正): [组织操作] 菜单 → [Agent设置] 菜单项
# （用例原文"点击 [Agent设置] 按钮"实为组织操作下拉菜单项）
echo "[step 4] [组织操作] 菜单 → [Agent设置]"
click_by_exact 'Agent设置' 'Agent设置菜单项'
ab_wait 1500

# 预期结果 2: 成功进入 organization 的 Agent配置 页面
assert_snapshot_contains 'Agent设置' "已进入 ${ORG_CONFIG_NAME} 的 Agent设置 面板"

# step 5: 配置 Agent 相关参数
# 翻译决断：用例未给具体参数值，仅软断言关键配置项存在（见头部决断 3）
echo "[step 5] 校验 Agent 配置项存在"
assert_snapshot_contains '智能体空间' '配置项：允许创建在线智能体空间/在线知识空间'
assert_snapshot_contains '额度' '配置项：总额度'

# step 6: 点击 [保存] 按钮（实跑核对：按钮文案为"保存"，
# 非用例原文"保存配置"，与 020 一致）
echo "[step 6] 点击 [保存]"
click_by_exact '保存' '保存按钮'

# ---------- 预期结果断言 ----------

# 预期结果 3: Agent 配置保存成功（轮询：成功提示出现 或 面板关闭，§7.3）
ok=""
for ((i = 0; i < 15; i++)); do
    snap=$(snap_i)
    case "$snap" in
        *'保存成功'*|*'成功'*) ok=1; break;;
    esac
    case "$snap" in
        *'Agent设置" ['*) ;;   # Agent设置面板仍打开，继续等待
        *) ok=1; break;;       # 面板已关闭（保存完成）
    esac
    sleep 1
done
if [ -n "$ok" ]; then
    echo "  [断言通过] Agent 配置保存成功"
else
    echo "  [断言失败] 未见保存成功特征" >&2
    WARN=$((WARN+1))
fi

# ---------- 收尾 ----------
finish
