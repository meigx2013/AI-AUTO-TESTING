#!/bin/bash
# 由 009_resource-management-toolset.md 翻译而来（测试用例 markdown → agent-browser）
#
# 通用操作已抽取至 common.sh（快照 ref 驱动），本脚本仅保留用例业务步骤：
#   管理后台 → 平台级设置 → 资源管理 → 上传资源
#
# 上传三态适配（2026-09-07）：
#   A 上传成功（全新资源）：表单展开 → 填写 → 上传 → 列表断言
#   B 上传覆盖（同名同/更高版本）：确认弹窗放行 → 表单展开 → 同 A
#   C 版本低（平台已有更高版本）：点[取消]关闭弹窗，用例直接判通过
#
# 前置条件（不自动级联，缺失即报错）：
#   1. 用户已完成系统登录（先执行 replay_testcase/001_system-login.sh）
#   2. 本地存在待上传的场景智能体压缩包（UPLOAD_FILE 指向真实文件）
#
# 运行：bash replay_testcase/009_resource-management-toolset.sh（默认显示浏览器窗口）
# 如需无头模式：HEADED=0 bash replay_testcase/009_resource-management-toolset.sh
#
# 注：UPLOAD_FILE 用例原文为 Windows 路径（D:\TEST01\toolset），
#     回放环境必须显式指定本地文件，如 UPLOAD_FILE=/path/to/basic-tools-v2.zip

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/../common/common.sh"

# 统一测试数据：data/test-data.sh（含全部用例数据，环境变量优先）
DATA_DIR="${SCRIPT_DIR}/../data"
load_data_file "${DATA_DIR}/test-data.sh"


ab_init
require_vars ASDM_USER ASDM_PASS UPLOAD_FILE
[ -f "$UPLOAD_FILE" ] || { echo "  [失败] 上传文件不存在: $UPLOAD_FILE" >&2; exit 1; }
fname=$(basename "$UPLOAD_FILE")
# 平台资源管理列表展示的资源名 = 上传文件名（当前
# UPLOAD_FILE 默认 context-builder-8.zip），非压缩包内 registryId；
# 可用 RES_DISPLAY_NAME 环境变量覆盖
RES_DISPLAY_NAME="${RES_DISPLAY_NAME:-$fname}"

# ---------- 操作步骤 ----------

# step 1: 用户进入 ASDM管理后台 首页
# 单任务补跑/会话过期时可能无登录态，先幂等登录 super-admin
login
goto_admin_console

# step 2: 点击左下角 [平台级设置] 按钮
echo "[step 2] 进入 [平台级设置]"
goto_platform_settings

# step 3: 点击 [资源管理] Tab页签（前置依赖 008：hide_admin_resource_management
#         开关须为"全量开放"，否则该 Tab 不显示）
echo "[step 3] 点击 [资源管理] Tab页签"
click_tab '资源管理'

# ---------- 上传主流程（step 4-7：三态适配 + 读错误完全重置重试） ----------
# 上传三态（2026-09-07）：
#   A 上传成功（全新资源）：表单展开（"请输入资源名称"输入框出现）→ step 9 填写提交
#   B 上传覆盖（同名同/更高版本重复上传）：中途出现 ZIP 结构确认[是] /
#     版本覆盖[确认覆盖] 弹窗，点击放行后表单同样展开 → 同 A
#   C 版本低（平台已有更高版本，报错形如"场景智能体版本号必须大于或等于
#     已有版本 1.1.1，当前版本 1.0.0"）→ 点[取消]放弃上传，用例判通过
# 读错误自愈（NotReadableError，2026-09-07 实测）：
#   agent-browser 注入的 File 对象偶发不可读（同文件手动上传无此问题）；
#   错误一旦出现，弹窗内重注入无法恢复（2s/5s/15s 间隔均败）——须点[取消]
#   关闭弹窗完全重置，重走 打开弹窗→选范围/类型→注入 全流程（等效手动
#   上传路径），至多 3 轮
upload_result=""
attempt=0
while :; do
    attempt=$((attempt+1))
    [ "$attempt" -gt 1 ] && { echo "  [重试] 第 ${attempt} 轮上传尝试（完全重置后重走流程）"; ab_wait 2000; }

    # step 4: 点击 [+ 上传资源] 按钮，打开 [上传资源] 窗口
    echo "[step 4] 点击 [+ 上传资源]"
    click_by_text '上传资源' '上传资源按钮'
    assert_visible '上传资源' '[上传资源] 弹窗出现'

    # step 5: [上传资源] 选择上传范围（单选按钮组：项目/全局）+ 资源类型（下拉框）
    # 注意：资源类型下拉的两步法点击（select_option）会报 CDP box model 错误（浮层
    # 元素不可点），实际无法选中——改用 agent-browser 原生 select 命令直接设置
    echo "[step 5] 选择上传范围: $RES_SCOPE / 资源类型: $RES_TYPE"
    ab_click "$RES_SCOPE" "上传范围单选[$RES_SCOPE]" 0
    type_cb=$(ref_by_label '资源类型') \
        || { echo "  [失败] 未找到资源类型下拉框" >&2; exit 1; }
    select_by_native "$type_cb" "$RES_TYPE" '资源类型下拉框'

    # step 6: 选择上传文件
    # 【机制·2026-09-07 定位】agent-browser 0.34.0 的 CDP 文件注入（DOM.setFileInputFiles）
    # 产生的 File 对象 blob 数据不可读（元数据在、底层丢失）——页面 JSZip 经
    # FileReader.readAsArrayBuffer 读取必报 NotReadableError（实测：注入后同一
    # File 的 arrayBuffer()/FileReader 双通道均 FAIL）。手动上传走文件选择器
    # 无此问题。故改为 JS 层直接构造 File：
    #   zip 内容分块 base64 传入 window.__chunks → atob 解码 → new File →
    #   DataTransfer 赋值 input.files → 派发 change（React 正常捕获，此前
    #   小数据实验已验证该路径页面能真实读到内容）
    echo "[step 6] 选择上传文件: $fname"
    # 6.1 文件内容分块注入浏览器（每块 16KB base64，约 4 块）
    agent-browser eval 'window.__chunks=[];"INIT"' >/dev/null 2>&1
    b64=$(base64 -i "$UPLOAD_FILE" | tr -d '\n')
    total=${#b64}
    step=16000
    for ((off = 0; off < total; off += step)); do
        chunk="${b64:off:step}"
        agent-browser eval "window.__chunks.push(\"${chunk}\")" >/dev/null 2>&1
    done
    echo "  [传输] 文件内容已分块传入浏览器（${total} base64 字符）"
    # 6.2 组装 + 构造 File + DataTransfer 注入 + change（IIFE 内联完成）
    inject_res=$(agent-browser eval "(async()=>{const b64=window.__chunks.join(\"\");window.__chunks=null;const bytes=Uint8Array.from(atob(b64),c=>c.charCodeAt(0));const f=new File([bytes],\"${fname}\",{type:\"application/zip\"});const dt=new DataTransfer();dt.items.add(f);const inp=document.querySelector(\"[role=dialog] input[type=file]\");if(!inp)return \"NO_INPUT\";inp.files=dt.files;inp.dispatchEvent(new Event(\"change\",{bubbles:true}));try{const b=await f.arrayBuffer();return \"INJECTED:\"+b.byteLength}catch(e){return \"INJ_FAIL:\"+e.name}})()" 2>/dev/null)
    case "$inject_res" in
        *INJECTED:*) echo "  [注入成功] ${inject_res}（JS 构造 File 路径）";;
        *)
            echo "  [失败] JS 构造 File 注入失败（${inject_res:-无输出}）" >&2
            upload_result="read-failed";;
    esac

    # step 7: 轮询上传校验结果，三态判定
    echo "[step 7] 轮询上传校验结果（上传成功/上传覆盖/版本低 三态适配）"
    dlg_txt=""
    for ((i = 0; i < 15; i++)); do
        dlg_txt=$(agent-browser eval 'Array.from(document.querySelectorAll("[role=dialog],dialog,[role=modal]")).map(d=>d.innerText).join("\n")' 2>/dev/null)
        # C 版本低：中止轮询走取消分支
        case "$dlg_txt" in
            *'版本号必须大于或等于已有版本'*) upload_result="version-low"; break;;
        esac
        # 读错误：本轮注入失败，跳出内层（外层关弹窗完全重置后重试）
        case "$dlg_txt" in
            *'could not be read'*) upload_result="read-failed"; break;;
        esac
        # B 覆盖流程的中途确认弹窗（出现才点击，soft 兜底防误点）：
        #   版本覆盖[确认覆盖] / ZIP 目录结构校验[是]
        case "$dlg_txt" in
            *'确认覆盖'*) click_by_exact '确认覆盖' '版本覆盖确认弹窗' 1 soft || true;;
        esac
        snap=$(snap_i)
        if printf '%s\n' "$snap" | grep -E -- '- (button|menuitem) "是"' >/dev/null; then
            click_by_exact '是' '上传确认弹窗' 1 soft || true
        fi
        # A/B 表单展开判定：资源名称输入框出现（与 ref_by_label 同口径）
        if printf '%s\n' "$snap" | grep -E -- '- (textbox|combobox|spinbutton) "[^"]*请输入资源名称' >/dev/null; then
            upload_result="form-expanded"; break
        fi
        ab_wait 1500
    done

    # 读错误且未到重试上限 → 关闭弹窗完全重置，进入下一轮
    if [ "$upload_result" = "read-failed" ] && [ "$attempt" -lt 3 ]; then
        echo "  [自愈] 文件读取失败（NotReadableError），关闭弹窗完全重置后重试"
        ab_click_last_exact '取消' '上传弹窗取消按钮'
        ab_wait 1000
        continue
    fi
    break
done

# ---------- 三态分支处理 ----------
case "$upload_result" in
    version-low)
        # C 版本低：按约定取消上传，用例视为通过（资源已在列表中且版本更高）
        echo "  [适配] 平台已有更高版本资源（版本低），取消本次上传，用例视为通过"
        ab_click_last_exact '取消' '上传弹窗取消按钮'
        ab_wait 1000
        if dialog_open; then
            echo "  [失败] 取消后上传弹窗未关闭" >&2
            exit 1
        fi
        echo "  [断言通过] 资源已存在且平台版本更高（版本低场景，忽略上传）"
        finish;;
    form-expanded)
        :;;  # A/B：继续 step 9 起的表单填写与提交
    *)
        if [ "$upload_result" = "read-failed" ]; then
            echo "  [失败] 文件读取持续失败（NotReadableError，完全重置重试 3 轮均败；同文件手动上传正常，疑 agent-browser 注入 File 兼容性问题）" >&2
        else
            echo "  [失败] 上传后表单未展开且未检出版本低报错（状态: ${upload_result:-轮询超时}）" >&2
        fi
        exit 1;;
esac

# step 9: 填写资源名称与资源描述（资源描述必填：为空时点击 [上传] 会被表单校验
#         静默拦截——按钮不置灰、无提示、无请求，极易误判为点击失效）
echo "[step 9] 填写资源名称/资源描述"
fill_by_label '请输入资源名称' "${RES_NAME:-$fname}"
fill_by_label '请输入资源描述' "${RES_DESC:-ASDM 场景智能体示例资源}"
ab_wait 500

# step 10: 选择分类（必填，系统内置选项，如"上下文管理 (系统内置)"）
# 注意：分类下拉框在选中资源类型后才出现（条件字段），且无可访问标签——
#       按其当前值 = 占位符"请选择分类"定位。
#       不可"弹窗区段取最后一个 combobox"——会命中快照中排在弹窗之后的
#       DigiWorker 面板下拉（"无可用实例"）：agent-browser select 对无关
#       下拉不报错，分类静默未选 → [上传] 被表单校验拦截（无提示、无请求）。
#       故按占位符匹配定位（兜底取弹窗区段第 2 个 combobox = 资源类型之后
#       的分类框），并在 select 后校验生效值。
echo "[step 10] 选择分类: $RES_CATEGORY"
cat_cb=$(snap_i | grep -E -- ': 请选择分类' | grep -oE 'e[0-9]+' | head -1)
[ -n "$cat_cb" ] || cat_cb=$(snap_i | sed -n '/上传资源 全局/,$p' \
    | grep -E -- '- combobox' | grep -oE 'e[0-9]+' | sed -n 2p)
[ -n "$cat_cb" ] || { echo "  [失败] 未找到分类下拉框" >&2; exit 1; }
cat_opt=$(snap_i | grep -oE -- "\"[^\"]*${RES_CATEGORY}[^\"]*\"" | head -1 | tr -d '"')
[ -n "$cat_opt" ] || { echo "  [失败] 未找到分类选项: $RES_CATEGORY" >&2; exit 1; }
select_by_native "$cat_cb" "$cat_opt" '分类下拉框'
cat_val=$(snap_i | grep -E -- "\[[^]]*ref=${cat_cb}\]" | sed -E 's/.*: //' | head -1)
case "$cat_val" in
    ''|*请选择分类*)
        echo "  [失败] 分类未选中（当前值: ${cat_val:-空}），[上传] 将被表单校验拦截" >&2
        exit 1;;
esac
echo "  [已选] 分类 = $cat_val"

# step 11: 点击 [上传] 按钮（初始禁用，ab_click 自动轮询等待启用）
echo "[step 11] 点击 [上传]"
click_by_exact '上传' '上传按钮'
ab_wait 3000

# ---------- 预期结果断言 ----------

# 预期结果 1: 资源管理列表中增加一条记录 "$fname"
# 【断言定版 2026-09-07 三修】列表默认视图不展示新上传记录（本轮 15:30 实测：
# 重载后裸轮询 12 轮均空 → 假失败，09-01 批次的整页重载方案失效）。按操作
# 记录（Recording 2026_9_7 at 16_03_04.json）须先执行搜索过滤：
#   ① 输入查询资源名称（placeholder "按资源名称或唯一ID搜索..."）
#   ② 资源类型下拉 = 场景智能体（原生 select，选项值 toolset）
#   ③ 状态下拉 = 正常（原生 select，选项值 Active）
#   ④ 点击 [搜索] 按钮 → 列表方展示目标行
# 两个下拉为无标签原生 select（快照 ref 定位易歧义）——eval 按选项值集合
# 特征识别并打 data-asdm-f 标签，再走 agent-browser 原生 fill/select/click。
echo "[断言] 资源列表中出现: $RES_DISPLAY_NAME"
# 注意：必须匹配列表行（cell/link），上传弹窗残留文本（textbox 值/registryId
# 预填）会造成假阳性（提交实际未成功但断言误判通过）

# 8.1 等待上传弹窗关闭（提交成功的标志）；超时打印弹窗文本摘要辅助定位
dlg_open=1
for ((i = 0; i < 15; i++)); do
    dialog_open || { dlg_open=0; break; }
    ab_wait 1000
done
if [ "$dlg_open" -eq 1 ]; then
    echo "  [警告] 上传弹窗 15s 未关闭（疑似提交被拦截/失败），弹窗文本摘要："
    agent-browser eval 'Array.from(document.querySelectorAll("[role=dialog],dialog,[role=modal]")).map(d=>d.innerText).join(" ").slice(0,300)' 2>/dev/null
fi

# 8.2 整页重载资源管理页（列表不随提交自动刷新），取得干净列表态
#     （同时清除上传 toast，为 8.4 的 innerText 兜底排除假阳性来源）
agent-browser open "${BASE_URL%/}/server/_settings?tab=ResourceManager" >/dev/null
ab_wait 3000

# 8.3 搜索区控件识别打标（页面懒加载，轮询等待；
#     MISS 诊断位序 = 类型下拉/状态下拉/名称输入框/搜索按钮，1=缺失）
tag=""
for ((i = 0; i < 10; i++)); do
    tag=$(agent-browser eval "(()=>{const sels=[...document.querySelectorAll('select')];const t=sels.find(s=>[...s.options].some(o=>o.value==='toolset'));const st=sels.find(s=>[...s.options].some(o=>o.value==='Active'));const q=[...document.querySelectorAll('input')].find(e=>(e.getAttribute('placeholder')||'').includes('按资源名称或唯一ID'));let go=null;if(t)go=[...t.parentElement.children].find(e=>e.tagName==='BUTTON'&&(e.textContent||'').trim()==='搜索');if(!go)go=[...document.querySelectorAll('button')].find(b=>(b.textContent||'').trim()==='搜索');if(!t||!st||!q||!go)return 'MISS:'+[!!t,!!st,!!q,!!go].map(Number).join('');t.setAttribute('data-asdm-f','type');st.setAttribute('data-asdm-f','status');q.setAttribute('data-asdm-f','q');go.setAttribute('data-asdm-f','go');return 'TAGOK'})()" 2>/dev/null)
    case "$tag" in *TAGOK*) break;; esac
    ab_wait 1000
done
case "$tag" in
    *TAGOK*) :;;
    *) echo "  [失败] 资源列表搜索区控件未就绪（${tag:-无输出}）" >&2; exit 1;;
esac

# 8.4 搜索并校验：填名称 + 类型 + 状态 → [搜索] → 轮询匹配列表行
#     列表行可能不进交互快照（generic 汇总行，013 同款教训）——快照 cell/link
#     未命中时以 DOM innerText 兜底（此时已整页重载，无上传 toast 残留，
#     body.innerText 命中资源名即来自列表行）
search_and_check() {  # $1=搜索词；列表命中返回 0
    local q="$1" i snap txt
    agent-browser fill "input[data-asdm-f=q]" "$q" >/dev/null 2>&1
    agent-browser select "select[data-asdm-f=type]" "toolset" >/dev/null 2>&1 \
        || agent-browser select "select[data-asdm-f=type]" "场景智能体" >/dev/null 2>&1 || true
    agent-browser select "select[data-asdm-f=status]" "Active" >/dev/null 2>&1 \
        || agent-browser select "select[data-asdm-f=status]" "正常" >/dev/null 2>&1 || true
    ab_wait 500
    agent-browser click "button[data-asdm-f=go]" >/dev/null 2>&1 \
        || agent-browser eval "document.querySelector('button[data-asdm-f=go]')?.click()" >/dev/null 2>&1
    for ((i = 0; i < 8; i++)); do
        snap=$(snap_i)
        case "$snap" in
            *"cell \"${q}"*|*"- link \"${q}\""*) return 0;;
        esac
        txt=$(agent-browser eval 'document.body.innerText' 2>/dev/null)
        case "$txt" in
            *"${q}"*) return 0;;
        esac
        ab_wait 1000
    done
    return 1
}
shown=1
search_and_check "$RES_DISPLAY_NAME" && shown=0
# 全名未命中 → 退化为基名搜索（版本低场景既有资源名无 .zip 后缀，与
# 013/016 版本低适配口径一致）
if [ "$shown" -eq 1 ] && [ "${RES_DISPLAY_NAME%.zip}" != "$RES_DISPLAY_NAME" ]; then
    echo "  [适配] 全名搜索未命中，退化为基名搜索: ${RES_DISPLAY_NAME%.zip}"
    search_and_check "${RES_DISPLAY_NAME%.zip}" && shown=0
fi
if [ "$shown" -eq 0 ]; then
    echo "  [断言通过] 资源管理列表中出现 $RES_DISPLAY_NAME"
else
    echo "  [断言失败] 资源管理列表中出现 $RES_DISPLAY_NAME" >&2; WARN=$((WARN+1))
fi

# ---------- 收尾（§8.3） ----------
finish
