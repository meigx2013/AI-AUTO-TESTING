# Tools Directory

本目录包含支持 asdm-planner 工具集功能的实用工具。这些工具设计用于 CLI 环境，供 Agent 调用。

## Structure

每个工具应有独立的子目录，包含：
- `README.md`：工具文档
- `main.py` 或 `main.js`：入口文件
- `config.json`：配置文件（可选）
- `tests/`：测试套件（推荐）

## Available Tools

### path-validator
**路径验证工具**：验证 asdm-admin 子模块中的文件路径正确性，生成相对路径链接用于特性进展报告。

**功能**：
- 验证文件路径是否存在
- 生成 Markdown 格式的相对路径链接
- 提供 CLI 命令验证示例
- 支持批量文件路径验证

**使用**：
```bash
cd tools/path-validator
python main.py --validate <文件路径>
python main.py --validate-and-link <文件路径>
```

## Planned Tools

### planning-sync
同步产品规划文档，从 Git 仓库拉取最新的 `ASDM-ProductPlanning.md` 和特性文档，确保本地与远程一致。

### feature-status
查询和更新特性状态，支持按模块、Release、优先级等维度过滤，输出 Markdown 表格。

## Guidelines

1. 工具应自包含，不依赖其他工具的内部实现
2. 每个工具遵循单一职责原则
3. 配置应外部化，通过 `config.json` 或环境变量管理
4. 错误处理应健壮，提供有意义的错误消息
5. 日志应可配置，支持 verbose 模式

## Example Tool Structure

```
{tool-name}/
├── README.md
├── main.py
├── config.json
└── tests/
    └── test_main.py
```
