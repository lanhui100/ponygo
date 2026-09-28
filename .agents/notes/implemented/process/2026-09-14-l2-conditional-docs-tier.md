# Agent Note: 让"最轻的 L2"在判据里可表示——判据 2.5 条件化（docs-tier: on|off）

Status: implemented

## Problem

`maturity-ladder.md` §6 的停止线表对"单人 + 决策密度 ≥ 1 条/周"建议「保留 L1 + 上最轻的 L2
（仅 format 门禁，不上 classification / 冻结 / 文档分层）」；但 §5 的 L2 判据是 2.1–2.5 全项，
其中 2.5 = 文档分层已激活，`ponygo` 在 `level >= 2` 时把 2.1–2.5 全部当硬判据。照 §6 行事的
单实例 `ponygo status` 必 FAIL——§6 承诺的中间态在 §5 里不可表示（TASK-002 双审各自独立发现）。

## Decision

按 consultant 三选一裁决（Q1=A，`docs/dev-team/reviews/review-TASK-003-consultant.md`），
判据 2.5 改为**条件判据**，声明载体 = `meta.yaml` 的 `docs-tier: on|off` 键：

- **undeclared = SKIP + WARN 催声明**（不计入 PASS，也不判 FAIL）；
- **off = 显式 opt-out**（结论行改写为「2.1–2.4 PASS；2.5 未启用」，禁写"全部 PASS"；
  建议录一条 decision 说明为何不上文档分层）；
- **on + 家清单仍有 `【TODO】` 残留 = FAIL**；on + 模板态未激活同样 FAIL；
- **off + 已激活 = 矛盾 WARN**（声明与事实不符，催对齐）；
- **undeclared + 已激活 = PASS**（实际做到优先于声明）；
- 引号/空白/非法值（yes/true/大写/空）**不得兑现 on/off 语义**——白名单正则
  `^docs-tier:[[:space:]]*(on|off)$` 判非法键 WARN，状态机值读取只剥 `\r` 不剥引号/空白，
  任何变体落"未声明"支（保守方向，无绕过 FAIL 的路径）；
- 仅 `level >= 2` 生效（L1 声明 docs-tier: on 被忽略，静默），`lv >= 3` 同 L2 分支处理。

框架规则细节（含否决的替代方案、采纳理由、影响面）见 `revisions/accepted/2026-09-14-l2-conditional-docs-tier.md`。

## Alternatives considered

- **保持现状（L2 必须全项），删掉 §6「最轻 L2」改为"停在 L1"**：否决（consultant Q1 否决 C）。
  丢掉"只上 format 门禁"这个真实中间态，等于用删建议消解矛盾。
- **把 2.5 降级为 WARN**：否决（Q1 否决 B）。文档分层失去机械看守，与 v2.0「文档治理前置」冲突。
- **通配"存在即声明"（目录存在=已启用）**：否决。目录 init 即生成模板态，`exemptions` 已在目录下，
  通配会误触发（L2 评审遗漏边界条）。

## Consequences

- `ponygo` 的 `verify_ladder` 2.5 条件化 + `warn_meta_violations` 白名单加 docs-tier +
  meta.yaml heredoc 注释 + 结论行改写；`maturity-ladder.md` §1/§5/§6/§附同步；
  `.meta/meta.yaml` 铁律注释、`README.md` §4.1 键说明同步；
- `tests/run.sh` s12 四分支六用例（含 off+已激活矛盾 WARN、on+无 TODO PASS、引号值回归）、
  s13 新键/缩进/非法值、s28 作用域（L1+on 忽略）；
- 与 v2.0 无冲突：前置的是"有家"（0.5/1.9），条件化的是"分层激活"（2.5），两层不是同一物。

> 实证出处注：条件判据形态源自 TASK-002 双审对 §5/§6 矛盾的独立发现与 TASK-003 consultant
> 三选一裁决；本仓库为 ponygo 框架自身实例，docs-tier 保持未声明（level: 1 不验 2.x），零影响。