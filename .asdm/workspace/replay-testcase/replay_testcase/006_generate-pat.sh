#!/bin/bash
# 由 006_generate-pat.md 翻译而来（测试用例 markdown → agent-browser）
#
# 通用操作已抽取至 common.sh（快照 ref 驱动），本脚本仅保留用例业务步骤：
#   管理后台 → 用户信息 → 访问令牌 → 创建令牌 → 抓取 PAT 落盘
#
# 前置条件（不自动级联，缺失即报错）：
#   1. 用户已完成系统登录（先执行 replay_testcase/001_system-login.sh）
#
# 注：生成的 PAT 令牌写入 $DATA_DIR/pat.txt（仅供后续用例读取，勿提交仓库）
#
# 运行：bash replay_testcase/006_generate-pat.sh（默认显示浏览器窗口）
# 如需无头模式：HEADED=0 bash replay_testcase/006_generate-pat.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/../common/common.sh"

# 统一测试数据：data/test-data.sh（含全部用例数据，环境变量优先）
DATA_DIR="${SCRIPT_DIR}/../data"
load_data_file "${DATA_DIR}/test-data.sh"


ab_init
require_vars ASDM_USER ASDM_PASS PAT_NAME

# ---------------------------------------------------------------------------
# PAT 完整值抓取（解决页面掩码展示 pat_xxx**** 问题）
# ---------------------------------------------------------------------------
# 【背景】管理后台在令牌创建成功后，DOM 中只渲染掩码文本
#   （形如 pat_XvdcUduk****），save_element_value 取到的即该掩码，落盘后
#   data/pat.txt 不可用。完整令牌只存在于两处：
#     1) [创建令牌] 接口的响应体（一次性明文下发）
#     2) 页面 [复制] 动作写入剪贴板的内容
#   故在点击 [创建] 之前注入钩子，分别捕获 fetch/XHR 响应体与剪贴板写入值。
# 【注意】钩子为页面内 JS，点击 [创建] 属 SPA 局部刷新，不会导致钩子丢失。
PAT_HOOK_JS='(() => { window.__patCap = { net: [], clip: [] }; const push = (k, t) => { try { if (typeof t === "string" && t.indexOf("pat_") !== -1) window.__patCap[k].push(t); } catch (e) {} }; const of = window.fetch; if (of) { window.fetch = function () { const p = of.apply(this, arguments); try { p.then(function (r) { try { r.clone().text().then(function (t) { push("net", t); }); } catch (e) {} return r; }); } catch (e) {} return p; }; } const X = window.XMLHttpRequest; if (X) { const os = X.prototype.send; X.prototype.send = function () { try { this.addEventListener("load", function () { try { push("net", this.responseText); } catch (e) {} }); } catch (e) {} return os.apply(this, arguments); }; } try { const ow = navigator.clipboard.writeText.bind(navigator.clipboard); navigator.clipboard.writeText = function (t) { push("clip", t); return ow(t); }; } catch (e) {} try { const oe = document.execCommand.bind(document); document.execCommand = function (c) { try { if (String(c).toLowerCase() === "copy") { const a = document.activeElement; const v = (a && a.value !== undefined && a.value !== null && a.value) || String(window.getSelection()); if (v) push("clip", v); } } catch (e) {} return oe.apply(document, arguments); }; } catch (e) {} return "hooked"; })()'

# 【提取】优先取接口响应的 data.token（一次性明文），其次取剪贴板载荷；
#         正则要求 pat_ 后至少 16 位有效字符，天然排除 pat_xxx**** 掩码
PAT_EXTRACT_JS='(() => { const c = window.__patCap || { net: [], clip: [] }; for (const s of c.net) { try { const j = JSON.parse(s); if (j && j.data && typeof j.data.token === "string" && j.data.token.indexOf("pat_") === 0) return j.data.token; } catch (e) {} } const out = []; const re = /pat_[A-Za-z0-9_\-]{16,}/g; const scan = (x) => { let m; while ((m = re.exec(x)) !== null) out.push(m[0]); }; c.clip.forEach(scan); c.net.forEach(scan); return out.join("\n"); })()'

# 【幂等清理】删除同名旧令牌
# 【背景】平台对令牌名称唯一性校验：同名 POST 返回 409，创建弹窗不会出现，
#         后续 [复制] 按钮必然找不到（脚本重复执行的头号失败原因）。
#         故创建前先按名称精确匹配行并删除，保证本脚本可反复重跑。
pat_delete_same_name() {  # $1=令牌名称（默认 $PAT_NAME）
    local name="${1:-$PAT_NAME}" b64 js i res
    b64=$(printf '%s' "$name" | base64 | tr -d '\n')

    # 【行匹配】按首列名称精确匹配 tr，点击行内 [删除]
    js=$(printf '(() => { const t = new TextDecoder().decode(Uint8Array.from(atob("%s"), c => c.charCodeAt(0))); const rows = [...document.querySelectorAll("tr")]; for (const r of rows) { const cells = [...r.querySelectorAll("td")].map(c => (c.textContent || "").trim()); if (cells[0] === t) { const b = [...r.querySelectorAll("button")].find(x => (x.textContent || "").trim() === "删除"); if (b) { b.click(); return "OK"; } } } return "NOEL"; })()' "$b64")
    for ((i = 0; i < 8; i++)); do
        res=$(agent-browser eval "$js" 2>/dev/null)
        case "$res" in *OK*) break;; *NOEL*) ab_wait 800; continue;; esac
        break
    done
    case "$res" in *OK*) ;; *) return 0;; esac   # 无同名令牌，无需清理

    # 【二次确认】删除确认弹窗的按钮文案为「确认删除」。
    #   候选文本走**精确相等**匹配，"删除"不在候选内，天然不会误点列表
    #   行内控件；并限定在确认弹窗容器内查找——子串匹配 + 取 DOM 末尾会把
    #   列表最后一行的 [删除] 误当确认按钮点掉（删错令牌 → 创建 409）。
    for ((i = 0; i < 10; i++)); do
        res=$(agent-browser eval '(() => { const vis = e => { const r = e.getBoundingClientRect(); return r.width > 0 && r.height > 0; }; const txt = e => (e.textContent || "").replace(/\s+/g, ""); const dlg = [...document.querySelectorAll("[role=dialog],div,section")].reverse().find(d => { if (!vis(d)) return false; const s = txt(d); if (s.length > 400) return false; return (s.indexOf("确认删除") !== -1 || s.indexOf("确定删除") !== -1 || s.indexOf("确定") !== -1 || s.indexOf("确认") !== -1) && d.querySelector("button"); }); if (!dlg) return "NODLG"; const b = [...dlg.querySelectorAll("button")].reverse().find(x => vis(x) && ["确认删除", "确定删除", "确定", "确认"].indexOf(txt(x)) !== -1); if (!b) return "NOBTN"; b.click(); return "OK"; })()' 2>/dev/null)
        case "$res" in
            *OK*) break;;
            *NODLG*|*NOBTN*) ab_wait 500; continue;;
            *) break;;
        esac
    done
    ab_wait 1200

    # 【校验】确认同名行已消失；未消失则告警（交由后续 409 诊断暴露）
    res=$(agent-browser eval "$(printf '(() => { const t = new TextDecoder().decode(Uint8Array.from(atob("%s"), c => c.charCodeAt(0))); const rows = [...document.querySelectorAll("tr")]; for (const r of rows) { const cells = [...r.querySelectorAll("td")].map(c => (c.textContent || "").trim()); if (cells[0] === t) return "STILL"; } return "GONE"; })()' "$b64")" 2>/dev/null)
    case "$res" in
        *GONE*) echo "  [清理] 已删除同名旧令牌: $name";;
        *)      echo "  [告警] 同名令牌仍存在，创建可能 409: $name" >&2;;
    esac
}

# 【诊断】令牌仍缺失时，dump 页面内所有含 pat_ 的叶子节点（标签/值/属性）
PAT_DOM_DUMP_JS='(() => { const els = [...document.querySelectorAll("*")].filter(e => e.children.length === 0 && (e.textContent || "").indexOf("pat_") !== -1); const out = []; for (const e of els) { const attrs = []; for (const a of e.attributes) attrs.push(a.name + "=" + a.value); out.push([e.tagName, e.value || "", (e.textContent || "").trim(), attrs.join("|")].join(" ~ ")); } const inputs = [...document.querySelectorAll("input,textarea")].map(i => String(i.value || "")).filter(v => v.indexOf("pat_") !== -1); return JSON.stringify({ els: out, inputs: inputs }); })()'

# 【浮层明文提取】创建成功后弹出 [令牌已生成] 浮层，提示
#   "该明文仅展示一次，请立即复制保存。" —— 浮层内 div 直接承载完整明文，
#   与列表页的掩码 prefix（pat_xxx****）不同源，且不依赖剪贴板权限
#   （无需 document focused），故作为抓取主路径。
#   【策略】先按 "令牌已生成" 标题定位浮层容器，在其子树中取含 pat_ 的
#   **最长**匹配（掩码串更短、明文更长）；浮层未出现时退回全局最长匹配。
PAT_DIALOG_JS='(() => { const norm = e => String((e.textContent || "") + " " + (e.value || "")); const re = /pat_[A-Za-z0-9_\-]{16,}/g; const pick = (root) => { let best = ""; for (const e of root.querySelectorAll("*")) { const s = norm(e); let m; while ((m = re.exec(s)) !== null) { if (m[0].length > best.length) best = m[0]; } } return best; }; const dlg = [...document.querySelectorAll("div,section,[role=dialog]")].reverse().find(d => (d.textContent || "").indexOf("令牌已生成") !== -1 && d.querySelectorAll("*").length > 0); const hit = dlg ? pick(dlg) : ""; if (hit) return hit; return pick(document.body); })()'

pat_grab_dialog() { agent-browser eval "$PAT_DIALOG_JS" 2>/dev/null | tr -d '"' | grep -E '^pat_' | head -1; }

pat_grab_clean() { agent-browser eval "$PAT_EXTRACT_JS" 2>/dev/null | grep -E '^pat_' | head -1; }

# pat_read_clipboard — 从系统剪贴板读取完整令牌
# 【原理】用例操作步骤 13 为 [复制] 生成的令牌；页面只渲染掩码，但 [复制]
#   写入剪贴板的是完整明文。故以 agent-browser clipboard read 取回——
#   这是唯一与人工"复制→粘贴"等价的取值路径。
# 【前置】页面需处于聚焦状态，否则 Chromium 报
#   "Document is not focused"（NotAllowedError）；故先 JS focus 再读。
# 【返回】0 = 读到（stdout = 令牌原文）；1 = 未读到
pat_read_clipboard() {
    local v
    agent-browser eval '(() => { window.focus(); document.body.focus(); return "ok"; })()' >/dev/null 2>&1
    v=$(agent-browser clipboard read 2>/dev/null | tr -d '\r\n' | grep -oE 'pat_[A-Za-z0-9_-]{16,}' | head -1)
    [ -n "$v" ] || return 1
    printf '%s' "$v"
    return 0
}

# pat_click_copy — 点击令牌展示弹窗的 [复制] 按钮（JS 点击，免坐标）
# 【背景】弹窗存在 div.absolute.inset-0 覆盖层，agent-browser 坐标点击会被
#   "Element is covered by ..." 拦截，故用页面内 JS 派发点击。
# 【返回】0 = 已点击；1 = 未找到按钮
pat_click_copy() {
    local res
    res=$(agent-browser eval '(() => { const all = [...document.querySelectorAll("button,[role=button],a")].filter(e => { const r = e.getBoundingClientRect(); return r.width > 0 && r.height > 0; }); const b = [...all].reverse().find(e => (e.textContent || "").trim() === "复制"); if (!b) return "NOEL"; b.click(); return "OK"; })()' 2>/dev/null)
    case "$res" in *OK*) ab_wait 800; return 0;; *) return 1;; esac
}

pat_write() {  # $1=令牌原文
    printf '%s' "$1" > "$DATA_DIR/pat.txt"
    chmod 600 "$DATA_DIR/pat.txt"
    echo "  已写入: $DATA_DIR/pat.txt"
}

# pat_fill_name — JS 填充令牌名称（绕过弹窗覆盖层，驱动 React 受控输入）
# 【参数】$1 = 名称
# 【返回】0 = 已填充；1 = 未找到输入框
pat_fill_name() {  # $1=名称
    local b64 js res
    b64=$(printf '%s' "$1" | base64 | tr -d '\n')
    js=$(printf '(() => { const t = new TextDecoder().decode(Uint8Array.from(atob("%s"), c => c.charCodeAt(0))); const dlg = [...document.querySelectorAll("div")].reverse().find(d => (d.textContent || "").indexOf("创建个人访问令牌") !== -1 && d.querySelector("input")); const input = dlg ? dlg.querySelector("input") : document.querySelector("input[maxlength]"); if (!input) return "NOEL"; const setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, "value").set; setter.call(input, t); input.dispatchEvent(new Event("input", { bubbles: true })); input.dispatchEvent(new Event("change", { bubbles: true })); return "OK:" + input.value; })()' "$b64")
    res=$(agent-browser eval "$js" 2>/dev/null)
    case "$res" in *OK:*) return 0;; *) return 1;; esac
}

# pat_select_expiry — JS 选择有效期（当前值已是目标则跳过，规避覆盖层）
# 【背景】弹窗有效期默认 "30 天"，与目标值一致时无需展开下拉——
#         展开动作恰是被覆盖层拦截的高危操作，跳过可显著降低失败率。
# 【参数】$1 = 选项文本（如 "30 天"）
# 【返回】0 = 已是目标值或选择成功；1 = 未命中
pat_select_expiry() {  # $1=选项文本
    local b64 js res
    b64=$(printf '%s' "$1" | base64 | tr -d '\n')
    # 6a: 原生 <select> 优先——按 option 文本（或 value）去空白匹配后，
    #     用原生 value setter + change 事件驱动 React 受控 select；
    #     已是目标值直接返回 SAME（不展开下拉，规避覆盖层拦截）
    js=$(printf '(() => { const t = new TextDecoder().decode(Uint8Array.from(atob("%s"), c => c.charCodeAt(0))).replace(/\\s+/g, ""); const norm = s => String(s || "").replace(/\\s+/g, ""); const sels = [...document.querySelectorAll("select")].filter(e => e.getBoundingClientRect().width > 0); for (const s of sels) { const hit = [...s.options].find(o => norm(o.textContent) === t || norm(o.value) === t); if (hit) { if (String(s.value) === String(hit.value)) return "SAME"; const setter = Object.getOwnPropertyDescriptor(window.HTMLSelectElement.prototype, "value").set; setter.call(s, hit.value); s.dispatchEvent(new Event("change", { bubbles: true })); return "OK"; } } const cbs = [...document.querySelectorAll("[role=combobox]")].filter(e => e.getBoundingClientRect().width > 0); for (const c of cbs) { if (norm(c.textContent) === t) return "SAME"; } return "DIFF"; })()' "$b64")
    res=$(agent-browser eval "$js" 2>/dev/null)
    case "$res" in
        *SAME*|*OK*) ab_wait 400; return 0;;
    esac
    # 6b: 自定义 combobox 回退——JS 展开后点选目标选项
    agent-browser eval '(() => { const c = [...document.querySelectorAll("[role=combobox]")].filter(e => e.getBoundingClientRect().width > 0)[0]; if (!c) return "NOEL"; c.click(); return "OK"; })()' >/dev/null 2>&1
    ab_wait 600
    js=$(printf '(() => { const t = new TextDecoder().decode(Uint8Array.from(atob("%s"), c => c.charCodeAt(0))).replace(/\\s+/g, ""); const norm = e => String(e.textContent || "").replace(/\\s+/g, ""); const all = [...document.querySelectorAll("[role=option],li")].filter(e => e.getBoundingClientRect().width > 0 && norm(e) === t); const o = all[all.length - 1]; if (!o) return "NOEL"; o.click(); return "OK"; })()' "$b64")
    res=$(agent-browser eval "$js" 2>/dev/null)
    ab_wait 600
    case "$res" in *OK*) return 0;; *) return 1;; esac
}

# ---------- 操作步骤 ----------

# step 1: 用户进入 ASDM管理后台 首页
# 单任务补跑/会话过期时可能无登录态，先幂等登录 super-admin 再进管理后台
login
goto_admin_console

# step 2: 点击右上角用户信息区域，展开用户菜单
echo "[step 2] 点击右上角用户信息区域"
click_user_info

# step 3: 点击 [访问令牌]
echo "[step 3] 点击 [访问令牌]"
click_by_text '访问令牌' '访问令牌菜单项'
ab_wait 1500

# step 4: 幂等清理同名旧令牌（平台名称唯一，同名创建会 409 失败）
echo "[step 4] 清理同名旧令牌（${PAT_NAME}）"
pat_delete_same_name

# step 5: 点击 [+创建令牌]
echo "[step 5] 点击 [+创建令牌]"
click_by_text '创建令牌' '创建令牌按钮'
assert_visible '创建个人访问令牌' '[创建个人访问令牌] 弹窗出现'

# step 6: [创建个人访问令牌] 信息录入 —— 令牌名称
# 弹窗存在 div.absolute.inset-0 覆盖层，agent-browser 的
#   fill/click 走坐标事件会被 "Element is covered by ..." 拦截。
#   故名称录入与下拉操作一律走页面内 JS：用原生 value setter + input 事件驱动
#   React 受控组件（直接赋值 el.value 不会触发 React onChange，提交时仍是空值）。
echo "[step 6] 录入令牌名称: $PAT_NAME"
pat_fill_name "$PAT_NAME" || { echo "  [失败] 未找到令牌名称输入框" >&2; exit 1; }

# step 7: 选择有效期（默认已是目标值时跳过，避免被覆盖层拦截）
echo "[step 7] 选择有效期（${PAT_EXPIRY}）"
pat_select_expiry "$PAT_EXPIRY" || { echo "  [失败] 未选择有效期" >&2; exit 1; }

# step 8: 注入捕获钩子（须在点击 [创建] 之前）
echo "[step 8] 注入令牌捕获钩子（剪贴板 / 接口响应）"
agent-browser eval "$PAT_HOOK_JS" >/dev/null 2>&1

# step 9: 点击 [创建] 按钮
echo "[step 9] 点击 [创建]"
click_by_exact '创建' '创建按钮'
ab_wait 1500

# step 10: 抓取生成的 PAT 令牌（特征 pat_）并写入数据目录
echo "[step 10] 抓取 PAT 令牌"
tok=""
# 8a【主路径】等 [令牌已生成] 浮层出现，直接读浮层内 div 承载的完整明文
for _ in 1 2 3 4 5 6 7 8 9 10 11 12; do
    tok=$(pat_grab_dialog) || tok=""
    [ -n "$tok" ] && break
    ab_wait 1000
done
# 8b: 浮层明文结构变化时，点击 [复制] 后从系统剪贴板读（等价人工复制→粘贴）
if [ -z "$tok" ]; then
    for _ in 1 2 3 4 5; do
        if pat_click_copy; then
            tok=$(pat_read_clipboard) || tok=""
            [ -n "$tok" ] && break
        fi
        ab_wait 1000
    done
fi
# 8c: 再退一步取页面内钩子捕获的复制载荷 / 创建接口响应体 data.token
[ -z "$tok" ] && tok=$(pat_grab_clean)

# 关闭令牌展示弹窗，避免残留遮罩影响后续用例
ab_click '关闭' '关闭令牌弹窗' 1 soft

if [ -z "$tok" ]; then
    echo "  [失败] 未抓取到完整令牌（页面仅掩码展示，剪贴板/接口响应均未捕获）" >&2
    echo "  [诊断] 创建接口最近响应状态（409 = 名称重复，需刷新 PAT_NAME）:" >&2
    agent-browser network requests --type xhr,fetch --filter personal-access-tokens --json 2>/dev/null \
        | grep -oE '"method":"[A-Z]+"|"status":[0-9]+' | tail -6 >&2
    echo "  [诊断] 页面含 pat_ 的 DOM 节点：" >&2
    agent-browser eval "$PAT_DOM_DUMP_JS" 2>&1 | head -20 >&2
    exit 1
fi
pat_write "$tok"

# ---------- 预期结果断言 ----------

# 预期结果 1: PAT 令牌已生成并成功落盘（且为完整值，不含掩码）
echo "[断言] PAT 令牌已落盘"
assert_file_not_empty "$DATA_DIR/pat.txt" "PAT 令牌已写入 data/pat.txt"

echo "[断言] PAT 令牌为完整值（无掩码）"
disk_tok=$(tr -d '\r\n' < "$DATA_DIR/pat.txt")
case "$disk_tok" in
    *'*'*)
        echo "  [断言失败] 落盘内容仍为掩码: ${disk_tok}" >&2
        WARN=$((WARN + 1));;
    pat_*)
        echo "  [断言通过] 完整令牌长度 ${#disk_tok}";;
    *)
        echo "  [断言失败] 落盘内容不含 pat_ 前缀: ${disk_tok}" >&2
        WARN=$((WARN + 1));;
esac

# ---------- 收尾（§8.3） ----------
finish
