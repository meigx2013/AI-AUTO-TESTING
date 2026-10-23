# Specifications for Review Spec

## Purpose
本文档定义 `review-spec` 操作的行为规范，约束特性规格审查的检查规则、评判标准和输出格式。

## Shared Specifications
共享规范（关键文档引用、数据校验规则、路径约束、可靠性规则）详见 [specs4shared.md](./specs4shared.md)。

## Architecture

### Check Pipeline
审查操作遵循 Pipeline 模式，按顺序执行代码扫描和三类检查：

```
Input → Code Context Scan → Completeness Check → Consistency Check → Traceability Check → Report
```

代码扫描结果作为所有检查的事实依据，每类检查独立执行，结果汇总后输出审查报告。

### Check Scopes

| 检查项 | 范围 | 关注点 |
|--------|------|--------|
| Code Context Scan | 代码库 | 扫描实际代码，为审查提供事实依据 |
| Completeness | 文档内部 | 文档是否包含所有必需章节和内容 |
| Consistency | 文档与代码/规划 | 文档内容是否与代码实现和规划文档一致 |
| Traceability | 文档到系统 | 文档是否可追溯到系统中的模块和特性 |

### Code Context Scanning (Required)

**审查前必须使用 code-explorer 对相关代码进行扫描**，确保所有审查判断基于代码实际情况。

1. 根据特性文档中涉及的模块和功能描述，确定扫描范围
2. 扫描覆盖：
   - 特性文档中涉及的模块代码目录和文件结构
   - 文档中引用的 API 端点、Service、Controller 等实际实现状态
   - 文档中描述的数据模型、数据库表的实际定义
   - 依赖特性涉及的代码模块
   - 配置文件和环境变量
3. 扫描结果用于交叉验证：
   - 文档中的"现有代码分析"是否与实际代码一致
   - 接口设计、数据模型是否与代码实现匹配
   - 实现状态标记（✅/⚠️/❌/🔲）是否与代码实际情况吻合
4. **事实支撑原则**：所有 issue 必须引用代码扫描中的具体发现作为依据，不可仅凭文档内容做形式化判断

## Check Specifications

### Completeness Check

**目的**：确保特性文档内容完整，无遗漏

**检查项**：
1. 必需章节存在性：
   - 概述（非空，≥50 字）
   - 归属模块（有效模块编号）
   - 预期变更（≥1 条变更项）
   - 验收标准（≥1 条验收条件）
   - 依赖关系（显式声明，可为"无"）
   - 里程碑（≥1 个阶段）

2. 状态合规性：校验规则见 `specs4shared.md` Data Validation Rules

3. 代码分析一致性：文档"现有代码分析"章节的描述是否与 code-explorer 扫描结果一致

**错误分级**：
- `error`：缺失必需章节、模块编号无效
- `warning`：章节内容过短、里程碑未填目标日期

### Consistency Check

**目的**：确保特性文档与产品规划和代码实现一致

**检查项**：
1. 模块一致性：
   - 特性文档中的模块编号必须存在于 `ASDM-ProductPlanning.md`
   - 特性文档中的模块名称必须与规划文档匹配

2. 状态一致性：
   - 文档中的状态必须与特性清单中的状态一致
   - 优先级必须与特性清单中的优先级一致

3. 依赖一致性：
   - 声明的前置依赖必须存在于特性清单中
   - 被依赖的特性状态不得为"已废弃"

4. Release 一致性：
   - 目标 Release 不得早于当前活跃 Release
   - P1 特性必须有明确的目标 Release

5. 代码一致性（基于 code-explorer 扫描）：
   - 文档中的接口设计是否与代码中的实际 API 匹配
   - 文档中的数据模型是否与代码中的实际数据结构匹配

6. 文件命名一致性：
   - 特性文件名必须遵循 `FT-XXX-特性名称-Feature.md` 格式
   - 文件名与文件夹名必须保持一致（除 `-Feature.md` 后缀外完全一致）
   - 文件名中的特性编号 `FT-XXX` 必须与文件夹名中的编号一致

**错误分级**：
- `error`：模块不存在、依赖特性不存在、状态冲突、文件命名格式错误
- `warning`：P1 特性无目标 Release、依赖特性状态为规划中

### Traceability Check

**目的**：确保特性可追溯到系统中的定义

**检查项**：
1. 模块追溯：
   - 特性在 `ASDM-ProductPlanning.md` 的模块清单中有对应条目
   - 模块的二级模块中有对应的变更描述

2. 依赖追溯：
   - 前置依赖的特性编号可在特性清单中找到
   - 双向依赖关系无环路

3. API 追溯（如涉及）：
   - 新增 API 端点是否与现有模块的 API 模式一致
   - API 路径是否遵循 `/api/{module}/{resource}` 规范

4. 代码追溯（基于 code-explorer 扫描）：
   - 文档中的实现状态标记（✅/⚠️/❌/🔲）是否与代码扫描结果吻合
   - 文档声称"已实现"的功能是否在代码中确实存在

**错误分级**：
- `error`：特性不在规划文档中、依赖环路
- `warning`：API 路径不规范、模块条目缺少变更描述

## Error Categories

- `MISSING_SECTION`：缺失必需章节
- `INVALID_VALUE`：字段值不合法
- `MODULE_MISMATCH`：模块信息不一致
- `STATUS_CONFLICT`：状态信息冲突
- `DEPENDENCY_MISSING`：依赖特性不存在
- `DEPENDENCY_CYCLE`：依赖关系存在环路
- `UNTRACEABLE`：无法追溯到规划文档
- `FILENAME_MISMATCH`：文件名与文件夹名不一致
- `FILENAME_FORMAT_ERROR`：文件名格式不符合规范

## Output Format

```json
{
  "status": "success" | "error",
  "feature_id": "FT-XXX",
  "checks": {
    "completeness": {
      "passed": true | false,
      "issues": [
        {
          "severity": "error" | "warning",
          "category": "string",
          "message": "string",
          "suggestion": "string"
        }
      ]
    },
    "consistency": { "passed": true | false, "issues": [] },
    "traceability": { "passed": true | false, "issues": [] }
  },
  "summary": {
    "errors": "number",
    "warnings": "number",
    "passed": "number",
    "failed": "number"
  },
  "timestamp": "ISO 8601 datetime"
}
```
