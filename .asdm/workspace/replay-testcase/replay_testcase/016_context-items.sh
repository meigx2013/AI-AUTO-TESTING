#!/bin/bash
# 由 016_context-items.md 翻译而来（测试用例 markdown → agent-browser）
#
# 通用操作已抽取至 common.sh（快照 ref 驱动），本脚本仅保留用例业务步骤：
#   test01 登录 → 项目 → 资源库 → 知识空间 → 知识源 → 添加源（单步自动化构建）→ 创建
#
# 前置条件（不自动级联，缺失即报错）：
#   1. 用户 test01@asdm.ai 已完成系统登录
#   2. 项目 "$PROJECT_NAME" 已创建（先执行 replay_testcase/010_create-project.sh）
#   3. 知识空间 "$KNOWLEDGE_NAME" 已创建（先执行 replay_testcase/015_create-context.sh）
#
# 运行：bash replay_testcase/016_context-items.sh（默认显示浏览器窗口）
# 如需无头模式：HEADED=0 bash replay_testcase/016_context-items.sh
#
# 翻译决断：
#   1. 用例原文项目名/空间名与 test-data.sh 批次数据不一致，统一使用
#      $PROJECT_NAME / $KNOWLEDGE_NAME（差异记入 test-plan §七）
#   2. "点击 [知识空间]名称" 决断为点击 015 创建的知识空间名称（知识源挂在
#      具体空间下；依赖 015 先执行）
#   3. "场景智能体：[Context-builder]" 格式与"构建模式：选择[...]"一致，决断
#      为下拉选择（场景智能体从已上传资源中选择）；若实跑发现为文本输入，
#      改 fill_by_any_label（§4.4 角色核对陷阱）
#   4. "名称"（代码类仓库）为创建类数据（不幂等），按 §5.2 带批次时间戳后缀防重名

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
require_vars ASDM_USER ASDM_PASS ORG_NODE PROJECT_NAME KNOWLEDGE_NAME \
             CONTEXT_BUILD_MODE CONTEXT_SOURCE_NAME CONTEXT_REPO_URL CONTEXT_AGENT CONTEXT_CMD

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

# step 2: 右侧工作区打开 [资源库] 页面
# 资源库默认展示 [场景智能体] 子页，知识空间列表需先点击
#   [知识空间] 子导航，否则 step 4 找不到知识空间名称
echo "[step 2] 打开 [资源库] 页面"
click_by_text '资源库' '资源库导航'
ab_wait 1000
echo "[step 3] 点击 [知识空间] 子导航"
click_by_exact '知识空间' '知识空间子导航'
ab_wait 1000

# step 4: 点击知识空间 "$KNOWLEDGE_NAME"（015 创建），进入 [概览]
echo "[step 4] 点击知识空间: $KNOWLEDGE_NAME"
click_by_text "$KNOWLEDGE_NAME" '知识空间名称'
# 详情页 tab 为路由懒加载，固定等待 1500ms 偶发不足；改轮询等待详情页
# 特征（最长 10s）
wait_for_text '知识源' 10 || true
# 特征文本'查看知识空间详情、知识源和配置'已随平台改版移除；改为校验详情页
# [知识源] 入口存在（软断言，不阻断流程）
assert_snapshot_contains '知识源' '知识空间详情页出现（知识源入口）'

# step 5: 点击 [知识源] 按钮，进入知识源页面
# 精确匹配优先：避免误点含"知识源"前缀的其他元素（如 [添加源]）
echo "[step 5] 点击 [知识源]"
click_by_exact '知识源' '知识源导航'
ab_wait 1000

# step 6: 点击 [添加源] 按钮
echo "[step 6] 点击 [添加源]"
click_by_text '添加源' '添加源按钮'
ab_wait 1000
assert_visible '添加源' '[添加源] 页面出现'

# step 7: [添加源] 信息录入 —— 构建模式 / 名称 / 仓库 / 场景智能体 / 命令
echo "[step 7] 信息录入: 名称=$CONTEXT_SOURCE_NAME 构建模式=$CONTEXT_BUILD_MODE"
# 构建模式为 radio 单选组（非下拉），select_option 两步法切换无效（表单
# 停留错误模式致字段错乱：名称框被连填名称+URL）——须用 click_radio
click_radio "$CONTEXT_BUILD_MODE"
ab_wait 500
fill_by_any_label "$CONTEXT_SOURCE_NAME" '名称'

# 【环境守卫】仓库可用性检测（级联豁免显性化）：
# 代码库类知识源的 [仓库 *] 下拉选项来源于项目已配置的 GitHub 仓库（011）；
# 011 因 GH_TOKEN 占位豁免时，仓库下拉仅"请选择仓库"（无可选项），
# 场景智能体下拉亦无可用实例——提前报错说明根因，避免表单填写一半才失败
# 守卫必须位于 click_radio 切到单步模式之后执行（radio 切换会改变表单结构）；
# ref 提取须按行级匹配再抠 ref——快照行格式为 [expanded=false, ref=eN]，
# 直接用 \[ref=eN 正则会被属性左括号截断导致恒空 → 守卫误报"无可选项"。
# 下拉选项本身异步懒加载，判定前先轮询等待（最长 10s），防"未加载完"误判。
snap=$(snap_i)
repo_cb=$(printf '%s' "$snap" | grep -E -- '- combobox "仓库' | grep -oE 'ref=e[0-9]+' | head -1 | cut -d= -f2)
repo_opts=$(printf '%s' "$snap" | awk '/- combobox "仓库/{f=1;next} f && /- option "/{print;next} f{exit}')
n_real=$(printf '%s' "$repo_opts" | grep -v '请选择仓库' | grep -cE '\- option "')
for ((i = 0; i < 20; i++)); do
    [ -n "$repo_cb" ] && [ "$n_real" -gt 0 ] && break
    ab_wait 500
    snap=$(snap_i)
    repo_cb=$(printf '%s' "$snap" | grep -E -- '- combobox "仓库' | grep -oE 'ref=e[0-9]+' | head -1 | cut -d= -f2)
    repo_opts=$(printf '%s' "$snap" | awk '/- combobox "仓库/{f=1;next} f && /- option "/{print;next} f{exit}')
    n_real=$(printf '%s' "$repo_opts" | grep -v '请选择仓库' | grep -cE '\- option "')
done
if [ -z "$repo_cb" ] || [ "$n_real" -eq 0 ]; then
    echo "  [失败] 仓库下拉无可选项——级联依赖 011 项目配置（GH_TOKEN 占位豁免 → 项目未配置仓库），016 无法添加代码库知识源" >&2
    WARN=$((WARN+1))
    finish
fi
# 仓库为项目仓库下拉（单步模式下 [仓库 *] 为 combobox，无 URL 文本输入
# 形态）——选择第一个可用仓库
repo_opt=$(printf '%s' "$repo_opts" | grep -v '请选择仓库' | head -1 | grep -oE '"[^"]+"' | tr -d '"')
select_by_native "$repo_cb" "$repo_opt" '仓库下拉框'
# 场景智能体为 Portal 浮层下拉（未展开时选项不在快照中），且选项在仓库
# 选择后才加载（顺序：选仓库 → 选智能体）；选项文本 = "资源名 (版本)"
# （版本号浮动）——按 $CONTEXT_AGENT 前缀动态匹配；触发器限定弹窗内
# button（左侧导航存在同名 link "场景智能体"，ref_by_text 首命中会误点导航）
ts_r=$(extract_ref "$(snap_i)" '- button "场景智能体" \[') \
    || { echo "  [失败] 未找到 [场景智能体] 下拉触发器" >&2; exit 1; }
agent-browser click "@${ts_r}" >/dev/null
ts_opt=""
for ((i = 0; i < 20; i++)); do
    ts_opt=$(extract_ref "$(snap_i)" "- option \"[^\"]*${CONTEXT_AGENT}")
    # 版本低适配（2026-09-07）：009 版本低场景（平台已有更高版本）下既有资源名
    # 无 .zip 后缀——全名未命中时退化为去后缀基名匹配
    if [ -z "$ts_opt" ] && [ "${CONTEXT_AGENT%.zip}" != "$CONTEXT_AGENT" ]; then
        ts_opt=$(extract_ref "$(snap_i)" "- option \"[^\"]*${CONTEXT_AGENT%.zip}")
    fi
    [ -n "$ts_opt" ] && break
    ab_wait 500
done
[ -n "$ts_opt" ] || { echo "  [失败] 场景智能体下拉无 ${CONTEXT_AGENT} 选项（级联 009 资源上传）" >&2; exit 1; }
agent-browser click "@${ts_opt}" >/dev/null
ab_wait 800

# 命令为原生 select（#add-item-command），选中场景智能体后才 enable 并
# 加载该智能体的命令选项（disabled 态快照中无 "命令 *" 标签文本）——
# 轮询等待 enable 再原生 select（$CONTEXT_CMD 随 009 上传资源而定）
cmd_cb=""
for ((i = 0; i < 20; i++)); do
    cmd_cb=$(extract_ref "$(snap_i)" '- combobox "命令 \*')
    [ -n "$cmd_cb" ] && break
    ab_wait 500
done
[ -n "$cmd_cb" ] || { echo "  [失败] 命令下拉未随场景智能体选择渲染" >&2; exit 1; }
select_by_native "$cmd_cb" "$CONTEXT_CMD" '命令下拉框'

# step 8: 点击 [创建] 按钮
echo "[step 8] 点击 [创建]"
click_by_exact '创建' '创建按钮'
ab_wait 2000

# ---------- 预期结果断言 ----------

# 预期结果 1: 知识源列表页面新增一条记录（列表刷新时序不可靠，轮询 + 软断言）
echo "[断言] 知识源列表出现: $CONTEXT_SOURCE_NAME"
wait_for_text "$CONTEXT_SOURCE_NAME" 10 || true
assert_snapshot_contains "$CONTEXT_SOURCE_NAME" "知识源 $CONTEXT_SOURCE_NAME 已创建"

# ---------- 收尾 ----------
finish
