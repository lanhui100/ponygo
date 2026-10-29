# Agent Note: 模板仓自身升 L2 + 新增判据 1.10（必含 `## Alternatives considered`）

Status: implemented

## Problem

两件互相关联的欠账，都是"承诺已写、机械面未兑现"：

1. **模板仓自身停在 L1**：`.meta/meta.yaml` 的 `level` 仍是 `1`，但 L2 判据 2.1–2.4 在本仓
   早已逐项满足（`gates/` 有实质门禁、脚本过 `bash -n`、有负样本 spec、本地钩子真接线）。
   level 是"当前档位"的唯一真值源（`meta.yaml` 铁律），它停在 1 = 框架对自身交付的门禁
   **不作可验承诺**，同时让 `ponygo status` 跳过 2.x 判定——实例看到的是一个"自己都不敢
   升 L2"的模板，L2 的说服力被自己的状态文件削掉。
2. **`## Alternatives considered` 有契约无判据**：`.agents/notes/README.md` 把备选节列为
   每条决策的强制契约，但判定真源 `verify-note.sh` 的 1.1–1.9 不含这一项
   （`grep -c Alternatives verify-note.sh` = 0）。后果在 `implemented/process/
   2026-10-29-forced-adr-gate-wiring.md` 的 Consequences 里作为**覆盖缺口**登记过：
   门禁层 A1/CI 都不拒绝缺备选节的 ADR，A2 该 case 只能做**探针**（WARN、不计入 PASS）。
   而"WARN 不计入 PASS"在实务中等于默认放过——契约由此退化为建议。

两件事在同一次变更内做，因为升级 L2 的同一批改动正好是补判据的落点：没有 1.10，升 L2 只是
换一个状态文件数字；只有 1.10 而不升 L2，则真源比声明更强，`status` 仍不判 L1 全貌。

## Decision

**决定一：模板仓自身升到 L2。** `.meta/meta.yaml` 的 `level: 1` 改为 `level: 2`（只改这一行，
注释保持），并如实记录判据现状：

| 判据 | 现状（本仓实测） |
|---|---|
| 2.1 `gates/` 有实质门禁 | PASS（A1 `adr-verify.sh`、A2 `adr-verify.spec.sh`、A4 `ci-verify.sh`） |
| 2.2 门禁脚本可运行 | PASS（三个 `*.sh` 均过 `bash -n`；代理判据） |
| 2.3 有负样本 spec | PASS（`adr-verify.spec.sh`，11 个 case） |
| 2.4 本地钩子真接线（五条 AND） | PASS（`core.hooksPath=.githooks`；`pre-commit` 存在且可执行；哨兵块逐字节合规且位置在 shebang 之后） |
| 2.5 文档分层已激活（条件判据） | **SKIPPED**——`meta.yaml` 未声明 `docs-tier: on|off`，故 `status` 打 WARN 催声明、2.5 不计入 PASS |

`ponygo status` 实得：`级自洽验证：通过（L0-L2 机械判据全部 PASS；2.5 SKIPPED——未声明 docs-tier，不计入 PASS）`，
rc = 0。**声明 `docs-tier` 是另一件事，本次不做**：为过判据去改 `docs-tier: on` 会把"文档分层
已激活"变成一句没人兑现的声明（`.meta/docs-tier/README.md` 仍是模板态），而 `off` 又需要一条
独立的"为何不上文档分层"决策——两者都超出本次范围，故留 2.5 为 SKIPPED + WARN 的诚实状态。

**决定二：新增判据 1.10——每条决策必含 `## Alternatives considered`（硬判据，不是 WARN）。**

- 实现：`verify-note.sh` 在 `check_one` 内、1.8 之后新增一段，沿用同一 `fail()` 与同一遍历入口
  （无参整树 / 带参单文件两种模式同时生效）；正则 `^## Alternatives considered([[:space:]]|$)`。
  FAIL 文案：`1.10 <path>：缺 ## Alternatives considered（非平凡决策必须写明被否决的备选与理由）`。
  豁免：`archived/`（冻结豁免，与 1.8 同口径）、`README.md` / `AGENTS.md`（函数入口早退）、
  `*.zh.md`（双语配对，译文随母语版同批补齐，不独立判）。
- 真源表：`maturity-ladder.md` §5 的 L1→L2 表新增 1.10 行（布尔项 + 锚定命令 + 判读），
  表下注说明"为何 1.10 是硬判据"。
- 技能面：`write-adr/SKILL.md` 的判据范围表述 1.1–1.9 → 1.1–1.10，校准样例补**反例**
  （只写 `## Decision` 不写 Alternatives）。
- 门禁自检：`adr-verify.spec.sh` 中"缺备选节"的 case 由**探针**翻转为**硬断言**
  （非法样本必须被拒，且文案含判据号 `1.10`）——探针的存在理由（真源不判）已消失。
- 口径同步：`.meta/gates/README.md`、`ci-verify.sh`、`adr-verify.sh` 注释中的 1.1–1.9 → 1.1–1.10。

**本仓自证**：模板仓自身缺备选节的决策 = **0 个**——`bash .agents/skills/write-adr/verify-note.sh`
在加 1.10 后仍然 rc = 0（20 条决策全含备选节），故升级不触发本仓的任何补齐动作。

## Alternatives considered

- **不升级、保持 L1**：否决。2.1–2.4 已满足而 level 仍写 1，等于让状态文件长期说谎——模板仓的
  `.meta/meta.yaml` 是实例的参照物，它停在 L1 会被读成"L2 还不成熟"。代价是本次要如实登记
  2.5 SKIPPED（一项 WARN），但那正是判据想要的诚实输出，不是缺陷。
- **把 Alternatives 检查放进 `ponygo audit` 的 M 档（提醒层），不进判定真源**：否决。
  这会把同一条判据做成"两套强度、两个入口"：audit 报、`verify-note.sh` 不报、pre-commit 不拦，
  于是"绿"的含义随调用者而变（正是 §5 判据表要消灭的多真值）。更具体地：audit 是**体检**
  （随时跑、人读），判定真源是**门禁的判据源**（pre-commit + CI 消费）——备选节是"每条决策无条件
  必须"的格式契约，条件为真，就不该降级为体检项。M 档适合"新鲜度/对应性"这类语义启发式，
  不适合可机械判的在场性。
- **只做 WARN、不做硬判据**：否决，且这正是本次要终结的状态。WARN 不计入 PASS 在实务里等于
  放过（`adr-verify.spec.sh` 的原探针就是活样本：缺口登记了两周，各实例的缺节 ADR 一条没少）。
  判据强度的正确刻度是"要么有非零退出命令，要么承认靠 review"——没有第三种。选硬判据的前提
  是它有可执行的补救（补写 2–3 个备选 + 理由），这一点成立，故不选 WARN。
- **在 `adr-verify.sh`（A1 门禁层）补一个 grep 而不动真源**：否决。同一判据两份实现必然漂移
  （P9），且会造成"`ponygo status` 绿、门禁红"的双真值——这与 A1 的设计边界直接冲突
  （A1 只做真源做不到的三件事：TOCTOU、`ACMR` 覆盖面、非普通文件拒绝）。
- **同时声明 `docs-tier: off`（或 `on`）以让 2.5 也"有结论"**：本次否决。`on` 会让模板态
  `docs-tier/README.md` 当场 FAIL（声明空心）；`off` 是显式 opt-out，须配一条"为何不上文档分层"
  的独立决策——两件事都该在自己的变更里做，不该借升级"顺手清零"一项 WARN。
- **把 1.10 的豁免口径放宽到"仅 implemented 生效"**：否决。proposed/rejected 同样需要备选
  （proposed 的 Alternatives 是评审的输入，rejected 的备选是"当初差点选了什么"的唯一记录）；
  只豁免 `archived/`（冻结）与两类治理契约载体文件。

## Consequences

**迁移面（本节是本次变更真正的成本所在）**：

现存实例**不能只更新 `verify-note.sh`** ——脚本一更新，pre-commit（A1）与 CI（A4）立刻按 1.10
判，所有缺备选节的 ADR 会在下一次提交/CI 变红，且补救不是机械可批量的（备选与落选理由是语义内容，
必须逐条回到当时的权衡现场去写）。因此**顺序是硬约束**：

1. **先补齐缺节 ADR**（逐条补 `## Alternatives considered`：2–3 个当时真正比较过的备选 +
   各自落选理由；写不出备选 = 该条其实不构成决策，应并入相邻决策或降级为普通文档）；
2. **再更新 `verify-note.sh`**（实例跟随模板/CLI 更新，或手动同步该文件）；
3. **更新后自证**：`bash .agents/skills/write-adr/verify-note.sh` → 0；反面自测：造一条只有
   `## Decision` 的临时 ADR → 必须 rc≠0 且报 `1.10`；
4. `archived/` 下**不必补**（冻结豁免，保持归档时原貌——这是"冻结"这个词的全部意义）。

**已知待补清单（仅登记，本次不修改这些仓）**：

| 实例 | 待补 ADR 条数 | 具体条目 |
|---|---|---|
| `ponyfun` | 1 | `implemented/architecture/2026-10-29-platform-static-site-verify.md` |
| `ponyllm` | 5 | `2026-09-20-auth-migration`、`2026-09-20-auth-eval`、`2026-10-11-parity-gate-and-cascade-rollback`、`2026-10-07-pool-matrix-slot-presence-and-placeholder-semantics`、`2026-10-18-residential-egress-pool-strategy` |
| `job_copilot_marketing` | 3 条 ADR + 1 个游离文件 | 3 条 ADR 缺备选节；游离文件 `test_red_phase_receipt.md` 连 1.5（路径深度）都不满足——**该仓当前已因 1.5 变红，属既有欠账**，不是 1.10 引入的新红 |

模板仓自身：缺备选节 = **0 条**（加判据后 `verify-note.sh` 仍 rc = 0），故本仓升级零补齐成本。

**代价与已知限制（四条，诚实登记）**：

1. **CLI 不复刻 1.10（设计选择，非缺口）**：1.10 只由判定真源 `verify-note.sh` 判定；
   `ponygo` 单文件内的 `verify_ladder` 仍覆盖 1.1–1.9，因此 `ponygo status` **不报** 1.10——
   它明确声明自己的机械范围是 1.1–1.9。看守面并未缺席：pre-commit 的 A1 与 CI 的 A4 都经
   `verify-note.sh`，1.10 已被强制。在 CLI 里再写一份 grep 会造成"真源绿、CLI 红"或反之的
   双真值（P9），这正是 A1 当初不去复刻判据的同一理由。
2. **双写漂移（可观测）**：`verify-note.sh`、`SKILL.md`、`adr-verify.spec.sh`、`.meta/gates/README.md`、
   `adr-verify.sh`、`ci-verify.sh` 都在 `UPGRADE_UNIVERSE` 里（模板文件 + `ponygo` heredoc 双写）。
   本次改的是模板侧 → `ponygo upgrade --check` 会对未同步的那几处报 drift（漂移=观察，默认 exit 0，
   `--check` 才非零）。这是"模板先改、heredoc 后同步"的**预期信号**，不是缺陷：本次改动完成、
   heredoc 尚未同步时的实测快照是 5 处 drift（`SKILL.md` / `gates/README.md` / `adr-verify.sh` /
   `adr-verify.spec.sh` / `ci-verify.sh`）；heredoc 同步后复测 `--check` 已归零（零漂移）。
3. **1.10 判不到质量**：它只判"备选节在场"。写一句"备选：无（本条无替代方案）"同样 PASS——
   备选是否真的权衡过、落选理由是否成立，仍是语义判断（靠 review 与 write-adr 校准样例，
   见 SKILL.md 新增反例）。判据加固的是**退化下限**（ADR 不再能只剩结论），不是质量上限。
4. **`*.zh.md` 豁免与 1.8 口径不同**：1.7/1.8 明写"`*.zh.md` 不在豁免之列"，1.10 却豁免它。
   理由：双语配对是同一决策的两份投影，1.10 的实质内容（备选与理由）由母语版承载、译文随同批
   补齐；若强制译文独立满足，会把"双语同步"变成一门额外的翻译门禁（而当前没有 doc-sync 门，
   这条守不住也验不了）。差异已写进 `maturity-ladder.md` §5 的 1.10 注。

**配套改动（同一次变更内）**：`.meta/meta.yaml`（level 1→2）、`verify-note.sh`（1.10 + 头部口径）、
`maturity-ladder.md`（§5 表新增 1.10 行 + 两条注）、`write-adr/SKILL.md`（判据范围 1.1–1.10 +
反例）、`adr-verify.spec.sh`（探针→硬断言）、`.meta/gates/README.md` 与 `ci-verify.sh` /
`adr-verify.sh`（口径 1.1–1.10）。`docs/methodology.md` 无"1.1–1.9 判据范围"表述，本次零改动
（其 1.9 提及是逐条口径，不涉及范围）。框架侧演进提案与验收口径见
`revisions/accepted/2026-10-29-alternatives-criterion-1-10.md`。

**验收（实收 rc）**：`bash .agents/skills/write-adr/verify-note.sh` → 0；
`bash .meta/gates/adr-verify.spec.sh` → 0（含翻转后的硬断言 case）；
`bash .meta/gates/ci-verify.sh` → 0；`bash ponygo status` → 0（级= L2，2.1–2.4 PASS）；
反面自测（临时造只有 `## Decision` 的 ADR）→ rc = 1 且报 `1.10`。
