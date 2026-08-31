/**
 * 测试场景: SC-001 系统登录-超级管理员正常登录
 * 来源录制: recordings/001_系统登录/001_系统登录.json
 * 生成时间: 2026-08-31 06:25:38
 * 脚本类型: Playwright（降级产物）
 *
 * 运行方式: node 001-系统登录-超级管理员正常登录.js
 *
 * 录制噪声说明: 录制中的重复 change（同值）、点击空白区域、Alt+Tab 切窗
 * 均为录制噪声，按规范"以最终 change 值为准"合并，不转换为脚本步骤。
 */
const { chromium } = require('playwright');
const path = require('path');

const env = require(path.join(__dirname, 'data', 'env.json'));
const accounts = require(path.join(__dirname, 'data', 'accounts.json')).accounts;

(async () => {
  const browser = await chromium.launch({ channel: 'chrome', headless: false });
  const context = await browser.newContext({
    viewport: { width: 1692, height: 721 }
  });
  const page = await context.newPage();

  try {
    // ==================== 场景：SC-001 系统登录-超级管理员正常登录 ====================
    console.log('========== 开始执行：系统登录-超级管理员正常登录 ==========');

    // Step 1: 打开平台门户首页（录制步骤索引 1）
    console.log('[Step 1] 打开平台门户首页...');
    await page.goto(`${env.baseUrl}/portal/`, { waitUntil: 'networkidle', timeout: 30000 });

    // 断言 1: 门户首页加载成功，标题含"ASDM AI资源中心"（录制步骤索引 1 的 assertedEvents）
    const title1 = await page.title();
    if (!title1.includes('ASDM AI资源中心')) {
      throw new Error(`断言失败：门户首页标题不含「ASDM AI资源中心」（实际: ${title1}）`);
    }
    console.log('✅ 断言通过: 门户首页加载成功（title: ' + title1 + '）');

    // 登录保障（三路探测之 cookie 信号）：检测到会话则跳过登录流程
    const cookies = await context.cookies();
    const authCookies = cookies.filter(c => /session|sid|token|auth|jwt|connect\.sid/i.test(c.name));
    if (authCookies.length > 0) {
      console.log('[LOGIN:SKIP] ✅ cookie 检测到会话 (' + authCookies.map(c => c.name).join(', ') + ')，已登录，跳过登录流程');
    } else {
      console.log('[LOGIN:NEED] ❌ 未检测到会话 cookie，执行登录流程');

      // Step 2: 点击页头「登录」按钮（录制步骤索引 2；中文按钮优先 CSS）
      console.log('[Step 2] 点击页头「登录」按钮...');
      await page.locator('header button').click();

      // 断言 2: 跳转到登录页（录制步骤索引 2 的 assertedEvents）
      await page.waitForURL(/signin/, { timeout: 15000 });
      console.log('✅ 断言通过: 已跳转到登录页（URL: ' + page.url() + '）');

      // Step 3: 填写超级管理员邮箱（录制步骤索引 3）
      console.log('[Step 3] 填写超级管理员邮箱...');
      await page.getByPlaceholder('请输入邮箱地址').fill(accounts.superAdmin.username);

      // Step 4: 填写超级管理员密码（录制步骤索引 4）
      console.log('[Step 4] 填写超级管理员密码...');
      await page.getByPlaceholder('请输入您的密码').fill(accounts.superAdmin.password);

      // Step 5: 按 Tab 键切换输入焦点（录制步骤索引 6）
      console.log('[Step 5] 按 Tab 切换输入焦点...');
      await page.keyboard.press('Tab');

      // Step 6: 点击登录表单「登录」按钮（录制步骤索引 16；中文提交按钮优先 CSS）
      console.log('[Step 6] 点击「登录」按钮提交表单...');
      await page.locator('form button').click();
    }

    // 断言 3: 登录成功返回门户首页（录制步骤索引 16 的 assertedEvents）
    await page.waitForURL(/\/portal\//, { timeout: 30000 });
    await page.waitForTimeout(3000);
    const title2 = await page.title();
    if (!title2.includes('ASDM AI资源中心')) {
      throw new Error(`断言失败：登录后标题不含「ASDM AI资源中心」（实际: ${title2}）`);
    }
    console.log('✅ 断言通过: 登录成功返回门户首页（URL: ' + page.url() + '）');

    console.log('✅ 系统登录-超级管理员正常登录 - 执行成功！');
  } catch (error) {
    console.error('❌ 系统登录-超级管理员正常登录 - 执行失败:', error.message);
    process.exitCode = 1;
  } finally {
    await page.waitForTimeout(3000);
    await browser.close();
  }
})();
