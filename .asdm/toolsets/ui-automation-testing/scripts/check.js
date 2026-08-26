#!/usr/bin/env node
/**
 * check.js
 * 扫描 recordings/ 目录，比对 tree.json，生成检测报告
 *
 * 用法:
 *   node check.js                              # 在当前目录（recording-checklist 工作区）运行
 *   node check.js <workspace>                  # 指定 recording-checklist 工作区路径
 *   node check.js --workspace=<workspace>      # 同上
 *   node check.js --recordings=<path>         # 指定录制文件根目录（默认 <workspace>/recordings）
 *   node check.js --update                     # 同时更新 recording-checklist.md
 *   node check.js --html                       # 同时生成 HTML 报告
 *   node check.js --all                        # 更新 markdown + 生成 HTML
 */

const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);

let WORKSPACE = '.';
let RECORDINGS_PATH = null;

const flagIdx = args.findIndex(a => a.startsWith('--workspace='));
if (flagIdx !== -1) {
  WORKSPACE = args[flagIdx].split('=')[1];
  args.splice(flagIdx, 1);
} else if (args.length > 0 && !args[0].startsWith('--')) {
  WORKSPACE = args.shift();
}

const recIdx = args.findIndex(a => a.startsWith('--recordings='));
if (recIdx !== -1) {
  RECORDINGS_PATH = args[recIdx].split('=')[1];
  args.splice(recIdx, 1);
}

const WORKSPACE_DIR = path.resolve(WORKSPACE);

const RECORDINGS_DIR = RECORDINGS_PATH ? path.resolve(RECORDINGS_PATH) : path.join(WORKSPACE_DIR, 'recordings');
const TREE_FILE = path.join(WORKSPACE_DIR, 'structure', 'tree.json');
const CHECKLIST_FILE = path.join(WORKSPACE_DIR, 'recording-checklist.md');
const REPORTS_DIR = path.join(WORKSPACE_DIR, 'reports');

const UPDATE_MD = args.includes('--update') || args.includes('--all');
const GEN_HTML = args.includes('--html') || args.includes('--all');

// 颜色
const c = {
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  gray: '\x1b[90m',
  reset: '\x1b[0m',
  bold: '\x1b[1m'
};

function formatTime(timestamp) {
  if (!timestamp) return '-';
  const d = new Date(timestamp);
  return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')} ${String(d.getHours()).padStart(2,'0')}:${String(d.getMinutes()).padStart(2,'0')}`;
}

function formatRelativeTime(timestamp) {
  if (!timestamp) return '-';
  const diff = Date.now() - timestamp;
  const days = Math.floor(diff / (24 * 60 * 60 * 1000));
  if (days === 0) return '今天';
  if (days === 1) return '昨天';
  if (days < 7) return `${days}天前`;
  if (days < 30) return `${Math.floor(days/7)}周前`;
  return `${Math.floor(days/30)}月前`;
}

function checkFile(filePath) {
  try {
    const stat = fs.statSync(filePath);
    return {
      exists: true,
      mtime: stat.mtimeMs,
      size: stat.size,
      isEmpty: stat.size === 0,
      isFresh: (Date.now() - stat.mtimeMs) < 30 * 24 * 60 * 60 * 1000
    };
  } catch {
    return { exists: false, mtime: null, size: 0, isEmpty: true, isFresh: false };
  }
}

function loadTree() {
  if (!fs.existsSync(TREE_FILE)) {
    console.error(`${c.red}❌ 错误：未找到 ${TREE_FILE}${c.reset}`);
    console.log(`工作区: ${WORKSPACE_DIR}`);
    console.log('请先运行: node scripts/generate-tree.js <功能清单文件> [workspace]');
    process.exit(1);
  }
  return JSON.parse(fs.readFileSync(TREE_FILE, 'utf-8'));
}

function generateHtmlReport(tree, results, summary) {
  const now = new Date().toISOString();
  const reportFile = path.join(REPORTS_DIR, `check-report-${new Date().toISOString().slice(0,10).replace(/-/g,'')}.html`);

  const progressPct = summary.total > 0 ? Math.round((summary.recorded / summary.total) * 100) : 0;
  const progressColor = progressPct >= 80 ? '#22c55e' : progressPct >= 50 ? '#f59e0b' : '#ef4444';

  let html = `<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Recording Checklist 检测报告</title>
<style>
* { margin: 0; padding: 0; box-sizing: border-box; }
body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #f5f5f5; padding: 20px; color: #333; }
.container { max-width: 1200px; margin: 0 auto; }
.header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; border-radius: 12px; margin-bottom: 20px; }
.header h1 { font-size: 24px; margin-bottom: 8px; }
.header .meta { opacity: 0.9; font-size: 14px; }
.stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin-bottom: 20px; }
.stat-card { background: white; padding: 20px; border-radius: 10px; box-shadow: 0 2px 8px rgba(0,0,0,0.06); }
.stat-card .number { font-size: 32px; font-weight: bold; color: #667eea; }
.stat-card .label { color: #666; font-size: 14px; margin-top: 4px; }
.stat-card.missing .number { color: #ef4444; }
.stat-card.warning .number { color: #f59e0b; }
.progress-bar { background: white; padding: 20px; border-radius: 10px; box-shadow: 0 2px 8px rgba(0,0,0,0.06); margin-bottom: 20px; }
.progress-bar .bar { height: 24px; background: #e5e7eb; border-radius: 12px; overflow: hidden; margin-top: 10px; }
.progress-bar .fill { height: 100%; background: ${progressColor}; border-radius: 12px; transition: width 0.5s ease; width: ${progressPct}%; }
.progress-bar .text { text-align: center; margin-top: 8px; font-size: 14px; color: #666; }
.module { background: white; border-radius: 10px; margin-bottom: 15px; overflow: hidden; box-shadow: 0 2px 8px rgba(0,0,0,0.06); }
.module-header { padding: 15px 20px; background: #f8fafc; border-bottom: 1px solid #e2e8f0; display: flex; justify-content: space-between; align-items: center; }
.module-header h3 { font-size: 16px; color: #1e293b; }
.module-header .badge { padding: 4px 12px; border-radius: 20px; font-size: 12px; font-weight: 500; }
.badge-done { background: #dcfce7; color: #166534; }
.badge-partial { background: #fef3c7; color: #92400e; }
.badge-empty { background: #fee2e2; color: #991b1b; }
table { width: 100%; border-collapse: collapse; }
th, td { padding: 12px 20px; text-align: left; border-bottom: 1px solid #f1f5f9; font-size: 14px; }
th { color: #64748b; font-weight: 600; background: #fafafa; }
tr:hover { background: #f8fafc; }
.status { display: inline-flex; align-items: center; gap: 6px; padding: 4px 10px; border-radius: 20px; font-size: 12px; font-weight: 500; }
.status-done { background: #dcfce7; color: #166534; }
.status-missing { background: #fee2e2; color: #991b1b; }
.status-stale { background: #fef3c7; color: #92400e; }
.status-empty { background: #f3f4f6; color: #6b7280; }
.dependency-tag { font-size: 11px; color: #8b5cf6; background: #f3e8ff; padding: 2px 8px; border-radius: 4px; margin-left: 8px; }
.time { color: #94a3b8; font-size: 13px; }
.warnings { background: #fffbeb; border: 1px solid #fcd34d; border-radius: 10px; padding: 20px; margin-bottom: 20px; }
.warnings h3 { color: #92400e; margin-bottom: 10px; font-size: 16px; }
.warnings ul { list-style: none; }
.warnings li { padding: 6px 0; color: #78350f; font-size: 14px; }
.warnings li::before { content: "⚠️ "; margin-right: 4px; }
.footer { text-align: center; color: #94a3b8; font-size: 12px; margin-top: 30px; padding: 20px; }
</style>
</head>
<body>
<div class="container">
<div class="header">
  <h1>📋 Recording Checklist 检测报告</h1>
  <div class="meta">生成时间: ${now} | 产品: ${tree.product || 'CodeArts'} | 工具: Chrome DevTools Recorder</div>
</div>

<div class="stats">
  <div class="stat-card">
    <div class="number">${summary.total}</div>
    <div class="label">原子操作总数</div>
  </div>
  <div class="stat-card">
    <div class="number" style="color:#22c55e">${summary.recorded}</div>
    <div class="label">已录制</div>
  </div>
  <div class="stat-card missing">
    <div class="number">${summary.missing}</div>
    <div class="label">待补充</div>
  </div>
  <div class="stat-card warning">
    <div class="number">${summary.warnings.length}</div>
    <div class="label">新鲜度警告</div>
  </div>
</div>

<div class="progress-bar">
  <div style="display:flex; justify-content:space-between; align-items:center;">
    <span style="font-weight:600; color:#1e293b;">总体完成度</span>
    <span style="font-size:20px; font-weight:bold; color:${progressColor};">${progressPct}%</span>
  </div>
  <div class="bar"><div class="fill"></div></div>
  <div class="text">${summary.recorded} / ${summary.total} 个原子操作已完成录制</div>
</div>`;

  if (summary.warnings.length > 0) {
    html += `
<div class="warnings">
  <h3>新鲜度警告 (${summary.warnings.length} 项)</h3>
  <ul>
    ${summary.warnings.map(w => `<li>${w}</li>`).join('')}
  </ul>
</div>`;
  }

  for (const mod of tree.modules) {
    const modResults = results.filter(r => r.moduleDir === mod.dir);
    const modRecorded = modResults.filter(r => r.exists).length;
    const modTotal = modResults.length;

    let badgeClass = 'badge-empty';
    let badgeText = `0/${modTotal}`;
    if (modRecorded === modTotal) {
      badgeClass = 'badge-done';
      badgeText = `${modRecorded}/${modTotal} ✅`;
    } else if (modRecorded > 0) {
      badgeClass = 'badge-partial';
      badgeText = `${modRecorded}/${modTotal}`;
    }

    html += `
<div class="module">
  <div class="module-header">
    <h3>📁 ${mod.dir}/ — ${mod.name}</h3>
    <span class="badge ${badgeClass}">${badgeText}</span>
  </div>
  <table>
    <thead>
      <tr>
        <th style="width:40px">#</th>
        <th>原子操作</th>
        <th>文件名</th>
        <th>状态</th>
        <th>修改时间</th>
        <th>备注</th>
      </tr>
    </thead>
    <tbody>`;

    for (const r of modResults) {
      let statusClass, statusText;
      if (!r.exists) {
        statusClass = 'status-missing';
        statusText = '❌ 待补充';
      } else if (r.isEmpty) {
        statusClass = 'status-empty';
        statusText = '⚠️ 空文件';
      } else if (!r.isFresh) {
        statusClass = 'status-stale';
        statusText = `⏰ ${r.relativeTime}`;
      } else {
        statusClass = 'status-done';
        statusText = '✅ 已录制';
      }

      const depTag = r.dependencies?.length 
        ? `<span class="dependency-tag">依赖: ${r.dependencies.join(', ')}</span>` 
        : '';
      const depByTag = r.dependents?.length
        ? `<span class="dependency-tag" style="background:#ecfdf5; color:#166534;">被${r.dependents.length}个依赖</span>`
        : '';

      html += `
      <tr>
        <td>${r.index}</td>
        <td>${r.desc}${depTag}${depByTag}</td>
        <td><code style="background:#f1f5f9; padding:2px 6px; border-radius:4px; font-size:12px;">${r.fileName}</code></td>
        <td><span class="status ${statusClass}">${statusText}</span></td>
        <td class="time">${r.timeStr}</td>
        <td style="color:#64748b; font-size:13px;">${r.note || '-'}</td>
      </tr>`;
    }

    html += `
    </tbody>
  </table>
</div>`;
  }

  html += `
<div class="footer">
  <p>Recording Checklist v1.0 | 由 check.js 自动生成</p>
</div>
</div>
</body>
</html>`;

  if (!fs.existsSync(REPORTS_DIR)) fs.mkdirSync(REPORTS_DIR, { recursive: true });
  fs.writeFileSync(reportFile, html, 'utf-8');
  console.log(`\n📄 HTML 报告已生成: ${reportFile}`);
  return reportFile;
}

function updateChecklistMarkdown(tree, results, summary) {
  const now = new Date().toISOString().slice(0, 19).replace('T', ' ');
  const progressPct = summary.total > 0 ? Math.round((summary.recorded / summary.total) * 100) : 0;

  let md = `# Recording Checklist

> 生成时间: ${now}  
> 产品: ${tree.product || 'CodeArts'}  
> 录制工具: Chrome DevTools Recorder  
> 检测基准目录: \`${path.relative(WORKSPACE_DIR, RECORDINGS_DIR).replace(/\\/g, '/')}/\`

---

## 📊 统计概览

| 模块 | 已录制 | 待补充 | 总计 | 完成度 |
|------|--------|--------|------|--------|
`;

  for (const mod of tree.modules) {
    const modResults = results.filter(r => r.moduleDir === mod.dir);
    const modRecorded = modResults.filter(r => r.exists && !r.isEmpty).length;
    const modMissing = modResults.filter(r => !r.exists).length;
    const modTotal = modResults.length;
    const modPct = modTotal > 0 ? Math.round((modRecorded / modTotal) * 100) : 0;
    md += `| ${mod.name} | ${modRecorded}/${modTotal} | ${modMissing} | ${modTotal} | ${modPct}% |\n`;
  }

  md += `| **合计** | **${summary.recorded}/${summary.total}** | **${summary.missing}** | **${summary.total}** | **${progressPct}%** |\n\n`;

  // 待补充清单
  const missingItems = results.filter(r => !r.exists);
  if (missingItems.length > 0) {
    md += `## 📝 待补充清单（按优先级排序）\n\n`;

    // 按依赖关系排序：被依赖的优先
    const priorityOrder = missingItems.sort((a, b) => {
      if (a.dependents?.length && !b.dependents?.length) return -1;
      if (!a.dependents?.length && b.dependents?.length) return 1;
      return 0;
    });

    for (const item of priorityOrder) {
      const priority = item.dependents?.length ? '🔴 高' : '🟡 中';
      const depNote = item.dependents?.length ? `（被 ${item.dependents.length} 个场景依赖）` : '';
      md += `- [ ] \`${item.moduleDir}/${item.fileName}\` — ${item.desc} ${priority}${depNote}\n`;
    }
    md += '\n';
  }

  // 各模块详情
  for (const mod of tree.modules) {
    const modResults = results.filter(r => r.moduleDir === mod.dir);
    md += `## ${mod.dir}/ — ${mod.name}\n\n`;
    md += `> ${mod.description}\n\n`;
    md += `| # | 原子操作 | 文件名 | 状态 | 修改时间 | 备注 |\n`;
    md += `|---|----------|--------|------|----------|------|\n`;

    for (const r of modResults) {
      let status, note = '';
      if (!r.exists) {
        status = '❌ 待补充';
        if (r.dependencies?.length) note = `依赖: ${r.dependencies.join(', ')}`;
      } else if (r.isEmpty) {
        status = '⚠️ 空文件';
      } else if (!r.isFresh) {
        status = `⏰ ${r.relativeTime}`;
      } else {
        status = '✅ 已录制';
      }
      if (r.dependents?.length) {
        note = note ? `${note}; 被${r.dependents.length}个依赖` : `被${r.dependents.length}个场景依赖`;
      }
      md += `| ${r.index} | ${r.desc} | \`${r.fileName}\` | ${status} | ${r.timeStr} | ${note || '-'} |\n`;
    }
    md += '\n';
  }

  // 新鲜度警告
  if (summary.warnings.length > 0) {
    md += `## ⚠️ 新鲜度警告\n\n`;
    for (const w of summary.warnings) {
      md += `- ${w}\n`;
    }
    md += '\n';
  }

  // 录制指南
  md += `## 📖 录制指南\n\n### 1. 使用 Chrome DevTools Recorder\n\n1. 打开 Chrome → F12 → **Recorder** 面板\n2. 点击 **「开始新的录制」**\n3. 输入录制名称（与文件名一致，如 \`create-project\`）\n4. 执行原子操作\n5. 停止录制 → **导出为 JSON** → 保存到对应目录\n\n### 2. 文件放置规则\n\n- 按模块放入对应目录（如 \`01-project/\`）\n- **文件名必须与清单完全一致**（区分大小写）\n- 导出格式选择 **JSON**\n\n### 3. 优先级建议\n\n1. 先录制 \`00-common/\` 下的公共操作（登录等）\n2. 优先补充「被依赖」的文件（影响多个场景）\n3. 再按模块逐个补全\n\n### 4. 复用说明\n\n- \`00-common/login.json\` 被多个模块依赖，建议最先录制\n- 场景录制时可直接从登录态开始，无需重复录制登录流程\n- 各模块原子操作可组合为完整业务流程\n\n---\n\n*本文件由 check.js 自动生成，请勿手动修改表格内容*\n`;

  fs.writeFileSync(CHECKLIST_FILE, md, 'utf-8');
  console.log(`📝 Markdown 清单已更新: ${CHECKLIST_FILE}`);
}

function main() {
  const tree = loadTree();
  const results = [];
  const summary = { total: 0, recorded: 0, missing: 0, warnings: [] };

  console.log('\n' + '='.repeat(70));
  console.log(`${c.bold}📋 Recording Checklist 检测报告${c.reset}`);
  console.log(`${c.gray}工作区: ${WORKSPACE_DIR}${c.reset}`);
  console.log('='.repeat(70));

  for (const mod of tree.modules) {
    const modulePath = path.join(RECORDINGS_DIR, mod.dir);

    if (!fs.existsSync(modulePath)) {
      fs.mkdirSync(modulePath, { recursive: true });
    }

    console.log(`\n${c.blue}📁 ${mod.dir}/${c.reset} ${c.gray}(${mod.name})${c.reset}`);

    for (let i = 0; i < mod.files.length; i++) {
      const file = mod.files[i];
      summary.total++;
      const filePath = path.join(modulePath, file.name);
      const info = checkFile(filePath);

      const result = {
        index: i + 1,
        moduleDir: mod.dir,
        fileName: file.name,
        desc: file.desc,
        exists: info.exists,
        mtime: info.mtime,
        timeStr: formatTime(info.mtime),
        relativeTime: formatRelativeTime(info.mtime),
        isEmpty: info.isEmpty,
        isFresh: info.isFresh,
        size: info.size,
        dependencies: file.dependencies || [],
        dependents: file.dependents || [],
        note: file.note || ''
      };
      results.push(result);

      if (info.exists) {
        summary.recorded++;
        if (info.isEmpty) {
          summary.warnings.push(`${mod.dir}/${file.name} — 文件为空`);
        } else if (!info.isFresh) {
          const days = Math.floor((Date.now() - info.mtime) / 86400000);
          summary.warnings.push(`${mod.dir}/${file.name} — 已 ${days} 天未更新`);
        }
      } else {
        summary.missing++;
      }

      // 控制台输出
      let status, color;
      if (!info.exists) {
        status = '❌ 待补充';
        color = c.red;
      } else if (info.isEmpty) {
        status = '⚠️ 空文件';
        color = c.yellow;
      } else if (!info.isFresh) {
        status = `⏰ ${result.relativeTime}`;
        color = c.yellow;
      } else {
        status = '✅ 已录制';
        color = c.green;
      }

      const depMark = result.dependents?.length ? `${c.gray}[被${result.dependents.length}个依赖]${c.reset}` : '';
      console.log(`  ${color}${status}${c.reset} ${file.name.padEnd(30)} ${result.timeStr.padEnd(20)} ${depMark}`);
    }
  }

  // 汇总
  const pct = summary.total > 0 ? Math.round((summary.recorded / summary.total) * 100) : 0;
  console.log('\n' + '='.repeat(70));
  console.log(`${c.bold}📊 统计汇总${c.reset}`);
  console.log(`  总计: ${summary.total} 个原子操作`);
  console.log(`  已录制: ${c.green}${summary.recorded}${c.reset}`);
  console.log(`  待补充: ${c.red}${summary.missing}${c.reset}`);
  console.log(`  完成度: ${pct >= 80 ? c.green : pct >= 50 ? c.yellow : c.red}${pct}%${c.reset}`);

  if (summary.warnings.length > 0) {
    console.log(`\n${c.yellow}⚠️ 新鲜度警告 (${summary.warnings.length} 项):${c.reset}`);
    summary.warnings.forEach(w => console.log(`   - ${w}`));
  }

  // 生成报告
  if (UPDATE_MD) {
    updateChecklistMarkdown(tree, results, summary);
  }

  if (GEN_HTML) {
    generateHtmlReport(tree, results, summary);
  }

  console.log('\n' + '='.repeat(70));
  console.log('✅ 检测完成\n');
}

main();
