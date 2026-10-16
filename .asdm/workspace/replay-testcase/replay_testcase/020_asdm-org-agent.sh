#!/bin/bash
# 由 020_asdm-org-agent.md 翻译而来（测试用例 markdown → agent-browser）
#
# 通用操作已抽取至 common.sh（快照 ref 驱动），本脚本仅保留用例业务步骤：
#   super-admin 登录 → 平台级设置 → 组织 Tab → 组织树 → 组织操作菜单 →
#   Agent设置 → 保存
#
# 前置条件（不自动级联，缺失即报错）：
#   1. 用户 super-admin@asdm.ai 已完成系统登录（先执行 replay_testcase/001_system-login.sh）
#   2. 组织 "$ASDM_ORG_NAME" 已存在（默认 rtdl；用例原文的 ASDM-Org 在当前
#      平台不存在，以现存顶层组织代跑，见头部决断 1）
#
# 运行：bash replay_testcase/020_asdm-org-agent.sh（默认显示浏览器窗口）
# 如需无头模式：HEADED=0 bash replay_testcase/020_asdm-org-agent.sh
#
# 翻译决断：
#   1. 用例前置"组织 ASDM-Org 已存在"：当前平台组织树仅有顶层组织 rtdl
#      （实跑快照核对），ASDM-Org 不存在——按"环境不一致以 test-data.sh
#      统一"原则，ASDM_ORG_NAME 默认 rtdl 代跑验证流程；平台创建 ASDM-Org
#      后可用 ASDM_ORG_NAME=ASDM-Org 覆盖（差异记入 test-plan §七）
#   2. Agent设置入口（实跑快照核对修正）：组织树中点击组织节点本身会跳转
#      组织单元页（/org-<名>），正确路径为——节点行内 [组织操作]（…）按钮
#      → 菜单 [Agent设置] 菜单项（用例原文"点击 [Agent设置] 按钮"实为菜单项）
#   3. 用例步骤 7"配置 Agent 相关参数……总额度/可用镜像根据对应环境选择"：
#      参数值环境相关且用例未给静态值，不代拟具体配置值——仅软断言关键
#      配置项存在（在线智能体空间/额度/可用镜像列表），保持现有配置直接
#      保存以验证保存链路（§4.3 提交类按钮注意必填项——保存按钮为"保存"，
#      实跑快照核对，非用例原文"保存配置"）
#   4. 预期 3 "配置保存成功"按保存后轮询成功提示或面板关闭断言（§7.3）

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/../common/common.sh"

# 统一测试数据：data/test-data.sh（含全部用例数据，环境变量优先）
DATA_DIR="${SCRIPT_DIR}/../data"
load_data_file "${DATA_DIR}/test-data.sh"


ab_init
require_vars ASDM_USER ASDM_PASS ASDM_ORG_NAME

# ---------- 操作步骤 ----------

# step 1: super-admin 进入 ASDM 管理后台 首页
# 编排中 010-017 会把浏览器身份切到 test01，此处先幂等恢复
# super-admin 登录态（当前身份不符时 login 自动退出重登），再进管理后台
login
goto_admin_console

# step 2: 点击左下角 [平台级设置]，右侧工作区打开平台级设置页面
echo "[step 2] 进入 [平台级设置]"
goto_platform_settings

# step 3: 点击 [组织] Tab页签
echo "[step 3] 点击 [组织] Tab页签"
click_tab '组织'
ab_wait 1500

# 预期结果 1: 成功从首页进入 平台级设置-组织 页面（组织树渲染出目标组织）
# 组织树数据异步拉取，冷加载可超 10s，轮询次数取 30
if wait_for_text "$ASDM_ORG_NAME" 30; then
    echo "  [断言通过] 已进入平台级设置-组织页面（组织树含 ${ASDM_ORG_NAME}）"
else
    echo "  [断言失败] 组织树未见 $ASDM_ORG_NAME" >&2
    WARN=$((WARN+1))
fi

# step 4(决断修正): 定位组织节点行内 [组织操作]（…）按钮并展开菜单
# （不点击节点本身——点击会跳转组织单元页；树默认折叠时先展开）
expand_all_tree
ab_wait 1000
op=$(snapshot_line_after "$ASDM_ORG_NAME" 'button') \
    || { echo "  [失败] 未找到 [$ASDM_ORG_NAME] 行内 [组织操作] 按钮" >&2; exit 1; }
agent-browser click "@${op}" >/dev/null
ab_wait 800

# step 5(决断修正): [组织操作] 菜单 → [Agent设置] 菜单项
echo "[step 5] [组织操作] 菜单 → [Agent设置]"
click_by_exact 'Agent设置' 'Agent设置菜单项'
ab_wait 1500

# 预期结果 2: 成功进入组织的 Agent设置 面板
assert_snapshot_contains 'Agent设置' "已进入 $ASDM_ORG_NAME 的 Agent设置 面板"

# step 6: 配置 Agent 相关参数
# 翻译决断：环境相关参数不代拟值，仅软断言关键配置项存在（见头部决断 3）
echo "[step 6] 校验 Agent 配置项存在"
assert_snapshot_contains '在线智能体空间' '配置项：允许创建在线智能体空间/在线知识空间'
assert_snapshot_contains '总额度' '配置项：总额度'
assert_snapshot_contains '可用镜像' '配置项：可用镜像列表'

# step 7: 点击 [保存] 按钮（实跑核对：按钮文案为"保存"，
# 非用例原文"保存配置"）
echo "[step 7] 点击 [保存]"
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
    echo "  [断言失败] 保存后 Agent设置 面板未关闭且无成功提示" >&2
    WARN=$((WARN+1))
fi

# ---------- 收尾 ----------
finish
