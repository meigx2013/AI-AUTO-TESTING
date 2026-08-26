# UI 测试脚本代码规范

## 概述

本规范定义了 UI 自动化测试脚本的代码编写标准。测试脚本由 `/asdm-ui-test-design-generate` action 根据测试用例文档自动生成，遵循 Page Object Model（POM）设计模式。

> **说明（方案 v1.1）**：本工具集的主产物为 agent-browser 脚本（`.sh`，规范见 `ui-test-agent-browser-spec.md`），Playwright 脚本为**降级产物**。以下 POM 规范适用于需要框架化组织的场景；单场景独立脚本可参考 `ui-test-design-generate-spec.md#脚本模板`。

## 约束（方案 v1.1）

- **断言不丢失**：录制 json 中的断言步骤必须全部转换为脚本断言，不得丢弃。
- **数据与脚本分离**：账号、URL、业务值从用例文件夹下 `data/` 数据文件读取（`env.json` / `accounts.json` / `business.json`），禁止硬编码，见 `ui-test-data-spec.md`。

## 项目结构

### Playwright + TypeScript（推荐）

```
test-scripts/
├── playwright.config.ts          # Playwright 配置文件
├── package.json                  # Node.js 依赖
├── tsconfig.json                 # TypeScript 配置
├── pages/                        # Page Object 页面对象
│   ├── base.page.ts              # 基础页面类（公共方法）
│   ├── login.page.ts             # 登录页
│   ├── dashboard.page.ts         # 仪表盘页
│   └── ...
├── tests/                        # 测试用例脚本
│   ├── login.spec.ts
│   ├── dashboard.spec.ts
│   └── ...
├── fixtures/                     # 测试 fixture / 数据
│   ├── test-data.ts
│   └── auth.setup.ts
└── utils/                        # 工具函数
    ├── helpers.ts
    └── reporters.ts
```

### Selenium + Python

```
test-scripts/
├── conftest.py                   # pytest 配置和 fixture
├── pytest.ini                    # pytest 配置文件
├── requirements.txt              # Python 依赖
├── pages/                        # Page Object 页面对象
│   ├── base_page.py
│   ├── login_page.py
│   └── ...
├── tests/                        # 测试用例脚本
│   ├── test_login.py
│   └── ...
├── data/                         # 测试数据
│   └── test_data.py
└── utils/                        # 工具函数
    ├── driver_factory.py
    └── helpers.py
```

## Page Object 模板

### Playwright TypeScript

```typescript
// pages/<PageName>.page.ts
import { Page, Locator, expect } from '@playwright/test';

/**
 * <页面名称> Page Object
 * 封装页面元素定位和操作方法
 */
export class <PageName>Page {
  readonly page: Page;

  // ==================== 定位器 ====================
  // 遵循优先级：data-testid > role/text > css > xpath
  readonly pageTitle: Locator;
  readonly submitButton: Locator;
  readonly errorMessage: Locator;

  // ==================== 页面URL ====================
  static readonly URL = '/<page-path>';

  constructor(page: Page) {
    this.page = page;

    // 初始化所有定位器
    this.pageTitle = page.locator('[data-testid="page-title"]');
    this.submitButton = page.getByRole('button', { name: '提交' });
    this.errorMessage = page.locator('.error-message');
  }

  // ==================== 导航方法 ====================

  /**
   * 导航到当前页面
   */
  async goto(): Promise<void> {
    await this.page.goto(<PageName>Page.URL);
    await this.waitForPageLoad();
  }

  // ==================== 操作方法 ====================

  /**
   * <操作方法描述>
   * @param param 参数说明
   */
  async <actionName>(param: string): Promise<void> {
    await this.<element>.fill(param);
    await this.<element>.click();
  }

  // ==================== 断言方法 ====================

  /**
   * 验证页面已正确加载
   */
  async expectPageLoaded(): Promise<void> {
    await expect(this.pageTitle).toBeVisible();
    await expect(this.page).toHaveURL(<PageName>Page.URL);
  }

  // ==================== 私有方法 ====================

  /**
   * 等待页面加载完成
   */
  private async waitForPageLoad(): Promise<void> {
    await this.page.waitForLoadState('networkidle');
  }
}
```

### Selenium Python

```python
# pages/<page_name>_page.py
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from pages.base_page import BasePage


class <PageName>Page(BasePage):
    """<页面名称> Page Object"""

    # 页面URL
    URL = '/<page-path>'

    # ==================== 定位器 ====================
    PAGE_TITLE = (By.CSS_SELECTOR, '[data-testid="page-title"]')
    SUBMIT_BUTTON = (By.XPATH, "//button[text()='提交']")
    ERROR_MESSAGE = (By.CLASS_NAME, 'error-message')

    def __init__(self, driver):
        super().__init__(driver)

    # ==================== 操作方法 ====================

    def click_submit(self):
        """点击提交按钮"""
        self.click(self.SUBMIT_BUTTON)

    def get_error_message(self) -> str:
        """获取错误信息文本"""
        return self.get_text(self.ERROR_MESSAGE)

    # ==================== 断言方法 ====================

    def verify_page_loaded(self):
        """验证页面已正确加载"""
        self.wait_for_element(self.PAGE_TITLE)
        assert self.PAGE_TITLE in self.driver.current_url
```

## 测试脚本模板

### Playwright TypeScript

```typescript
// tests/<test-name>.spec.ts
import { test, expect } from '@playwright/test';
import { <PageName>Page } from '../pages/<PageName>.page';
import { TEST_DATA } from '../fixtures/test-data';

test.describe('<测试模块名称>', () => {

  let <pageVar>: <PageName>Page;

  test.beforeEach(async ({ page }) => {
    <pageVar> = new <PageName>Page(page);
    // 前置条件：如登录
    // await loginAndSetup(page);
  });

  test('<场景ID> <场景名称> @smoke', async ({ page }) => {
    // Step 1: 导航到页面
    await <pageVar>.goto();
    await <pageVar>.expectPageLoaded();

    // Step 2: 执行操作
    await <pageVar>.<actionName>();

    // Step 3: 断言结果
    await expect(page.locator('<selector>')).toBeVisible();
    await expect(page.locator('<selector>')).toHaveText('<expected>');
  });

  test('<场景ID> <异常场景名称>', async ({ page }) => {
    // 异常流程测试
    await <pageVar>.goto();

    // 执行异常操作
    await <pageVar>.<invalidAction>();

    // 验证错误提示
    await expect(<pageVar>.errorMessage).toBeVisible();
    await expect(<pageVar>.errorMessage).toContainText('<错误信息>');
  });
});
```

## 命名规范

### 文件命名
| 类型 | 规范 | 示例 |
|------|------|------|
| Page Object | `kebab-case.page.ts` | `login.page.ts` |
| 测试文件 | `kebab-case.spec.ts` | `login.spec.ts` |
| Fixture | `kebab-case.ts` | `test-data.ts` |
| 配置文件 | `kebab-case.config.ts` | `playwright.config.ts` |

### 代码命名
| 类型 | 规范 | 示例 |
|------|------|------|
| 类名 | PascalCase | `LoginPage` |
| 方法名 | camelCase | `clickLoginButton()` |
| 变量名 | camelCase | `loginPage` |
| 常量 | UPPER_SNAKE_CASE | `BASE_URL` |
| 选择器属性值 | kebab-case | `data-testid="login-btn"` |

## 选择器规范

### 优先级顺序

1. **`data-testid`**（最推荐）
   ```typescript
   page.locator('[data-testid="submit-btn"]')
   ```

2. **语义角色 + 可访问名称**
   ```typescript
   page.getByRole('button', { name: '提交' })
   page.getByLabel('用户名')
   page.getByPlaceholder('请输入密码')
   ```

3. **文本内容**
   ```typescript
   page.getByText('欢迎回来')
   page.getByText('提交', { exact: true })
   ```

4. **CSS 选择器**（稳定时使用）
   ```typescript
   page.locator('.login-form .submit-btn')
   page.locator('#username')
   ```

5. **XPath**（最后手段）
   ```typescript
   page.locator('//button[contains(text(), "提交")]')
   ```

### 禁止的做法

```typescript
// ❌ 脆弱：CSS Modules 的 hash 类名
page.locator('.login_form_submit__aB3xY')

// ❌ 脆弱：深层嵌套结构
page.locator('div:nth-child(3) > div:nth-child(2) > button:nth-child(1)')

// ❌ 不可读：无意义的 XPath
page.locator('//div/div/div/button')
```

## 等待规范

### Playwright 推荐做法

```typescript
// ✅ 自动等待（Playwright 默认行为）
await page.getByRole('button', { name: '提交' }).click();

// ✅ 等待元素可见
await expect(page.locator('.result')).toBeVisible({ timeout: 10000 });

// ✅ 等待网络请求完成
await page.waitForResponse(resp => resp.url().includes('/api/data') && resp.status() === 200);

// ❌ 避免固定等待
await page.waitForTimeout(3000); // 除非确实必要
```

## Playwright 配置模板

```typescript
// playwright.config.ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,

  reporter: [
    ['html', { outputFolder: '../test-reports/html' }],
    ['json', { outputFile: '../test-results/results.json' }],
  ],

  timeout: 30000,
  expect: {
    timeout: 10000,
  },

  use: {
    baseURL: process.env.BASE_URL || 'http://localhost:3000',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    testIdAttribute: 'data-testid',
  },

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] },
    },
    {
      name: 'mobile-chrome',
      use: { ...devices['Pixel 5'] },
    },
  ],

  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
  },
});
```

## 质量检查清单

生成脚本后应检查：

- [ ] Page Object 文件命名符合 kebab-case 规范
- [ ] 测试文件命名以 `.spec.ts` 结尾
- [ ] 选择器优先使用 `data-testid` 或语义化方法
- [ ] 无固定 `waitForTimeout` / `sleep` 调用（除非必要）
- [ ] 每个测试至少包含一个 `expect` 断言
- [ ] `beforeEach` 中正确设置前置条件
- [ ] 测试之间相互独立，不依赖执行顺序
- [ ] 错误场景有对应的断言
- [ ] 配置文件包含必要的基础设置

---

## 相关文档

- **Action**: `/asdm-ui-test-design-generate` - 使用本规范生成 Playwright 降级脚本
- **Spec**: `ui-test-case-spec.md` - 测试用例文档规范
- **Playwright 官方文档**: https://playwright.dev/docs/intro
