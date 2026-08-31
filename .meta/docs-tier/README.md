# docs-tier/ —— 文档分层（按 tier 分类法给每个事实安一个家）

**首版（L3 及以下）此目录只有本文件。** 文档分层是 L3 的产物，依赖"文档已经多到
需要分层"这一事实——文档量少到读一遍就知道每个事实在哪时，tier 分层是净开销。

升到 L3 时，把下方模板表填成你的 `tier-taxonomy.md`，并补 slop checklist 与词数预算。

> **「原理」引用的出处**：本文的 methodology 引用指向 ponygo 框架仓库的
> `docs/methodology.md`：<https://github.com/lanhui100/ponygo/blob/main/docs/methodology.md>。
> 原理层唯一真相源在框架仓库，实例不复制——复制即漂移。

## tier 分类法模板（解冻 L3 时填写；原理：methodology §5.1）

每一 tier 的「该承载什么 / 不该承载什么」必须写死——只写"放什么文档"的 tier 表会漂移。

| tier | Job（该承载） | 不承载 | 本项目的家（路径，待填） |
|---|---|---|---|
| 常载命约 | 每次会话必载的 standing orders，1-3 行每条，链到 home | 故事/示例/复述 | 【TODO，如 根 AGENTS.md】 |
| 架构地图 | 组合、核心模块、接缝、扩展点（有序地图） | 类型细节/决策理由/状态标注 | 【TODO】 |
| 决策记录 | 活动决策（当前态现在时） | 迁移计划/验收清单 | `.meta/decisions/` |
| 事故复盘 | 事故年表、证据、因果链、预防 | 教学叙事 | 【TODO，如 docs/postmortem/】 |
| how-to | 带编号验证步的操作指引 | 设计理由（→ 决策记录） | 【TODO，如 docs/cookbook/】 |
| 用户文档 | 产品面向指南 | 贡献流程/决策史 | 【TODO】 |
| 包/模块契约 | 单模块配置/语义/限制/扩展点 | 逐行注释复述 | 【TODO，如各模块 README】 |
| 生成参考 | 从源码再生成的参考 + 新鲜度门禁 | 手编生成源 | 【TODO】 |

**放置速查**：bug→事故复盘；理由→决策记录；过程→how-to；契约→模块 README；
standing orders→常载命约 + 理由链。

## slop checklist（审计清单，原理：methodology §5.4）

- 同一条规则出现在多个家（留一个家，其余链过去）；
- 叙述历史/战争故事（previously/now/no longer——状态会腐烂）；
- 实现状态标注（"implemented!"/"future:"——布局与 manifest 携带状态，散文不携带）；
- 手抄目录/逐行注释复述（源码或生成器是权威）；
- 段落墙、强调通胀（到处都是 bold = 没有强调）。

## 词数预算（L3 选装）

standing-doc 设上限，超限按 **relocate → condense → raise** 顺序处理；
上限是护栏不是压减目标，目标线下保留至少 5% 余量。
