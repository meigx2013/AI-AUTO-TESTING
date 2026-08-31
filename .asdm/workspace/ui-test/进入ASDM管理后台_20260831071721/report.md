# 进入ASDM管理后台 - 执行报告

> **执行时间**：2026-08-31 07:52:46
> **用例文件夹**：`.asdm\workspace\ui-test\进入ASDM管理后台_20260831071721`

---

## 一、执行总览

| 指标 | 数值 |
|------|------|
| 场景总数 | 1 |
| 执行成功 | 1 |
| 执行失败 | 0 |
| 跳过执行 | 0 |
| 总耗时 | 约 9 秒 |
| 通过率 | 100% |

## 二、自愈记录

| 场景 | 失败步骤 | 失败类型 | 是否自愈 | 说明 |
|------|---------|---------|---------|------|
| SC-001 | assert-2 | 断言失败（title 期望过时） | ✅ 已修复（人工确认后） | 按转人工清单建议修改脚本：title 断言由精确匹配 `grep -x "ASDM"` 改为包含匹配 `grep -q "ASDM"`，脚本 `@step` 注释旁已追加 `# @healed 2026-08-31` 留痕；重跑通过（exit 0） |

**修复根因**：录制快照（assertedEvents）中 title 为 `ASDM`，当前 SPA 路由完成后 title 动态更新为 `ASDM | 平台概览`，原 `grep -x` 整行精确匹配失败；URL `/projects` 断言始终稳定满足，业务目标实际已达成。

## 三、各场景执行详情

### 场景 SC-001：001-门户导航-从门户进入管理控制台

| 属性 | 值 |
|------|------|
| 脚本文件 | `001-门户导航-从门户进入管理控制台.sh` |
| 优先级 | P0 |
| 执行状态 | ✅ 成功 |
| 依赖场景 | — |
| 耗时 | 约 9 秒 |
| 断言通过/总数 | 2/2 |

**控制台输出**：

```
==========================================
  SC-001: 门户导航-从门户进入管理控制台
==========================================
[STEP:step-1:START] 导航: 打开平台门户首页
  → 打开 https://platform-sit01.asdm.ai/portal/ 并设置视口 1692x787
✓ Done
[STEP:step-1:OK]
[STEP:assert-1:START] 断言: 门户首页加载成功
✅ 断言通过: 门户首页加载成功（title: "ASDM AI资源中心"）
[STEP:assert-1:OK]
[EXEC:START] SC-001 | 门户导航-从门户进入管理控制台
[LOGIN:CHECK] URL: https://platform-sit01.asdm.ai/portal/
[LOGIN:CHECK] cookies: "token=eyJhbGciOiJIUzUxMiJ9.eyJzdWIiOiIxIiwidXNlcm5hbWUiOiJzdXBlci1hZG1pbkBhc2RtLmFpIiwiaWF0IjoxNzg4MTYxODI4LCJleHAiOjE3OTA3NTM4Mjh9.Ft7blnU2dJya7uqQGdo0P9TDCqwnPC80jYS0-9mp9k9A2ZghM69FqqP8TRSwuvsGX56afEkH4m_O8XhJVF64mg"
[LOGIN:SKIP] ✅ cookie 检测到会话 (token )，已登录，跳过登录流程
[STEP:step-2:START] 点击: 点击页头用户头像按钮
  → 点击页头用户头像按钮（登录后 header 内按钮即用户头像，采用与录制 xpath 同位的稳定简化 CSS「header button」；录制 CSS div.css-6su6fj 为 emotion 哈希类，不稳定仅作备选）
✓ Done
[STEP:step-2:OK]
[STEP:step-3:START] 点击: 点击「控制台管理」菜单项
  → 点击用户下拉菜单中的「控制台管理」菜单项（menuitem 有显式 ARIA role，find role menuitem 实测稳定；text/ 前缀对嵌套 StaticText 中文节点匹配不稳定；备选 CSS li:nth-of-type(2) 依赖菜单位次）
✓ Done
[STEP:step-3:OK]
[STEP:assert-2:START] 断言: 已进入 ASDM 管理后台
✅ 断言通过: 已进入 ASDM 管理后台（URL: https://platform-sit01.asdm.ai/projects, title: "ASDM | 平台概览"）
[STEP:assert-2:OK]
✅ SC-001 门户导航-从门户进入管理控制台 - 执行成功！
[EXEC:END] SC-001 | 成功
```

**说明**：执行成功

---

## 四、变量传递记录

| 变量名 | 产生场景 | 值 | 消费场景 | 状态 |
|--------|---------|-----|---------|------|
| 场景编号 | 依赖数据文件 | — | 依赖数据项 | ✅ 数据文件就绪 |
| SC-001 | env.json, accounts.json | — | baseUrl, superAdmin.username/password | — |

## 五、执行结论

- **结论**：通过（成功 1 / 失败 0 / 跳过 0）

## 六、断言覆盖情况

| 指标 | 数值 |
|------|------|
| 操作步骤总数 | 3 |
| 断言步骤总数 | 2 |
| 断言通过率 | 2/2 |
| 断言占比（断言步骤数 / 操作步骤数） | 66.7% |

### 各场景断言明细

| 场景编号 | 断言步骤数 | 通过 | 失败 | 未执行 |
|---------|-----------|------|------|--------|
| SC-001 | 2 | 2 | 0 | 0 |

## 七、转人工清单

无（全部场景执行通过，无需转人工）。

---

> **报告生成时间**：2026-08-31 07:52:46

> 本报告由 collect-report.js 机械生成（执行 + 标记解析）。选择器转换/自愈等需语义判断的部分仍建议由 AI 处理。