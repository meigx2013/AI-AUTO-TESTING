# 回放测试目录结构规格说明

> 定义 agent-browser 回放测试产物的统一目录结构与落盘规则，作为
> `testcase-to-sh` / `transfer-to-sh` 等工具的输出路径依据，以及脚本运行
> 产物（中间数据、日志、截图）的存放约定。
>
> - 根目录固定为 `.asdm/workspace/replay-testcase/`（相对项目根目录，不存在时先创建）
> - 按产物类型划分为五个子目录：**公共库 `common` / 测试脚本 `replay_testcase` /
>   测试数据 `data` / 任务编排 `task` / 执行结果 `result`**
> - **定版布局（2026-09-01 起）**：脚本集中放 `replay_testcase/`，公共库放
>   `common/`，两者同级；脚本文件名不再带 `replay_testcase_` 前缀（目录名已表达归属）

## 一、目录结构定义

```
.asdm/workspace/replay-testcase/            # 回放测试根目录（固定，相对项目根目录）
├── common/                                 # 公共方法库
│   └── common.sh                           # 全部回放脚本 source 复用（唯一一份）
├── replay_testcase/                        # 回放脚本（每用例一个，平铺于本目录）
│   ├── 001_system-login.sh
│   ├── 003_create-org.sh
│   └── …                                   # 其余用例同构：<编号_用例名>.sh
├── data/                                   # 测试数据
│   ├── test-data.sh                        # 统一测试数据（generate-test-data.md 刷新）
│   ├── pat.txt                             # 用例间传递的中间数据（如 006 生成的 PAT 令牌）
│   └── …                                   # 上传文件、参数化文件、跨用例落盘数据
├── task/                                   # 任务编排
│   ├── run-all.sh                          # 全量串联执行编排脚本
│   ├── test-plan.md                        # 测试计划静态实例
│   └── …                                   # 批次编排脚本、任务定义、依赖链（json/md/sh）
└── result/                                 # 执行结果
    ├── 001_system-login.log                # 回放日志（现役实现：固定名覆盖式）
    ├── 001_system-login-20260824_1015.png  # 页面截图（按需，带时间戳）
    └── …                                   # 断言报告、汇总报告（run-all.log）
```

## 二、各目录职责定义

| 目录 | 职责 | 存放内容 | 产生方 |
| --- | --- | --- | --- |
| `common/` | 公共方法库 | 唯一的 `common.sh`（快照定位、点击/填充、等待、断言、登录导航、收尾等通用能力） | `testcase-to-sh` 生成后人工增强沉淀 |
| `replay_testcase/` | 测试脚本 | 每用例一个 `<编号>_<用例名>.sh`，只写业务步骤，通用能力一律调用 `common.sh` | `testcase-to-sh` 生成 |
| `data/` | 测试数据 | 统一 `test-data.sh`、用例间传递的中间数据（`pat.txt` 等）、上传文件、参数文件 | 脚本运行落盘 + 人工准备 |
| `task/` | 任务编排 | 串联执行编排脚本、测试计划、任务定义、依赖链与执行计划 | 人工 / `generate-test-plan.md` 生成 |
| `result/` | 执行结果 | 回放日志、页面截图、断言/汇总报告 | 脚本运行产物 |

### 2.1 common/ —— 公共方法库

- 全仓**仅一份** `common/common.sh`，一次生成、全部脚本 source 复用，**已存在时直接复用不重生成**。
- 转换中发现的通用新能力（多处复用的定位/操作/断言模式）先沉淀进本文件，禁止在业务脚本内复制库函数。
- 库内 `DATA_DIR` 默认值为 `<本库所在目录>/../data`（即 `replay-testcase/data`），source 前赋值或环境变量可覆盖。

### 2.2 replay_testcase/ —— 测试脚本

- **每用例一个脚本**，文件名 = `<编号>_<用例名>.sh`（如 `001_system-login.sh`），编号序即依赖序、执行序。
- 脚本只描述"业务步骤"，通用能力全部经 `common.sh` 调用（设计原则：业务脚本写"做什么"，公共库管"怎么驱动浏览器"）。
- 用例的录制 JSON 源文件（Chrome DevTools Recorder 导出）留在项目根或指定位置，不随脚本迁入本目录（本目录只放可执行脚本）。
- 用例专属数据不生成独立 `-data.sh`：全部用例共用 `data/test-data.sh`，新数据以分节追加方式并入。

### 2.3 data/ —— 测试数据

- 存放统一测试数据 `test-data.sh`（`: "${VAR:=默认值}"` 形式，环境变量优先）与跨用例共享的**动态数据**。
- 中间数据按用途命名：`<数据键名>.txt`，如 `pat.txt`、`new-user.txt`；含明文凭据的落盘文件须 `chmod 600`。
- 脚本内通过环境变量兜底读取，读不到即报错并提示先执行依赖脚本（规则同 `testcase-to-sh` §4.7）。

### 2.4 task/ —— 任务编排

- 存放**跨用例的串联执行编排**，体现依赖链（编号序即依赖序）。
- 编排脚本以 `$(dirname "$0")/..` 定位根目录，再进 `replay_testcase/` / `data` / `result`：

```bash
#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
RESULT_DIR="${ROOT_DIR}/result"
DATA_DIR="${ROOT_DIR}/data"
for tc in 001_system-login 002_access-asdm 003_create-org 004_create-sub-org \
          005_create-user 006_generate-pat; do
    bash "${ROOT_DIR}/replay_testcase/${tc}.sh" || exit 1
done
```

- 现役编排器 `run-all.sh` 另含中断处理、依赖级联跳过、豁免判定、耗时统计等能力，
  细节见 `.asdm/workspace/replay-testcase/task/run-all.sh` 头部注释与 `test-plan.md`。

### 2.5 result/ —— 执行结果

- 存放脚本运行产生的**日志、截图、报告**：
  - 日志（现役实现）：`<编号>_<用例名>.log` 固定名覆盖式，断点续跑依据日志内 `[结果] 通过` 记录
  - 汇总日志：`run-all.log`
  - 截图（按需）：`<编号>_<用例名>-<YYYYMMDD_HHMMSS>.png`
- 可提交的失败现场（`agent-browser screenshot` 产物）也落此目录，便于回溯定位。

## 三、路径引用规则（脚本内）

脚本内**不得硬编码根目录绝对路径**，一律基于自身位置相对定位：

```bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"      # = .../replay-testcase/replay_testcase
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/../common/common.sh"            # 公共库（同级 common/ 目录）
DATA_DIR="${SCRIPT_DIR}/../data"                 # 测试数据（同级 data/ 目录）
RESULT_DIR="${SCRIPT_DIR}/../result"             # 执行结果（按需，日志由编排器落盘）
TASK_DIR="${SCRIPT_DIR}/../task"                 # 任务编排
load_data_file "${DATA_DIR}/test-data.sh"        # 数据先于 ab_init 加载
```

- 加载顺序不可颠倒：`source common.sh` → 赋值 `DATA_DIR` → `load_data_file` → `ab_init`
  （`BASE_URL` 兜底在 `ab_init` 内生效，外部环境 > test-data.sh > 兜底值）。
- 环境变量优先：`PAT="${PAT:-$(cat "$DATA_DIR/pat.txt" 2>/dev/null)}"`，读不到报错并提示先跑依赖脚本。
- 编排脚本（`task/` 下）以 `$(dirname "$0")/..` 定位根目录，再进 `replay_testcase` / `data` / `result`。

## 四、生成规则（对接现有工具文档）

| 工具文档 | 输出约定 |
| --- | --- |
| `testcase-to-sh` §一/§十 | 每用例生成 `replay_testcase/<编号>_<用例名>.sh`；公共库 `common/common.sh`；中间数据落 `data/`；编排与计划落 `task/` |
| `generate-test-data.md` | 刷新 `data/test-data.sh`（名称类数据带 `TEST_TS` 时间戳后缀） |
| `generate-test-plan.md` | 生成/刷新 `task/run-all.sh` 与 `task/test-plan.md` |
| `transfer-to-sh` §四 | 录制 JSON 回放脚本落 `.asdm/workspace/replay-recording/`（独立产物，不进本目录） |

统一执行流程：

1. 首次使用时创建目录：`mkdir -p .asdm/workspace/replay-testcase/{common,replay_testcase,data,task,result}`
2. 生成脚本时：公共库写 `common/common.sh`；每用例写 `replay_testcase/<编号>_<用例名>.sh`
3. 运行脚本时：中间数据 → `data/`；日志、截图、报告 → `result/`
4. 串联执行：编排脚本 → `task/`，内部经 `../replay_testcase/<编号>_<用例名>.sh` 引用

## 五、迁移与兼容

- **历史布局**（脚本平铺于 `replay-testcase/` 根目录、文件名带 `replay_testcase_` 前缀、
  `common.sh` 与脚本同层）已于 2026-09-01 迁移至本布局，迁移三件事：
  1. `replay_testcase_<slug>.sh` → `replay_testcase/<slug>.sh`（去前缀）
  2. `common.sh` → `common/common.sh`
  3. 脚本头部三处同步：`source` 路径、`DATA_DIR`、注释中的脚本名；
     `common.sh` 内 `DATA_DIR` 默认值改 `../data`；`task/run-all.sh` 执行入口加 `/replay_testcase/`
- `data/`、`task/`、`result/` 目录路径不变，历史数据与日志无需迁移。
- `.gitignore` 建议追加：`.asdm/workspace/replay-testcase/data/test-data.sh`（含明文凭据）、
  `.asdm/workspace/replay-testcase/result/`（运行产物可再生成）。

## 已知限制

- 各用例脚本默认不自动级联执行，串联依赖由 `task/` 编排脚本承担（脚本内登录类前置除外）。
- 脚本内 `SCRIPT_DIR` 相对定位依赖"脚本位于 `replay_testcase/` 一级子目录"这一前提，
  目录改名或层级调整需同步更新引用（含 `common.sh` 的 `DATA_DIR` 默认值）。
- 敏感数据（密码、Token）仅存在于 `data/test-data.sh` 与 `data/` 落盘文件，禁止写入脚本或提交版本库。
