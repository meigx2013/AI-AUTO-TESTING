/**
 * LOGIN-002 登录后进入控制台管理（Playwright 降级产物）
 * 来源录制: recordings/系统登录/001_系统登录.json（步骤 15~16）
 * 生成时间: 2026-08-31 02:09:42
 *
 * 前置依赖说明: Playwright 降级脚本各自独立启动浏览器，无法跨脚本共享登录态，
 * 因此本脚本内含登录态检测（门户头部按钮文本）：检测到「登录」按钮时先执行登录，
 * 再验证用户菜单 → 控制台管理入口。与 agent-browser 主产物（依赖场景 1 的 daemon
 * 会话）策略不同，属降级产物的独立运行保障。
 */
const { chromium } = require('playwright');
const path = require('path');

const env = require(path.join(__dirname, 'data', 'env.json'));
const accounts = require(path.join(__dirname, 'data', 'accounts.json')).accounts;

(async () => {
  const { username, password } = accounts.superAdmin;

  const browser = await chromium.launch({ channel: 'chrome', headless: false });
  const context = await browser.newContext({
    viewport: { width: 1692, height: 753 }
  });
  const page = await context.newPage();

  try {
    console.log('========== 开始执行：LOGIN-002 登录后进入控制台管理 ==========');

    // Step 1: 打开门户首页（含登录态检测）
    // Recorder selectors: (navigate 步骤，无元素选择器；录制步骤 1)
    console.log('[Step 1] 打开门户首页...');
    await page.goto(`${env.baseUrl}/portal/`, { waitUntil: 'networkidle', timeout: 30000 });

    // 登录态检测：门户头部为「登录」文本按钮则未登录，先执行登录（录制步骤 2/4/5/14）
    const headerButton = page.locator('header button');
    const buttonText = await headerButton.innerText().catch(() => '');
    if (buttonText.includes('登录')) {
      console.log('[登录态] 检测到未登录（门户头部为「登录」按钮），执行登录...');
      await headerButton.click();
      await page.waitForURL(/signin/, { timeout: 10000 });
      await page.getByPlaceholder('请输入邮箱地址').fill(username);
      await page.getByPlaceholder('请输入您的密码').fill(password);
      await page.locator('form button').click();
      await page.waitForURL(/\/portal\//, { timeout: 30000 });
    } else {
      console.log('[登录态] 门户头部为用户头像按钮，已登录，跳过登录');
    }

    // Step 2: 点击门户头部用户头像按钮，展开用户下拉菜单
    // Recorder selectors: div.css-6su6fj svg ⚠️(hash 类名不稳定) | xpath///*[@id="root"]/div/header/div/div[2]/button/svg | pierce/...
    // 依据 xpath：元素位于 header 下 button 内（登录前为「登录」按钮，登录后为头像按钮），改用 header button
    console.log('[Step 2] 点击门户头部用户头像按钮...');
    await page.locator('header button').click();
    await page.waitForTimeout(1000);

    // Step 3: 在用户下拉菜单中点击「控制台管理」菜单项（text/控制台管理 → getByText）
    // Recorder selectors: aria/控制台管理 | li:nth-of-type(2) | xpath//html/body/div[2]/div[3]/ul/li[2] | pierce/... | text/控制台管理
    console.log('[Step 3] 点击「控制台管理」菜单项...');
    await page.getByText('控制台管理').click();
    await page.waitForURL(/\/projects/, { timeout: 10000 });

    // 断言 1: 已跳转到控制台管理页面（录制步骤 16 assertedEvents: url=".../projects"）
    console.log(`✅ 断言通过: 已跳转到控制台管理页面（${page.url()}）`);

    console.log('✅ LOGIN-002 登录后进入控制台管理 - 执行成功！');
    process.exitCode = 0;
  } catch (error) {
    console.error('❌ LOGIN-002 登录后进入控制台管理 - 执行失败:', error.message);
    process.exitCode = 1;
  } finally {
    await page.waitForTimeout(3000);
    await browser.close();
  }
})();
