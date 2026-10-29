# docs-tier/ —— 文档分层契约（按 tier 分类法给每个事实安一个家）

## 已激活文档家清单

**已激活（2026-10-29 起；判据 2.5 机械检查本标题与下方家清单）。**
本仓同时是框架模板源与一个已激活实例：`ponygo init` 生成的副本仍是**模板态**（含待填占位），
本文件是**本仓自己的激活版**——这也是 `ponygo upgrade` 对本文件豁免漂移比对的原因
（见 `ponygo` 的 `cmd_upgrade` 中 `dt_skip` 分支）。

> 原理出处：本文的 methodology 引用指向框架仓库的 `docs/methodology.md`
> <https://github.com/lanhui100/ponygo/blob/main/docs/methodology.md>。原理层唯一真相源在框架仓库，
> 实例不复制——复制即漂移。

## tier 分类法（本仓已填；原理：methodology §5.1）

每一 tier 的「该承载什么 / 不该承载什么」必须写死——只写"放什么文档"的 tier 表会漂移。
家载体分工：**AGENTS.md**（agent 自动加载的治理规则）与 **README**（人读契约）不混用。

| tier | Job（该承载） | 不承载 | 本项目家 |
|---|---|---|---|
| 常载命约 | 每次会话必载的 standing orders，1-3 行每条，链到 home | 故事/示例/复述 | `AGENTS.md`（`ponygo sync` 投影）+ 真源 `.meta/constitution/constitution.md` |
| 文档标准 | tier 分类 / 写作规则 / slop checklist | 具体文档正文 | `docs/AGENTS.md` |
| 架构地图 | 组合、核心模块、接缝、扩展点（有序地图） | 类型细节/决策理由/状态标注 | `docs/methodology.md`（原理与分层）+ `README.md` 的目录结构（骨架地图） |
| 决策记录 | 活动决策（当前态现在时） | 迁移计划/验收清单 | `.agents/notes/`（实例决策）+ `revisions/`（框架自身演进：笔记记"为什么"，revision 记"框架怎么变"） |
| 事故复盘 | 事故年表、证据、因果链、预防 | 教学叙事 | `.agents/notes/implemented/bug-fix/`（不设独立 postmortem 目录：单维护者场景下"事故即一次决策"，两条轨道会互相漂移，理由见 `2026-10-29-activate-docs-tier.md`） |
| how-to | 带编号验证步的操作指引 | 设计理由（→ 决策记录） | `checklists/`（`init.md` / `audit.md` / `observe-init.md` / `observe-audit.md`） |
| 用户文档 | 产品面向指南 | 贡献流程/决策史 | `README.md`（人读契约：安装、命令、升级路径） |
| 包/模块契约 | 单模块配置/语义/限制/扩展点 | 逐行注释复述 | 不适用——单文件 CLI（`ponygo`），无包目录；接口由 `ponygo --help` 自述 |
| 生成参考 | 从源码再生成的参考 + 新鲜度门禁 | 手编生成源 | `ponygo --help`（CLI 自身产出，无手编副本；`audit/` 与 `checklists/` 是人读判据，不是生成物） |

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
本仓暂不设数值上限（单维护者、doc-sync 门未启用）；启用时把数值写在本节，不留占位。
