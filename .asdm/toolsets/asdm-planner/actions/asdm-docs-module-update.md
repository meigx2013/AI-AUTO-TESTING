# Docs Module Update

## Metadata

```json
{
  "guid": "d6e7f8a9-b0c1-2d3e-4f5a-6b7c8d9e0f1a",
  "name": "asdm-docs-module-update",
  "displayName": "Docs Module Update",
  "description": "编写或更新 ASDM 平台的功能模块说明文档，对特定功能模块进行功能性描述和操作指导",
  "toolset": {
    "guid": "e5f6a7b8-c9d0-1e2f-3a4b5c6d7e8f",
    "id": "asdm-planner",
    "name": "ASDM Planner Toolset",
    "version": "1.0.0"
  },
  "scenario": "module-docs"
}
```

## Description
编写或更新 ASDM 平台的功能模块说明文档。模块功能说明文档面向最终用户，对 ASDM 中的特定功能模块进行功能性描述和操作指导。支持自然语言输入，AI 自动扫描代码理解功能实现，并按照标准文档结构生成用户操作手册。

本 action 适用于 `asdm-docs` 文档站点的模块文档编写，产出文档存放于 `asdm-docs/public/docs/zh-cn/content/platform/modules/` 目录下。文档以用户视角撰写，包含详细的功能描述、操作指引和截图占位符。

## Usage
```
/asdm-docs-module-update <自然语言描述>
```

用户可以用自然语言描述要编写的模块文档信息，AI 将自动提取所需参数。如缺少必要信息，AI 会向用户询问确认。

## Parameters

所有参数均可通过自然语言输入，AI 自动提取。若必填参数缺失，AI 须向用户询问。

| 参数 | 必填 | 说明 | 示例 |
|------|:----:|------|------|
| `module_name` | ✅ | 功能模块名称（中文） | "组织结构管理"、"实例管理"、"资源库管理" |
| `target_path` | ✅ | 文档目标路径（相对于 asdm-docs 文档根目录） | "platform/modules/organization"、 "platform/modules/instance" |
| `code_paths` | ✅ | 需要扫描的代码路径列表（用于理解功能实现） | "asdm-admin/asdm-admin-web/src/pages/Projects/" |
| `sub_modules` | ❌ | 子模块列表（用于生成目录和关联文档） | ["projects", "users", "permissions"] |
| `update_mode` | ❌ | 更新模式：create（新建）/ update（更新现有），默认 create | create、update |

## Examples

### 自然语言输入
```
/asdm-docs-module-update 编写组织结构管理模块的文档，包括项目管理、用户角色、权限系统和设置管理
```

```
/asdm-docs-module-update 为实例管理模块编写功能说明文档，代码在 asdm-admin 的 Instance 相关页面
```

```
/asdm-docs-module-update 更新组织结构管理的文档，补充截图和操作说明
```

```
/asdm-docs-module-update 编写资源库管理模块文档，路径 platform/modules/repo，子模块包括注册表、上下文管理、规约管理
```

## Process

### 1. 解析输入

从自然语言中提取参数：
- **模块名称**：从描述中提取功能模块名（如"组织结构管理"→ module_name="组织结构管理"）
- **目标路径**：从描述中提取或推断文档存放路径
- **代码路径**：从描述中提取代码位置关键词，映射到具体代码目录
- **子模块列表**：从描述中提取子功能名称
- **更新模式**：语义映射（"更新"/"补充"→update，"编写"/"创建"→create）

若无法确定模块名称或代码路径，向用户询问确认。

### 2. 代码上下文扫描（必须执行）

**编写文档前必须使用 code-explorer 对相关代码进行扫描**，确保文档内容基于实际功能实现，而非凭空想象。

扫描范围：
- 模块对应的前端页面组件（路由、页面组件、子组件）
- 相关的 API 服务调用（API client、请求方法）
- 类型定义和接口（TypeScript 类型、接口定义）
- 后端 API 端点和 Controller（如有需要）
- 相关的配置文件和路由定义

扫描结果用于：
- 理解功能模块的完整功能列表和用户操作流程
- 获取准确的字段名称、状态值、选项列表等
- 确认页面布局、交互逻辑和导航关系
- 验证功能描述与代码实现的一致性

### 3. 检查现有文档

- 如果 `update_mode=create`：
  - 检查目标路径下是否已存在 `_index.md` 文件
  - 若存在，提示用户是否切换为 update 模式
  - 若不存在，按模板创建新文档

- 如果 `update_mode=update`：
  - 读取现有 `_index.md` 和子模块文档
  - 对比代码扫描结果，识别需要补充或修正的内容
  - 保留现有文档的合理结构，仅更新需要变更的部分

### 4. 生成/更新文档

基于代码扫描结果，按 `.asdm/toolsets/asdm-planner/specs/templates/Module-Doc-Template.md` 模板生成或更新文档。

**文档编写原则**：
- 面向最终用户，避免技术术语和代码细节
- 每个章节开头提供详细的文字说明，解释"这是什么"和"为什么需要"
- 在合理的位置提供截图占位符（`![描述](./images/xxx.png)`）
- 使用 1. / 1.1 / 1.1.1 编号体系
- 确保文字描述足够让用户理解功能，避免只有标题和表格

### 5. 生成子模块文档

如果用户指定了 `sub_modules`，为每个子模块生成独立的 Markdown 文档，并确保：
- 每个子模块文档有独立的标题和概述段落
- 子模块文档之间通过相对路径链接互相引用
- `_index.md` 中包含指向各子模块文档的目录链接

### 6. 粗体格式检查（必须执行）

**写入文件前必须执行粗体格式检查**，按照 `specs4shared.md` 9.4 节的规范逐项检查 B1-B5：

1. 扫描文档中所有 `**...**` 粗体标记
2. 逐项检查：
   - B1：粗体内不含句末中文标点（`？`、`。`、`！`）
   - B2：粗体不包裹完整长句或问句，仅强调关键术语
   - B3：`**` 标记与中文字符之间无多余空格
   - B4：粗体内中文与英文/数字之间空格一致
   - B5：表格内粗体标签简洁，冒号放在粗体外
3. 自动修复发现的问题
4. 在输出中报告检查结果

### 7. 写入文档文件（必须执行）

**每次执行后必须将文档写入文件系统**，不得仅在对话中输出。

- 创建目录（如不存在）：`asdm-docs/public/docs/zh-cn/content/{target_path}/`
- 创建 `images/` 子目录（用于存放截图）
- 写入 `_index.md` 主文档
- 写入各子模块文档（如有）
- 返回写入结果

### 参数提取规则

AI 应从自然语言中智能提取以下信息：

- **模块名称**：识别"XX模块"、"XX管理"等模式
- **目标路径**：
  - 从描述中直接提取路径（如"路径 platform/modules/organization"）
  - 从模块名称推断（如"组织结构管理"→"platform/modules/organization"）
- **代码路径**：
  - 从描述中提取代码目录关键词
  - 映射到具体的代码目录结构（如"Instance 相关"→"asdm-admin/asdm-admin-web/src/pages/Projects/Modules/Instance/"）
- **子模块列表**：从"包括XX、XX、XX"等列举模式中提取
- **更新模式**：
  - "编写"/"创建"/"新建"/"为...写" → create
  - "更新"/"补充"/"改进"/"完善" → update

### 缺失参数确认

当必填参数缺失时，一次性列出缺失项向用户确认：

```
请补充以下必要信息：
1. 模块名称：请提供功能模块的中文名称
2. 代码路径：请指出该模块涉及的代码目录（如前端页面路径）
3. 文档路径：请指定文档存放路径（如 platform/modules/xxx）
```

## Related Specifications
- [specs4shared.md](../specs/specs4shared.md) - 共享规范（校验规则、路径约束、编写要点）
- [specs4docs-module-update.md](../specs/specs4docs-module-update.md) - docs-module-update 专属规范
- [Module-Doc-Template.md](../specs/templates/Module-Doc-Template.md) - 模块功能说明文档标准模板

## Output

### 模块文档输出
```json
{
  "phase": "module-docs",
  "status": "success",
  "update_mode": "create | update",
  "module_name": "string",
  "documents": [
    {
      "path": "asdm-docs/public/docs/zh-cn/content/platform/modules/xxx/_index.md",
      "type": "index"
    },
    {
      "path": "asdm-docs/public/docs/zh-cn/content/platform/modules/xxx/sub-module.md",
      "type": "sub_module"
    }
  ],
  "images_dir": "asdm-docs/public/docs/zh-cn/content/platform/modules/xxx/images/",
  "pending_screenshots": ["org-project-list.png", "org-structure.png"],
  "timestamp": "ISO 8601 datetime"
}
```

- `phase`：固定为 "module-docs"（模块文档阶段）
- `update_mode`：区分 "create"（新建）和 "update"（更新现有）
- `documents`：写入的文档文件列表，包含路径和类型（index/sub_module）
- `images_dir`：截图存放目录路径
- `pending_screenshots`：需要后续补充的截图文件名列表
