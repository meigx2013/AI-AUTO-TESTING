#!/usr/bin/env bash
# ============================================================
# ASDM 回放编排脚本（自动生成，请勿手改生成逻辑）
# 生成文档：.asdm/toolsets/transfer/generate-test-plan.md（§五 B）
# 配套计划：task/test-plan.md（同批生成）
# 数据批次：TEST_TS=0901085429
# ------------------------------------------------------------
# 【布局适配】当前布局：脚本集中放 replay_testcase/ 子目录（文件名 <slug>.sh，
#  无 replay_testcase_ 前缀），公共库放 common/common.sh。
#  脚本定位：${ROOT_DIR}/replay_testcase/<slug>.sh；目录布局变更时需重新生成。
# 【身份切换】010-017、024-026 脚本内置 test01 切换（sesskey 覆盖），无需传参；
#  需覆盖账号时以 TEST01_USER/TEST01_PASS 环境变量传入（load 时环境变量优先）。
# 【编号说明】012 编号含双脚本：012_create-workspace（现役用例）、
#  012_system-logout（遗留脚本，无用例源文件，收尾置尾，见 test-plan.md §七 备注 2）。
# 【豁免机制】EXEMPT_RULES 中任务若对应变量为空或含 PLACEHOLDER 占位符特征，
#  判定为豁免-缺外部数据，跳过执行并留痕（test-plan.md §六）。
# 【本批状态】TEST_TS=0901085429 批次下 GH_TOKEN / AGENT_ORBIT_KEY 均已填入
#  真实值，7 条规则全部不触发（本批 27 任务全部就绪、豁免 0）。规则保留为
#  【条件守卫】：后续刷新 test-data.sh 时变量若回退为空或占位符，对应任务
#  自动重新判定为豁免，无需重新生成本脚本（test-plan.md §六）。
# 【执行能力增强】三项能力（重新生成本脚本时需回填）：
#  1. Ctrl+C 优雅中断：trap 捕获 SIGINT/SIGTERM，当前任务停止记「中断」（任务
#     日志留痕），未开始任务记「未执行」，输出已执行汇总与耗时统计后以退出码
#     130 退出；中断后直接重跑本脚本 = 断点续跑（已通过任务自动跳过）。
#  2. 依赖失败级联跳过：DEPS 依赖表（取自 test-plan.md §二「前置」列）中任一
#     前置任务处于「失败/级联跳过/中断」时，本任务不执行，标记「级联跳过」并
#     注明根因链（如 005_create-user 失败 → 010 及全部 test01 相关后继跳过）；
#     豁免与已有通过记录不级联；修复前置后重跑，级联任务自动恢复执行。
#  3. 耗时统计：逐任务执行时长记入任务日志尾部 [耗时] 行与 run-all.log 逐任务
#     明细表（耗时列），结束输出起止时间、总耗时、任务执行耗时合计。
# 【bash 3.2 兼容】本增强仅用索引数组 + 线性查找（macOS 自带 /bin/bash 3.2 无
#  declare -A 关联数组）；空数组配合 set -u 使用 ${ARR[@]+"${ARR[@]}"} 展开守卫。
# 【日志命名约定】任务级 = result/<任务>.log 覆盖式输出（无时间戳）；
#  汇总 = result/run-all.log；断点续跑判定 = 任务日志内含 "[结果] 通过" 记录
#  （失败自动重测，删除对应文件即强制重跑）。
# ============================================================
# 【运行环境守卫】本脚本依赖 bash 专属特性（数组、${!var} 间接展开、trap），
#  被 sh（POSIX 模式）/ dash 调用会报语法错误，此处自动转 bash 重执行：
if [ -z "${BASH_VERSION:-}" ] || { command -v shopt >/dev/null 2>&1 && shopt -qo posix; }; then
    exec bash "$0" "$@"
fi

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
RESULT_DIR="${ROOT_DIR}/result"
DATA_DIR="${ROOT_DIR}/data"
RUN_LOG="${RESULT_DIR}/run-all.log"   # main() 内截断重建；trap 中断提示亦写此文件
mkdir -p "${RESULT_DIR}"

# ---------- 生成器写入区（勿改动括号外框架） ----------
TASKS=(
  001_system-login
  002_access-asdm
  003_create-org
  004_create-sub-org
  005_create-user
  006_generate-pat
  007_pipeline-config
  008_feature-flag
  009_resource-management-toolset
  010_create-project
  011_project-config
  012_create-workspace
  013_workspace-resources
  014_workspace-runs
  015_create-context
  016_context-items
  017_context-sync-status
  018_agentorbit-config
  019_hide-digidev-icon
  020_asdm-org-agent
  021_organization-agent-config
  022_personal-avatar
  023_digital-avatar-created-successfully
  024_create-online-agent-space
  025_online-knowledge-space
  026_multi-step-build
  099_efficiency-insights
  012_system-logout
)

# 依赖表：元素 "任务slug|前置1 前置2 …"（前置取自
# test-plan.md §二「前置」列），供「依赖失败级联跳过」判定；
# 重新生成本脚本时需回填
DEPS=(
  "001_system-login|"
  "002_access-asdm|001_system-login"
  "003_create-org|001_system-login"
  "004_create-sub-org|001_system-login 003_create-org"
  "005_create-user|001_system-login"
  "006_generate-pat|001_system-login"
  "007_pipeline-config|001_system-login 006_generate-pat"
  "008_feature-flag|001_system-login"
  "009_resource-management-toolset|001_system-login"
  "010_create-project|001_system-login 004_create-sub-org 005_create-user"
  "011_project-config|001_system-login 010_create-project"
  "012_create-workspace|001_system-login 005_create-user 010_create-project"
  "013_workspace-resources|009_resource-management-toolset 010_create-project 012_create-workspace"
  "014_workspace-runs|010_create-project 012_create-workspace 013_workspace-resources"
  "015_create-context|010_create-project"
  "016_context-items|010_create-project 015_create-context"
  "017_context-sync-status|010_create-project 015_create-context 016_context-items"
  "018_agentorbit-config|001_system-login"
  "019_hide-digidev-icon|001_system-login"
  "020_asdm-org-agent|001_system-login"
  "021_organization-agent-config|001_system-login"
  "022_personal-avatar|001_system-login"
  "023_digital-avatar-created-successfully|001_system-login 018_agentorbit-config 022_personal-avatar"
  "024_create-online-agent-space|001_system-login 005_create-user 010_create-project"
  "025_online-knowledge-space|001_system-login 005_create-user 010_create-project"
  "026_multi-step-build|001_system-login 005_create-user 010_create-project 025_online-knowledge-space"
  "099_efficiency-insights|001_system-login 005_create-user"
  "012_system-logout|001_system-login"
)

# EXEMPT_RULES：<任务slug|变量>（键必须与 TASKS 项一致），变量为空或含占位符特征则豁免
# 014/016/017 与 011 同属 GH_TOKEN 级联链（项目无
# GitHub 仓库/CI 时三者必然无法执行），统一纳入豁免机制；
# 重新生成本脚本时需回填此批增补（详见 task/test-plan.md §六 豁免说明）
# 【本批状态】以下 7 条为条件守卫，当前批次变量均已填真实值 → 均不触发；
#  变量回退为空/占位符时自动重新生效（见文件头【本批状态】注记）
EXEMPT_RULES=(
  "011_project-config|GH_TOKEN"
  "014_workspace-runs|GH_TOKEN"
  "016_context-items|GH_TOKEN"
  "017_context-sync-status|GH_TOKEN"
  "018_agentorbit-config|AGENT_ORBIT_KEY"
  "022_personal-avatar|AGENT_ORBIT_KEY"
  "023_digital-avatar-created-successfully|AGENT_ORBIT_KEY"
)
# 占位符特征（test-data.sh 中豁免变量默认值含此特征，如 GH_TOKEN=ghp_xxx…）
PLACEHOLDER="xxx"
# -------------------------------------------------------

# 任务结果记录（索引数组，元素 "任务slug|结果|日志或原因|耗时"，按处理顺序追加）
RESULTS=()
# 未通过集合（索引数组，元素 "任务slug|原因"，仅 收失败/级联跳过/中断 项）
NOT_OK=()

# 加载数据文件（test-data.sh 定义/默认，环境变量优先）
load_data_file() {
  local f="${DATA_DIR}/test-data.sh"
  if [[ -f "${f}" ]]; then
    # shellcheck source=/dev/null
    source "${f}"
  else
    echo "[失败] 数据文件缺失: ${f}" | tee -a "${RUN_LOG}"
    exit 1
  fi
}

# 豁免判定：变量为空或含占位符特征 → 豁免
is_exempt() {
  local task="$1"
  # 空数组守卫：规则全部解除（本批状态）时，"${ARR[@]}" 在 set -u 下会被
  # bash 3.2 判为 unbound variable，故统一采用 ${ARR[@]+"${ARR[@]}"} 展开
  for rule in ${EXEMPT_RULES[@]+"${EXEMPT_RULES[@]}"}; do
    local t="${rule%%|*}" v="${rule##*|}"
    if [[ "${t}" == "${task}" ]]; then
      local val="${!v:-}"
      if [[ -z "${val}" || "${val}" == *"${PLACEHOLDER}"* ]]; then
        echo "豁免-缺外部数据(${v})"
        return 0
      fi
    fi
  done
  return 1
}

# 取任务的前置依赖列表（空格分隔；无则输出空串）
deps_of() {
  local task="$1" e
  for e in "${DEPS[@]}"; do
    if [[ "${e%%|*}" == "${task}" ]]; then
      echo "${e#*|}"
      return 0
    fi
  done
  echo ""
}

# 依赖级联判定：任一前置处于 NOT_OK（失败/级联跳过/中断）→ 输出根因并返回 0
dep_blocked() {
  local task="$1" dep e
  # shellcheck disable=SC2086  # 有意分词：依赖列表以空格分隔多个前置 slug
  for dep in $(deps_of "${task}"); do
    for e in ${NOT_OK[@]+"${NOT_OK[@]}"}; do
      if [[ "${e%%|*}" == "${dep}" ]]; then
        echo "前置 ${dep} ${e#*|}"
        return 0
      fi
    done
  done
  return 1
}

# 取任务结果记录：输出 "结果|日志或原因|耗时"，无记录则 "未记录|无执行记录|-"
get_result() {
  local task="$1" e
  for e in ${RESULTS[@]+"${RESULTS[@]}"}; do
    if [[ "${e%%|*}" == "${task}" ]]; then
      echo "${e#*|}"
      return 0
    fi
  done
  echo "未记录|无执行记录|-"
}

# 秒数 → 可读时长（如 3725 → 1h2m5s；65 → 1m5s；37 → 37s）
fmt_dur() {
  local s="$1"
  if (( s >= 3600 )); then
    printf '%dh%dm%ds' $(( s / 3600 )) $(( (s % 3600) / 60 )) $(( s % 60 ))
  elif (( s >= 60 )); then
    printf '%dm%ds' $(( s / 60 )) $(( s % 60 ))
  else
    printf '%ds' "${s}"
  fi
}

# Ctrl+C（SIGINT/SIGTERM）优雅中断：置标志并留痕；主循环据此停止后续任务、
# 输出已执行汇总与耗时统计后以退出码 130 退出。不在 trap 内直接 exit，
# 以保证正在执行的任务能完整走完留痕分支（任务日志补 [结果] 中断 + [耗时]）。
INTERRUPTED=0
CURRENT_TASK=""
on_interrupt() {
  INTERRUPTED=1
  echo "" | tee -a "${RUN_LOG}"
  echo "[中断] 收到中断信号（Ctrl+C）：停止当前任务 ${CURRENT_TASK:-无}，后续任务不再执行，即将输出汇总" | tee -a "${RUN_LOG}"
}
trap on_interrupt INT TERM

main() {
  load_data_file
  # 【日志命名约定】统一固定名覆盖式输出（无时间戳）：
  #   任务级 = ${RESULT_DIR}/<任务>.log　汇总级 = ${RESULT_DIR}/run-all.log；
  # 是否已测试的判定 = 任务日志内含 "[结果] 通过" 记录（失败自动重测，
  # 删除对应文件即强制重跑），避免时间戳堆叠导致无法分辨测试状态
  RUN_LOG="${RESULT_DIR}/run-all.log"
  : > "${RUN_LOG}"
  # TEST_TS 由 generate-test-data.md 作为注释标注于 test-data.sh 头部（非变量），不在此引用
  local t_start="$(date +%s)"
  local t_start_str="$(date '+%Y-%m-%d %H:%M:%S')"
  echo "==== ASDM 回放编排：共 ${#TASKS[@]} 个任务　开始: ${t_start_str} ====" | tee -a "${RUN_LOG}"

  local pass=0 fail=0 exempt=0 skip=0 cascade=0 interrupt=0 notrun=0
  local exec_secs=0      # 已执行任务（通过/失败/中断）纯执行耗时合计（秒）
  RESULTS=()
  NOT_OK=()
  local tc

  for tc in "${TASKS[@]}"; do
    # ---- 中断检测：已中断则剩余任务全部标记「未执行」留痕 ----
    if (( INTERRUPTED )); then
      echo "[未执行] ${tc}（用户中断，任务未开始）" | tee -a "${RUN_LOG}"
      RESULTS+=("${tc}|未执行|用户中断(Ctrl+C)，任务未开始|-")
      NOT_OK+=("${tc}|中断(用户中断)")
      notrun=$((notrun + 1))
      continue
    fi

    local script="${ROOT_DIR}/replay_testcase/${tc}.sh"
    local log_file="${RESULT_DIR}/${tc}.log"
    if [[ ! -f "${script}" ]]; then
      echo "[阻塞] 脚本缺失: ${script}" | tee -a "${RUN_LOG}"
      RESULTS+=("${tc}|阻塞|脚本缺失: ${script}|-")
      NOT_OK+=("${tc}|失败(脚本缺失)")
      fail=$((fail + 1)); continue
    fi
    if exemption="$(is_exempt "${tc}")"; then
      echo "[豁免] ${tc}（${exemption}）" | tee -a "${RUN_LOG}"
      RESULTS+=("${tc}|豁免|${exemption}|-")
      exempt=$((exempt + 1)); continue
    fi
    # ---- 依赖失败级联判定：任一前置未通过（失败/级联跳过/中断）→ 本任务不执行 ----
    if blocked="$(dep_blocked "${tc}")"; then
      echo "[级联跳过] ${tc}：${blocked}，依赖未就绪不执行（修复前置后重跑本脚本，本任务自动恢复执行）" | tee -a "${RUN_LOG}"
      RESULTS+=("${tc}|级联跳过|${blocked}|-")
      NOT_OK+=("${tc}|级联跳过(${blocked})")
      cascade=$((cascade + 1)); continue
    fi
    # 断点续跑判定 = 任务日志含 [结果] 通过（固定名覆盖式：未通过无此记录，
    # 下次自动重测；删除文件即强制重跑）——替代原失效的时间戳模式检查
    if grep -q '^\[结果\] 通过' "${log_file}" 2>/dev/null; then
      echo "[跳过] ${tc} 已有通过记录（${log_file}），跳过" | tee -a "${RUN_LOG}"
      RESULTS+=("${tc}|跳过|已有通过记录(${log_file})|-")
      skip=$((skip + 1)); continue
    fi
    # ---- 执行 + 计时（执行前再查中断标志，兜底检查阶段收到的 Ctrl+C） ----
    if (( INTERRUPTED )); then
      echo "[未执行] ${tc}（用户中断，任务未开始）" | tee -a "${RUN_LOG}"
      RESULTS+=("${tc}|未执行|用户中断(Ctrl+C)，任务未开始|-")
      NOT_OK+=("${tc}|中断(用户中断)")
      notrun=$((notrun + 1))
      continue
    fi
    CURRENT_TASK="${tc}"
    local t0="$(date +%s)"
    echo "[执行] ${tc} → ${log_file}　开始: $(date '+%H:%M:%S')" | tee -a "${RUN_LOG}"
    if bash "${script}" >"${log_file}" 2>&1; then
      local dur=$(( $(date +%s) - t0 )); exec_secs=$((exec_secs + dur))
      echo "[结果] 通过 $(date '+%Y-%m-%d %H:%M:%S')" >> "${log_file}"
      echo "[耗时] ${dur}s" >> "${log_file}"
      echo "[通过] ${tc}（耗时 $(fmt_dur "${dur}")）" | tee -a "${RUN_LOG}"
      RESULTS+=("${tc}|通过|${log_file}|${dur}s")
      pass=$((pass + 1))
    else
      local dur=$(( $(date +%s) - t0 )); exec_secs=$((exec_secs + dur))
      if (( INTERRUPTED )); then
        echo "[结果] 中断 $(date '+%Y-%m-%d %H:%M:%S')" >> "${log_file}"
        echo "[中断] ${tc}（Ctrl+C 停止，已执行 $(fmt_dur "${dur}")；日志 ${log_file}；重跑本脚本自动重测）" | tee -a "${RUN_LOG}"
        RESULTS+=("${tc}|中断|用户中断(Ctrl+C)|${dur}s")
        NOT_OK+=("${tc}|中断(用户中断)")
        interrupt=$((interrupt + 1))
      else
        echo "[结果] 失败 $(date '+%Y-%m-%d %H:%M:%S')" >> "${log_file}"
        echo "[失败] ${tc}（耗时 $(fmt_dur "${dur}")；留痕 ${log_file}，下次运行自动重测；依赖本任务的后继任务将级联跳过）" | tee -a "${RUN_LOG}"
        RESULTS+=("${tc}|失败|${log_file}|${dur}s")
        NOT_OK+=("${tc}|失败")
        fail=$((fail + 1))
      fi
      echo "[耗时] ${dur}s" >> "${log_file}"
    fi
    CURRENT_TASK=""
  done

  # ---- 汇总：计数 + 逐任务明细（含耗时）+ 耗时统计 ----
  local total_dur=$(( $(date +%s) - t_start ))
  echo "==== 汇总：通过 ${pass} / 失败 ${fail} / 级联跳过 ${cascade} / 豁免 ${exempt} / 跳过(已有通过) ${skip} / 中断 ${interrupt} / 未执行(中断) ${notrun}（共 ${#TASKS[@]}） ====" | tee -a "${RUN_LOG}"
  echo "---- 逐任务明细 ----" | tee -a "${RUN_LOG}"
  printf " %-42s %-8s %-8s %s\n" "任务" "结果" "耗时" "日志/原因" | tee -a "${RUN_LOG}"
  for tc in "${TASKS[@]}"; do
    r="$(get_result "${tc}")"
    res="${r%%|*}"; rest="${r#*|}"
    cause="${rest%%|*}"; dur="${rest#*|}"
    printf " %-42s %-8s %-8s %s\n" "${tc}" "${res}" "${dur}" "${cause}" | tee -a "${RUN_LOG}"
  done
  echo "---- 耗时统计 ----" | tee -a "${RUN_LOG}"
  echo "起止时间：${t_start_str} → $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "${RUN_LOG}"
  echo "总耗时：$(fmt_dur "${total_dur}")" | tee -a "${RUN_LOG}"
  echo "任务执行耗时合计：$(fmt_dur "${exec_secs}")（不含跳过/豁免/级联跳过/未执行任务）" | tee -a "${RUN_LOG}"
  echo "日志：${RUN_LOG}" | tee -a "${RUN_LOG}"

  if (( INTERRUPTED )); then
    echo "[中断退出 code=130] 断点续跑：直接重跑本脚本（已通过任务自动跳过，从首个未通过任务继续）" | tee -a "${RUN_LOG}"
    exit 130
  fi
  [[ ${fail} -eq 0 ]]
}

main "$@"
