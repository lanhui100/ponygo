# Agent Note: windows-core 的 job 预算 60 → 90 分钟（CORE 层含折叠 s90，Windows 实测被 job timeout 取消）

Status: implemented

## Problem

v2.11.0 之后的 CI 在 `windows-core` 上出现**取消**（不是断言失败）：CI run `44222219021`，
job 从 `02:18:03Z` 起跑、`timeout-minutes: 60` 到点被 cancel。日志时间线（job 内场景开始/结束行）显示：

- s01…s79：`02:18` → `02:50:31` ≈ **32 分钟**（其中 s66 105s、s79 156s 属正常慢项）；
- `s90_gate_hardening_acceptance` 从 `02:50:31` 起跑，**直到 job 被取消时仍未结束**（≈34 分钟未完成）。

`s90` 是 CORE 层的**折叠套件**（`tests/acceptance/gate-hardening/run-all.sh` 里 gh1–gh14 全部 gh 用例）。
它随每次"新契约加一条 gh 用例"而变重：本仓在 W1/W3 期间新增 gh8–gh14，且 A2/A7 的 spec 体量增加
（W1 加 A6 fail-closed 用例、W2a 加删除入册/迁移用例），在 Windows Git Bash 上被进一步放大。
于是 CORE 层的总时长越过 60 分钟预算，job 被整块取消——**取消比失败更糟**：日志停在 s90 开头，
无法看出是哪个 gh 用例慢，也拿不到任何断言结论。

先前 `B024` 修的是"A2 spec 自包裹默认 30s 在 Windows 上误杀自己"（已改为 90s）；本条是**另一层**问题：
job 级预算不够，不是 spec 级预算不够。

## Decision

1. `.github/workflows/ci.yml` 的 `windows-core`：`timeout-minutes: 60 → 90`（写明了理由与时间线指针）。
2. `gh6` 的 `D2` 冻结断言 `60 → 90` 同批迁移（`GH6/D2 windows-core timeout-minutes: 90（rev4 预算）`），
   注释链到本记录——预算数字是契约，改它必须同时改看守它的断言。
3. **目标不是长期 90 分钟**：把 s90 的 Windows 成本降下来后，应把预算收回 60。降本候选（下一批）：
   - s90 内的 gh 用例按"平台无关/平台专属"再分：平台无关的移到 Linux-only 的折叠套件（不动 94 场景契约）；
   - 削减新 gh 用例的夹具数量（每个 `ponygo init` 在 Windows 上约 5–10s）；
   - 评估把 s90 整体移出 CORE（改由 windows-full 夜间覆盖）——**本批不采纳**：gh6 的 Windows 专属预算断言
     （300s 档）会失去 PR 级看守。
4. 登记 `B026`（Windows CORE 层时长 & s90 成本）追踪降本与"预算收回 60"。

## Alternatives considered

- **把 s90 移出 CORE（改 NONCORE）**：否决——CORE 的意义就是"平台专属 + 门/聚合门"，gh6 里有
  Windows 专属预算断言（如 spec 300s 档）；移出去等于让 Windows 只有在 nightly 才验证这些契约。
- **削减/跳过新 gh 用例**：否决——gh8–gh14 是 W1/W2/W3 的验收看守（A6 fail-closed、删除入册、判词、
  逃生口留痕、A3 v2）。跳过等于把新承诺在 Windows 上降级为 review。
- **提高 runner 规格 / 并行拆分 s90**：暂不采纳——需要把 s90 拆成多个 scenario（94 场景契约要改），
  且收益只在 Windows；先用预算解决"取消"，降本作为后续。
- **继续修 spec 级预算（90 → 更大）**：否决——`B024` 已定位 A2 是 spec 级误杀；本条是 job 级总时长，
  再抬 spec 预算只会让单条挂死更久，不解决总时长。
- **让 windows-core 只在 PR 跑少量、其余夜间**：实质等于把 s90 移出 PR 门——同第 1 条的否决理由。

## Consequences

- PR 上 Windows 最坏等待从 60 分钟变成 90 分钟；换来的是"不再被整块取消、能拿到断言结论"。
- 90 分钟是**临时预算**：若 s90 继续变重（每加一条 gh 用例都会加），90 也会被击穿。
  降本动作与"收回 60"的目标已登记 `B026`，本记录不复述其细节（避免第二真源）。
- 与 `B024` 的关系：B024 = spec 自包裹默认值（已修，90s）；B026 = job 级预算（本记录）+ s90 成本追踪。
  两者根因不同、修复面不同，故分开入册。
