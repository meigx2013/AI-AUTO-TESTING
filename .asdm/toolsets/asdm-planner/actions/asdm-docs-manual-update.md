# Docs Manual Update

## Metadata

```json
{
  "guid": "c5d6e7f8-a9b0-1c2d-3e4f-5a6b7c8d9e0f",
  "name": "asdm-docs-manual-update",
  "displayName": "Docs Manual Update",
  "description": "编写或更新 ASDM 平台的场景化操作手册，以用户旅程视角引导完成特定场景的完整操作流程",
  "toolset": {
    "guid": "e5f6a7b8-c9d0-1e2f-3a4b5c6d7e8f",
    "id": "asdm-planner",
    "name": "ASDM Planner Toolset",
    "version": "1.0.0"
  },
  "scenario": "user-manual"
}
```

## Description
编写或更新 ASDM 平台的场景化操作手册。场景化操作手册面向最终用户，以用户旅程视角引导完成特定场景的完整操作流程。支持自然语言输入，AI 自动扫描代码理解界面实现，并按照标准文档结构生成场景化操作手册。

本 action 适用于 `asdm-docs` 文档站点的场景化操作手册编写，产出文档存放于 `asdm-docs/public/docs/zh-cn/content/platform/manual/` 目录下。每个场景使用独立子目录，以 `_index.md` 作为入口文档。文档以用户视角撰写，强调操作步骤的连贯性、截图的导航引导和标准化的阅读体验。

## Usage
```
/asdm-docs-manual-update <自然语言描述>
```

用户可以用自然语言描述要编写的场景化手册信息，AI 将自动提取所需参数。如缺少必要信息，AI 会向用户询问确认。

## Parameters

所有参数均可通过自然语言输入，AI 自动提取。若必填参数缺失，AI 须向用户询问。

| 参数 | 必填 | 说明 | 示例 |
|------|:----:|------|------|
| `scenario_name` | ✅ | 场景名称（中文，简明扼要） | "用户注册和登录"、"创建组织和项目" |
| `target_path` | ✅ | 文档目标路径（相对于 manual 目录） | "user-registration-login"、"organization-project-setup" |
| `code_paths` | ✅ | 需要扫描的代码路径列表（用于理解界面实现） | "asdm-admin/asdm-admin-web/src/pages/Login/" |
| `user_role` | ❌ | 目标用户角色描述 | "新用户"、"项目管理员" |
| `prerequisites` | ❌ | 前置条件列表 | ["已拥有 ASDM 账户", "已创建组织"] |
| `next_scenario` | ❌ | 下一步场景名称和路径 | {"name": "创建组织、项目并完成必要的项目初始化", "path": "../organization-project-setup/"} |
| `update_mode` | ❌ | 更新模式：create（新建）/ update（更新现有），默认 create | create、update |

## Examples

### 自然语言输入
```
/asdm-docs-manual-update 编写用户注册和登录的场景化操作手册，代码在 asdm-admin 的 Login 相关页面
```

```
/asdm-docs-manual-update 为"创建组织和项目"场景编写操作手册，面向新用户，前置条件是已完成注册登录
```

```
/asdm-docs-manual-update 更新用户注册登录手册，补充第三方登录的截图和说明
```

```
/asdm-docs-manual-update 编写"使用工作空间完成场景执行"手册，代码在 asdm-admin 的 Workspace 相关页面
```

## Process

### 1. 解析输入

从自然语言中提取参数：
- **场景名称**：从描述中提取场景名（如"用户注册和登录"→ scenario_name="用户注册和登录"）
- **目标路径**：从描述中提取或推断文档存放路径（英文短横线格式）
- **代码路径**：从描述中提取代码位置关键词，映射到具体代码目录
- **用户角色**：从描述中提取目标用户（如"新用户"→ user_role="新用户"）
- **前置条件**：从描述中提取前置条件
- **更新模式**：语义映射（"更新"/"补充"→update，"编写"/"创建"→create）

若无法确定场景名称或代码路径，向用户询问确认。

### 2. 代码上下文扫描（必须执行）

**编写手册前必须使用 code-explorer 对相关代码进行扫描**，确保文档内容基于实际界面实现，而非凭空想象。

扫描范围：
- 场景涉及的前端页面组件（路由、页面组件、子组件）
- 相关的 API 服务调用（API client、请求方法）
- 类型定义和接口（TypeScript 类型、接口定义）
- 国际化文件（i18n，获取准确的界面文字）
- 相关的配置文件和路由定义

扫描结果用于：
- 获取准确的界面文字、按钮标签、提示信息
- 确认页面布局、交互逻辑和导航关系
- 验证操作步骤与实际界面的一致性
- 确保所有描述的操作在系统中真实存在

### 3. 检查现有文档

- 如果 `update_mode=create`：
  - 检查目标路径下是否已存在 `_index.md` 文件
  - 若存在，提示用户是否切换为 update 模式
  - 若不存在，按模板创建新文档

- 如果 `update_mode=update`：
  - 读取现有 `_index.md` 和同级文档
  - 对比代码扫描结果，识别需要补充或修正的内容
  - 保留现有文档的合理结构，仅更新需要变更的部分

### 4. 生成/更新文档

基于代码扫描结果，按 `.asdm/toolsets/asdm-planner/specs/templates/Manual-Doc-Template.md` 模板生成或更新文档。

**文档编写原则**（详见 specs4docs-manual-update.md）：
- 面向最终用户，站在用户旅程视角描述操作流程
- 场景说明使用 Mermaid 流程图展示用户旅程主要阶段
- 每个操作步骤严格依赖系统可见界面（通过代码扫描验证）
- 截图上方标注导航路径（如 `首页 ｜ 用户头像 ｜ 访问令牌`）
- 截图下方标注图例说明（如 `图 4-1：点击用户头像后的下拉菜单`）
- 使用 1. / 1.1 / 1.1.1 编号体系
- 步骤间衔接合理，确保用户可实际完成操作

### 5. 粗体格式检查（必须执行）

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

### 6. 写入文档文件（必须执行）

**每次执行后必须将文档写入文件系统**，不得仅在对话中输出。

- 创建目录（如不存在）：`asdm-docs/public/docs/zh-cn/content/platform/manual/{target_path}/`
- 创建 `images/` 子目录（用于存放截图）
- 写入 `_index.md` 主文档
- 返回写入结果

### 参数提取规则

AI 应从自然语言中智能提取以下信息：

- **场景名称**：识别"XX场景"、"XX手册"、"XX操作"等模式
- **目标路径**：
  - 从描述中直接提取路径
  - 从场景名称推断英文短横线格式（如"用户注册和登录"→"user-registration-login"）
- **代码路径**：
  - 从描述中提取代码目录关键词
  - 映射到具体的代码目录结构
- **用户角色**：识别"新用户"、"管理员"、"开发者"等角色描述
- **前置条件**：识别"完成XX后"、"需要XX"等条件描述
- **更新模式**：
  - "编写"/"创建"/"新建"/"为...写" → create
  - "更新"/"补充"/"改进"/"完善" → update

### 缺失参数确认

当必填参数缺失时，一次性列出缺失项向用户确认：

```
请补充以下必要信息：
1. 场景名称：请提供场景的中文名称
2. 代码路径：请指出该场景涉及的代码目录（如前端页面路径）
3. 文档路径：请指定文档存放路径（如 user-registration-login）
```

## Related Specifications
- [specs4shared.md](../specs/specs4shared.md) - 共享规范（校验规则、路径约束、编写要点）
- [specs4docs-manual-update.md](../specs/specs4docs-manual-update.md) - docs-manual-update 专属规范
- [Manual-Doc-Template.md](../specs/templates/Manual-Doc-Template.md) - 场景化操作手册标准模板

## Output

### 场景化操作手册输出
```json
{
  "phase": "user-manual",
  "status": "success",
  "update_mode": "create | update",
  "scenario_name": "string",
  "documents": [
    {
      "path": "asdm-docs/public/docs/zh-cn/content/platform/manual/xxx/_index.md",
      "type": "index"
    }
  ],
  "images_dir": "asdm-docs/public/docs/zh-cn/content/platform/manual/xxx/images/",
  "pending_screenshots": ["sign-in.png", "register-page.png"],
  "timestamp": "ISO 8601 datetime"
}
```

- `phase`：固定为 "user-manual"（场景化操作手册阶段）
- `update_mode`：区分 "create"（新建）和 "update"（更新现有）
- `scenario_name`：场景的中文名称
- `documents`：写入的文档文件列表，包含路径和类型
- `images_dir`：截图存放目录路径
- `pending_screenshots`：需要后续补充的截图文件名列表
