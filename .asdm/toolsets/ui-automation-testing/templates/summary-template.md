# 输出摘要模板

以下为测试步骤设计完成后的总览摘要模板（`### 8. 输出总览摘要`）。

---

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  📋 测试步骤设计完成
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  需求: <需求描述>
  用例文件夹: .asdm/workspace/ui-test/<用例名称>_<时间戳>/

  📄 测试步骤文档: test-step-design.md
     ├─ 场景数: <N> 个
     │  ├─ <编号>: <场景名称> (<优先级>)
     │  └─ <编号>: <场景名称> (<优先级>)
     ├─ 页面总数: <N> 个
     └─ 步骤总数: <N> 步

  📋 录制清单工作区: recording-checklist/
     ├─ structure/tree.json       ← <N> 个原子操作，由 generate-tree.js 生成
     ├─ recording-checklist.md    ← 可视化清单，由 check.js 生成
     └─ 需要录制的脚本: <N> 个
        ├─ 🔴 recordings/<模块>/<文件>.json (<依赖说明>)
        ├─ 🟡 recordings/<模块>/<文件>.json
        └─ ⚪ recordings/<模块>/<文件>.json

  📁 数据骨架: data/
     ├─ env.json        ← 请确认 baseUrl
     ├─ accounts.json   ← 请补充密码
     └─ business.json   ← 已预填业务数据

  ▶️ 下一步:
     1. 按 recording-checklist.md 完成人工录制
     2. 运行 node .asdm/toolsets/ui-automation-testing/scripts/check.js <workspace> --all 更新清单
     3. 运行 /asdm-ui-test-design-generate 以生成自动化测试脚本
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
