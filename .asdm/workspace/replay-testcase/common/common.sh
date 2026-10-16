#!/bin/bash
# ============================================================================
# common.sh — ASDM 回放测试通用方法库（agent-browser 快照 ref 驱动）
# ============================================================================
#
# 【一句话定位】
#   本库是 27 个回放测试脚本（replay_testcase/<NNN>_<名称>.sh，012 编号含双脚本）
#   共享的通用方法库：测试脚本只描述"业务步骤"，本库负责"如何驱动浏览器"。
#
# 【工作原理】快照 ref 驱动
#   1. agent-browser snapshot -i 抓取页面交互快照（每个可交互元素带 eN 编号）
#   2. 按可见文本 / 表单标签 / 精确文本 / 行位置 / URL / 角色 匹配出 eN（ref）
#   3. agent-browser click / fill / select / upload 等原生命令精确操作该 ref
#   4. ref 仅在"当次快照"内有效 —— 因此所有操作函数内部都会自行重新取快照，
#      调用方无需感知 eN 生命周期（无副作用原则）
#
# 【设计原则】
#   1. 通用：只依赖"可见文本/表单标签/精确文本/行位置/URL/角色"定位元素，
#      不含任何具体测试用例的业务数据。
#   2. 无副作用：函数内部自行取快照定位 ref，调用方无需感知 eN 生命周期；
#      任何改变页面结构的操作后，函数内部都会重新取快照。
#   3. 可组合：按"初始化 → 定位 → 操作 → 等待 → 断言 → 收尾"分层，
#      测试脚本按需组合调用，超时等参数均可覆盖。
#   4. iframe 穿透：act_in_frame 以 BFS 遍历所有同源 frame 按选择器定位，
#      不依赖录制时的 frame 路径，可覆盖多层嵌套 iframe 场景。
#
# 【方法族索引】
#   1. 初始化/环境     ab_init / load_data_file / require_vars
#   2. 快照与定位      snap_i / extract_ref / ref_by_text / ref_by_label /
#                      ref_by_exact / snapshot_line_after / refs_of_role
#   3. 导航/等待       ab_wait / open_page / wait_for_ref_by_text /
#                      wait_for_ref_by_label / wait_for_url_match /
#                      wait_for_url_gone / wait_for_text / dialog_open /
#                      wait_for_dialog / wait_element_gone /
#                      wait_for_network_status / click_by_heading
#   4. 元素操作        click_by_text / click_by_exact / fill_by_label /
#                      fill_by_any_label / click_radio
#   5. 下拉框          select_option / select_by_native
#   6. 上传/取值       upload_file / get_element_value / save_element_value
#   7. 树/搜索控件     expand_all_tree / click_tree_node / search_and_filter /
#                      clear_search_box / cell_after
#   7b. iframe 穿透    act_in_frame
#   8. 断言            assert_snapshot_contains / assert_snapshot_missing /
#                      assert_visible / assert_url_matches /
#                      assert_url_not_matches / assert_file_not_empty
#   9. 登录/导航       is_logged_in / login / click_user_info /
#                      goto_admin_console / in_admin_console /
#                      goto_platform_settings / click_tab /
#                      goto_org_project / click_confirm_if_present
#   10. 收尾           finish
#
# 【全局变量约定】
#   WARN      软断言失败计数（断言函数累加，finish 汇总，>0 则退出码 1）
#   ACT_RETRY iframe 内操作重试次数（默认 5，环境变量可覆盖）
#   BASE_URL  被测系统地址（加载顺序契约：外部环境变量 > data/test-data.sh
#             > ab_init 兜底值。本库 source 阶段不赋具体值防止"占位"，
#             地址变更只改 test-data.sh 一处即可全局生效）
#   DATA_DIR  数据落盘目录（库内已内置默认 <本库所在目录>/../data，即
#             replay-testcase/data；环境变量或 source 前赋值可覆盖）
#   ASDM_USER / ASDM_PASS  登录凭据
#   HEADED    1 有头浏览器（默认），0 无头
#
# 【使用约定】（测试脚本中，顺序不可颠倒——保证单跑与 run-all 全量一致）
#   脚本位于 replay_testcase/ 子目录、本库位于 common/ 子目录，两者同级：
#   source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../common" && pwd)/common.sh"
#   DATA_DIR="<脚本目录>/../data"
#   load_data_file "${DATA_DIR}/test-data.sh"   # 数据先于 ab_init 加载：
#                                 # test-data.sh 的 := 默认须在 ab_init 兜底
#                                 # 之前生效（BASE_URL/凭据等唯一事实来源）
#   ab_init                       # 初始化（建数据目录、HEADED、BASE_URL 兜底）
#   require_vars ASDM_USER ASDM_PASS
#   goto_admin_console            # 内置 login 自愈：未登录自动登录、
#                                 # 身份不符自动退出换号（无需先跑 001）
#   ...
#   finish                        # 汇总 WARN 软断言并退出
#
# 【输出规范】
#   stdout：正常日志（[导航]/[操作]/[断言通过]）
#   stderr：[失败]/[断言失败]/[跳过] 等错误日志（不污染 stdout）
#
# 【依赖】
#   * agent-browser CLI（须已在 PATH 中）
#   * grep / awk / head 等标准 POSIX 工具
# ============================================================================

set -uo pipefail

# ---------------------------------------------------------------------------
# 1. 初始化 / 环境
# ---------------------------------------------------------------------------

# WARN — 全局软断言失败计数
# 【用途】断言类函数失败时累加，finish() 汇总后决定退出码（>0 则 exit 1）。
# 【注意】脚本级全局变量，勿在函数内用 local 遮蔽
WARN=0

# ACT_RETRY — iframe 内操作重试次数
# 【用途】仅对"时序性失败"（NOEL，控件懒加载未渲染）生效；
#         AMBIG（歧义）为确定性失败，不参与重试。
# 【覆盖】可在 source 前用环境变量覆盖：ACT_RETRY=10 bash test.sh
ACT_RETRY="${ACT_RETRY:-5}"

# BASE_URL — 被测系统地址
# 【加载顺序契约】本库 source 阶段仅初始化为空（防 set -u 崩溃；空值不
#            阻止 test-data.sh 的 := 默认生效），具体兜底值延迟到
#            ab_init() 内——优先级恒为：外部环境变量 > test-data.sh >
#            ab_init 兜底。历史教训：曾在 source 阶段赋 dt01 默认值，
#            "占位"导致单跑脚本时 test-data.sh 的 sit 永不生效，与
#            run-all 全量执行环境不一致（009 资源管理 Tab 找不到根因）。
#            地址变更只改 data/test-data.sh 一处，勿在此/各脚本硬编码。
BASE_URL="${BASE_URL:-}"

# DATA_DIR — 数据落盘目录（默认 <本库所在目录>/../data，与各测试脚本约定一致：
#            本库在 common/、脚本在 replay_testcase/，两者同级的 ../data 即
#            replay-testcase/data）
DATA_DIR="${DATA_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/data}"

# ---- 浏览器互斥锁：trap 链式执行支持（私有工具） ----
# 【背景】ab_lock 原先直接 trap 'rm -rf ...' EXIT INT TERM，会覆盖调用方
#         （测试脚本）在同信号上已注册的 trap；反之调用方后设 trap 也会覆盖
#         锁清理导致锁泄漏。现改为：持锁时先记录既有 trap 命令体，新 trap
#         先释放锁、再链式执行调用方原命令，双方清理逻辑都得以保留。
# 【细节】bash 3.2 命令替换子 shell 内 trap -p 可见（已实测）；INT/TERM 原
#         无处理时按默认语义终止（130/143），exit 会再触发 EXIT trap，rm 幂等
#         可重复；_ab_on_exit 显式 return 原 rc，退出码不被 trap 改写。
# 【局限】trap -p 为单引号包裹格式，原命令体内嵌单引号时解析为尽力而为；
#         残余风险由 ab_lock 僵尸锁自愈（kill -0 检测）+ finish() 兜底释放。
_AB_LOCK_DIR=""
_AB_PREV_EXIT_CMD=""
_AB_PREV_INT_CMD=""
_AB_PREV_TERM_CMD=""

# _ab_trap_cmd — 从 `trap -p SIG` 输出（trap -- 'CMD' SIG/SIGINT…）提取 CMD
_ab_trap_cmd() {
    local s="$1"
    s="${s#trap -- }"       # 去掉前缀 → 'CMD' SIG
    s="${s% *}"             # 去掉尾部 " SIG"（信号名无关：INT/SIGINT 均可）
    s="${s#\'}"             # 去掉首引号
    printf '%s' "${s%\'}"   # 去掉尾引号
}

# _ab_release_lock — 释放浏览器互斥锁（幂等，可安全重复调用）
_ab_release_lock() {
    [ -n "$_AB_LOCK_DIR" ] && rm -rf "$_AB_LOCK_DIR" 2>/dev/null
}

_ab_on_exit() {
    local rc=$?
    _ab_release_lock
    [ -n "$_AB_PREV_EXIT_CMD" ] && eval "$_AB_PREV_EXIT_CMD"
    return "$rc"
}

_ab_on_signal() {  # $1 = INT|TERM
    local sig="$1" prev
    if [ "$sig" = INT ]; then prev="$_AB_PREV_INT_CMD"; else prev="$_AB_PREV_TERM_CMD"; fi
    if [ -n "$prev" ]; then
        # 调用方有自己的信号处理：交还控制。此处不预释放锁——若其处理逻辑
        # exit，EXIT trap 会释放；若不退出则脚本继续持锁运行，避免锁已释放
        # 而脚本仍在驱动浏览器导致并发竞争
        eval "$prev"
    else
        # 无原处理：释放锁并按默认语义终止；exit 再触发 EXIT trap 完成清理
        [ "$sig" = INT ] && exit 130
        exit 143
    fi
}

# ab_lock — 浏览器会话互斥锁（同一时间只允许一个回放脚本运行）
# 【背景】多个脚本并发驱动同一 agent-browser 会话会互相抢页面/覆盖导航，
#         导致"页面混乱"型失败（快照 ref 竞争、登录态互相顶掉）。
# 【原理】mkdir 的原子性：目录不存在则创建成功即持锁；已存在则轮询等待。
# 【防僵尸锁】持锁进程已退出（kill -0 失败）时自动清理接管，不永久卡死。
# 【释放】脚本退出/中断时由 trap 自动清理（EXIT/INT/TERM，链式保留调用方
#         既有 trap；finish() 亦兜底释放；调用方后设 trap 覆盖时靠自愈）。
# 【锁路径】${TMPDIR:-/tmp}/asdm-replay.lock（含持锁 PID）
ab_lock() {
    local lock_dir="${TMPDIR:-/tmp}/asdm-replay.lock" i pid
    for ((i = 0; i < 300; i++)); do
        if mkdir "$lock_dir" 2>/dev/null; then
            echo "$$" > "${lock_dir}/pid"
            # 记录既有 trap 并接管：释放时先清锁、再回放调用方原命令
            _AB_LOCK_DIR="$lock_dir"
            _AB_PREV_EXIT_CMD="$(_ab_trap_cmd "$(trap -p EXIT)")"
            _AB_PREV_INT_CMD="$(_ab_trap_cmd "$(trap -p INT)")"
            _AB_PREV_TERM_CMD="$(_ab_trap_cmd "$(trap -p TERM)")"
            trap _ab_on_exit EXIT
            trap '_ab_on_signal INT' INT
            trap '_ab_on_signal TERM' TERM
            return 0
        fi
        pid=$(cat "${lock_dir}/pid" 2>/dev/null)
        if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then
            echo "  [告警] 互斥锁持有进程(PID $pid)已退出，清理僵尸锁并接管" >&2
            rm -rf "$lock_dir"
            continue
        fi
        [ "$i" = "0" ] && echo "  [等待] 另一回放脚本正在运行，排队获取浏览器锁..." >&2
        sleep 1
    done
    echo "  [失败] 等待浏览器互斥锁超时（5 分钟），请确认无其他脚本在跑后删除 ${lock_dir}" >&2
    exit 1
}

# ab_init — 初始化回放环境
# 【用途】建立数据落盘目录，并按 HEADED 设置浏览器有头/无头模式。
# 【参数】无
# 【副作用】创建 $DATA_DIR；设置环境变量 AGENT_BROWSER_HEADED；获取浏览器互斥锁
# 【注意】须在调用本库任何 agent-browser 命令之前调用一次，且须在
#         load_data_file 之后调用（BASE_URL 兜底在此生效，见加载顺序契约）
ab_init() {
    ab_lock
    mkdir -p "$DATA_DIR"
    # BASE_URL 最后兜底：外部环境变量与 test-data.sh 均未提供时才生效
    # （正常路径下 load_data_file 已赋值，此行不覆盖）
    BASE_URL="${BASE_URL:-https://platform-sit01.asdm.ai/}"
    if [ "${HEADED:-1}" = "1" ]; then
        export AGENT_BROWSER_HEADED=1
    fi
}

# load_data_file — 加载测试数据文件
# 【用途】source 一个测试数据文件（环境变量优先，文件内为 : "${VAR:=...}" 形式）。
# 【参数】$1 = 数据文件绝对路径
# 【返回】0 = 成功；文件不存在时静默跳过（不报错）
# 【示例】load_data_file "${SCRIPT_DIR}/../data/test-data.sh"
load_data_file() {
    local f="$1"
    [ -f "$f" ] || return 0   # 文件不存在：静默跳过且返回 0（与注释契约一致）
    . "$f"
}

# require_vars — 校验必需环境变量
# 【用途】逐个检查变量是否已定义，缺失即打印提示并 exit 1，
#         避免后续步骤在空变量上静默出错。
# 【参数】$@ = 变量名列表（不带 $ 前缀）
# 【示例】require_vars ASDM_USER ASDM_PASS ORG_NAME
# 【退出】任一变量未设置 → 报错并 exit 1（提示检查数据文件）
require_vars() {
    local v
    for v in "$@"; do
        : "${!v:?请设置 ${v}，或检查数据文件}"
    done
}

# ---------------------------------------------------------------------------
# 2. 快照与元素定位
# ---------------------------------------------------------------------------

# snap_i — 抓取交互快照
# 【用途】取当前页面所有可交互元素清单（含 eN ref 编号）。
# 【参数】无
# 【输出】stdout = agent-browser snapshot -i 原始文本
# 【注意】每步操作后页面结构已变，定位函数内部各自重新取快照，勿跨步复用 ref
snap_i() { agent-browser snapshot -i 2>/dev/null; }

# _ere_escape — 转义 ERE 元字符（私有工具）
# 【用途】把"可见文本"安全嵌入 grep -E 模式：文本含 . * [ ] ( ) | 等字符时
#         一律按字面匹配，避免被当作正则元字符导致误命中/漏配/模式报错。
# 【边界】extract_ref / refs_of_role 的入参本身定位为"原生 ERE 模式"（调用
#         方可传正则），不经本函数；仅按文本语义定位的函数在内部转义。
_ere_escape() { printf '%s' "$1" | sed -e 's/[][\.*+?{}()|^$]/\\&/g'; }

# _b64 — 文本 base64 编码（私有工具）
# 【用途】把含引号/中文/特殊字符的文本安全传入 JS eval（先编码、浏览器内
#         atob+TextDecoder 解码），规避引号转义地狱。
_b64() { printf '%s' "$1" | base64 | tr -d '\n'; }

# extract_ref — 从快照文本提取第一个 ref
# 【用途】核心定位原语：对给定快照文本，按 ERE 匹配模式取首条匹配行，
#         再从该行抠出第一个 eN 编号。
# 【原理】三级管道逐级收敛：grep -m1 取首匹配行 → grep -oE 抠出 eN → head -1 取首个
# 【参数】$1 = 快照文本；$2 = ERE 匹配模式（grep -E 风格）
# 【输出】stdout = eN（未匹配则为空）
# 【示例】ref=$(extract_ref "$snap" "- (button|link) \"[^\"]*登录")
extract_ref() {   # $1=快照文本 $2=ERE 匹配模式
    printf '%s\n' "$1" | grep -m1 -E -- "$2" | grep -oE 'e[0-9]+' | head -1
}

# ref_by_text — 按可见文本定位元素
# 【用途】优先匹配 button/link/menuitem/tab/option 角色行，
#         失败则退化匹配任意含该文本的行（容错）。
# 【参数】$1 = 可见文本（子串匹配，如 '登录'）
# 【输出】stdout = eN（未找到则为空，返回码 1）
# 【注意】子串匹配可能命中多个，恒取首个；需要精确匹配时改用 ref_by_exact
ref_by_text() {   # $1=可见文本
    local snap r pat
    pat=$(_ere_escape "$1")
    snap=$(snap_i)
    r=$(extract_ref "$snap" "- (button|link|menuitem|tab|option) \"[^\"]*${pat}")
    [ -z "$r" ] && r=$(extract_ref "$snap" "${pat}")
    [ -n "$r" ] && { printf '%s' "$r"; return 0; }
    return 1
}

# ref_by_label — 按表单标签定位输入控件
# 【用途】输入框/下拉框/数值框场景：按可见标签匹配 textbox/combobox/spinbutton 角色。
# 【参数】$1 = 标签文本（如 '邮箱'）
# 【输出】stdout = eN（未找到则为空，返回码 1）
ref_by_label() {  # $1=标签文本
    local r pat
    pat=$(_ere_escape "$1")
    r=$(extract_ref "$(snap_i)" "- (textbox|combobox|spinbutton) \"[^\"]*${pat}")
    [ -n "$r" ] && { printf '%s' "$r"; return 0; }
    return 1
}

# ref_by_exact — 按精确可见文本定位
# 【用途】避免 "创建" 误命中 "创建顶层组织" 这类前缀歧义：
#         要求角色文本完整等于 $1 才匹配。
# 【参数】$1 = 精确文本
# 【输出】stdout = eN（未找到则为空，返回码 1）
ref_by_exact() {  # $1=精确文本
    local r pat
    pat=$(_ere_escape "$1")
    r=$(extract_ref "$(snap_i)" "- (button|link|menuitem|tab|option) \"${pat}\"")
    [ -n "$r" ] && { printf '%s' "$r"; return 0; }
    return 1
}

# snapshot_line_after — 取特征行之后的第一个指定角色元素
# 【用途】树节点行内隐藏操作按钮（如 "..."）场景：快照中特征文本行之后
#         紧跟的某角色元素即为目标。
# 【参数】$1 = 行特征文本；$2 = 角色名（如 button）
# 【输出】stdout = eN（未找到则为空，返回码 1）
# 【示例】ref=$(snapshot_line_after "组织名" "button")
snapshot_line_after() {  # $1=行特征文本 $2=角色名
    local r
    r=$(snap_i | awk -v feat="$1" -v role="$2" '
        index($0, feat) { found = 1; next }
        found && $0 ~ "- " role " " { match($0, /e[0-9]+/); print substr($0, RSTART, RLENGTH); exit }
    ')
    [ -n "$r" ] && { printf '%s' "$r"; return 0; }
    return 1
}

# refs_of_role — 取快照中所有指定角色的 ref
# 【用途】某角色元素无统一标签时的枚举方案，如"页面最后 N 个下拉框"：
#         拿到全部 ref 后由调用方按顺序取用。
# 【参数】$1 = 角色名（如 combobox）
# 【输出】stdout = 每行一个 eN（按快照出现顺序）
# 【示例】last_ref=$(refs_of_role combobox | tail -1)
refs_of_role() {  # $1=角色名（如 combobox）
    snap_i | grep -E -- "- ${1}" | grep -oE 'e[0-9]+'
}

# ---------------------------------------------------------------------------
# 3. 页面级导航 / 等待
# ---------------------------------------------------------------------------

# ab_wait — 固定等待
# 【用途】操作后短暂停顿，等待渲染 / 动画 / 事件生效。
# 【参数】$1 = 等待毫秒数（默认 1000）
ab_wait() { agent-browser wait "${1:-1000}" >/dev/null; }

# open_page — 打开页面并等待渲染
# 【用途】浏览器导航到指定 URL，并预留渲染时间。
# 【参数】$1 = URL（默认 $BASE_URL）
open_page() {     # $1=URL（默认 BASE_URL）
    # 门户 JS bundle 很大，加载常超 open 内部默认超时（~25s）；
    # 超时报错无害（页面仍在后台继续加载），故静默之，就绪判定交由后续
    # wait_for_* 轮询兜底（轮询已放宽至 3 分钟量级）
    agent-browser open "${1:-$BASE_URL}" >/dev/null 2>&1
    ab_wait 1500
}

# wait_for_ref_by_text — 轮询等待文本元素出现
# 【用途】SPA 渲染 / 登录按钮出现等异步场景：轮询快照直至目标文本可交互。
# 【参数】$1 = 文本；$2 = 轮询次数（默认 15）；$3 = 间隔毫秒（默认 1000）
# 【返回】0 = 命中（stdout = eN）；1 = 超时未出现
# 【示例】ref=$(wait_for_ref_by_text '登录' 15) || 处理未出现
wait_for_ref_by_text() {  # $1=文本 $2=轮询次数(默认15) $3=间隔ms(默认1000)
    local i ref pat
    pat=$(_ere_escape "$1")
    for ((i = 0; i < ${2:-15}; i++)); do
        ref=$(extract_ref "$(snap_i)" "- (button|link|menuitem|tab|option) \"[^\"]*${pat}") \
            && { printf '%s' "$ref"; return 0; }
        ab_wait "${3:-1000}"
    done
    return 1
}

# wait_for_ref_by_label — 轮询等待表单控件出现
# 【用途】登录页表单渲染等场景：轮询直至指定标签的输入控件可用。
# 【参数】$1 = 标签文本；$2 = 轮询次数（默认 15）；间隔固定 1000ms
# 【返回】0 = 命中（stdout = eN）；1 = 超时未出现
wait_for_ref_by_label() {  # $1=标签文本 $2=轮询次数(默认15)
    local i ref
    for ((i = 0; i < ${2:-15}; i++)); do
        ref=$(ref_by_label "$1") && { printf '%s' "$ref"; return 0; }
        ab_wait 1000
    done
    return 1
}

# wait_for_url_match — 轮询等待 URL 匹配
# 【用途】导航跳转完成校验：轮询 get url 直至包含目标子串。
# 【参数】$1 = 子串；$2 = 轮询次数（默认 20）；$3 = 间隔毫秒（默认 1000）
# 【返回】0 = 命中（stdout = 当前 URL）；1 = 超时
wait_for_url_match() {  # $1=子串 $2=轮询次数(默认20) $3=间隔ms(默认1000)
    local i url
    for ((i = 0; i < ${2:-20}; i++)); do
        ab_wait "${3:-1000}"
        url=$(agent-browser get url 2>/dev/null)
        case "$url" in
            *"$1"*) printf '%s' "$url"; return 0;;
        esac
    done
    return 1
}

# wait_for_url_gone — 轮询等待 URL 离开某子串
# 【用途】登录后离开 /signin 等反向场景：轮询直至 URL 不再包含目标子串。
# 【参数】$1 = 子串；$2 = 轮询次数（默认 15）；$3 = 间隔毫秒（默认 1000）
# 【返回】0 = 已离开（stdout = 当前 URL）；1 = 超时仍停留
wait_for_url_gone() {  # $1=子串 $2=轮询次数(默认15) $3=间隔ms(默认1000)
    local i url
    for ((i = 0; i < ${2:-15}; i++)); do
        ab_wait "${3:-1000}"
        url=$(agent-browser get url 2>/dev/null)
        case "$url" in
            *"$1"*) : ;;
            *) printf '%s' "$url"; return 0;;
        esac
    done
    return 1
}

# wait_for_text — 轮询等待快照出现特征文本
# 【用途】异步结果断言（如"检测成功"）：轮询快照直至包含特征文本。
# 【参数】$1 = 特征文本；$2 = 轮询次数（默认 10）；$3 = 间隔秒（默认 1）
# 【返回】0 = 出现；1 = 超时
wait_for_text() {  # $1=特征文本 $2=轮询次数(默认10) $3=间隔s(默认1)
    local i snap
    for ((i = 0; i < ${2:-10}; i++)); do
        snap=$(snap_i)
        case "$snap" in
            *"$1"*) return 0;;
        esac
        sleep "${3:-1}"
    done
    return 1
}

# dialog_open — 检测弹窗是否处于打开状态
# 【用途】弹窗出现断言的可靠原语：入口按钮与弹窗标题同文本时，assert_visible
#         的快照文本匹配会误命中按钮文本造成假阳性（022/023 实测教训），
#         改为检测 [role=dialog]/dialog/[role=modal] 元素数量。
# 【参数】无
# 【返回】0 = 有弹窗打开；1 = 无弹窗
# 【示例】click_by_text '<入口按钮>' '<说明>'; ab_wait 1500
#         dialog_open || { echo "  [失败] 弹窗未出现" >&2; exit 1; }
dialog_open() {
    local n
    n=$(agent-browser eval 'document.querySelectorAll("[role=dialog],dialog,[role=modal]").length' 2>/dev/null)
    case "$n" in
        ''|*[!0-9]*) return 1;;   # 空或非数字（会话异常/报错文本）视为无弹窗
    esac
    [ "$n" -gt 0 ]
}

# wait_for_dialog — 轮询等待弹窗出现
# 【用途】弹窗打开判定（含渲染等待），dialog_open 的轮询版。
# 【参数】$1 = 轮询次数（默认 10）；$2 = 间隔毫秒（默认 1000）
# 【返回】0 = 弹窗已出现；1 = 超时未出现
wait_for_dialog() {  # $1=轮询次数(默认10) $2=间隔ms(默认1000)
    local i
    for ((i = 0; i < ${1:-10}; i++)); do
        dialog_open && return 0
        ab_wait "${2:-1000}"
    done
    return 1
}

# wait_element_gone — 轮询等待 DOM 元素消失（提交生效校验）
# 【用途】表单提交后校验弹窗/表单元素已从 DOM 消失——必填项缺失时平台常
#         静默拦截提交（弹窗不关闭、无提示、无请求），以此把静默失败显性化
#         （OP-19，026 实践沉淀）。
# 【参数】$1 = CSS 选择器（如 "#add-item-name"，勿含单引号）；
#         $2 = 轮询次数（默认 15）；$3 = 间隔毫秒（默认 1000）
# 【返回】0 = 元素已消失（提交生效）；1 = 超时仍存在（提交未生效）
# 【示例】ab_click_last_exact '创建' '提交按钮'
#         wait_element_gone '#add-item-name' \
#             || { echo "  [失败] 弹窗未关闭——校验未通过" >&2; exit 1; }
wait_element_gone() {  # $1=CSS选择器 $2=轮询次数(默认15) $3=间隔ms(默认1000)
    local i res
    for ((i = 0; i < ${2:-15}; i++)); do
        res=$(agent-browser eval "!!document.querySelector('${1}')" 2>/dev/null)
        case "$res" in
            *true*)   ;;            # 元素仍存在，继续轮询
            *false*)  return 0;;    # 元素已从 DOM 消失 → 提交生效
            *)        ;;            # eval 异常输出（空/报错）：继续轮询，不误判为已消失
        esac
        ab_wait "${3:-1000}"
    done
    return 1
}

# wait_for_network_status — 轮询接口状态码（瞬时 toast 兜底）
# 【用途】成功/失败提示为瞬时 toast（快照与 innerText 均捕获不到）时，改抓
#         agent-browser network requests 中 URL 含特征的最新请求，按状态码
#         三态判定：2xx = 成功，4xx/5xx = 失败（立即返回），无请求继续轮询
#         （OP-22，018/011/023 实践沉淀）。
# 【参数】$1 = 接口 URL 特征（grep -F 固定字符串）；
#         $2 = 轮询次数（默认 30）；$3 = 间隔秒（默认 1）
# 【返回】0 = 命中 2xx；1 = 命中 4xx/5xx 或超时
# 【示例】agent-browser network requests --clear >/dev/null 2>&1
#         click_by_text '<触发按钮>' '<说明>'
#         wait_for_network_status 'personal-access-tokens' || { WARN=$((WARN+1)); }
wait_for_network_status() {  # $1=URL特征 $2=轮询次数(默认30) $3=间隔秒(默认1)
    local i line st
    for ((i = 0; i < ${2:-30}; i++)); do
        line=$(agent-browser network requests --type xhr,fetch 2>/dev/null \
               | grep -F -- "$1" | tail -1)
        if [ -n "$line" ]; then
            st=$(printf '%s\n' "$line" | awk '{print $NF}')
            case "$st" in
                2*) return 0;;
                4*|5*) return 1;;
                *) ;;    # 3xx 等其他状态：暂不判定，继续轮询等终态请求
            esac
        fi
        sleep "${3:-1}"
    done
    return 1
}

# click_by_heading — 点击 heading 标题元素（坐标点击）
# 【背景】列表卡片/条目的标题常为 "heading + onclick" 结构，ab_click 的 JS
#         el.click() 对这类元素返回 ok 但不触发跳转（合成事件被 React
#         Router 忽略），agent-browser 坐标点击（CDP 真实鼠标事件）可生效。
#         ref_by_exact/ref_by_text 的角色白名单不含 heading，故单独定位。
# 【参数】$1 = 精确标题文本；$2 = 说明（可选）；$3 = soft（非空时未命中返回 1）
# 【退出】未找到 heading → 报错并 exit 1（硬失败）；soft 模式返回 1
click_by_heading() {  # $1=标题文本 $2=说明(可选) $3=soft(可选)
    local r i
    for ((i = 0; i < 10; i++)); do
        r=$(extract_ref "$(snap_i)" "- heading \"${1}\"")
        [ -n "$r" ] && break
        ab_wait 500
    done
    if [ -z "$r" ]; then
        if [ -n "${3:-}" ]; then
            echo "  [跳过] 未找到标题元素: $1${2:+（$2）}" >&2
            return 1
        fi
        echo "  [失败] 未找到标题元素: $1${2:+（$2）}" >&2
        exit 1
    fi
    agent-browser click "@${r}" >/dev/null
    ab_wait 1000
}

# ---------------------------------------------------------------------------
# 4. 元素操作
# ---------------------------------------------------------------------------

# click_by_text — 按可见文本点击
# 【用途】最常见的点击入口：先按文本定位（角色优先），再点击。
# 【参数】$1 = 文本；$2 = 说明（可选，失败日志中带出便于定位问题）
# 【退出】未找到元素 → 报错并 exit 1（硬失败，防止后续在错误状态下继续执行）
# ab_click — 通用文本点击（JS 优先，agent-browser 兜底）
# 【背景】agent-browser 0.34.0 的坐标点击对 Remix data-discover 链接及部分
#         侧边栏元素（link/button）静默失效（0.27.0 无头模式同源 bug 残留），
#         JS el.click() 经实测可靠生效；故优先 JS，未命中再退回快照 ref 点击。
# 【参数】$1 = 可见文本；$2 = 说明（可选）；$3 = 精确匹配（1=精确优先，默认 0）
#        $4 = soft（非空时未命中仅告警并返回 1，不退出）
# 【退出】两种方式均未命中 → 报错并 exit 1（硬失败）；soft 模式返回 1
# _ab_eval_click_retry — 执行 JS 点击并按需轮询（私有工具）
# 【用途】ab_click / ab_click_last_exact 共用的"JS eval + 时序性失败重试"层：
#         ok 即成功（含 800ms 渲染等待）；disabled/notfound 轮询至多 $2 次
#         （React 受控组件 re-render / 表格重渲染过渡态均有延迟，元素瞬时
#         不可见属时序性问题）；其余输出（eval 异常）立即放弃，转兜底路径。
_ab_eval_click_retry() {  # $1=jscode $2=最大尝试次数(默认8)
    local jscode="$1" tries=0 res
    while :; do
        res=$(agent-browser eval "$jscode" 2>/dev/null)
        case "$res" in
            *ok*) ab_wait 800; return 0;;
            *disabled*|*notfound*)
                tries=$((tries+1))
                [ "$tries" -ge "${2:-8}" ] && break
                ab_wait 500
                continue;;
        esac
        break
    done
    return 1
}

ab_click() {  # $1=文本 $2=说明(可选) $3=精确匹配(1=精确优先) $4=soft
    local mode="${3:-0}" jscode r
    jscode=$(printf '(()=>{const t=new TextDecoder().decode(Uint8Array.from(atob("%s"),c=>c.charCodeAt(0)));const mode=%s;const sels="a,button,[role=menuitem],[role=tab],[role=link],[role=button],[role=option],[role=treeitem],[role=radio],[onclick]";const all=[...document.querySelectorAll(sels)].filter(e=>{const r=e.getBoundingClientRect();return r.width>0&&r.height>0});const name=e=>(e.textContent||"").trim()||(e.getAttribute&&e.getAttribute("aria-label"))||(e.getAttribute&&e.getAttribute("title"))||"";const enabled=e=>!e.disabled&&e.getAttribute("aria-disabled")!=="true";let el=all.find(e=>enabled(e)&&name(e)===t);if(!el&&mode===0)el=all.find(e=>enabled(e)&&name(e).includes(t));if(el){el.click();return "ok"}const dis=all.find(e=>!enabled(e)&&(name(e)===t||(mode===0&&name(e).includes(t))));if(dis)return "disabled";return "notfound"})()' "$(_b64 "$1")" "$mode")
    _ab_eval_click_retry "$jscode" && return 0
    # JS 未命中 → agent-browser 快照 ref 兜底
    if [ "$mode" = "1" ]; then
        r=$(ref_by_exact "$1") || r=$(ref_by_text "$1")
    else
        r=$(ref_by_text "$1")
    fi
    if [ -n "$r" ]; then
        agent-browser click "@${r}" >/dev/null
        ab_wait 800
        return 0
    fi
    if [ -n "${4:-}" ]; then
        echo "  [跳过] 未找到元素: $1${2:+（$2）}" >&2
        return 1
    fi
    echo "  [失败] 未找到元素: $1${2:+（$2）}" >&2
    exit 1
}

click_by_text() {  # $1=文本 $2=说明(可选)
    ab_click "$1" "$2" 0
}

# click_by_exact — 按精确文本点击（找不到退化为按文本）
# 【用途】页面存在 "创建" 与 "创建顶层组织" 等前缀歧义时先用精确匹配；
#         精确未命中再退化 ref_by_text，兼顾精度与容错。
# 【参数】$1 = 精确文本；$2 = 说明（可选）；$3 = soft（可选，非空时未命中仅告警返回 1）
# 【退出】两级都未找到 → 报错并 exit 1（硬失败）；soft 模式返回 1
click_by_exact() {  # $1=精确文本 $2=说明(可选) $3=soft(可选)
    ab_click "$1" "$2" 1 "${3:-}"
}

# ab_click_last_exact — 按"最后一个"精确文本匹配点击
# 【用途】同名按钮歧义场景：页面空状态引导按钮与弹窗提交按钮同文本（如
#         010 的"创建项目"：空列表引导按钮 DOM 在前、弹窗提交按钮靠后），
#         ab_click/click_by_exact 取 DOM 顺序第一个会点到弹窗外按钮，提交
#         从未发生；弹窗/抽屉等浮层在 DOM 树中恒靠后，取最后一个匹配即
#         浮层内控件。
# 【参数】$1 = 精确文本；$2 = 说明（可选）
# 【退出】轮询 8 次（含禁用等待）未命中 → 报错并 exit 1（硬失败）
ab_click_last_exact() {  # $1=精确文本 $2=说明(可选)
    local jscode
    jscode=$(printf '(()=>{const t=new TextDecoder().decode(Uint8Array.from(atob("%s"),c=>c.charCodeAt(0)));const sels="a,button,[role=button]";const all=[...document.querySelectorAll(sels)].filter(e=>{const r=e.getBoundingClientRect();return r.width>0&&r.height>0});const name=e=>(e.textContent||"").trim()||(e.getAttribute&&e.getAttribute("aria-label"))||"";const enabled=e=>!e.disabled&&e.getAttribute("aria-disabled")!=="true";const el=[...all].reverse().find(e=>enabled(e)&&name(e)===t);if(el){el.click();return "ok"}const dis=[...all].reverse().find(e=>!enabled(e)&&name(e)===t);if(dis)return "disabled";return "notfound"})()' "$(_b64 "$1")")
    _ab_eval_click_retry "$jscode" && return 0
    echo "  [失败] 未找到元素（含浮层）: $1${2:+（$2）}" >&2
    exit 1
}

# fill_by_label — 按表单标签填充输入框
# 【用途】对指定标签的输入框（textbox/combobox/spinbutton）填写值。
# 【参数】$1 = 标签文本；$2 = 填充值；$3 = 说明（可选）
# 【退出】未找到输入框 → 报错并 exit 1（硬失败）
fill_by_label() {  # $1=标签文本 $2=填充值 $3=说明(可选)
    local r
    r=$(ref_by_label "$1") || { echo "  [失败] 未找到输入框: $1${3:+（$3）}" >&2; exit 1; }
    agent-browser fill "@${r}" "$2" >/dev/null
}

# fill_by_any_label — 按候选标签依次尝试填充
# 【用途】字段无统一标签（不同页面叫法不同）时，依次尝试多个候选标签，
#         首个命中即填充生效。
# 【参数】$1 = 填充值；其余参数 = 候选标签列表
# 【退出】全部未命中 → 报错并 exit 1（硬失败）
# 【示例】fill_by_any_label "$值" '新用户邮箱' '邮箱'
fill_by_any_label() {  # $1=填充值，其余=候选标签
    local val="$1"; shift
    local lbl r
    for lbl in "$@"; do
        r=$(ref_by_label "$lbl") && { agent-browser fill "@${r}" "$val" >/dev/null; return 0; }
    done
    echo "  [失败] 未找到输入框（候选标签: $*）" >&2
    exit 1
}

# click_radio — 点击单选选项
# 【用途】表单单选场景：先按 LabelText/radio 角色匹配，未命中退化按可见文本。
# 【参数】$1 = 选项文本
# 【退出】未找到选项 → 报错并 exit 1（硬失败）
click_radio() {  # $1=选项文本
    local r pat
    pat=$(_ere_escape "$1")
    r=$(extract_ref "$(snap_i)" "- (LabelText|radio) \"[^\"]*${pat}") || r=$(ref_by_text "$1") \
        || { echo "  [失败] 未找到单选选项: $1" >&2; exit 1; }
    agent-browser click "@${r}" >/dev/null
    ab_wait 500
}

# ---------------------------------------------------------------------------
# 5. 下拉框
# ---------------------------------------------------------------------------

# select_option — 下拉框两步法选择
# 【用途】浮层式下拉框：先点击触发器展开选项列表，再从展开后的快照点击目标选项。
# 【参数】$1 = 触发器标签/文本；$2 = 选项文本
# 【退出】触发器或选项未找到 → 报错并 exit 1（硬失败）
# 【示例】select_option '上传范围' '平台级'
# 【注意】展开后选项出现在浮层（option/listitem 角色）；若 @ref 点击报
#         CDP box model 错误，改用 select_by_native
select_option() {  # $1=触发器标签/文本 $2=选项文本
    local r o pat
    r=$(ref_by_label "$1") || r=$(ref_by_text "$1") \
        || { echo "  [失败] 未找到下拉框: $1" >&2; exit 1; }
    agent-browser click "@${r}" >/dev/null
    ab_wait 500
    pat=$(_ere_escape "$2")
    o=$(extract_ref "$(snap_i)" "- (option|listitem) \"[^\"]*${pat}") || o=$(ref_by_text "$2") \
        || { echo "  [失败] 未找到选项: $2" >&2; exit 1; }
    agent-browser click "@${o}" >/dev/null
    ab_wait 500
}

# select_by_native — 原生 select 命令选择
# 【用途】两步法点击 @ref 报 CDP box model 错误（浮层元素不可点）时的替代方案：
#         直接用 agent-browser select 原生命令设置下拉值。
# 【参数】$1 = ref（eN）；$2 = 选项文本；$3 = 说明（可选）
# 【退出】选择失败 → 报错并 exit 1（硬失败）
# 【示例】select_by_native "$(refs_of_role combobox | tail -1)" 'Admin'
select_by_native() {  # $1=ref $2=选项文本 $3=说明(可选)
    agent-browser select "@${1}" "$2" >/dev/null \
        || { echo "  [失败] 选择 ${2} 失败${3:+（$3）}" >&2; exit 1; }
    ab_wait 500
}

# ---------------------------------------------------------------------------
# 6. 上传 / 取值
# ---------------------------------------------------------------------------

# upload_file — 上传本地文件
# 【用途】OS 原生文件对话框无法用 click 操作，需用 agent-browser upload 命令注入。
# 【定位】优先探测隐藏 input[type=file]（自定义上传区域场景，快照 ref 定位不到
#         且误匹配会报 CDP 错误）；无 file input 再按可见文本，退化含"上传"的控件。
# 【参数】$1 = 控件定位文本；$2 = 本地文件绝对路径
# 【退出】未找到控件 → 报错并 exit 1（硬失败）
upload_file() {  # $1=控件定位文本 $2=本地文件绝对路径
    local r
    if agent-browser eval '!!document.querySelector("input[type=file]")' 2>/dev/null | grep -i true >/dev/null; then
        # 自定义上传区域（generic 可点击块）背后挂隐藏 file input，直接注入
        agent-browser upload "input[type=file]" "$2" >/dev/null
    else
        r=$(ref_by_text "$1") || r=$(extract_ref "$(snap_i)" '- (button|textbox).*上传') \
            || { echo "  [失败] 未找到文件选择控件: $1" >&2; exit 1; }
        agent-browser upload "@${r}" "$2" >/dev/null
    fi
    ab_wait 1000
}

# get_element_value — 取元素值
# 【用途】读取元素当前值：get value 为空（静态文本元素）时退化为 get text。
# 【参数】$1 = ref（eN）
# 【输出】stdout = 元素值
get_element_value() {  # $1=ref
    local v
    v=$(agent-browser get value "@${1}" 2>/dev/null)
    [ -z "$v" ] && v=$(agent-browser get text "@${1}" 2>/dev/null)
    printf '%s' "$v"
}

# save_element_value — 提取元素值并落盘
# 【用途】令牌/密钥抓取场景：如 PAT 以 pat_ 前缀文本展示，取到后写入文件供后续脚本复用。
# 【参数】$1 = ref（eN）；$2 = 输出文件绝对路径
# 【返回】0 = 成功（文件已写入，权限 600）；1 = 未抓取到值
# 【副作用】创建/覆盖 $2 并 chmod 600（敏感信息最小权限）
# 【示例】ref=$(extract_ref "$(snap_i)" 'pat_') && save_element_value "$ref" "$DATA_DIR/pat.txt"
save_element_value() {  # $1=ref $2=输出文件
    local v
    v=$(get_element_value "$1")
    if [ -n "$v" ]; then
        printf '%s' "$v" > "$2"
        chmod 600 "$2"
        echo "  已写入: $2"
        return 0
    fi
    echo "  [失败] 未抓取到元素值" >&2
    return 1
}

# ---------------------------------------------------------------------------
# 7. 树 / 搜索等复杂控件
# ---------------------------------------------------------------------------

# expand_all_tree — 展开所有折叠的树节点
# 【用途】组织树默认折叠、子节点未渲染时，一次性点击所有折叠中的
#         "Expand" 小三角按钮（JS eval 直查 DOM，绕过快照 / ref）。
# 【参数】无
# 【输出】stdout = 展开按钮数量（已重定向丢弃）
# 【注意】1. agent-browser eval 执行 JS 表达式：箭头函数必须写成 IIFE 才会被调用，
#            纯 "=> {...}" 只会被求值为函数对象（返回 {}），点击不会发生
#         2. 树节点小三角为图标按钮：可访问名来自 aria-label（无 textContent、
#            无 aria-expanded 属性），且展开后 aria-label 变为 "Collapse" ——
#            故按 aria-label 前缀 "Expand" 过滤天然只命中折叠节点
expand_all_tree() {
    agent-browser eval "(() => { const b=[...document.querySelectorAll('button')].filter(x => (x.getAttribute('aria-label')||'').trim().startsWith('Expand') || (x.textContent||'').trim().startsWith('Expand')); b.forEach(x => x.click()); return b.length; })()" >/dev/null 2>&1
}

# click_tree_node — 轮询点击组织树节点（树面板内 DOM 精确定位）
# 【用途】点击 [组织与项目] 抽屉组织树中的指定节点（子组织/项目层级 button）。
# 【参数】$1 = 节点名；$2 = 轮询次数（默认 8）
# 【返回】0 = 点击成功；1 = 超时未找到（不退出，由调用方决定处理）
# 【示例】click_tree_node "$ORG_NODE" || { echo 失败; exit 1; }
# 【原理】树节点点击在浏览器内一次 JS eval 完成，三步闭环：
#   1. 定位树面板：含 h3 "组织与项目" 标题的 fixed 容器（挂 header 下）
#   2. 展开折叠节点：点击面板内 aria-label="Expand" 图标按钮（子节点懒渲染，
#      折叠时目标节点根本不在 DOM）；展开动作发生则本轮结束，等下轮再点击
#   3. 面板内精确文本匹配：button.textContent.trim() === 节点名 → el.click()
# 【设计要点】不可用全页子串匹配定位树节点，两因：①树折叠时子组织节点未
#   渲染，子串匹配会误命中主内容区项目列表的同名前缀链接；②抽屉开启时其
#   全屏遮罩 div.fixed.inset-0 盖住主内容区，坐标点击被拦。故定位范围收敛
#   到树面板内 + 文本全等匹配 + JS el.click()（绕过坐标命中测试）。
# 【注意】顶层组织名渲染为 div（非 button，不可点击进入），本函数目标为
#         button 形态的子组织/项目节点；点击成功后抽屉自动关闭并导航。
click_tree_node() {  # $1=节点名 $2=轮询次数(默认8)
    local i res b64 jscode
    b64=$(_b64 "$1")
    jscode=$(printf '(()=>{const t=new TextDecoder().decode(Uint8Array.from(atob("%s"),c=>c.charCodeAt(0)));
const h=[...document.querySelectorAll("h3")].find(x=>(x.textContent||"").trim()==="组织与项目");
if(!h)return "NOPANEL";
let p=h;while(p&&p!==document.body){if(getComputedStyle(p).position==="fixed")break;p=p.parentElement;}
if(!p||p===document.body)return "NOPANEL";
const exp=[...p.querySelectorAll("button")].filter(b=>(b.getAttribute("aria-label")||"").trim()==="Expand");
if(exp.length){exp.forEach(b=>b.click());return "EXPANDED"}
const btn=[...p.querySelectorAll("button")].find(b=>(b.textContent||"").trim()===t);
if(btn){btn.click();return "OK"}
return "NOEL"})()' "$b64")
    for ((i = 0; i < ${2:-8}; i++)); do
        res=$(agent-browser eval "$jscode" 2>/dev/null)
        case "$res" in
            *OK*)       ab_wait 1000; return 0;;
            *EXPANDED*) ;;  # 本轮仅展开，子节点异步渲染，下一轮再点击
            *NOPANEL*)  ;;  # 抽屉未渲染完，继续轮询
            *NOEL*)     ;;  # 目标节点尚未出现，继续轮询（含展开等待）
            *)          ;;  # 其他输出（异常），继续轮询
        esac
        ab_wait 1000
    done
    echo "  [失败] 未找到树节点: $1（最后状态: ${res:-无}）" >&2
    return 1
}

# search_and_filter — 搜索框过滤表格
# 【用途】列表页过滤数据：点击[搜索] → 等待搜索框 → fill → Enter 提交 → 等待过滤完成。
# 【参数】$1 = 关键词
# 【返回】0 = 完成；1 = 未找到搜索按钮或搜索框
# 【示例】search_and_filter "$FLAG" || exit 1
# 【注意】过滤完成判定 = 快照出现"编辑"按钮；等不到也返回 0（宽容策略，
#         过滤结果交由后续断言校验）
search_and_filter() {  # $1=关键词
    local sbtn ref j
    sbtn=$(ref_by_text '搜索') || { echo "  [失败] 未找到搜索按钮" >&2; return 1; }
    agent-browser click "@${sbtn}" >/dev/null
    ab_wait 800
    ref=""
    for ((j = 0; j < 10; j++)); do
        ref=$(extract_ref "$(snap_i)" '- (textbox|searchbox)')
        [ -n "$ref" ] && break
        ab_wait 500
    done
    [ -n "$ref" ] || { echo "  [失败] 未找到搜索框" >&2; return 1; }
    agent-browser fill "@${ref}" "$1" >/dev/null
    agent-browser press Enter >/dev/null
    # 等待表格过滤完成（出现含关键词的结果行 cell；不可用"编辑按钮"判定——
    # 未过滤表格本来就有编辑按钮，会假完成导致后续在重渲染过渡态取值/点击）
    # 【勿用 grep -q】grep -q 命中即退出会使上游 printf 遭 EPIPE（Broken pipe），
    # pipefail 下管道退出码变 141 → if 恒为假：命中也无法提前返回，等待循环
    # 必然跑满（019 实测教训，2026-09-02）；改为 grep >/dev/null——grep 会读完
    # 全部输入再退出，printf 正常写完，退出码语义正确
    # 轮询 15 次 × 1000ms：慢平台（保存后列表重拉/接口抖动）下原 10×500ms
    # 窗口不足（019 复核段 15s 内行未渲染），放宽至 ~15s
    for ((j = 0; j < 15; j++)); do
        if printf '%s\n' "$(snap_i)" | grep -E -- "cell \"[^\"]*$(_ere_escape "$1")" >/dev/null; then return 0; fi
        ab_wait 1000
    done
    echo "  [告警] 等待过滤结果超时（15 次），快照中未出现含 '$1' 的表格行" >&2
    return 0
}

# clear_search_box — 清空当前搜索框
# 【用途】关键词残留会污染后续定位，切换搜索前清空（fill 空 + Enter）。
# 【参数】无
# 【返回】0 = 已清空，或本来就没有搜索框
clear_search_box() {
    local ref
    ref=$(extract_ref "$(snap_i)" '- (textbox|searchbox)') || return 0
    agent-browser fill "@${ref}" "" >/dev/null
    agent-browser press Enter >/dev/null
    ab_wait 800
}

# cell_after — 取表格行内特征 cell 之后的第 N 个 cell
# 【用途】表格行内多 cell 场景：以特征文本所在行为起点，向后取第 N 个 cell 文本
#         （如状态列）。
# 【参数】$1 = 特征 cell 文本；$2 = 向后跳过数（默认 1）
# 【输出】stdout = 目标 cell 行文本（未找到则为空）
# 【示例】status=$(cell_after "$flag" 1)
cell_after() {  # $1=特征 cell 文本 $2=向后跳过数(默认1)
    snap_i | awk -v feat="$1" -v skip="${2:-1}" '
        index($0, "cell \"" feat "\"") { found = 1; s = skip; next }
        found && /cell "/ { if (s > 0) { s--; next } print; exit }
    '
}

# ---------------------------------------------------------------------------
# 7b. iframe 内元素操作
# ---------------------------------------------------------------------------

# act_in_frame — 在任意层级 iframe 中按选择器操作
# 【用途】快照 ref 范式覆盖不到的 iframe 内元素：以 JS eval 在浏览器主文档
#         执行定位 + 事件派发，穿透多层嵌套 iframe（含跨域自动跳过）。
# 【原理】吸收 agent-browser-lib.sh 的 act 设计，去掉"录制 frame 路径"依赖：
#   * BFS 从主文档起遍历所有同源 iframe 的 contentDocument，按选择器反查，
#     要求全局唯一命中（含同一文档内的多处命中）；多处命中返回 AMBIG 拒绝
#     执行（防页面结构变化后静默错点）
#   * 跨域 frame 的 contentDocument 不可访问（null/抛异常），自动跳过
#   * fill/select 赋值后派发 input+change 事件（bubbles），
#     让挂在祖先节点上的事件委托也能收到；click/dblclick 派发合成事件
#   * NOEL 属时序性失败（控件懒加载未渲染），按 ACT_RETRY 重试；
#     AMBIG 为确定性歧义，重试无意义直接失败
# 【参数】
#   $1 = 选择器：CSS（"#id"、".cls > span"）或 "xpath/" 前缀的 XPath
#   $2 = 动作：click | fill | select | dblclick
#   $3 = 值（fill/select 必填，其余可省略）
# 【返回】0 = 操作成功；1 = 失败（NOEL/AMBIG/其他，均 exit 1）
# 【输出】stdout = [操作] 日志；stderr = [失败] 详情
# 【示例】
#   act_in_frame 'input[name="repoName"]' fill 'my-repo'           # CSS 填充
#   act_in_frame 'xpath://button[contains(text(),"确定")]' click     # XPath 点击
#   act_in_frame 'select#env' select 'prod'                         # 原生下拉
# 【注意】
#   * 选择器/值内插在 JS 单引号字符串中，值中不能含单引号
#   * 仅同源 iframe 可穿透，跨域 frame 内元素需其他手段
#   * 可选环境变量 ACT_RETRY（重试次数，默认 5）
act_in_frame() {  # $1=选择器(CSS 或 xpath/ 前缀) $2=动作(click/fill/select/dblclick) $3=值(可选)
    local sel="$1" action="$2" val="${3:-}" js out i
    js=$(cat <<EOF
(function () {
    // 选择器解析：'xpath/' 前缀走 XPath（快照式取全部命中），否则按 CSS 取全部命中
    function findAll(doc) {
        var sel = '${sel}';
        if (sel.indexOf('xpath/') === 0) {
            var r = doc.evaluate(sel.slice(6), doc, null, XPathResult.ORDERED_NODE_SNAPSHOT_TYPE, null);
            var out = [];
            for (var k = 0; k < r.snapshotLength; k++) out.push(r.snapshotItem(k));
            return out;
        }
        return Array.prototype.slice.call(doc.querySelectorAll(sel));
    }
    // BFS 遍历所有同源 frame，统计全局命中总数（跨文档与单文档内均要求唯一）
    var queue = [document], total = 0, el = null;
    while (queue.length) {
        var cur = queue.shift();
        var hits = findAll(cur);
        for (var k = 0; k < hits.length; k++) { total++; if (el === null) el = hits[k]; }
        var frames = cur.querySelectorAll('iframe');
        for (var i = 0; i < frames.length; i++) {
            try { if (frames[i].contentDocument) queue.push(frames[i].contentDocument); } catch (e) {}
        }
    }
    if (total > 1) return 'AMBIG';
    if (el === null) return 'NOEL';
    // 执行动作
    switch ('${action}') {
        case 'fill':
        case 'select':
            el.value = '${val}';
            el.dispatchEvent(new Event('input',  { bubbles: true }));
            el.dispatchEvent(new Event('change', { bubbles: true }));
            break;
        case 'click':
            el.click();
            break;
        case 'dblclick':
            el.dispatchEvent(new MouseEvent('dblclick', { bubbles: true }));
            break;
    }
    return 'OK';
})()
EOF
)
    # 仅对时序性失败（NOEL）重试，AMBIG/OK 直接跳出
    for ((i = 0; i < ACT_RETRY; i++)); do
        out=$(agent-browser eval "$js" 2>&1)
        case "$out" in
            *NOEL*) [ $((i + 1)) -lt "$ACT_RETRY" ] && sleep 0.5;;
            *) break;;
        esac
    done
    case "$out" in
        *OK*) echo "  [操作] ${action} @ ${sel}"; ab_wait 500; return 0;;
        *NOEL*)  echo "  [失败] 元素不存在: ${sel} (${action})" >&2;;
        *AMBIG*) echo "  [失败] 选择器命中多处（跨 frame 或同文档内），拒绝猜测: ${sel}" >&2;;
        *)       echo "  [失败] ${sel} (${action}): ${out}" >&2;;
    esac
    exit 1
}

# ---------------------------------------------------------------------------
# 8. 断言
# ---------------------------------------------------------------------------
# 【软断言 vs 硬断言】
#   软断言（assert_snapshot_contains / missing / url_* / file_not_empty）：
#     失败仅累加 WARN，不中断执行，收尾由 finish() 汇总决定退出码 ——
#     适合"尽量跑完、最后汇总"的批量校验。
#   硬断言（assert_visible / 定位失败 exit 1）：
#     失败立即退出 —— 适合"关键前置条件不成立则继续执行无意义"的场景。

# assert_snapshot_contains — 软断言：快照包含特征文本
# 【用途】页面内容校验；失败仅累加 WARN 不中断，收尾由 finish 汇总。
# 【参数】$1 = 特征文本；$2 = 说明（断言日志文案）
# 【副作用】失败时 WARN+1
# 【示例】assert_snapshot_contains '创建成功' '组织创建成功提示'
assert_snapshot_contains() {  # $1=特征文本 $2=说明
    local snap; snap=$(snap_i)
    case "$snap" in
        *"$1"*) echo "  [断言通过] $2";;
        *) echo "  [断言失败] $2：快照中未找到 '$1'" >&2; WARN=$((WARN+1));;
    esac
}

# assert_snapshot_missing — 软断言：快照不包含特征文本
# 【用途】反向校验（登录态清除、列表删除等场景）；失败仅累加 WARN 不中断。
# 【参数】$1 = 特征文本；$2 = 说明
# 【副作用】失败时 WARN+1
assert_snapshot_missing() {  # $1=特征文本 $2=说明
    local snap; snap=$(snap_i)
    case "$snap" in
        *"$1"*) echo "  [断言失败] $2：快照中仍存在 '$1'" >&2; WARN=$((WARN+1));;
        *) echo "  [断言通过] $2";;
    esac
}

# assert_visible — 硬断言：快照必须包含特征文本
# 【用途】关键页面/弹窗出现校验；未出现即失败退出（与软断言的本质区别）。
# 【参数】$1 = 特征文本；$2 = 说明
# 【退出】未找到 → 报错并 exit 1（硬失败）
assert_visible() {  # $1=特征文本 $2=说明
    local snap; snap=$(snap_i)
    case "$snap" in
        *"$1"*) echo "  [断言通过] $2";;
        *) echo "  [失败] $2：快照中未找到 '$1'" >&2; exit 1;;
    esac
}

# assert_url_matches — 软断言：URL 匹配某子串
# 【用途】导航落点校验；失败时 WARN+1。
# 【参数】$1 = 子串；$2 = 说明
assert_url_matches() {  # $1=子串 $2=说明
    local url
    url=$(agent-browser get url 2>/dev/null)
    case "$url" in
        *"$1"*) echo "  [断言通过] $2: $url";;
        *) echo "  [断言失败] $2，当前 URL: $url" >&2; WARN=$((WARN+1));;
    esac
}

# assert_url_not_matches — 软断言：URL 不匹配某子串
# 【用途】反向导航落点校验（如不应停留在错误页）；失败时 WARN+1。
# 【参数】$1 = 子串；$2 = 说明
assert_url_not_matches() {  # $1=子串 $2=说明
    local url
    url=$(agent-browser get url 2>/dev/null)
    case "$url" in
        *"$1"*) echo "  [断言失败] $2，当前 URL: $url" >&2; WARN=$((WARN+1));;
        *) echo "  [断言通过] $2: $url";;
    esac
}

# assert_file_not_empty — 软断言：文件存在且非空
# 【用途】令牌落盘后的持久化校验；失败时 WARN+1。
# 【参数】$1 = 文件路径；$2 = 说明
assert_file_not_empty() {  # $1=文件 $2=说明
    if [ -s "$1" ]; then
        echo "  [断言通过] $2"
    else
        echo "  [断言失败] $2（文件为空或不存在: $1）" >&2; WARN=$((WARN+1))
    fi
}

# ---------------------------------------------------------------------------
# 9. 登录 / 导航流程
# ---------------------------------------------------------------------------

# ab_find_user_info — JS 定位右上角用户信息按钮（忽略空格差异）
# 【背景】平台渲染用户名时可能在字符间插入空格（如邮箱前缀 test01 显示为
#         "t test 01"），快照子串匹配 "test01" 会落空。本函数在浏览器内将
#         按钮文本去除所有空白后，再与邮箱前缀（同样去空白）做包含匹配；
#         同时保留 Admin Super / 用户信息 兜底特征。
# 【区域限定】按钮过滤限定 header/顶部区域（closest("header") 或
#         top<150）——Portal"热门推荐"资源卡片为整卡可点 button，文本含
#         作者名 "Admin Super"（实测 top~1087 主内容区），不限区域时
#         adminsuper 兜底特征必误命中卡片：is_logged_in 会把未登录 Portal
#         误判为已登录、click_user_info 会误点卡片（012 实测教训，
#         2026-09-07）。真实用户信息按钮恒在顶部（实测 Portal top=12、
#         管理后台 top=10，均在 header 内）。
# 【显示名候选】目标身份为 TEST01_USER 时，右上角按钮渲染的是该用户的
#         显示名（姓+名，如 "t 测试 一" = 头像字母+姓名插空格），完全不含
#         邮箱前缀——故将 姓+名（NEW_USER_LAST+NEW_USER_FIRST）也纳入
#         匹配候选。仅当目标前缀与 TEST01_USER 前缀一致时启用，防止把
#         test01 的显示名误判为其他身份（如 super-admin）的登录态。
# 【参数】$1 = 动作：check（仅检测，默认） | click（找到后点击）
#        $2 = 邮箱前缀（默认取 $ASDM_USER 的 @ 前部分）
#        $3 = strict（非空 = 仅匹配 $2 前缀及其显示名，不做兜底特征匹配）
# 【返回】0 = 找到（click 模式已点击）；1 = 未找到
# 【注意】"是否特定身份已登录"（login 幂等检查）必须传 strict —— 否则
#         super-admin 的 "Admin Super" 按钮会命中兜底特征，把管理员误判
#         为任意目标身份（如 test01）；"是否存在登录态"（is_logged_in /
#         click_user_info）不传 strict，保留兜底以提高容错。
ab_find_user_info() {  # $1=动作(check|click) $2=邮箱前缀(可选) $3=strict(可选)
    local action="${1:-check}" prefix="${2:-${ASDM_USER%%@*}}" strict="${3:-}" dn b64 db64 js res
    # 显示名候选（姓+名）：非 strict（任意登录态检测）时恒启用；
    # strict（特定身份检测）时仅当目标前缀 = TEST01_USER 前缀才启用，防止跨身份误判
    dn=""
    if [ -n "${NEW_USER_LAST:-}${NEW_USER_FIRST:-}" ]; then
        dn="${NEW_USER_LAST}${NEW_USER_FIRST}"
        if [ -n "$strict" ] && { [ -z "${TEST01_USER:-}" ] || [ "$prefix" != "${TEST01_USER%%@*}" ]; }; then
            dn=""
        fi
    fi
    b64=$(_b64 "$prefix")
    db64=$(_b64 "$dn")
    js=$(printf '(()=>{const dec=x=>new TextDecoder().decode(Uint8Array.from(atob(x),c=>c.charCodeAt(0)));const t=dec("%s");const dn="%s"?dec("%s"):"";const norm=s=>(s||"").replace(/\\s+/g,"").toLowerCase();const p=norm(t);const d=norm(dn);const strict="%s"!=="";
const c=[...document.querySelectorAll("button")].filter(b=>{const n=norm(b.textContent);
const hit=(p!==""&&n.includes(p))||(d!==""&&n.includes(d))||(!strict&&(n.includes("adminsuper")||n.includes("用户信息")));
const r=b.getBoundingClientRect();
return hit&&(!!b.closest("header")||r.top<150)&&r.width>0&&r.height>0});
if(!c.length)return "NOEL";if("%s"==="click")c[0].click();return "OK"})()' "$b64" "$db64" "$db64" "$strict" "$action")
    res=$(agent-browser eval "$js" 2>/dev/null)
    case "$res" in
        *OK*) return 0;;
        *)    return 1;;
    esac
}

# is_logged_in — 判断当前是否已登录
# 【原理】任一登录态特征命中即视为已登录：邮箱前缀 / "测试一" / "用户信息"；
#         快照匹配全部落空时退化 JS 规范化空格匹配（覆盖 "test01" 渲染为
#         "t test 01" 这类场景），adminsuper 兜底特征亦在 JS 内完成。
# 【参数】无
# 【返回】0 = 已登录；1 = 未登录
# 【注意】邮箱前缀依赖 $ASDM_USER 的 @ 前部分
is_logged_in() {
    local r
    # 快照级特征仅保留"用户名前缀/显示名/用户信息"字面匹配；勿在此匹配
    # Admin Super（含 button 角色行限定）——Portal 首页"热门推荐"资源卡片
    # 为整卡可点 button，文本含作者名 "Admin Super"（实测 top~1087 主内容
    # 区），快照子串/角色行匹配必误命中，把未登录 Portal 误判为已登录
    # （012 实测教训，2026-09-07）。adminsuper 特征改由下方 ab_find_user_info
    # 兜底——其 JS 已限定 header/顶部区域（top<150），卡片不再干扰，而
    # 真实用户信息按钮恒在顶部（实测 Portal top=12、管理后台 top=10）。
    r=$(ref_by_text "${ASDM_USER%%@*}") \
        || r=$(ref_by_text '测试一') || r=$(ref_by_text '用户信息')
    [ -n "$r" ] && return 0
    ab_find_user_info check
}

# _LOGIN_AS — 进程级登录态标志
# 【用途】记录本进程内已确保登录（或已确认登录态）的目标邮箱；login 对
#         同一邮箱的后续调用直接跳过——goto_admin_console 内置 login 后，
#         显式调用过 login 的脚本不会二次触发"退出重登"，零额外开销。
_LOGIN_AS=""

# login — 完整登录流程（幂等）
# 【流程】打开首页 → 轮询[登录]按钮 → 填邮箱/密码 → 提交 →
#         轮询 URL 离开 /signin（登录成功判定）
# 【幂等】两级：①本进程已确保过同一身份登录（_LOGIN_AS 命中）直接跳过；
#         ②页面已存在登录态且身份一致时自动跳过，不会重复登录
# 【身份自愈】当前登录身份与目标邮箱不符（如 Admin Super 需切换为
#         test01）时，自动退出当前账号再以目标身份重新登录
# 【参数】$1 = 邮箱（默认 $ASDM_USER）；$2 = 密码（默认 $ASDM_PASS）
# 【退出】登录按钮/邮箱框缺失、或提交后未离开 /signin → 报错并 exit 1
login() {  # $1=邮箱(默认$ASDM_USER) $2=密码(默认$ASDM_PASS)
    local email="${1:-$ASDM_USER}" pass="${2:-$ASDM_PASS}" ref i snap
    # 进程级幂等：本进程内已确保过同一身份 → 直接跳过（不重开页面）
    [ "${_LOGIN_AS:-}" = "$email" ] && return 0
    open_page
    # 门户 JS bundle 下载耗时久（页面可空白 1~2 分钟）：
    #   轮询 ~3 分钟（90 次 × ~2s），双出口探测——出现[登录]按钮（未登录）
    #   或用户信息特征（已登录，登录按钮被用户信息替代）即跳出；
    #   已登录场景提前退出，不空等满 3 分钟。
    #   注意：不能用"快照出现任意可交互元素"作就绪信号——页面框架/骨架
    #   先于 auth 状态渲染，会把未登录误判为"已登录身份不符"
    ref=""
    for ((i = 0; i < 90; i++)); do
        snap=$(snap_i)
        ref=$(extract_ref "$snap" "- (button|link|menuitem|tab|option) \"[^\"]*登录")
        [ -n "$ref" ] && break
        ab_find_user_info check && break
        ab_wait 1000
    done
    if [ -z "$ref" ]; then
        # 未等到[登录]按钮：也无任何登录态特征 → 页面加载超时硬失败
        ab_find_user_info check \
            || { echo "  [失败] 页面加载超时（3 分钟内未出现[登录]按钮或登录态，JS 下载未完成？）" >&2; exit 1; }
        # 页面已渲染但无[登录]按钮 → 已登录态：身份一致则跳过（短轮询防
        # 用户信息按钮渲染滞后于页面框架）；不一致则退出换号
        # （快照子串匹配落空时退化 JS 规范化空格匹配，覆盖 "t test 01" 渲染；
        #   strict 确保不被 Admin Super 兜底特征误判为任意目标身份）
        local ok=""
        for ((i = 0; i < 15; i++)); do
            if ref_by_text "${email%%@*}" >/dev/null || ab_find_user_info check "${email%%@*}" strict; then
                ok=1; break
            fi
            ab_wait 1000
        done
        if [ -n "$ok" ]; then
            echo "  已存在登录态（${email%%@*}），跳过登录"
            _LOGIN_AS="$email"; return 0
        fi
        echo "  当前登录身份非 ${email%%@*}，先退出当前账号再重新登录"
        click_user_info
        click_by_exact '退出登录' '退出登录菜单项'
        click_confirm_if_present
        ab_wait 1500
        open_page
        # 退出后回未登录首页：再轮询 ~3 分钟等[登录]按钮
        ref=$(wait_for_ref_by_text '登录' 120) \
            || { echo "  [失败] 未找到【登录】按钮且无登录态" >&2; exit 1; }
    fi
    agent-browser click "@${ref}" >/dev/null
    # 门户首页"登录"按钮跳转可能慢或不触发 SPA 路由：
    # 邮箱框未渲染时兜底直达 /signin 后再轮询（~3 分钟 / 120 次，大 JS 页面渲染慢）
    ref=$(wait_for_ref_by_label '邮箱' 120) || {
        echo "  登录表单未随[登录]按钮渲染，直达 /signin 兜底"
        agent-browser open "${BASE_URL%/}/signin" >/dev/null 2>&1
        ab_wait 1500
        # 兜底后再轮询 120 次（~3 分钟）
        ref=$(wait_for_ref_by_label '邮箱' 120) \
            || { echo "  [失败] 登录页未渲染（未出现邮箱输入框）" >&2; exit 1; }
    }
    agent-browser fill "@${ref}" "$email" >/dev/null
    fill_by_label '密码' "$pass" '密码输入框'
    click_by_text '登录' '登录按钮'
    # 轮询直至 URL 离开 /signin；超时未离开 = 登录失败（凭据/环境异常），
    # 带病继续只会让后续步骤连锁失败，故硬退出
    # 登录提交后跳转轮询 120 次（~3 分钟，大 JS 页面路由慢）
    wait_for_url_gone 'signin' 120 1000 || {
        echo "  [失败] 登录提交后仍未离开 /signin（凭据或环境异常？）" >&2
        exit 1; }
    _LOGIN_AS="$email"
}

# click_user_info — 点击右上角用户信息区域
# 【定位】登录态特征（邮箱前缀 / Admin Super / 测试一 / 用户信息）任一命中即点击。
# 【参数】无
# 【退出】未找到用户信息区域 → 报错并 exit 1（提示是否已完成系统登录）
click_user_info() {
    local i
    # 轮询等待用户信息区域出现（SPA 重载后渲染有延迟，一次性快照易漏检）
    # 优先 JS 精确点击（ab_find_user_info click：仅遍历 button 元素 +
    # 规范化文本，prefix/显示名/adminsuper 多候选兜底）——快照 ref_by_text
    # 'Admin Super' 的角色匹配兜底会被首页"热门推荐"新闻卡片作者行
    # （link）误命中，点开新闻卡片而非用户菜单，菜单未展开导致后续
    # [控制台管理] 必然找不到；JS 只遍历 button 元素不受新闻文本干扰。
    # 轮询 120 次（~3 分钟：大 JS 页面登录后用户信息按钮渲染慢，
    # 页面空白期点击必然落空）
    for ((i = 0; i < 120; i++)); do
        if ab_find_user_info click; then
            ab_wait 800
            return 0
        fi
        ab_wait 1000
    done
    echo "  [失败] 未找到用户信息区域（是否已完成系统登录？）" >&2
    exit 1
}

# goto_admin_console — 导航：Portal → ASDM 管理后台
# 【流程】确保登录态（login 自愈）→ 打开首页 → 点击用户信息区域 → 点击[控制台管理]
# 【自愈】内置幂等 login：未登录自动登录；当前登录身份非目标
#         账号（$ASDM_USER）时自动退出当前账号并换目标账号重新登录——
#         单个回放脚本可独立执行，无需先跑 001 建立登录态（登录态随
#         agent-browser 浏览器会话保持，跨进程依然生效）
# 【落点校验】ab_click 的 JS el.click() 对 [控制台管理] 返回 ok，但 SPA 路由
#         不一定真的跳转（菜单项异步挂载/路由懒加载），无校验直接返回会让
#         后续步骤在 Portal 上找管理后台元素必然失败。故点击后校验落点，
#         未进入则重试，再失败以深链直达。
# 【落点判定】依 basic-operations.md OP-06：
#   URL 含 /projects|/server|/console|/admin，或快照含"平台级设置"/"组织与项目"
#   管理后台首页 URL = /projects（NOT /server；/server 为设置页前缀，直开
#   /server 会被重定向回 /portal）——故判定式中 projects 必列
# 【参数】无
# 【退出】重试与深链兜底均未进入 → 报错并 exit 1
goto_admin_console() {
    echo "[导航] Portal → ASDM 管理后台"
    login
    open_page
    click_user_info
    # soft 点击：菜单项未挂载时不硬失败，交由下方重试与深链兜底
    if ab_click '控制台管理' '控制台管理入口' 0 soft; then
        ab_wait 1500
        in_admin_console 20 && return 0
    fi
    # 重试：回 Portal 重开用户菜单再点一次（首次点击可能落在菜单挂载过渡态）
    echo "  [重试] 未进入管理后台，回 Portal 重开菜单再点击 [控制台管理]"
    open_page
    click_user_info
    ab_click '控制台管理' '控制台管理入口' 0 soft && {
        ab_wait 1500
        in_admin_console 20 && return 0
    }
    # 兜底：SPA 深链直达管理后台首页 /projects
    echo "  [兜底] 直开 ${BASE_URL%/}/projects"
    agent-browser open "${BASE_URL%/}/projects" >/dev/null 2>&1
    ab_wait 2000
    if in_admin_console 30; then
        echo "  [断言通过] 已进入管理后台"
        return 0
    fi
    echo "  [失败] 未能进入 ASDM 管理后台（当前: $(agent-browser get url 2>/dev/null)）" >&2
    exit 1
}

# in_admin_console — 轮询判定当前是否已在 ASDM 管理后台
# 【用途】导航落点校验（goto_admin_console 内部使用），防止"点了但没跳转"
#         导致后续步骤在错误页面上定位元素（007 首轮失败根因）。
# 【判定】URL 含 /projects|/server|/console|/admin，或快照含管理后台
#         特征文本（"平台级设置" / "组织与项目"）——后者覆盖 URL 未变但
#         工作区已渲染的 SPA 情形。
# 【参数】$1 = 轮询次数（默认 20）
# 【返回】0 = 已在管理后台；1 = 超时未进入
in_admin_console() {  # $1=轮询次数(默认20)
    local i url snap
    for ((i = 0; i < ${1:-20}; i++)); do
        url=$(agent-browser get url 2>/dev/null)
        case "$url" in
            */projects*|*/server*|*/console*|*/admin*)
                echo "  [断言通过] 已进入管理后台: $url"; return 0;;
        esac
        snap=$(snap_i)
        case "$snap" in
            *'平台级设置'*|*'组织与项目'*)
                echo "  [断言通过] 已进入管理后台（快照含特征文本，URL: ${url}）"; return 0;;
        esac
        ab_wait 1000
    done
    return 1
}

# goto_platform_settings — 进入 [平台级设置] 页面
# 【用途】003-009 用例的公共前置路径；进入后硬断言页面已打开。
# 【参数】无
# 【退出】页面未出现"平台级设置" → 报错并 exit 1
goto_platform_settings() {
    echo "[导航] 进入 [平台级设置]"
    click_by_text '平台级设置' '平台级设置页面'
    ab_wait 1500
    # 强断言：必须真实进入 /server/_settings（页面出现 Tab 页签组），
    # 避免仅侧边栏入口文本匹配造成的假通过
    local url
    url=$(agent-browser get url 2>/dev/null)
    case "$url" in
        */server/_settings*|*_settings*)
            echo "  [断言通过] 平台级设置页面已打开: $url";;
        *)
            echo "  [断言失败] 未进入平台级设置页面（当前: ${url}）" >&2
            exit 1;;
    esac
}

# click_tab — 点击 Tab 页签
# 【用途】精确匹配优先避免前缀歧义（click_by_exact 封装 + 等待）。
# 【参数】$1 = Tab 名；$2 = 说明（默认 "$1 Tab"）
# 说明：agent-browser 坐标点击对侧边栏/部分 Tab 失效，故 click_tab 先用 ref
#       轮询等"元素已渲染"（ref 仅作出现探测、不用于点击），再交 ab_click
#       （JS 优先）执行真实点击——定位做两遍是有意为之，勿合并。
click_tab() {  # $1=Tab名 $2=说明(可选)
    local r i
    for ((i = 0; i < 10; i++)); do
        r=$(ref_by_exact "$1") && break
        r=$(ref_by_text "$1") && break
        ab_wait 500
    done
    [ -n "$r" ] || { echo "  [失败] 未找到元素: $1${2:+（$2）}" >&2; exit 1; }
    ab_click "$1" "${2:-$1 Tab}" 1
}

# goto_org_project — 打开 [组织与项目] 导航
# 【参数】无
goto_org_project() {
    echo "[导航] 打开 [组织与项目] 导航"
    click_by_text '组织与项目' '组织与项目导航'
    ab_wait 1000
}

# click_confirm_if_present — 二次确认弹窗自动确认
# 【用途】退出登录等需二次确认的场景：弹窗打开且出现 确定/确认 时点击之，
#         弹窗未出现则静默跳过（幂等，可安全重复调用）。
# 【防误点】快照"仅出现 确定/取消 文本"就点击会误点页面自带的孤立 确定
#         按钮（筛选栏/工具条等）。故需满足其一才点击：
#         ① dialog_open 检出真实弹窗（role=dialog/modal，022/023 已验证）；
#         ② 快照同时出现 [确定/确认] 与 [取消]（确认类 UI 的成对特征，
#            覆盖未标 role 的非标准确认条）。
# 【参数】无
click_confirm_if_present() {
    local snap
    snap=$(snap_i)
    case "$snap" in
        *'确定'*|*'确认'*) ;;
        *) return 0;;    # 无确认按钮：无弹窗需处理
    esac
    if ! dialog_open; then
        case "$snap" in
            *'取消'*) ;;             # 确认+取消成对，疑似非标准确认条 → 继续
            *) return 0;;            # 孤立确定按钮（非弹窗）→ 不点，防误点
        esac
    fi
    ab_click '确定' '确认弹窗' 1 soft || ab_click '确认' '确认弹窗' 1 soft || return 0
    ab_wait 800
}

# ---------------------------------------------------------------------------
# 10. 收尾
# ---------------------------------------------------------------------------

# finish — 汇总软断言结果并退出
# 【原理】WARN > 0（存在软断言失败）→ 退出码 1；全部通过 → 退出码 0。
# 【参数】无
# 【注意】每个回放脚本末尾必须调用一次，是 CI 判定通过/失败的出口；
#         此处兜底释放浏览器锁（调用方后设 trap 覆盖锁清理时不泄漏，
#         EXIT trap 内重复释放幂等无害）
finish() {
    _ab_release_lock
    if [ "$WARN" -gt 0 ]; then
        echo "回放结束，${WARN} 项断言未通过。" >&2
        exit 1
    fi
    echo "回放完成，全部断言通过。"
    exit 0
}
