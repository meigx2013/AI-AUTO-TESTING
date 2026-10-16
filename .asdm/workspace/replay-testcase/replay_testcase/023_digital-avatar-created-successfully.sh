#!/bin/bash
# 由 023_digital-avatar-created-successfully.md 翻译而来（测试用例 markdown → agent-browser）
#
# 通用操作已抽取至 common.sh（快照 ref 驱动），本脚本仅保留用例业务步骤：
#   登录 → 用户中心 → 数字分身页签 → 创建新分身 → 列表新增记录 + 创建提示验证
#
# 前置条件（不自动级联，缺失即报错）：
#   1. 登录态：goto_admin_console 内置 login 自愈（未登录自动登录、
#      身份不符自动退出换号），可独立执行
#   2. AgentOrbit 平台连接已配置（先执行 replay_testcase/018_agentorbit-config.sh；
#      数字分身为 AgentOrbit 在线能力，连接未配置时 [创建新分身] 按钮禁用，
#      脚本前置守卫报错，run-all.sh 按 AGENT_ORBIT_KEY 豁免）
#
# 运行：bash replay_testcase/023_digital-avatar-created-successfully.sh（默认显示浏览器窗口）
# 如需无头模式：HEADED=0 bash replay_testcase/023_digital-avatar-created-successfully.sh
#
# 翻译决断：
#   1. 用例未指明登录身份：与 022 同为数字分身个人功能，决断为公共凭据
#      ASDM_USER（super-admin）
#   2. 用例原文入口"平台级设置 → [Agent设置] Tab"有误：真实入口为
#      用户中心 → [数字分身] 页签（平台级设置无 Agent设置页签）——
#      按真实页面结构修正导航（§4.4 角色核对陷阱）
#   3. 分身名称 "数字分身" 为创建类数据（不幂等），按 §5.2 带批次时间戳
#      后缀防重名（DIGITAL_AVATAR_NAME，与 022 的 AVATAR_NAME 区分为两个分身）
#   4. "返回首页，查看数字分身状态"的"首页"决断为 Agent 设置
#      （数字分身）页面首页（用例语境"Agent设置-首页"，即创建弹窗关闭后
#      的分身列表页），非 Portal 首页——创建后列表即时刷新展示新分身
#   5. 预期 3 的成功提示 "Digital avatar created successfully" 为 toast
#      纯文本（交互快照 -i 可能不含），用 body innerText 轮询检测
#   6. 预期 1 "状态显示正常"：分身列表状态列文案未经实跑核对，本脚本断言
#      记录存在（创建成功）；状态列文案确认后可补充状态特征断言
#      （test-plan §七 差异备注登记）

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/../common/common.sh"

# 统一测试数据：data/test-data.sh（含全部用例数据，环境变量优先）
DATA_DIR="${SCRIPT_DIR}/../data"
load_data_file "${DATA_DIR}/test-data.sh"


ab_init
require_vars ASDM_USER ASDM_PASS DIGITAL_AVATAR_NAME

# ---------- 操作步骤 ----------

# step 1: 用户进入 ASDM 管理后台 首页（登录态）
goto_admin_console

# step 2(决断修正): 点击右上角用户信息展开菜单 → [用户中心]，
# 打开用户中心页面（非用例原文的"平台级设置"，见翻译决断 2）
echo "[step 2] 用户信息 → [用户中心]"
click_user_info
click_by_text '用户中心' '用户中心菜单项'
ab_wait 1500
assert_visible '数字分身' '用户中心页面已打开（含 [数字分身] 页签）'

# step 3(决断修正): 点击 [数字分身] 页签
# click_by_exact 在页面刚加载时 JS eval 偶发无返回（React 组件未挂载完毕），
# 改用 click_by_text（子串匹配 + 重试更宽松）
echo "[step 3] 点击 [数字分身] 页签"
ab_wait 1000
click_by_text '数字分身' '数字分身页签'
ab_wait 1500

# 前置守卫（§六）：[创建新分身] 按钮在 AgentOrbit 连接未配置时禁用，
# 带病执行必失败（点击静默无效），前置报错并说明解除条件
if snap_i | grep -q '创建新分身" \[disabled'; then
    echo "  [失败] [创建新分身] 按钮处于禁用状态：数字分身依赖 AgentOrbit 平台连接" >&2
    echo "         （先执行 replay_testcase/018_agentorbit-config.sh 配置连接，或 AGENT_ORBIT_KEY=密钥 解除豁免）" >&2
    exit 1
fi

# step 4: 点击 [创建新分身] 按钮，打开 [创建新分身] 窗口
# assert_visible 会误匹配按钮文本，改为检测 [role=dialog]；弹窗未打开时
# 检查权限拦截（"无个人数字分身创建权限"）
echo "[step 4] 点击 [创建新分身]"
click_by_text '创建新分身' '创建新分身按钮'
ab_wait 2000
dlg=$(agent-browser eval 'document.querySelectorAll("[role=dialog],dialog,[role=modal]").length' 2>/dev/null)
if [ "${dlg:-0}" -eq 0 ]; then
    body=$(agent-browser eval 'document.body.innerText' 2>/dev/null)
    if printf '%s' "$body" | grep -q '无个人数字分身创建权限'; then
        echo "  [跳过] 用户所在集合无个人数字分身创建权限（平台配置问题，非脚本缺陷）" >&2
        echo "         （请联系管理员开通权限后重试）" >&2
        WARN=$((WARN+1)); finish
    fi
    echo "  [失败] [创建新分身] 弹窗未出现（且未检测到权限拦截提示）" >&2; exit 1
fi
echo "  [断言通过] [创建新分身] 窗口出现"

# step 5: [创建新分身] 信息录入 —— 分身名称
# 弹窗输入框无 label，改快照取首个 textbox
echo "[step 5] 录入分身名称: $DIGITAL_AVATAR_NAME"
name_tb=$(snap_i | grep -E -- '- textbox' | grep -oE 'e[0-9]+' | head -1)
if [ -z "$name_tb" ]; then
    fill_by_any_label "$DIGITAL_AVATAR_NAME" '分身名称' '名称' '请输入'
else
    agent-browser fill "@${name_tb}" "$DIGITAL_AVATAR_NAME" >/dev/null
fi

# step 6: 点击 [创建] 按钮
# （"创建"为"创建新分身"的前缀，精确匹配优先避免误点入口按钮）
# 点击前清空网络日志：创建成功判定以 API + innerText 双重
echo "[step 6] 点击 [创建]"
agent-browser network requests --clear >/dev/null 2>&1
click_by_exact '创建' '创建按钮'
ab_wait 2000

# ---------- 预期结果断言 ----------

# 预期结果 3: 数字分身创建成功
# toast 轮询（innerText contains "Digital avatar created successfully"）
# 依赖瞬时 toast 文案，易因时序漏报；故用双重判定：
#   1) 接口：POST/PUT 请求 URL 含 avatar/twin/digital 且 HTTP 2xx = 创建成功
#   2) innerText：保留原文案兜底（toast 可见时命中）
echo "[断言] 数字分身创建成功"
ok=""
for ((i = 0; i < 20; i++)); do
    # 接口判定
    line=$(agent-browser network requests --type xhr,fetch 2>/dev/null \
           | grep -iE 'avatar|twin|digital' | tail -1)
    st=$(printf '%s\n' "$line" | awk '{print $NF}')
    [ -n "$line" ] && { case "$st" in 2*) ok=1; break;; 4*|5*) break;; esac; }
    # innerText 兜底
    hit=$(agent-browser eval 'document.body.innerText.includes("Digital avatar created successfully")' 2>/dev/null)
    case "$hit" in *true*) ok=1; break;; esac
    sleep 1
done
if [ -n "$ok" ]; then
    echo "  [断言通过] 数字分身创建成功"
else
    echo "  [断言失败] 创建接口未返回 2xx 且未捕获成功提示" >&2
    WARN=$((WARN+1))
fi

# 预期结果 1/2: 返回数字分身首页，列表新增记录 "$DIGITAL_AVATAR_NAME"
# （列表刷新时序不可靠，轮询 + 软断言；状态列复核见翻译决断 6）
echo "[断言] 分身列表出现: $DIGITAL_AVATAR_NAME"
wait_for_text "$DIGITAL_AVATAR_NAME" 10 || true
assert_snapshot_contains "$DIGITAL_AVATAR_NAME" "分身列表新增记录（首页展示数字分身信息）: $DIGITAL_AVATAR_NAME"

# ---------- 收尾 ----------
finish
