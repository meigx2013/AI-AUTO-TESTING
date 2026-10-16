#!/bin/bash
# 由 011_project-config.md 翻译而来（测试用例 markdown → agent-browser）
#
# 通用操作已抽取至 common.sh（快照 ref 驱动），本脚本仅保留用例业务步骤：
#   test01 登录 → 管理后台 → 组织与项目 → 组织节点 → 项目 → 其他 → 添加仓库配置 → 检测可用性
#
# 前置条件（不自动级联，缺失即报错）：
#   1. 用户 test01@asdm.ai 已完成系统登录
#   2. 项目 "$PROJECT_NAME" 已创建（先执行 replay_testcase/010_create-project.sh）
#
# 运行：bash replay_testcase/011_project-config.sh（默认显示浏览器窗口）
# 如需无头模式：HEADED=0 bash replay_testcase/011_project-config.sh

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
require_vars ASDM_USER ASDM_PASS ORG_NODE PROJECT_NAME REPO_URL REPO_BRANCH GH_TOKEN

# ---------- 操作步骤 ----------

# step 1: 以 test01 完成系统登录（已存在登录态则跳过，与 010 一致）
echo "[step 1] test01 登录"
login

# step 2: 用户进入 ASDM管理后台 首页（test01 登录态）
goto_admin_console

# step 3: 打开 [组织与项目] 导航
echo "[step 3] 打开 [组织与项目] 导航"
goto_org_project

# step 4: 组织层级树中，点击组织节点 "$ORG_NODE"
echo "[step 4] 点击组织节点: $ORG_NODE"
click_tree_node "$ORG_NODE" || exit 1

# step 5: 点击项目列表中的 "$PROJECT_NAME"，进入项目页面
echo "[step 5] 点击项目: $PROJECT_NAME"
click_by_text "$PROJECT_NAME" '项目名称'
ab_wait 1500
assert_snapshot_contains "$PROJECT_NAME" "项目页面已打开（含项目名称）"

# step 6: 右侧工作区打开 [项目设置] 页面（用例原文步骤 3：项目默认落在概览页，
# "其他"Tab 位于项目设置页内，须先进项目设置；
# 侧边栏入口为 Remix data-discover 链接，坐标点击静默失效，ab_click 的
# JS el.click() 优先路径实测可靠）
echo "[step 6] 打开 [项目设置] 页面"
click_by_exact '项目设置' '项目设置侧边栏入口'
ab_wait 1500

# step 7: 点击 [其他] Tab页签
echo "[step 7] 点击 [其他] Tab页签"
click_tab '其他'

# step 8: 点击 [+添加仓库配置] 按钮，打开 [添加仓库配置] 窗口
echo "[step 8] 点击 [+添加仓库配置]"
click_by_text '添加仓库配置' '添加仓库配置按钮'
assert_visible '添加仓库配置' '[添加仓库配置] 弹窗出现'

# step 9: [添加仓库配置] 信息录入
# 弹窗表单为原生 select + 无标签 textbox，且 select 数量随平台状态浮动
# ——DigiWorker 实例下拉（"无可用实例"）可额外出现，按位置取 combobox[1]/[2]
# 会错位到"实例/类型"上；agent-browser select 匹配不到选项值时静默无操作
# （exit 0、值不变），鉴权始终停在 none，Token 框不渲染。定位策略：
#   1. 按选项内容识别下拉：含 "github" 选项 = 仓库类型；含 "Token" 选项 = 鉴权方式
#   2. 先完成两个下拉选择、再填文本框——切换下拉会重渲染表单（URL placeholder
#      随类型变化），先填后切会被清空（先选鉴权方式，再填 URL/Token）
#   3. 文本框按 placeholder 前缀定位（无标签可依）：URL="https://git…、
#      分支="main"、Token="ghp_…（鉴权切 token 后才懒渲染）
#   4. select 传值与选项 value 字面一致：类型 'github'、鉴权 'token'（小写）
find_cb_by_option() {  # $1=选项文本（字面前缀）→ stdout: 所属 combobox 的 eN
    snap_i | awk -v pat="- option \"${1}" '
        /- combobox / { ref = $0; sub(/.*ref=/, "", ref); sub(/\].*/, "", ref) }
        index($0, pat) { print ref; exit }
    '
}
echo "[step 9] 录入仓库配置"
type_cb=$(find_cb_by_option 'github')
[ -n "$type_cb" ] || { echo "  [失败] 未按选项内容识别到仓库类型下拉框" >&2; exit 1; }
select_by_native "$type_cb" 'github' '仓库源类型'
# 类型切换重渲染表单，鉴权下拉需重新定位后再选（先选鉴权，再填文本）
auth_cb=$(find_cb_by_option 'Token')
[ -n "$auth_cb" ] || { echo "  [失败] 未按选项内容识别到鉴权方式下拉框" >&2; exit 1; }
select_by_native "$auth_cb" 'token' '鉴权方式'
# Token 输入框在鉴权方式切 token 后懒渲染，轮询等待（页面 JS 大渲染慢）
tok_tb=""
for ((i = 0; i < 30; i++)); do
    tok_tb=$(snap_i | grep -E -- '- textbox "ghp_' | grep -oE 'e[0-9]+' | head -1)
    [ -n "$tok_tb" ] && break
    ab_wait 500
done
[ -n "$tok_tb" ] || { echo "  [失败] 未找到仓库Token输入框（鉴权方式切 token 后未渲染）" >&2; exit 1; }
url_tb=$(snap_i | grep -E -- '- textbox "https://git' | grep -oE 'e[0-9]+' | head -1)
br_tb=$(snap_i | grep -E -- '- textbox "main"' | grep -oE 'e[0-9]+' | head -1)
# 分支框兜底：取既非 URL 也非 Token 的那个 textbox
[ -n "$br_tb" ] || br_tb=$(refs_of_role textbox | grep -v -x -e "$url_tb" -e "$tok_tb" | head -1)
[ -n "$url_tb" ] || { echo "  [失败] 未找到仓库URL输入框" >&2; exit 1; }
[ -n "$br_tb" ] || { echo "  [失败] 未找到仓库分支输入框" >&2; exit 1; }
agent-browser fill "@${url_tb}" "$REPO_URL" >/dev/null
agent-browser fill "@${br_tb}" "$REPO_BRANCH" >/dev/null
agent-browser fill "@${tok_tb}" "$GH_TOKEN" >/dev/null

# step 10: 点击 [保存] 按钮
echo "[step 10] 点击 [保存]"
click_by_exact '保存' '保存按钮'
ab_wait 1500

# 预期结果 1: 仓库配置列表中增加一条记录
# 列表记录渲染仓库路径（REPO_NAME，如 "meigx2013/Ai-Fast"）而非
# 完整 URL（附 github/Token/活跃 徽标与检测可用性/编辑/删除操作），断言改
# 匹配 REPO_NAME
echo "[断言] 仓库配置列表中出现: $REPO_NAME"
assert_snapshot_contains "$REPO_NAME" "仓库配置列表中出现 $REPO_NAME"

# step 11: 点击新增记录右侧的 [检测可用性]
echo "[step 11] 点击 [检测可用性]"
# 清空网络请求日志：step 12 以 check-availability 接口返回为判定依据
agent-browser network requests --clear >/dev/null 2>&1
ref=$(ref_by_text '检测可用性') || ref=$(snapshot_line_after "$REPO_URL" 'button') \
    || { echo "  [失败] 未找到 [检测可用性] 按钮" >&2; exit 1; }
agent-browser click "@${ref}" >/dev/null
ab_wait 500

# step 12: 轮询检测接口返回判定结果（最多约 30s）
# 检测结果仅有瞬时 toast，a11y 快照与 innerText 均捕获不到；且页面右侧
# DigiWorker 面板常驻文本 "无可用实例" 会误命中 *'可用'* 模式。故以接口为准：
#   POST /api/project/projects/{pid}/settings/{sid}/check-availability
#   响应体 {"code":200,"message":"success"} → 检测成功
echo "[step 12] 等待检测结果（接口判定）"
ok=""
for ((i = 0; i < 30; i++)); do
    line=$(agent-browser network requests --type xhr,fetch 2>/dev/null | grep -F 'check-availability' | tail -1)
    rid=$(printf '%s\n' "$line" | grep -oE '^\[[0-9]+\.[0-9]+\]' | tr -d '[]')
    if [ -n "$rid" ]; then
        body=$(agent-browser network request "$rid" --json 2>/dev/null)
        # responseBody 为 JSON 转义串，成功特征 \"code\":200（grep -F 字面匹配，
        # 带反斜杠转义不会误匹配 CLI 输出顶层的 "status" 字段）
        if printf '%s' "$body" | grep -qF '\"code\":200'; then ok=1; break; fi
        st=$(printf '%s\n' "$line" | awk '{print $NF}')
        case "$st" in 4*|5*) break;; esac   # HTTP 4xx/5xx 直接判失败
    fi
    sleep 1
done

# 预期结果 2: 检测可用性成功（接口 code=200 / message=success）
echo "[断言] 检测可用性成功（接口判定）"
if [ -n "$ok" ]; then
    echo "  [断言通过] 仓库检测成功（check-availability 接口返回 success）"
else
    echo "  [断言失败] 仓库检测接口未返回成功" >&2; WARN=$((WARN+1))
fi

# ---------- 收尾（§8.3） ----------
finish
