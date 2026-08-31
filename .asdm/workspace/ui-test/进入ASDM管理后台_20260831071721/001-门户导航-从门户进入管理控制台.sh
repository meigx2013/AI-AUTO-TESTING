#!/usr/bin/env bash
# ============================================================
# 测试场景: SC-001 门户导航-从门户进入管理控制台
# 来源录制: recordings/002_进入ASDM管理后台/002_进入ASDM管理后台.json
# 生成时间: 2026-08-31 07:17:21
# 脚本类型: agent-browser（主产物）
#
# 运行方式:
#   bash 001-门户导航-从门户进入管理控制台.sh
#   BROWSER=chromium bash 001-门户导航-从门户进入管理控制台.sh   # 指定浏览器（默认 chrome）
#
# 前置说明: 本场景业务步骤需登录态（页头显示用户头像 Admin Super）。
# 脚本内含登录保障（三路探测 cookie → 标题 → URL），未检测到会话时
# 自动执行登录流程（登录链路复用 recordings/001_系统登录.json 实测步骤）。
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
SCENARIO_NAME="门户导航-从门户进入管理控制台"

echo "=========================================="
echo "  ${SCENARIO_ID}: ${SCENARIO_NAME}"
echo "=========================================="

# @step step-1 | 导航: 平台门户首页 — 打开 ASDM 平台门户首页并设置视口
# Recorder selectors:
#   - (setViewport 1692x787)
#   - (navigate https://platform-sit01.asdm.ai/portal/)
echo "[STEP:step-1:START] 导航: 打开平台门户首页"
echo "  → 打开 ${BASE_URL}/portal/ 并设置视口 1692x787"
# 注：open 输出重定向以避免 agent-browser daemon 管道死锁；页面加载由 assert-1 标题断言验证
agent-browser ${HEADED_FLAG} open "${BASE_URL}/portal/" --browser=${BROWSER} > /dev/null 2>&1
agent-browser set viewport 1692 787
sleep 2
echo "[STEP:step-1:OK]"

# @step assert-1 | 断言: 平台门户首页 — 门户首页加载成功，页面标题含"ASDM AI资源中心"
# Recorder selectors:
#   - (assertedEvents: navigation https://platform-sit01.asdm.ai/portal/ title "ASDM AI资源中心")
echo "[STEP:assert-1:START] 断言: 门户首页加载成功"
PAGE_TITLE=$(agent-browser eval "document.title")
if ! echo "${PAGE_TITLE}" | grep -q "ASDM AI资源中心"; then
  echo "❌ 断言失败: 门户首页标题不含「ASDM AI资源中心」（实际: ${PAGE_TITLE}）"
  exit 1
fi
echo "✅ 断言通过: 门户首页加载成功（title: ${PAGE_TITLE}）"
echo "[STEP:assert-1:OK]"

echo "[EXEC:START] ${SCENARIO_ID} | ${SCENARIO_NAME}"

# ==================== 登录保障（三路探测 cookie → 标题 → URL；保障逻辑，非录制步骤） ====================
# 门户首页未登录也可公开访问，但本场景业务步骤需登录态，故探测不到会话
# cookie 时主动执行登录流程（链路复用 001_系统登录 录制实测）。
CURRENT_URL=$(agent-browser get url)
COOKIE_STR=$(agent-browser eval "document.cookie")
DETECTED=$(echo "${COOKIE_STR}" | grep -oiE "(session|sid|token|auth|jwt|connect\.sid)" | tr '\n' ' ')
echo "[LOGIN:CHECK] URL: ${CURRENT_URL}"
echo "[LOGIN:CHECK] cookies: ${COOKIE_STR:-(空)}"

if [ -n "${DETECTED}" ]; then
  echo "[LOGIN:SKIP] ✅ cookie 检测到会话 (${DETECTED})，已登录，跳过登录流程"
else
  echo "[LOGIN:NEED] ❌ 未检测到会话 cookie，执行登录流程"
  # 未登录时 header 按钮为「登录」按钮（与 001 录制同位）
  agent-browser click "header button"
  sleep 2
  SIGNIN_URL=$(agent-browser get url)
  if ! echo "${SIGNIN_URL}" | grep -q "signin"; then
    echo "❌ 登录保障失败: 点击页头「登录」按钮后未跳转登录页（URL: ${SIGNIN_URL}）"
    exit 1
  fi
  agent-browser find placeholder '请输入邮箱地址' fill "${SUPER_ADMIN_EMAIL}"
  agent-browser find placeholder '请输入您的密码' fill "${SUPER_ADMIN_PASSWORD}"
  # 中文提交按钮优先 CSS 选择器（find role --name 常不触发）
  agent-browser click "form button"
  # SPA 异步渲染：get url 无 auto-wait，采用重试循环（10 次 × 1 秒）等待回到门户首页
  LOGIN_OK=0
  LOGIN_URL=""
  for i in $(seq 1 10); do
    sleep 1
    LOGIN_URL=$(agent-browser get url)
    if echo "${LOGIN_URL}" | grep -q "/portal/"; then
      LOGIN_OK=1
      break
    fi
    echo "  → 第 ${i} 次检测未就绪（URL: ${LOGIN_URL}），继续等待..."
  done
  if [ "${LOGIN_OK}" -ne 1 ]; then
    echo "❌ 登录保障失败: 登录后未返回门户首页（URL: ${LOGIN_URL}）"
    exit 1
  fi
  echo "[LOGIN:OK] 登录完成，已回到门户首页"
  sleep 2
fi

# @step step-2 | 点击: 平台门户首页 — 点击页头用户头像按钮（Admin Super），展开用户下拉菜单
# Recorder selectors:
#   - aria/s Admin Super
#   - aria/[role="graphics-symbol"]
#   - div.css-6su6fj path
#   - xpath///*[@id="root"]/div/header/div/div[2]/button/svg/path
#   - pierce/div.css-6su6fj path
echo "[STEP:step-2:START] 点击: 点击页头用户头像按钮"
echo "  → 点击页头用户头像按钮（登录后 header 内按钮即用户头像，采用与录制 xpath 同位的稳定简化 CSS「header button」；录制 CSS div.css-6su6fj 为 emotion 哈希类，不稳定仅作备选）"
agent-browser click "header button"
sleep 2
echo "[STEP:step-2:OK]"

# @step step-3 | 点击: 用户下拉菜单 — 点击菜单项「控制台管理」，进入 ASDM 管理后台
# Recorder selectors:
#   - aria/控制台管理
#   - li:nth-of-type(2)
#   - xpath//html/body/div[2]/div[3]/ul/li[2]
#   - pierce/li:nth-of-type(2)
#   - text/控制台管理
echo "[STEP:step-3:START] 点击: 点击「控制台管理」菜单项"
echo "  → 点击用户下拉菜单中的「控制台管理」菜单项（menuitem 有显式 ARIA role，find role menuitem 实测稳定；text/ 前缀对嵌套 StaticText 中文节点匹配不稳定；备选 CSS li:nth-of-type(2) 依赖菜单位次）"
# 菜单为异步弹出且 find 类命令无 auto-wait，采用重试点击（5 次 × 1 秒）
MENU_CLICKED=0
for i in $(seq 1 5); do
  if agent-browser find role menuitem click --name '控制台管理' 2>/dev/null; then
    MENU_CLICKED=1
    break
  fi
  echo "  → 第 ${i} 次尝试未找到菜单项，继续等待..."
  sleep 1
done
if [ "${MENU_CLICKED}" -ne 1 ]; then
  echo "❌ 失败: 未能点击「控制台管理」菜单项（备选: agent-browser click 'li:nth-of-type(2)）"
  exit 1
fi
echo "[STEP:step-3:OK]"

# @step assert-2 | 断言: ASDM 管理后台 — 点击「控制台管理」后跳转到管理后台项目页（/projects），页面标题包含"ASDM"
# @healed 2026-08-31: title 断言由精确匹配 grep -x "ASDM" 改为包含匹配 grep -q "ASDM"（SPA 路由后 title 动态更新为 "ASDM | 平台概览"，录制快照期望过时；URL /projects 断言已稳定满足，人工确认动态行为属预期）
# Recorder selectors:
#   - (assertedEvents: navigation https://platform-sit01.asdm.ai/projects title "ASDM")
echo "[STEP:assert-2:START] 断言: 已进入 ASDM 管理后台"
# SPA 异步渲染：get url / eval 无 auto-wait，采用重试循环（10 次 × 1 秒）
NAV_OK=0
FINAL_URL=""
FINAL_TITLE=""
for i in $(seq 1 10); do
  sleep 1
  FINAL_URL=$(agent-browser get url)
  FINAL_TITLE=$(agent-browser eval "document.title")
  if echo "${FINAL_URL}" | grep -q "/projects" && echo "${FINAL_TITLE}" | tr -d '[:space:]' | grep -q "ASDM"; then
    NAV_OK=1
    break
  fi
  echo "  → 第 ${i} 次检测未就绪（URL: ${FINAL_URL}, title: ${FINAL_TITLE}），继续等待..."
done
if [ "${NAV_OK}" -ne 1 ]; then
  echo "❌ 断言失败: 未跳转到管理后台（期望 URL 含 /projects 且 title 为 ASDM；实际 URL: ${FINAL_URL}, title: ${FINAL_TITLE}）"
  exit 1
fi
echo "✅ 断言通过: 已进入 ASDM 管理后台（URL: ${FINAL_URL}, title: ${FINAL_TITLE}）"
echo "[STEP:assert-2:OK]"

echo "✅ ${SCENARIO_ID} ${SCENARIO_NAME} - 执行成功！"
echo "[EXEC:END] ${SCENARIO_ID} | 成功"
