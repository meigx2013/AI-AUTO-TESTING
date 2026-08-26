# UI Automation Testing Toolset — 安装指南

## 环境检测

当前环境：**Tencent CodeBuddy**（`.codebuddy` 目录存在）

## 安装步骤

### 1. 创建工作区目录

```bash
mkdir -p .asdm/workspace/ui-test
mkdir -p recordings
```

### 2. 注册快捷命令（Tencent CodeBuddy）

采用**引用式注册**：在 `.codebuddy/commands/` 中创建引用存根（而非复制完整指令），存根通过 `actionRef` 指向源 action 文件，执行时由 AI 读取源文件并按其完整指令执行。这样指令只需在 `.asdm/toolsets/ui-automation-testing/actions/` 中维护一份，工具集升级后无需重新复制。

```bash
# 为以下 4 个命令分别创建引用存根（保留 frontmatter 中的 registryId 与 actionRef，正文指示读取源文件执行）：
#   .codebuddy/commands/asdm-ui-test-step-design.md       -> actions/asdm-ui-test-step-design.md
#   .codebuddy/commands/asdm-ui-test-design-generate.md   -> actions/asdm-ui-test-design-generate.md
#   .codebuddy/commands/asdm-ui-test-run.md               -> actions/asdm-ui-test-run.md
#   .codebuddy/commands/asdm-ui-test-freshness.md         -> actions/asdm-ui-test-freshness.md
```

存根文件格式示例：

```markdown
---
registryId: ui-automation-testing
actionRef: .asdm/toolsets/ui-automation-testing/actions/asdm-ui-test-<命令名>.md
---
# asdm-ui-test-<命令名>（引用式注册）

本文件是引用式注册存根，完整指令维护在源文件中，本存根不包含任何额外逻辑。

## 执行指令

1. 立即使用文件读取工具读取源文件：`.asdm/toolsets/ui-automation-testing/actions/asdm-ui-test-<命令名>.md`
2. **源文件的全部内容即为本命令的完整指令**，严格按照其中的指令执行任务
3. 用户在本命令后输入的参数作为源指令的输入
4. 若源文件中引用了其他相对路径文件（spec、template、scripts 等），均相对工作区根目录解析

## 用途

<一句话命令用途>
```

### 3. 验证安装

确认以下目录和文件存在：

- `.asdm/workspace/ui-test/` — 工作区目录
- `.codebuddy/commands/asdm-ui-test-step-design.md`
- `.codebuddy/commands/asdm-ui-test-design-generate.md`
- `.codebuddy/commands/asdm-ui-test-run.md`
- `.codebuddy/commands/asdm-ui-test-freshness.md`
- `.asdm/toolsets/ui-automation-testing/manifest.json`

## 可用命令

| 命令 | 功能 |
|------|------|
| `/asdm-ui-test-step-design` | 测试步骤设计 — PRD → 测试步骤文档 + 录制计划 |
| `/asdm-ui-test-design-generate` | 设计与编码 — 读取录制脚本 → 双产物转换 |
| `/asdm-ui-test-run` | 执行与报告 — 执行脚本 → 断言报告 |
| `/asdm-ui-test-freshness` | 保鲜巡检 — 覆盖检测 + 健康巡检 + AI 自愈 |

## 端到端工作流

```
Step 0: /asdm-ui-test-step-design  测试<功能描述>     ← 设计测试步骤+录制计划
Step 1: 人工使用 Chrome DevTools Recorder 录制 → 保存到 recordings/  ← 人工环节
Step 2: /asdm-ui-test-design-generate 测试<功能描述>  ← AI 转换生成脚本
Step 3: /asdm-ui-test-run <用例名>                   ← 执行+报告
Step 4: /asdm-ui-test-freshness 全部                 ← 定期保鲜巡检
```
