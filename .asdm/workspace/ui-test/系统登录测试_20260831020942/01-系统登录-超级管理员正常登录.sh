#!/usr/bin/env bash
# ============================================================
# 测试场景: LOGIN-001 超级管理员正常登录
# 来源录制: recordings/系统登录/001_系统登录.json（步骤 0~14）
# 生成时间: 2026-08-31 02:09:42
# 脚本类型: agent-browser（主产物）
#
# 登录保障说明: 本场景为用例首个场景，负责建立登录态供后续场景复用。
#   开头清理残留 daemon（agent-browser close）确保从未登录状态开始；
#   执行完毕保持浏览器会话（不 close），后续场景在同一 daemon 中复用登录态。
#
# 运行方式:
#   bash 01-系统登录-超级管理员正常登录.sh
#   BROWSER=chromium bash 01-系统登录-超级管理员正常登录.sh     # 指定浏览器（默认 chrome）
#   HEADED=0 bash 01-系统登录-超级管理员正常登录.sh             # 无头模式（默认有头）
# ============================================================

set -e

# ==================== 配置 ====================
HEADED_FLAG="--headed"    # agent-browser 默认无头，需显式指定有头；仅首个 open 使用（避免 daemon 冲突）
DATA_DIR="$(cd "$(dirname "$0")" && pwd)/data"

# 从 data/ 文件读取环境配置与账号（数据与脚本分离，见 ui-test-data-spec.md）
# 注意：Git Bash 下需使用 cygpath -m 将 Unix 路径转为 Windows 正斜杠路径
BASE_URL=$(node -e "console.log(require('$(cygpath -m ${DATA_DIR}/env.json)').baseUrl)")
SUPER_ADMIN_EMAIL=$(node -e "console.log(require('$(cygpath -m ${DATA_DIR}/accounts.json)').accounts.superAdmin.username)")
SUPER_ADMIN_PASSWORD=$(node -e "console.log(require('$(cygpath -m ${DATA_DIR}/accounts.json)').accounts.superAdmin.password)")

SCENARIO_ID="LOGIN-001"
SCENARIO_NAME="超级管理员正常登录"

echo "[EXEC:START] ${SCENARIO_ID} | ${SCENARIO_NAME}"

# ==================== 步骤 1：打开门户首页 ====================
# @step step-1 | 导航: ASDM 门户首页 — 打开门户页面（清理残留会话，确保从未登录状态开始）
# Recorder selectors:
#   - (navigate 步骤，无元素选择器；录制步骤 1 url="https://platform-dt01.asdm.ai/portal/")
echo "[STEP:step-1:START] 导航: 打开门户首页"
echo "  → 清理残留浏览器会话后打开 ${BASE_URL}/portal/，确保从未登录状态开始"
agent-browser close 2>/dev/null || true
sleep 1
echo "[CMD] agent-browser ${HEADED_FLAG} open \"${BASE_URL}/portal/\" --browser=${BROWSER:-chrome}"
agent-browser ${HEADED_FLAG} open "${BASE_URL}/portal/" --browser=${BROWSER:-chrome}
agent-browser set viewport 1692 753
sleep 2
echo "[STEP:step-1:OK]"

# ==================== 断言 1：门户加载成功 ====================
# @step assert-1 | 断言: ASDM 门户首页 — 页面标题为「ASDM AI资源中心」
# Recorder selectors:
#   - (导航断言，来源于录制步骤 1 的 assertedEvents: title="ASDM AI资源中心")
echo "[STEP:assert-1:START] 断言: 门户首页加载成功"
PAGE_TITLE=$(agent-browser eval "document.title")
if ! echo "${PAGE_TITLE}" | grep -q "ASDM AI资源中心"; then
  echo "❌ 断言失败: 门户标题不符（期望含「ASDM AI资源中心」，实际: ${PAGE_TITLE}）"
  exit 1
fi
echo "✅ 断言通过: 门户首页加载成功（标题: ${PAGE_TITLE}）"
echo "[STEP:assert-1:OK]"

# ==================== 步骤 2：点击门户「登录」按钮 ====================
# @step step-2 | 点击: ASDM 门户首页 — 点击头部「登录」按钮，进入登录页
# Recorder selectors:
#   - aria/登录
#   - header button
#   - xpath///*[@id="root"]/div/header/div/div[2]/button
#   - pierce/header button
#   - text/登录
echo "[STEP:step-2:START] 点击: 点击门户头部「登录」按钮"
echo "  → 中文按钮使用 CSS 选择器 header button（aria/ 前缀非有效 CSS）"
agent-browser click "header button"
sleep 2
echo "[STEP:step-2:OK]"

# ==================== 断言 2：跳转登录页 ====================
# @step assert-2 | 断言: 登录页 — URL 跳转到 /signin 且登录表单可见
# Recorder selectors:
#   - (导航断言，来源于录制步骤 2 的 assertedEvents: url=".../signin?redirect=...")
echo "[STEP:assert-2:START] 断言: 已跳转到登录页"
CURRENT_URL=$(agent-browser eval "window.location.href")
if ! echo "${CURRENT_URL}" | grep -q "signin"; then
  echo "❌ 断言失败: 未跳转到登录页（期望 URL 含 signin，实际: ${CURRENT_URL}）"
  exit 1
fi
FORM_INPUT_COUNT=$(agent-browser get count "form input")
if [ "${FORM_INPUT_COUNT}" -lt 2 ]; then
  echo "❌ 断言失败: 登录表单输入框数量不足（期望 ≥2，实际: ${FORM_INPUT_COUNT}）"
  exit 1
fi
echo "✅ 断言通过: 已跳转登录页（${CURRENT_URL}），登录表单可见"
echo "[STEP:assert-2:OK]"

# ==================== 步骤 3：填写邮箱 ====================
# @step step-3 | 输入: 登录页 — 在「请输入邮箱地址」输入框填写超级管理员邮箱
# Recorder selectors:
#   - aria/请输入邮箱地址
#   - form > div > div:nth-of-type(1) input
#   - xpath///*[@id="root"]/div[1]/div/div[1]/div/div/div[2]/form/div/div[1]/div/input
#   - pierce/form > div > div:nth-of-type(1) input
echo "[STEP:step-3:START] 输入: 填写登录邮箱"
echo "  → 在邮箱输入框填写超级管理员账号（值从 data/accounts.json 读取）"
agent-browser find placeholder '请输入邮箱地址' fill "${SUPER_ADMIN_EMAIL}"
sleep 0.5
echo "[STEP:step-3:OK]"

# ==================== 步骤 4：填写密码 ====================
# @step step-4 | 输入: 登录页 — 在「请输入您的密码」输入框填写密码
# Recorder selectors:
#   - aria/请输入您的密码
#   - form > div > div:nth-of-type(2) input
#   - xpath///*[@id="root"]/div[1]/div/div[1]/div/div/div[2]/form/div/div[2]/div/div/input
#   - pierce/form > div > div:nth-of-type(2) input
echo "[STEP:step-4:START] 输入: 填写登录密码"
echo "  → 在密码输入框填写密码（值从 data/accounts.json 读取）"
agent-browser find placeholder '请输入您的密码' fill "${SUPER_ADMIN_PASSWORD}"
sleep 0.5
echo "[STEP:step-4:OK]"

# ==================== 步骤 5：点击「登录」提交按钮 ====================
# @step step-5 | 点击: 登录页 — 点击表单「登录」提交按钮
# Recorder selectors:
#   - aria/登录
#   - form button
#   - xpath///*[@id="root"]/div[1]/div/div[1]/div/div/div[2]/form/div/div[4]/button
#   - pierce/form button
echo "[STEP:step-5:START] 点击: 点击表单「登录」提交按钮"
echo "  → 中文提交按钮使用 CSS 选择器 form button（find role --name 中文常不触发提交）"
agent-browser click "form button"
sleep 5
echo "[STEP:step-5:OK]"

# ==================== 断言 3：登录成功跳回门户 ====================
# @step assert-3 | 断言: ASDM 门户首页 — 登录成功后跳回门户，标题为「ASDM AI资源中心」
# Recorder selectors:
#   - (导航断言，来源于录制步骤 14 的 assertedEvents: url="https://platform-dt01.asdm.ai/portal/", title="ASDM AI资源中心")
echo "[STEP:assert-3:START] 断言: 登录成功并跳回门户首页"
CURRENT_URL=$(agent-browser eval "window.location.href")
PAGE_TITLE=$(agent-browser eval "document.title")
if ! echo "${CURRENT_URL}" | grep -q "/portal/"; then
  echo "❌ 断言失败: 登录后未跳回门户（期望 URL 含 /portal/，实际: ${CURRENT_URL}）"
  exit 1
fi
if ! echo "${PAGE_TITLE}" | grep -q "ASDM AI资源中心"; then
  echo "❌ 断言失败: 登录后门户标题不符（期望含「ASDM AI资源中心」，实际: ${PAGE_TITLE}）"
  exit 1
fi
echo "✅ 断言通过: 登录成功，已跳回门户（${CURRENT_URL}，标题: ${PAGE_TITLE}）"
echo "[STEP:assert-3:OK]"

echo "✅ ${SCENARIO_ID} ${SCENARIO_NAME} - 执行成功！"
echo "[EXEC:END] ${SCENARIO_ID} | 成功"
