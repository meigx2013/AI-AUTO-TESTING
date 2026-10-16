#!/bin/bash
# 由 007_pipeline-config.md 翻译而来（测试用例 markdown → agent-browser）
#
# 通用操作已抽取至 common.sh（快照 ref 驱动），本脚本仅保留用例业务步骤：
#   管理后台 → 平台级设置 → 其他 → 添加流水线配置（Jenkins 型）
#
# 【表单结构】[新增流水线配置] 表单按 DOM 顺序为：名称 → 流水线类型
#   (select 值 jenkins) → Base URL → Jenkins 凭证 → 知识空间同步 Jenkinsfile
#   → 智能体空间执行 Jenkinsfile → 知识空间分析 Jenkinsfile → ASDM API PAT。
#   注意：Jenkins 凭证 / 3 个 Jenkinsfile / PAT 字段属"类型 = Jenkins"条件渲染，
#   默认（GitHub Actions）形态下不可见——须先切换流水线类型再核对/填写表单。
#
# 前置条件（不自动级联，缺失即报错）：
#   1. 用户已完成系统登录（先执行 replay_testcase/001_system-login.sh）
#   2. PAT 令牌已创建（先执行 replay_testcase/006_generate-pat.sh，读 data/pat.txt）
#
# 运行：bash replay_testcase/007_pipeline-config.sh（默认显示浏览器窗口）
# 如需无头模式：HEADED=0 bash replay_testcase/007_pipeline-config.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/../common/common.sh"

# 统一测试数据：data/test-data.sh（含全部用例数据，环境变量优先）
DATA_DIR="${SCRIPT_DIR}/../data"
load_data_file "${DATA_DIR}/test-data.sh"


ab_init
require_vars ASDM_USER ASDM_PASS PIPELINE_NAME JENKINS_URL JENKINS_CRED
# 三个 Jenkinsfile 选项值（用例步骤 6，即 select 的 option value，
# 可经环境变量覆盖）
JENKINSFILE_SPACE_SYNC="${JENKINSFILE_SPACE_SYNC:-context/asdm-context-space-sync.no-docker.Jenkinsfile}"
JENKINSFILE_WORKSPACE_EXEC="${JENKINSFILE_WORKSPACE_EXEC:-workspace/asdm-workspace-exec.no-docker.Jenkinsfile}"
JENKINSFILE_CONTEXT_ANALYZE="${JENKINSFILE_CONTEXT_ANALYZE:-context/asdm-context-analyze.no-docker.Jenkinsfile}"
# PAT 令牌：优先取环境变量，否则读取 006 用例落盘的 pat.txt
PAT="${PAT:-$(cat "${DATA_DIR}/pat.txt" 2>/dev/null)}"
[ -n "$PAT" ] || { echo "  [失败] 未获取到 PAT 令牌，请先执行 replay_testcase/006_generate-pat.sh" >&2; exit 1; }

# ---------- 操作步骤 ----------

# ---------- 页面落点校验（对应用例 md 步骤 1/3/4/5 的"页面跳转关键点"） ----------
# 【背景】本用例跨 3 个页面层级（Portal → 管理后台首页 → 平台级设置页 →
#   新增流水线配置弹窗），任一跳转落空后，后续定位会在错误页面上"找到同名
#   元素"或硬失败，日志无法判断卡在哪一层。故每步导航后做落点断言。
# 【页面落点】
#   · 管理后台首页 URL = /projects（侧边栏含 link "平台级设置"）
#   · 平台级设置页 URL = /server/_settings（右侧工作区出现 Tab 页签组）
#   · [其他] Tab 选中后工作区出现 [添加流水线配置] 按钮
assert_at() {  # $1=特征文本 $2=页面说明 $3=轮询次数(默认15)
    local i snap
    for ((i = 0; i < ${3:-15}; i++)); do
        snap=$(snap_i)
        case "$snap" in
            *"$1"*) echo "  [落点] $2（已到达）"; return 0;;
        esac
        ab_wait 1000
    done
    echo "  [失败] 未到达 $2：快照中未找到 '$1'（当前 URL: $(agent-browser get url 2>/dev/null)）" >&2
    exit 1
}

# step 1: 用户进入 ASDM管理后台 首页
# 单任务补跑/会话过期时可能无登录态，先幂等登录 super-admin
# 落点校验：管理后台首页侧边栏出现 [平台级设置] 入口（goto_admin_console 已
# 校验 URL/特征文本，此处再锚定侧边栏入口，确保下一步点击目标存在）
echo "[step 1] 进入 ASDM 管理后台首页"
login
goto_admin_console
assert_at '平台级设置' 'ASDM 管理后台首页'

# step 2: 点击左下角 [平台级设置] 按钮
echo "[step 2] 点击左下角 [平台级设置]"
goto_platform_settings

# step 3: 右侧工作区打开 平台级设置 页面（用例 md 步骤 3 为独立一步，
# 故在此显式校验"右侧工作区"已切到设置页内容区）
echo "[step 3] 校验右侧工作区已打开 [平台级设置] 页面"
assert_url_matches '/server/_settings' '平台级设置页面 URL'
# 设置页左侧导航为 button 组（概览/组织/用户/资源管理/
# AgentOrbit/特性开关/CLI管理/分类管理/精选资源/最佳实践管理/其他），非 tab
# 角色、也无"通用"文本——以工作区标题 heading "平台级设置" + 目标页签
# button "其他" 作为"右侧工作区已切换到设置页"的落点特征
assert_at 'heading "平台级设置"' '平台级设置页工作区（右侧内容区）'
assert_at 'button "其他"' '平台级设置页页签按钮组（含 [其他]）'

# step 4: 点击 [其他] Tab页签
echo "[step 4] 点击 [其他] Tab页签"
click_tab '其他'
# 落点校验：[其他] Tab 内容区出现 [添加流水线配置] 入口，否则后续点击必然落空
assert_at '添加流水线配置' '平台级设置 · [其他] Tab 内容区'
ab_wait 1000

# ---------- 弹窗内控件定位 ----------
# 【定位难点】名称输入框与 Jenkins 凭证输入框既无 <label> 也无 placeholder，
#   只能按 DOM 顺序定位；Base URL（placeholder "https://jenkins.example.com"）
#   与 ASDM API PAT（placeholder "请输入 ASDM API PAT"）有可访问名，可精确匹配。
# 【弹窗收敛】全页 refs_of_role 会混入弹窗外（平台级设置页）的同角色元素，故统一
#   从弹窗标题行 "新增流水线配置" 起、到弹窗底部 [创建] 按钮止截取控件 ref
#   （快照行序 = DOM 序，与表单字段顺序一致）。
dialog_refs() {   # $1=角色名（textbox|combobox）
    snap_i | awk -v role="$1" '
        index($0, "新增流水线配置") { in_dlg = 1; next }
        in_dlg && index($0, "- button \"创建\"") { exit }
        in_dlg && index($0, "- " role) {
            match($0, /ref=e[0-9]+/); print substr($0, RSTART + 4, RLENGTH - 4)
        }
    '
}

# next_textbox_after — 取弹窗内某 ref 之后的第一个 textbox
# 【用途】Jenkins 凭证输入框无可访问名，按"紧跟 Base URL 输入框之后"定位
#         （表单 DOM：Base URL 在 div[2]、凭证在 div[4]）。
next_textbox_after() {  # $1=ref
    snap_i | awk -v r="ref=$1" '
        index($0, r) { f = 1; next }
        f && index($0, "- textbox") {
            match($0, /ref=e[0-9]+/); print substr($0, RSTART + 4, RLENGTH - 4); exit
        }
    '
}

# 【幂等】列表已存在同名记录时跳过创建
# 【注意】同名记录不论类型（GitHub Actions / Jenkins）均命中跳过——需按
#   Jenkins 型重建时，请先在列表删除该记录（或改 PIPELINE_NAME=... 覆盖）
if printf '%s\n' "$(snap_i)" | grep -q -- "heading \"${PIPELINE_NAME}\""; then
    echo "  流水线配置 ${PIPELINE_NAME} 已存在，跳过创建（幂等）"
else
    # step 5: 点击 [+ 添加流水线配置] 按钮，打开 [新增流水线配置] 窗口
    echo "[step 5] 点击 [+ 添加流水线配置]"
    click_by_text '添加流水线配置' '添加流水线配置按钮'
    assert_visible '新增流水线配置' '[新增流水线配置] 弹窗出现'

    # step 6: [新增流水线配置] 信息录入（子步骤 7-12）
    echo "[step 7] 录入名称: $PIPELINE_NAME"
    name_tb=$(snapshot_line_after '新增流水线配置' 'textbox') \
        || { echo "  [失败] 未找到名称输入框" >&2; exit 1; }
    agent-browser fill "@${name_tb}" "$PIPELINE_NAME" >/dev/null

    # step 8: 流水线类型选择 [Jenkins]（弹窗内第 1 个 combobox，原生 select）
    echo "[step 8] 选择流水线类型: Jenkins"
    type_cb=$(dialog_refs combobox | head -1)
    [ -n "$type_cb" ] || { echo "  [失败] 未找到流水线类型下拉框" >&2; exit 1; }
    # option value = "jenkins"
    select_by_native "$type_cb" 'jenkins' '流水线类型'
    # 【防静默空操作】agent-browser select 匹配不到选项时 exit 0 且值不变
    # （011 §step 9 同源坑）：读回选中值校验，落空则按选项标签重试
    [ "$(agent-browser get value "@${type_cb}" 2>/dev/null)" = 'jenkins' ] \
        || select_by_native "$type_cb" 'Jenkins' '流水线类型（按选项标签重试）'

    # 类型切至 Jenkins 后表单重渲染出 Jenkins 专属字段，轮询等待
    # （Base URL placeholder "https://jenkins.example.com" 即切换生效的判据：
    #   GitHub Actions 形态此处为 "my-group/my-repo"）
    url_tb=""
    for ((i = 0; i < 30; i++)); do
        url_tb=$(extract_ref "$(snap_i)" '- textbox "https://jenkins.example.com"')
        [ -n "$url_tb" ] && break
        ab_wait 500
    done
    # 兜底：弹窗内第 2 个文本框（DOM 顺序：名称 → Base URL）
    [ -n "$url_tb" ] || url_tb=$(dialog_refs textbox | sed -n 2p)
    [ -n "$url_tb" ] \
        || { echo "  [失败] 未找到 Base URL 输入框（流水线类型是否未切至 Jenkins？）" >&2; exit 1; }

    echo "[step 9] 录入 Base URL: $JENKINS_URL"
    agent-browser fill "@${url_tb}" "$JENKINS_URL" >/dev/null

    # step 10: 录入 Jenkins 凭证（紧跟 Base URL 之后，无可访问名）
    echo "[step 10] 录入 Jenkins 凭证"
    pat_tb=""
    for ((i = 0; i < 20; i++)); do
        pat_tb=$(extract_ref "$(snap_i)" '- textbox "请输入 ASDM API PAT"')
        [ -n "$pat_tb" ] && break
        ab_wait 500
    done
    [ -n "$pat_tb" ] || pat_tb=$(dialog_refs textbox | tail -1)
    cred_tb=$(next_textbox_after "$url_tb")
    # 兜底：弹窗内第 3 个文本框（DOM 顺序：名称 → Base URL → 凭证 → PAT）
    [ -n "$cred_tb" ] || cred_tb=$(dialog_refs textbox | sed -n 3p)
    # 凭证框若与 PAT 框重合，说明凭证字段未渲染（鉴权方式非凭证型）
    [ -n "$pat_tb" ] && [ "$cred_tb" = "$pat_tb" ] && cred_tb=""
    [ -n "$cred_tb" ] || { echo "  [失败] 未找到 Jenkins 凭证输入框" >&2; exit 1; }
    agent-browser fill "@${cred_tb}" "$JENKINS_CRED" >/dev/null

    # step 11: 三个 Jenkinsfile 下拉（表单 div[5] 内 3 个原生 select，顺序 =
    #   知识空间同步 / 智能体空间执行 / 知识空间分析；选项自 Jenkins
    #   拉取，需轮询等待渲染）
    cbs=()
    for ((i = 0; i < 20; i++)); do
        cbs=()
        for r in $(dialog_refs combobox); do cbs+=("$r"); done
        [ "${#cbs[@]}" -ge 4 ] && break   # 类型下拉 + 3 个 Jenkinsfile 下拉
        ab_wait 500
    done
    [ "${#cbs[@]}" -ge 4 ] \
        || { echo "  [失败] Jenkinsfile 下拉未渲染（Jenkins 不可达或未配置？）" >&2; exit 1; }
    n=${#cbs[@]}
    echo "[step 11] 选择三个 Jenkinsfile"
    select_by_native "${cbs[$((n-3))]}" "$JENKINSFILE_SPACE_SYNC" '知识空间同步 Jenkinsfile'
    select_by_native "${cbs[$((n-2))]}" "$JENKINSFILE_WORKSPACE_EXEC" '智能体空间执行 Jenkinsfile'
    select_by_native "${cbs[$((n-1))]}" "$JENKINSFILE_CONTEXT_ANALYZE" '知识空间分析 Jenkinsfile'
    echo "  选中值: $(agent-browser get value "@${cbs[$((n-3))]}" 2>/dev/null) | $(agent-browser get value "@${cbs[$((n-2))]}" 2>/dev/null) | $(agent-browser get value "@${cbs[$((n-1))]}" 2>/dev/null)"

    # step 12: 录入 ASDM API PAT（006 用例产出的令牌）
    echo "[step 12] 录入 ASDM API PAT"
    [ -n "$pat_tb" ] || { echo "  [失败] 未找到 ASDM API PAT 输入框" >&2; exit 1; }
    agent-browser fill "@${pat_tb}" "$PAT" >/dev/null

    # step 13: 点击 [创建] 按钮（取最后一个精确匹配，防弹窗外同名引导按钮误点）
    echo "[step 13] 点击 [创建]"
    ab_click_last_exact '创建' '创建按钮（弹窗内）'
    ab_wait 2000
    # 落点校验：创建成功则弹窗关闭（标题消失），仍停留说明校验未通过（如字段
    # 必填未过），此时列表断言很可能拿到弹窗残留值造成假阳性
    assert_snapshot_missing '新增流水线配置' '[新增流水线配置] 弹窗已关闭（提交被接受）'
fi

# ---------- 预期结果断言 ----------

# 预期结果 1: 流水线配置创建成功（列表记录行含 heading "$PIPELINE_NAME"，
# 区别于弹窗 textbox 残留值——防创建失败弹窗停留时的假阳性）
echo "[断言] 流水线配置创建成功: $PIPELINE_NAME"
shown=1
for ((i = 0; i < 10; i++)); do
    snap=$(snap_i)
    case "$snap" in
        *"heading \"${PIPELINE_NAME}\""*) shown=0; break;;
        *) ab_wait 500;;
    esac
done
if [ "$shown" -eq 0 ]; then
    echo "  [断言通过] 流水线配置列表中出现 $PIPELINE_NAME"
else
    echo "  [断言失败] 流水线配置列表中出现 $PIPELINE_NAME" >&2; WARN=$((WARN+1))
fi

# ---------- 收尾（§8.3） ----------
finish
