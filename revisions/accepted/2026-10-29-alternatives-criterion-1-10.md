# Revision: 新增 L1 判据 1.10——每条决策必含 `## Alternatives considered`（硬判据）

Status: accepted

## Problem

L1 判据真源（`maturity-ladder.md` §5 的 1.1–1.9）锁的是**形状**：路径两轴、文件名、日期、
`Status:` 与目录一致、骨架标题与 lifecycle 匹配、文档有家。**它不判备选节是否在场**——
而 `.agents/notes/README.md` 把 `## Alternatives considered` 写成每条决策的强制契约
（"记录无备选的决策是在邀请重开争执"）。

契约与判据之间的这条缝有实证代价：

- `ponygo` 仓自身 `grep -c Alternatives .agents/skills/write-adr/verify-note.sh` = 0；
- 交付即接线那一轮（`revisions/accepted/2026-10-29-forced-adr-gate-wiring.md`）只能把
  "缺备选节"的负样本 case 做成**探针**：真源不判 → 断言拒绝是错的，只好打 `WARN` 并声明
  "不计入 PASS"。缺口被诚实地登记进了 Consequences，**但登记不等于修**：
  `ponyfun` 1 条、`ponyllm` 5 条、`job_copilot_marketing` 3 条 ADR 都缺备选节，
  全部在各仓"全绿"状态下长期存在。
- 结论：**WARN 不计入 PASS 在实务中等于默认放过**。凡"每条决策无条件必须"的格式项，
  要么给出非零退出命令，要么承认它靠 review——中间档（提醒）已被证明不产生修复动作。

## Decision

1. **判定真源新增 1.10**（`verify-note.sh`，`check_one` 内与 1.8 同一 `fail()` / 同一遍历入口）：
   每个决策文件必须含标题行 `## Alternatives considered`，正则
   `^## Alternatives considered([[:space:]]|$)`。
   FAIL 文案：`1.10 <path>：缺 ## Alternatives considered（非平凡决策必须写明被否决的备选与理由）`。
   **豁免**：`archived/`（冻结豁免，与 1.8 同口径）、`README.md` / `AGENTS.md`（治理契约载体）、
   `*.zh.md`（双语配对，译文随母语版同批补齐）。
2. **真源表加行**：`maturity-ladder.md` §5 的 L1→L2 表新增 1.10（布尔项 + 锚定命令 + 判读）+
   表下注（为何是硬判据、豁免口径、判不到什么）。
3. **技能面同步**：`write-adr/SKILL.md` 判据范围 1.1–1.9 → 1.1–1.10；校准样例补**反例**
   （只写 `## Decision` 不写 Alternatives，含可执行补救指引）。
4. **门禁自检翻转**：`adr-verify.spec.sh` 的"缺备选节"case 从**探针**（WARN、不计入 PASS）
   改为**硬断言**（非法样本必须被拒 + 文案须含判据号 `1.10`）——探针的存在理由已消失。
   断言仍只指向"门会响"，判据实现保持单一（真源一处），不私设第二真值。
5. **本仓自证 + 自升级**：模板仓自身 20 条决策**全部含备选节**（0 条待补），故 1.10 落地后
   `verify-note.sh` 仍 exit 0；同批把 `.meta/meta.yaml` 的 `level` 由 1 升到 2
   （2.1–2.4 已满足，2.5 因未声明 `docs-tier` 为 SKIPPED + WARN）。

## Alternatives

- **放进 `ponygo audit` 的 M 档（提醒层），不进判定真源**：否决。制造"两套强度、两个入口"——
  audit 报而 pre-commit 不拦，"绿"的含义随调用者变化（多真值）。M 档适合"新鲜度/对应性"这类
  语义启发式，不适合"可机械判的在场性"。
- **只做 WARN（保留探针）**：否决。这正是本次要终结的状态，且已有反证：缺口登记后各实例
  一条没补。判据强度的正确刻度是"非零退出命令 / 明确承认靠 review"，没有中间档。
- **在 A1（`adr-verify.sh`）里加 grep，不动真源**：否决。同一判据两份实现必然漂移（P9），
  且会造出"`ponygo status` 绿、门禁红"的双真值；A1 的设计边界是"只做真源做不到的三件事"。
- **在 `ponygo` 单文件的 `verify_ladder` 里也实现一份 1.10**：否决（P9 一份判据一份实现）。
  CLI 里再写一遍正则，就会有两份实现去描述同一条判据，任一侧改动立刻漂移；且会造出
  "`ponygo status` 说绿/红、门禁说另一种"的双真值。**归属定为：1.10 只由真源
  `verify-note.sh` 判定，CLI 不复刻**——`verify_ladder` 的 L1 段仍覆盖 1.1–1.9 并明文声明该范围；
  1.10 的看守面由 A1（pre-commit）与 A4（CI）承担，两者都调真源。代价是 `status` 的报告面
  少于判据面（已登记为 Consequences 第 1 项）。
- **同时声明 `docs-tier: on/off` 以给 2.5 一个结论**：否决。`on` 让模板态当场 FAIL（声明空心）；
  `off` 需配一条独立的"何为不上文档分层"决策。两者都超出本 revision 的范围，不应借升级清零 WARN。
- **豁免口径只保留 `archived/`（去掉 `*.zh.md`）**：否决。双语配对是同一决策的两份投影，
  实质内容由母语版承载；强制译文独立满足会把双语同步变成一门额外的翻译门禁，而当前没有
  doc-sync 门，这条既守不住也验不了。差异已写进 §5 的 1.10 注（与 1.7/1.8 的 zh 口径不同，明示）。

## Migration

**顺序是硬约束：先补齐，再更新脚本。** 脚本一更新，pre-commit（A1）与 CI（A4）立刻按 1.10 判，
而补救（写备选与落选理由）是语义内容，无法机械批量。

1. **预检清单**：在实例仓内一次性枚举缺节 ADR（只读，不改文件）：
   ```bash
   grep -rLE '^## Alternatives considered([[:space:]]|$)' --include='*.md' \
     --exclude='*.zh.md' --exclude='README.md' --exclude='AGENTS.md' \
     .agents/notes/proposed .agents/notes/implemented .agents/notes/rejected
   ```
   输出即待补清单（`archived/` 不在扫描面内——冻结豁免）。
2. **逐条补齐**：每条 ADR 补 `## Alternatives considered`，写 2–3 个**当时真正比较过**的备选 +
   各自落选理由。写不出备选 = 该条其实不构成决策 → 并入相邻决策或降级为普通文档（这正是 1.10
   的第二个作用：反向识别"为记录而记录"的伪 ADR）。`archived/` 下**不必补**（冻结）。
3. **更新真源**：实例跟随模板/CLI 更新 `.agents/skills/write-adr/verify-note.sh`
   （或重跑 `ponygo init` 后按模板同步）。更新后立刻自证：
   - `bash .agents/skills/write-adr/verify-note.sh` → 0
   - 反面自测：造一条只有 `## Problem` + `## Decision` 的临时 ADR →
     `verify-note.sh <path>` 必须 rc ≠ 0 且报 `1.10`；测完删除该临时文件。
4. **CLI 面（不需改判据，只需保持口径）**：`1.10` **不由 `verify_ladder` 复刻**（P9，见
   Alternatives）——`ponygo` 单文件只需两件事：`write_skeleton` 里 `verify-note.sh` 的 heredoc
   副本随模板同步；`status`/`verify_ladder` 的 L1 段保留"机械范围 = 1.1–1.9"的明示注释
   （避免读者以为 `status` 绿 = 1.10 也过了）。过渡期内 `ponygo upgrade --check` 会对
   **尚未同步的 heredoc 副本**报 drift（漂移=观察，默认 exit 0）——本次改动后、heredoc 同步前的
   实测快照是 5 处（`SKILL.md` / `.meta/gates/README.md` / `adr-verify.sh` / `adr-verify.spec.sh` /
   `ci-verify.sh`）；同步后复测 `--check` 零漂移。
5. **已知待补实例清单**（登记，不在本次修复）：`ponyfun` 1 条
   （`implemented/architecture/2026-10-29-platform-static-site-verify.md`）；`ponyllm` 5 条
   （`2026-09-20-auth-migration`、`2026-09-20-auth-eval`、`2026-10-11-parity-gate-and-cascade-rollback`、
   `2026-10-07-pool-matrix-slot-presence-and-placeholder-semantics`、
   `2026-10-18-residential-egress-pool-strategy`）；`job_copilot_marketing` 3 条 ADR +
   游离文件 `test_red_phase_receipt.md`（**该仓当前已因 1.5 变红，属既有欠账**，不是 1.10 引入）。
   模板仓自身：0 条。

## Consequences

- **判据面**：L1 判据从 1.1–1.9 扩到 1.1–1.10；`ponygo status` 的 L1 段**按设计**仍覆盖
  1.1–1.9（不做第二份实现），故 `status` 绿不等于 1.10 过——1.10 由 A1/A4 经真源看守，
  这是"报告面 < 判据面"的有意取舍，已在 `maturity-ladder.md` §5 与真源文件头明示。
- **门禁面（真实看守）**：pre-commit A1 与 CI A4 都经 `verify-note.sh`，1.10 即刻生效；
  `adr-verify.spec.sh` 的探针翻转为硬断言后，门禁自检能证明"缺备选节会被拒"。
- **实例面**：缺节 ADR 的仓（上表）会在更新脚本后变红——**这是判据加强的正确结果**，
  不是回归；补救必须走"人补内容"而非"脚本放宽"。
- **维护税**：`verify-note.sh` / `SKILL.md` / `adr-verify.spec.sh` / `gates/README.md` /
  `adr-verify.sh` / `ci-verify.sh` 均在 `UPGRADE_UNIVERSE` 内（模板 + `ponygo` heredoc 双写），
  本次改模板侧 → 过渡期 `upgrade --check` 报 drift 可观测；heredoc 副本同步后归零。
- **判不到的部分**：备选的**质量**（是否真权衡过、理由是否成立）与"多类是否该拆条"仍是
  语义判断，靠 review 与 write-adr 校准样例。判据加固的是退化下限，不是质量上限。
- **与 1.7/1.8 的口径差异**：`*.zh.md` 在 1.7/1.8 不豁免、在 1.10 豁免——差异已在
  `maturity-ladder.md` §5 的 1.10 注明示，避免后来者误以为豁免口径统一。

## 验收

1. `bash .agents/skills/write-adr/verify-note.sh` → **0**（模板仓 20 条决策含 1.10 仍通过）
2. `bash .meta/gates/adr-verify.spec.sh` → **0**（含翻转后的硬断言 case：
   `缺 ## Alternatives considered 拒绝（1.10 硬判据，文案带判据号）`）
3. `bash .meta/gates/ci-verify.sh` → **0**
4. `bash ponygo status` → **0**，级 = L2，2.1–2.4 PASS；2.5 SKIPPED + WARN（未声明 `docs-tier`，
   本次刻意不声明）
5. 反面自测：临时造只有 `## Decision` 无 Alternatives 的 ADR →
   `verify-note.sh <path>` 非零且报 `1.10`；`*.zh.md` 同内容 → 0（豁免）；
   `archived/` 同内容 → 0（冻结豁免）；测完删除临时文件
6. 本机 `bash tests/run.sh` 的既有夹具不受影响（夹具 ADR 均含备选节；`tests/` 不在本次写域，
   由测试负责人独立裁决）

> 框架侧工程决策（本仓作为软件项目如何落地）见
> `.agents/notes/implemented/process/2026-10-29-ponygo-self-level2-and-alternatives-gate.md`。
