#!/bin/bash
# 由 005_create-user.md 翻译而来（测试用例 markdown → agent-browser）
#
# 通用操作已抽取至 common.sh（快照 ref 驱动），本脚本仅保留用例业务步骤：
#   管理后台 → 平台级设置 → 用户 → 创建用户（含角色映射）
#
# 前置条件（不自动级联，缺失即报错）：
#   1. 登录态：goto_admin_console 内置 login 自愈（未登录自动登录、
#      身份不符自动退出换号），可独立执行
#
# 运行：bash replay_testcase/005_create-user.sh（默认显示浏览器窗口）
# 如需无头模式：HEADED=0 bash replay_testcase/005_create-user.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/../common/common.sh"

# 统一测试数据：data/test-data.sh（含全部用例数据，环境变量优先）
DATA_DIR="${SCRIPT_DIR}/../data"
load_data_file "${DATA_DIR}/test-data.sh"


ab_init
require_vars ASDM_USER ASDM_PASS NEW_USER_EMAIL NEW_USER_PASS NEW_USER_ROLE NEW_USER_ORG

# ---------- 操作步骤 ----------

# step 1: 用户进入 ASDM管理后台 首页
goto_admin_console

# step 2: 点击左下角 [平台级设置] 按钮
echo "[step 2] 进入 [平台级设置]"
goto_platform_settings

# step 3: 点击 [用户] Tab页签
echo "[step 3] 点击 [用户] Tab页签"
click_tab '用户'

# step 4: 点击 [+创建用户] 按钮
echo "[step 4] 点击 [+创建用户]"
click_by_text '创建用户' '创建用户按钮'
# 弹窗断言（标题可能为 新建用户 或 创建用户）
snap=$(snap_i)
case "$snap" in
    *新建用户*|*创建用户*) : ;;
    *) echo "  [失败] 弹窗未出现: 新建用户/创建用户" >&2; exit 1;;
esac

# step 5: [创建用户] 信息录入 —— 邮箱 / 密码 / 姓 / 名
echo "[step 5] 录入用户基本信息"
fill_by_any_label "$NEW_USER_EMAIL" '新用户邮箱' '邮箱'
fill_by_any_label "$NEW_USER_PASS" '初始密码' '密码'
fill_by_label '姓' "$NEW_USER_LAST" '姓输入框'
fill_by_label '名' "$NEW_USER_FIRST" '名输入框'

# step 6: 新增角色映射
echo "[step 6] 新增角色映射"
click_by_text '新增角色映射' '新增角色映射按钮'
ab_wait 500

# 角色下拉定位：快照中 [未绑定组织] 按钮行之前最近的 combobox 即角色下拉。
# 【勿按"最后 N 个 combobox"取】页面右下角 DigiWorker 聊天浮层自带
# combobox "无可用实例"，会挤占倒数位置导致误选 [项目] 下拉框，
# "组织管理员" 选到项目框上必然落空 → 创建按钮保持禁用 → 提交静默无效。
role_cb=$(snap_i | awk '
    /- button "未绑定组织"/ { exit }
    /- combobox/ { match($0, /e[0-9]+/); r = substr($0, RSTART, RLENGTH) }
    END { print r }')
[ -n "$role_cb" ] || { echo "  [失败] 未找到角色下拉框" >&2; exit 1; }
echo "  角色映射 [$NEW_USER_ROLE] → 组织 [$NEW_USER_ORG]"
select_by_native "$role_cb" "$NEW_USER_ROLE" '角色下拉框'
# 校验角色已选上（combobox 行值 = 目标角色），未生效即硬失败
snap=$(snap_i)
printf '%s\n' "$snap" | grep -q -- "- combobox \[.*\]: ${NEW_USER_ROLE}\$" \
    || { echo "  [失败] 角色未选为: $NEW_USER_ROLE" >&2; exit 1; }

# 选择角色后绑定组织：组织选择器是按钮（未绑定时文本"未绑定组织"），
# 点击展开组织搜索树（body 下 React portal 浮层），输入组织名过滤后
# 点击精确匹配的组织节点（过滤后目标子组织节点自动展开出现）。
click_by_exact '未绑定组织' '组织选择器（未绑定态）'
ab_wait 800
sref=$(extract_ref "$(snap_i)" '- searchbox "搜索组织') \
    || { echo "  [失败] 未找到组织搜索框" >&2; exit 1; }
agent-browser fill "@${sref}" "$NEW_USER_ORG" >/dev/null
# 轮询等待搜索过滤完成、目标组织节点出现（过滤异步渲染，固定等待不可靠）
oref=""
for ((i = 0; i < 10; i++)); do
    oref=$(ref_by_exact "$NEW_USER_ORG") && break
    ab_wait 500
done
[ -n "$oref" ] || { echo "  [失败] 组织树中未找到: $NEW_USER_ORG" >&2; exit 1; }
agent-browser click "@${oref}" >/dev/null
# 校验组织绑定已生效：按钮文本由"未绑定组织"变为目标组织名。
# 【关键】此校验失败必须硬退出——组织未绑定时 [创建用户] 按钮保持禁用，
# 点击无效、提交从未发生，脚本会在断言处静默假失败。
bound=1
for ((i = 0; i < 10; i++)); do
    snap=$(snap_i)
    case "$snap" in
        *"- button \"${NEW_USER_ORG}\""*) bound=0; break;;
        *) ab_wait 500;;
    esac
done
[ "$bound" -eq 0 ] || { echo "  [失败] 组织绑定未生效: ${NEW_USER_ORG}（仍为未绑定组织）" >&2; exit 1; }
echo "  [绑定成功] 角色 [$NEW_USER_ROLE] + 组织 [$NEW_USER_ORG]"

# step 7: 点击 [创建用户] 按钮（组织已校验绑定，按钮必然启用）
echo "[step 7] 点击 [创建用户]"
click_by_exact '创建用户' '创建用户按钮'
ab_wait 1500

# ---------- 预期结果断言 ----------

# 预期结果 1: 用户列表中出现新用户 "$NEW_USER_EMAIL"
# 注意：平台创建用户成功后弹窗不会自动关闭（实测确认），需主动点击 [关闭]。
# 先轮询确认新用户邮箱出现在列表中（创建成功），再关闭弹窗并断言已关闭。
echo "[断言] 用户列表中出现: $NEW_USER_EMAIL"
# 注意：必须匹配列表行（cell），否则弹窗输入框的 value（textbox 行）会误判为通过
shown=1
for ((i = 0; i < 10; i++)); do
    snap=$(snap_i)
    case "$snap" in
        *"cell \"$NEW_USER_EMAIL\""*) shown=0; break;;
        *) ab_wait 500;;
    esac
done
if [ "$shown" -eq 0 ]; then
    echo "  [断言通过] 用户列表中出现 $NEW_USER_EMAIL"
else
    echo "  [断言失败] 用户列表中出现 $NEW_USER_EMAIL" >&2; WARN=$((WARN+1))
fi

# 若创建弹窗仍打开（平台行为：成功后不自动关闭），主动点击 [关闭]
snap=$(snap_i)
if case "$snap" in *'textbox "新用户邮箱'*) true;; *) false;; esac; then
    echo "[收尾] 创建成功但弹窗未自动关闭，点击 [关闭]"
    click_by_exact '关闭' '关闭弹窗按钮'
    ab_wait 800
fi

echo "[断言] 创建用户弹窗已关闭"
closed=1
for ((i = 0; i < 10; i++)); do
    snap=$(snap_i)
    case "$snap" in
        *'textbox "新用户邮箱'*) ab_wait 500;;
        *) closed=0; break;;
    esac
done
if [ "$closed" -eq 0 ]; then
    echo "  [断言通过] 创建用户弹窗已关闭"
else
    echo "  [断言失败] 创建用户弹窗未关闭" >&2; WARN=$((WARN+1))
fi

# ---------- 收尾（§8.3） ----------
finish
