#!/usr/bin/env node
/**
 * convert-recording.js
 * 将 Chrome DevTools Recorder JSON 转换为结构化步骤设计（stepDesign.md）
 * 与自然语言标注（annotations.json）。固化 `asdm-ui-test-step-design` action
 * 的机械部分（解析录制、按 type 分类步骤、@符号元素探测打分、生成文档与标注），
 * 仅“业务模块映射”等需要语义判断的部分保留给 AI。
 *
 * 用法:
 *   node convert-recording.js <录制JSON文件> \
 *     [--out=<输出目录>] [--case=<用例名>] \
 *     [--index=<场景序号:1>] [--scenario=<SC-xxx>] [--module=<模块名>]
 *
 * 示例:
 *   node convert-recording.js recordings/用户与登录/登录-2026-07-16.json \
 *     --out=.asdm/workspace/ui-test/用户创建与令牌管理_20260721120000 \
 *     --case=用户创建与令牌管理 --index=1 --module=用户与登录
 *
 * 说明:
 *   - module 默认取 recordings/<模块>/<文件>.json 的 <模块> 目录名
 *   - 若 --out 下已存在 annotations.json，本脚本将把当前场景“合并”进去而不覆盖其他场景
 */

const fs = require('fs');
const path = require('path');

// ---------- 参数解析 ----------
const args = process.argv.slice(2);
let INPUT = null;
const opts = { out: '.', case: null, index: 1, scenario: null, module: null };
for (const a of args) {
  if (a.startsWith('--out=')) opts.out = a.split('=')[1];
  else if (a.startsWith('--case=')) opts.case = a.split('=')[1];
  else if (a.startsWith('--index=')) opts.index = parseInt(a.split('=')[1], 10) || 1;
  else if (a.startsWith('--scenario=')) opts.scenario = a.split('=')[1];
  else if (a.startsWith('--module=')) opts.module = a.split('=')[1];
  else if (!a.startsWith('--')) INPUT = a;
}
if (!INPUT) {
  console.error('❌ 缺少录制 JSON 文件参数');
  console.error('用法: node convert-recording.js <录制JSON> [--out=...] [--case=...] [--index=...] [--scenario=...] [--module=...]');
  process.exit(1);
}
if (!fs.existsSync(INPUT)) {
  console.error(`❌ 录制文件不存在: ${INPUT}`);
  process.exit(1);
}

const NNN = String(opts.index).padStart(3, '0');
const SC = opts.scenario || `SC-${NNN}`;
const MODULE = opts.module || path.basename(path.dirname(path.resolve(INPUT)));
const CASE = opts.case || path.basename(INPUT, '.json');
const ts = new Date().toISOString().replace('T', ' ').slice(0, 19);
const REL_REC = `recordings/${MODULE}/${path.basename(INPUT)}`;

// ---------- 步骤分类规则 ----------
function opLabel(type) {
  switch (type) {
    case 'setViewport': return '设置视口';
    case 'navigate': return '导航';
    case 'click': return '点击';
    case 'change': return '输入';
    case 'keyDown': return '按下按键';
    case 'keyUp': return '释放按键';
    case 'scroll': return '滚动';
    case 'waitForElement': return '等待元素';
    case 'waitForNetworkRequest': return '等待网络';
    case 'assert': return '断言';
    default: return type || '未知';
  }
}
function recPriority(type) {
  if (type === 'navigate' || type === 'click' || type === 'change') return '🔴';
  if (type === 'assert') return '🟡';
  return '⚪';
}
/** @符号/选择器稳定性探测：✅ 可定位 / ⚠️ 需确认 / ❌ 不可定位 */
function detectStatus(selectors) {
  const flat = (selectors || []).flat().filter(Boolean);
  if (flat.length === 0) return '❌';
  if (flat.some(s => s.startsWith('aria/'))) return '✅';
  if (flat.some(s => /^[#.a-zA-Z]/.test(s))) return '✅';
  if (flat.some(s => s.startsWith('xpath/') || s.startsWith('pierce/'))) return '⚠️';
  return '✅';
}
function firstSelector(selectors) {
  const flat = (selectors || []).flat().filter(Boolean);
  return flat[0] || '—';
}

// ---------- 读取录制 ----------
let rec;
try {
  rec = JSON.parse(fs.readFileSync(INPUT, 'utf-8'));
} catch (e) {
  console.error(`❌ 解析录制 JSON 失败: ${e.message}`);
  process.exit(1);
}
const steps = Array.isArray(rec.steps) ? rec.steps : [];
const recTitle = rec.title || CASE;

// ---------- 转换为结构化步骤 ----------
const rows = [];        // stepDesign.md 表格行
const stepMap = {};     // annotations.json steps
let k = 0, ak = 0;

steps.forEach((step, idx) => {
  const type = step.type;
  const isAssert = type === 'assert';
  const id = isAssert ? `assert-${NNN}-${++ak}` : `step-${NNN}-${++k}`;
  const label = opLabel(type);
  const sel = firstSelector(step.selectors);
  const status = detectStatus(step.selectors);
  const priority = recPriority(type);

  let description, expected, testData = '—';
  switch (type) {
    case 'setViewport':
      description = `设置视口 ${step.width}x${step.height}`;
      expected = `视口尺寸为 ${step.width}x${step.height}`;
      break;
    case 'navigate': {
      const url = step.url || '';
      description = `导航到 ${url}`;
      const ev = (step.assertedEvents || [])[0];
      expected = ev ? `页面加载完成，标题「${ev.title || ''}」` : `跳转到 ${url}`;
      break;
    }
    case 'click':
      description = `点击元素（${sel}）`;
      expected = '目标元素被点击并触发交互';
      break;
    case 'change':
      testData = step.value != null ? String(step.value) : '—';
      description = `在 ${sel} 输入值`;
      expected = `输入框显示 ${testData}`;
      break;
    case 'keyDown':
    case 'keyUp':
      description = `${label}（${step.key || ''}）`;
      expected = `触发按键 ${step.key || ''}`;
      break;
    case 'scroll':
      description = '滚动页面';
      expected = '页面滚动到位';
      break;
    case 'assert': {
      const ev = (step.assertedEvents || [])[0];
      description = `断言验证（${ev ? ev.type : '状态'}）`;
      expected = ev ? `验证 ${ev.type}` : '验证页面状态符合预期';
      break;
    }
    default:
      description = `${label}`;
      expected = '—';
  }

  rows.push([
    isAssert ? `assert-${ak}` : k,
    description,
    testData,
    expected,
    sel,
    priority,
    status,
  ]);

  stepMap[id] = {
    description,
    expectedResult: expected,
    recordingStepIndex: idx,
    isAssertion: isAssert,
  };
});

// ---------- 生成 stepDesign.md ----------
const md =
`# ${MODULE} UI 自动化测试步骤（由 convert-recording.js 生成）

> **来源录制**：${REL_REC}
> **生成时间**：${ts}
> **场景编号**：${SC}
> **说明**：本文件由 convert-recording.js 机械生成（步骤分类 + @符号元素探测），
>   业务模块映射与场景拆分如需调整，请在 design-generate 阶段由 AI 补充。

## 场景 ${SC}：${recTitle}

**优先级**：P0
**录制优先级**：🔴 必须

| 步骤 | 操作描述 | 测试数据 | 预期结果 | 元素描述 | 录制优先级 | 定位状态 |
|------|----------|----------|----------|---------|-----------|---------|
${rows.map(r => `| ${r[0]} | ${r[1]} | ${r[2]} | ${r[3]} | \`${r[4]}\` | ${r[5]} | ${r[6]} |`).join('\n')}
`;

// ---------- 生成 / 合并 annotations.json ----------
const annotations = {
  testCase: CASE,
  generatedAt: ts,
  description: recTitle,
  scenarios: {
    [SC]: {
      name: recTitle,
      sourceRecording: REL_REC,
      scripts: { agentBrowser: '', playwright: '' },
      steps: stepMap,
    },
  },
};

const outDir = path.resolve(opts.out);
if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });

const stepFile = path.join(outDir, 'stepDesign.md');
fs.writeFileSync(stepFile, md, 'utf-8');

const annFile = path.join(outDir, 'annotations.json');
if (fs.existsSync(annFile)) {
  try {
    const existing = JSON.parse(fs.readFileSync(annFile, 'utf-8'));
    existing.scenarios = existing.scenarios || {};
    existing.scenarios[SC] = annotations.scenarios[SC];
    if (!existing.testCase) existing.testCase = CASE;
    if (!existing.generatedAt) existing.generatedAt = ts;
    fs.writeFileSync(annFile, JSON.stringify(existing, null, 2), 'utf-8');
  } catch (e) {
    console.warn(`⚠️ 合并已有 annotations.json 失败，覆盖写入: ${e.message}`);
    fs.writeFileSync(annFile, JSON.stringify(annotations, null, 2), 'utf-8');
  }
} else {
  fs.writeFileSync(annFile, JSON.stringify(annotations, null, 2), 'utf-8');
}

const total = rows.length;
const located = rows.filter(r => r[6] === '✅').length;
const needConfirm = rows.filter(r => r[6] === '⚠️').length;
const unlocated = rows.filter(r => r[6] === '❌').length;

console.log(`\n✅ 转换完成: ${INPUT}`);
console.log(`   场景: ${SC} (${recTitle})`);
console.log(`   步骤数: ${total}（断言 ${ak}）`);
console.log(`   定位状态: ✅ ${located} / ⚠️ ${needConfirm} / ❌ ${unlocated}`);
console.log(`   输出:`);
console.log(`     - ${stepFile}`);
console.log(`     - ${annFile}${fs.existsSync(annFile) ? '（已合并）' : ''}`);
