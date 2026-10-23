# ASDM Action: Toolset Showcase Generator

## Metadata

```json
{
  "guid": "b2c3d4e5-f6a7-8b9c-0d1e-2f3a4b5c6d7e",
  "name": "asdm-toolset-showcase-generator",
  "displayName": "Toolset Showcase Generator",
  "description": "根据 toolset 目录自动生成标准化的市场价值展示文档（showcase），包含 Mermaid 流程图、logo 文件，并使用 mmdc CLI 验证所有图表语法正确性",
  "toolset": {
    "guid": "e5f6a7b8-c9d0-1e2f-3a4b5c6d7e8f",
    "id": "asdm-planner",
    "name": "ASDM Planner Toolset",
    "version": "1.0.0"
  },
  "scenario": "showcase-generation"
}
```

## Description

为 ASDM Toolset 自动生成**标准化市场价值展示文档（showcase）**。读取 toolset 源码目录中的 `manifest.json`、`README.md`、`actions/`、`specs/` 等信息，生成一份包含完整营销内容的 Markdown 文档，并附带 SVG logo 文件。所有生成的 Mermaid 图表均通过 `mmdc` CLI 工具验证。

## Usage

```
/asdm-toolset-showcase-generator <toolset-directory-path>
```

**示例**：
```
/asdm-toolset-showcase-generator .asdm/toolsets/req-analyzer
/asdm-toolset-showcase-generator .asdm/toolsets/context-builder
```

用户给出 toolset 所在的**相对或绝对目录路径**。AI 将在该目录对应的位置创建 showcase 文件和 logo 文件。

## Parameters

| 参数 | 必填 | 说明 | 示例 |
|------|:----:|------|------|
| `toolset_dir` | ✅ | Toolset 源码目录路径（含 manifest.json） | `.asdm/toolsets/req-analyzer` |
| `output_dir` | ❌ | 输出目录（默认自动推断为 `asdm-core-assets-enterprise/asdm-core-assets/docs/toolsets/<id>/`） | — |

## Process

### Phase 1: 信息收集与分析

1. **解析输入路径**
   - 接收用户给出的 `toolset_dir`
   - 规范化为绝对路径：如以 `.` 或相对路径开头，则基于 workspace root (`/home/azureuser/source/asdm-product-management`) 拼接
   - 校验目录存在且包含 `manifest.json`

2. **读取 Toolset 元数据**
   - 读取 `manifest.json`，提取以下字段：
     - `registry_id` / `name` → toolset 名称
     - `description` → 描述
     - `version` → 版本号
     - `commands` → 命令列表（key 为命令名，value 为中文说明）
     - `guid` → GUID
   - 如无 `manifest.json`，尝试从目录名推断 registry_id

3. **读取 README.md**
   - 提取：一句话定位、核心功能描述、设计哲学、使用场景

4. **扫描 Actions 目录**
   - 列出 `actions/` 下所有 `.md` 文件
   - 对每个 action 文件提取：
     - 命令名称（从文件名或 Metadata.name）
     - displayName（从 Metadata）
     - description（从 Metadata 或 Description 章节）
     - 使用流程步骤（从 Process 章节）

5. **扫描 Specs 目录（如有）**
   - 识别模板文件、规范定义
   - 提取关键业务术语和数据模型

6. **分析输出位置**
   - 默认输出到 `{workspace}/asdm-core-assets-enterprise/asdm-core-assets/docs/toolsets/{registry_id}/`
   - 如该目录已存在且有旧 showcase，提示用户是否覆盖

### Phase 2: Showcase 内容生成

基于收集到的信息，按以下**标准化章节结构**生成 showcase 文档：

#### 必需章节（必须生成）

| # | 章节标题 | 内容来源 | 说明 |
|---|---------|---------|------|
| 1 | **标题 + Logo 引用** | `registry_id` | `# {Name} - 市场价值展示` + `![{Name} Icon]({id}-icon.svg)` |
| 2 | **一句话定位** | README + description | 一段话概括 toolset 的独特价值和定位，使用 `**{Name}** —— ...` 格式 |
| 3 | **核心价值主张 - 痛点表格** | Action 分析 | 表格：痛点场景 / 传统方案困境 / {Name} 的解法（3-6 行） |
| 4 | **核心价值主张 - 核心创新点** | README + Action 分析 | 2-4 个创新点，每个包含架构图（ASCII art）或机制说明 |
| 5 | **产品特性矩阵 - 能力表** | commands + actions | 表格：能力 / 命令 / 说明 |
| 6 | **产品特性矩阵 - 设计原则** | README + specs | 3-5 条原则列表 |
| 7 | **适用场景与目标客户** | README + actions | 用户画像表 + 适用项目特征 + 典型应用场景表 |
| 8 | **竞争优势对比** | 行业常识 + toolset 特点 | 表格：维度 / 传统方案 / {Name}（5-8 行） |
| 9 | **商业价值量化** | 合理估算 | 效率提升数据（代码块格式）+ ROI 计算表 |
| 10 | **使用流程（Mermaid 流程图）** | Action 流程 | 至少 2 个 Mermaid flowchart 图 |
| 11 | **技术规格** | manifest.json | 版本 / Registry ID / GUID / 配置类型 / 命令数量等规格表 |
| 12 | **产物目录结构** | actions 输出 | ASCII 树形图展示产出物目录结构 |
| 13 | **快速体验** | commands | 安装命令 + 上手步骤（代码块格式） |
| 14 | **最佳实践建议** | README + 场景 | 什么时候用 / 协同 toolset 等 |
| 15 | **结尾 Slogan** | 定位延伸 | `*{Name} —— ...*` 斜体格式 |

#### Mermaid 流程图规则（严格遵循）

> **配色规范**：所有 Mermaid 图表**必须**遵循 `.asdm/toolsets/asdm-planner/specs/mermaid-style-spec.md` 中定义的 **浅色 Pastel 配色方案**（参考 `system-design-showcase.md`）。禁止使用深底白字的高饱和配色。

生成任何 Mermaid 图时，**必须遵守以下语法规范**（已通过 mmdc 验证确认）：

1. **subgraph 样式**：禁止使用 `style SubgraphName fill:...`（对 subgraph 无效）。必须使用：
   ```mermaid
   classDef myStyle fill:#xxx,stroke:#xxx,color:#xxx
   class SubgraphName myStyle
   ```

2. **实线标签**：`A -->|"label"| B`（正确）

3. **虚线标签**：禁止使用 `A -.>"label"| B`（解析错误）。必须使用：
   ```
   A -. label .-> B
   ```

4. **节点文本中的特殊字符**：HTML 实体转义
   - `<` → `&lt;`
   - `>` → `&gt;`
   - `|` → `&#124;`

5. **推荐图表类型**（根据 toolset 特点选择）：
   - `flowchart TB/LR` — 主流程、阶段流转
   - 子图内避免冗余 `direction TB`（外层已声明方向）

6. **配色规范**（强制遵循，详见独立 spec 文件）：
   - **必须使用浅色 Pastel 配色**：fill 用 pastel 浅色（如 `#dbeafe`、`#dcfce7`），color 用深色文字（如 `#1e3a5f`、`#14532d`）
   - **禁止深底白字**：不允许 fill 用高饱和色 + color 用 `#fff`
   - **语义化选色**：输入用蓝灰、处理用蓝色、正向用绿色、负向用红色、边界/条件用琥珀色、产出用紫色
   - **完整调色板和 classDef 模板**见 `.asdm/toolsets/asdm-planner/specs/mermaid-style-spec.md`

#### Logo 文件生成

在 showcase 同目录下生成 SVG logo：

- **文件名**：`{registry_id}-icon.svg`
- **内容要求**：
  - 简洁的图标式 SVG（viewBox="0 0 100 100"，尺寸固定为 **200x200**）
  - 使用 toolset 的主题色（从功能定位推断）
  - 包含一个简化的图形符号（代表 toolset 的核心功能域）
  - 纯色填充，无边框装饰
  - 可选同时生成 PNG 版本（`{registry_id}-icon.png`）

**SVG 模板结构**：
```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="200" height="200">
  <!-- 背景圆角方形 -->
  <rect x="10" y="10" width="80" height="80" rx="18" ry="18" fill="{theme_color}"/>
  <!-- 中心图标（根据 toolset 类型选择符号） -->
  {icon_path}
</svg>
```

**主题色参考表**：

| 功能域类型 | 主色调 | 备选色 |
|-----------|--------|--------|
| 需求/分析类 | `#d97706` (琥珀) | `#b45309` |
| 上下文/构建类 | `#0284c7` (天蓝) | `#0369a1` |
| 规划/管理类 | `#7c3aed` (紫) | `#6d28d9` |
| 文档/生成类 | `#059669` (绿) | `#047857` |
| 通用工具类 | `#2563eb` (蓝) | `#1d4ed8` |
| 设计/创意类 | `#db2777` (粉) | `#be185d` |

**图标符号参考表**：

| 功能域类型 | SVG 符号 | 说明 |
|-----------|---------|------|
| 需求/分析类 | 放大镜 `<circle>+<line>` | 分析、洞察 |
| 上下文/构建类 | 树/层级 `<rect>` 层叠 | 结构、导航 |
| 规划/管理类 | 清单/列表 `<line>` 多行 | 任务、规划 |
| 文档/生成类 | 文档 `<rect>+<line>` | 文件、输出 |
| 通用工具类 | 齿轮/扳手 `<circle>+<path>` | 工具、配置 |
| 设计/创意类 | 画笔/调色板 | 创作、设计 |

### Phase 3: Mermaid 验证

1. **提取 Mermaid 代码块**
   - 从生成的 showcase markdown 中提取所有 ```` mermaid ... ```` 代码块
   - 为每个代码块分配序号（diagram-1, diagram-2, ...）

2. **逐个验证**
   - 将每个 mermaid 代码块写入临时 `.mmd` 文件（`/tmp/mermaid-validate/{showcase-id}-diagram-N.mmd`）
   - 执行 `mmdc -i {input}.mmd -o {output}.png` 验证
   - 捕获输出和错误信息

3. **错误修复循环**

   ```
   while (有验证失败的图表) {
     a. 解析 mmdc 错误输出，定位具体行号和问题
     b. 常见错误及修复策略：
        - Parse error on line N: 检查该行的链接语法（虚线标签、特殊字符）
        - style subgraph warning: 替换为 classDef + class
        - Unexpected token: 检查引号配对、HTML 转义
     c. 在 showcase 源文中修正对应的 mermaid 代码块
     d. 重新运行 mmdc 验证
     e. 最多重试 3 次；如仍失败，报告具体错误给用户
   }
   ```

4. **验证报告**
   - 所有图表通过后，输出验证摘要：
     ```
     ✅ Mermaid 验证全部通过
     图表数量: N
     验证结果: diagram-1 ✅ / diagram-2 ✅ / ... / diagram-N ✅
     ```

### Phase 4: 文件写入与汇报

1. **写入文件**
   - Showcase: `{output_dir}/{registry_id}-showcase.md`
   - Logo SVG: `{output_dir}/{registry_id}-icon.svg`
   - Logo PNG（可选）: `{output_dir}/{registry_id}-icon.png`

2. **校验清单**（写入前检查）
   - [ ] 所有必需章节均已生成
   - [ ] 至少包含 2 个 Mermaid flowchart
   - [ ] 所有 Mermaid 图均通过 mmdc 验证
   - [ ] Logo SVG 文件存在且格式正确
   - [ ] 文档中引用的 logo 文件名与实际一致
   - [ ] 技术规格表中的版本号与 manifest.json 一致
   - [ ] 产品特性矩阵中的命令清单与 manifest.json commands 一致

3. **返回结果**

## Output

### 成功输出
```json
{
  "phase": "showcase-generation",
  "status": "success",
  "toolset_id": "string",
  "toolset_name": "string",
  "version": "string",
  "showcase_path": "asdm-core-assets-enterprise/asdm-core-assets/docs/toolsets/{id}/{id}-showcase.md",
  "logo_svg_path": "asdm-core-assets-enterprise/asdm-core-assets/docs/toolsets/{id}/{id}-icon.svg",
  "logo_png_path": "asdm-core-assets-enterprise/asdm-core-assets/docs/toolsets/{id}/{id}-icon.png",
  "mermaid_validation": {
    "total_diagrams": 3,
    "passed": 3,
    "failed": 0,
    "details": [
      {"diagram_id": "diagram-1", "title": "主流程图", "status": "pass"},
      {"diagram_id": "diagram-2", "title": "追溯链路", "status": "pass"},
      {"diagram_id": "diagram-3", "title": "详细视图", "status": "pass"}
    ]
  },
  "sections_generated": 15,
  "timestamp": "ISO 8601 datetime"
}
```

### 错误输出
```json
{
  "phase": "showcase-generation",
  "status": "error",
  "error_code": "TOOLSET_NOT_FOUND | MANIFEST_MISSING | MERMAID_VALIDATION_FAILED | WRITE_FAILED",
  "error_message": "人类可读的错误详情",
  "timestamp": "ISO 8601 datetime"
}
```

## Related Specifications
- 本 Action 依赖 `@mermaid-js/mermaid-cli`（mmdc）进行 Mermaid 语法验证
- Showcase 文档存放于 `asdm-core-assets-enterprise/asdm-core-assets/docs/toolsets/{id}/` 目录
- **Mermaid 配色规范**：`.asdm/toolsets/asdm-planner/specs/mermaid-style-spec.md`（独立可引用的样式规范）
- 参考 Showcase 模板：`asdm-core-assets-enterprise/asdm-core-assets/docs/toolsets/req-analyzer/req-analyzer-showcase.md`
- 参考 Showcase 模板：`asdm-core-assets-enterprise/asdm-core-assets/docs/toolsets/context-builder/context-builder-showcase.md`
- 参考 Showcase 模板（配色标杆）：`asdm-core-assets-enterprise/asdm-core-assets/docs/toolsets/system-design/system-design-showcase.md`

## Appendix: Showcase 章节模板速查

> 以下是各章节的精简模板，AI 生成时应参照此结构填充内容。

### 一句话定位模板
```markdown
## 一句话定位

**{Toolset Name}** —— 为{目标用户}打造的{核心能力}，让{传统痛点}从"{旧方式}"进化到"{新方式}"。
```

### 痛点表格模板
```markdown
### 🎯 解决的行业痛点

| 痛点场景 | 传统方案的困境 | {Name} 的解法 |
|---------|---------------|---------------|
| **痛点1** | 困境描述 | 解法描述 |
```

### 产品特性矩阵模板
```markdown
### ✅ 核心/N 大核心能力

| 能力 | 命令 | 说明 |
|------|------|------|
| **🎯 能力名** | `/command-name` | 能力说明 |
```

### 技术规格表模板
```markdown
## 技术规格

| 项目 | 规格 |
|------|------|
| **版本** | v{x.y.z} |
| **Registry ID** | {id}-v{x.y.z} |
| **GUID** | {guid} |
| **配置类型** | Toolset |
| **命令数量** | N 个 |
| **产出物格式** | Markdown (.md), HTML (.html), ... |
| **存储位置** | `.asdm/.../` 目录 |
| **兼容性** | 适用于任何支持 Markdown 的 AI Coding 工具 |
```

### 快速体验模板
```markdown
## 快速体验

### 安装命令

```
/asdm-toolset-install {registry_id}
```

### N步上手

```
步骤 1: {第一步标题}
  /command-{step1}
  → 结果说明

步骤 2: {第二步标题}
  /command-{step2}
  → 结果说明
...
```
```
