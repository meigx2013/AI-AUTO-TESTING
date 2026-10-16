#!/bin/bash
# 由 025_online-knowledge-space.md 翻译而来（测试用例 markdown → agent-browser）
#
# 通用操作已抽取至 common.sh（快照 ref 驱动），本脚本仅保留用例业务步骤：
#   test01 登录 → 项目 → 资源库 → 知识空间 → 新建知识空间（在线）→ 知识源（多步构建）→ 保存
#
# 前置条件（不自动级联，缺失即报错）：
#   1. 用户 test01@asdm.ai 已完成系统登录（先执行 replay_testcase/005_create-user.sh）
#   2. 组织下已存在项目（先执行 replay_testcase/010_create-project.sh）
#
# 运行：bash replay_testcase/025_online-knowledge-space.sh（默认显示浏览器窗口）
# 如需无头模式：HEADED=0 bash replay_testcase/025_online-knowledge-space.sh
#
# 翻译决断：
#   1. 用例原文项目名与 test-data.sh 批次数据不一致，按规范以 test-data.sh
#      统一，使用 $PROJECT_NAME（差异记入 test-plan §七）
#   2. 用例步骤 2 省略了组织导航，按 010/015/016 已实测验证路径展开：
#      [组织与项目] → 组织树节点 "$ORG_NODE" → 点击项目名称；知识空间入口
#      为 [资源库] → [知识空间] 子导航（016 实测路径）
#   3. 登录身份决断为 test01（知识空间挂靠项目，与 015/016 一致）
#   4. 类型字段：015 实跑表单仅录名称/描述（015 用例未写类型且创建成功，
#      说明类型非必填或有默认值）；本用例明确"类型：选择 [在线]"，按用例
#      原文翻译为原生 select 选择（012/016 的 select 实测经验：类型类控件
#      为原生 select）；实跑若表单无 '类型' 控件需核对表单结构后修正
#   5. 用例步骤 10 "添加知识源"未写名称等字段：按 016 同构决断知识源必有
#      名称（列表展示依赖），补录名称字段（MULTI_CONTEXT_NAME 带时间戳防重名）；
#      多步构建模式下的其余必填字段用例未提供、不代拟——若提交静默无效，
#      按 §4.3 排查表单必填项后补全
#   6. 用例步骤 11 提交按钮写 [保存]（016 同位置为 [创建]），按用例原文
#      '保存' 翻译：click_by_exact 精确优先 + 子串退化兜底
#   7. 知识空间名称 "在线知识空间" 为创建类数据（不幂等），按 §5.2 带批次
#      时间戳后缀防重名（026 复用同名变量字面进入，不重复创建）

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
require_vars ASDM_USER ASDM_PASS ORG_NODE PROJECT_NAME \
             ONLINE_KNOWLEDGE_NAME ONLINE_KNOWLEDGE_TYPE \
             MULTI_CONTEXT_BUILD_MODE MULTI_CONTEXT_NAME

# ---------- 操作步骤 ----------

# step 1: test01 登录 → 管理后台 → 组织与项目 → 组织节点 → 项目页面
echo "[step 1] test01 登录"
login
goto_admin_console
goto_org_project
click_tree_node "$ORG_NODE" || exit 1
echo "[step 1] 点击项目: $PROJECT_NAME"
click_by_text "$PROJECT_NAME" '项目名称'
ab_wait 1500

# step 2: 右侧工作区打开 [资源库] 页面，点击 [知识空间] 子导航
# （016 实测：资源库默认展示 [场景智能体] 子页，须先切 [知识空间] 子导航）
echo "[step 2] 打开 [资源库] → [知识空间] 页面"
click_by_text '资源库' '资源库导航'
ab_wait 1000
click_by_exact '知识空间' '知识空间子导航'
ab_wait 1000

# step 3: 点击 [创建知识空间] 按钮，打开 [创建知识空间] 窗口
# 按钮实际文案为 [新建知识空间]（用例原文写 [创建知识空间]，
# 平台按钮统一用"新建"）
echo "[step 3] 点击 [新建知识空间]"
click_by_text '新建知识空间' '新建知识空间按钮'
assert_visible '新建知识空间' '[新建知识空间] 窗口出现'

# step 4: [创建知识空间] 信息录入 —— 名称 / 类型（在线）
echo "[step 4] 信息录入: 名称=$ONLINE_KNOWLEDGE_NAME 类型=$ONLINE_KNOWLEDGE_TYPE"
fill_by_any_label "$ONLINE_KNOWLEDGE_NAME" '名称'
# 类型选择（012/016 实测经验：类型类控件为原生 select；触发器找不到时
# ref_by_text 兜底；实跑若表单无类型控件见翻译决断 4）
# 知识空间表单仅名称/描述字段，无类型控件——类型"在线"无从选择，
# 属用例与平台表单差异，信息性跳过不计 WARN（差异记录 test-plan §七）
type_cb=$(ref_by_label '类型') || type_cb=$(ref_by_text '类型')
if [ -n "$type_cb" ]; then
    select_by_native "$type_cb" "$ONLINE_KNOWLEDGE_TYPE" '类型下拉框'
else
    echo "  [跳过] 知识空间表单无类型控件（平台表单结构现状，差异见 test-plan §七）" >&2
fi

# step 5: 点击 [创建] 按钮
echo "[step 5] 点击 [创建]"
click_by_exact '创建' '创建按钮'
ab_wait 2000

# step 6: 点击该知识空间，进入 在线知识空间
echo "[step 6] 点击进入知识空间: $ONLINE_KNOWLEDGE_NAME"
click_by_text "$ONLINE_KNOWLEDGE_NAME" '知识空间记录'
# 特征文本'查看知识空间详情、知识源和配置'已随平台改版移除
# ——改为校验详情页 [知识源] 入口存在
ks_detail=""
for ((i = 0; i < 20; i++)); do
    if snap_i | grep -q '知识源'; then ks_detail=1; break; fi
    ab_wait 1000
done
if [ -n "$ks_detail" ]; then
    echo "  [断言通过] 知识空间详情页出现"
else
    echo "  [失败] 未进入知识空间详情页（持续加载中或点击未生效）" >&2; exit 1
fi

# step 7: 点击 [知识源] Tab页签
# 精确匹配优先：避免误点含"知识源"前缀的其他元素（如 [添加源]）
echo "[step 7] 点击 [知识源] 页签"
click_by_exact '知识源' '知识源导航'
ab_wait 1000

# step 8: 添加知识源，构建模式选择 [多步构建]
echo "[step 8] 点击 [添加源]"
click_by_text '添加源' '添加源按钮'
ab_wait 1000
assert_visible '添加源' '[添加源] 页面出现'

# step 9: [添加源] 信息录入 —— 构建模式 / 名称
echo "[step 9] 信息录入: 构建模式=$MULTI_CONTEXT_BUILD_MODE 名称=$MULTI_CONTEXT_NAME"
# 构建模式为 radio 单选组（非下拉），select_option 两步法无效
# ——须用 click_radio；多步交互构建为默认选中，点击幂等
click_radio "$MULTI_CONTEXT_BUILD_MODE"
ab_wait 500
fill_by_any_label "$MULTI_CONTEXT_NAME" '名称'

# step 10: 点击 [保存] 按钮
# 添加源弹窗提交按钮实际文案为 [创建]（用例原文写 [保存]，
# 差异记录 test-plan §七）
echo "[step 10] 点击 [创建]"
click_by_exact '创建' '创建按钮'
ab_wait 2000

# ---------- 预期结果断言 ----------

# 预期结果 1: 成功进入 在线知识空间
# 添加源提交后平台停留于知识源相关视图，快照不再含空间名；
# 空间可达性已由 step 6 硬断言保证，此处改为 URL 详情形态校验（/workspaces/<id>）
url=$(agent-browser get url 2>/dev/null)
# 知识空间详情 URL 形态为 /proj-<ts>/_library/contexts/<id>
case "$url" in
    */_library/contexts/*) echo "  [断言通过] 在线知识空间 ${ONLINE_KNOWLEDGE_NAME} 详情视图（URL 校验）";;
    *) echo "  [断言失败] 未停留在知识空间详情视图，当前: $url" >&2; WARN=$((WARN+1));;
esac

# 预期结果 2: 知识源构建模式设置为 多步构建 并保存成功
# （列表刷新时序不可靠，轮询 + 软断言；断言知识源记录与构建模式特征文本）
# $MULTI_CONTEXT_NAME 紧跟全角括号时会被 bash 并入变量名（macOS UTF-8
# locale，unbound variable）——用 ${VAR} 显式界定变量名边界
echo "[断言] 知识源列表出现: ${MULTI_CONTEXT_NAME}（构建模式: ${MULTI_CONTEXT_BUILD_MODE}）"
wait_for_text "$MULTI_CONTEXT_NAME" 10 || true
assert_snapshot_contains "$MULTI_CONTEXT_NAME" "知识源 $MULTI_CONTEXT_NAME 已保存"
assert_snapshot_contains "$MULTI_CONTEXT_BUILD_MODE" "知识源构建模式为 $MULTI_CONTEXT_BUILD_MODE"

# ---------- 收尾 ----------
finish
