# specs4asdm-feature-progress

本文档定义了 `asdm-feature-progress` action 的专属规范，补充共享规范中的通用规则。

## 分支检查规则

### scope=release_only（默认）

1. **仅检查 releases/* 分支**
   - 检查 `releases/release-*` 格式的分支
   - 不检查 main、origin/main、feat/*、dt/* 等分支
   - 不展示其他分支的实现情况

2. **releases 分支识别**
   - 本地仓库：`git branch` 中以 `releases/` 开头的分支
   - 远程仓库：`git branch -r` 中以 `origin/releases/` 开头的分支
   - 子模块：检查 `.git` 文件确认是否为 submodule，切换到对应目录检查

3. **跨仓库检查**
   - asdm-admin、asdm-agentorbit、asdm-cli 等作为独立仓库检查
   - 每个仓库单独记录 release 分支的实现状态
   - 在汇总章节标注"该仓库无 release 分支"

### scope=all

1. **检查所有相关分支**
   - releases/* 分支：标记为"已发布"
   - main/master：标记为"主开发分支"
   - feat/* 分支：标记为"开发中"，注明最新提交
   - dt/* 分支：按要求忽略

2. **分支优先级**
   - releases/* > main > feat/* > 其他

## 代码扫描规则

### 扫描优先级

1. **高优先级扫描**（DoD 标记为 ✅ 或 🟡 的功能）
   - 必须执行 code-explorer 扫描
   - 扫描结果作为 DoD 状态判断的唯一依据
   - 记录扫描的具体文件路径和代码片段

2. **中优先级扫描**（DoD 标记为 ❌ 的功能）
   - 验证该功能确实不存在
   - 检查是否有相关的基础设施（如数据库表结构、服务框架）
   - 扫描可能的替代实现

### 扫描结果记录

每个检查项必须记录：
```
检查项：2.1.1 存储分层策略
代码扫描：
- 文件：asdm-admin/.../entity/repo/AssetRepository.java
- 发现：asset_repositories 表存在，但 storage_type 字段缺失
- 文件：deploy/mysql/migrations/V1.1.4__Auth_registration_switch.sql
- 发现：asset_registry_info 表已创建，支持 registry_level 字段
结论：🟡 部分完成 - 当前所有层级均使用 Git 存储
```

## 进展报告输出规则

### 报告路径

进展报告必须保存到：
```
docs/planning/Feat/FT-XXX-{name}/FT-XXX-{name}-特性实现进展报告.md
```

**模板位置**：`specs/templates/Progress-Report-Template.md`

**文件名格式**：`FT-XXX-{name}-特性实现进展报告.md`
- `{name}` 应使用中文特性名称，与文件夹名一致
- 不包含 "Feature.md" 后缀

### 报告更新规则

当 `update_doc=true` 时：

1. **更新时间戳**
   - 更新"检查时间"为当前时间
   - 在报告末尾添加"最后更新"脚注

2. **保留历史记录**
   - 不删除之前检查的结果
   - 在 DoD 表格中保留历史状态（如有）
   - 添加"历史检查记录"章节

3. **仅更新变更**
   - 仅更新实际发生变化的章节
   - 保持报告结构稳定
   - 标注"本报告由 asdm-feature-progress action 自动生成"

## DoD 检查表格式

### 标准表格格式

```markdown
| 编号 | 完成点 | 规划说明 | 状态 | 当前实现状态 |
|:----:|--------|----------|:----:|--------------|
| 2.1.1 | 存储分层策略 | 服务器级资源使用 Git 存储... | 🟡 | 当前所有层级均使用 Git 存储... |
```

### 状态列说明

| 状态 | Emoji | 说明 |
|:----:|:-----:|------|
| 已完成 | ✅ | 代码扫描确认功能完整存在 |
| 部分完成 | 🟡 | 代码扫描确认部分功能存在 |
| 待实现 | ❌ | 代码扫描确认功能不存在 |

### 汇总表格式

```markdown
| 类别 | 完成项 | 部分完成项 | 待实现项 | 完成率 |
|------|:------:|:---------:|:--------:|:------:|
| 核心功能 | 0 | 4 | 2 | 33% |
| 数据一致性 | 1 | 1 | 2 | 25% |
| **总计** | **2** | **11** | **9** | **17%** |
```

## 错误处理

### 找不到特性文档

1. 检查 `docs/planning/Feat/` 目录下是否存在对应特性文件夹
2. 若不存在，返回错误：
   ```json
   {
     "status": "error",
     "error": "feature_not_found",
     "feature_id": "FT-XXX",
     "message": "特性文档不存在，请先使用 /plan-feature 创建特性文档"
   }
   ```

### 找不到 release 分支

1. 检查 `git branch -a` 中是否存在 releases/* 分支
2. 若不存在，返回警告：
   ```
   ⚠️ 警告：未找到 releases/* 分支
   - 当前仅有 main 分支
   - 建议：按 release_only 模式检查 main 分支实现情况
   ```
3. 询问用户是否继续检查 main 分支

### 代码扫描失败

1. 记录扫描失败的目录和错误信息
2. 在报告中标注：
   ```
   ⚠️ 代码扫描失败
   - 目录：xxx
   - 错误：xxx
   - 影响：无法验证以下 DoD 检查项...
   ```
3. 跳过无法扫描的检查项，继续执行其他检查
4. 返回 partial_success 状态

## 与其他 Action 的关系

### 与 plan-feature

- plan-feature 创建特性文档后，asdm-feature-progress 可用于检查初始实现状态
- 检查结果可作为 plan-feature 后续更新的输入

### 与 review-spec

- review-spec 审查特性文档的完整性和一致性
- asdm-feature-progress 检查特性文档的代码实现情况
- 两者可结合使用：先 review-spec 审查文档，再 asdm-feature-progress 检查实现

### 执行顺序建议

1. 新建特性 → 先执行 review-spec 确认文档完整
2. 开发过程中 → 定期执行 asdm-feature-progress 更新进展
3. 发布前 → 执行 review-spec 确认文档与实现一致

## 路径约束

### 根路径

所有路径相对于工作区根目录：
```
/home/azureuser/source/asdm-product-management/
```

### 特性文档路径

```
docs/planning/Feat/FT-XXX-{name}/
```

### 进展报告路径

```
docs/planning/Feat/FT-XXX-{name}/FT-XXX-{name}-特性实现进展报告.md
```

### 代码路径（asdm-admin 示例）

```
asdm-admin/
├── asdm-admin-services/
│   └── asdm-admin-services-core/
│       └── src/main/java/ai/asdm/admin/core/
│           ├── entity/
│           ├── service/
│           ├── controller/
│           └── dto/
├── deploy/mysql/migrations/
└── web/src/
```

## 校验规则

### 特性编号格式

- 必须匹配 `FT-\d{3}` 格式
- 如 FT-003、FT-040、FT-099

### 分支名称格式

- releases/*：`releases/release-r03`
- feat/*：`feat/hechenxu/asset-project`
- 不接受 dt/* 分支

### 完成度计算

```
完成度 = (已完成项 × 1.0 + 部分完成项 × 0.5) / 总项数 × 100%
```

四舍五入到整数。

## 代码清单规范

### 文件清单要求

**代码清单应按 DoD 验收点逐一列出**，每个验收点单独列出一个文件清单表格。

#### 表格格式

| 数据列 | 说明 |
|--------|------|
| **文件名** | 仅显示文件名（不含路径），节省显示空间 |
| **链接** | Markdown 相对路径链接，点击可跳转至代码文件 |

#### 链接格式要求

- 使用相对路径链接，格式：`[查看代码](../../../../asdm-admin/...)`
- 路径计算：以 `docs/planning/Feat/FT-XXX/进展报告.md` 为基准
- asdm-admin 子模块路径结构：
  - 后端：`asdm-admin/asdm-admin-services/asdm-admin-services-core/src/main/java/ai/asdm/admin/core/...`
  - 数据库迁移：`asdm-admin/deploy/mysql/migrations/...`
  - 前端：`asdm-admin/asdm-admin-web/src/...`
  - 国际化：`asdm-admin/asdm-admin-web/src/i18n/locales/{lang}/...`

### 路径验证要求

**重要**：在列出文件路径之前，必须使用路径验证工具验证文件路径的正确性。

#### 验证工具

使用 `asdm-planner/tools/path-validator` 工具进行路径验证：

```bash
# 进入路径验证工具目录
cd /home/azureuser/source/asdm-product-management/.asdm/toolsets/asdm-planner/tools/path-validator

# 验证单个文件路径
python main.py --validate /home/azureuser/source/asdm-product-management/asdm-admin/asdm-admin-services/asdm-admin-services-core/src/main/java/ai/asdm/admin/core/controller/auth/PersonalAccessTokenController.java

# 验证并生成 Markdown 链接
python main.py --validate-and-link /home/azureuser/source/asdm-product-management/asdm-admin/asdm-admin-services/asdm-admin-services-core/src/main/java/ai/asdm/admin/core/controller/auth/PersonalAccessTokenController.java
```

#### 批量验证

创建配置文件 `files.json`：

```json
{
  "files": [
    "asdm-admin/asdm-admin-services/asdm-admin-services-core/src/main/java/ai/asdm/admin/core/controller/auth/PersonalAccessTokenController.java",
    "asdm-admin/asdm-admin-services/asdm-admin-services-core/src/main/java/ai/asdm/admin/core/service/auth/PersonalAccessTokenService.java",
    "asdm-admin/deploy/mysql/migrations/V1.1.2__Personal_Access_Tokens.sql"
  ]
}
```

然后运行：
```bash
python main.py --batch files.json
```

#### 确认路径正确性后生成链接

- 仅在文件存在且路径正确时才生成链接
- 对于不存在的文件，标注为"文件不存在"而非生成无效链接

### 代码清单示例

```markdown
### 3.1 核心功能验收点

| 文件名 | 链接 |
|-------|------|
| `PersonalAccessTokenController.java` | [查看代码](../../../../asdm-admin/asdm-admin-services/asdm-admin-services-core/src/main/java/ai/asdm/admin/core/controller/auth/PersonalAccessTokenController.java) |
| `PersonalAccessTokenService.java` | [查看代码](../../../../asdm-admin/asdm-admin-services/asdm-admin-services-core/src/main/java/ai/asdm/admin/core/service/auth/PersonalAccessTokenService.java) |
| `V1.1.2__Personal_Access_Tokens.sql` | [查看代码](../../../../asdm-admin/deploy/mysql/migrations/V1.1.2__Personal_Access_Tokens.sql) |
| `UserPatTab.tsx` | [查看代码](../../../../asdm-admin/asdm-admin-web/src/pages/Projects/Modules/Settings/UserPatTab.tsx) |

### 3.2 安全要求验收点

| 文件名 | 链接 |
|-------|------|
| `PersonalAccessTokenEntity.java` | [查看代码](../../../../asdm-admin/asdm-admin-services/asdm-admin-services-core/src/main/java/ai/asdm/admin/core/entity/auth/PersonalAccessTokenEntity.java) |
| `PatPlaintextModal.tsx` | [查看代码](../../../../asdm-admin/asdm-admin-web/src/pages/Projects/Modules/Settings/PatPlaintextModal.tsx) |
```

### DoD 分类与代码清单对应

每个 DoD 分类应有对应的代码清单：

| DoD 分类 | 对应代码类型 |
|----------|--------------|
| 核心功能 | Controller、Service、实体类、数据库迁移、前端组件 |
| 安全要求 | Entity、Repository、Security 配置、前端安全组件 |
| 数据一致性 | 数据库迁移脚本、Entity、DTO、Validation |
| 接口完整性 | Controller、API Client、前端 API 服务、国际化文件 |
| 待完善项 | 测试目录、配置目录（如无相关文件则标注） |
| 部署要求 | 数据库迁移脚本、配置文件 |
