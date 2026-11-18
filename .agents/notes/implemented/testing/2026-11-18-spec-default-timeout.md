# Agent Note: 出厂 spec 的自包裹默认上限由 30s 提高到 90s（Windows 直接调用路径不再被自身默认值误杀）

Status: implemented

## Problem

发布 v2.11.0 后 CI 的 `windows-core` 仍红，且新增了三类红（CI run `44203170901` / job `134462228450`）：

```
FAIL A2 adr-verify.spec.sh 自检 exit 0（期望 [0] 实得 [124]）
FAIL A4 ci-verify.sh 在本仓实跑 exit 0（期望 [0] 实得 [1]）
FAIL T-U1-4 / T-U2-5 / T-U3-4（gh8/gh9 里"依赖 A2/A4 绿"的断言）
```

根因不是逻辑错，而是**自包裹默认值**：出厂 spec 的开头是
`GT=${PONYGO_GATE_SPEC_TIMEOUT:-30}`——它只在 `audit --run-specs` 下拿到平台预算
（Windows 180s / 其他 90s），一旦**直接调用**（`bash .meta/gates/adr-verify.spec.sh`，测试与人工都用这条），
就用内建默认 30s。A2 在最近的 W1/W2a 中增加了 A6 缺失/fail-closed 与删除入册/迁移等用例后，
Linux 实测 3.6s，而 Windows Git Bash 的进程启动开销把同一条 spec 推过 30s → `timeout` 杀掉（124）→
A4 的 A2 段连带失败 → 依赖"门/自检绿"的断言全部连带红。`B024` 记录的正是这条增量回归。

## Decision

1. 四个**有自包裹**的出厂 spec 的默认上限 `30 → 90`：
   `.meta/gates/adr-verify.spec.sh`、`archive-verify.spec.sh`、`scratch-hygiene.spec.sh`、`backlog-gate.spec.sh`
   （`GT=${PONYGO_GATE_SPEC_TIMEOUT:-90}`，KILL 兜底仍 `-k 5`；非法值/越界仍 `exit 2`）。
2. 同步口径（同批，避免第二真源漂移）：
   - `.meta/gates/README.md` 的 `GT=...:-30` 与说明改成 90，并写明理由（Windows 直接调用路径）；
   - `maturity-ladder.md` 2.3 段的"软 25s + KILL 5s（最坏 30s）"改为"软 90s + KILL 5s（最坏 95s）"；
   - `tests/acceptance/gate-hardening/gh6_test_tiering_contract.sh` 的 `C13` 断言 `30 → 90`（冻结件随决策迁移，
     注释里链到本记录）。
3. A9（`no-residue.spec.sh`）**没有**自包裹 → 本批不动（见 Consequences 的残留风险）。

## Alternatives considered

- **只在 `ci.yml` 的 windows job 设 `PONYGO_GATE_SPEC_TIMEOUT=180`**：否决——只修 CI，不修
  "直接调用"这条路径（测试与人工都走它），且实例在 Windows 上直接跑 spec 仍会 30s 被误杀；
  等于用环境变量掩盖默认值不合理。
- **在 spec 内按平台调默认（OSTYPE/uname 探测）**：否决——契约 C13 明确规定"平台真值只允许存在于
  `ponygo` 一处，spec 内零平台判定"；破这条会让平台口径长出第二份。
- **削减 A2 的新增用例或按平台跳过**：否决——W1/W2a 的用例是 fail-closed 与删除入册的看守，
  跳过等于把 Windows 变成"少一套判据"的绿。
- **直接把默认抬到 180/300**：否决——挂死 spec 的本地等待成本随之翻倍；90 ≈ Linux 实测的 25 倍余量，
  足以覆盖 Git Bash 的启动开销，同时仍是一个像样的上限（挂死会在 95s 内被点名杀掉）。
- **改 `timeout` 的 KILL 兜底而不是软上限**：否决——KILL 只是软上限之后的强制回收，改它不改变
  "软上限先到即 124"的判定路径。

## Consequences

- Windows 直接调用（测试/人工）不再被自身默认值误杀；`audit --run-specs` 的平台预算推导（Linux 90 /
  Windows 180）**不变**——它在调用时显式下传，优先级仍高于默认。
- 代价（诚实登记）：本地挂死的 spec 现在要等 90s（不是 30s）才被点名；这是换取"Windows 不假红"的成本。
- 实例侧：四个 spec 是 `UPGRADE_UNIVERSE` 资产（`backlog-gate.spec.sh` 除外，属实例门），
  实例跑 `upgrade apply` 后会拿到 90s 默认；此前 `ponygo status` 的 2.1 会显示 `stale/modified` 分类提示迁移。
- **残留风险**：A9（`no-residue.spec.sh`）没有自包裹——若它在某个平台挂死，只能等 CI job 超时，
  不会像 A2/A7 那样 95s 内被点名。已登记 backlog（B025）作为下一批候选整改。
- 验证证据：Linux 本地 A2 3.6s（远低于 90）；`gh6`/`ci-verify`/`audit --run-specs` 绿；
  Windows 的最终验证以 CI `windows-core` 为准（本记录提交后观察）。
