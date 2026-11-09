# Agent Note: 治理根布局（双根：`.meta/` 机器态 + `.agents/` agent 资产）与 meta.yaml 键白名单铁律

Status: implemented

## Problem

治理体系需要一个可寻址的根目录承载宪法、决策、门禁、技能、文档分层五类资产（当时设想用**单根**
`.meta/` 全部承载；现行形状是双根，见 Decision），
同时需要一个状态文件标记成熟度。状态文件若承载多字段（版本/组件清单/演进记录），
字段间互相派生、手填必漂移——重演"行与文件夹不一致"的老问题。

## Decision

治理根是**双根**，不是单根 `.meta/`（本条原裁决的"单根 .meta/"形状已被
`implemented/architecture/2026-08-31-agents-runtime-vs-meta-truth.md` 部分取代；下面是现行形状）：

| 根 | 内容 | 为什么在这里 |
|---|---|---|
| `.meta/` | `constitution/`（宪法，单一真相源）+ `gates/`（门禁 + 负样本 spec）+ `docs-tier/`（文档分层约定）+ `meta.yaml`（状态文件） | 治理的**机器态与真源**：由投影（`ponygo sync`）与钩子（`pre-commit` / CI）消费，不需要 agent 主动发现 |
| `.agents/` | `notes/`（决策记录，lifecycle × class 双轴）+ `skills/`（可复用流程技能） | AI agent **运行时读写**的资产：必须在工具发现路径上（notes 进检索面、skills 进路由面） |

分家原则：能被工具自动加载/发现的资产放 `.agents/`；只能被命令消费的机器态放 `.meta/`。
决策记录与技能**不在** `.meta/` 下——`ls .meta` 只有上表四项（`constitution/`、`docs-tier/`、
`gates/`、`meta.yaml`），决策在 `.agents/notes/`、技能在 `.agents/skills/`。

`meta.yaml` 的合法键恰为三个——`level` / `ai-surface` / `docs-tier`：
`level` 是成熟度级的唯一真值源，`ai-surface` 与 `docs-tier` 是开关声明（`on`/`off`，不能由目录
存在性推导，故必须显式落盘）；版本由 git 派生，组件清单由目录存在性充当，演进记录由 git 历史 +
决策记录充当。
出现其它键由 `ponygo status`/`audit` 双挂 WARN（不改退出码）。
决策双轴编码进路径：`.agents/notes/{lifecycle}/{class}/yyyy-mm-dd-topic-title.md`，
lifecycle 四态 + class 六类封闭集合（classes.local 开放领域扩展）。

## Alternatives considered

- **多字段 yaml（版本/组件/成熟度并记）**：否决——凡能被机械推导的东西不冗余声明，
  推导源（git、目录）与手填副本必然漂移。
- **决策标签写在文件 frontmatter 里**：否决——文件夹即标签，路径与内容二选一，
  双写必漂移（methodology §2.1 实证）。
- **治理根用 `docs/` 或根目录散放**：否决——`docs/` 是文档家，拿它当治理根会让机器态与人类文档
  混住；"可被 `test -d` 一条命令判有无"这条理由只要求**每类资产各自的父目录**可判（现行为两根：
  `.meta/` 与 `.agents/`），不需要单一根。

## Consequences

- 骨架完整度、决策数、级判据全部可由 `find`/`grep`/`test` 机械判定（P2 落地）。
- meta.yaml 的键白名单写死在 CLI 的 `warn_meta_violations`，是规格的一部分。
