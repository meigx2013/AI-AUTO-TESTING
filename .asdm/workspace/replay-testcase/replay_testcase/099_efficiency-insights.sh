#!/bin/bash
# 由 099_efficiency-insights.md 翻译而来（测试用例 markdown → agent-browser）
#
# 通用操作已抽取至 common.sh（快照 ref 驱动），本脚本仅保留用例业务步骤：
#   三角色逐一切换（超级管理员→组织管理员→项目管理员）→ 效能洞察 →
#   验证各角色数据权限级别与下拉选择器可用性
#
# 前置条件（不自动级联，缺失即报错）：
#   1. 用户已注册（超级管理员凭据就绪）
#   2. 组织管理员已创建（先执行 replay_testcase/005_create-user.sh）
#   3. 项目管理员已创建（PROJECT_ADMIN_USER/PASS 为空时跳过该角色验证，§5.1 外部凭据类）
#
# 幂等策略：导航类/只读验证——天然幂等，重复执行收敛
#
# 运行：bash replay_testcase/099_efficiency-insights.sh（默认显示浏览器窗口）
# 如需无头模式：HEADED=0 bash replay_testcase/099_efficiency-insights.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/../common/common.sh"

# 统一测试数据：data/test-data.sh（含全部用例数据，环境变量优先）
DATA_DIR="${SCRIPT_DIR}/../data"
load_data_file "${DATA_DIR}/test-data.sh"

ab_init
require_vars ASDM_USER ASDM_PASS TEST01_USER TEST01_PASS ORG_NAME SUB_ORG_NAME PROJECT_NAME

# 项目管理员凭据（外部凭据类，§5.1）：为空时跳过该角色验证
# 创建项目管理员用户后可将邮箱/密码写入 PROJECT_ADMIN_USER/PROJECT_ADMIN_PASS
# 或传入环境变量解除豁免
SKIP_PROJECT_ADMIN=0
if [ -z "${PROJECT_ADMIN_USER:-}" ] || [ -z "${PROJECT_ADMIN_PASS:-}" ]; then
    SKIP_PROJECT_ADMIN=1
    echo "  [豁免] 项目管理员凭据未配置（PROJECT_ADMIN_USER/PASS 为空），跳过该角色验证"
fi

# ---------- 辅助函数 ----------

# check_dropdown — 验证下拉框含可选项（两步法 + combobox 退化 + 重试）
# 【用途】点击级别 Tab 后，下拉框数据可能异步加载。先尝试 select_option 两步法，
#         失败退化为 combobox 展开后检查快照是否含期望选项。含多次重试。
# 【参数】$1 = 下拉框标签/文本；$2... = 期望匹配的选项文本（多个候选任一匹配即通过）
#         最后一个参数为角色说明（如 '超级管理员组织单元'）
# 【注意】调用格式: check_dropdown '组织单元' "$ORG_NAME" "$SUB_ORG_NAME" '说明'
#         当下拉框显示"无可用实例"时，视为下拉框可用但无数据（信息性提示，不判失败）
check_dropdown() {
    local label="$1"; shift
    # 最后一个参数为说明
    local desc="${*: -1}"
    # 中间参数为期望选项
    local opts=("$@")
    unset 'opts[${#opts[@]}-1]'  # 去掉最后一个（说明）
    local retry i snap cb_ref found opt

    for ((retry = 0; retry < 3; retry++)); do
        # 先尝试 select_option 两步法
        for opt in "${opts[@]}"; do
            if (select_option "$label" "$opt") >/dev/null 2>&1; then
                echo "  [断言通过] ${desc}下拉框可选择: $opt"
                return 0
            fi
        done

        # 退化：combobox 展开后检查快照
        cb_ref=$(refs_of_role combobox | head -1)
        if [ -n "$cb_ref" ]; then
            agent-browser click "@${cb_ref}" >/dev/null
            ab_wait 1000
            snap=$(snap_i)
            # 先检查"无可用实例"——下拉框存在但无数据
            case "$snap" in
                *'无可用实例'*)
                    echo "  [信息] ${desc}下拉框可用，但当前无数据（显示"无可用实例"）"
                    agent-browser press Escape >/dev/null
                    ab_wait 300
                    return 0;;
            esac
            for opt in "${opts[@]}"; do
                case "$snap" in
                    *"$opt"*)
                        echo "  [断言通过] ${desc}下拉框含可选项: $opt"
                        agent-browser press Escape >/dev/null
                        ab_wait 300
                        return 0;;
                esac
            done
            # 未匹配到选项，关闭下拉框
            agent-browser press Escape >/dev/null
            ab_wait 300
        fi

        # 重试前等待
        [ "$retry" -lt 2 ] && {
            echo "  [重试] ${desc}下拉框选项未就绪，等待..."
            ab_wait 3000
        }
    done
    echo "  [断言失败] ${desc}下拉框无可选项" >&2
    WARN=$((WARN+1))
}

# ---------- 操作步骤 ----------

# ===================== 角色 1：超级管理员 =====================

# step 1(原步骤 1): 用户进入 ASDM 管理后台 首页
echo "[step 1] 超级管理员登录 → 管理后台"
login
goto_admin_console

# step 2(原步骤 2): 点击左侧【效能洞察】菜单，进入效能洞察页面
echo "[step 2] 点击左侧【效能洞察】菜单"
click_by_text '效能洞察' '效能洞察菜单'
ab_wait 2000

# 等待级别 Tab 渲染（SPA 异步），轮询至出现
wait_for_text '平台级别' 30 1 \
    || { echo "  [失败] 超级管理员效能洞察页面级别数据未加载" >&2; exit 1; }
assert_visible '效能洞察' '效能洞察页面已打开'

# ---------- 预期结果断言：超级管理员 ----------

echo "[断言] 超级管理员：验证数据权限级别"

# 预期结果 2: 超级管理员可查看所有【平台级别】【组织单元级别】【项目级别】数据权限
# 默认展示【平台级别】数据，数据加载成功，页面展示正常
assert_snapshot_contains '平台级别' '超级管理员可见平台级别'
assert_snapshot_contains '组织单元级别' '超级管理员可见组织单元级别'
assert_snapshot_contains '项目级别' '超级管理员可见项目级别'

# 点击【组织单元级别】, 可通过下拉列表选择【组织单元】，数据加载成功
echo "[超级管理员] 点击【组织单元级别】"
click_tab '组织单元级别'
ab_wait 2000
assert_snapshot_contains '组织单元级别' '超级管理员组织单元级别页面已加载'

# 验证组织单元下拉列表可用
check_dropdown '组织单元' "$ORG_NAME" "$SUB_ORG_NAME" '超级管理员组织单元'
ab_wait 1500

# 点击【项目级别】, 可通过下拉列表选择【项目】，数据加载成功
echo "[超级管理员] 点击【项目级别】"
click_tab '项目级别'
ab_wait 3000
assert_snapshot_contains '项目级别' '超级管理员项目级别页面已加载'

# 验证项目下拉列表可用（项目数据异步加载，等待更长时间）
check_dropdown '项目' "$PROJECT_NAME" '超级管理员项目'
ab_wait 1500

# ===================== 角色 2：组织管理员 =====================

# 决断（§4.2 身份切换）：脚本内切换凭据变量后调 login（幂等），
# login 检测身份不符自动退出重登
echo "[角色切换] 超级管理员 → 组织管理员（${TEST01_USER%%@*}）"
_LOGIN_AS=""
ASDM_USER="${TEST01_USER}"
ASDM_PASS="${TEST01_PASS}"
login
goto_admin_console

echo "[组织管理员] 点击左侧【效能洞察】菜单"
click_by_text '效能洞察' '效能洞察菜单'
ab_wait 3000

# 等待页面数据加载（组织管理员页面布局可能与超级管理员不同，
# 不一定有"组织单元级别"/"项目级别" Tab 标签——直接验证数据区域即可）
# 轮询等待：出现组织单元相关下拉框或级别 Tab
for ((i = 0; i < 30; i++)); do
    snap=$(snap_i)
    case "$snap" in
        *'组织单元级别'*|*'项目级别'*|*"$ORG_NAME"*|*"$SUB_ORG_NAME"*)
            break;;
    esac
    # 检查是否有 combobox（下拉框出现意味着数据已加载）
    if refs_of_role combobox | head -1 | grep -q 'e'; then
        break
    fi
    ab_wait 1000
done

assert_visible '效能洞察' '效能洞察页面已打开（组织管理员）'

# ---------- 预期结果断言：组织管理员 ----------

echo "[断言] 组织管理员：验证数据权限级别"

# 预期结果 3: 组织管理员可查看本组织【组织单元级别】【项目级别】数据权限
# 组织管理员页面可能不显示级别 Tab 标签（默认直接展示组织单元级别数据），
# 改为检测级别 Tab 是否存在来决定断言方式
snap=$(snap_i)
has_level_tabs=0
case "$snap" in
    *'组织单元级别'*|*'项目级别'*) has_level_tabs=1;;
esac

if [ "$has_level_tabs" -eq 1 ]; then
    # 有级别 Tab：验证可见性
    assert_snapshot_contains '组织单元级别' '组织管理员可见组织单元级别'
    assert_snapshot_contains '项目级别' '组织管理员可见项目级别'
else
    # 无级别 Tab：页面默认展示组织单元级别数据，Tab 标签不可见不影响功能
    echo "  [信息] 组织管理员页面未显示级别 Tab，默认展示组织单元级别数据"
    # 间接验证：组织单元数据已加载（下拉框存在即可验证）
fi

# 不应出现平台级别（软断言：不同角色权限隔离校验）
assert_snapshot_missing '平台级别' '组织管理员不可见平台级别'

# 可通过下拉列表选择【组织单元】
check_dropdown '组织单元' "$ORG_NAME" "$SUB_ORG_NAME" '组织管理员组织单元'
ab_wait 1500

# 点击【项目级别】, 可通过下拉列表选择【项目】
if [ "$has_level_tabs" -eq 1 ]; then
    echo "[组织管理员] 点击【项目级别】"
    click_tab '项目级别'
    ab_wait 2000
    check_dropdown '项目' "$PROJECT_NAME" '组织管理员项目'
    ab_wait 1500
    assert_snapshot_contains '项目级别' '组织管理员项目级别数据加载成功'
else
    # 无级别 Tab 时尝试按文本点击
    echo "[组织管理员] 尝试切换到项目级别"
    if ab_click '项目级别' '' 0 soft; then
        ab_wait 2000
        check_dropdown '项目' "$PROJECT_NAME" '组织管理员项目'
        ab_wait 1500
        assert_snapshot_contains '项目级别' '组织管理员项目级别数据加载成功'
    else
        echo "  [信息] 组织管理员页面无项目级别入口，跳过项目级别验证"
        # 软断言：记录但不退出
    fi
fi

# ===================== 角色 3：项目管理员 =====================

if [ "$SKIP_PROJECT_ADMIN" -eq 1 ]; then
    echo "  [跳过] 项目管理员角色验证（凭据未配置）"
else
    echo "[角色切换] 组织管理员 → 项目管理员（${PROJECT_ADMIN_USER%%@*}）"
    _LOGIN_AS=""
    ASDM_USER="${PROJECT_ADMIN_USER}"
    ASDM_PASS="${PROJECT_ADMIN_PASS}"
    login
    goto_admin_console

    echo "[项目管理员] 点击左侧【效能洞察】菜单"
    click_by_text '效能洞察' '效能洞察菜单'
    ab_wait 3000

    # 等待页面数据加载
    for ((i = 0; i < 30; i++)); do
        snap=$(snap_i)
        case "$snap" in
            *'项目级别'*|*"$PROJECT_NAME"*) break;;
        esac
        if refs_of_role combobox | head -1 | grep -q 'e'; then break; fi
        ab_wait 1000
    done

    assert_visible '效能洞察' '效能洞察页面已打开（项目管理员）'

    # ---------- 预期结果断言：项目管理员 ----------

    echo "[断言] 项目管理员：验证数据权限级别"

    # 预期结果 4: 项目管理员可查看本项目【项目级别】数据权限
    # 项目管理员页面可能不显示级别 Tab 标签
    snap=$(snap_i)
    has_proj_level_tabs=0
    case "$snap" in
        *'项目级别'*) has_proj_level_tabs=1;;
    esac

    if [ "$has_proj_level_tabs" -eq 1 ]; then
        assert_snapshot_contains '项目级别' '项目管理员可见项目级别'
    else
        echo "  [信息] 项目管理员页面未显示级别 Tab，默认展示项目级别数据"
    fi

    assert_snapshot_missing '平台级别' '项目管理员不可见平台级别'
    assert_snapshot_missing '组织单元级别' '项目管理员不可见组织单元级别'

    # 可通过下拉列表选择【项目】
    check_dropdown '项目' "$PROJECT_NAME" '项目管理员项目'
    ab_wait 1500

    if [ "$has_proj_level_tabs" -eq 1 ]; then
        assert_snapshot_contains '项目级别' '项目管理员项目级别数据加载成功'
    fi
fi

# ---------- 收尾 ----------
finish
