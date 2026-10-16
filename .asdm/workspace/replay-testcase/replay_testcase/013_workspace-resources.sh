#!/bin/bash
# 由 013_workspace-resources.md 翻译而来（测试用例 markdown → agent-browser）
#
# 通用操作已抽取至 common.sh（快照 ref 驱动），本脚本仅保留用例业务步骤：
#   test01 登录 → 项目 → 智能体空间 → 资源 → 管理场景智能体 → 可选资源[新增] → 已关联
#
# 前置条件（不自动级联，缺失即报错）：
#   1. 用户 test01@asdm.ai 已完成系统登录
#   2. 项目 "$PROJECT_NAME" 已创建（先执行 replay_testcase/010_create-project.sh）
#   3. 智能体空间 "$WORKSPACE_NAME" 已创建（先执行 replay_testcase/012_create-workspace.sh）
#   4. 场景智能体资源已上传至平台（先执行 replay_testcase/009_resource-management-toolset.sh，
#      资源名 = "$UPLOAD_FILE" 文件名）
#
# 运行：bash replay_testcase/013_workspace-resources.sh（默认显示浏览器窗口）
# 如需无头模式：HEADED=0 bash replay_testcase/013_workspace-resources.sh
#
# 翻译决断：
#   1. 用例原文项目名/空间名与 test-data.sh 批次数据不一致，统一使用
#      $PROJECT_NAME / $WORKSPACE_NAME（差异记入 test-plan §七）
#   2. "点击 [智能体空间]名称" 决断为点击 012 创建的空间名称（进入其概览）
#   3. "在[可选资源]页面，点击[新增]按钮" 决断为点击可选资源列表的 [新增]
#      按钮（首个命中）；关联目标为 009 上传的场景智能体资源
#   4. 预期"已关联页面新增资源"以资源名（UPLOAD_FILE 文件名）出现在已关联
#      区为准断言
#   5. 页面改版适配（2026-09-07）：资源页新增"资源类型"分组并直接展示
#      场景智能体列表——幂等检查前移至资源页面列表（已含目标资源即视为
#      关联完成，不打开弹窗）；弹窗"已关联"区与页面列表条目均不进交互
#      快照（generic 汇总行文本被截断，旧 grep 口径失效=首轮假失败根因），
#      幂等检查与断言统一改用 DOM innerText 口径
#   6. 断言定版（2026-09-07 二次调整）：新增关联后显式关闭弹窗（step 7），
#      以"资源页面场景智能体列表出现资源名"为唯一断言口径——弹窗内文本
#      不再作断言依据（避免弹窗未关时 body.innerText 含弹窗内容造成假阳性，
#      须先确认弹窗已关闭再校验页面列表）

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
require_vars ASDM_USER ASDM_PASS ORG_NODE PROJECT_NAME WORKSPACE_NAME UPLOAD_FILE

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

# step 2: 右侧工作区打开 [智能体空间] 页面
# 精确匹配优先：避免"智能体空间"作为 [新建智能体空间] 按钮的子串被误点
echo "[step 2] 打开 [智能体空间] 页面"
click_by_exact '智能体空间' '智能体空间导航'
ab_wait 1000

# step 3: 点击 [智能体空间] 名称（012 创建），进入 [概览]
echo "[step 3] 点击智能体空间: $WORKSPACE_NAME"
# 空间名 heading 对 JS 合成 click 不响应（返回 ok 但不跳转），
# 须用 click_by_heading 走 agent-browser 坐标点击（真实鼠标事件）
click_by_heading "$WORKSPACE_NAME" '智能体空间名称'
# 详情页判定用 URL 匹配：列表页 URL 为 .../workspaces（无尾斜杠），
# 详情页为 .../workspaces/<id>——快照特征文本已随平台改版移除；
# 特征勿用 '概览'：侧边栏 "Overview 概览" 恒命中造成假阳性
ws_detail=""
for ((i = 0; i < 20; i++)); do
    case "$(agent-browser get url 2>/dev/null)" in
        *_workspaces/workspaces/*) ws_detail=1; break;;
        *) ab_wait 1000;;
    esac
done
if [ -n "$ws_detail" ]; then
    echo "  [断言通过] 智能体空间详情页出现"
else
    echo "  [失败] 未进入智能体空间详情页（持续加载中或点击未生效）" >&2; exit 1
fi

# step 4: 点击 [资源] 按钮，进入资源页面
# 精确匹配优先：避免误点项目级导航 [资源库]（"资源"是其前缀）
echo "[step 4] 点击 [资源]"
click_by_exact '资源' '资源导航'
ab_wait 1500   # 场景智能体列表懒加载，稍候

# ---------- 页面改版适配（2026-09-07）：文本口径工具 ----------
# 资源页新增"资源类型"分组（场景智能体/知识空间/规约/技能 计数按钮），其下
# 直接展示"场景智能体"列表（"已配置 N 项" + 资源名行）。列表条目为纯文本，
# 不进交互快照（snapshot -i）；弹窗"已关联"区同理——generic 汇总行 name 文本
# 被截断，资源名仅在 DOM innerText 可见。故幂等检查与断言统一走 innerText。

# page_text — 资源页面全文（DOM innerText；场景智能体列表条目仅在此可见）
page_text() { agent-browser eval 'document.body.innerText' 2>/dev/null; }

# dialog_text — 弹窗全文（[role=dialog] 等 innerText 拼接）
dialog_text() {
    agent-browser eval 'Array.from(document.querySelectorAll("[role=dialog],dialog,[role=modal]")).map(d=>d.innerText).join("\n")' 2>/dev/null
}

# linked_section — 弹窗"已关联"区文本：截取"已关联"标记之后的部分
# （innerText 为带 \n 字面转义的单行 JSON 串，sed 截去"已关联"之前内容，
#   避免可选资源列表同名资源造成误判；无"已关联"标记时输出空 = 未关联）
linked_section() {
    local t; t=$(dialog_text)
    case "$t" in
        *已关联*) printf '%s\n' "$t" | sed 's/.*已关联//';;
    esac
}

# page_has_res — 资源页面"场景智能体"列表已含目标资源（幂等判据）
page_has_res() {
    local i
    for ((i = 0; i < 10; i++)); do
        case "$(page_text)" in
            *"${RES_NAME}"*) return 0;;
        esac
        ab_wait 500
    done
    return 1
}

# 关联目标 = 009 上传的场景智能体资源
# 平台资源管理/可选资源区展示的资源名 = UPLOAD_FILE 文件名（非压缩包内
# registryId），与 009 断言口径一致
RES_NAME="${RES_DISPLAY_NAME:-$(basename "$UPLOAD_FILE")}"

# 幂等检查（前移）：资源页面"场景智能体"列表已含目标资源 → 关联已存在，
# 视为完成，跳过 [管理场景智能体] 弹窗与新增操作
if page_has_res; then
    echo "  资源页面场景智能体列表已存在 ${RES_NAME}，跳过管理场景智能体（幂等）"
else
    # step 5: 点击 [管理场景智能体] 按钮
    # 弹窗结构：可选资源列表行按钮 name = "<资源名> <registryId> · <版本> 新增"，
    # 已关联区位于"已关联" heading 之后（资源名 + [删除] 按钮，仅 innerText 可见）
    echo "[step 5] 点击 [管理场景智能体]"
    click_by_text '管理场景智能体' '管理场景智能体按钮'
    ab_wait 1500
    assert_visible '可选资源' '[可选资源] 弹窗出现'

    # 版本低适配（2026-09-07）：009 版本低场景（平台已有更高版本）下，既有资源名
    # 无 .zip 后缀（如 context-builder-8.zip 命中平台资源 context-builder-8）——
    # 可选资源列表按全名未命中时，退化为去后缀基名匹配
    res_snap=$(dialog_text)
    case "$res_snap" in
        *"${RES_NAME}"*) ;;
        *)
            res_base="${RES_NAME%.zip}"
            case "$res_snap" in
                *"${res_base}"*)
                    echo "  [适配] 可选资源列表未见 ${RES_NAME}，退化为基名匹配: ${res_base}"
                    RES_NAME="$res_base";;
            esac;;
    esac

    # 弹窗内幂等：已关联区已含资源名 → 关联已存在，跳过新增
    if linked_section | grep -- "$RES_NAME" >/dev/null; then
        echo "  已关联区已存在 ${RES_NAME}，跳过新增（幂等）"
    else
        # step 6: 在可选资源列表中点击资源行 [新增] 按钮
        # （行按钮 name 为长文本，click_by_exact 精确匹配落空后 ref 子串兜底可命中；
        #   JS 精确匹配若误点他处，此处直接子串匹配资源行按钮更稳）
        # $RES_NAME 后紧跟全角括号会被 bash 并入变量名（unbound variable），
        # 须用 ${RES_NAME} 显式界定变量名边界
        echo "[step 6] 点击 [新增]（资源行: ${RES_NAME}）"
        click_by_text "$RES_NAME" "资源行新增按钮"
        ab_wait 2000
    fi

    # step 7: 关闭 [管理场景智能体] 弹窗，回资源页面
    # 弹窗关闭按钮 name = "Close"（精确匹配，不误点 DigiWorker 的 "Close chat"）
    echo "[step 7] 关闭弹窗，回资源页面"
    click_by_exact 'Close' '关闭弹窗' soft || agent-browser press Escape >/dev/null 2>&1
    ab_wait 1000
    if dialog_open; then
        agent-browser press Escape >/dev/null 2>&1
        ab_wait 1000
    fi
    if dialog_open; then
        echo "  [失败] 弹窗未关闭，无法回资源页面校验场景智能体列表" >&2; exit 1
    fi
fi

# 预期结果 1: 资源页面"场景智能体"列表新增一条关联资源记录
# 【唯一口径】页面列表条目仅 DOM innerText 可见；弹窗已确认关闭（step 7），
# 故 body.innerText 命中资源名即来自页面列表，无弹窗内容假阳性
# 【刷新兜底】页面列表可能不随弹窗关闭自动刷新——第 6 轮未命中时整页
# 重载资源页再查（与 009 资源列表同款处理）
echo "[断言] 场景智能体列表出现资源记录: $RES_NAME"
shown=1
for ((i = 0; i < 12; i++)); do
    case "$(page_text)" in
        *"${RES_NAME}"*) shown=0; break;;
    esac
    if [ "$i" = "5" ]; then
        echo "  [兜底] 列表未见更新，整页重载资源页后再查"
        agent-browser open "$(agent-browser get url 2>/dev/null)" >/dev/null 2>&1
        ab_wait 3000
        continue
    fi
    ab_wait 1000
done
if [ "$shown" -eq 0 ]; then
    echo "  [断言通过] 场景智能体列表出现 ${RES_NAME}"
else
    echo "  [断言失败] 场景智能体列表未出现 $RES_NAME" >&2; WARN=$((WARN+1))
fi

# ---------- 收尾 ----------
finish
