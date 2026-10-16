#!/bin/bash
# 由 022_personal-avatar.md 翻译而来（测试用例 markdown → agent-browser）
#
# 通用操作已抽取至 common.sh（快照 ref 驱动），本脚本仅保留用例业务步骤：
#   登录 → 用户信息 → 用户中心 → 数字分身页签 → 创建新分身 → 分身列表新增记录
#
# 前置条件（不自动级联，缺失即报错）：
#   1. 登录态：goto_admin_console 内置 login 自愈（未登录自动登录、
#      身份不符自动退出换号），可独立执行
#   2. AgentOrbit 平台连接已配置（数字分身为 AgentOrbit 在线能力：
#      平台级设置 → AgentOrbit 页签填写密钥并保存；未配置时
#      [创建新分身] 按钮禁用，本脚本前置守卫报错）
#
# 运行：bash replay_testcase/022_personal-avatar.sh（默认显示浏览器窗口）
# 如需无头模式：HEADED=0 bash replay_testcase/022_personal-avatar.sh
#
# 翻译决断：
#   1. 用例未指明登录身份：分身属用户个人功能，使用公共凭据
#      ASDM_USER（super-admin）
#   2. 用例写"平台级设置 → Agent设置 Tab"：实跑快照核对发现平台级设置
#      无"Agent设置"页签（仅 AgentOrbit 连接配置页签，018 用例对应物且为空
#      文件）；分身实际入口为 用户中心（/settings/user-profile）→ [数字分身]
#      页签（?tab=twins）——按真实页面结构修正导航（§4.4 角色核对陷阱）
#   3. [创建新分身] 按钮在 AgentOrbit 连接未配置时禁用（§8-2 平台静默
#      拦截特性），脚本前置守卫检测并明确报错；run-all.sh 按
#      AGENT_ORBIT_KEY 占位豁免（§九）
#   4. 分身名称 "个人数字分身" 为创建类数据（不幂等），按 §5.2 带批次
#      时间戳后缀防重名
#   5. "分身列表中增加一条记录"不产生动作，并入预期结果断言（§4.1）

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/../common/common.sh"

# 统一测试数据：data/test-data.sh（含全部用例数据，环境变量优先）
DATA_DIR="${SCRIPT_DIR}/../data"
load_data_file "${DATA_DIR}/test-data.sh"


ab_init
require_vars ASDM_USER ASDM_PASS AVATAR_NAME

# ---------- 操作步骤 ----------

# step 1: 用户进入 ASDM 管理后台 首页（登录态）
goto_admin_console

# step 2(决断修正): 点击右上角用户信息展开菜单 → [用户中心]，
# 打开用户中心页面（/settings/user-profile；非用例原文的"平台级设置"）
echo "[step 2] 用户信息 → [用户中心]"
click_user_info
click_by_text '用户中心' '用户中心菜单项'
ab_wait 1500
assert_visible '数字分身' '用户中心页面已打开（含 [数字分身] 页签）'

# step 3(决断修正): 点击 [数字分身] 页签（进入 ?tab=twins）
echo "[step 3] 点击 [数字分身] 页签"
click_by_exact '数字分身' '数字分身页签'
ab_wait 1500

# 前置守卫（§六）：[创建新分身] 按钮在 AgentOrbit 连接未配置时禁用，
# 带病执行必失败（点击静默无效），前置报错并说明解除条件
if snap_i | grep -q '创建新分身" \[disabled'; then
    echo "  [失败] [创建新分身] 按钮处于禁用状态：数字分身依赖 AgentOrbit 平台连接" >&2
    echo "         （平台级设置 → AgentOrbit 页签配置密钥并保存后重试；对应 018 用例为空文件未转换）" >&2
    exit 1
fi

# step 4: 点击 [创建新分身] 按钮，打开 [创建新分身] 窗口
# assert_visible '创建新分身' 会误匹配按钮文本（弹窗未实际打开也通过），
# 故检测 [role=dialog] 元素；点击后若弹窗未出现，检查是否为平台权限拦截
# （"无个人数字分身创建权限"）——此为平台配置问题（AgentOrbit 连接已保存
# 但用户所在集合无创建权限/实例数为 0），WARN 豁免
echo "[step 4] 点击 [创建新分身]"
click_by_text '创建新分身' '创建新分身按钮'
ab_wait 2000
# 检测弹窗是否真正打开（role=dialog 或 modal 元素出现）
dlg=$(agent-browser eval 'document.querySelectorAll("[role=dialog],dialog,[role=modal]").length' 2>/dev/null)
if [ "${dlg:-0}" -eq 0 ]; then
    # 弹窗未打开，检查是否为权限拦截
    body=$(agent-browser eval 'document.body.innerText' 2>/dev/null)
    if printf '%s' "$body" | grep -q '无个人数字分身创建权限'; then
        echo "  [跳过] 用户所在集合无个人数字分身创建权限（平台配置问题，非脚本缺陷）" >&2
        echo "         （AgentOrbit 连接已保存但用户无创建权限/实例数为 0；" >&2
        echo "          请联系管理员开通权限后重试）" >&2
        WARN=$((WARN+1)); finish
    fi
    echo "  [失败] [创建新分身] 弹窗未出现（且未检测到权限拦截提示）" >&2; exit 1
fi
echo "  [断言通过] [创建新分身] 窗口出现"

# step 5: [创建新分身] 信息录入 —— 分身名称
# 弹窗输入框无 label 标签，fill_by_any_label 候选标签 '分身名称'/'名称'
# 落空；改为快照取弹窗内首个 textbox 按角色定位（textbox 无可见
# placeholder 时仍可定位）
echo "[step 5] 录入分身名称: $AVATAR_NAME"
name_tb=$(snap_i | grep -E -- '- textbox' | grep -oE 'e[0-9]+' | head -1)
if [ -z "$name_tb" ]; then
    # 兜底：fill_by_any_label（placeholder 可能含候选关键词）
    fill_by_any_label "$AVATAR_NAME" '分身名称' '名称' '请输入'
else
    agent-browser fill "@${name_tb}" "$AVATAR_NAME" >/dev/null
fi

# step 6: 点击 [创建] 按钮
# （"创建"为"创建新分身"的前缀，精确匹配优先避免误点入口按钮）
echo "[step 6] 点击 [创建]"
click_by_exact '创建' '创建按钮'
ab_wait 2000

# ---------- 预期结果断言 ----------

# 预期结果 1/2: 分身列表中增加一条记录 "$AVATAR_NAME"，创建成功
# （列表刷新时序不可靠，轮询 + 软断言）
echo "[断言] 分身列表出现: $AVATAR_NAME"
wait_for_text "$AVATAR_NAME" 10 || true
assert_snapshot_contains "$AVATAR_NAME" "分身列表新增记录: $AVATAR_NAME"

# ---------- 收尾 ----------
finish
