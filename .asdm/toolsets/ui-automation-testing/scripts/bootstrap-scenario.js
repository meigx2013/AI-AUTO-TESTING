#!/usr/bin/env node
/**
 * bootstrap-scenario.js
 * 机械创建 design-generate 的数据集骨架（固化其脚手架部分）：
 *   .asdm/workspace/ui-test/<用例名>_<时间戳>/
 *     data/{env.json, accounts.json, business.json, variables.js}
 *     <NN>-<模块>-<场景>.sh   (agent-browser 主产物骨架，业务步骤留给 AI)
 *     <NN>-<模块>-<场景>.js   (playwright 降级骨架，来自 playwright-script-template.js)
 *
 * 业务步骤逻辑、选择器转换与自愈仍由 AI 在 design-generate 阶段填充。
 *
 * 用法:
 *   node bootstrap-scenario.js --case=<用例名> \
 *     [--manifest=<场景清单JSON>] [--from-tree=<tree.json>] \
 *     [--out=<基目录>] [--base-url=<URL>] [--no-timestamp]
 *
 * 场景清单 JSON 格式 (--manifest):
 *   [
 *     { "scenario": "SC-001", "module": "用户与登录", "scene": "超级管理员登录",
 *       "recording": "recordings/用户与登录/登录-2026-07-16.json" },
 *     ...
 *   ]
 * --from-tree 模式：读取 recording-checklist/structure/tree.json，每个 file 作为一个场景。
 */

const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);
const opts = {
  case: null, manifest: null, fromTree: null,
  out: '.asdm/workspace/ui-test', baseUrl: '', noTimestamp: false,
};
for (const a of args) {
  if (a.startsWith('--case=')) opts.case = a.split('=')[1];
  else if (a.startsWith('--manifest=')) opts.manifest = a.split('=')[1];
  else if (a.startsWith('--from-tree=')) opts.fromTree = a.split('=')[1];
  else if (a.startsWith('--out=')) opts.out = a.split('=')[1];
  else if (a.startsWith('--base-url=')) opts.baseUrl = a.split('=')[1];
  else if (a === '--no-timestamp') opts.noTimestamp = true;
}
if (!opts.case) {
  console.error('❌ 缺少 --case 参数');
  console.error('用法: node bootstrap-scenario.js --case=<用例名> [--manifest=...] [--from-tree=...] [--out=...] [--base-url=...]');
  process.exit(1);
}
if (!opts.manifest && !opts.fromTree) {
  console.error('❌ 必须提供 --manifest=<场景清单JSON> 或 --from-tree=<tree.json> 之一');
  process.exit(1);
}

// ---------- 收集场景 ----------
let scenarios = [];
if (opts.manifest) {
  if (!fs.existsSync(opts.manifest)) { console.error(`❌ 清单不存在: ${opts.manifest}`); process.exit(1); }
  scenarios = JSON.parse(fs.readFileSync(opts.manifest, 'utf-8'));
} else {
  if (!fs.existsSync(opts.fromTree)) { console.error(`❌ tree.json 不存在: ${opts.fromTree}`); process.exit(1); }
  const tree = JSON.parse(fs.readFileSync(opts.fromTree, 'utf-8'));
  const mods = Array.isArray(tree) ? tree : (tree.modules || []);
  let n = 0;
  for (const mod of mods) {
    const dir = mod.dir || mod.name || '';
    const files = Array.isArray(mod.files) ? mod.files : [];
    for (const f of files) {
      n += 1;
      const name = typeof f === 'string' ? f : (f.name || `file-${n}`);
      const desc = typeof f === 'string' ? path.basename(f, '.json') : (f.desc || f.name);
      scenarios.push({
        scenario: `SC-${String(n).padStart(3, '0')}`,
        module: path.basename(dir) || '未分类',
        scene: desc,
        recording: `recordings/${dir}/${name}`,
      });
    }
  }
}
if (!scenarios.length) {
  console.error('❌ 未解析到任何场景');
  process.exit(1);
}
scenarios.sort((a, b) => (a.scenario || '').localeCompare(b.scenario || ''));

// ---------- 模板内容 ----------
const tmplDir = path.join(__dirname, '..', 'templates');
const VAR_TMPL = path.join(tmplDir, 'variable-templates.js');
const PW_TMPL = path.join(tmplDir, 'playwright-script-template.js');
let varTmpl = fs.existsSync(VAR_TMPL) ? fs.readFileSync(VAR_TMPL, 'utf-8') : '// 变量模板缺失\n';
let pwTmpl = fs.existsSync(PW_TMPL) ? fs.readFileSync(PW_TMPL, 'utf-8') : '// playwright 模板缺失\n';

const ts = new Date().toISOString().replace('T', ' ').slice(0, 19);
const nowStamp = new Date().toISOString().replace(/[-:T]/g, '').slice(0, 14);
const folderName = opts.noTimestamp ? opts.case : `${opts.case}_${nowStamp}`;
const folder = path.resolve(opts.out, folderName);
fs.mkdirSync(path.join(folder, 'data'), { recursive: true });

// data 骨架
fs.writeFileSync(path.join(folder, 'data', 'env.json'), JSON.stringify({
  baseUrl: opts.baseUrl || '<请补充: 被测系统 Base URL>',
  signinUrl: opts.baseUrl ? `${opts.baseUrl.replace(/\/$/, '')}/login` : '<请补充: 登录页 URL>',
}, null, 2), 'utf-8');

fs.writeFileSync(path.join(folder, 'data', 'accounts.json'), JSON.stringify({
  superAdmin: { email: '<请补充>', password: '<请补充>' },
}, null, 2), 'utf-8');

fs.writeFileSync(path.join(folder, 'data', 'business.json'), JSON.stringify({
  // 业务变量占位：由 design-generate / AI 填充实际业务值
}, null, 2), 'utf-8');

fs.writeFileSync(path.join(folder, 'data', 'variables.js'), varTmpl, 'utf-8');

// agent-browser 骨架
function shSkeleton(sc) {
  const sceneName = `${sc.module}-${sc.scene}`;
  return `#!/usr/bin/env bash
# ==========================================
#  ${sc.scenario}: ${sc.scene}
#  来源录制: ${sc.recording}
#  生成时间: ${ts}（由 bootstrap-scenario.js 生成骨架，业务步骤请在此填充）
# ==========================================
set -e

BASE_DIR="$(cd "$(dirname "\${BASH_SOURCE[0]}")/.." && pwd)"
SCENARIO_ID="${sc.scenario}"
SCENARIO_NAME="${sceneName}"

# 加载变量
source "\${BASE_DIR}/data/variables.sh" 2>/dev/null || true

echo "=========================================="
echo "  \${SCENARIO_ID}: \${SCENARIO_NAME}"
echo "=========================================="

# 标记由 agent-browser 在执行真实步骤时打印；此处骨架先用 echo 占位，
# 填充业务步骤后应删除下方占位 echo，改由 agent-browser 输出（详见 agent-browser-spec）。
echo "[LOGIN:CHECK]"

echo "[EXEC:START] \${SCENARIO_ID} | \${SCENARIO_NAME}"

# @step 在此按录制步骤填充 agent-browser 指令
# 参考 convert-recording.js 生成的 stepDesign.md / annotations.json
# 例如: agent-browser step navigate --url "\${BASE_URL}/signin"
#       agent-browser step fill --selector 'aria/请输入邮箱地址' --value "\${ADMIN_EMAIL}"

echo "[EXEC:END] \${SCENARIO_ID} | 成功"
`;
}

// ---------- 输出每个场景 ----------
const created = [];
for (const sc of scenarios) {
  const nn = String(sc.scenario || '').replace(/^SC-/, '') || '001';
  const baseName = `${nn}-${sc.module}-${sc.scene}`;
  const safeName = baseName.replace(/[\\/:*?"<>|]/g, '_');

  const shPath = path.join(folder, `${safeName}.sh`);
  fs.writeFileSync(shPath, shSkeleton(sc), 'utf-8');
  fs.chmodSync(shPath, 0o755);

  const jsPath = path.join(folder, `${safeName}.js`);
  const jsContent = pwTmpl
    .replace(/<场景名称>/g, sc.scene)
    .replace(/<SC-xxx>/g, sc.scenario);
  fs.writeFileSync(jsPath, jsContent, 'utf-8');

  created.push(safeName);
}

console.log(`\n✅ 脚手架生成完成: ${folder}`);
console.log(`   数据骨架: data/{env.json, accounts.json, business.json, variables.js}`);
console.log(`   场景脚本 (${scenarios.length}):`);
created.forEach((n, i) => console.log(`     - ${scenarios[i].scenario}: ${n}.sh / ${n}.js`));
console.log(`\n下一步: 在 ${folder} 中填充 .sh/.js 业务步骤，再运行 lint-dataset.js 校验。`);
