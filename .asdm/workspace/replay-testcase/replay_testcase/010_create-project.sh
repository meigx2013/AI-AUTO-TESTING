#!/bin/bash
# 由 010_create-project.md 翻译而来（测试用例 markdown → agent-browser）
#
# 通用操作已抽取至 common.sh（快照 ref 驱动），本脚本仅保留用例业务步骤：
#   test01 登录 → 管理后台 → 组织与项目 → 组织节点 → 新建项目
#
# 前置条件（不自动级联，缺失即报错）：
#   1. 已创建组织 "$ORG_NODE"（先执行 replay_testcase/004_create-sub-org.sh）
#   2. 已创建用户 test01@asdm.ai（先执行 replay_testcase/005_create-user.sh）
#
# 运行：bash replay_testcase/010_create-project.sh（默认显示浏览器窗口）
# 如需无头模式：HEADED=0 bash replay_testcase/010_create-project.sh

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
require_vars ASDM_USER ASDM_PASS ORG_NODE PROJECT_NAME
# 平台限制：项目名称最大 20 字符，超出会被输入框静默截断（填入值 ≠ PROJECT_NAME，
# 列表断言必失败）——此处前置校验，避免截断后带病执行
if [ "${#PROJECT_NAME}" -gt 20 ]; then
    echo "  [失败] PROJECT_NAME 超过 20 字符上限（当前 ${#PROJECT_NAME} 字符）: $PROJECT_NAME" >&2
    exit 1
fi

# ---------- 操作步骤 ----------

# step 1: 以 test01 完成系统登录（已存在登录态则跳过）
echo "[step 1] test01 登录"
login

# step 2: 用户进入 ASDM管理后台 首页
goto_admin_console

# step 3: 右侧工作区，点击顶部 [组织与项目] 导航
echo "[step 3] 打开 [组织与项目] 导航"
goto_org_project
assert_visible '组织与项目' '[组织与项目] 导航窗口出现'

# step 4: 组织层级树中，点击组织节点 "$ORG_NODE"
echo "[step 4] 点击组织节点: $ORG_NODE"
click_tree_node "$ORG_NODE" || exit 1

# step 5: 点击项目列表上方的 [+新建项目] 按钮
echo "[step 5] 点击 [+新建项目]"
click_by_text '新建项目' '新建项目按钮'
assert_visible '新建项目' '[新建项目] 弹窗出现'

# step 6: [新建项目] 信息录入 —— 项目名称
echo "[step 6] 录入项目名称: $PROJECT_NAME"
fill_by_any_label "$PROJECT_NAME" '项目名称' '名称'

# step 7: 点击 [创建项目] 按钮
# 注意：页面空列表引导按钮与弹窗提交按钮同文本"创建项目"（DOM 前者靠前），
# click_by_exact 会点到弹窗外引导按钮（提交从未发生），此处必须
# 用 ab_click_last_exact 取最后一个匹配（弹窗提交按钮 DOM 靠后）
echo "[step 7] 点击 [创建项目]"
ab_click_last_exact '创建项目' '创建项目按钮（弹窗内）'
ab_wait 2000
# 幂等重跑：项目已存在时平台拦截提交，弹窗停留并提示"该集合下已存在同名项目"。
# 关闭残留弹窗（创建成功场景弹窗已自行关闭，此检测不触发），保证断言在干净页面上进行
if dialog_open; then
    ab_click '取消' '关闭残留弹窗' 1 soft || true
    ab_wait 800
fi

# ---------- 预期结果断言 ----------

# 预期结果 1: 项目列表中增加一条记录 "$PROJECT_NAME"
# 【前端改版 2026-09-07】组织概览页（/org-*/_overview/summary，即点击组织节点
# 后的落地页）的项目列表项已由 link/cell 改为 button 渲染，两种形态：
#   "子组织与项目"区 button "<项目名> <项目标识> · <组织名>"
#   "可用项目"区   button "<项目名> <组织名> 查看项目 →"
#   文本均以项目名开头、后跟空格（非引号闭合）。断言按快照行首角色匹配
#   button/link/cell 三种形态（link/cell 保留兼容旧视图），要求项目名后
#   紧跟空格或引号 —— 防两类误判：
#   ① 弹窗输入框残留值（textbox 行 "...: <项目名>"）假阳性：textbox 不在
#     角色组内，天然排除（同 005 的 cell 防护）
#   ② 以项目名为前缀的其他更长名称（前缀撞名）假阳性：要求名称后紧跟
#     空格/引号，"NAME2" 之类不命中
# 【ERE 转义教训】模式须写 \"${pat}( | \")（名称后直接跟空格或引号）；
#   写成 \"${pat}\"( | \") 会变成"名称+引号+空格/引号"——button 行名称后
#   是空格+标识（引号在行尾闭合），恒不匹配
echo "[断言] 项目列表中出现: $PROJECT_NAME"
shown=1
pat=$(_ere_escape "$PROJECT_NAME")
for ((i = 0; i < 15; i++)); do
    snap=$(snap_i)
    # 勿改用 grep -q：命中即退出会使上游 printf 遭 EPIPE，pipefail 下退出码
    # 变 141 → 断言恒失败（见 common.sh search_and_filter 的 019 教训注）
    if printf '%s\n' "$snap" | grep -E -- "- (button|link|cell) \"${pat}( |\")" >/dev/null; then
        shown=0; break
    fi
    ab_wait 1000
done
if [ "$shown" -eq 0 ]; then
    echo "  [断言通过] 项目列表中出现 $PROJECT_NAME"
else
    echo "  [断言失败] 项目列表中出现 $PROJECT_NAME" >&2; WARN=$((WARN+1))
fi

# ---------- 收尾（§8.3） ----------
finish
