# UI Replay Testing Toolset — 安装指南

## 环境检测

当前环境：**Tencent CodeBuddy**（`.codebuddy` 目录存在）

## 前置依赖

- `agent-browser` CLI 已安装并在 PATH 中（安装方式见 `spec/agent-browser-spec.md` §二：
  `npm install -g agent-browser` + `agent-browser install` 下载 Chrome for Testing）
- `bash` 可用（回放脚本与编排脚本依赖 bash 专属特性：进程替换、数组、`${!var}`）

## 安装步骤

### 1. 创建工作区目录

```bash
mkdir -p .asdm/workspace/replay-testcase/{common,replay_testcase,data,task,result}
```

### 2. 注册快捷命令（Tencent CodeBuddy）

采用**引用式注册**：在 `.codebuddy/commands/` 中创建引用存根（而非复制完整指令），存根通过 `actionRef` 指向源 action 文件，执行时由 AI 读取源文件并按其完整指令执行。这样指令只需在 `.asdm/toolsets/ui-auto-testing/actions/` 中维护一份，工具集升级后无需重新复制。

```bash
# 为以下 3 个命令分别创建引用存根（保留 frontmatter 中的 registryId 与 actionRef，正文指示读取源文件执行）：
#   .codebuddy/commands/testcase-to-sh.md        -> actions/testcase-to-sh.md
#   .codebuddy/commands/generate-test-data.md    -> actions/generate-test-data.md
#   .codebuddy/commands/generate-test-plan.md    -> actions/generate-test-plan.md
```

存根文件格式示例：

```markdown
---
registryId: ui-auto-testing
actionRef: .asdm/toolsets/ui-auto-testing/actions/<命令名>.md
---
# <命令名>（引用式注册）

本文件是引用式注册存根，完整指令维护在源文件中，本存根不包含任何额外逻辑。

## 执行指令

1. 立即使用文件读取工具读取源文件：`.asdm/toolsets/ui-auto-testing/actions/<命令名>.md`
2. **源文件的全部内容即为本命令的完整指令**，严格按照其中的指令执行任务
3. 用户在本命令后输入的参数作为源指令的输入
4. 若源文件中引用了其他相对路径文件（spec、scripts 等），均相对工作区根目录解析

## 用途

<一句话命令用途>
```

### 3. 验证安装

确认以下目录和文件存在：

- `.asdm/workspace/replay-testcase/` — 工作区目录（含 `common` / `replay_testcase` / `data` / `task` / `result` 五子目录）
- `.codebuddy/commands/testcase-to-sh.md`
- `.codebuddy/commands/generate-test-data.md`
- `.codebuddy/commands/generate-test-plan.md`
- `.asdm/toolsets/ui-auto-testing/manifest.json`

## 可用命令

| 命令 | 功能 |
|------|------|
| `/testcase-to-sh` | 用例转换 — 测试用例 md → agent-browser 回放脚本 |
| `/generate-test-data` | 数据刷新 — 批次名称类数据 TEST_TS 时间戳 |
| `/generate-test-plan` | 计划生成 — 测试计划 + run-all.sh 全量编排 |

## 端到端工作流

```
Step 1: /testcase-to-sh test-cases/           ← 用例 md 批量转换为回放脚本
Step 2: /generate-test-data                   ← 刷新批次数据（每批新回放前一次）
Step 3: /generate-test-plan                   ← 生成测试计划与全量编排脚本
Step 4: bash .asdm/workspace/replay-testcase/task/run-all.sh   ← 全量执行
        （调试：单任务执行；中断后：断点续跑，禁止整批重跑）
```
