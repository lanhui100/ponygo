# Agent Note: 仓库卫生只交付指引（体检面 + 设计菜单），不做框架门、不设等级轴

Status: implemented

## Problem

审计与实机对比暴露一个空档：ponygo 有"临时产物下沉"的常载命约（命约 7）与 `scratch-hygiene.sh` 三类机械拦截，
但**没有一套"植入时怎么体检一个仓的卫生状况、怎么为它设计自己的卫生体系"的程序**。后果是：
- 每个实例的卫生面只到"E1–E3 是否过"这一层，构建产物入库、删除边界、游离过程文档、大文件、依赖一致性
  这些项无人系统地过一遍；
- 想补这一块时，最容易走的两条错路是：①把 deepseek-harness 的 `clean.ts` 搬进来（TS workspace 专属，
  会给零依赖 bash 的元框架引入终身维护税）；②在框架里再加一个"卫生门"（框架门不计实例门，
  等于让判据永远免判——`ponygo audit` 已立此论证）。
- 另有一处具体缺口被实机确认：**清理脚本的删除边界**（仓根锚定 / 父目录 realpath / 不跟随链接 / 白名单 fail-closed）
  是"任何删除器都该有"的安全不变量，但仓里没有任何地方写它。

## Decision

1. **新增指引页** `audit/hygiene-design.md`（`audit/` = 权威细目库的家），内容四段：
   - §1 **体检面**：12 项扁平清单（`HY-1…HY-12`），每项 = 布尔命题 + **锚定命令** + 判定性（机械/部分/review）
     + "何时必须"（只引用 `level` 与命约 7 / 判据 2.3，不复述档位定义）；
   - §2 **设计菜单**：按当前 `level` 映射（L1 只要求 HY-2/3/4 为真；L2 落成实例门 + 同名负样本 spec；
     L3 才谈技能化），并给**门骨架、负样本 spec 骨架、删除安全四不变量**（只借 DSH `clean.ts` 的四条不变量，
     不搬清理器本体）；
   - §3 **一次性产出**：植入时必须落一条 `hygiene-baseline` 决策记录（四节：体检事实 / 已选机械门 /
     明确不做项 / 复审条件）；**本项不设门**（文件与内容语义判不了），由 `governance-review` 在
     L2 升级与 `upgrade adopt` 之前核对"记录存在 + 四节齐"；
   - §4 **不覆盖声明**（报告必须原文复述）。
2. **不新增等级轴**：体检项只标"判定性"与"档位引用"，不造"卫生 L1/L2/L3"。理由：
   `meta.yaml` 的 `level` 与 `maturity-ladder.md` 的判据号是唯一成熟度真源，再开一套会互相漂移（命约 4 / P9）；
   分级解决"好看"，判定性标注解决"可判"。
3. **接入既有程序而不新开一套**：`governance-review` 的「卫生面」从三条粗筛升级为"引用本页走两步"；
   `audit/checklist.md` 加一行指针（**不改判据、不改编号**，并显式写明 `HY-n` 不映射判据号）；
   `README.md` 与 `.meta/docs-tier/README.md` 的 `audit/` 描述同步。
4. **本仓 dogfood 体检一次**（记录在本文 §Consequences 下方）：验证清单可执行、并暴露 HY-12 的口径问题
   （单文件源码/native 大文件会被误报），据此把 HY-12 收窄为"大二进制/非源码文件"。

## 两路独立审核（2026-11-18，opencode / antigravity，互不可见）

两路均给 **FAIL**（同一份审阅任务、同一提交 `a2a56e3`），合并去重后 **6 条 BLOCKING + 7 条 ADVISORY**，
全部已核对并修复，逐条如下（两路独立命中同一问题的，标"共同"）：

| # | 严重度 | 问题（合并后） | 来源 | 修复 |
|---|---|---|---|---|
| 1 | BLOCKING | §2.2 spec 骨架是**假绿**：夹具从不拷入被测门 → `bash` 127 被当作"拒绝"；`REJECTS` 先加后判；无正控制 | 共同 | 骨架内 `cp "$GATE"`、`REJECTS` 按真实 `$?` 累加、加正控制；用"恒拒门"做变异测试（正控制必红，实测 rc=1） |
| 2 | BLOCKING | §1 表格命令含字面 `\\.` → HY-3 **恒假**、HY-5 **恒真**（都标"机械"） | 共同 | 改单反斜杠；HY-5 用 `grep -lF`；表前写明"`\|` 是表格转义，复制时还原 `\|`"；本仓实跑：HY-3 exit 0、HY-5 = 0 |
| 3 | BLOCKING | `governance-review` 随 `init` 进入实例，却以**实例不存在的相对路径**引用本页（`audit/` 不播种）→ 悬空引用 | 共同 | 技能改为**框架仓 URL** 引用，并明写"实例侧没有该文件"；本页新增「在场范围」段 |
| 4 | BLOCKING | 骨架 spec 代码里没有代码位置的 `exit/return [1-9]` → 照抄即撞本仓 2.3 静态判据 | opencode | 末尾 `[ "$FAIL_N" -eq 0 ] \|\| exit 1` + `exit 0` |
| 5 | BLOCKING | §3 记录"必含四节"与 ADR 门冲突（缺 `## Decision` / `## Alternatives considered` 会被 1.8/1.10 拒） | opencode | §3 改为**标准 ADR 骨架**，四节作为 `## Decision` 子节；给出可过门的完整模板 |
| 6 | BLOCKING | "L2 升级与 `upgrade adopt` 之前必须有"是**虚构强制前置**：ladder 无此项、`adopt` 与卫生无关 | antigravity | 全文降级为"**review 层核对项**，不产生退出码、不接 `status`/`adopt`"；`checklists/audit.md` 同批改 |
| 7 | ADVISORY | `audit/checklist.md` 新增指针漏行首 `>`，切断口径声明块 | 共同 | 三行补 `>` |
| 8 | ADVISORY | HY-5 与 `docs/AGENTS.md:40` / `scratch-hygiene.sh` 的 E3 **口径不一致**（宽 vs 窄） | opencode | HY-5 收窄到 home 的 `release.yml`/`install.sh`，其余 workflow/scripts 标"宽筛属 review" |
| 9 | ADVISORY | dogfood 表静默漏 HY-1/HY-10（违反本页"不适用要写进记录"） | 共同 | 补两行；并注明 HY-3/HY-5 需按修正后命令复跑 |
| 10 | ADVISORY | §2.1 门骨架注释声称 4 项判据、实现只有 3 项；③ 在路径全缺时"恒真" | opencode | 注释改"三项判据"；③ 无可检索面时打印「不适用」而非静默通过 |
| 11 | ADVISORY | §4"报告必须原文复述"在 `governance-review` 的「本审查不覆盖」清单里无载体 | opencode | 技能的不覆盖清单登记本页 §4 |
| 12 | ADVISORY | 成果物路径缺 `{class}` 轴 → 照抄触发判据 1.3/1.4 | antigravity | 路径补 `.../process/yyyy-mm-dd-hygiene-baseline.md` |
| 13 | ADVISORY | "不设门"与"可机械核对"自相矛盾（同一句自述可判） | opencode | 与 #6 合并处理：**明确标 review 核对项**，不伪装成门、也不留"必须有"的硬承诺 |

**未采纳**：无（13 条全部处理；其中 #13 与 #6 合并为同一修复）。
**审核方法论收益**：两路独立审核在 #3/#4/#5/#12 上分别只命中一路——单路审核会漏；且 #1/#2 的"命令跑不出结论"
是本轮最有价值的发现（指引页自己的锚定命令必须先对本仓实跑）。

## Alternatives considered

- **把 DSH 的 `clean.ts` 并入 `scratch-hygiene.sh`（或新增清洁器）**：否决——它的语义绑 TS workspace 产物
  （`lib/`、`dist-exe/`、`.typecheck`、`node_modules` 是依赖目录），且是 TS/tsx 运行时；ponygo 是零依赖 bash、
  栈无关。可迁移的只有**删除安全不变量**，已按此收窄（§2.3）。
- **在框架里加"卫生门"**：否决——框架门会被计为"每个实例都白得"的假绿（`audit` 的实例门计数规则），
  且白名单/清理策略因仓而异（P9）。框架只给骨架，实例填白名单。
- **三等级（卫生 L1/L2/L3）**：否决——与 `level` + ladder 判据成第二套真源，必然漂移；
  且"卫生几级"没有判据真源，是典型假指标。改为"判定性（机械/部分/review）+ 档位引用"。
- **把卫生体检做成 `ponygo audit` 的第五问**：否决——四问是已发布契约（scorecard / checklist / JSON
  字段与多套测试钉死），加第五问是破坏性变更；本批只加指引页与指针，不动四问。
- **卫生基线记录设为门（缺记录 → status FAIL）**：否决——"这份体检是否认真"判不了，硬门只会逼人造文件
  （假门禁，P6）；改为 review 层面的前置核对。
- **只写散文式"仓库应保持整洁"指引**：否决——P2：靠自觉的约定必然衰减；每项必须给锚定命令或显式标 review。

## Consequences

- 植入多了一个**可执行的体检程序**（12 项 + 命令），而不是一句原则；L2 之前的"卫生设计"有了落点（基线记录）。
- 代价（诚实登记）：① 体检项里有 4 项是"部分/review"，不能全机械化；② "不适用"要靠人写理由，
  有人会漏（这是 review 成本，不是机械保证）；③ 基线记录不进门，可能被跳过——由 `governance-review`
  的 L2/adopt 前置核对兜住，但仍是靠自觉的一环。
- 本页与四问、`ponygo.audit/1` 字段、既有判据编号**均无耦合**；`ponygo audit` 的输出与分数零改动。
- **同步陷阱（本次踩到并回滚，记下来防再犯）**：`.meta/docs-tier/README.md` 在 `UPGRADE_UNIVERSE` 里，
  但它是**激活态豁免同步**的文件——`upgrade apply/--check` 对已激活实例跳过它。若无差别地"把仓库副本写回
  `ponygo` heredoc"，就会把**实例激活版**覆盖掉**模板态**模板，使 `init` 出的新实例一出生就是"已激活"，
  直接打穿判据 2.5 的模板态分支（实测全量 10 条红）。正确做法：只同步 `governance-review/SKILL.md`
  这类**纯 stage 文件**，docs-tier 注册表只改仓库副本、不动 heredoc；同步后必须跑全量而不是只看
  `upgrade --check`（它会因豁免而恒 0，掩盖这次覆盖）。

### 本仓 dogfood 体检结果（2026-11-18，`ponygo` 仓）

| ID | 结果 |
|---|---|
| HY-1 | `ls -d .scratch` 在场；`.scratch/` 约定锚点在 `docs/AGENTS.md`（临时产物统一下沉）✓ |
| HY-2 | `git ls-files .scratch` = 0 ✓ |
| HY-3 | `.gitignore` 声明 `.scratch/` ✓ |
| HY-4 | 构建产物入库 = 0 ✓ |
| HY-5 | 发布/安装链引用 `.scratch` = 0 ✓ |
| HY-6 | **不适用**：本仓无清理脚本（若将来新增，必须满足 §2.3 四条） |
| HY-7 | `.rgignore` 隔离 `/.agents/notes/archived/` ✓ |
| HY-8 | 根目录仅 4 个契约 md（AGENTS/CLAUDE/README/maturity-ladder），无游离过程文档 ✓ |
| HY-9 | 无生成物文件（模板双写在 `ponygo` 单文件内，不产文件）→ **不适用** |
| HY-11 | **不适用**：零依赖，无 lockfile |
| HY-10 | `find .agents/notes/implemented -mtime +180` 有历史候选，属 L3 语义判断 → 记为**候选，不作结论** |
| HY-12 | 唯一 >512KB 跟踪文件是 `ponygo` 本体（单文件 CLI = 有意的源码），**经点名排除**；无大二进制 ✓ |

> 表中 HY-3 / HY-5 的 ✓ 是**按审查修正后的命令**复跑所得（修正前表格里的 `\\.` 会分别造成恒假/恒真）；
> 命令以 `audit/hygiene-design.md` §1 现行正文为准。
