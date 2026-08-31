#!/usr/bin/env bash
# ============================================================
# 测试场景: LOGIN-002 登录后进入控制台管理
# 来源录制: recordings/系统登录/001_系统登录.json（步骤 15~16）
# 生成时间: 2026-08-31 02:09:42
# 脚本类型: agent-browser（主产物）
#
# 前置依赖: 需先运行 01-系统登录-超级管理员正常登录.sh 建立登录态
#   （同一 agent-browser daemon 会话；登录态由场景 LOGIN-001 保障，
#    本场景仅做前置条件校验，不内嵌登录逻辑）
#
# 运行方式:
#   bash 01-系统登录-超级管理员正常登录.sh    # 先运行场景 1（建立登录态）
#   bash 02-系统登录-登录后进入控制台管理.sh  # 再运行本场景
# ============================================================

set -e

# ==================== 配置 ====================
DATA_DIR="$(cd "$(dirname "$0")" && pwd)/data"

# 从 data/ 文件读取环境配置（数据与脚本分离，见 ui-test-data-spec.md）
# 注意：Git Bash 下需使用 cygpath -m 将 Unix 路径转为 Windows 正斜杠路径
BASE_URL=$(node -e "console.log(require('$(cygpath -m ${DATA_DIR}/env.json)').baseUrl)")

SCENARIO_ID="LOGIN-002"
SCENARIO_NAME="登录后进入控制台管理"

echo "[EXEC:START] ${SCENARIO_ID} | ${SCENARIO_NAME}"

# ==================== 步骤 1：打开门户并校验登录态 ====================
# @step step-1 | 导航: ASDM 门户首页 — 打开门户页面并校验登录态（前置条件校验，不执行登录）
# Recorder selectors:
#   - (navigate 步骤，无元素选择器；录制步骤 1 url="https://platform-dt01.asdm.ai/portal/")
echo "[STEP:step-1:START] 导航: 打开门户首页并校验登录态"
echo "  → 打开 ${BASE_URL}/portal/（复用场景 LOGIN-001 的 daemon 会话与登录态，open 不重复加 --headed）"
agent-browser open "${BASE_URL}/portal/" --browser=${BROWSER:-chrome}
agent-browser set viewport 1692 753
sleep 2
# 前置条件校验：登录后门户头部为用户头像按钮（button 内含 svg），未登录则为「登录」文本按钮
HEADER_SVG_COUNT=$(agent-browser get count "header button svg" 2>/dev/null || echo "0")
if [ "${HEADER_SVG_COUNT}" -lt 1 ]; then
  echo "❌ 前置条件不满足: 未检测到登录态（门户头部无用户头像按钮）"
  echo "   请先运行: bash 01-系统登录-超级管理员正常登录.sh"
  exit 1
fi
echo "  → 登录态校验通过（门户头部检测到用户头像按钮）"
echo "[STEP:step-1:OK]"

# ==================== 步骤 2：点击用户头像按钮 ====================
# @step step-2 | 点击: ASDM 门户首页 — 点击头部用户头像按钮，展开用户下拉菜单
# Recorder selectors:
#   - div.css-6su6fj svg ⚠️（CSS Modules hash 类名，不稳定）
#   - xpath///*[@id="root"]/div/header/div/div[2]/button/svg
#   - pierce/div.css-6su6fj svg
# ⚠️ 选择器不稳定: 录制原始 CSS 为 hash 类名；依据 xpath 可知元素位于 header 下 button 内
#   （与录制步骤 2 的「登录」按钮同一位置，登录后变为头像按钮），改用稳定选择器 header button
echo "[STEP:step-2:START] 点击: 点击门户头部用户头像按钮"
echo "  → 登录后原「登录」按钮位置变为头像按钮，使用稳定选择器 header button"
agent-browser click "header button"
sleep 1
echo "[STEP:step-2:OK]"

# ==================== 步骤 3：点击「控制台管理」菜单项 ====================
# @step step-3 | 点击: 用户下拉菜单 — 点击「控制台管理」菜单项
# Recorder selectors:
#   - aria/控制台管理
#   - li:nth-of-type(2)
#   - xpath//html/body/div[2]/div[3]/ul/li[2]
#   - pierce/li:nth-of-type(2)
#   - text/控制台管理
echo "[STEP:step-3:START] 点击: 点击「控制台管理」菜单项"
echo "  → 在用户下拉菜单中点击「控制台管理」（text/ 前缀非有效 CSS，转换为 find text 命令）"
agent-browser find text '控制台管理' click
sleep 2
echo "[STEP:step-3:OK]"

# ==================== 断言 1：跳转控制台 ====================
# @step assert-1 | 断言: 控制台页面 — 跳转到 /projects 控制台管理页面
# Recorder selectors:
#   - (导航断言，来源于录制步骤 16 的 assertedEvents: url="https://platform-dt01.asdm.ai/projects", title="ASDM")
echo "[STEP:assert-1:START] 断言: 已跳转到控制台管理页面"
CURRENT_URL=$(agent-browser eval "window.location.href")
if ! echo "${CURRENT_URL}" | grep -q "/projects"; then
  echo "❌ 断言失败: 未跳转到控制台（期望 URL 含 /projects，实际: ${CURRENT_URL}）"
  exit 1
fi
echo "✅ 断言通过: 已跳转到控制台管理页面（${CURRENT_URL}）"
echo "[STEP:assert-1:OK]"

echo "✅ ${SCENARIO_ID} ${SCENARIO_NAME} - 执行成功！"
echo "[EXEC:END] ${SCENARIO_ID} | 成功"
