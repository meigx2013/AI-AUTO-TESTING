/**
 * 测试场景: SC-001 门户导航-从门户进入管理控制台
 * 来源录制: recordings/002_进入ASDM管理后台/002_进入ASDM管理后台.json
 * 生成时间: 2026-08-31 07:17:21
 * 脚本类型: Playwright（降级产物）
 *
 * 运行方式: node 001-门户导航-从门户进入管理控制台.js
 *
 * 前置说明: 本场景业务步骤需登录态（页头用户头像 Admin Super），
 * 未检测到会话时自动执行登录流程（链路复用 recordings/001_系统登录.json 实测步骤）。
 */
const { chromium } = require('playwright');
const path = require('path');

const env = require(path.join(__dirname, 'data', 'env.json'));
const accounts = require(path.join(__dirname, 'data', 'accounts.json')).accounts;

(async () => {
  const browser = await chromium.launch({ channel: 'chrome', headless: false });
  const context = await browser.newContext({
    viewport: { width: 1692, height: 787 }
  });
  const page = await context.newPage();

  try {
    // ==================== 场景：SC-001 门户导航-从门户进入管理控制台 ====================
    console.log('========== 开始执行：门户导航-从门户进入管理控制台 ==========');

    // Step 1: 打开平台门户首页（录制步骤索引 1；viewport 1692x787 为录制步骤索引 0，已合并）
    console.log('[Step 1] 打开平台门户首页...');
    await page.goto(`${env.baseUrl}/portal/`, { waitUntil: 'networkidle', timeout: 30000 });

    // 断言 1: 门户首页加载成功，标题含"ASDM AI资源中心"（录制步骤索引 1 的 assertedEvents）
    const title1 = await page.title();
    if (!title1.includes('ASDM AI资源中心')) {
      throw new Error(`断言失败：门户首页标题不含「ASDM AI资源中心」（实际: ${title1}）`);
    }
    console.log('✅ 断言通过: 门户首页加载成功（title: ' + title1 + '）');

    // 登录保障（三路探测之 cookie 信号，含 HttpOnly）：未检测到会话则执行登录流程
    const cookies = await context.cookies();
    const authCookies = cookies.filter(c => /session|sid|token|auth|jwt|connect\.sid/i.test(c.name));
    if (authCookies.length > 0) {
      console.log('[LOGIN:SKIP] ✅ cookie 检测到会话 (' + authCookies.map(c => c.name).join(', ') + ')，已登录，跳过登录流程');
    } else {
      console.log('[LOGIN:NEED] ❌ 未检测到会话 cookie，执行登录流程');
      // 未登录时 header 按钮为「登录」按钮（与 001 录制同位）
      await page.locator('header button').click();
      await page.waitForURL(/signin/, { timeout: 15000 });
      await page.getByPlaceholder('请输入邮箱地址').fill(accounts.superAdmin.username);
      await page.getByPlaceholder('请输入您的密码').fill(accounts.superAdmin.password);
      // 中文提交按钮优先 CSS 选择器
      await page.locator('form button').click();
      await page.waitForURL(/\/portal\//, { timeout: 30000 });
      await page.waitForTimeout(3000);
      console.log('[LOGIN:OK] 登录完成，已回到门户首页');
    }

    // Step 2: 点击页头用户头像按钮（录制步骤索引 2；登录后 header 内按钮即用户头像 Admin Super）
    console.log('[Step 2] 点击页头用户头像按钮...');
    await page.locator('header button').click();
    await page.waitForTimeout(2000);

    // Step 3: 点击用户下拉菜单「控制台管理」菜单项（录制步骤索引 3；menuitem 有显式 ARIA role，实测稳定）
    console.log('[Step 3] 点击「控制台管理」菜单项...');
    await page.getByRole('menuitem', { name: '控制台管理' }).click();

    // 断言 2: 跳转到管理后台项目页（录制步骤索引 3 的 assertedEvents）
    await page.waitForURL(/\/projects/, { timeout: 30000 });
    const title2 = (await page.title()).trim();
    if (title2 !== 'ASDM') {
      throw new Error(`断言失败：管理后台标题不为「ASDM」（实际: ${title2}）`);
    }
    console.log('✅ 断言通过: 已进入 ASDM 管理后台（URL: ' + page.url() + ', title: ' + title2 + '）');

    console.log('✅ 门户导航-从门户进入管理控制台 - 执行成功！');
  } catch (error) {
    console.error('❌ 门户导航-从门户进入管理控制台 - 执行失败:', error.message);
    process.exitCode = 1;
  } finally {
    await page.waitForTimeout(3000);
    await browser.close();
  }
})();
