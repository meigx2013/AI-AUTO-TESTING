# Path Validator Tool

路径验证工具，用于验证 asdm-admin 子模块中的文件路径正确性，确保特性进展报告中的代码链接有效。

## 功能

- 验证文件路径是否存在
- 生成相对路径链接（用于 Markdown 文档）
- 支持批量文件路径验证
- 提供 CLI 命令示例

## 使用方式

### 1. 验证单个文件

```bash
# 验证文件是否存在
python main.py --validate /home/azureuser/source/asdm-product-management/asdm-admin/asdm-admin-services/asdm-admin-services-core/src/main/java/ai/asdm/admin/core/controller/auth/PersonalAccessTokenController.java

# 验证并生成相对路径链接
python main.py --validate-and-link /home/azureuser/source/asdm-product-management/asdm-admin/asdm-admin-services/asdm-admin-services-core/src/main/java/ai/asdm/admin/core/controller/auth/PersonalAccessTokenController.java
```

### 2. 批量验证

```bash
# 从配置文件批量验证
python main.py --batch config.json

# 从文件列表批量验证
python main.py --file-list files.txt
```

### 3. 生成 CLI 验证命令

```bash
# 生成 find 命令示例
python main.py --generate-find PersonalAccessTokenController.java

# 生成 ls 命令示例
python main.py --generate-ls PersonalAccessTokenController.java
```

## 配置文件格式

```json
{
  "base_path": "/home/azureuser/source/asdm-product-management",
  "asdm_admin_path": "asdm-admin",
  "report_base_path": "docs/planning/Feat/FT-XXX",
  "files": [
    "asdm-admin/asdm-admin-services/asdm-admin-services-core/src/main/java/ai/asdm/admin/core/controller/auth/PersonalAccessTokenController.java",
    "asdm-admin/asdm-admin-services/asdm-admin-services-core/src/main/java/ai/asdm/admin/core/service/auth/PersonalAccessTokenService.java",
    "asdm-admin/deploy/mysql/migrations/V1.1.2__Personal_Access_Tokens.sql"
  ]
}
```

## 输出格式

### 验证结果

```json
{
  "file_path": "/full/path/to/file.java",
  "exists": true,
  "relative_link": "../../../../asdm-admin/.../file.java",
  "filename": "file.java",
  "markdown_row": "| `file.java` | [查看代码](../../../../asdm-admin/.../file.java) |"
}
```

### CLI 命令示例

```bash
# 验证文件是否存在
find /home/azureuser/source/asdm-product-management/asdm-admin -name "PersonalAccessTokenController.java" -type f

# 查看完整路径
ls -la /home/azureuser/source/asdm-product-management/asdm-admin/asdm-admin-services/asdm-admin-services-core/src/main/java/ai/asdm/admin/core/controller/auth/PersonalAccessTokenController.java
```

## 集成到特性进展报告流程

在生成特性进展报告时，应先调用此工具验证所有文件路径：

1. **验证阶段**：使用此工具验证所有 DoD 验收点相关的文件路径
2. **生成阶段**：仅对存在的文件生成 Markdown 链接
3. **报告阶段**：在附录中显示验证结果和生成的 Markdown 表格

## 错误处理

- 文件不存在时返回明确的错误信息
- 路径格式错误时提供修复建议
- 支持相对路径和绝对路径输入
- 提供详细的调试信息（verbose 模式）