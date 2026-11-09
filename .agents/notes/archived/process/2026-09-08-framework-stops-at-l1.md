# Agent Note: 框架自身停在 L1（停止线裁决）——不升 L2 的理由与 L1→L2 可达性证据

Status: implemented

## Problem

TASK-002 的原始计划要求"ponygo 仓库自身升到 L2"（加门禁 + `.githooks/` + 激活 docs-tier +
`level: 2`），理由是"框架交付了升 L2 的说明书，自己却从未走过一次"。两份独立对抗审核
（`docs/dev-team/reviews/review-TASK-002-consultant.md` 与 architect 报告）各自独立指出：
该计划与仓库自己的停止线冲突，并把本机事实写进了仓库真值源。

| 冲突 | 证据 |
|---|---|
| 违反停止线 | `maturity-ladder.md` §6：「单人但决策密度 ≥ 1 条/周 → 保留 L1 + 上最轻的 L2（仅 format 门禁，**不上** classification / 冻结 / **文档分层**）」；实测本仓 1 位贡献者、24 commits |
| 判据判错对象 | 判据 2.4 = `git config core.hooksPath`（**本机**配置、不可提交）；提交 `level: 2` 后每个新鲜克隆都在声明它不满足的等级，CI 又从不跑 `ponygo status` |
| 自相矛盾 | 提交 `.githooks/pre-commit` 后 `audit` 的"无本地钩子"缺口行消失（条件是 `hooksPath 未设 且 ! -f .githooks/pre-commit`），而分层报告仍显示「本地层：无」 |
| 假 PASS | Windows 下新建文件 `git add` 记录 `100644`；POSIX 克隆上 Git 静默跳过不可执行的钩子，而 2.4 只查"目录非空" |
| 单源性缺口 | 激活 docs-tier 后仓库文件与模板必然分叉，s14 的逐字节断言（`review-EXTERNAL-001.md` P2-5 的处置）被迫放宽，会丢掉"模板改了、仓库副本没跟"的唯一看守 |

## Decision

1. **框架自身保持 `level: 1`**：不激活 docs-tier、不提交 `.githooks/`、不新建 docs-parity 门禁。
   升到 L2 是"规模值不值当"的价值判断（P6），当前规模下按 §6 不应上文档分层。
2. **L1→L2 的可达性由测试证明**：`tests/run.sh` 场景 28 在临时实例里跑通 L2 四件套
   （门禁脚本 + 负样本 spec + `core.hooksPath` 挂载 + docs-tier 激活），并断言撤掉 `hooksPath`
   后判据 2.4 会 FAIL。CI 双平台执行——这是"判据可被满足"的机械证据，且**不冒充**"框架自己是 L2"。
3. **只读命令的执行侧改为 opt-in**：见 `revisions/accepted/2026-09-08-spec-execution-opt-in.md`。
4. **§5/§6 矛盾登记为提案**：`proposed/process/2026-09-08-l2-minimal-representable.md`。

## Alternatives considered

- **升 L2，并把判据 2.4 改为"仓库可观察形状"**（钩子文件存在且索引为 `100755`，`hooksPath`
  挂载降为 WARN）：方向正确——2.4 确实判错了对象——但属框架规则变更、影响所有既有实例，
  与本次范围不匹配，拆为独立任务重开。
- **保持 L1 且什么都不做**：否决。那样"框架从未走过 L1→L2"的缺口仍无任何证据；场景 28 成本低、
  CI 可复跑，是本次唯一站得住的可达性证据。
- **激活 docs-tier 但保留 s14 逐字节断言**：不可能——激活后仓库文件必然与模板分叉，s14 必红；
  而放宽 s14 的代价是丢掉单源性看守（见上表最后一行）。

## Consequences

- 本仓库 `ponygo status` 继续报 L1 / exit 0；`ponygo audit` 继续报「无本地钩子」缺口——
  这是**诚实**的本机事实，不是待修缺陷。
- 框架"吃自己的狗粮"的范围止于 L1（决策入册 + 文档有家 + CI 回归门）；L2 机制由测试证明可达。
- 触发重开此决策的条件：贡献者 ≥ 2 人，或出现需要跨提交守住的硬约束（格式/分类/冻结），
  届时按 §6 阈值表重新评估并录新 decision。
