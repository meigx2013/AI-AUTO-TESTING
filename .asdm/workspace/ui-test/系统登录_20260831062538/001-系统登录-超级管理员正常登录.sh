#!/usr/bin/env bash
# ============================================================
# 测试场景: SC-001 系统登录-超级管理员正常登录
# 来源录制: recordings/001_系统登录/001_系统登录.json
# 生成时间: 2026-08-31 06:25:38
# 脚本类型: agent-browser（主产物）
#
# 运行方式:
#   bash 001-系统登录-超级管理员正常登录.sh
#   BROWSER=chromium bash 001-系统登录-超级管理员正常登录.sh   # 指定浏览器（默认 chrome）
#
# 录制噪声说明: 录制中的重复 change（同值）、点击空白区域、Alt+Tab 切窗
# 均为录制噪声，按规范"以最终 change 值为准"合并，不转换为脚本步骤。
# ============================================================

set -e

# ==================== 配置 ====================
HEADED_FLAG="--headed"   # 仅首个 open 使用（--headed 与后续命令混用会与 daemon 冲突）
BROWSER="${BROWSER:-chrome}"
DATA_DIR="$(cd "$(dirname "$0")" && pwd)/data"

# 数据与脚本分离：从 data/ 读取环境与账号（Git Bash 下需 cygpath -m 转换路径）
BASE_URL=$(node -e "console.log(require('$(cygpath -m ${DATA_DIR}/env.json)').baseUrl)")
SUPER_ADMIN_EMAIL=$(node -e "console.log(require('$(cygpath -m ${DATA_DIR}/accounts.json)').accounts.superAdmin.username)")
SUPER_ADMIN_PASSWORD=$(node -e "console.log(require('$(cygpath -m ${DATA_DIR}/accounts.json)').accounts.superAdmin.password)")

SCENARIO_ID="SC-001"
SCENARIO_NAME="系统登录-超级管理员正常登录"

echo "=========================================="
echo "  ${SCENARIO_ID}: ${SCENARIO_NAME}"
echo "=========================================="

# ==================== 登录保障（首个场景：三路探测 cookie → 标题 → URL） ====================
# 本场景即登录测试：仅当 cookie 明确检测到会话键名时跳过登录流程（直接验证门户可达）。
# 门户首页未登录也可公开访问（录制证实 navigate portal 成功且 header 存在"登录"按钮），
# 故不启用"标题/URL 正常即视为已登录"的 HttpOnly 兜底，确保登录链路被执行。
NEED_LOGIN=1

# @step step-1 | 导航: 平台门户首页 — 打开 ASDM 平台门户首页并设置视口
# Recorder selectors:
#   - (setViewport 1692x721)
#   - (navigate https://platform-sit01.asdm.ai/portal/)
echo "[STEP:step-1:START] 导航: 打开平台门户首页"
echo "  → 打开 ${BASE_URL}/portal/ 并设置视口 1692x721"
# 注：open 输出重定向以避免 agent-browser daemon 管道死锁；页面加载由 assert-1 标题断言验证
agent-browser ${HEADED_FLAG} open "${BASE_URL}/portal/" --browser=${BROWSER} > /dev/null 2>&1
agent-browser set viewport 1692 721
sleep 2
echo "[STEP:step-1:OK]"

CURRENT_URL=$(agent-browser get url)
PAGE_TITLE=$(agent-browser eval "document.title")
COOKIE_STR=$(agent-browser eval "document.cookie")
DETECTED=$(echo "${COOKIE_STR}" | grep -oiE "(session|sid|token|auth|jwt|connect\.sid)" | tr '\n' ' ')
echo "[LOGIN:CHECK] URL: ${CURRENT_URL}"
echo "[LOGIN:CHECK] title: ${PAGE_TITLE}"
echo "[LOGIN:CHECK] cookies: ${COOKIE_STR:-(空)}"

if [ -n "${DETECTED}" ]; then
  echo "[LOGIN:SKIP] ✅ cookie 检测到会话 (${DETECTED})，已登录，跳过登录流程"
  NEED_LOGIN=0
else
  echo "[LOGIN:NEED] ❌ 未检测到会话 cookie，执行登录流程"
fi

# @step assert-1 | 断言: 平台门户首页 — 门户首页加载成功，页面标题含"ASDM AI资源中心"
# Recorder selectors:
#   - (assertedEvents: navigation https://platform-sit01.asdm.ai/portal/ title "ASDM AI资源中心")
echo "[STEP:assert-1:START] 断言: 门户首页加载成功"
if ! echo "${PAGE_TITLE}" | grep -q "ASDM AI资源中心"; then
  echo "❌ 断言失败: 门户首页标题不含「ASDM AI资源中心」（实际: ${PAGE_TITLE}）"
  exit 1
fi
echo "✅ 断言通过: 门户首页加载成功（title: ${PAGE_TITLE}）"
echo "[STEP:assert-1:OK]"

echo "[EXEC:START] ${SCENARIO_ID} | ${SCENARIO_NAME}"

# ==================== 登录流程（录制步骤 2~16 去噪后） ====================
if [ "${NEED_LOGIN}" -eq 1 ]; then

  # @step step-2 | 点击: 门户首页 — 点击页头「登录」按钮，进入登录页
  # Recorder selectors:
  #   - aria/登录
  #   - header button
  #   - xpath///*[@id="root"]/div/header/div/div[2]/button
  #   - pierce/header button
  #   - text/登录
  echo "[STEP:step-2:START] 点击: 点击页头「登录」按钮"
  echo "  → 点击页头「登录」按钮（中文按钮，优先使用录制中的 CSS 选择器 header button）"
  agent-browser click "header button"
  sleep 2
  echo "[STEP:step-2:OK]"

  # @step assert-2 | 断言: 登录页 — 点击登录按钮后跳转到登录页（URL 含 /signin）
  # Recorder selectors:
  #   - (assertedEvents: navigation https://platform-sit01.asdm.ai/signin?redirect=... title "ASDM")
  echo "[STEP:assert-2:START] 断言: 已跳转到登录页"
  SIGNIN_URL=$(agent-browser get url)
  if ! echo "${SIGNIN_URL}" | grep -q "signin"; then
    echo "❌ 断言失败: 未跳转到登录页（URL: ${SIGNIN_URL}）"
    exit 1
  fi
  echo "✅ 断言通过: 已跳转到登录页（URL: ${SIGNIN_URL}）"
  echo "[STEP:assert-2:OK]"

  # @step step-3 | 输入: 登录页 — 在「请输入邮箱地址」输入框填写超级管理员邮箱
  # Recorder selectors:
  #   - aria/请输入邮箱地址
  #   - form > div > div:nth-of-type(1) input
  #   - xpath///*[@id="root"]/div[1]/div/div[1]/div/div/div[2]/form/div/div[1]/div/input
  #   - pierce/form > div > div:nth-of-type(1) input
  #   - text/super-admin@asdm.ai
  echo "[STEP:step-3:START] 输入: 填写超级管理员邮箱"
  echo "  → 在「请输入邮箱地址」输入框填写超级管理员邮箱"
  agent-browser find placeholder '请输入邮箱地址' fill "${SUPER_ADMIN_EMAIL}"
  echo "[STEP:step-3:OK]"

  # @step step-4 | 输入: 登录页 — 在「请输入您的密码」输入框填写超级管理员密码
  # Recorder selectors:
  #   - aria/请输入您的密码
  #   - form > div > div:nth-of-type(2) input
  #   - xpath///*[@id="root"]/div[1]/div/div[1]/div/div/div[2]/form/div/div[2]/div/div/input
  #   - pierce/form > div > div:nth-of-type(2) input
  #   - text/superadmin@20260214
  echo "[STEP:step-4:START] 输入: 填写超级管理员密码"
  echo "  → 在「请输入您的密码」输入框填写超级管理员密码"
  agent-browser find placeholder '请输入您的密码' fill "${SUPER_ADMIN_PASSWORD}"
  echo "[STEP:step-4:OK]"

  # @step step-5 | 键盘: 登录页 — 按 Tab 键将焦点从邮箱框切换到密码框
  # Recorder selectors:
  #   - (keyUp Tab)
  echo "[STEP:step-5:START] 键盘: 按 Tab 切换输入焦点"
  echo "  → 按 Tab 键切换输入焦点"
  agent-browser press Tab
  echo "[STEP:step-5:OK]"

  # @step step-6 | 点击: 登录页 — 点击登录表单中的「登录」按钮提交登录
  # Recorder selectors:
  #   - aria/登录
  #   - form button
  #   - xpath///*[@id="root"]/div[1]/div/div[1]/div/div/div[2]/form/div/div[4]/button
  #   - pierce/form button
  echo "[STEP:step-6:START] 点击: 点击「登录」按钮提交表单"
  echo "  → 点击登录表单中的「登录」按钮（中文提交按钮，优先使用录制中的 CSS 选择器 form button）"
  agent-browser click "form button"
  echo "[STEP:step-6:OK]"

fi

# ==================== 断言: 登录成功返回门户 ====================
# @step assert-3 | 断言: 平台门户首页 — 登录成功后跳转回门户首页，URL 含 /portal/ 且标题为"ASDM AI资源中心"
# Recorder selectors:
#   - (assertedEvents: navigation https://platform-sit01.asdm.ai/portal/ title "ASDM AI资源中心")
echo "[STEP:assert-3:START] 断言: 登录成功返回门户首页"
# SPA 异步渲染：get url / eval 无 auto-wait，采用重试循环（10 次 × 1 秒）
LOGIN_OK=0
FINAL_URL=""
FINAL_TITLE=""
for i in $(seq 1 10); do
  sleep 1
  FINAL_URL=$(agent-browser get url)
  FINAL_TITLE=$(agent-browser eval "document.title")
  if echo "${FINAL_URL}" | grep -q "/portal/" && echo "${FINAL_TITLE}" | grep -q "ASDM AI资源中心"; then
    LOGIN_OK=1
    break
  fi
  echo "  → 第 ${i} 次检测未就绪（URL: ${FINAL_URL}），继续等待..."
done
if [ "${LOGIN_OK}" -ne 1 ]; then
  echo "❌ 断言失败: 登录后未返回门户首页（URL: ${FINAL_URL}, title: ${FINAL_TITLE}）"
  exit 1
fi
echo "✅ 断言通过: 登录成功返回门户首页（URL: ${FINAL_URL}）"
echo "[STEP:assert-3:OK]"

echo "✅ ${SCENARIO_ID} ${SCENARIO_NAME} - 执行成功！"
echo "[EXEC:END] ${SCENARIO_ID} | 成功"
