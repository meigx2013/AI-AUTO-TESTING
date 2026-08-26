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

将 4 个 action 文件复制到 `.codebuddy/commands/` 目录：

```bash
Copy-Item .asdm/toolsets/ui-automation-testing/actions/asdm-ui-test-step-design.md .codebuddy/commands/ -Force
Copy-Item .asdm/toolsets/ui-automation-testing/actions/asdm-ui-test-design-generate.md .codebuddy/commands/ -Force
Copy-Item .asdm/toolsets/ui-automation-testing/actions/asdm-ui-test-run.md .codebuddy/commands/ -Force
Copy-Item .asdm/toolsets/ui-automation-testing/actions/asdm-ui-test-freshness.md .codebuddy/commands/ -Force
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
