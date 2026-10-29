# Agent Note: 移除 `--yes` 与交互确认；替代治理改为适配任务书；`docs-tier: off` 提示闭环

Status: implemented

## Problem

三处"看着在治理、实则不产生判定"的假动作，各自都把一个本可机械收敛的问题留给了人：

1. **交互确认是双输机制**。`init` / `observe init` 的 `confirm_or_skip` 走"打印即将执行 → 等 y/N"，
   并以 `--yes` 作为非交互逃逸。它防不住误操作——被确认的动作本身是幂等的（`init` 缺什么补什么、
   重复跑零改动、不改写业务文件；`observe init` 覆盖已有声明必须显式 `--force`），
    "确认"无法变更任何结果，只能在键盘层面制造摩擦；却新增**两条逃逸路径**：
   非 TTY 下 `read` 必然失败（历史上曾静默 no-op，R15 用 `die`「非交互环境请显式 --yes」打补丁，
    等于把 UI 缺陷升格成 CLI 契约，CI 里必然踩）；交互读失败时按"已取消"处理
    （`printf '' | ponygo init` 或上层管道吞掉 stdin 时"成功"却什么都没做）。
    更根本的问题：一旦存在 `--yes`，**所有文档、示例、CI 模板都得教两套调用**，
    而"要确认"这个承诺本身没有任何非零退出可验——它不属于治理，只是终端礼仪。
2. **替代治理形态的处置是空心的**。`init` 检出 `docs/adr/`、CONTRIBUTING.md、CODEOWNERS、
   `pre-commit`/lefthook、CI 配置等既有治理资产后，只打一行"先 `audit` 再决定迁移"。
    对被检出的旧项目来说，真正缺的不是这句提醒（人人都会点头），而是**逐项映射载体**：
    这套旧资产在 ponygo 双根里对应什么、该做哪一个动作、做完凭什么算完。没有任务书，
    提醒退化为噪声，旧项目照旧在任何地方都不算落地。
3. **`docs-tier: off` 的提示不闭环**。`off` 是显式 opt-out，`status` 提示"建议录一条 decision
   说明为何不上文档分层"（对齐 `retire` 的退级须录 decision 纪律）；但即使录了，提示仍逐次打印——
   一个"已被回应的建议"持续报 WARN，结果只有两种：被永久忽略（WARN 通胀），或诱导用户改声明，
   走 `on` 但模板态未激活的 FAIL 分支。

## Decision

三条同时落地，构成同一次契约变更：

1. **`--yes` 整体移除 + 交互确认整体移除（breaking，无兼容期）**：`init` / `observe init` 不再读
   stdin、不再打印 y/N 询问；`--yes` 不再是已知选项，**传入即按未知选项报错**（非零退出）。
   `--dry-run` 保留为**唯一预览手段**（只打印将做的动作，不落盘、不动 `git config`），
   终端 / 脚本 / CI 语义一致。原 `confirm_or_skip` 与 R15 的"非 TTY `die`"一并作废——
   写入安全性由**幂等 + 只增不改 + 显式覆盖开关（`--force`）**保证，不由确认提示保证。
   决策取代：`implemented/process/2026-10-29-forced-adr-gate-wiring.md` 的 R15（已标已作废）。
2. **替代治理形态 → 适配任务书**：`init` 检出既有治理资产时生成
   `.meta/adaptation/alt-governance.md`，逐项四栏：**检出项 / 语义映射 / 唯一动作 / 完成判据**
   （例：`docs/adr/` → 语义映射为"决策记录"→ 唯一动作"目录原样保留只读、新决策落
   `.agents/notes/{lifecycle}/process/`"→ 判据"落一条 `*alt-governance*.md` 写明两处分工"）；
   终端同打 **≤ 6 行摘要**（首行"N 项 + 任务书路径"、逐项一行极短句、末行 WARN 提示；>4 项折叠）。
   任务书是**生成物**：内容纯函数，幂等重写（二次 `init` md5 不变、无命中即删），勿手编。
   **不阻断 `init`**：骨架照常注入，任务书是待办清单而非门禁。`status` / `audit` 对此打 WARN；
   **落一条 `.agents/notes/**/process/*alt-governance*.md` 写明各项处置后 WARN 消失**
   （决策入册 = 已裁定如何处置，这是"已处置"唯一可机械识别的形状；逐项是否真的做完仍是 review 项）。
3. **`docs-tier: off` 提示闭环**：`status` 打印"建议录 decision"前先扫 `.agents/notes/**`，
   只要存在**文件名含 `docs-tier` 的 decision（任何 lifecycle / class）** 就**静默不再提示**
   （`off` + 已激活的家清单仍照旧报矛盾 WARN——那条说的是"声明与事实不符"，与被回应的建议无关）。

## Alternatives considered

- **① 保留 `--yes` 兼容（不删，仅标注 deprecated）**：否决。兼容期把成本从一个发布窗口延长到
  整个 deprecation 周期：两套调用要同时被文档、示例、CI 模板、测试矩阵覆盖（双写税），
  而"确认"没有任何可验收益（被确认的动作幂等）。更关键的是**留着就等于承认"某些写操作需要人点头"**，
  与"写入只增不改、`--dry-run` 可预演"的设计前提自相矛盾——一条 CLI 不该同时宣称"操作安全"与"操作需确认"。
- **② 检测到替代治理直接 fail-closed 拒绝 `init`**：否决。"你有旧治理资产"不是错误，
  是非空仓的**常态**；用非零退出拒绝，等于把所有历史厚重项目关在门外，并把"迁移值不值"这个
  人的判断塞进机器。而且 fail-closed 无法给出退出条件：什么状态下才允许 `init`？
  删掉 `docs/adr/`？（销毁用户资产）→ 要求先跑 `audit`？（新增一个"必须先过某命令"的门，同 R4 的教训：
  正常路径不应红色。）任务书是这条的替代形态：不拒绝、不静默、可逐项勾掉。
- **③ 只打一句提示、不生成任务书**（即现状的"先 `audit` 再决定迁移"）：否决。这是**待办无载体**：
  提醒留在终端滚屏里，随会话结束而消失，下一次进场的 agent 与人都不知道还剩什么没做。
  "不静默缺席"要求提示有**落盘的家**，否则它与没提示的区别只有一行 stderr。
- **保留交互确认、只删 `--yes`**：否决。删 `--yes` 后确认只剩交互一条路，非 TTY 必然失败
  （R15 的老问题原样保留），且确认本身仍不可验、仍教两套调用（键盘 vs 管道）。
- **在 `status` 里把"任务书未处置"判为 FAIL**：否决。机器可判的只有"有没有一条
  `.agents/notes/**/process/*alt-governance*.md`"，判不了"任务书每一项是否真的做完"（那是语义判断，
  靠 review）；把不可判的东西做成 FAIL 就是假门禁。故 `status` / `audit` 只 WARN，
  且 WARN 的消失条件写死为"该决策文件入册"。
- **任务书写进 `docs/`（人读文档家）**：否决。它是**一次性迁移工单**，不是长期文档：
  放进 `docs/` 会永久占一个文档位、并在处置完成后变成陈旧事实（slop：状态会腐烂）。
  `.meta/` 是机器态与真源，按需生成、处置完可删，位置与生命周期匹配。
- **任务书静态模板（不按检出项裁剪）**：否决。静态模板会把未检出的资产也列成待办，
  用户按清单做无用功后不再信任它；逐项检出驱动 = 清单里每一行都指向真实存在的旧资产。
- **把 `docs-tier: off` 的静默条件放宽为"任意 decision"**：否决。任何一条无关 decision 都会
  把提示吞掉，等于删掉提示；文件名含 `docs-tier` 是可机械识别、且写下来就必须解释的最小载体。

## Consequences

- **Breaking 面（明确接受）**：任何脚本、别名、CI 步骤、文档里传 `--yes` 的调用点**立即报错**
  （未知选项，非零退出）。这不是渐进弃用——没有兼容期、没有 warning 档。迁移动作是机械的：
  `grep -rn '\-\-yes' .github/ scripts/ Makefile` 后删旗标；删掉后行为与老的 `--yes` 路径**完全一致**
  （`init` 本来就不读 stdin）。选择硬切的理由：兼容成本要由框架长期承担，而收益方（"还留着旧脚本"的
  少数调用点）只需一次 grep 就能自愈；给一条**不再有语义**的旗标留兼容，等于给"确认"这个概念续命。
- **"任务书不阻断"的取舍**：不阻断 = 检出替代治理的项目**一定**能完成 `init`（旧项目不被劝退），
  代价是**不读任务书也能带着 WARN 走很远**——`status` / `audit` 的 WARN 是唯一的持续提醒，且只要落
  一条 `.agents/notes/**/process/*alt-governance*.md` 就能消掉，因此"写了决策但没真做"是可能的。
  这是有意的诚实边界：机器只判"你是否书面裁定了怎么处置"，不判"你是否做完"
  （不可机械判定的项不设假门禁）。真正的兜底在 review 与 `ponygo audit`
  （四问记分卡会问"承诺怎么强制"）。
- **WARN 的两条消失路径必须区分**：`alt-governance` WARN 靠 `.agents/notes/**/process/*alt-governance*.md`
  消失（处置裁定已入册）；`docs-tier: off` 提示靠文件名含 `docs-tier` 的任意 decision 消失
  （opt-out 理由已入册）。两者都是"提示 → 落一条决策 → 静默"的同一族语义，但触发词不同，别混用：
  落 `alt-governance` decision 不会消掉 docs-tier 提示，反之亦然。
- **`docs-tier: off` + 已激活家清单的矛盾 WARN 保留**：被回应的是"建议"，不是"矛盾"。
  声明说 `off`、文件却写着"已激活文档家清单"仍是必须对齐的事实错误（`status` 继续 WARN）。
- **文档面同步**：`README.md` §3.2（写命令零确认 + `--dry-run` 唯一预览）、§4.1（`.meta/adaptation/`
  与 `docs-tier` 提示闭环）、§5（探测 → 任务书，不再"确认后注入"）；`checklists/init.md`
  （无交互确认 + 任务书处置步）、`checklists/observe-init.md`（删 `--yes` 行）；
  `revisions/accepted/2026-10-29-forced-adr-gate-wiring.md`（Migration 去 `--yes` + v2 迁移补充）；
  `implemented/process/2026-10-29-forced-adr-gate-wiring.md`（R15 改写为已作废并链到本条）；
  `maturity-ladder.md` §5 判据 2.5 的注（`off` 提示的静默条件）。
- **命令面净减**：少一个旗标（`--yes`）、少一个交互分支（`confirm_or_skip`）、少一个 TTY 判定
  （R15 的 `[ ! -t 0 ]`），多一个生成物（`alt-governance.md`）。判定逻辑不变，非零退出语义不变。
- **已知边界（适配检测）**：检出项里的"既有非 ponygo `AGENTS.md` / `CLAUDE.md`"只在**首次** `init` 前成立——
  首次 init 的 `sync` 会把 ponygo 哨兵块并入该文件，二次 init 时该项不再命中
  （`detect_alt_gov_hits` 的判据是"文件存在且**不含** `ponygo` / `BEGIN constitution`"），
  故任务书 `alt-governance.md` 的字节会在"首次 → 二次"之间变化一次、此后稳定
  （实测 `docs/adr` + `AGENTS.md` 场景：2 项 → 1 项，md5 `f5335c8a…` → `a0848d88…`，第三、四次恒等）。
  若该项是**唯一**命中，二次 init 会直接**删除** `alt-governance.md`（生成物语义：无命中即删），
  `status` / `audit` 也随之不再有适配 WARN（WARN 条件 = 检出命中非空 ∧ 未登记 decision，
  与任务书是否在场无关；decision 登记后两种情形都静默）。这是幂等重写/无命中即删的正常表现，
  不是漂移——任务书本来就是"给尚未被 ponygo 接管的资产开清单"，不需要也不该被"修"成恒定字节。

## 验收

1. `bash .agents/skills/write-adr/verify-note.sh` → 0（整树 1.1–1.9）
2. `bash .meta/gates/ci-verify.sh` → 0
3. `grep -rn '\-\-yes' README.md checklists/ revisions/ .agents/notes/ .meta/` → 只剩历史/被否决备选性质的提及
   （本条的 Alternatives ① 与 R15 的作废说明），无"用法"层残留
4. 真实调用：`bash ponygo init --yes` 非零退出并报未知选项；`bash ponygo init --dry-run` 正常打印装配计划
5. 替代治理路径：在含 `docs/adr/` 的临时仓跑 `bash ponygo init` → 生成 `.meta/adaptation/alt-governance.md`
   + 终端 ≤ 6 行摘要 + `init` rc=0；`ponygo status` 打 WARN；落一条
   `.agents/notes/**/process/*alt-governance*.md` 后 WARN 消失（两次 `init` 任务书 md5 不变 = 幂等）
6. `docs-tier: off` 闭环：临时仓 `docs-tier: off` 且无 `*docs-tier*` decision → `status` 提示；
   落一条文件名含 `docs-tier` 的 decision 后同一命令**不再提示**（rc 与其余判据不变）
