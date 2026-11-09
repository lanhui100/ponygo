# Agent Note: 判据加固——rejected 理由必填、implemented 必含 Decision、1.9 拆分与问④只认封印

Status: implemented

## Problem

三处判据共同的病灶是**用"形态在场"代替"事实在场"**，于是"没做"与"做对"在判据眼里同形：

1. **1.8 只判"不出现什么"，不判"必须出现什么"**。原先 `implemented/` 只查提案时代标题是否在场：
   把文件 `git mv` 进 `implemented/` 却未改写正文的条目（`## Proposal` 已删、`## Decision` 从未写）
   与"迁移时真改写了"的条目，在反向判据下**都是绿的**（两者都不含 `## Proposal`）。中文标题更是
   整批逃过英文正则——本仓 `remove-yes-and-adapt-alt-governance` 的 `## 验收` 就是活样本：路径
   /`Status:`/英文标题全绿，正文仍是提案骨架（该条已在同批改为 `## Consequences`，判据由此拿到
   一个"加严前必红、加严后必绿"的真实样本）。
2. **1.7 只判 `Status:` 首词在词表内，不判 verdict 有内容**。`Status: rejected` 记录了"被否决"，
   却没记"为什么否决"——重新面对同一岔路时，那一行理由是唯一不可再生的证据。
3. **1.9 被当成一个整体报告，实际跨了两个判定主体**。1.9 = `docs/AGENTS.md` 存在 + 根 `AGENTS.md`
   索引链 + 包文档覆盖；中间的索引链依赖 `meta.yaml` 的 `ai-surface` 开关与投影块形态，只有 CLI 的
   `verify_ladder` 读得到，判定真源 `verify-note.sh`（A1/A4 消费）只看到第一项。旧实现
   `[ -f AGENTS.md ] && ! grep -q 'docs/AGENTS.md'` 在文件缺失时条件为假 → **静默通过**（假绿）；
   同时 JSON 恒称 `verified:["1.1-1.9"]`，把没跑的子项报成已验证。
4. **审计问④把"形态"当"证据"**：`[ -d archived ]` 在 `init` 时就为真（四态目录由 init 预建），
   于是"从未退场过"的仓白送一分——与本框架既有的"占位不计分"（2.1 的 `README`/`.gitkeep` 豁免、
   2.3 的空 spec 不计）自相矛盾。问④问的是"过时的东西真的退场了吗"，不是"留了位置吗"。

## Decision

**1. 判据补强：1.7 与 1.8 各补一条正向断言（硬判据，不是 WARN）**

- **1.7**：`rejected/` 下 `Status:` 首词为 `rejected` 时，同一行必须带理由——分隔符 `—` / `-` / `:`
  任一，其后剥掉空白**至少 2 字节**（真源按 `wc -c`；故单 CJK 字 = 3 字节即通过，单 ASCII 字符不过）。
  FAIL 文案：`1.7 <path>：rejected 缺一行理由（Status: rejected — <为何否决>）`。
  豁免：`archived/`（冻结）、`README.md` / `AGENTS.md`、`*.zh.md`（双语配对，与 1.10 同口径）。
- **1.8**：`implemented/` **必须含现在时 `## Decision`**（缺即 FAIL，文案
  `1.8 <path>：implemented 缺 ## Decision（迁移即改写：现在时 Decision 必须在场）`）；并继续禁提案
  时代标题——英文按**词边界**匹配（`## Proposal` / `## Plan` / `## Migration plan` /
  `## Acceptance criteria`），**中文按前缀匹配**（`提案` / `计划` / `迁移计划` / `验收标准` / `验收` /
  `风险` / `待办`）。前缀而非边界，是因为中文标题无词间空格，边界匹配会把 `## 验收清单`、
  `## 风险与缓解`、`## 待办事项` 这类复合词全部放行（等于开个洞）；代价是以禁词开头的正常标题也一并
  被拒（fail-closed，可接受）。
- **诚实边界（写进契约，不许靠猜）**：围栏代码块（``` 或 ~~~）内出现的 `## Decision` /
  `## Alternatives considered` 同样被认作"在场"——判据判的是**文本在场性**，不是 AST 结构。
  这条假阴性面登记在此；要消除它得引入 Markdown 解析器，与零依赖单文件 CLI 的成本不对等。

**2. 只读报告面与判定真源同批同步（禁止单边生效）**

`verify_ladder`（`status` / `audit` 的人类报告与 `--json`）与 `verify-note.sh`（A1/pre-commit 与
A4/CI 的判定真源）在**同一变更内**改，且**关键字逐字相同**（`缺 ## Decision`、`提案时代标题`）。
理由：两者是同一判据的两个消费面，单边生效会造成"报告绿、门禁红"（或反之）——使用者无法判断哪个是
真值，也不知道该信哪一条。本轮两次判据加固都出现过文案不一致的即时红，靠同批 diff 才收敛。

**3. 1.9 拆成 a/b/c 三个子项，其中只有 1.9b 是条件判据**

| 子项 | 内容 | 谁判 | 条件 |
|---|---|---|---|
| 1.9a | `docs/AGENTS.md` 存在（文档标准的家） | 真源（仅无参整树模式）+ `verify_ladder` | 恒判 |
| 1.9b | 根 `AGENTS.md` 存在且含 `docs/AGENTS.md` 字面链 | **只有** `verify_ladder`（`status`/`audit` 共用） | `ai-surface: on` → fail-closed（缺文件/无链即 1.9 FAIL：声明即承诺）；未声明或 `off` → **SKIPPED，不计入 PASS**（结论行 + WARN 明示） |
| 1.9c | 包文档覆盖（每包 `AGENTS.md` 或 `README.md`，或入 `.meta/docs-tier/exemptions`） | **只有** `verify_ladder` | 恒判 |

**对齐契约（改准后的事实）**：真源只对齐 1.1–1.8 与 1.9a；1.9b/1.9c 只由只读命令的
`verify_ladder` 判。因此 **A1/A4 绿 ≠ 1.9 全绿**（真源头部原话是「A1/A4 绿 ≠ 1.9b PASS」，本轮把
范围写全）——本地/远端门证明的是 ADR 格式与归档封印，不证明 AI 常载入口完好、也不证明包文档覆盖；
这句已写进 `verify-note.sh` 的头部「对齐契约」注，属于同一变更内的口径同步。

`--json` 的 `coverage` 块随 `AS19_SKIP` 同源收窄：`ai-surface: on` → `verified:["1.1-1.9"]`；
未判定 → `verified:["1.1-1.8"]` + `skipped:["1.9b"]`（`unverified` 恒为 `["1.10"]`——
本命令不执行仓库脚本，故不由它验证）。**SKIPPED ≠ PASS 在机器面同样成立**：没跑的子项不进 verified。

**4. 审计问④ 只认「已封印归档件」**

判据由「`archived/` 目录存在」改为「`archived/manifest.sha256` 存在且含 **≥1 条格式合法条目**」
（行格式 `^[0-9a-f]{64}  .+`，与 A6 `seal` 的写入口径一致）。空 `archived/`、有件但未封印、
空 manifest 一律不计分。审计层**只判格式**：manifest 与归档件的逐一一致（篡改/缺条目/孤儿/重复）
归 A6 `archive-verify.sh check`；只读纪律（判定优先只读）下审计**不执行**任何仓库脚本。

**配套落点（同一变更内）**：`verify-note.sh`（1.7/1.8/1.10 段与头部口径）、`ponygo` 的
`verify_ladder` 1.8 段 + 1.9b 分支 + `json_coverage` + 审计问④、文档面 `maturity-ladder.md` §5
（1.7/1.8/1.9 三行与注）、`audit/checklist.md` 4.1/4.2、`audit/depth-selector.md`、负样本
`adr-verify.spec.sh` 与冻结验收用例。

## Alternatives considered

- **把 1.9b 也搬进 `verify-note.sh`，让 A1/A4 一并看守**：否决。真源是**纯文本判据**（只读文件、
  不解释 `meta.yaml` 的开关语义、不判投影块成对性），而 1.9b 的对象正是"开关声明 + 投影块形态"；
  搬进去等于在真源里复制一份 CLI 的成对哨兵判据——同一判据两处实现必然漂移（P9），下次改投影形态
  要两处同改。取舍：宁可让 1.9b 的看守面窄（CLI 的 `status`/`audit` + A5 的 `audit --run-specs` 步），
  也不造第二个真值；归属写进 `maturity-ladder.md`，不靠读者猜。
- **保持 `[ -d archived ]` 判据**：否决。`init` 预建四态目录 → "建了个空目录"白送一分，与 2.1
  （`README`/`.gitkeep` 占位不计分）、2.3（空 spec 不计分）的既有口径直接矛盾；而且它奖励的是
  "留了位置"，不是"真退场"——本仓这次唯一一次真实归档（`2026-09-08` 停止线条）恰好证明了两者可分：
  目录早就在，可审计事实是 manifest 里多了一行。
- **只加 WARN 不加硬判据**：否决。WARN 不计入 PASS 在实务里等于默认放过——1.10 的教训就是现成样本
  （缺口登记两周、各实例缺节 ADR 一条没少）。1.7/1.8 的补救是机械可执行的（补一行理由 / 补
  `## Decision`），与 1.10 同类，没有理由选软档。
- **让 JSON 保持 `verified:["1.1-1.9"]`，只加一个 `skipped` 键**：否决。机器面仍宣称 1.9 全绿，
  下游按 `coverage.verified` 判"哪些轴已验"时会读到假事实。两条路的改动成本相同（改一个数组 vs
  加一个键），唯一差别是诚实度——选收窄 `verified`：不可验证的东西不进 verified。
- **把中文禁入做成标题白名单（只允许枚举的节名）**：否决。合法节形态会演进（本轮之前没人反对
  `## Consequences` 的复现、将来也可能出现新的现在时节名），白名单会让新增合法头恒红，维护税高；
  黑名单 + 前缀匹配已经覆盖提案态残留的全部实际形态，且失败方向是 fail-closed（多拒不少拒）。

## Consequences

- 每个 `implemented/` 决策不能只"删掉提案标题"就完事：`## Decision` 必须在场——迁移的真实工作量是
  **改写正文**，`git mv` 只是第一步。`rejected/` 的每一条都要能回答"为什么否决"，重开争执时有据可查。
- 1.9b 的看守面是分层的：本地 `ponygo status` + CI 的 A5 workflow `ponygo audit --run-specs` 步
  （两者同一 `verify_ladder`）；A1（pre-commit）与 A4（`ci-verify.sh`）经真源，只覆盖格式轴
  （1.1–1.10），**看不到 1.9b**。这是设计分层不是缺口——把 1.9b 搬进真源被否（见 Alternatives 第 1 条）。
- `--json` 的 `coverage` 随 `ai-surface` 状态变化：`on` → `verified:["1.1-1.9"]`；未声明/`off` →
  `verified:["1.1-1.8"]` + `skipped:["1.9b"]`。SKIPPED 时人类结论行同步改写并禁写「全部 PASS」。
- 审计问④不再奖励空目录；但审计层只判 manifest 的形状，**是否与归档件逐一一致必须跑 A6**
  （`bash .meta/gates/archive-verify.sh check`）——审计不给这个结论，也不冒充给。
- **本轮教训进契约**：`status`/`audit` 的人类文案关键字必须与 `verify-note.sh` 的 FAIL 文案同批逐字
  对齐（`缺 ## Decision` / `提案时代标题`），否则同一语料在两个消费面给出不同结论。
- 判不到的部分（诚实登记，不装假门禁）：标题**质量**（`## Decision` 是否真写成决定而非计划复述）、
  `rejected` 理由**是否成立**，仍是语义判断（靠 review 与 write-adr 校准样例）；围栏代码块内的标题
  计入"在场"是已登记的假阴性面。
- **`level: 0` 的机器面也已收口**：声明 L0 时 L1 段不执行，故 `coverage` 走保守默认
  （`verified:["1.1-1.8"]` + `skipped:["1.9b"]`）；只有 `verify_ladder` 真判过 1.9b（**判成 FAIL 也算判过**）
  才给 `verified:["1.1-1.9"]`——"没跑"与"跑过"在机器面分开，`status --json` 与 `audit --json` 逐字节一致。
  提前退出分支（骨架缺口等）同走保守默认，不再出现「status 说已验证、audit 说未判」的同源破约。
- **1.7 的"理由"按剥离后正文计**：先剥分隔符（`—`/`-`/`:`）与空白，剩余 ≥2 字节才算理由——
  `Status: rejected ——` 这类纯分隔符写法被拒。已登记残余：CJK 单标点（如 `。`）不被剥离，
  因其在 C locale 下与汉字不可字节区分，属靠 review 兜的已知假阴性面。
- 迁移面：本仓语料在同批内补齐（`remove-yes-and-adapt-alt-governance` 的 `## 验收` → `## Consequences`；
  全树 `implemented/` 缺 `## Decision` = 0），故加严当天零红。前置与相邻决策：1.10 的先例见
  `implemented/process/2026-10-29-ponygo-self-level2-and-alternatives-gate.md`；机读契约（2.6 与
  `--json`）见 `implemented/process/2026-11-01-audit-machine-surface-and-ai-projection.md`；
  1.9 的文档家与条件判据先例见 `implemented/process/2026-09-14-l2-conditional-docs-tier.md`；
  归档封印的写法与只读边界见 `implemented/process/2026-11-07-archive-seal.md`。
