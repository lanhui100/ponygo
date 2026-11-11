# Agent Note: 方法论 v3.3 —— dsh 门禁统计口径复核

Status: implemented

## Problem

`docs/methodology.md` v3.2（2026-11-11）已预留两处口径待复核（v3.2 记录 Consequences 声明"29 个具名脚本"口径需原始扫描定义才能判，留待下一轮）。按 dsh `de5d733a18` 的 `scripts/run-gates.ts` 与 `scripts/*.spec.ts` 实存文件复核后，两处均有可复现的修正：

1. §4.5 负样本覆盖写「29 个具名脚本中 14 个有同名 `*.spec.ts`（≈48%）」——该口径无命令可复现：全仓 `scripts/verify-*.ts` 实为 76 个、同名 `*.spec.ts` 30 个（≈39%）；按 §4.5 逐一点名集核查为 19 个 verify/check/coverage 脚本中 8 个同名 spec、13 个 gen 生成器中 9 个、`run-gates` 自带 `run-gates.spec.ts`。「29/14」既不对应点名集也不对应全仓，继续保留会让读者无法依据本文复验，击穿 §9 记分卡"先找磁盘证据再打分"的纪律。
2. §0 文档分层行写「doc-sync 42 门」——`run-gates.ts` `case 'doc-sync'` 直接返回 `docSyncLeafGates()`，实测 43 个叶门（`quick: true` 21 个）；「42」无命令可复现（可能系不含 doc-typecheck 或按聚合再取的旧口径）。

不修正的代价：方法论自称以 dsh 为实证案例且每章须回答"如何被验证"，两处不可复现的统计会诱使读者照文章把「每个门都有负样本」当作现状，或把 doc-sync 门数与源码对不上号。

## Decision

把 `docs/methodology.md` 升到 v3.3，三处改动同提交进正文与版本记录（历史版本条目不回改，按文档自身规则保留发布时取值）：

- §4.5 负样本句改双口径：点名集 19 个 verify/check/coverage 脚本中 8 个同名 `*.spec.ts`（另 `run-gates` 自带 `run-gates.spec.ts`）、13 个 gen 生成器中 9 个；全仓 `verify-*.ts` 76 个、同名 spec 30 个（≈39%）。保留原句的诚实结论：「'每个门都有负样本'是目标，不是现状」。
- §0 doc-sync 改「43 叶（docSyncLeafGates，quick 21）」。
- 状态头升 v3.3；版本记录追加 v3.3 条目（含两处修正的收据命令）。

收据（dsh `de5d733a18`）：
- `ls scripts/verify-*.ts | wc -l` = 76；`ls scripts/verify-*.spec.ts | wc -l` = 30。
- 点名集逐查：verify-agent-note-format / verify-agent-note-classification / verify-archived-agent-notes / doc-typecheck / verify-md-wrap / verify-mermaid / verify-doc-refs / verify-doc-budgets / verify-translation-pairing / verify-type-equiv / verify-export-jsdoc 无同名 spec；check-workspace-constraints / coverage-exempt / coverage-partitions / verify-md-links / verify-package-paths / verify-subsystem-pages / verify-repository-references / verify-concrete-terms 有同名 spec（8 个）；gen 点名 13 个中 9 个同名 spec；`run-gates.spec.ts` 存在。
- `run-gates.ts` `case 'doc-sync': return docSyncLeafGates()`；`docSyncLeafGates()` 内 `pnpmScript|pnpmExec` 叶门 43、`quick: true` 21。

## Alternatives considered

- **保留「29/14≈48%」并在版本记录里注明口径存疑**：否决——v3.2 已留"待复核"，本轮若再拖就是第二轮可见而不修；数据本身既非点名集也非全仓，读者无法复验，修订代价（一段话）低于继续存疑的信任成本。
- **只改全仓口径（30/76）放弃点名集**：否决——点名集口径更能回答"方法论 §4.5 介绍的门配了哪些负样本"，两者互补，双口径并存比选一更防误读；原文"由模块级 spec 或 workflow 形状契约间接覆盖"的补充句保留，覆盖无同名 spec 的脚本。
- **doc-sync 维持 42，改为"约 40 级"**：否决——方法论 §0 表格的守护者列以"可验证命令"立身，任何近似值都削弱该列的意义；实测 `case 'doc-sync'` 的精确叶门数就是 43，直接写实。
- **把两处修改并入 v3.2 决策记录**：否决——v3.2 记录的 Decision 已定稿并指向 v3.2 版本记录；v3.3 是新一轮复核结果，独立成记录才与版本记录逐版对齐（沿用 v3.2 记录同款理由）。

## Consequences

- 方法论正文两处统计以实存文件为准、命令可复跑：§4.5 负样本覆盖率（点名集 8/19 + gen 9/13、全仓 30/76≈39%），§0 doc-sync 43 叶（quick 21）。
- dsh 系列文章第 1 篇的「每个门禁脚本均配备负样本」过度宣称在 ponyfun 侧单独改稿，本记录不改文章（该方法论修订可为该改稿提供现成口径）。
- 持续复核义务不变：下次 dsh 源码迁移后按 §9 抽查法复查 §4.5 点名集与 doc-sync 叶门数的取数命令是否仍成立（新门/新生成器入场会改变这两个数）。