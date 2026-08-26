#!/usr/bin/env node
/**
 * lint-dataset.js
 * 确定性校验一个 UI 测试数据集是否符合工具集规范（命名 / 结构 / 标注完整性 /
 * 脚本骨架），固化 design-generate 与 run 阶段里反复出现的“检测数据集”机械检查。
 *
 * 用法:
 *   node lint-dataset.js <数据集文件夹或前缀> [--workspace=<ui-test基目录>]
 *
 * 退出码: 0 = 仅警告/通过；1 = 存在错误。
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const args = process.argv.slice(2);
let TARGET = null;
let workspace = '.asdm/workspace/ui-test';
for (const a of args) {
  if (a.startsWith('--workspace=')) workspace = a.split('=')[1];
  else if (!a.startsWith('--')) TARGET = a;
}
if (!TARGET) {
  console.error('❌ 缺少数据集文件夹参数');
  console.error('用法: node lint-dataset.js <文件夹或前缀> [--workspace=...]');
  process.exit(1);
}

// 解析数据集文件夹（支持前缀匹配，取最新 mtime）
function resolveFolder(target, base) {
  const absBase = path.resolve(base);
  if (fs.existsSync(path.resolve(target)) && fs.statSync(path.resolve(target)).isDirectory()) {
    return path.resolve(target);
  }
  const cand = path.join(absBase, target);
  if (fs.existsSync(cand) && fs.statSync(cand).isDirectory()) return cand;
  if (!fs.existsSync(absBase)) return null;
  const matches = fs.readdirSync(absBase)
    .filter(d => d.startsWith(target) && fs.statSync(path.join(absBase, d)).isDirectory())
    .map(d => ({ d, m: fs.statSync(path.join(absBase, d)).mtimeMs }))
    .sort((a, b) => b.m - a.m);
  return matches.length ? path.join(absBase, matches[0].d) : null;
}

const folder = resolveFolder(TARGET, workspace);
if (!folder) {
  console.error(`❌ 找不到数据集文件夹: ${TARGET}`);
  process.exit(1);
}

const errors = [];
const warns = [];
const ok = [];
function err(msg) { errors.push(msg); }
function warn(msg) { warns.push(msg); }
function pass(msg) { ok.push(msg); }

// 1. 文件夹命名
if (/_\d{14}$/.test(path.basename(folder))) pass('文件夹命名符合 <用例名>_<时间戳> 规范');
else warn(`文件夹命名未含时间戳后缀: ${path.basename(folder)}`);

// 2. overview.md
const ovPath = path.join(folder, 'overview.md');
if (!fs.existsSync(ovPath)) err('缺少 overview.md');
else {
  const ov = fs.readFileSync(ovPath, 'utf-8');
  if (/执行计划/.test(ov)) pass('overview.md 含“执行计划”章节');
  else err('overview.md 缺少“执行计划”章节');
}

// 3. data 骨架
for (const f of ['env.json', 'accounts.json', 'business.json', 'variables.js']) {
  const p = path.join(folder, 'data', f);
  if (!fs.existsSync(p)) err(`data/${f} 缺失`);
  else {
    if (f.endsWith('.json')) {
      try { JSON.parse(fs.readFileSync(p, 'utf-8')); pass(`data/${f} 为合法 JSON`); }
      catch (e) { err(`data/${f} 不是合法 JSON: ${e.message}`); }
    } else pass(`data/${f} 存在`);
  }
}

// 4. annotations.json
const annPath = path.join(folder, 'annotations.json');
if (!fs.existsSync(annPath)) err('缺少 annotations.json');
else {
  let ann;
  try { ann = JSON.parse(fs.readFileSync(annPath, 'utf-8')); pass('annotations.json 为合法 JSON'); }
  catch (e) { err(`annotations.json 非法 JSON: ${e.message}`); ann = null; }
  if (ann) {
    const scs = ann.scenarios || {};
    const scKeys = Object.keys(scs);
    if (!scKeys.length) err('annotations.json 中无场景');
    for (const scId of scKeys) {
      const sc = scs[scId];
      if (!sc.steps || !Object.keys(sc.steps).length) err(`${scId}: 无 steps`);
      for (const [sid, st] of Object.entries(sc.steps || {})) {
        if (!st.description) err(`${scId}/${sid}: 缺少 description`);
        if (!st.expectedResult) err(`${scId}/${sid}: 缺少 expectedResult`);
        if (st.recordingStepIndex == null) err(`${scId}/${sid}: 缺少 recordingStepIndex`);
        if (st.isAssertion) {
          if (!st.expectedResult || st.expectedResult === '—') warn(`${scId}/${sid}: 断言步骤 expectedResult 偏空`);
        }
      }
      if (sc.scripts) {
        if (!sc.scripts.agentBrowser) warn(`${scId}: scripts.agentBrowser 未填`);
        if (!sc.scripts.playwright) warn(`${scId}: scripts.playwright 未填`);
      }
    }
  }
}

// 5. 场景脚本骨架 (.sh / .js) + @step 一致性
const shList = fs.readdirSync(folder).filter(f => f.endsWith('.sh'));
for (const sh of shList) {
  const shPath = path.join(folder, sh);
  const jsPath = path.join(folder, sh.replace(/\.sh$/, '.js'));
  const content = fs.readFileSync(shPath, 'utf-8');
  let stepCnt = 0;
  if (/set -e/.test(content)) pass(`${sh}: 含 set -e`); else err(`${sh}: 缺少 set -e`);
  if (/\[EXEC:START\]/.test(content)) pass(`${sh}: 含 [EXEC:START]`); else err(`${sh}: 缺少 [EXEC:START]`);
  if (/\[EXEC:END\]/.test(content)) pass(`${sh}: 含 [EXEC:END]`); else err(`${sh}: 缺少 [EXEC:END]`);
  stepCnt = (content.match(/#\s*@step/g) || []).length;
  if (stepCnt === 0) warn(`${sh}: 无 @step 注释（步骤待填充）`); else pass(`${sh}: 含 ${stepCnt} 个 @step`);

  if (!fs.existsSync(jsPath)) err(`${sh}: 对应的 .js 降级脚本缺失`);
}

// 6. 录制源文件存在性
const recBase = path.resolve(workspace, '..', '..', '..', 'recordings');
function checkRec(rel) {
  // rel 形如 recordings/模块/文件.json
  const p = path.resolve(recBase, path.basename(path.dirname(rel)), path.basename(rel));
  if (!fs.existsSync(p)) {
    // 退化匹配：在 recordings 下按文件名查找
    const name = path.basename(rel);
    let found = false;
    if (fs.existsSync(recBase)) {
      for (const mod of fs.readdirSync(recBase)) {
        if (fs.existsSync(path.join(recBase, mod, name))) { found = true; break; }
      }
    }
    if (!found) warn(`录制源文件未找到: ${rel}`);
  }
}
if (fs.existsSync(annPath)) {
  try {
    const ann = JSON.parse(fs.readFileSync(annPath, 'utf-8'));
    for (const sc of Object.values(ann.scenarios || {})) {
      if (sc.sourceRecording) checkRec(sc.sourceRecording);
    }
  } catch (_) {}
}

// ---------- 输出报告 ----------
const lines = [];
lines.push(`# 数据集校验报告`);
lines.push('');
lines.push(`> 数据集: \`${path.basename(folder)}\``);
lines.push(`> 时间: ${new Date().toISOString().replace('T', ' ').slice(0, 19)}`);
lines.push('');
lines.push(`| 类别 | 数量 |`);
lines.push(`|------|------|`);
lines.push(`| ✅ 通过 | ${ok.length} |`);
lines.push(`| ⚠️ 警告 | ${warns.length} |`);
lines.push(`| ❌ 错误 | ${errors.length} |`);
lines.push('');
if (ok.length) { lines.push('## 通过项'); ok.forEach(m => lines.push(`- ✅ ${m}`)); lines.push(''); }
if (warns.length) { lines.push('## 警告'); warns.forEach(m => lines.push(`- ⚠️ ${m}`)); lines.push(''); }
if (errors.length) { lines.push('## 错误'); errors.forEach(m => lines.push(`- ❌ ${m}`)); lines.push(''); }
lines.push(`**结论**: ${errors.length ? '存在错误，需修复后执行' : (warns.length ? '通过（含警告）' : '完全通过')}`);

const report = lines.join('\n');
console.log(report);

process.exit(errors.length ? 1 : 0);
