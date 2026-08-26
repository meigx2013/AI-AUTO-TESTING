/**
 * 变量保存模板 — data.json 跨脚本共享变量
 *
 * 保存方式：
 * - 文件存储：跨脚本共享变量（推荐）
 * - 环境变量：简单键值传递
 * - 脚本内变量：同一脚本内步骤间传递
 */

// === 变量保存模板 ===
const fs = require('fs');
const path = require('path');

const dataDir = path.join(__dirname);
const dataFile = path.join(dataDir, 'data.json');

// 读取已有数据
let sharedData = {};
if (fs.existsSync(dataFile)) {
  sharedData = JSON.parse(fs.readFileSync(dataFile, 'utf-8'));
}

// 保存新变量
sharedData.token = await page.evaluate(() => localStorage.getItem('token'));
sharedData.orderId = orderId;

fs.writeFileSync(dataFile, JSON.stringify(sharedData, null, 2));

// === 变量读取模板 ===
const dataFile2 = path.join(__dirname, 'data.json');
if (!fs.existsSync(dataFile2)) {
  throw new Error('前置数据文件不存在，请先执行依赖场景脚本');
}
const sharedData2 = JSON.parse(fs.readFileSync(dataFile2, 'utf-8'));
