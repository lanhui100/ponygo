# Agent Note: P0 抗熵增修复 —— 门资产锚定、默认关语义、L2 判据收紧

Status: implemented

## Problem

2026-11-11 的元框架审核（对标 dsh 系列第 1 篇）在 ponygo 自身找到三条"承诺—机制"断点：

1. **门与负样本可同时掏空而无观测者**：实例门 `foo.sh` 与其 `foo.spec.sh` 都写成 `exit 0` 后，`ponygo status`、`ponygo audit --run-specs`、`ponygo upgrade --check` 全绿（实例门不在 `UPGRADE_UNIVERSE`）；框架门被掏空时只有 `upgrade --check` 报漂移，而它不参与判定。
2. **`ai-surface` 默认态与命约相反**：填槽态删掉 `ai-surface` 键后 `ponygo sync` 仍投影常载命约（1048B，含「常载命约」正文），而命约 5 声明"AI 适配默认关"、宪法 `:95` 声明"删除该键=关闭"。
3. **L2 可零工作取得**：`pair23_instance > 0` 使 2.3 在零实例门时短路，`init` 产物 + 一个 5 行空壳决策即得 `ladder pass` / `exit 0`，与 `.meta/gates/README.md:4`「升到 L2 时放你的第一个实例门禁」矛盾。

不修正的代价：治理数字与事实脱钩（假门禁比没门禁更危险），且实例可无成本宣称成熟度，直接击穿方法论 P2/P8 与 §9 记分卡的证据纪律。

## Decision

按 `.dev-team/contract-p0-fixes.md` 与冻结验收脚本 `tests/acceptance/p0-fixes/verify-p0.sh`（16 项断言）实施五项：

- **P0-1 投影门控**：`do_sync` 区分宪法形态——模板态（含 `TODO:`）永远投影 bootstrap 引导（onboarding 前置，与开关无关）；填槽态仅显式 `ai-surface: on` 才投影常载命约，缺键/`off`/非法值 → 不投影并打印一行说明；该分支下若根 `AGENTS.md`/`CLAUDE.md` 仍含 `BEGIN constitution` 哨兵块 → WARN 残留投影（含手工删除指引，不自动删）。2.6 判据语义不变（未声明=SKIPPED 不计入 PASS）。
- **P0-2 2.3 三条 AND**：① 仓内 ≥1 个非空 `*.spec.*`；② L2 必须有 ≥1 个**实例门**（框架门 A1/A2/A6/A8 不计——它们每个实例都有，计进来判据永远免判）；③ 每个实例门 spec 必须含**拒绝断言**（`exit/return [1-9]`），只 `exit 0` 的 spec 判 FAIL。
- **P0-3/P0-4 门资产锚定**：`skeleton_drift` 结果分类——`UPGRADE_UNIVERSE` 中的门资产（`adr-verify.sh`/`adr-verify.spec.sh`/`ci-verify.sh`/`archive-verify.sh`/`archive-verify.spec.sh`）漂移 → 归入判据 2.1 FAIL（文案「可能被替换」并给恢复/`upgrade apply` 修法）；其余 universe 文件（README/SKILL）漂移仍为观察项。
- **P0-5 数字校准**：`tests/run.sh` 场景数由脚本自身枚举（当前 92）、`audit/depth-selector.md` 内嵌项数改为派生口径（S `total=12` / M `total=16`，`hits` 随仓库状态变，不写死）、`maturity-ladder.md` 的 dsh doc-sync 口径改 43 叶（quick 21）。
- **测试与文档同批**：`tests/run.sh` 的 `set_level2()` 单点收口为"加装一对合规实例门+spec"，避免既有 level-2 场景集体因夹具不足而红；`tests/acceptance/auditfix` 等因语义变更失效的 fixture 同步改期望；`maturity-ladder.md` §5 的 2.1/2.3 行补新语义。

验收收据：`bash tests/acceptance/p0-fixes/verify-p0.sh` PASS=16 FAIL=0；`bash tests/run.sh` pass=1816 fail=0；本仓 `status`/`audit`/`upgrade --check` 均 exit 0。

## Alternatives considered

- **只做资产 SHA manifest、不改判据**（方案 A）：否决——它只解决"框架门被替换"，解决不了"零实例门即得 L2"与"空壳 spec 恒绿"；且 manifest 需要新写一套比对与存在性语义，成本高于把漂移并入既有 2.1 判定。
- **维持 `ai-surface` 缺键=投影，只改宪法措辞**（方案 B）：否决——命约 5 承诺的是"默认关"，改措辞等于把默认开放写进宪法，与"人类开发者优先、避免为 AI 而 AI"的初衷相反；且合规场景（停用 AI 代理）需要的是默认安全。
- **把 L2 无实例门判为 WARN 而非 FAIL**（方案 C）：否决——`.meta/gates/README.md:4` 已把"放第一个实例门"写成 L2 的应然动作；WARN 不改变退出码，等于保留断点。改 `set_level2()` 夹具单点收口后，churn 可控（实测仅 1 处 helper + 少量 fixture 期望）。
- **为防"门自我掏空"引入门内容沙箱/签名**（方案 D）：否决——机器无法判定"门是否真拒绝"，签名只防篡改不防作者自签；正解是"资产锚定 + spec 拒绝断言 + 措辞诚实"（本轮已覆盖），沙箱成本 >> 收益。
- **把 M 档 total 从 16 恢复为 17 以对齐审核时点数值**（方案 E）：否决——16 是去重后的真实值（`tests/acceptance/gate-hardening/gh4_gate_spec_pairing.sh` 已硬断言 16，代码注释明写"删除重复计分项后 M=16"）；为对齐旧数字恢复重复计分项属于"为过测试放宽判据"。

## Consequences

- 三类熵增入口关闭：门资产被替换在默认判据 2.1 立刻红；`ai-surface` 缺键不再偷偷投影；L2 不再零成本可得。
- 已知代价与边界：① `off`/退场不删除既有投影（P9「删除是独立工程」），只给 WARN 与手工指引；② 2.3 的框架门排除名单是显式文件名，后续新增框架门需同步登记（当前已含 A8 `no-residue.sh`）；③ 实例若确实要"只用框架门"到达 L2，现必须显式加一个实例门——这被视为该判据的应有成本。
- 后续（P1 批，未在本条实现）：`status` 对"已接线"措辞降级、`audit --json` 增 `declared/verified` 与 `miss_ids`、其它 forge 零字节不算载体、HANDOFF 归家、`.dev-team` 家清单口径、`retire off` 残留 WARN。逐项见审核报告 §4。
- 持续复核：下一次框架门新增或 2.x 判据变更时，须同批复核本条的排除名单与验收脚本（`verify-p0.sh`）是否仍成立。
