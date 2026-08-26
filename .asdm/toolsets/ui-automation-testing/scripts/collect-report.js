#!/usr/bin/env node
/**
 * collect-report.js
 * 机械执行数据集下的 .sh 脚本（按 overview.md 执行计划顺序），解析运行标记
 * ([EXEC:START/END]、[STEP:*:START/OK]、[LOGIN:*]、❌断言失败)，生成 report.md，
 * 固化 asdm-ui-test-run action 的“运行 + 汇总报告”机械部分。
 * 选择器转换/自愈（需 AI 语义判断）仍回退 AI。
 *
 * 用法:
 *   node collect-report.js <数据集文件夹或前缀> [--workspace=<ui-test基目录>]
 */

const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const args = process.argv.slice(2);
let TARGET = null;
let workspace = '.asdm/workspace/ui-test';
for (const a of args) {
  if (a.startsWith('--workspace=')) workspace = a.split('=')[1];
  else if (!a.startsWith('--')) TARGET = a;
}
if (!TARGET) {
  console.error('❌ 缺少数据集文件夹参数');
  console.error('用法: node collect-report.js <文件夹或前缀> [--workspace=...]');
  process.exit(1);
}

function resolveFolder(target, base) {
  const absBase = path.resolve(base);
  if (fs.existsSync(path.resolve(target)) && fs.statSync(path.resolve(target)).isDirectory()) return path.resolve(target);
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
if (!folder) { console.error(`❌ 找不到数据集文件夹: ${TARGET}`); process.exit(1); }

const md = fs.existsSync(path.join(folder, 'overview.md'))
  ? fs.readFileSync(path.join(folder, 'overview.md'), 'utf-8') : '';

// ---------- markdown 表格解析 ----------
function extractTableAfter(text, anchor) {
  const lines = text.split('\n');
  let i = lines.findIndex(l => l.includes(anchor));
  if (i < 0) return [];
  while (i < lines.length && !lines[i].trim().startsWith('|')) i++;
  const rows = [];
  for (; i < lines.length; i++) {
    if (lines[i].trim().startsWith('|')) {
      const cells = lines[i].split('|').slice(1, -1).map(s => s.trim());
      if (cells.length && cells.every(c => /^:?-+:?$/.test(c))) continue;
      rows.push(cells);
    } else if (rows.length) break;
  }
  return rows;
}
const SC_RE = /SC-\d{3}/;

// 场景设计摘要 -> 优先级 + 依赖
const summaryRows = extractTableAfter(md, '场景设计摘要');
const summaryMap = {};
for (const r of summaryRows) {
  const scId = (r[0] || '').match(SC_RE);
  if (!scId) continue;
  const priority = r[2] || 'P0';
  const precond = r[4] || '';
  const dep = precond.match(SC_RE);
  summaryMap[scId[0]] = { priority, dependency: dep && dep[0] !== scId[0] ? dep[0] : null, precond };
}

// 脚本执行顺序 -> 顺序 + 脚本文件
const planRows = extractTableAfter(md, '脚本执行顺序');
const planMap = {};
for (const r of planRows) {
  const order = parseInt(r[0], 10);
  const scId = (r[1] || '').match(SC_RE);
  if (!scId) continue;
  // 取反引号内的脚本文件名，优先 .sh
  const backticks = (r[2] || '').match(/`([^`]+)`/g) || [];
  const names = backticks.map(s => s.replace(/`/g, ''));
  const shName = names.find(n => n.endsWith('.sh'));
  const jsName = names.find(n => n.endsWith('.js'));
  planMap[scId[0]] = { order: isNaN(order) ? 999 : order, script: shName || jsName || '', expected: r[3] || '' };
}

// annotations -> 预期步骤/断言数
let ann = null;
try { ann = JSON.parse(fs.readFileSync(path.join(folder, 'annotations.json'), 'utf-8')); } catch (_) {}
const annMap = {};
if (ann && ann.scenarios) {
  for (const [scId, sc] of Object.entries(ann.scenarios)) {
    const steps = Object.entries(sc.steps || {});
    annMap[scId] = {
      expectedSteps: steps.filter(([, v]) => !v.isAssertion).length,
      expectedAssert: steps.filter(([, v]) => v.isAssertion).length,
    };
  }
}

// 变量传递说明
const varRows = extractTableAfter(md, '变量传递说明');

// ---------- 组装待执行场景 ----------
const scenarios = Object.keys(planMap).map(scId => ({
  scId,
  order: planMap[scId].order,
  scriptName: planMap[scId].script,
  expected: planMap[scId].expected,
  priority: (summaryMap[scId] || {}).priority || 'P0',
  dependency: (summaryMap[scId] || {}).dependency || null,
  expectedSteps: (annMap[scId] || {}).expectedSteps || 0,
  expectedAssert: (annMap[scId] || {}).expectedAssert || 0,
  status: null, elapsedMs: 0, consoleOut: '', errorOut: '', reason: '',
  execSteps: 0, execAssert: 0, assertPass: 0, assertFail: 0, assertFailLines: [],
}));
scenarios.sort((a, b) => a.order - b.order);

// ---------- clean_data ----------
const dataJson = path.join(folder, 'data', 'data.json');
if (fs.existsSync(dataJson)) { try { fs.unlinkSync(dataJson); } catch (_) {} }

// ---------- 执行 ----------
const statusOf = {};
for (const sc of scenarios) {
  if (sc.dependency && statusOf[sc.dependency] && statusOf[sc.dependency] !== 'success') {
    sc.status = 'skipped';
    sc.reason = `依赖场景 ${sc.dependency} ${statusOf[sc.dependency] === 'skipped' ? '未执行' : '执行失败'}，跳过`;
    statusOf[sc.scId] = 'skipped';
    continue;
  }
  const rel = sc.scriptName;
  let scriptPath = path.join(folder, rel);
  if (!fs.existsSync(scriptPath) && rel.endsWith('.sh')) {
    const js = rel.replace(/\.sh$/, '.js');
    if (fs.existsSync(path.join(folder, js))) scriptPath = path.join(folder, js);
  }
  if (!fs.existsSync(scriptPath)) {
    sc.status = 'skipped';
    sc.reason = `脚本文件缺失: ${rel}`;
    statusOf[sc.scId] = 'skipped';
    continue;
  }
  const start = Date.now();
  let res;
  try {
    res = spawnSync('bash', [scriptPath], {
      cwd: folder, encoding: 'utf-8', timeout: 600000,
      maxBuffer: 32 * 1024 * 1024, killSignal: 'SIGTERM',
    });
  } catch (e) {
    sc.status = 'failed';
    sc.reason = `无法启动脚本: ${e.message}`;
    statusOf[sc.scId] = 'failed';
    continue;
  }
  sc.elapsedMs = Date.now() - start;
  const out = (res.stdout || '') + '\n' + (res.stderr || '');
  const outOnly = res.stdout || '';
  sc.consoleOut = outOnly.trim();
  sc.errorOut = (res.stderr || '').trim();

  const execEndFail = /\[EXEC:END\][^\n]*失败/.test(out);
  const execEndOk = /\[EXEC:END\][^\n]*(成功)/.test(out);
  const hasExecEnd = /\[EXEC:END\]/.test(out);
  sc.execSteps = (out.match(/\[STEP:step-[\w-]+:START\]/g) || []).length;
  sc.execAssert = (out.match(/\[STEP:assert-[\w-]+:START\]/g) || []).length;
  sc.assertPass = (out.match(/\[STEP:assert-[\w-]+:OK\]/g) || []).length;
  sc.assertFailLines = (outOnly.match(/❌\s*断言失败[：:].*/g) || []);
  sc.assertFail = sc.assertFailLines.length;

  const failed = res.status !== 0 || execEndFail || sc.assertFail > 0 || (res.error && !hasExecEnd);
  sc.status = failed ? 'failed' : 'success';

  // 失败原因
  if (failed) {
    const firstErr = (outOnly.match(/(?:\[ERROR\][^\n]*|❌[^\n]*)/g) || [])[0];
    sc.reason = firstErr ? firstErr.replace(/^\[ERROR\]\s*/, '') : (execEndFail ? '脚本标记执行失败' : `退出码 ${res.status}`);
    if (sc.assertFail > 0) sc.reason = `断言失败: ${sc.assertFailLines[0]}`;
  } else {
    sc.reason = '';
  }
  statusOf[sc.scId] = sc.status;
}
const total = scenarios.length;
const success = scenarios.filter(s => s.status === 'success').length;
const failed = scenarios.filter(s => s.status === 'failed').length;
const skipped = scenarios.filter(s => s.status === 'skipped').length;
const totalMs = scenarios.reduce((a, s) => a + (s.status !== 'skipped' ? s.elapsedMs : 0), 0);
const passRate = total ? Math.round(success / total * 100) : 0;

const opTotal = scenarios.reduce((a, s) => a + (s.status === 'skipped' ? s.expectedSteps : Math.max(s.expectedSteps, s.execSteps)), 0);
const assertTotal = scenarios.reduce((a, s) => a + s.expectedAssert, 0);
const assertPassTotal = scenarios.reduce((a, s) => a + s.assertPass, 0);
const assertFailTotal = scenarios.reduce((a, s) => a + s.assertFail, 0);
const assertRate = assertTotal ? `${assertPassTotal}/${assertTotal}` : '—';
const assertRatio = opTotal ? (assertTotal / opTotal * 100).toFixed(1) + '%' : '—';

const fmtMs = ms => ms >= 1000 ? `约 ${Math.round(ms / 1000)} 秒` : `${ms} ms`;
const now = new Date().toISOString().replace('T', ' ').slice(0, 19);
const caseName = (md.match(/^#\s*(.+?)\s*-\s*测试概览/m) || [])[1] || path.basename(folder);

// ---------- 生成 report.md ----------
const L = [];
L.push(`# ${caseName} - 执行报告`);
L.push('');
L.push(`> **执行时间**：${now}`);
L.push(`> **用例文件夹**：\`${path.relative(process.cwd(), folder)}\``);
L.push('');
L.push('---');
L.push('');
L.push('## 一、执行总览');
L.push('');
L.push('| 指标 | 数值 |');
L.push('|------|------|');
L.push(`| 场景总数 | ${total} |`);
L.push(`| 执行成功 | ${success} |`);
L.push(`| 执行失败 | ${failed} |`);
L.push(`| 跳过执行 | ${skipped} |`);
L.push(`| 总耗时 | ${fmtMs(totalMs)} |`);
L.push(`| 通过率 | ${passRate}% |`);
L.push('');
L.push('## 二、各场景执行详情');
L.push('');
for (const sc of scenarios) {
  const stMap = { success: '✅ 成功', failed: '❌ 失败', skipped: '⏭️ 跳过' };
  L.push(`### 场景 ${sc.scId}：${sc.scriptName.replace(/\.(sh|js)$/, '')}`);
  L.push('');
  L.push('| 属性 | 值 |');
  L.push('|------|------|');
  L.push(`| 脚本文件 | \`${sc.scriptName}\` |`);
  L.push(`| 优先级 | ${sc.priority} |`);
  L.push(`| 执行状态 | ${stMap[sc.status]} |`);
  L.push(`| 依赖场景 | ${sc.dependency || '—'} |`);
  L.push(`| 耗时 | ${sc.status === 'skipped' ? '—' : fmtMs(sc.elapsedMs)} |`);
  L.push(`| 断言通过/总数 | ${sc.status === 'skipped' ? '—' : `${sc.assertPass}/${sc.expectedAssert || sc.execAssert}`} |`);
  L.push('');
  if (sc.status !== 'skipped') {
    L.push('**控制台输出**：');
    L.push('');
    L.push('```');
    L.push(sc.consoleOut.slice(0, 4000) || '(无输出)');
    L.push('```');
    L.push('');
  }
  if (sc.errorOut || sc.reason) {
    L.push('**错误信息**：');
    L.push('');
    L.push('```');
    L.push((sc.errorOut || sc.reason || '').slice(0, 2000));
    L.push('```');
    L.push('');
  }
  L.push(`**说明**：${sc.reason || '执行成功'}`);
  L.push('');
  L.push('---');
  L.push('');
}
L.push('## 三、变量传递记录');
L.push('');
if (varRows.length) {
  L.push('| 变量名 | 产生场景 | 值 | 消费场景 | 状态 |');
  L.push('|--------|---------|-----|---------|------|');
  for (const r of varRows) {
    const vName = r[0] || '';
    const producer = r[1] || '';
    const consumer = r[2] || '';
    let state = '—';
    if (/data\//.test(producer) || /数据文件/.test(producer)) state = '✅ 数据文件就绪';
    else {
      const p = producer.match(SC_RE);
      if (p) state = statusOf[p[0]] === 'success' ? '✅ 已产生' : `❌ 未产生（${p[0]} 执行${statusOf[p[0]] === 'skipped' ? '未执行' : '失败'}）`;
    }
    L.push(`| ${vName} | ${producer} | — | ${consumer} | ${state} |`);
  }
} else {
  L.push('_（未在 overview.md 解析到变量传递说明）_');
}
L.push('');
L.push('## 四、执行结论');
L.push('');
const verdict = failed === 0 && skipped === 0 ? '通过' : (success > 0 && (failed > 0 || skipped > 0) ? '部分通过' : '未通过');
L.push(`- **结论**：${verdict}（成功 ${success} / 失败 ${failed} / 跳过 ${skipped}）`);
L.push('');
if (failed > 0) {
  L.push('### 失败场景总结');
  L.push('');
  L.push('| 场景编号 | 失败原因 | 建议 |');
  L.push('|---------|---------|------|');
  for (const sc of scenarios.filter(s => s.status === 'failed')) {
    L.push(`| ${sc.scId} | ${(sc.reason || '').replace(/\|/g, '/').slice(0, 60)} | 检查选择器/数据文件，必要时转人工兜底 |`);
  }
  L.push('');
}
L.push('## 五、断言覆盖情况');
L.push('');
L.push('| 指标 | 数值 |');
L.push('|------|------|');
L.push(`| 操作步骤总数 | ${opTotal} |`);
L.push(`| 断言步骤总数 | ${assertTotal} |`);
L.push(`| 断言通过率 | ${assertRate} |`);
L.push(`| 断言占比（断言步骤数 / 操作步骤数） | ${assertRatio} |`);
L.push('');
L.push('### 各场景断言明细');
L.push('');
L.push('| 场景编号 | 断言步骤数 | 通过 | 失败 | 未执行 |');
L.push('|---------|-----------|------|------|--------|');
for (const sc of scenarios) {
  const totalA = sc.expectedAssert;
  const pass = sc.status === 'skipped' ? 0 : sc.assertPass;
  const fail = sc.status === 'skipped' ? 0 : sc.assertFail;
  const unexec = sc.status === 'skipped' ? totalA : Math.max(0, totalA - pass - fail);
  L.push(`| ${sc.scId} | ${totalA || (sc.status === 'skipped' ? '—' : sc.execAssert)} | ${sc.status === 'skipped' ? '—' : pass} | ${sc.status === 'skipped' ? '—' : fail} | ${sc.status === 'skipped' ? totalA : unexec} |`);
}
L.push('');
L.push('## 六、转人工清单');
L.push('');
L.push('### 失败场景');
L.push('');
L.push('| 序号 | 问题脚本 | 所属场景 | 报错原因 | AI 已尝试的修复动作 | 建议人工操作 |');
L.push('|------|---------|---------|---------|--------------------|-------------|');
let idx = 0;
for (const sc of scenarios.filter(s => s.status !== 'success')) {
  idx += 1;
  const reason = (sc.reason || (sc.status === 'skipped' ? '依赖未满足' : '执行失败')).replace(/\|/g, '/').slice(0, 80);
  L.push(`| ${idx} | \`${sc.scriptName}\` | ${sc.scId} | ${reason} | — | 检查选择器或数据文件，重跑后验证 |`);
}
L.push('');
L.push('---');
L.push('');
L.push(`> **报告生成时间**：${now}`);
L.push('');
L.push('> 本报告由 collect-report.js 机械生成（执行 + 标记解析）。选择器转换/自愈等需语义判断的部分仍建议由 AI 处理。');

fs.writeFileSync(path.join(folder, 'report.md'), L.join('\n'), 'utf-8');
console.log(`\n✅ 报告已生成: ${path.join(folder, 'report.md')}`);
console.log(`   结论: ${verdict} | 成功 ${success} / 失败 ${failed} / 跳过 ${skipped} | 通过率 ${passRate}%`);
