# 测试数据管理规范

## 概述

本规范定义了方案 v1.1 第 10 章「测试数据管理方案」的标准。核心原则：**场景间数据相关性最小，数据与脚本分离** —— 测试数据（账号、业务写入值、环境配置）独立存放于数据文件，脚本引用而非硬编码。

## 数据分类与存放

测试数据按三类分类管理，统一存放在用例文件夹下的 `data/` 目录：

```
.asdm/workspace/ui-test/<用例名称抽象>_<YYYYMMDDHHmmss>/
├── data/
│   ├── env.json              # 环境配置：URL、环境标识
│   ├── accounts.json         # 账号池：测试账号
│   └── business.json         # 业务数据：按场景组织的写入值
├── overview.md
├── <模块>-<场景简称>.sh
└── ...
```

### env.json（环境配置）

```json
{
  "envName": "dt01",
  "baseUrl": "https://platform-dt01.asdm.ai",
  "signinUrl": "https://platform-dt01.asdm.ai/signin?redirect=%2F",
  "description": "DT01 测试环境"
}
```

> `signinUrl` 为登录页地址，供登录保障模式（`ensure_login`）直接导航使用。如果登录页在根路径 `/` 渲染（无 URL 重定向），`signinUrl` 可省略，检测将依赖页面标题（`document.title` 含 "Sign"）。

### accounts.json（账号池）

```json
{
  "accounts": {
    "superAdmin": {
      "username": "super-admin@asdm.ai",
      "password": "<密码>",
      "role": "超级管理员"
    },
    "normalUser": {
      "username": "<用户名>",
      "password": "<密码>",
      "role": "普通用户"
    }
  }
}
```

> 账号为敏感信息：`accounts.json` 应加入 `.gitignore`（或仅保留不含密码的模板 `accounts.example.json` 入库），由测试人员本地维护。
>
> **凭据自动提取**：设计阶段如果 `recordings/用户与登录/` 存在登录录制文件，AI 应从录制文件的 `change` 步骤中提取实际的邮箱和密码值，预填到 `accounts.json` 中，减少人工补充工作量。

### business.json（业务数据）

按场景组织，key 为场景编号：

```json
{
  "TOKEN-001": {
    "tokenName": "auto-test-token",
    "description": "自动化测试创建的个人令牌"
  },
  "FEATURE-001": {
    "featureKey": "grayscale-flag-01"
  }
}
```

> ⚠️ **常见陷阱：连字符键名必须使用方括号访问**
>
> 场景编号（如 `TOKEN-001`、`ORG-001`）中**含有连字符**，不是合法的 JavaScript 标识符。
> 使用**点号** `data.TOKEN-001` 会被 JS 解析为减法 `data.TOKEN - 001`，结果 `NaN`。
>
> ```bash
> # ❌ 错误（点号 + 连字符 = NaN）
> TOKEN=$(node -e "...require('business.json').TOKEN-001.tokenName")
>
> # ✅ 正确（方括号语法）
> TOKEN=$(node -e "...require('business.json')['TOKEN-001'].tokenName")
>
> # ✅ 正确（Playwright 中同理）
> const token = business['TOKEN-001'].tokenName;
> ```
>
> **规则**：只要 JSON key 含**连字符**、**数字开头**或**中文**，一律使用 `data['键名']` 方括号语法。仅在 key 为纯字母/字母数字组合（如 `superAdmin`）时才可使用 `data.superAdmin` 点号语法。

### data.json（场景间变量传递）

场景间运行时产生的变量（如登录 token、创建后的订单号）仍按既有约定使用用例文件夹下的 `data.json`（见 `ui-test-design-generate-spec.md#变量保存规范`），与静态测试数据分开管理。

## 脚本引用方式

### agent-browser 脚本（.sh）

```bash
DATA_DIR="$(cd "$(dirname "$0")" && pwd)/data"

# 读取环境配置
BASE_URL=$(node -e "console.log(require('${DATA_DIR}/env.json').baseUrl)")

# 读取账号
USERNAME=$(node -e "console.log(require('${DATA_DIR}/accounts.json').accounts.superAdmin.username)")
PASSWORD=$(node -e "console.log(require('${DATA_DIR}/accounts.json').accounts.superAdmin.password)")

# 读取业务数据
TOKEN_NAME=$(node -e "console.log(require('${DATA_DIR}/business.json')['TOKEN-001'].tokenName)")

agent-browser open "${BASE_URL}/signin"
agent-browser fill '#username' "${USERNAME}"
agent-browser fill '#password' "${PASSWORD}"
```

### Playwright 脚本（.js）

```javascript
const path = require('path');
const env = require(path.join(__dirname, 'data', 'env.json'));
const accounts = require(path.join(__dirname, 'data', 'accounts.json')).accounts;
const business = require(path.join(__dirname, 'data', 'business.json'));

const { username, password } = accounts.superAdmin;

await page.goto(`${env.baseUrl}/signin`);
await page.locator('#username').fill(username);
await page.locator('#password').fill(password);
```

## 数据依赖声明

每个场景在总体文档 `overview.md` 中声明数据依赖，格式如下：

```markdown
### 数据依赖声明

| 场景编号 | 依赖数据文件 | 依赖数据项 | 前置准备 | 后置清理 |
|---------|-------------|-----------|---------|---------|
| TOKEN-001 | accounts.json, business.json | superAdmin 账号, tokenName | 无 | 删除创建的令牌 |
| LOGIN-001 | accounts.json, env.json | superAdmin 账号, baseUrl | 无 | 无 |
```

- 有条件时，前置准备与后置清理步骤应包含在脚本中（如测试完成后删除创建的数据）。
- 场景间不共享业务数据；确需共享的运行时变量走 `data.json`。

## 管理要求

- 数据文件纳入脚本库统一归档与版本管理（`accounts.json` 按上文脱敏要求处理）。
- 环境切换只需修改 `env.json`，不得修改脚本。
- 新增场景时，所需数据项补充到对应数据文件，key 命名使用 camelCase。
- 后期方向（暂缓）：数据自动构造、环境重置能力。

---

## 相关文档

- **Spec**: `ui-test-design-generate-spec.md` - 设计与脚本生成工作流规范（变量保存规范）
- **Spec**: `ui-test-agent-browser-spec.md` - agent-browser 脚本规范
- **Spec**: `ui-test-freshness-spec.md` - 保鲜工作流规范（数据问题自愈）
