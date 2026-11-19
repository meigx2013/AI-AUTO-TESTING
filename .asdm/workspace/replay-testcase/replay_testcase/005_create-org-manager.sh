#!/bin/bash
# 由 005_create-org-manager.md 翻译而来（测试用例 markdown → agent-browser）
#
# 通用操作已抽取至 common.sh（快照 ref 驱动），本脚本仅保留用例业务步骤：
#   管理后台 → 平台级设置 → 用户 Tab → 创建组织管理员用户（角色映射 + 组织绑定）
#
# 前置条件（不自动级联，缺失即报错）：
#   1. 用户已完成系统登录——登录类前置由 goto_admin_console 内置的幂等
#      login 自动处理（未登录自动登录、身份不符自动退出换号重新登录），
#      凭据经 test-data.sh 的 ASDM_USER/ASDM_PASS 提供，缺失由 require_vars
#      前置报错，可独立执行。
#   2. 已创建组织 "测试组织01"——批次决断：用例原文组织按批次对齐为
#      004 产物 NEW_USER_ORG=T001_组织02（=SUB_ORG_NAME），先执行
#      replay_testcase/003_create-org.sh 与 replay_testcase/004_create-sub-org.sh
#      （决断已记入 test-data.sh NEW_USER_ORG 行注释与登记表备注）。
#   3. 幂等性：创建类用例不幂等——同批次重跑按**序号顺延自愈**（规则修订
#      2026-11-19，generate-test-data.md §2.3-7）：批次实例在平台已存在时
#      邮箱序号 +1 顺延（T001_USER01@asdm.ai → T001_USER02@asdm.ai → …）
#      直至空闲序号，不终止、不换批次号；顺延仅作用于执行期创建值
#      （批内追加实例，不落盘、不回写静态快照——赋值规则为纯静态求值，
#      不依赖任何运行期落盘产物），test-data.sh 静态快照不变。
#
# 运行（工作目录 = replay-testcase/）：bash replay_testcase/005_create-org-manager.sh（默认显示浏览器窗口）
# 如需无头模式：HEADED=0 bash replay_testcase/005_create-org-manager.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"      # = .../replay-testcase/replay_testcase
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/../common/common.sh"            # 公共库在同级 common/ 目录

# 统一测试数据：data/test-data.sh（含全部用例数据，环境变量优先）
DATA_DIR="${SCRIPT_DIR}/../data"                 # 数据在同级 data/ 目录
load_data_file "${DATA_DIR}/test-data.sh"

BASE_URL="${BASE_URL:-https://asdm-dt01.leansoftx.com/}"

ab_init
require_vars ASDM_USER ASDM_PASS NEW_USER_EMAIL NEW_USER_PASS \
             NEW_USER_LAST NEW_USER_FIRST NEW_USER_ROLE NEW_USER_ORG

# ---------- 操作步骤 ----------

# step 1(原步骤 1): 用户进入 ASDM管理后台 首页
#   决断：goto_admin_console 完整链路（login 幂等自愈 → Portal → 控制台管理），
#   落点 /projects 校验为硬断言（未进入后台即 exit 1）。
goto_admin_console

# step 2~3(原步骤 2、3): 点击左下角 [平台级设置]，右侧工作区打开平台级设置页面
#   决断：两步合并为 goto_platform_settings（点击 + /server/_settings 落点硬校验）。
echo "[step 2~3] 进入 [平台级设置]"
goto_platform_settings

# step 4(原步骤 4): 点击 [用户] Tab页签
echo "[step 4] 点击 [用户] Tab页签"
click_tab '用户'

# step 4.5(规则修订 2026-11-19): 同批次重名序号顺延（generate-test-data.md §2.3-7）
#   NEW_USER_EMAIL 批次实例在平台已存在时序号 +1 顺延（USER01→USER02→…）
#   直至空闲序号；list_has_record 以 cell 精确匹配判定，防同前缀记录
#   （如已注销的验证遗留）干扰。顺延后：
#     - 顺延仅改变执行期创建值（批内追加实例），不落盘、不回写
#       test-data.sh 静态快照与 ref 链（NEW_USER_EMAIL=TEST01_USER
#       字面一致仅在未顺延时成立，§2.3-7 对齐口径）
#     - USER 类当前仅序号 01 占号（登记表 §1.1），顺延方向（02→）无占号冲突
email="$NEW_USER_EMAIL"
for i in 1 2 3 4 5 6 7 8 9 10; do
    list_has_record "$email" || break
    echo "  [顺延] $email 已在平台存在，序号 +1"
    email=$(bump_batch_seq "$email") \
        || { echo "  [失败] 邮箱非批次实例格式，无法顺延: $email" >&2; exit 1; }
done
if [ "$email" != "$NEW_USER_EMAIL" ]; then
    echo "  [顺延生效] 实际创建邮箱: $email（原: $NEW_USER_EMAIL）"
    NEW_USER_EMAIL="$email"
fi
clear_search_box   # 清顺延检查残留的关键词，防污染后续定位

# step 5(原步骤 5): 点击 [+创建用户] 按钮，打开 [新建用户] 窗口
#   决断：入口按钮实际文本 "+创建用户" 的 + 与文本间距不可考（快照文本
#   可能渲染为 "+ 创建用户"），click_by_text '创建用户' 子串匹配两者皆命中；
#   弹窗未开时页面唯一含该词的可点元素即入口（列表为空时页面可能另有
#   精确文本"创建用户"的空状态引导按钮，点击同样打开创建弹窗，殊途同归）。
#   弹窗打开后由 wait_for_dialog 检测 dialog 元素真实打开（硬断言，流程
#   关键节点；022/023 实测教训：入口与标题同文本时 assert_visible 会误
#   命中按钮文本造成假阳性）。
echo "[step 5] 点击 [创建用户] 入口，等待 [新建用户] 弹窗"
click_by_text '创建用户' '+创建用户入口按钮'
wait_for_dialog 10 1000 \
    || { echo "  [失败] [新建用户] 弹窗未出现" >&2; exit 1; }
echo "  [断言通过] [新建用户] 弹窗已打开（dialog 元素检测）"

# step 6(原步骤 6): [新建用户] 信息录入 —— 邮箱/初始密码/姓/名
#   决断：用例原文值 test01@asdm.ai / admin@2026 以批次对齐实例取代
#   （NEW_USER_EMAIL=TEST01_USER=T001_USER01@asdm.ai，010/011 登录复用；
#    密码/姓/名为固定值原样，§5.2 同批次字面对齐）。
echo "[step 6] 录入新用户信息: $NEW_USER_EMAIL"
fill_by_label '新用户邮箱' "$NEW_USER_EMAIL" '新用户邮箱输入框'
fill_by_label '初始密码' "$NEW_USER_PASS" '初始密码输入框'
fill_by_label '姓' "$NEW_USER_LAST" '姓输入框'
fill_by_label '名' "$NEW_USER_FIRST" '名输入框'

# step 7(原步骤 7): 点击 [新增角色映射] —— 第一个下拉框选择 [组织管理员]，
#                   第二个下拉框选择 [测试组织01]（批次对齐 T001_组织02）
#   顺序决断：先角色后组织——角色映射中角色变更会清空已绑定的组织
#   （平台实际行为，实测沉淀），先组织后角色会被清空导致提交缺组织。
echo "[step 7] 新增角色映射: 角色=$NEW_USER_ROLE 组织=$NEW_USER_ORG"
click_by_text '新增角色映射' '新增角色映射按钮'
ab_wait 800

# 7a 第一个下拉框（角色）—— 原生 select 键盘交互
#   决断：角色下拉为原生 select（快照角色 combobox）；agent-browser select
#   命令（Playwright selectOption）派发的 change 不进 React 受控表单
#   state、被后续重渲染回滚（005 实测，平台特性清单外新增）——改
#   select_by_keyboard 键盘交互（方向键改值触发 input+change 双事件）。
#   区段截取以 "新增角色映射" 引号定界：弹窗容器渲染为 generic 元素、
#   其可见文本为整块无分隔拼接，纯文本地址会误命中导致截取起点前移、
#   误取区段外控件（实测曾误取"账户状态"下拉）。
role_ref=$(refs_of_role_after '新增角色映射' 'combobox' | head -1)
[ -n "$role_ref" ] \
    || { echo "  [失败] 角色映射区段未找到角色下拉框" >&2; exit 1; }
select_by_keyboard "$role_ref" "$NEW_USER_ROLE" '角色映射-角色' \
    || { echo "  [失败] 角色选择未生效: $NEW_USER_ROLE" >&2; exit 1; }

# 7b 第二个下拉框（组织）—— 实为按钮 + 浮层搜索树
#   决断：步骤写"第二个下拉框选择"，实际控件角色为 button（初始文本
#   "未绑定组织"，点击展开浮层搜索树，非 combobox——§4.4 角色核对陷阱）；
#   浮层选项 @ref 点击报 CDP box model 错误（平台特性 5）——经
#   select_option_by_ref 内置 click_overlay_node JS 精确匹配兜底
#   （含树折叠懒加载的展开重试）。
org_btn=$(ref_by_text '未绑定组织')
[ -n "$org_btn" ] \
    || { echo "  [失败] 未找到组织选择控件（未绑定组织按钮）" >&2; exit 1; }
select_option_by_ref "$org_btn" "$NEW_USER_ORG" '角色映射-组织' \
    || { echo "  [失败] 组织选择未生效: $NEW_USER_ORG" >&2; exit 1; }

#   组织绑定生效校验（软断言）："未绑定组织"占位文本应消失
ab_wait 500
if ref_by_text '未绑定组织' >/dev/null; then
    echo "  [告警] 组织占位文本仍在，绑定可能未生效（以创建结果断言为准）" >&2
    WARN=$((WARN+1))
fi

# step 8(原步骤 8): 点击 [创建用户] 按钮
#   决断：提交按钮与入口按钮同词根（入口 "+创建用户"/引导 "创建用户"），
#   用 ab_click_last_exact 取 DOM 末位精确匹配（弹窗提交按钮恒靠后，
#   与 010 "创建项目" 同源歧义场景）。提交静默拦截显性化（平台特性 2/12）：
#   创建后弹窗应关闭；仍打开时可能是必填静默拦截或弹窗不自动关，两种情形
#   均以 reload 后列表断言判定真实结果（软断言，不在此硬断言误杀）。
echo "[step 8] 点击 [创建用户] 提交"
ab_click_last_exact '创建用户' '创建用户提交按钮'
ab_wait 2000

# step 9(原步骤 9): 用户列表中增加一条组织管理员用户记录
#   决断：按 §4.1 "列表增加一条记录" 不翻译为动作，并入预期结果断言（§七）。

# ---------- 预期结果断言 ----------

# 预期结果 1(原 1): [测试组织01]中新增1条组织管理员用户记录
#   决断：断言锚点用批次对齐邮箱 NEW_USER_EMAIL（列表行唯一特征）；
#   平台级用户列表不按组织过滤，组织归属经上方绑定校验软断言 +
#   角色映射步骤成功间接保证。列表刷新时序不可靠（平台特性 12）——
#   reload 兜底重开页面 + 搜索过滤（防同名多条假命中，§7.1）+ 轮询断言
#   （软断言，失败 WARN 由 finish 汇总）。
echo "[断言] 用户列表出现记录: $NEW_USER_EMAIL"
agent-browser reload >/dev/null 2>&1
ab_wait 2000
if search_and_filter "$NEW_USER_EMAIL"; then
    if wait_for_text "$NEW_USER_EMAIL" 10 1; then
        assert_snapshot_contains "$NEW_USER_EMAIL" "用户列表中出现 $NEW_USER_EMAIL"
    else
        echo "  [断言失败] 列表未出现用户记录（创建提交可能被静默拦截，检查必填/邮箱重名）" >&2
        WARN=$((WARN+1))
    fi
else
    echo "  [断言失败] 列表搜索过滤未完成" >&2
    WARN=$((WARN+1))
fi
clear_search_box

# ---------- 收尾 ----------
finish
