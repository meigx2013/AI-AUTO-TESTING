#!/bin/bash
# 由 026_multi-step-build.md 翻译而来（测试用例 markdown → agent-browser）
#
# 通用操作已抽取至 common.sh（快照 ref 驱动），本脚本仅保留用例业务步骤：
#   test01 登录 → 项目 → 资源库 → 在线知识空间（幂等进入）→ 知识源（多步构建）
#   → [构建] → 构建完成 → 打开多个 MD 文件验证内容
#
# 前置条件（不自动级联，缺失即报错）：
#   1. 用户 test01@asdm.ai 已完成系统登录（先执行 replay_testcase/005_create-user.sh）
#   2. 组织下已存在项目（先执行 replay_testcase/010_create-project.sh）
#   3. 在线知识空间与多步构建知识源已创建（先执行
#      replay_testcase/025_online-knowledge-space.sh；单跑本脚本时按幂等
#      分支自动兜底创建，见翻译决断 2）
#
# 运行：bash replay_testcase/026_multi-step-build.sh（默认显示浏览器窗口）
# 如需无头模式：HEADED=0 bash replay_testcase/026_multi-step-build.sh
#
# 翻译决断：
#   1. 用例原文步骤 5-8（创建知识空间）、9-10（添加知识源）与 025 完全相同：
#      编号序即依赖序（§六），025 为本用例前置；按"登录类前置幂等处理"
#      精神将重复创建翻译为幂等分支——已存在（025 已执行）则直接进入/跳过，
#      不存在（断点续跑漏 025）则按 025 同构流程兜底创建，保证单跑/续跑安全
#   2. 用例步骤 11 "点击 [构建] 按钮"：构建按钮定位按用例原文 '构建' 精确
#      匹配（知识源行内操作，025 仅添加一个知识源、全局唯一）；实跑若为
#      行内图标按钮（无可见文本），改 snapshot_line_after 模式（§4.3）
#   3. 多步构建为异步长任务：按 §7.3 轮询，成功特征 = 快照出现 '.md' 文件
#      条目（构建产出的 MD 文档），失败特征 = '构建失败'；轮询上限 5 分钟
#      （60 次 × 5s + 快照耗时），超时按失败计（软断言）
#   4. 步骤 12 "打开多个文件，查看生成的 MD 文档"："多个" 决断为至少
#      2 个，从快照提取 .md 文件名（去重）后依次点击前 2 个打开验证
#   5. 预期 4 "MD 内容正确"：MD 正文为纯文本，交互快照（-i）不含，
#      用 body innerText 校验——断言打开后页面文本包含文件名（文档标题
#      特征）且非空；深度内容正确性（语义级）超出自动断言能力，需人工
#      抽查（test-plan §七 差异备注登记）
#   6. [添加源] 表单（多步交互构建模式）除"名称"外还有两个必填控件，用例
#      原文未写，遗漏会导致提交被表单校验静默拦截：
#        名称 *      #add-item-name        fill
#        仓库 *      #add-item-repository  原生 select（选项来自项目仓库，级联 011）
#        场景智能体   #add-item-toolset     Portal 浮层下拉（选项来自 009 上传资源）
#      后果链：源未创建 → 弹窗不关闭 → [构建] 按钮被弹窗按钮遮挡
#      （covered by button.flex.min-w-[4.5rem]）→ 预期 1/3/4 连锁失败。
#      字段处理与 016 同构；提交后有弹窗关闭硬校验，把"静默拦截"显性化为即时失败

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
             MULTI_CONTEXT_BUILD_MODE MULTI_CONTEXT_NAME CONTEXT_AGENT

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

# step 2: 右侧工作区打开 [资源库] → [知识空间] 页面
echo "[step 2] 打开 [资源库] → [知识空间] 页面"
click_by_text '资源库' '资源库导航'
ab_wait 1000
click_by_exact '知识空间' '知识空间子导航'
ab_wait 1000

# step 3(幂等决断): 进入 在线知识空间
# 已存在（025 创建）→ 直接点击进入；不存在 → 兜底创建（名称 + 类型在线 + 创建）
if snap_i | grep -q -- "$ONLINE_KNOWLEDGE_NAME"; then
    echo "[step 3] 知识空间已存在（025 创建），直接进入: $ONLINE_KNOWLEDGE_NAME"
    click_by_text "$ONLINE_KNOWLEDGE_NAME" '知识空间记录'
else
    echo "[step 3] 知识空间不存在（025 未执行），兜底创建: $ONLINE_KNOWLEDGE_NAME"
    # 按钮实际文案为 [新建知识空间]（用例原文写 [创建知识空间]，
    # 平台按钮统一用"新建"）
    click_by_text '新建知识空间' '新建知识空间按钮'
    assert_visible '新建知识空间' '[新建知识空间] 窗口出现'
    fill_by_any_label "$ONLINE_KNOWLEDGE_NAME" '名称'
    type_cb=$(ref_by_label '类型') || type_cb=$(ref_by_text '类型')
    if [ -n "$type_cb" ]; then
        select_by_native "$type_cb" "$ONLINE_KNOWLEDGE_TYPE" '类型下拉框'
    else
        echo "  [跳过] 知识空间表单无类型控件（平台表单结构现状，与 025 同款差异，见 test-plan §七）" >&2
    fi
    click_by_exact '创建' '创建按钮'
    ab_wait 2000
    click_by_text "$ONLINE_KNOWLEDGE_NAME" '知识空间记录'
fi
ks_detail=""
for ((i = 0; i < 20; i++)); do
    # 特征文本'查看知识空间详情、知识源和配置'已随平台改版移除——改为校验
    # 详情页 [知识源] 入口存在；URL 形态兜底校验 /_library/contexts/<id>
    snap=$(snap_i)
    case "$snap" in
        *'知识源'*) ks_detail=1; break;;
    esac
    url=$(agent-browser get url 2>/dev/null)
    case "$url" in
        */_library/contexts/*) ks_detail=1; break;;
    esac
    ab_wait 1000
done
if [ -n "$ks_detail" ]; then
    echo "  [断言通过] 知识空间详情页出现"
else
    echo "  [失败] 未进入知识空间详情页（持续加载中或点击未生效）" >&2; exit 1
fi

# step 4(幂等决断): 点击 [知识源] 页签 → 添加知识源（多步构建）
echo "[step 4] 点击 [知识源] 页签"
click_by_exact '知识源' '知识源导航'
ab_wait 1000

# 幂等检查：列表异步渲染，一次性快照易漏检（漏检会误判不存在而走兜底
# 重复添加）——先轮询等待再判定
ks_exists=""
for ((i = 0; i < 10; i++)); do
    if snap_i | grep -q -- "$MULTI_CONTEXT_NAME"; then ks_exists=1; break; fi
    ab_wait 1000
done
if [ -n "$ks_exists" ]; then
    echo "[step 4] 多步构建知识源已存在（025 添加），跳过重复添加"
else
    echo "[step 4] 知识源不存在（025 未执行），兜底添加: $MULTI_CONTEXT_NAME"
    click_by_text '添加源' '添加源按钮'
    ab_wait 1000
    assert_visible '添加源' '[添加源] 页面出现'
    # 兜底分支：构建模式为 radio 单选组（select_option 两步法无效）；
    # 提交按钮文案为 [创建] 非 [保存]
    click_radio "$MULTI_CONTEXT_BUILD_MODE"
    ab_wait 500
    fill_by_any_label "$MULTI_CONTEXT_NAME" '名称'

    # step 5: 仓库 *（#add-item-repository，原生 select；用例原文未写但为必填）
    # 选项来自项目已配置的 GitHub 仓库（级联 011），与 016 同构处理：
    # 行级匹配 combobox → 取其后的 option 列表 → 选第一个非占位选项
    snap=$(snap_i)
    repo_cb=$(printf '%s' "$snap" | grep -E -- '- combobox "仓库' | grep -oE 'ref=e[0-9]+' | head -1 | cut -d= -f2)
    repo_opts=$(printf '%s' "$snap" | awk '/- combobox "仓库/{f=1;next} f && /- option "/{print;next} f{exit}')
    n_real=$(printf '%s' "$repo_opts" | grep -v '请选择' | grep -cE '\- option "')
    for ((i = 0; i < 20; i++)); do
        [ -n "$repo_cb" ] && [ "$n_real" -gt 0 ] && break
        ab_wait 500
        snap=$(snap_i)
        repo_cb=$(printf '%s' "$snap" | grep -E -- '- combobox "仓库' | grep -oE 'ref=e[0-9]+' | head -1 | cut -d= -f2)
        repo_opts=$(printf '%s' "$snap" | awk '/- combobox "仓库/{f=1;next} f && /- option "/{print;next} f{exit}')
        n_real=$(printf '%s' "$repo_opts" | grep -v '请选择' | grep -cE '\- option "')
    done
    if [ -z "$repo_cb" ] || [ "$n_real" -eq 0 ]; then
        echo "  [失败] 仓库下拉无可选项——级联依赖 011 项目配置（GH_TOKEN 占位豁免 → 项目未配置仓库），无法添加知识源" >&2
        WARN=$((WARN+1)); finish
    fi
    repo_opt=$(printf '%s' "$repo_opts" | grep -v '请选择' | head -1 | grep -oE '"[^"]+"' | tr -d '"')
    echo "[step 5] 仓库选择: $repo_opt"
    select_by_native "$repo_cb" "$repo_opt" '仓库下拉框'

    # step 6: 场景智能体（#add-item-toolset，Portal 浮层下拉；选项在仓库选择后加载）
    # 触发器限定弹窗内 button（左侧导航存在同名 link "场景智能体"，子串匹配会误点）
    ts_r=$(extract_ref "$(snap_i)" '- button "场景智能体" \[') \
        || { echo "  [失败] 未找到 [场景智能体] 下拉触发器" >&2; exit 1; }
    agent-browser click "@${ts_r}" >/dev/null
    ts_opt=""
    for ((i = 0; i < 20; i++)); do
        ts_opt=$(extract_ref "$(snap_i)" "- option \"[^\"]*${CONTEXT_AGENT}")
        # 版本低适配（2026-09-07）：009 版本低场景下既有资源名无 .zip 后缀——
        # 全名未命中时先退化基名，仍无才走首个非占位选项兜底
        if [ -z "$ts_opt" ] && [ "${CONTEXT_AGENT%.zip}" != "$CONTEXT_AGENT" ]; then
            ts_opt=$(extract_ref "$(snap_i)" "- option \"[^\"]*${CONTEXT_AGENT%.zip}")
        fi
        [ -n "$ts_opt" ] && break
        ab_wait 500
    done
    # 选项文本为"资源名 (版本)"（版本号浮动）：$CONTEXT_AGENT 前缀未命中时
    # 退化为浮层内首个非占位选项
    [ -n "$ts_opt" ] || ts_opt=$(snap_i | grep -E -- '- option "' | grep -v '请选择' \
        | head -1 | grep -oE 'ref=e[0-9]+' | head -1 | cut -d= -f2)
    [ -n "$ts_opt" ] || { echo "  [失败] 场景智能体下拉无可选项（级联 009 资源上传）" >&2; exit 1; }
    agent-browser click "@${ts_opt}" >/dev/null
    ab_wait 800

    click_by_exact '创建' '创建按钮'
    ab_wait 2000
    # 提交生效校验：表单校验拦截时弹窗不关闭（#add-item-name 仍在 DOM），
    # 静默放行会致 [构建] 按钮被弹窗遮挡、后续断言连锁失败
    for ((i = 0; i < 15; i++)); do
        agent-browser eval '!!document.querySelector("#add-item-name")' 2>/dev/null | grep -qi true || break
        ab_wait 1000
    done
    if agent-browser eval '!!document.querySelector("#add-item-name")' 2>/dev/null | grep -qi true; then
        echo "  [失败] [添加源] 弹窗未关闭——表单必填项缺失或校验未通过，知识源未创建" >&2
        exit 1
    fi
    echo "  [断言通过] [添加源] 弹窗已关闭（提交生效）"
fi

# step 7: 点击 [构建] 按钮，开始多步构建
# 构建为知识源行内按钮：[添加源] 弹窗未关闭时行内按钮被弹窗按钮遮挡
# （covered by button.flex.min-w-[4.5rem]）——先轮询等到按钮可定位再点
echo "[step 7] 点击 [构建]"
build_ref=""
for ((i = 0; i < 20; i++)); do
    build_ref=$(extract_ref "$(snap_i)" '- (button|link) "构建"')
    [ -n "$build_ref" ] && break
    ab_wait 1000
done
[ -n "$build_ref" ] || { echo "  [失败] 未找到 [构建] 按钮（知识源未创建或列表未刷新）" >&2; exit 1; }
ab_click '构建' '构建按钮' 1
ab_wait 2000

# ---------- 预期结果断言 ----------

# 预期结果 1: 成功进入 在线知识空间（step 3 已硬断言，软断言复核）
# 添加源提交后平台停留于知识源视图，快照不再含空间名——改为 URL 详情形态
# 校验（/_library/contexts/<id>），快照命中亦认可
url=$(agent-browser get url 2>/dev/null)
case "$url" in
    */_library/contexts/*)
        echo "  [断言通过] 在线知识空间 $ONLINE_KNOWLEDGE_NAME 详情视图（URL 校验: ${url}）";;
    *)
        assert_snapshot_contains "$ONLINE_KNOWLEDGE_NAME" "在线知识空间 $ONLINE_KNOWLEDGE_NAME 可见";;
esac

# 预期结果 2: 知识源构建模式设置为 多步构建（025/兜底创建已保证，软断言复核）
assert_snapshot_contains "$MULTI_CONTEXT_BUILD_MODE" "知识源构建模式为 $MULTI_CONTEXT_BUILD_MODE"

# 预期结果 3: 多步构建成功完成（异步长任务轮询，§7.3；
# 成功特征 = '.md' 文件条目出现（构建产出），失败特征 = '构建失败'）
echo "[断言] 多步构建完成（等待 .md 文件产出，最长约 5 分钟）"
build_ok=""
for ((i = 0; i < 60; i++)); do
    snap=$(snap_i)
    case "$snap" in
        *'.md'*) build_ok=1; break;;
        *'构建失败'*) break;;
    esac
    sleep 5
done
if [ -n "$build_ok" ]; then
    echo "  [断言通过] 多步构建成功完成（MD 文件已产出）"
else
    echo "  [断言失败] 多步构建未完成（5 分钟内未见 .md 文件产出或构建失败）" >&2
    WARN=$((WARN+1))
fi

# 预期结果 4: 打开多个文件，生成的 MD 内容正确
# （"多个" ≥ 2 个：文件数断言 + 依次打开前 2 个并校验正文文本）
echo "[断言] 打开多个 MD 文件验证内容"
n_files=$(snap_i | grep -oE '"[^"]*\.md"' | tr -d '"' | sort -u | wc -l | tr -d ' ')
if [ "${n_files:-0}" -ge 2 ]; then
    echo "  [断言通过] 文件列表存在多个 MD 文件（${n_files} 个）"
else
    echo "  [断言失败] MD 文件数不足 2 个（当前 ${n_files:-0} 个）" >&2
    WARN=$((WARN+1))
fi

files=$(snap_i | grep -oE '"[^"]*\.md"' | tr -d '"' | sort -u | head -2)
for f in $files; do
    # soft 模式点击：文件条目定位失败仅告警不中断，继续验证下一个
    if ab_click "$f" "文件 $f" 0 soft; then
        ab_wait 1500
        # MD 正文为纯文本（交互快照不含），用 body innerText 校验：
        # 打开后页面文本含文件名（文档标题特征）且整体非空
        body_txt=$(agent-browser eval 'document.body.innerText' 2>/dev/null)
        case "$body_txt" in
            *"$f"*)
                echo "  [断言通过] 文件 $f 已打开且正文包含文档标题特征";;
            *)
                echo "  [断言失败] 文件 $f 打开后正文未见标题特征（内容校验不充分，语义级正确性需人工抽查）" >&2
                WARN=$((WARN+1));;
        esac
    else
        echo "  [断言失败] 无法打开文件: $f" >&2
        WARN=$((WARN+1))
    fi
done

# ---------- 收尾 ----------
finish
