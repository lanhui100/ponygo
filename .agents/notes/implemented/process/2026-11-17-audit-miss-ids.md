# Agent Note: 审计四问的项级稳定 id 与 miss_ids 补全

Status: implemented

## Problem

`ponygo audit --json` 的 `miss_ids` 只承载"级判据 + gap"（如 `2.3` / `no_decisions`），
四问打分的那 16 个计分项**没有稳定 id**：实测 15/16 命中时 `miss_ids:[]`（W0 审计同类观测），
机器面因此丢信息——按 JSON 消费的下游只知道"少了一项"，不知道**少的是哪一项**，也无法据此
跟踪"补了没有"（同一份输出在补齐前后无法 diff）。

## Decision

1. 四问的每个计分项分配**冻结 id**（16 个，形如 `q1.rejected_trace` / `q2.gate_spec_paired` /
   `q4.sealed_archive`；S 档出现其中非 M 的 11 个），计分改走统一入口 `audit_item <id> <ok>`：
   `total++`，`ok` 时 `hit++`，否则把 id 记入 `AUDIT_MISS_IDS`。
2. `miss_ids` = 级判据 fail ∪ gap id ∪ 项级未命中（去重、保持首次出现顺序）；
   `ponygo audit --json` 的 `hits`/`total` 与整份 schema **不变**——这是机器面补全，不是重打分。
3. 人读面**追加**一行 `未命中项：<id> <id> …`（零未命中时完全不打印），既有行一字不改。

## Alternatives considered

- **给每项算 hash 作 id**：否决——id 要能被文档引用与人工排查，语义化命名的可读性远高于不可变哈希；
  稳定性由"冻结表 + 代码审查"保证（改动 id 即改契约，需同批改文档与测试）。
- **只把 miss 数量写进 JSON（`miss_count`）**：否决——数量不定位，等于把"哪项没达标"留给猜。
- **重排/重算四问分数以对齐 id**：否决——计分口径是已发布契约（S 12 / M 16、命中数被多套测试钉死），
  id 补全不得顺手动分数（本批实测 hits/total 前后一致）。
- **把 miss 项写进 `gaps`**：否决——`gaps` 是"最小改进动作"的目录（人读段落 + 修法），
  项级未命中是打分事实而非缺口条目；混在一起会让 `gaps` 从"该做什么"退化成"哪项没得分"。

## Consequences

- 同一份 `audit --json` 现在可以在补齐前后 diff：`q1.rejected_trace` 消失即证明那一项真的补上了。
- id 成为契约：改名 = 破坏性变更（下游可能按 id 记账），改 id 必须同批改 `audit/checklist.md`
  与测试，并在 ADR 里登记。
- 人读面多一行（零未命中时不出现），旧消费者按行前缀匹配不受影响。
