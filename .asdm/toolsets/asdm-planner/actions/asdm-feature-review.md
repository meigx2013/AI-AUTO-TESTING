# Review Spec

## Metadata

```json
{
  "guid": "b0c1d2e3-f4a5-6b7c-8d9e-0f1a2b3c4d5e",
  "name": "asdm-feature-review",
  "displayName": "Review Spec",
  "description": "审查 ASDM 特性规格文档，检查完整性、一致性和可追溯性",
  "toolset": {
    "guid": "e5f6a7b8-c9d0-1e2f-3a4b5c6d7e8f",
    "id": "asdm-planner",
    "name": "ASDM Planner Toolset",
    "version": "1.0.0"
  },
  "scenario": "spec-review"
}
```

## Description
审查 ASDM 特性规格文档，检查完整性、一致性和可追溯性。支持自然语言输入，自动识别审查目标。

## Usage
```
/asdm-feature-review <自然语言描述>
```

用户可以用自然语言描述审查目标，AI 自动提取所需参数。如缺少必要信息，AI 会向用户询问确认。

## Parameters

所有参数均可通过自然语言输入，AI 自动提取。若必填参数缺失，AI 须向用户询问。

| 参数 | 必填 | 说明 | 示例 |
|------|:----:|------|------|
| `id` | ✅ | 特性编号（与 `path` 二选一） | FT-003、FT-026 |
| `path` | ✅ | 特性文档目录路径（与 `id` 二选一） | docs/planning/Feat/FT-019-数据上报API/ |
| `check` | ❌ | 检查项：completeness / consistency / traceability / all（默认：all） | all、completeness |
| `strict` | ❌ | 严格模式，将 warning 也视为 error（默认：false） | true |

## Examples

### 自然语言输入
```
/asdm-feature-review 审查 FT-003 的特性文档
```

```
/asdm-feature-review 帮我检查一下数据上报API那个特性的完整性
```

```
/asdm-feature-review 严格审查 FT-026，看它和产品规划是否一致
```

```
/asdm-feature-review 审查 FT-038 的一致性和可追溯性
```

## Process

### 1. 解析输入

从自然语言中提取参数：
- **特性编号**：匹配 `FT-\d{3}` 格式
- **特性名称**：模糊匹配（如"数据上报API"→FT-019），需在 `ASDM-ProductPlanning.md` 中查找确认
- **检查项**：语义映射（"完整性"→completeness，"一致性"→consistency，"可追溯性"→traceability，"全部/全面"→all）
- **严格模式**：语义映射（"严格"→strict=true）

若无法确定审查目标（既无编号也无明确的特性名称），向用户询问确认。

### 2. 执行审查

基于文档内容，按 Pipeline 执行三类检查（completeness / consistency / traceability，详见 Check Items）及粗体格式检查。

### 3. 粗体格式检查

逐项检查粗体格式，规则如下：
  - B1：粗体内不含句末标点（句号、问号、叹号等）
  - B2：粗体不包裹完整长句（仅标注关键词或短语）
  - B3：粗体标记前后无多余空格
  - B4：粗体不与行内代码标记混用
  - B5：粗体不跨越列表项或段落
将发现的问题纳入审查报告。

### 4. 输出报告

生成审查报告，所有 issue 应引用文档中的具体位置作为依据。

## Check Items

### Completeness（完整性）
- 特性描述是否完整
- 是否明确归属模块和预期变更
- 是否包含验收标准
- 是否定义了边界条件
- **修订记录**：检查是否包含修订记录表格，格式要求：
  - 位置：文档开头（目录之前）
  - 表头：`| 版本 | 日期 | 修订人 | 修订内容 |`
  - 版本号格式：`X.X.X`（如 1.0.0、1.0.1）
  - 日期格式：`YYYY-MM-DD`
  - 新版本记录在表格顶部（最新在前）
- **目录**：检查是否包含目录章节，且：
  - 目录中的章节标题必须与实际章节标题完全一致
  - 目录顺序必须与实际章节顺序一致（章节号按文档内实际编号排列）
- **章节编号**：章节标题必须使用阿拉伯数字（如 `## 1 功能概述`），**禁止使用中文数字**（如 `## 一、`），确保目录锚点链接正常工作

### Consistency（一致性）
- 特性描述与模块定义是否一致
- 优先级与 Release 规划是否匹配
- 依赖关系是否可追溯
- 状态流转是否符合生命周期规则
- **文档目录结构**：检查目录名与文件名是否一致
  - 目录：`docs/planning/Feat/FT-XXX-{特性名称}/`
  - Feature 文件：`FT-XXX-{特性名称}-Feature.md`
  - 进展报告：`FT-XXX-{特性名称}-特性实现进展报告.md`
- **引用检查**：检查其他文档对该特性的引用路径是否正确（应指向 `Feature.md`，不应引用不存在的文件如 `Planning.md`）

### Traceability（可追溯性）
- 是否可追溯到产品规划文档中的模块条目
- 依赖的特性是否已存在且状态可满足
- API 设计是否与现有模块接口一致

## Parameter Extraction Rules

AI 应从自然语言中智能提取以下信息：

- **特性编号**：匹配 `FT-\d{3}` 格式
- **特性名称**：关键词匹配 `ASDM-ProductPlanning.md` 特性清单
- **检查项**：
  - "完整性" / "是否完整" → completeness
  - "一致性" / "是否一致" / "是否匹配" → consistency
  - "可追溯性" / "能否追溯" / "关联性" → traceability
  - "全部" / "全面" / "整体" / "所有" → all
- **严格模式**："严格" / "严格模式" → strict=true

### 缺失参数确认

当必填参数缺失时，一次性列出缺失项向用户确认：

```
请指定审查目标：
1. 特性编号：如 FT-003、FT-026
2. 或文档路径：如 docs/planning/Feat/FT-019-数据上报API/
```

## Output

### 审查完成输出
```json
{
  "phase": "review",
  "status": "success",
  "feature_id": "FT-XXX",
  "feature_name": "string",
  "checks": {
    "completeness": { "passed": true, "issues": [] },
    "consistency": { "passed": false, "issues": ["Issue description"] },
    "traceability": { "passed": true, "issues": [] }
  },
  "summary": {
    "errors": 0,
    "warnings": 2,
    "passed": 2,
    "failed": 1
  },
  "bold_format_issues": [],
  "timestamp": "ISO 8601 datetime"
}
```

- `phase`：固定为 "review"（审查阶段）
- `checks`：三类检查（completeness/consistency/traceability）的通过情况和 issue 列表
- `summary`：汇总统计，`strict=true` 时 warning 也计入 failed
- `bold_format_issues`：粗体格式检查（B1-B5）发现的问题列表（如有）
