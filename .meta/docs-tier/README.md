# docs-tier/ —— 文档分层契约（按 tier 分类法给每个事实安一个家）

**当前状态：模板态（L2 未激活）。** v2.0 起文档治理前置：`docs/AGENTS.md` 是文档标准的家
（agent 自动加载），已在 L0 播种；本文件是 **tier 分层的契约**——升到 L2 时把它推进为
「已激活文档家清单」（判据 2.5 机械检查），填写下方每个 tier 在本项目的家。

**如何激活（升 L2 时）**：把本文件顶部的『模板态』一词所在标题改为「已激活文档家清单」，
并把下方表格「本项目家」列的 `【TODO】` 填成真实路径（已由骨架生成的标 `✓`）。

> **「原理」引用的出处**：本文的 methodology 引用指向 ponygo 框架仓库的
> `docs/methodology.md`：<https://github.com/lanhui100/ponygo/blob/main/docs/methodology.md>。
> 原理层唯一真相源在框架仓库，实例不复制——复制即漂移。

## tier 分类法（激活时填写；原理：methodology §5.1）

每一 tier 的「该承载什么 / 不该承载什么」必须写死——只写"放什么文档"的 tier 表会漂移。
家载体分工：**AGENTS.md**（agent 自动加载的治理规则）与 **README**（人读契约）不混用。

| tier | Job（该承载） | 不承载 | 本项目家（待填 / 骨架已生成标 ✓） |
|---|---|---|---|
| 常载命约 | 每次会话必载的 standing orders，1-3 行每条，链到 home | 故事/示例/复述 | `AGENTS.md` ✓（sync 投影） |
| 文档标准 | tier 分类 / 写作规则 / slop checklist | 具体文档正文 | `docs/AGENTS.md` ✓（init 播种） |
| 架构地图 | 组合、核心模块、接缝、扩展点（有序地图） | 类型细节/决策理由/状态标注 | 【TODO】 |
| 决策记录 | 活动决策（当前态现在时） | 迁移计划/验收清单 | `.agents/notes/` ✓ |
| 事故复盘 | 事故年表、证据、因果链、预防 | 教学叙事 | 【TODO，如 docs/postmortem/】 |
| how-to | 带编号验证步的操作指引 | 设计理由（→ 决策记录） | 【TODO，如 docs/cookbook/】 |
| 用户文档 | 产品面向指南 | 贡献流程/决策史 | 【TODO】 |
| 包/模块契约 | 单模块配置/语义/限制/扩展点 | 逐行注释复述 | 各包 README（L1 判据 1.9 督促补齐） |
| 生成参考 | 从源码再生成的参考 + 新鲜度门禁 | 手编生成源 | 【TODO】 |

**放置速查**：bug→事故复盘；理由→决策记录；过程→how-to；契约→模块 README；
standing orders→常载命约 + 理由链。

## slop checklist（审计清单，原理：methodology §5.4）

- 同一条规则出现在多个家（留一个家，其余链过去）；
- 叙述历史/战争故事（previously/now/no longer——状态会腐烂）；
- 实现状态标注（"implemented!"/"future:"——布局与 manifest 携带状态，散文不携带）；
- 手抄目录/逐行注释复述（源码或生成器是权威）；
- 段落墙、强调通胀（到处都是 bold = 没有强调）。

## 词数预算（doc-sync 门，L2 选装）

standing-doc 设上限，超限按 **relocate → condense → raise** 顺序处理；
上限是护栏不是压减目标，目标线下保留至少 5% 余量。
