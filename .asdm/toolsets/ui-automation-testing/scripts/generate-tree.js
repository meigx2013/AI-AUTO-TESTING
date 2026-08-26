#!/usr/bin/env node
/**
 * generate-tree.js
 * 从功能清单文本生成 recording-checklist 的 structure/tree.json
 *
 * 用法:
 *   node generate-tree.js <功能清单文件> [workspace]
 *   node generate-tree.js <功能清单文件> --workspace=<workspace>
 *   node generate-tree.js <功能清单文件> --module-map=<module-map.json>
 *
 * 功能清单格式: 每行一个原子操作，用 "|" 分隔模块键和描述
 * 示例:
 *   common|登录系统
 *   common|退出登录
 *   project|创建项目
 *   project|删除项目
 *
 * 自定义模块映射（module-map.json）:
 *   {
 *     "common": { "dir": "00-common", "name": "公共操作", "desc": "系统级基础操作" },
 *     "project": { "dir": "01-project", "name": "项目管理", "desc": "项目生命周期管理" }
 *   }
 */

const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);

let INPUT_FILE = args[0] || './feature-list.txt';
let WORKSPACE = '.';
let MODULE_MAP_FILE = null;

// 解析参数
for (let i = 0; i < args.length; i++) {
  const arg = args[i];
  if (arg.startsWith('--workspace=')) {
    WORKSPACE = arg.split('=')[1];
  } else if (arg.startsWith('--module-map=')) {
    MODULE_MAP_FILE = arg.split('=')[1];
  } else if (arg.startsWith('--')) {
    // 忽略未知 flag
  } else if (i > 0) {
    // 第二个非 flag 参数作为 workspace
    WORKSPACE = arg;
  }
}

const WORKSPACE_DIR = path.resolve(WORKSPACE);
const OUTPUT_FILE = path.join(WORKSPACE_DIR, 'structure', 'tree.json');
const EXISTING_TREE_FILE = OUTPUT_FILE;

// 默认模块映射表
const DEFAULT_MODULE_MAP = {
  'common': { dir: '00-common', name: '公共操作', desc: '系统级基础操作，高复用场景' },
  'project': { dir: '01-project', name: '项目管理', desc: '项目生命周期管理' },
  'repository': { dir: '02-repository', name: '代码仓库', desc: '代码仓库与版本控制' },
  'pipeline': { dir: '03-pipeline', name: '流水线', desc: 'CI/CD 流水线管理' },
  'issue': { dir: '04-issue', name: '工作项', desc: '需求、缺陷、任务管理' },
  'wiki': { dir: '05-wiki', name: 'Wiki文档', desc: '知识库与文档管理' },
  'test': { dir: '06-test', name: '测试管理', desc: '测试用例与执行' },
  'deploy': { dir: '07-deploy', name: '部署发布', desc: '应用部署与发布' },
  'monitor': { dir: '08-monitor', name: '监控告警', desc: '系统监控与告警' },
  'setting': { dir: '09-setting', name: '系统设置', desc: '个人与系统配置' },
};

/**
 * 加载模块映射，优先级：
 * 1. --module-map 参数指定的 JSON 文件
 * 2. workspace 下已有的 structure/tree.json
 * 3. 内置 DEFAULT_MODULE_MAP
 */
function loadModuleMap() {
  const moduleMap = { ...DEFAULT_MODULE_MAP };
  const sources = [];

  // 1. 加载已有 tree.json 中的模块映射（跟随系统已有结构）
  if (fs.existsSync(EXISTING_TREE_FILE)) {
    try {
      const existing = JSON.parse(fs.readFileSync(EXISTING_TREE_FILE, 'utf-8'));
      if (existing.modules) {
        for (const mod of existing.modules) {
          const key = mod.dir?.replace(/^\d+-/, '') || mod.name;
          moduleMap[key] = { dir: mod.dir, name: mod.name, desc: mod.description || mod.desc };
        }
        sources.push(`已有 tree.json (${EXISTING_TREE_FILE})`);
      }
    } catch (e) {
      console.warn(`⚠️ 读取已有 tree.json 失败: ${e.message}`);
    }
  }

  // 2. 加载用户指定的 module-map.json（最高优先级）
  if (MODULE_MAP_FILE) {
    const mapPath = path.resolve(MODULE_MAP_FILE);
    if (!fs.existsSync(mapPath)) {
      console.error(`❌ 指定的模块映射文件不存在: ${mapPath}`);
      process.exit(1);
    }
    try {
      const customMap = JSON.parse(fs.readFileSync(mapPath, 'utf-8'));
      for (const [key, value] of Object.entries(customMap)) {
        moduleMap[key.toLowerCase()] = {
          dir: value.dir,
          name: value.name,
          desc: value.desc || value.description || '自定义模块'
        };
      }
      sources.push(`自定义映射 (${mapPath})`);
    } catch (e) {
      console.error(`❌ 解析模块映射文件失败: ${e.message}`);
      process.exit(1);
    }
  }

  if (sources.length > 0) {
    console.log(`📚 已加载模块映射来源: ${sources.join(' + ')}`);
  }

  return moduleMap;
}

/**
 * 获取下一个可用的模块编号目录
 */
function getNextModuleDir(usedDirs, key) {
  const existingNumbers = usedDirs
    .map(d => {
      const match = d.match(/^\d+/);
      return match ? parseInt(match[0], 10) : -1;
    })
    .filter(n => n >= 0);

  const maxNumber = existingNumbers.length > 0 ? Math.max(...existingNumbers) : 0;
  const nextNumber = maxNumber + 1;
  return `${String(nextNumber).padStart(2, '0')}-${key}`;
}

function toFileName(desc) {
  return desc
    .replace(/[\/\\:*?"<>|]/g, '')
    .trim()
    .replace(/\s+/g, '-')
    + '.json';
}

function inferModuleKey(desc) {
  const lower = desc.toLowerCase();
  if (lower.includes('登录') || lower.includes('退出') || lower.includes('切换')) {
    return 'common';
  } else if (lower.includes('项目')) {
    return 'project';
  } else if (lower.includes('仓库') || lower.includes('代码') || lower.includes('提交')) {
    return 'repository';
  } else if (lower.includes('流水线') || lower.includes('构建') || lower.includes('部署')) {
    return 'pipeline';
  }
  return 'others';
}

function isLoginFile(fileName, desc) {
  const text = `${fileName} ${desc}`.toLowerCase();
  return text.includes('login') || text.includes('登录');
}

function parseFeatureList(content, moduleMap) {
  const lines = content.split('\n').filter(l => l.trim() && !l.trim().startsWith('#'));
  const modules = {};
  const usedDirs = new Set(Object.values(moduleMap).map(m => m.dir));

  for (const line of lines) {
    const parts = line.split('|').map(s => s.trim());
    let moduleKey, desc;

    if (parts.length >= 2) {
      moduleKey = parts[0].toLowerCase();
      desc = parts[1];
    } else {
      desc = parts[0];
      moduleKey = inferModuleKey(desc);
    }

    let modInfo = moduleMap[moduleKey];
    if (!modInfo) {
      // 未知模块：自动分配下一个编号目录
      const nextDir = getNextModuleDir([...usedDirs], moduleKey);
      modInfo = {
        dir: nextDir,
        name: moduleKey,
        desc: `自定义模块: ${moduleKey}`
      };
      moduleMap[moduleKey] = modInfo;
      usedDirs.add(nextDir);
      console.log(`⚠️ 发现未定义模块键 "${moduleKey}"，已自动分配目录: ${nextDir}`);
    }

    if (!modules[modInfo.dir]) {
      modules[modInfo.dir] = {
        dir: modInfo.dir,
        name: modInfo.name,
        description: modInfo.desc,
        files: []
      };
    }

    modules[modInfo.dir].files.push({
      name: toFileName(desc),
      desc: desc,
      required: true,
      dependencies: []
    });
  }

  // 识别公共登录依赖
  const commonDir = '00-common';
  if (modules[commonDir]) {
    const loginFile = modules[commonDir].files.find(f => isLoginFile(f.name, f.desc));
    if (loginFile) {
      loginFile.dependents = [];
    }
  }

  // 为其他模块文件添加默认登录依赖
  for (const [dir, mod] of Object.entries(modules)) {
    if (dir === commonDir) continue;
    for (const file of mod.files) {
      const loginDep = modules[commonDir]?.files.find(f => isLoginFile(f.name, f.desc));
      if (loginDep) {
        file.dependencies.push(`${commonDir}/${loginDep.name}`);
        loginDep.dependents.push(`${dir}/${file.name}`);
      }
    }
  }

  return {
    version: '1.0',
    generatedAt: new Date().toISOString(),
    product: 'CodeArts',
    modules: Object.values(modules).sort((a, b) => a.dir.localeCompare(b.dir))
  };
}

function main() {
  if (!fs.existsSync(INPUT_FILE)) {
    console.error(`❌ 未找到功能清单文件: ${INPUT_FILE}`);
    console.log('请创建功能清单文件，格式如下:');
    console.log('  common|登录系统');
    console.log('  common|退出登录');
    console.log('  project|创建项目');
    console.log('  project|删除项目');
    console.log('\n如需自定义模块映射:');
    console.log('  node generate-tree.js feature-list.txt --module-map=module-map.json');
    process.exit(1);
  }

  const moduleMap = loadModuleMap();
  const content = fs.readFileSync(INPUT_FILE, 'utf-8');
  const tree = parseFeatureList(content, moduleMap);

  const dir = path.dirname(OUTPUT_FILE);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });

  fs.writeFileSync(OUTPUT_FILE, JSON.stringify(tree, null, 2), 'utf-8');

  console.log(`\n✅ tree.json 生成成功: ${OUTPUT_FILE}`);
  console.log(`📊 共 ${tree.modules.length} 个模块, ${tree.modules.reduce((s, m) => s + m.files.length, 0)} 个原子操作`);

  console.log('\n📁 目录结构预览:');
  for (const mod of tree.modules) {
    console.log(`  ${mod.dir}/ (${mod.name})`);
    for (const file of mod.files) {
      const depMark = file.dependencies?.length ? ' [←依赖]' : '';
      const depByMark = file.dependents?.length ? ` [被${file.dependents.length}个文件依赖]` : '';
      console.log(`    ${file.name} — ${file.desc}${depMark}${depByMark}`);
    }
  }
}

main();
