# Agent Note: s90 移出 CORE 层，windows-core 预算 90 → 60 分钟（收回 B026 的目标预算）

Status: implemented

## Problem

`2026-11-18-windows-core-budget` 把 `windows-core` 的 job 预算从 60 提到 90 分钟，并在该记录里写明
「**目标不是长期 90 分钟**：把 s90 的 Windows 成本降下来后，应把预算收回 60」，同时列出三个降本候选，
其中「把 s90 整体移出 CORE」被标注为**本批不采纳**。理由是当时的判断：`gh6` 的 Windows 专属预算断言
会因此失去 PR 级看守。该条由此落成 backlog **B026**。

90 分钟的预算是「不取消」的权宜，不是目标态。它的代价是**反馈变慢**：Windows PR 要跑满一小时才出结论，
而其中近四成时间花在 s90（`gate-hardening` 折叠套件）。

实测（CI run `44875119390` / job `135251130159`，2026-11-21，总 **62m17s**）：

```
s90 = 1480s (24.7m)   ← 占 40%
s27 = 278s  s11 = 227s  s59 = 200s  s92 = 137s
s60 = 103s  s13 = 93s   s57 = 84s   s31 = 66s  s47 = 48s  其余 < 30s
```

同轮 Linux 实测 `gate-hardening/run-all.sh` = **167.8s**（`real 2m47.8s`），
即 Windows 对 s90 的**平台放大 = 8.8x**。放大来源是进程创建 / git 操作 / NTFS 开销，
不是用例逻辑变慢——这意味着**削夹具**的收益远小于**整块搬走**。

## Decision

**把 `s90_gate_hardening_acceptance` 从 CORE-SET 迁至 NONCORE-SET，并把预算整块收回 60 分钟。**
这不是删场景：94 场景契约与 A16 的 7 个折叠场景一个不动，Linux full 层照跑全量。

三部分**必须同批落地**（缺一即自红）：

1. `tests/run.sh` 分层数据块：`CORE s90_gate_hardening_acceptance` → `NONCORE s90_gate_hardening_acceptance`。
   迁移后 `PONYGO_TEST_LAYER=core` → **26 场景**（原 27），full 仍 **94**。
2. `gh6` 的四类硬编码锚同步：`len(core)==27 → 26`、`len(noncore)==67 → 68`、
   `expected_core` 去掉 `s90`、D2 文案「core 层 27 场景」→ 26。
3. `ci.yml` 的 `timeout-minutes: 90 → 60` **与** `gh6/D2` 的断言 `== 90 → == 60` 同批。
   预算数字是契约，改它必须同时改看守它的断言（这条纪律来自 `2026-11-18-windows-core-budget` 自身）。

**补偿看守（本次的关键，不是附带项）**：搬走 s90 等于 Windows PR 级失去 gate-hardening 折叠看守，
必须补回来，否则就是「用降本换看守」：

- **补偿 ①**：`gh6` 的 CRLF 回归断言改为**常驻判据**（B005-b 交付）。Windows 专属的平台差异
  （CRLF、locale）不再依赖「在 Windows 上跑 s90」才能发现——本地即可跑，零成本。
  这条同时修掉了 B005-b 的根因，两个目标合一。
- **补偿 ②**：`gh6` 新增 `D2b` / `D2c` 两条断言，把本次决策**机械固化**：
  `s90` 必须以 `NONCORE ` 前缀出现且**不得**以 `CORE ` 前缀出现（防未来有人把它悄悄塞回 CORE
  又把预算撑爆）；`timeout-minutes == 60` 与 CORE 项数 `== 26` 必须同批自洽。
- **补偿 ③**：`selftest-linux` 每晚照跑 94 场景全量，keepers 面不减。

## Alternatives considered

- **① 把平台无关的 gh 用例迁到 Linux-only 折叠套件**：否决——写域最大（要把 gh1–gh14 按平台切片，
  再维护两份 run-all 编排），而 `2026-11-18-windows-core-budget` 已经指出真正的成本是**平台放大倍数**
  而非用例数量：切走一半用例，Windows 侧仍有 ~12 分钟、且切分线会随新用例漂移。
  收益/复杂度比不如整块搬走。
- **② 削 gh 夹具数量**：否决——折叠 7 场景是 A16 契约不得减；`ponygo init` 已是 gh 夹具的最小单元
  （Windows 上 5–10s），再削会削弱判定面。且按 8.8x 放大，即使砍掉一半夹具也只省 ~12 分钟，
  仍不足以在 60 分钟内留出安全余量。
- **③ 整块移出 CORE（选定）**：一次性拿到 24.7 分钟，Windows CORE ≈ **37.6 分钟**，60 分钟预算留 ≈22 分钟余量。
  代价（失去 Windows PR 级 gate-hardening 看守）由补偿 ①②③ 覆盖。
- **不搬 s90，只把预算改回 60**：否决——实测 62m17s 会直接撞 60m 被 cancel。
  **cancel 比 fail 更糟**：日志停在场景中途，拿不到任何断言结论（这正是 2026-11-18 那条记录的教训）。
- **搬走 s90 但保留预算 90**：否决——那就只剩「反馈变慢」没有再降本，等于 B026 没做。
  降本与收预算必须同批，否则预算数字与事实脱节（下一个维护者会以为还需要 90）。
- **先拿到 Windows 实跑 <60min 的绿证，再改预算**：否决这个**顺序**（不是否决取证本身）——
  预算改成 60 之后才可能观察到「60 够不够」。若坚持先取证再改，逻辑上无法推进
  （永远停在 90 的树里，跑出来的永远是 90 的事实）。正确做法是「同批改 + 实跑取证 + 取证前不 resolve」，
  即本次采用的：改动与断言同步落地，但 **B026 不 resolve，直到 windows-core 实跑 <60min 的绿证到手**。

## Consequences

- Windows PR 反馈时间从 ~62 分钟目标降到 ~38 分钟量级（预算上界 60）。
- **诚实边界**：本记录落盘时只有本机（Linux）证据——Linux 167.8s 基线 + 8.8x 放大推算 2257s ≈ 37.6m。
  真实的 windows-core 实跑绿证（<60min 且 `scenarios=26`）由 push 后的 CI 提供；
  **在拿到它之前 B026 不得 resolve**，且若实跑证明 60 仍不够，必须回退预算并重开降本讨论。
- Windows PR 级不再执行 gh1–gh14。补偿 ①②③ 是这次取舍的**前提条件**，不是可选项：
  若后续有人删掉 `D2b`/`D2c` 或移除 CRLF 常驻断言，等于把看守拆了却不恢复 s90。
- `2026-11-18-windows-core-budget` 的「目标不是长期 90」在此兑现；该记录的 90 分钟部分被本条取代，
  但其「预算数字是契约，改它必须同批改看守它的断言」这条纪律继续有效并被本条沿用。

## 对 B005 冻结验收判据的取代关系（L3 审查 B-2）

`backlog/legacy/dev-team-tasks/TASK-005.md`（冻结只读件，不改）的判据 1 原文：

> `windows-core`（GitHub Actions，PR 事件）**实跑绿**：`bash tests/run.sh` exit 0 且
> 汇总行 `scenarios=27 ... skipped=67`

本条把 `s90` 移出 CORE 后，`PONYGO_TEST_LAYER=core` 恒为 **26 场景 / 68 skipped**，
该判据的 `27 / 67` **永久不可满足**——不是被测对象不合格，是判据本身过期。

裁决：**判据 1 的数字部分由本条取代**，B005 的整卷判据改为
「`scenarios=26 ... skipped=68`，exit 0」。TASK-005 作为历史冻结件保留原文（`backlog/legacy/` 只读），
取代关系记录在此，避免「两条待办的验收条款互相矛盾且无人知道以哪条为准」。

同类情形若再出现（某条冻结判据的硬数字被后续架构决策作废），处置方式与本文一致：
**不改冻结件，在取代它的那条决策记录里写明取代关系**。
