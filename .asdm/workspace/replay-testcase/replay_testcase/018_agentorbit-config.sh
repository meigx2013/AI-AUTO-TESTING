#!/bin/bash
# 由 018_agentorbit-config.md 翻译而来（测试用例 markdown → agent-browser）
#
# 通用操作已抽取至 common.sh（快照 ref 驱动），本脚本仅保留用例业务步骤：
#   管理后台 → 平台级设置 → AgentOrbit → 录入密钥 → [测试连接] → [保存配置]
#
# 前置条件（不自动级联，缺失即报错）：
#   1. 登录态：goto_admin_console 内置 login 自愈（未登录自动登录、
#      身份不符自动退出换号），可独立执行
#   2. AGENT_ORBIT_KEY 已设置（AgentOrbit 平台连接密钥，外部凭据类 §5.1；
#      未设置时前置守卫报错，run-all.sh 豁免本任务——密钥就位后自动执行，
#      且配置保存成功后 022/023 的豁免可同步解除）
#
# 运行：bash replay_testcase/018_agentorbit-config.sh（默认显示浏览器窗口）
# 如需无头模式：HEADED=0 bash replay_testcase/018_agentorbit-config.sh
#
# 翻译决断：
#   1. 用例操作步骤无密钥录入（预期"连接成功"隐含连接配置已填写），但 022
#      实跑核对已知 AgentOrbit 连接配置须填写密钥（[创建新分身] 按钮在连接
#      未配置时禁用）——按 §4.1 信息录入模式补全密钥录入步骤，密钥取
#      AGENT_ORBIT_KEY（022 豁免变量，字面复用形成"018 配置 → 022/023 消费"
#      数据链）
#   2. 密钥输入框标签未经实跑核对（018 原为空文件，本次补充内容后首次转换），
#      按 fill_by_any_label 候选标签依次尝试：'密钥' / '连接密钥' /
#      'AgentOrbit 密钥' / 'API 密钥' / 'Key'，全落空时硬失败退出
#   3. 用例 [保存配置] 按钮文案按 021 实测经验决断（平台保存类按钮实际文案
#      常为"保存"，见 test-plan §七 差异 11）：click_by_exact '保存' 精确
#      优先、子串退化兜底，可同时覆盖 "保存" / "保存配置" 两种文案
#   4. 预期 4"连接成功" / 预期 5"配置保存成功"为异步结果，按 §7.3 轮询断言；
#      成功/失败特征词按平台常见 toast 文案编写固定模式（'连接成功' /
#      '连接失败' / '保存成功' / '保存失败'），实跑核对后如有差异同步修正
#
# 幂等策略：配置变更类——重复执行收敛到目标状态（密钥重填、覆盖保存），幂等

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/../common/common.sh"

# 统一测试数据：data/test-data.sh（含全部用例数据，环境变量优先）
DATA_DIR="${SCRIPT_DIR}/../data"
load_data_file "${DATA_DIR}/test-data.sh"


ab_init
require_vars ASDM_USER ASDM_PASS

# 前置守卫（§六）：密钥为空时测试连接无意义（外部凭据类数据未就绪，
# 带病执行必失败），前置报错并说明解除条件
if [ -z "${AGENT_ORBIT_KEY:-}" ]; then
    echo "  [失败] AGENT_ORBIT_KEY 未设置：本用例配置 AgentOrbit 连接需要平台密钥" >&2
    echo "         （AGENT_ORBIT_KEY=真实密钥 bash $0 解除；配置成功后 022/023 豁免可同步解除）" >&2
    exit 1
fi

# ---------- 操作步骤 ----------

# step 1: 用户进入 ASDM 管理后台 首页（super-admin 登录态）
goto_admin_console

# step 2: 点击 [平台级设置] → [AgentOrbit] 页签，
# 右侧工作区打开 AgentOrbit 连接配置 页面
echo "[step 2] 进入 [平台级设置] → [AgentOrbit]"
goto_platform_settings
click_tab 'AgentOrbit'
ab_wait 1000

# step 3(前决断补全): 录入 AgentOrbit 连接密钥
# （用例步骤省略，见翻译决断 1；候选标签覆盖常见命名，实跑核对后收敛）
echo "[step 3] 录入 AgentOrbit 连接密钥"
fill_by_any_label "$AGENT_ORBIT_KEY" '密钥' '连接密钥' 'AgentOrbit 密钥' 'API 密钥' 'Key'

# step 4: 点击 [测试连接]
# "连接成功"为瞬时 toast，a11y 快照与 innerText 均捕获不到；故以接口为准：
#   POST /api/agentorbit/config/test → HTTP 200 = 连接成功
echo "[step 4] 点击 [测试连接]"
agent-browser network requests --clear >/dev/null 2>&1
click_by_text '测试连接' '测试连接按钮'

# ---------- 预期结果断言 ----------

# 预期结果 1: 连接成功（接口判定）
echo "[断言] AgentOrbit 连接成功"
ok=""
for ((i = 0; i < 30; i++)); do
    line=$(agent-browser network requests --type xhr,fetch 2>/dev/null \
           | grep -F 'agentorbit/config/test' | tail -1)
    st=$(printf '%s\n' "$line" | awk '{print $NF}')
    [ -n "$line" ] && { case "$st" in 2*) ok=1; break;; 4*|5*) break;; esac; }
    sleep 1
done
if [ -n "$ok" ]; then
    echo "  [断言通过] AgentOrbit 连接成功（test 接口返回 2xx）"
else
    echo "  [断言失败] AgentOrbit 连接未成功（test 接口未返回 2xx）" >&2
    WARN=$((WARN+1))
fi

# ---------- 操作步骤（续） ----------

# step 5: 点击 [保存配置] 按钮
# 按钮实际文案为"保存配置"（非"保存"），须精确匹配
echo "[step 5] 点击 [保存配置]"
agent-browser network requests --clear >/dev/null 2>&1
click_by_exact '保存配置' '保存配置按钮'
ab_wait 1000

# 预期结果 2: 配置保存成功（接口判定）
# "保存成功"同为瞬时 toast；故以接口为准：
#   PUT /api/agentorbit/config → HTTP 200 = 保存成功
echo "[断言] AgentOrbit 配置保存成功"
ok=""
for ((i = 0; i < 30; i++)); do
    line=$(agent-browser network requests --type xhr,fetch 2>/dev/null \
           | grep -E 'PUT.*agentorbit/config' | tail -1)
    st=$(printf '%s\n' "$line" | awk '{print $NF}')
    [ -n "$line" ] && { case "$st" in 2*) ok=1; break;; 4*|5*) break;; esac; }
    sleep 1
done
if [ -n "$ok" ]; then
    echo "  [断言通过] AgentOrbit 配置保存成功（config 接口返回 2xx）"
else
    echo "  [断言失败] AgentOrbit 配置未保存成功（config 接口未返回 2xx）" >&2
    WARN=$((WARN+1))
fi

# ---------- 收尾 ----------
finish
