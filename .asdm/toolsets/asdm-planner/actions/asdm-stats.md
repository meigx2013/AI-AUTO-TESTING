# ASDM Stats

## Metadata

```json
{
  "guid": "f7a8b9c0-d1e2-3f4a-5b6c-7d8e9f0a1b2c",
  "name": "asdm-stats",
  "displayName": "ASDM Stats",
  "description": "统计 ASDM 产品线所有进展情况，生成代码库统计、提交频率、模块与特性数据，并以 SVG 图表形式嵌入 README.md",
  "toolset": {
    "guid": "e5f6a7b8-c9d0-1e2f-3a4b5c6d7e8f",
    "id": "asdm-planner",
    "name": "ASDM Planner Toolset",
    "version": "1.0.0"
  },
  "scenario": "stats-report"
}
```

## Description

统计 ASDM 产品线所有进展情况，生成综合统计报告并更新 `README.md`。统计数据包括：

1. **代码库数量**：扫描 workspace 下所有 git submodule 代码库
2. **代码行数统计**：各代码库的总代码行数、过去 7 天代码增量、行数最多贡献者排名（1-10）
3. **提交频繁度**：各代码库的 commit/天、过去 7 天变化情况、提交频繁度排名（1-10）
4. **产品模块数量**：从 `ASDM-ProductPlanning.md` 读取模块清单
5. **产品特性数量**：从 `ASDM-ProductPlanning.md` 读取特性清单及各状态分布

统计结果以 SVG 图表形式输出到 `assets/images/` 目录，并嵌入到 `README.md` 的统计专区。

> **⚠️ 重要：输出规范**
>
> - SVG 图表必须写入 `assets/images/` 目录
> - `README.md` 必须更新统计专区内容（含图表嵌入 + Markdown 数据表格）
> - 每个图表下方必须附带对应的 Markdown 数据表格，表格末尾必须包含**汇总行**（合计/平均值等）
> - 不得仅在对话中输出统计结果

## Usage
```
/asdm-stats
```

无需额外参数，自动扫描所有代码库和规划文档。

## Parameters

无参数。本命令自动从 workspace 和规划文档中收集所有数据。

## Process

### 1. 更新 git submodule（必须执行）

确保所有 submodule 代码最新：

```bash
cd /home/azureuser/source/asdm-product-management
git submodule foreach 'git fetch origin'
git submodule foreach 'git pull origin $(git rev-parse --abbrev-ref HEAD) || true'
git submodule status
```

若更新失败，记录警告并继续，在报告中标注"代码可能不是最新"。

### 2. 识别代码库

扫描 workspace 根目录，识别所有 git submodule 代码库。代码库列表以 `ASDM-ProductPlanning.md` 的"产品规划范围"表为准：

| 代码库 | 说明 |
|--------|------|
| `asdm-admin` | 后端（Spring Boot）+ 前端（React） |
| `asdm-agentorbit` | AI Agent 编排与管理平台 |
| `asdm-cert` | 证书与认证服务 |
| `asdm-cli` | ASDM 命令行工具 |
| `asdm-core-assets` | 核心资产库 |
| `asdm-core-assets-enterprise` | 企业级核心资产库 |
| `asdm-docs` | ASDM 文档站点 |
| `asdm-mcp-server` | ASDM MCP 服务器 |
| `asdm-official-website` | 官方网站 |

> 如 workspace 中缺少某些代码库目录，在统计中标注为"未检出"。

### 3. 代码行数统计

对每个代码库执行代码行数统计：

#### 3.1 总代码行数

使用 `cloc` 工具统计每个代码库的代码行数（按语言分类）：

```bash
cloc --json /home/azureuser/source/asdm-product-management/<repo> --exclude-dir=node_modules,.git,target,dist,build,.next,out,coverage
```

若 `cloc` 不可用，使用 `git ls-files` + `wc -l` 作为后备：

```bash
cd /home/azureuser/source/asdm-product-management/<repo>
git ls-files | grep -E '\.(java|ts|tsx|js|jsx|py|sql|xml|json|yaml|yml|md|html|css|scss|sh)$' | xargs wc -l 2>/dev/null | tail -1
```

#### 3.2 过去 7 天代码增量

```bash
cd /home/azureuser/source/asdm-product-management/<repo>
git log --since="7 days ago" --pretty=tformat: --numstat | awk '{ add += $1; subs += $2 } END { printf "added:%d removed:%d net:%d\n", add, subs, add-subs }'
```

#### 3.3 贡献者排名（按行数）

```bash
cd /home/azureuser/source/asdm-product-management/<repo>
git log --format='%aN' | sort | uniq -c | sort -rn | head -10
```

### 4. 提交频繁度统计

#### 4.1 整体提交频率（commit/天）

```bash
cd /home/azureuser/source/asdm-product-management/<repo>
# 总 commit 数
total_commits=$(git rev-list --count HEAD)
# 仓库天数
first_commit_date=$(git log --reverse --format='%ad' --date=short | head -1)
days=$(( ( $(date +%s) - $(date -j -f "%Y-%m-%d" "$first_commit_date" +%s) ) / 86400 ))
echo "commits_per_day=$(echo "scale=2; $total_commits / $days" | bc)"
```

#### 4.2 过去 7 天提交频率

```bash
cd /home/azureuser/source/asdm-product-management/<repo>
commits_7d=$(git rev-list --count --since="7 days ago" HEAD)
echo "commits_per_day_7d=$(echo "scale=2; $commits_7d / 7" | bc)"
```

#### 4.3 提交频繁度排名

按过去 7 天的 commit/天对所有代码库排名（1-10）。

### 5. 产品模块与特性统计

#### 5.1 模块数量

读取 `docs/planning/ASDM-ProductPlanning.md` 中功能模块表，统计模块数量。模块编号从 1 到 N，当前共 15 个模块。

#### 5.2 特性数量与状态分布

从 `ASDM-ProductPlanning.md` 的特性清单中统计：

- 总特性数量
- 各状态分布：
  - 🔵 规划中
  - 🟣 澄清中
  - 🟠 设计中
  - 🟢 概要设计完成
  - 🟩 详细设计完成
  - 🟡 实现中
  - ✅ 已实现
  - ❌ 已废弃

### 6. 生成 SVG 图表

将统计数据生成为 SVG 图表，写入 `assets/images/` 目录。需生成的图表：

#### 6.1 代码行数分布图

- **文件名**：`assets/images/stats-code-lines.svg`
- **图表类型**：水平条形图
- **数据**：各代码库的代码总行数，按行数降序排列
- **配色**：使用渐变色区分不同代码库
- **宽度**：800px，高度：自适应（每个条目 40px）

#### 6.2 过去 7 天代码增量图

- **文件名**：`assets/images/stats-code-delta-7d.svg`
- **图表类型**：水平条形图（正负双向）
- **数据**：各代码库过去 7 天的 net 增减行数
- **配色**：增量为绿色，减量为红色

#### 6.3 贡献者排名图

- **文件名**：`assets/images/stats-top-contributors.svg`
- **图表类型**：水平条形图
- **数据**：所有代码库合并后的 Top 10 贡献者（按 commit 数排名）
- **宽度**：800px，高度：440px

#### 6.4 提交频繁度排名图

- **文件名**：`assets/images/stats-commit-frequency.svg`
- **图表类型**：水平条形图
- **数据**：各代码库过去 7 天的 commit/天，降序排列
- **配色**：使用渐变色

#### 6.5 特性状态分布图

- **文件名**：`assets/images/stats-feature-status.svg`
- **图表类型**：环形图（Donut Chart）
- **数据**：各状态的特性数量占比
- **配色**：
  - 🔵 规划中 → `#4A90D9`
  - 🟣 澄清中 → `#9B59B6`
  - 🟠 设计中 → `#E67E22`
  - 🟢 概要设计完成 → `#2ECC71`
  - 🟩 详细设计完成 → `#27AE60`
  - 🟡 实现中 → `#F1C40F`
  - ✅ 已实现 → `#2ECC71`
  - ❌ 已废弃 → `#95A5A6`
- **中心**：显示总特性数量
- **宽度**：500px，高度：400px

#### SVG 生成规范

- 使用纯 SVG 1.1 标准，不依赖外部字体或 JS
- 嵌入中文字体声明：`font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", "PingFang SC", "Microsoft YaHei", sans-serif`
- 每个图表顶部包含标题，底部包含生成时间戳
- 图表背景色：`#FAFAFA`，边框：`#E0E0E0`，圆角：8px
- 使用 `write_to_file` 工具将 SVG 文件写入指定路径

### 7. 更新 README.md

在 `README.md` 中更新统计专区。统计专区位于"🚀 快速开始"章节之前，包含：

#### 7.1 统计专区结构

```markdown
## 📊 产品线统计

> 最后更新：{YYYY-MM-DD HH:mm}

### 总览

| 指标 | 数值 |
|------|------|
| 代码库数量 | {N} |
| 产品模块数量 | {N} |
| 产品特性总数 | {N} |
| 已实现特性 | {N} ({Pct}%) |

### 代码规模

![代码行数分布](assets/images/stats-code-lines.svg)

| 代码库 | 总行数 |
|--------|--------:|
| asdm-admin | {N} |
| ... | ... |
| **合计 / 平均** | **{total} / {avg}** |

### 开发活跃度

![过去 7 天代码增量](assets/images/stats-code-delta-7d.svg)

| 代码库 | 新增行 | 删除行 | 净增行 |
|--------|-------:|-------:|-------:|
| asdm-admin | {N} | {N} | {+/-N} |
| ... | ... | ... | ... |
| **合计 / 平均** | **{total}/{avg}** | **{total}/{avg}** | **{+/-total}/{avg}** |

![提交频繁度排名](assets/images/stats-commit-frequency.svg)

| 代码库 | 总提交数 | 7天提交数 | commit/天(7天) |
|--------|--------:|----------:|---------------:|
| asdm-admin | {N} | {N} | {N} |
| ... | ... | ... | ... |
| **合计 / 平均** | **{total}/{avg}** | **{total}/{avg}** | **{avg}** |

![Top 贡献者](assets/images/stats-top-contributors.svg)

| 排名 | 贡献者 | 提交数 |
|:----:|--------|-------:|
| 1 | {name} | {N} |
| ... | ... | ... |
| **Top10 合计 / 平均** | | **{total} / {avg}** |

### 特性进展

![特性状态分布](assets/images/stats-feature-status.svg)

| 状态 | 数量 | 占比 |
|------|-----:|-----:|
| 🔵 规划中 | {N} | {Pct}% |
| 🟣 澄清中 | {N} | {Pct}% |
| 🟠 设计中 | {N} | {Pct}% |
| 🟢 概要设计完成 | {N} | {Pct}% |
| 🟩 详细设计完成 | {N} | {Pct}% |
| 🟡 实现中 | {N} | {Pct}% |
| ✅ 已实现 | {N} | {Pct}% |
| ❌ 已废弃 | {N} | {Pct}% |
| **合计** | **{N}** | **100%** |
```

#### 7.2 Markdown 数据表格规范

每个 SVG 图表下方必须附带对应的 Markdown 数据表格，遵循以下规范：

1. **必须包含表格**：每个图表对应一张数据表格，不得省略
2. **汇总行**：每个表格末尾必须包含汇总行（加粗），格式为 `**合计 / 平均**` 或 `**合计**`
   - 代码规模表：`**合计 / 平均**`（总行数合计 + 平均行数）
   - 7天增量表：`**合计 / 平均**`（新增/删除/净增各列合计与平均）
   - 提交频繁度表：`**合计 / 平均**`（总提交合计/平均、7天提交合计/平均、commit/天平均值）
   - 贡献者排名表：`**Top10 合计 / 平均**`（Top10 提交数合计与平均）
   - 特性状态表：`**合计**`（特性总数，占比 100%）
3. **完整状态**：特性状态表必须列出全部 8 种状态（含数量为 0 的状态），确保状态覆盖完整
4. **数字格式**：使用千分位分隔符（如 `197,939`），净增行用 `+/-` 前缀标识方向
5. **表格对齐**：数值列使用右对齐 (`---:`)

#### 7.3 更新规则

- 若 `README.md` 中已存在 `## 📊 产品线统计` 章节，替换该章节内容（从 `## 📊 产品线统计` 到下一个 `## ` 级别标题之前）
- 若不存在，在 `## 🚀 快速开始` 章节之前插入统计专区
- 更新 README.md 底部的"最后更新"时间戳为当前时间

### 8. 输出结果

返回结构化的统计结果。

## Output

### 统计输出
```json
{
  "phase": "stats",
  "scenario": "product-stats",
  "status": "success",
  "repos": {
    "count": 9,
    "details": [
      {
        "name": "asdm-admin",
        "total_lines": 0,
        "delta_7d": { "added": 0, "removed": 0, "net": 0 },
        "total_commits": 0,
        "commits_7d": 0,
        "commits_per_day_7d": 0,
        "top_contributors": [
          { "name": "string", "commits": 0 }
        ]
      }
    ],
    "summary": {
      "total_lines": 0,
      "avg_lines": 0,
      "total_commits": 0,
      "total_commits_7d": 0,
      "avg_commits_per_day_7d": 0
    }
  },
  "contributors": {
    "top10": [
      { "rank": 1, "name": "string", "commits": 0 }
    ],
    "top10_total": 0,
    "top10_avg": 0
  },
  "modules": {
    "count": 15
  },
  "features": {
    "total": 0,
    "by_status": {
      "规划中": 0,
      "澄清中": 0,
      "设计中": 0,
      "概要设计完成": 0,
      "详细设计完成": 0,
      "实现中": 0,
      "已实现": 0,
      "已废弃": 0
    }
  },
  "charts": [
    "assets/images/stats-code-lines.svg",
    "assets/images/stats-code-delta-7d.svg",
    "assets/images/stats-top-contributors.svg",
    "assets/images/stats-commit-frequency.svg",
    "assets/images/stats-feature-status.svg"
  ],
  "readme_updated": true,
  "timestamp": "ISO 8601 datetime"
}
```

- `repos.count`：代码库总数
- `repos.details`：每个代码库的详细统计（含 `delta_7d` 的 added/removed/net 明细）
- `repos.summary`：代码库汇总（总行数、平均行数、总提交数、7天总提交、平均 commit/天）
- `contributors.top10`：Top 10 贡献者排名
- `contributors.top10_total` / `top10_avg`：Top10 提交数合计与平均
- `modules.count`：产品模块数量
- `features.total`：特性总数
- `features.by_status`：各状态的特性数量（含全部 8 种状态，即使为 0 也必须列出）
- `charts`：生成的 SVG 图表文件路径列表
- `readme_updated`：README.md 是否已更新
