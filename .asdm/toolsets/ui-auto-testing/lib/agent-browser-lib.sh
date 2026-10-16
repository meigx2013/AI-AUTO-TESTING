#!/bin/bash
# =====================================================================
# agent-browser-lib.sh — agent-browser 回放公共方法库
#
# 【来源】由 replay_recording*.sh 中重复的通用函数原样抽取而来，
#         供各回放脚本 source 复用，避免多份拷贝各自漂移。
# 【用法】source 本文件后即可调用 act / extract_ref。
#
# 【整体原理】
#   回放脚本不使用 agent-browser 的原生交互命令（click/fill 等），
#   而是统一走 `agent-browser eval "<JS>"`：在页面主文档上下文中执行
#   一段自构造的 JS，由 JS 自行完成「进入 iframe → 定位元素 → 派发事件」
#   全流程。这样做的原因：
#     1. agent-browser 的元素定位命令难以直接表达多层嵌套 iframe；
#     2. Chrome DevTools Recorder 导出的 frame 路径（iframe 索引数组）
#        可直接翻译为 JS 逐级取 contentDocument，一一对应；
#     3. JS 内可自由实现兜底策略（BFS 反查 + 唯一性校验）。
#
# 【约定（可被调用方预先用环境变量覆盖）】
#   * ACT_RETRY —— 每步未命中时的最大尝试次数（默认 5，含首次）
#   * WARN      —— 累计跳过/失败步数的全局计数（默认 0）
#   * HEADED    —— 1 打开可见浏览器窗口（默认），0 无头
#   * 依赖外部命令 agent-browser（须已在 PATH 中）
# =====================================================================

# ---- 默认初始化（source 时生效）----
# ${VAR:-默认值}：仅当 VAR 未设置或为空时才取默认值，
# 从而允许调用方在 source 之前用环境变量覆盖，如：
#   ACT_RETRY=10 HEADED=0 bash replay_recording.sh
ACT_RETRY="${ACT_RETRY:-5}"
WARN="${WARN:-0}"
# 调试期默认打开可见浏览器窗口，便于人工观察每步操作；
# 无头模式（HEADED=0）适合 CI 无人值守运行。
if [ "${HEADED:-1}" = "1" ]; then
    export AGENT_BROWSER_HEADED=1   # 打开可见的浏览器窗口
fi

# ---- act <frame路径> <选择器> <动作> [值] ----
# 回放一个「用户操作步骤」。
#   参数：
#     $1 frame路径 —— iframe 索引数组字面量，如 "[0]"、"[0,0]"，
#                     含义：从主文档起，第 0 个 iframe 内的第 0 个 iframe
#     $2 选择器    —— CSS（"#id"、".cls > span"）或 "xpath/" 前缀的 XPath
#     $3 动作      —— fill（输入框/滑块赋值）| select（下拉选择）
#                    | click | dblclick
#     $4 值        —— fill/select 时的目标值（可省略）
#
#   【定位策略（两级）】
#     一级：按录制时的 frame 索引路径逐级下钻 contentDocument
#           （仅同源 frame 可访问，跨域时 contentDocument 为 null → NOFRAME）。
#     二级：一级未命中时 BFS 遍历页面所有同源 frame 按选择器反查兜底；
#           要求全局唯一命中，多处命中返回 AMBIG 拒绝执行——
#           宁可跳过也不错点，防止页面结构变化后静默操作到错误元素。
#
#   【返回约定】JS 返回 'OK' | 'NOFRAME' | 'NOEL' | 'AMBIG'，
#           shell 层据此分类记日志、累加 WARN、决定是否重试。
act() {
    local path="$1" sel="$2" action="$3" val="${4:-}"

    # ---- 生成待执行的 JS（heredoc 一次成型）----
    # 原理：把 shell 变量以字面量内插进 JS 源码，整段交给
    # `agent-browser eval` 在浏览器主文档执行。
    # 注意：sel/action/val 内插在 JS 单引号字符串中，值中不能含单引号
    # （录制生成的选择器/值均满足此约束）。
    # 返回 'OK' | 'NOFRAME' | 'NOEL' 供下方分支判断。
    local js
    js=$(cat <<EOF
(function () {
    // ===== 1. 按索引路径逐级进入嵌套 iframe =====
    // 原理：d.querySelectorAll('iframe')[i].contentDocument 即
    // 「当前层第 i 个 iframe 的文档对象」，路径 [0,0] 连续下钻两次。
    // 仅同源页面拿得到 contentDocument；跨域或未加载完成为 null。
    var d = document;
    var path = ${path};
    for (var i = 0; i < path.length; i++) {
        var f = d.querySelectorAll('iframe')[path[i]];
        if (!f || !f.contentDocument) return 'NOFRAME';
        d = f.contentDocument;
    }

    // ===== 2. 在指定文档中定位目标元素（支持 CSS 与 xpath/ 前缀）=====
    // 统一封装：'xpath/' 前缀走 doc.evaluate（FIRST_ORDERED_NODE_TYPE
    // 只取首个匹配节点），否则按 CSS 用 querySelector。
    function find(doc) {
        var sel = '${sel}';
        if (sel.indexOf('xpath/') === 0) {
            var r = doc.evaluate(sel.slice(6), doc, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null);
            return r.singleNodeValue;
        }
        return doc.querySelector(sel);
    }
    var el = find(d);

    // ===== 2b. 索引路径未命中 → BFS 遍历所有同源 frame 反查兜底 =====
    // 原理：以主文档为起点广度优先，把每个可达的同源 frame 文档依次
    // 入队，逐个用同一选择器查找，统计总命中数 matches：
    //   0 命中  → 落到下方 NOEL（shell 层还会按时序重试）
    //   1 命中  → 兜底成功，等价于自动纠正了过期的 frame 索引
    //  >1 命中  → AMBIG，选择器有歧义，拒绝猜测（防静默错位）
    if (!el) {
        var queue = [document], matches = 0;
        while (queue.length) {
            var cur = queue.shift();
            var hit = find(cur);
            if (hit) { matches++; el = el || hit; }
            // 收集当前文档下所有 iframe 的文档对象，继续探索下一层。
            // try/catch + contentDocument 判空：跨域 frame 抛异常或为
            // null，直接跳过（本方案只支持同源页面）。
            var frames = cur.querySelectorAll('iframe');
            for (var j = 0; j < frames.length; j++) {
                try { if (frames[j].contentDocument) queue.push(frames[j].contentDocument); } catch (e) {}
            }
        }
        if (matches > 1) return 'AMBIG';
    }
    if (!el) return 'NOEL';

    // ===== 3. 对命中的元素执行动作 =====
    // 关键原理：不能只赋值，还要派发事件——
    //   input  事件：通知页面（oninput 等）值已发生变化；
    //   change 事件：模拟「失焦提交」，让监听 change 的逻辑
    //               （下拉选择、表单校验）同样被触发；
    //   bubbles:true：事件冒泡，使挂在祖先节点上的事件委托也能收到。
    switch ('${action}') {
        case 'fill':
        case 'select':
            el.value = '${val}';
            el.dispatchEvent(new Event('input',  { bubbles: true }));
            el.dispatchEvent(new Event('change', { bubbles: true }));
            break;
        case 'click':
            // el.click() 为合成点击，等效完整鼠标按下-抬起-点击语义
            el.click();
            break;
        case 'dblclick':
            // 手动派发 dblclick：el.click() 不会产生双击语义
            el.dispatchEvent(new MouseEvent('dblclick', { bubbles: true }));
            break;
    }
    return 'OK';
})()
EOF
)

    # ---- 执行 + 未命中重试（应对 iframe 懒加载时序）----
    # 为什么重试：iframe/控件常为异步懒加载，录制时刻存在的元素在
    # 回放时刻可能尚未渲染完成。仅对 NOEL/NOFRAME 这类「时序性失败」
    # 重试；AMBIG 是确定性歧义、OK 是成功，重试无意义直接跳出。
    # 每轮间隔 0.5s，最多 ${ACT_RETRY} 轮（含首次）。
    local out i
    for ((i = 0; i < ACT_RETRY; i++)); do
        out=$(agent-browser eval "$js" 2>&1)
        case "$out" in
            *NOEL*|*NOFRAME*) [ $((i + 1)) -lt "$ACT_RETRY" ] && sleep 0.5;;
            *) break;;
        esac
    done
    # ---- 结果分类：只记日志/计数，不中断整体回放 ----
    # 设计取舍：单步失败（如页面未渲染某控件）不应让整条回放中断，
    # 因此统一累加全局计数 WARN，由调用方在结束时汇总报告跳过/失败数。
    # 日志走 stderr，不污染 stdout 的正常输出流。
    case "$out" in
        *NOEL*)    echo "  [跳过] 元素不存在: ${path} ${sel} (${action})" >&2; WARN=$((WARN+1));;
        *NOFRAME*) echo "  [跳过] frame 不存在: ${path}" >&2; WARN=$((WARN+1));;
        *AMBIG*)   echo "  [跳过] 选择器跨 frame 不唯一，拒绝猜测: ${path} ${sel} (${action})" >&2; WARN=$((WARN+1));;
        *OK*)      ;;
        *)         echo "  [失败] ${path} ${sel} (${action}): ${out}" >&2; WARN=$((WARN+1));;
    esac
}

# ---- extract_ref <快照文本> <匹配模式> ----
# 从（frame 作用域）快照中提取指定元素的 ref
#   $1 = snapshot 文本，$2 = 匹配模式（grep 风格）
# 【用途】agent-browser 的页面快照会给每个可交互元素编号（e12、e35…），
#         拿到 ref 后即可用 `agent-browser click e12` 等命令精确操作，
#         省去手工编写选择器。
# 【原理】三级管道逐级收敛：
#   grep -m1 -- "$2"     取第一条匹配行（同组元素取首个）；
#   grep -oE 'e[0-9]+'   从该行抠出 ref 记号（每命中一个输出一行）；
#   head -1              同行出现多个 ref 时只取第一个。
extract_ref() {
    printf '%s\n' "$1" | grep -m1 -- "$2" | grep -oE 'e[0-9]+' | head -1
}
