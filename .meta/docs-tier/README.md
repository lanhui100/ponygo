# docs-tier/ —— 本仓文档家激活清单

## 已激活文档家清单

> 本文只登记**本仓实例路径**。tier 职责、写作规则与 slop checklist 的唯一真源是
> `docs/AGENTS.md`；原理与 DSH 实证见 `docs/methodology.md` §5。本文不复制这些规则。

| tier | 本仓家 |
|---|---|
| 根 AGENTS.md | 真源 `.meta/constitution/constitution.md`；投影 `AGENTS.md` / `CLAUDE.md` |
| 文档标准 | `docs/AGENTS.md` |
| 架构地图 | `docs/architecture.md` |
| 决策记录 | 实例决策 `.agents/notes/`；框架冻结演进史 `revisions/`（只读，不作现行权威） |
| 包/模块契约 | 单文件 CLI 无包目录；命令契约由 `ponygo --help` 与根 `README.md` 承载 |
| how-to | `checklists/` |
| 事故复盘 | `.agents/notes/implemented/bug-fix/` |
| 用户文档 | `README.md` |
| 工程过程记录 | `docs/dev-team/` 与 `.dev-team/`（交付证据，不作当前产品契约） |
| 生成参考 | `ponygo --help` 的实时输出；无手编命令参考副本 |

**放置速查**：bug→事故复盘；理由→决策记录；过程→how-to；契约→模块 README；
standing orders→根 AGENTS.md + 理由链；交付过程证据→工程过程记录。
