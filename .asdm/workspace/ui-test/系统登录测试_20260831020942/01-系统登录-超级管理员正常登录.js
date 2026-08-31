/**
 * LOGIN-001 超级管理员正常登录（Playwright 降级产物）
 * 来源录制: recordings/系统登录/001_系统登录.json（步骤 0~14）
 * 生成时间: 2026-08-31 02:09:42
 *
 * 与 agent-browser 主产物（01-系统登录-超级管理员正常登录.sh）同基名，
 * 同一元素使用一致的选择器语义，便于对照维护。
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
    console.log('========== 开始执行：LOGIN-001 超级管理员正常登录 ==========');

    // Step 1: 打开门户首页
    // Recorder selectors: (navigate 步骤，无元素选择器；录制步骤 1)
    console.log('[Step 1] 打开门户首页...');
    await page.goto(`${env.baseUrl}/portal/`, { waitUntil: 'networkidle', timeout: 30000 });

    // 断言 1: 门户标题为「ASDM AI资源中心」（录制步骤 1 assertedEvents）
    const portalTitle = await page.title();
    if (!portalTitle.includes('ASDM AI资源中心')) {
      throw new Error(`门户标题不符（期望含「ASDM AI资源中心」，实际: ${portalTitle}）`);
    }
    console.log(`✅ 断言通过: 门户首页加载成功（标题: ${portalTitle}）`);

    // Step 2: 点击门户头部「登录」按钮
    // Recorder selectors: aria/登录 | header button | xpath/... | pierce/header button | text/登录
    console.log('[Step 2] 点击门户头部「登录」按钮...');
    await page.locator('header button').click();
    await page.waitForURL(/signin/, { timeout: 10000 });

    // 断言 2: 已跳转登录页且登录表单可见（录制步骤 2 assertedEvents）
    const formInputCount = await page.locator('form input').count();
    if (formInputCount < 2) {
      throw new Error(`登录表单输入框数量不足（期望 ≥2，实际: ${formInputCount}）`);
    }
    console.log(`✅ 断言通过: 已跳转登录页（${page.url()}），登录表单可见`);

    // Step 3: 填写邮箱（aria/请输入邮箱地址 → getByPlaceholder）
    // Recorder selectors: aria/请输入邮箱地址 | form > div > div:nth-of-type(1) input | xpath/... | pierce/...
    console.log('[Step 3] 填写登录邮箱...');
    await page.getByPlaceholder('请输入邮箱地址').fill(username);

    // Step 4: 填写密码（aria/请输入您的密码 → getByPlaceholder）
    // Recorder selectors: aria/请输入您的密码 | form > div > div:nth-of-type(2) input | xpath/... | pierce/...
    console.log('[Step 4] 填写登录密码...');
    await page.getByPlaceholder('请输入您的密码').fill(password);

    // Step 5: 点击表单「登录」提交按钮（aria/登录 → CSS form button）
    // Recorder selectors: aria/登录 | form button | xpath/... | pierce/form button
    console.log('[Step 5] 点击表单「登录」提交按钮...');
    await page.locator('form button').click();
    await page.waitForURL(/\/portal\//, { timeout: 30000 });

    // 断言 3: 登录成功跳回门户，标题为「ASDM AI资源中心」（录制步骤 14 assertedEvents）
    const afterLoginTitle = await page.title();
    if (!afterLoginTitle.includes('ASDM AI资源中心')) {
      throw new Error(`登录后门户标题不符（期望含「ASDM AI资源中心」，实际: ${afterLoginTitle}）`);
    }
    console.log(`✅ 断言通过: 登录成功，已跳回门户（${page.url()}，标题: ${afterLoginTitle}）`);

    console.log('✅ LOGIN-001 超级管理员正常登录 - 执行成功！');
    process.exitCode = 0;
  } catch (error) {
    console.error('❌ LOGIN-001 超级管理员正常登录 - 执行失败:', error.message);
    process.exitCode = 1;
  } finally {
    await page.waitForTimeout(3000);
    await browser.close();
  }
})();
