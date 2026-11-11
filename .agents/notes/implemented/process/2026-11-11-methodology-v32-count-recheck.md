# Agent Note: 方法论 v3.2 —— dsh 计数复核与复活条件落点修正

Status: implemented

## Problem

`docs/methodology.md` v3.1（2026-11-10）按 dsh `de5d733a18` 复核的结果，仍有两处计数与源码不符、一处落点易被误指：

1. §0/§9 写「implemented 298 活态」，按同一提交去重计数实为 **296**（§2.1 六类合计 40+11+13+180+34+18=296 自洽；298 系误计 `.agents/notes/implemented/` 目录内的 AGENTS.md / CLAUDE.md 两个文档文件）。
2. §5.5 写「4 组 acp/sdk/session/web、250 个 `snapshot.yml`」，同提交跟踪实为 **363 个**。
3. §7.1 只写「复活条件立法」，未标注 dsh 落点——系列文章第 6 篇据此把复活条件误指到 `.agents/notes/rejected/simplification/`，而源码中 `## Reintroduction conditions` 段落在 **implemented/simplification** 笔记（如 `2026-09-11-remove-e2b-providers`），rejected 语料只冻结否决判据、不承载复活条件（`grep -l Reintroduction .agents/notes/rejected/simplification/*.md` 零命中）。

不修正的代价：方法论自称「先找磁盘证据再打分」，正文数字与 dsh 现状不一致会击穿 §9 记分卡的证据纪律；落点含糊则让实例的读者照系列文章把复活条件写进 rejected 目录，制造错误形状。

## Decision

把 `docs/methodology.md` 升到 v3.2，四处改动同提交进正文与版本记录（历史版本条目不回改，按文档自身规则保留发布时取值）：

- §0 决策记忆行与 §9 记分卡第 1 问：`implemented 298 活态` → **296**。收据：`git ls-files .agents/notes/implemented | grep -v 'AGENTS.md\|CLAUDE.md' | sed -E 's/\.(i18n\.yaml|zh\.md|md)$//' | sort -u | wc -l` = 296；六类（feature 40 / bug-fix 11 / simplification 13 / architecture 180 / process 34 / testing 18）合计 = 296。
- §5.5 snapshots 行：`250 个` → **363 个**（四组 acp 11 / sdk 40 / session 239 / web 64 = 354，另有 `packages/test-support/session-snapshot` fixtures 9）。收据：`git ls-files | grep -c 'snapshot\.yml$'` = 363。
- §7.1：复活条件立法句补 dsh 实例落点——`## Reintroduction conditions` 段落在 implemented/simplification 笔记，rejected 语料只冻结否决判据、不承载复活条件。
- 状态头升 v3.2；版本记录追加 v3.2 条目（含上述三项的变更理由与收据命令）。

## Alternatives considered

- **只改两处数字，不补 §7.1 落点**：否决——落点含糊正是系列文章第 6 篇误指 rejected/simplification 的成因；补一行实例标注即消除歧义，成本低于事后纠偏文章。
- **新建独立章节「dsh 复活条件」展开落点**：否决——方法论 §7 是工艺层，一个段落的落点用（dsh 实例：…）就地标注即可，展开成章节超出该承诺的可验证范围。
- **把 v3.2 并入 v3.1 决策记录（2026-11-10-methodology-v31-dsh-source-recheck）**：否决——v3.1 记录的 Decision 已定稿且指向 v3.1 版本记录；v3.2 是新一轮复核结果，独立成记录才与版本记录逐版对齐。同属「持续复核 dsh」义务的延续（v3.1 Consequences 已声明该义务）。
- **按新扫描把 §4.5 的脚本数（29/14）一并复核改写**：否决——「29 个具名脚本」指 §4.5 枚举的具名脚本集，非全量 `verify-*.ts`（实测 76 个）；口径需原始扫描定义才能判，超出本次两处 P1 数字范围，留待下一轮复核。

## Consequences

- 方法论正文与同提交 dsh 现状一致：§0 与 §2.1 分类合计自洽（296），§5.5 快照体量可复跑验证；§7.1 落点标注消除了系列文章误读的唯一歧义源。
- 系列文章第 6 篇的错漏（`357→358`、复活条件落点、四件套清单）在 ponyfun 侧单独改稿，本文档不代改文章（沿用 v3.1 记录的分工）。
- 持续复核义务不变：下次 dsh 源码迁移后按 §9 抽查法复查 §0/§2.1/§5.5 的计数取数命令是否仍成立。