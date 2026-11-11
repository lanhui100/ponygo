# ponygo 成熟度阶梯（Maturity Ladder）

> **定位**：这是 ponygo（软件项目工程化治理元框架）"随项目推进自我迭代"的引擎坐标系。它把 `docs/methodology.md` 的 P2 可验证性、P6 形意分离、P9 负空间三条原理，翻译成一张**可机械判定的阶梯总表 + 一组"靠 review"的目标画像**。
> **核心铁律**：首版只交付到 L2 的可机械闭环；L3–L5 是"目标画像 + 依赖的未交付物清单"，不是可判定的等级。升级是**菜单式非线性**的，且每级**双向（可升可退）**。
> **术语约定**：英文术语首见加中文一次（如 lifecycle（状态轴）、class（类别轴）、ADR（架构决策记录））；命令、路径、文件名、字段名不加中文。判据一律写成「布尔项 + 命令」，不写散文式"满足"。
> **文档家载体（v2.0 起）**：治理规则的**家**是 `AGENTS.md`（agent 处理子树时自动并入上下文），人读契约是 `README`（agent 不主动读不进上下文）——两者分工，不混用（原理：methodology §5.1，实证 dsh）。

---

## 1. 阶梯总表

| 级 | 名字 | 一句话定位 | 启用条件 | 核心产物 | 退出标准 / 升格判据 | validation | 首版状态 |
|---|---|---|---|---|---|---|---|
| **L0** | 播种 | 让"决策"与"文档"各有一个可寻址的家，哪怕只记一条 | 项目从零起步，尚无任何治理载体 | `.meta/` 治理根 + `docs/` 最小文档家 | `.meta/` 存在 且 `meta.yaml` 含 `level` 字段 且 `docs/AGENTS.md` 存在 | 机械 | 已交付 |
| **L1** | 决策入册 + 文档有家 | 非平凡决策落成带 lifecycle × class 路径编码的记录；每个事实有家（AGENTS.md 自动加载） | L0 成立，且出现第一条值得记的非平凡变更 | `notes/{lifecycle}/{class}/yyyy-mm-dd-topic-title.md` + `docs/AGENTS.md` + 包文档覆盖 | notes/ 下文件数 > 0 且路径两轴合法；文档家判据全过 | 机械 | 已交付 |
| **L2** | 承诺可验 + 文档分层 | 把"必须/禁止"转成非零退出的门禁命令；tier 分类落地为已激活清单（条件判据：`docs-tier: off` 为显式 opt-out） | L1 成立，且出现需要被跨提交守住的硬约束 | `gates/` 门禁脚本 + 负样本 spec + 本地钩子 + docs-tier 激活 | format/classification 门禁可跑且拒绝非法样本；文档分层已激活（未声明/off 时 2.5 SKIPPED 不计入 PASS） | 机械 + 部分 | 已交付 |
| **L3** | 流程资产 | 高频+高判断力流程沉淀为带触发式 description 的技能 | L2 成立，且同一流程第三次重复 | `skills/` SKILL.md（触发内联 + 校准样例） | 技能元数据门禁 + 触发条件可路由 | 靠 review + 部分机械 | 目标画像（依赖 skill 资产化） |
| **L4** | 负空间 | 删除/归档/遗忘成为有验证的独立工程 | L3 或 L2 成立，且语料开始腐烂需要 GC（垃圾回收） | `notes/archived/` + 哈希封印 manifest + supersession 审计 + 复活条件 | 归档冻结可查（`bash .meta/gates/archive-verify.sh`）、复活条件在场（判据 1.11）、supersession 同变更处理 | 部分机械 | 部分机械（1.11 形状判据 + A6/A7 封印；supersession 审计仍靠 review） |
| **L5** | 领域定制 | 架构不变量 + 生成物漂移门等按领域量体裁衣 | 各领域问题已稳定出现，值得投资更贵捍卫层 | 运行时不变量 + gen-\* 漂移门 + 分层 CI | 不变量有捍卫者且漂移被命令拦住 | 靠 review + 部分机械 | 目标画像（依赖运行时不变量） |

> **validation 列诚实标注**：L0→L1→L2 的可判定判据标「机械」（可被现成 `git`/`test`/`grep`/`find` 命令判定，见 §5）；L3–L5 标「靠 review」或「部分机械」——它们的判据要么依赖尚未交付的脚本，要么依赖语义判断，首版不复检。

---

## 2. 首版止步 L2 的诚实声明

**首版只交付 L0–L2 的可机械闭环。** 这三个等级里的每一个判据，都锚定一条现成的 `git`/`find`/`grep`/`test` 命令（§5 展开）。L3–L5 在此文档中是**目标画像（名词 + 依赖清单）**，不是可判定等级——谁声称"我们到了 L4"，必须同时掏出 L4 依赖的那套机制（归档封印门 A6/A7 已随 `ponygo init` 交付，复活条件的形状判据 1.11 已交付；supersession 审计仍未交付），否则只是散文。

**每一级依赖"尚未交付的脚本/机制"清单：**

| 级 | 依赖的未交付物 | 交付前判据只能靠什么 |
|---|---|---|
| **L2 文档分层（部分）** | **doc-sync 门**——能把 tier 放置、slop（重复/历史叙事/手抄目录）清单、词数预算转成非零退出命令的脚本族（dsh 实证 43 叶（quick 21），ponygo 首版只交付"已激活清单"这一形状判据） | 已激活清单态机械可查；tier 放置正确性靠 review |
| **L3** | **skill 资产化**——SKILL.md 五要素（触发式 description / 真相源清单 / 程序步骤 / 校准样例 / 验证报告格式）的模板 + 一个 skill 元数据门禁；以及"每三次重复资产化"的计数机制 | 靠 review（人工判断某流程是否已到"第三次重复"该入库；形状审计已由 `audit` 只读机械判定，基线技能与 `.meta/skills-library/` 安装副本**不计** L3 证据） |
| **L4** | **归档哈希封印 + supersession 审计**——归档封印门 A6（`.meta/gates/archive-verify.sh`：append-only SHA-256 manifest，`check`/`seal` 位置子命令）与负样本自检 A7 **已交付**并接进 A1/A4；复活条件的形状判据 1.11 **已交付**（`verify-note.sh`）；仍未交付的是 supersession 范围审查程序（新增 note 触发旧 note 复查） | 归档目录存在可查；"封印是否被改过"由 A6 `check` 机械判定（哈希不符/缺条目/孤儿/重复 → exit 1）；复活条件这一节是否在场由 1.11 判定；**supersession 是否同变更处理仍靠 review** |
| **L5** | **运行时不变量 + 生成物漂移门**——invariant（不变量）断言服务、`gen-* --check` 逐字节漂移门、分层 CI 调度器（run-gates 等价物）、workflow 形状契约 | 大部分靠 review；类型层的部分可 `tsc`，但语义层靠 review |

**为什么停在 L2 而不是往前冲**：L3–L5 的每个等级都需要先交付一批**新的机械验证脚本**，而写这些脚本本身是有终身维护税的工程（P9 负空间）。首版把 L0–L2 的机制（决策入册 + 文档有家 + 承诺可验）先转起来，让飞轮启动，L3–L5 的脚本族由"菜单式选装"按需解冻（§3）。

---

## 3. 菜单式非线性升级

L0→L1→L2 是唯一有先后顺序的三级：必须先有家（L0）才能入册（L1），必须先有册（L1）才有"哪些承诺值得守"的清单去门禁化（L2）。

**L3–L5 是可勾选的能力项，不强制顺序。** 有的项目先要门禁（L2 后直接加 L5 的运行时不变量），有的先要负空间（防过度建设，L2 后直接上 L4 归档）。判据：哪类问题在该项目的规模/类型下**最痛**，就先解哪个。

**选装建议（按项目类型推荐优先级）：**

| 项目类型 | 优先顺序 | 一句话理由 |
|---|---|---|
| 长命利基库 / 框架 | L4 → L3 → L5 | 语料腐烂最快，先上归档冻结防"过时决策挤掉当前事实" |
| 多服务 / 多包 monorepo | L5 → L3 → L4 | 不变量（包清单、注册即 effect）先守住，扩散才防得住 |
| AI agent 为主开发者的仓库 | L3 → L4 → L5 | 技能是 agent 的"重复程序"载体，先资产化高频流程 |
| 文档重度 / 对外产品 | L3 → L5 → L4 | 文档漂移最先被用户看见，先建 tier 分层 |
| 小而美 / 自用工具 | 停在 L2 或退到 L0（见 §6） | 规模不值当，负空间优先于正空间 |

---

## 4. 每级双向：启用条件 + 退场条件

P9 负空间对称原理：**每次添加隐含终身维护税；删除不是添加的逆操作，而是需要同等判据、同等验证、同等记录基础设施的独立工程。** 因此每级不仅写"何时启用"，也写"何时退场/降级"。

### L0 播种

- **启用**：项目起点，尚无 `.meta/`。
- **退场 / 降级**：L0 不可退（没有更低的级）。若 `.meta/` 被整目录删除，视为"弃用 ponygo"——这是一次需记录的删除决策，不是静默消失。

### L1 决策入册 + 文档有家

- **启用**：`.meta/` 已存在，且出现第一条非平凡变更（行为 / 架构 / 跨文件契约 / 流程 / 测试策略 / 磁盘-线-配置格式变化）。
- **退场 / 降级**：当团队规模与"决策密度"跌破阈值（见 §6 停止线），入册成本 > 防蒸发收益时，降回 L0「纯长驻模式」：保留 `.meta/` 与已录决策，**停止强制新增**。降级动作 = 把"枚举化触发条件"从门禁降为可选建议，并在 `meta.yaml` 反映。文档有家判据随 L1 一起退场——不是"文档删掉"，而是"停止强制新增文档家"。

### L2 承诺可验 + 文档分层

- **启用**：出现需要被跨提交守住的硬约束（格式、分类、冻结、空白），且该约束已稳定、频率足够高到值得配命令；或文档量开始需要分层。
- **退场 / 降级**：**过度治理检测**——当某条门禁连续 N 次提交只拦到"注定在 PR 里也会被 review 抓到"的琐碎项（false-positive 疲劳），或门槛命令本身成为小团队摩擦主因时，**降级回 L1**：把该门禁 disable，保留决策入册与文档有家。降级本身同样须留痕并由 review 验收（记录一条"为何关掉"的 decision + 保留负样本 spec 以便日后复活）；`ponygo retire` 只改写声明并提醒，**不机械校验**这两项。

### L3 流程资产

- **启用**：同一高频+高判断力流程第三次重复出现（Rule of three，三次法则）。
- **退场 / 降级**：当技能失去真实消费者（对应流程不再发生），或技能本身成了需要 skill 维护的"第二次跳"，删除技能。判据同 §2 的诚实原则——删除技能要证明"无消费者 + 无恢复计划"，不是随手删。

### L4 负空间

- **机械判据（已交付）**：归档件一旦进 `.agents/notes/archived/`，用
  `bash .meta/gates/archive-verify.sh seal` 追加 SHA-256 封印（`.agents/notes/archived/manifest.sha256`，
  纯文本 append-only），随后 `bash .meta/gates/archive-verify.sh check`（pre-commit 经 A1、CI 经 A4 自动跑）
  对 manifest 与归档 `.md` 做双向一致校验：篡改一字节、缺条目（未封印）、孤儿条目、重复条目、非追加写入
  一律非零退出。封印来源用「`Status:` 首词 = `implemented`」做代理判据；**git rename 溯源仍靠 review**。
- **复活条件的形状（判据 1.11，已交付）**：`implemented/simplification/` 下的 note 必须含**围栏外**的
  `## Reintroduction conditions`；若同条含 `## Removed surface`，还须含至少一行检索收据（行内含
  `rg` / `grep` / `git grep`）——「无生产消费者」这个声称必须锚到一条可复跑的命令。判据真源
  `verify-note.sh`（1.11 段），看守面 A1/A4。**复活条件是否真成立（能否指导复活）、检索是否真跑过 = 靠 review**。
- **仍需 review 的部分**：supersession 范围审查（新决策是否在同变更里复查了被取代的旧决策）。
- **启用**：决策语料开始腐烂——陈旧的 implemented note 挤掉当前 facts，或 supersession 债务开始堆积（新增决策覆盖旧决策却不清理）。
- **退场 / 降级**：负空间这套 (归档封印 + supersession 审计 + `.rgignore`) 本身有维护税。当语料规模小到"人工扫一眼就知道哪些过期"时，降级：解除哈希封印门禁，归档退为普通移动 + 人工抽查。
  此时 1.11（复活条件形状）一并降为建议——但**已写下的 `## Reintroduction conditions` 不删**：
  复活条件是删除决策的唯一回程票，降级撤的是判定，不是载体。

### L5 领域定制

- **启用**：某领域问题（包清单不变量、生成物漂移、运行时契约）已稳定且反复出回归，值得投资比"类型 + review"更贵的捍卫层。
- **退场 / 降级**：L5 的门禁最贵（分层 CI 调度器 + workflow 形状契约），是最该被"规模值不值当"叫停的一级。当守卫的不变量数量下降、或团队转而去维护门禁本身而不是产品时，降级回 L2/L3。

---

## 5. 升格判据的"可判定化"细则（L0–L2 展开）

L0–L2 的每条退出标准，落到**布尔检查项 + 锚定命令**。这些是供 CLI / audit 复用的**唯一真源**，§1 总表的 validation 列「机械」即由此而来。这些判据的机械化实现已内置于 `ponygo status`（v2.0 起，文档判据并入）。

### L0 → L1 的退出标准

| # | 布尔检查项 | 锚定命令 | 判读 |
|---|---|---|---|
| 0.1 | `.meta/` 目录存在 | `test -d .meta && echo PASS \|\| echo FAIL` | PASS |
| 0.2 | `meta.yaml` 存在 | `test -f .meta/meta.yaml && echo PASS \|\| echo FAIL` | PASS |
| 0.3 | `meta.yaml` 含 `level` 字段 | `grep -q '^level:' .meta/meta.yaml && echo PASS \|\| echo FAIL` | PASS |
| 0.4 | `level` 取值是合法枚举（`0`…`5`） | `grep -qE '^level:[[:space:]]*[0-5]$' .meta/meta.yaml && echo PASS \|\| echo FAIL` | PASS |
| 0.5 | 最小文档家播种：`docs/AGENTS.md` 存在（文档标准的家） | `test -f docs/AGENTS.md && echo PASS \|\| echo FAIL` | PASS |

> 注：`meta.yaml` **仅含 `level` / `ai-surface` / `docs-tier` 字段**（跨任务统一契约）。若出现其它键，是规格违例，audit 应告警——合法键 = `level` + `ai-surface` + `docs-tier`，其余均为违例。
> 注：0.5 的"最小文档家"由 `ponygo init` 骨架生成（根 AGENTS.md 索引链 + `docs/AGENTS.md`）；根 `README.md` 是人读契约，不作为判据硬要求（L0 最小家 = AGENTS.md 自动加载层）。

### L1 → L2 的退出标准

| # | 布尔检查项 | 锚定命令 | 判读 |
|---|---|---|---|
| 1.1 | `notes/` 目录存在 | `test -d .agents/notes && echo PASS \|\| echo FAIL` | PASS |
| 1.2 | 决策文件数 > 0 | `find .agents/notes -name '*.md' ! -name 'README.md' ! -name '*.zh.md' \| wc -l` | 结果 > 0 |
| 1.3 | lifecycle 轴只含封闭集合 `proposed/implemented/rejected/archived` | `find .agents/notes -mindepth 1 -maxdepth 1 -type d -printf '%f\n' \| sort \| uniq` | 输出 ⊆ 上述四值 |
| 1.4 | class 轴来自封闭集合（`feature/bug-fix/simplification/architecture/process/testing`）∪ `notes/classes.local` 实例扩展 | `find .agents/notes -mindepth 2 -maxdepth 2 -type d -printf '%f\n' \| sort \| uniq` | 输出 ⊆ 六值 ∪ classes.local |
| 1.5 | 路径深度卡死为 `{lifecycle}/{class}/…`（class 必须嵌在 lifecycle 下） | `find .agents/notes -type f -name '*.md'` 逐条人工核对深度 | 无根层级裸 `.md` |
| 1.6 | 文件名匹配 `yyyy-mm-dd-topic-title.md` | `find .agents/notes -name '*.md' -printf '%f\n' \| grep -vE '^[0-9]{4}-[0-9]{2}-[0-9]{2}-.+\\.md$'` | 输出为空 |
| 1.7 | 每条决策含 `Status:` 行且与所在 lifecycle 一致；`rejected/` 的 `Status:` 首词为 `rejected` 时**同一行必须有理由**（分隔符 `—`/`-`/`:` 任一，其后剥掉空白后至少 **2 字节**） | `grep -Rl --include='*.md' '^Status:' .agents/notes/proposed` / `…/implemented` 等，交叉验证；`grep -rLE --include='*.md' '^Status: rejected[[:space:]]*(—|-\|:)[[:space:]]*[^[:space:]]{2,}' .agents/notes/rejected` 应为空 | 无不一致，且无「rejected 缺一行理由」 |
| 1.8 | 正文骨架与 lifecycle 匹配：proposed/rejected 含 `## Proposal` 且无现在时 `## Decision`；implemented **必含**现在时 `## Decision`，且禁提案时代标题（英文 `## Proposal`/`## Plan`/`## Migration plan`/`## Acceptance criteria` + **中文等价** `## 提案`/`## 计划`/`## 迁移计划`/`## 验收标准`/`## 验收`/`## 风险`/`## 待办`） | `grep -rLE --include='*.md' '^## Decision([[:space:]]\|$)' .agents/notes/implemented` 应为空；`grep -rE --include='*.md' '^## (Proposal\|Plan\|Migration plan\|Acceptance criteria\|提案\|计划\|迁移计划\|验收标准\|验收\|风险\|待办)([[:space:]]\|$)' .agents/notes/implemented` 应为空；`grep -rLE --include='*.md' '^## Proposal([[:space:]]\|$)' .agents/notes/proposed .agents/notes/rejected` 应为空 | 无错位 |
| 1.9 | 文档有家：`docs/AGENTS.md` 存在（文档标准的家，agent 自动加载）+ 根 `AGENTS.md` 含 `docs/AGENTS.md` 索引链（**条件子项 1.9b：仅 `ai-surface: on` 时 fail-closed，且只由 CLI 判**）+ 包文档覆盖或豁免 | `test -f docs/AGENTS.md`；`grep -q '^ai-surface:[[:space:]]*on' .meta/meta.yaml && grep -q 'docs/AGENTS.md' AGENTS.md`；`find packages crates src -mindepth 1 -maxdepth 1 -type d` 下每子目录有 `AGENTS.md` 或 `README.md`，或列入 `.meta/docs-tier/exemptions` | 1.9a/1.9c 恒 PASS；1.9b：on → 缺失/无链即 FAIL，off 或未声明 → SKIPPED 不计入 PASS |
| 1.10 | 每条决策必含备选节 `## Alternatives considered`（被否决的备选 + 落选理由） | `grep -rLE '^## Alternatives considered([[:space:]]\|$)' --include='*.md' --exclude='*.zh.md' --exclude='README.md' --exclude='AGENTS.md' .agents/notes/proposed .agents/notes/implemented .agents/notes/rejected`（`archived/` 冻结豁免，故不列入扫描面） | 输出为空 |
| 1.11 | 负空间形状：`implemented/simplification/` 的 note 必含**围栏外**的 `## Reintroduction conditions`；若同条含 `## Removed surface`，还须含至少一行检索收据（行内含 `rg` / `grep` / `git grep`） | `bash .agents/skills/write-adr/verify-note.sh`（1.11 段；扫描面 = `implemented/simplification/**/*.md`，排除 `*.zh.md`，`archived/` 冻结不在扫描面） | 输出无「1.11 …」FAIL 行 |

> 1.5 的机械化实现为"每个决策 `.md` **恰好**位于 `{lifecycle}/{class}/` 两级之内"——depth 1-2 的裸文件与 depth ≥4 的过深层均违例；`README.md` / `AGENTS.md`（治理契约载体，非决策记录）豁免。
> 1.6 的 `grep -vE` 命令豁免 `README.md` / `AGENTS.md`（占位说明与工作指引不算决策记录）；文件名中的日期必须真为 `yyyy-mm-dd` 而非占位符。1.6 的 `grep -vE` 只查格式；日期**合法性**可再机械判一条：
> `find .agents/notes -name '*.md' -printf '%f\n' | sed -E 's/^([0-9]{4}-[0-9]{2}-[0-9]{2})-.*/\1/' | while read d; do date -d "$d" >/dev/null 2>&1 || echo "非法日期: $d"; done`
> 输出为空即法合法。命令不可解析的环境（如无 GNU date）降级为 review——不得自称"机械判过"。
> 1.4 的扩展口：L5 领域定制常需新增 class——在 `.agents/notes/classes.local` 每行写一个额外 class 名（小写字母/数字/连字符，`#` 起注释）即被 1.4 认可；封闭集本身不放开，扩展须显式落盘留有审计载体。
> 1.8 的豁免规则：`archived/` 冻结豁免（保持归档时原貌）；`README.md` / `AGENTS.md` 豁免。原理：时态与状态一致——提案用现在时 `## Decision` 等于未批准的方案伪装成已落地的决定，状态轴在正文层失真；proposed → implemented 迁移时必须把 `## Proposal` 改写为现在时（Acceptance criteria / Risks 折叠进 `## Consequences`）。该判据源自 ponyllm 实例的实证漂移（proposed ADR 误用 `## Decision`，1.1–1.7 全 PASS——路径/文件名/Status 三重影子锁不到正文骨架）。
> **1.8 的正向断言（2026-11-09 起）**：`implemented/` 不只要"没有提案标题"，还**必须有现在时 `## Decision`**——"什么都没写"与"写对了"在反向判据下同形（两者都不含 `## Proposal`），缺 Decision 的 implemented 是"迁移只做了 `git mv`、正文没改写"的残留态。同时把禁入的提案时代标题**补上中文等价**（`## 提案` / `## 计划` / `## 迁移计划` / `## 验收标准` / `## 验收` / `## 风险` / `## 待办`）：中文标题曾整批逃过英文正则（本仓 `remove-yes-and-adapt-alt-governance` 的 `## 验收` 就是活样本——路径/Status/英文标题全绿，正文仍是提案骨架）。判据实现在真源 `verify-note.sh`（1.8 段），FAIL 文案区分两种因：缺 `## Decision` 报"迁移即改写：现在时 Decision 必须在场"，中文/英文提案标题沿用"implemented 含提案时代标题"。
> 1.8 的"判不到"：标题**质量**（`## Decision` 是否真写成了决定而非计划复述）仍是语义判断，靠 review 与 write-adr 校准样例。
> 1.7 的 `archived/` 豁免规则：archived/ 下决策的 `Status:` ∈ {`implemented`, `archived`} 均判一致（冻结归档保留原 implemented 态）；`README.md` / `AGENTS.md` 豁免。CLI 实现对带引号（`level: "2"`）与 CRLF 行尾比上方锚定命令更宽容（归一后判定），复判时以 `ponygo status` 输出为准。
> **1.7 的新增子项（2026-11-09 起）：`rejected/` 必须带一行理由**。`Status: rejected` 是 verdict，verdict 不写理由是"否决了但没人知道为什么"——被否决的方案在重开争执时唯一的证据就是那一行。判据：`rejected` 之后须有分隔符（`—` / `-` / `:`）+ 其后剥掉空白至少 **2 字节**（真源按 `wc -c` 计，**不是字符数**——故 1 个 CJK 字 = 3 字节即通过，单个 ASCII 字符 = 1 字节不通过）；FAIL 文案 `1.7 <path>：rejected 缺一行理由（Status: rejected — <为何否决>）`。豁免：`archived/`（冻结）、`README.md` / `AGENTS.md`、`*.zh.md`（双语配对，译文随母语版同批补齐——与 1.10 同口径；注意这条豁免只关"理由"这类正文承接项，`*.zh.md` 的头部契约「`Status:` 行在场且与目录一致」不因此豁免。本仓当前无 `*.zh.md`，该分支判据面为零）。
> 1.9 的"文档有家"三连判据由 `ponygo init` 骨架播种（0.5 已覆盖 docs/AGENTS.md 存在）；根 AGENTS.md 索引链在 `ponygo sync` 投影的常载命约中（v2.0 起）；包文档覆盖的豁免清单放 `.meta/docs-tier/exemptions`（每行一个免检包名，`#` 起注释）。
> **1.9b 为条件子项（2026-11-09 起，与 2.6 同一开关）**：根 `AGENTS.md` 含 `docs/AGENTS.md` 索引链这一项**仅当 `meta.yaml` 声明 `ai-surface: on` 时 fail-closed**——`on` + 根文件缺失/无链 = 1.9 FAIL（声明即承诺：AI 常载入口缺位，索引链无处安放）；`off` 或未声明 = 该子项 **SKIPPED，不计入 PASS**（结论行禁写「全部 PASS」，只写「1.9b SKIPPED」+ WARN 催声明）。为什么挂开关而不是无条件判：不生成 AI 投影的实例没有"常载入口"这个对象，无条件判等于要求一个不存在的载体；但一旦声明 `on`，缺文件静默 PASS 就是假绿（旧实现 `[ -f ] && ! grep -q` 恰是这个漏洞：文件缺失 → 条件为假 → 不报错 → 静默通过）。1.9a（`docs/AGENTS.md` 存在）与 1.9c（包文档覆盖）不受该开关影响，恒判。
> **1.9b 的判定归属（别把三处门禁混为一谈）**：1.9b **只由 CLI 侧判**——`verify_ladder` 的 1.9b 分支（`ponygo status` 与 `ponygo audit` 共用同一实现），因为它要读 `meta.yaml` 的开关声明与根 `AGENTS.md` 的投影块形态。判定真源 `verify-note.sh` **只判 1.9a**（`docs/AGENTS.md` 存在），所以 **A1（pre-commit）与 A4（ci-verify.sh）看不到 1.9b**——两者都经真源，覆盖的是格式类判据（1.1–1.11）。看守面因此是：本地 `ponygo status`（`pre-commit` 不跑它）+ CI 的 `ponygo audit --run-specs` 步（A5 workflow 步骤 ②，同一 `verify_ladder`，故 CI 侧实际有看守）。把 1.9b 搬进真源等于复制一份成对哨兵判据（P9 双实现），不做。
> **1.10 为何是硬判据（2026-10-29 起）**：Alternatives 是**非平凡决策的实质内容**，不是格式装饰——只写 `## Decision` 的 ADR 退化为"事后记录"（记录了选了什么，答不出为什么不选另一条），重开争执时无法复原当时的权衡，决策史只剩结论而无理由。契约本就写在 `.agents/notes/README.md`（每条决策必含备选与落选原因），此前只是没有机械看守（覆盖缺口见 `implemented/process/2026-10-29-forced-adr-gate-wiring.md`）——补 1.10 即把"已声明但无人守"的承诺转成判定真源里的一条硬判据，不留 WARN 软档（WARN 不计入 PASS 等于默认放过）。**豁免口径**：`archived/` 冻结豁免（与 1.8 同口径，保持归档时原貌）；`README.md` / `AGENTS.md` 豁免（治理契约载体，非决策记录）；`*.zh.md`（双语配对）豁免——译文随母语版同批补齐，不独立判。**判不到的部分**：备选的**质量**（是否真的权衡过、落选理由是否成立）与"多类是否该拆条"仍是语义判断，靠 review 与 write-adr 校准样例。
> 1.10 的实现归属：只由判定真源 `verify-note.sh` 判定（P9：一份判据一份实现，两份必然漂移），CLI 的 `verify_ladder` **不复刻** 1.10——其 L1 段仍覆盖 1.1–1.9，并在 `status` 输出与代码注释里明文声明该范围；1.10 的看守面由本地门 A1（pre-commit）与远端门 A4（CI）承担，两者都经真源。因此 `ponygo status` 不报 1.10 是**设计选择，不是滞后缺口**；`upgrade --check` 对真源/SKILL/spec 的漂移信号见 `revisions/accepted/2026-10-29-alternatives-criterion-1-10.md`。
> **1.11（负空间形状判据，2026-11-11 起，自精微层 `[future]` 解冻）**：删除/收窄类决策必须把**复活条件**写成正文的一节——只写"删了什么"的 simplification note 答不出"什么条件下该把它接回来"，被删的能力就此失去回程票（P9 负空间对称：删除不是添加的逆操作，需要同等判据、同等验证、同等记录）。**判据范围**：`implemented/simplification/**/*.md`（排除 `*.zh.md`；`archived/` 冻结豁免、不在扫描面）；必含**围栏外**的 `## Reintroduction conditions`；若同条含 `## Removed surface`，还须含至少一行检索收据（行内含 `rg` / `grep` / `git grep`）——把"无生产消费者"这一声称锚到一条可复跑的命令；检索词按字面匹配（`rg --fixed-strings` 语义），判据不解释正则。**判不到的部分**：复活条件是否真成立（"以后有需要再说"同样 PASS）、那些检索是否真跑过——靠 review（见下表 1.11 行）。**实现归属**：只由 `verify-note.sh` 判定（与 1.10 同口径：CLI 不复刻，一份判据一份实现）；看守面 A1（pre-commit，暂存 ADR 子集）与 A4（CI，全树）。**编号为何落在 L1 段**：它锁的是"一条 note 的正文形状"，与 1.10 同位；它被记作 L4 的机械证据，是因为负空间实践要等语料开始腐烂才值得付（§1 L4 行）。

### 非机械项（四处"机器到不了"，靠 review，不装假门禁）

判据 1.1–1.11 锁的是**形状**。下面四项属于同一批决策契约里**内容质量**的部分：机械判定只能证明"写了"，
证明不了"写得对"。集中登记在此，与 `.agents/notes/README.md` 的「非机械项（机械影子管不到、必须靠
review 的四件事）」小节**同源同表**：那边是决策记录侧的操作口径（写的时候怎么自查），本节是判据真源侧
的登记（评审的时候怎么抽查）——1.7 / 1.8 / 1.10 / 1.11 四行必须逐条对应，**改一处须同批改另一处**。

| # | 机器判什么（在场性） | 机器判不到什么（质量） | 抽查动作 |
|---|---|---|---|
| 1.7 | `Status:` 行在场且与目录一致；`rejected` 带 ≥2 字节实质理由（剥离分隔符、空白、ASCII 与 CJK 标点后的剩余正文） | 理由**是否成立**（"与 X 冲突"可能早就和解了） | governance-review：抽 `rejected/` 条目逐条回问"该理由今天还成立吗"；不成立则补注现状或改判 |
| 1.8 | `implemented/` 含现在时 `## Decision`、且无提案时代标题 | 标题下的内容**是否真是决定**（而不是把计划换个标题） | change-review：抽 implemented ADR 的 Decision 对照代码/提交，看它陈述现状还是意图 |
| 1.10 | `## Alternatives considered` 在场 | 备选**是否真权衡**（写"备选：无（本条无替代方案）"同样 PASS） | write-adr 校准样例 + governance-review 抽查：每条备选是否含落选理由、能否复原当时的取舍 |
| 1.11 | `implemented/simplification/` 含围栏外 `## Reintroduction conditions`；含 `## Removed surface` 时含检索收据行 | 复活条件**是否真成立**（"以后有需要再说"同样 PASS）、那些检索是否真跑过 | governance-review / change-review：抽 simplification note 问"照这条条件，今天能判定该不该复活吗" |
| （无判据号）ai-surface 技能白名单 | **无机械影子**——白名单是声明，不参与任何判据 | 登记的技能是否仍该自主路由、新增技能是否该入白名单、`ai-surface: off` 后登记项是否随之失效 | 靠自觉 + review：改 `.agents/skills/` 或 constitution「AI 工具适配」节时人工核对；**无门**（P2：显式标注"靠自觉"，不装假门禁） |

> 最后一行没有判据号，也不打算有：技能白名单是**声明**而非**判据**，给"默认关的开关"造门禁等于逼
> 每个不用 AI 的实例为它付维护税（常载命约 5）。在此登记的唯一目的，是别让人把"写在 constitution 里"
> 读成"已被机械看守"。

**为什么集中登记**：散落的"靠 review"会被读成"不用管"。集中后有三个用法——① 评审时逐项抽查；
② 新写决策时知道哪几处必须用人工判断、不能靠判据绿放行；③ 判据加严时先看这张表判断本次加严覆盖的是
哪一层（在场性还是质量），避免把质量项误当机械项对外宣称。

### L2 本身的退出标准（升到 L3+ 前，L2 必须自洽）

| # | 布尔检查项 | 锚定命令 | 判读 |
|---|---|---|---|
| 2.1 | `gates/` 目录存在且非空；**且框架门资产（A1/A2/A4/A6/A7）与模板逐字节一致**——漂移 = 门可能被替换/弱化，判 FAIL（形状判据看不见字节变化，故必须逐字节比对；其余 universe 文件如 README/SKILL 漂移仍为观察项，不改退出码） | `find .meta/gates -type f ! -name 'README.md' ! -name '.gitkeep' \| wc -l`；`bash ponygo status`（漂移行 + `ponygo upgrade` 报告） | 结果 > 0 **且**门资产漂移 0 处 |
| 2.2 | 门禁脚本可运行（非零退出是"拒绝"语义） | `<gate-script> --help` 或跑一次空样本 | 返回可理解的帮助 / 退出码 |
| 2.3 | 有负样本 spec，且**L2 必须有 ≥1 个实例门**（框架随 init 交付的 A1/A4/A6/A8 不计实例门——否则每个实例都白得，判据永远免判）、每个实例门带同 Stem 同语言后缀的 spec，**且该 spec 含真实拒绝断言**（至少一处 `exit [1-9]` / `return [1-9]` 落在代码位置：只 `exit 0` 的 spec 恒绿，证明不了门会拒绝非法样本；**注释与 echo/printf 字符串里的 `exit 1` 不算证据**） | `find .meta/gates -type f -name '*.spec.*'`；`bash ponygo audit --level M` 逐门配对 + 拒绝断言扫描（先剔除注释行/行内注释与引号内字符串，再匹配 `(^\|[;&\|]\|then\|else)[[:space:]]*(exit\|return)[[:space:]]+[1-9]`；扫描面 = **与门配对的 spec**，纯正向 smoke spec 不计） | 实例门 ≥1、无未配对门、每个配对 spec 含真实拒绝断言 |
| 2.4 | 本地钩子已挂载**且真接线**（五条 AND）：① `core.hooksPath` 已设 ② 归一化（`~` 展开 + `pwd -P`/`realpath`）后目录内 `pre-commit` **存在** ③ 该文件**可执行**（`-x`；非可执行钩子被 git 静默忽略） ④ 哨兵块（`# >>> ponygo-gate: adr-verify v1 >>>` … `# <<< ponygo-gate: adr-verify v1 <<<` 区间）**逐字节等于**规范块（EOL 归一；块内含 marker 行 `# ponygo-gate: adr-verify v1` 与非注释调用行）**且位置合规**——在 `#!` 首行之后（无 shebang 则文件最前）、**首个顶层 `exit`/`exec` 之前**（位置是硬判据：末尾追加/睡在 `exit 0` 之后的块永不执行，位置不合规即判未接线并要求迁移） ⑤ `<root>/.meta/gates/adr-verify.sh` 存在 | `bash ponygo status`（①–⑤ 由 `verify_ladder` / `gate_hook_wired` 实现；④ 的实现 = 抽块后与内置规范块逐字节 `diff` + 位置检查）；人工代理：`p=$(git config core.hooksPath); d=$(cd "$p" && pwd -P); test -x "$d/pre-commit" && sed -n '/>>> ponygo-gate: adr-verify v1 >>>/,/<<< ponygo-gate: adr-verify v1 <<</p' "$d/pre-commit"` | ①–⑤ 全真 → PASS；任一不真 → FAIL，文案**按因**给补救（非 git → `git init` 后重跑；目录不可达 → `git config core.hooksPath .githooks`；不可执行 → `chmod +x <hook>`；块不合规/位置不合规 → `bash ponygo init`（删旧块 + 前置新块，一次原子替换）） |
| 2.5 | 文档分层已激活（**条件判据**）：`docs-tier: on` 声明且 `docs-tier/README.md` 非模板态（含"已激活文档家"标记） | `grep -q '已激活' .meta/docs-tier/README.md` | 存在（仅当 `meta.yaml` 含 `docs-tier: on` 时校验；未声明/`off` 时 2.5 SKIPPED 不计入 PASS） |
| 2.6 | AI 常载命约已投影且**新鲜**（**条件判据**）：`ai-surface: on` 声明，且根 `AGENTS.md` **与** `CLAUDE.md` 各含**恰一对**哨兵块 `<!-- BEGIN constitution -->` … `<!-- END constitution -->`（BEGIN 行号 < END、块内非空），块正文等于 constitution 的 canonical 投影 | `bash ponygo status`（`verify_ladder` 统一判，status 与 audit 共用；未声明=SKIP+WARN、`off`=显式 opt-out 不判 FAIL、`on` 结构错误/正文漂移=FAIL 并按因给修法；重复/倒序标记区只提示手工清理，不声称 sync 可修） | 存在（仅当 `meta.yaml` 含 `ai-surface: on` 时校验；未声明 → 2.6 SKIPPED 不计入 PASS；`off` → 结论行写「2.6 未启用」） |

> L2 判据的关键不在"脚本多"，而在**每条"必须/禁止"承诺都能被一条非零退出命令抓到**（P2）。2.2–2.3 是 L2 能被称为"承诺可验"的最低自证。
> 2.1 的 README/`.gitkeep` 豁免：占位说明文件不算门禁落地。2.2 的机械化实现以 `bash -n` 语法校验为**代理判据**，真判据仍是 `<gate> --help` / 空样本拒绝非零退出，供人工补验。
> 2.3 的机械化实现：存在性判据（形状，靠 review）。M 档另对每个实例门作同 Stem、同语言后缀配对：`foo.sh ↔ foo.spec.sh`、`foo.ps1 ↔ foo.spec.ps1`；唯一编排器豁免是 `ci-verify.sh`，框架内置 A1/A2/A6/A7 不冒充实例门。未配对项列入人读缺口与 JSON `gaps: ["gate_spec_missing"]`，默认 `audit` 非零拒绝；`.ps1` 配对仅作形状检查，不由 `audit --run-specs` 执行，其实际拒绝语义靠对应平台 CI 或 review。**执行判据**是 opt-in 的 `ponygo audit --run-specs`——跑 `*.spec.sh` 并断言各自 exit 0（契约见 `.meta/gates/README.md`；有 `timeout` 时软 25s + KILL 兜底 5s（最坏 30s）；嵌套由 `PONYGO_AUDIT_SPEC_DEPTH` 判定——`≥1` 时该层拒绝执行 spec）。**fail-closed**：存在未被真正执行的 spec（0 个 / 自报 SKIPPED（含部分）/ 递归护栏拦截）时，`audit` 以 **exit 3（证据不足）** 结束且不得输出「机械判据全部 PASS」；**无有效内容**（去空白与注释后为空）的 spec 判 FAIL → exit 1；判据 FAIL 优先于证据不足（exit 1 > 3）。为什么默认不执行：只读命令（`status`/`audit`）不得执行仓库脚本（对陌生遗留仓库 = 任意代码执行），故执行需显式开关。"空 spec 文件"过得了存在性，证明不了任何拒绝语义。
> **2.4 为加强判据（本地钩子真接线，2026-10-29 起）**：原判据「`core.hooksPath` 指向已配置路径」只证明**目录被指向**，不证明钩子真在跑——一行 `grep 'adr-verify'` 命中注释即可骗过，非可执行钩子被 git 静默忽略又让判据假达标（R3/R5）。故 2.4 = 表中①–⑤ 五条 AND：`hooksPath` 先展开 `~` 再归一化（`realpath` / `pwd -P`）比较（绝对路径与符号链接不误判"指向别处"，R9）；④ 用**哨兵块逐字节等于规范块**而非"含某行"——一举封死 `echo adr-verify.sh`、`|| true`、`if false; then … fi`、`: adr-verify.sh`、注释掉调用行等全部变体（F3）。**补救按因分支**（不许一律给 `bash ponygo init`）：非 git → 先 `git init` 再重跑；`hooksPath` 指向不可达目录 → `git config core.hooksPath .githooks`；钩子**不可执行** → `chmod +x <hook>`（`init` 不会替你激活沉睡钩子）；块不合规/缺失 → `bash ponygo init`（幂等重建块：临时文件 + `mv` 原子替换，`flock` 保护，半截块整块重建）。`hooksPath` 已设（如 husky 绝对路径）时 `init` 一律不动它，直接对该目录的 `pre-commit` 动手。①–⑤ 全真才 PASS，缺一即 FAIL——判据加强不改编号，结论行文案仍是 `2.1–2.4 PASS`。判据原理与代价见 `.agents/notes/implemented/process/2026-10-29-forced-adr-gate-wiring.md`。
> 2.4 的哨兵块形态（**插在 `#!` 首行之后**，既有字节顺序与内容零改动；末尾追加不算接线——既有钩子常以 `exit 0` 结尾，末尾块永不执行；块位置在首个顶层 `exit`/`exec` 之后视为未接线并迁移。首尾同文，marker 行 `# ponygo-gate: adr-verify v1` 供机器识别）：
> ```bash
> # >>> ponygo-gate: adr-verify v1 >>>
> if [ -f "$(git rev-parse --show-toplevel)/.meta/gates/adr-verify.sh" ]; then
>   bash "$(git rev-parse --show-toplevel)/.meta/gates/adr-verify.sh" || exit 1
> fi
> # <<< ponygo-gate: adr-verify v1 <<<
> ```
> 2.5 的"文档分层已激活"由 `ponygo init` 生成**模板态**（仅骨架占位）——升到 L2 时把 `.meta/docs-tier/README.md` 推进为"已激活文档家清单"（doc-sync 门作为 L3 依赖，§2），判据只锁"已从模板态离开"这一形状。tier 放置正确性靠 review（§2 诚实声明）。
> **2.5 为条件判据（v2.4 起，Q1=A）**：声明载体是 `meta.yaml` 的 `docs-tier: on|off` 键（顶格、值仅小写 on/off；`on` = 启用文档分层并校验 2.5，`off` = 显式 opt-out，未声明 = SKIP + WARN 催声明）。状态机：**undeclared = SKIP + WARN 催声明（不计入 PASS）**；**off = 显式 opt-out（结论行改写为"2.1–2.4 PASS；2.5 未启用"，禁写"全部 PASS"）**；**on + 家清单仍有 `【TODO】` 残留 = FAIL**；**off + 已激活 = 矛盾 WARN（声明与事实不符，催对齐）**；**undeclared + 已激活 = PASS（实际做到优先于声明）**。`docs-tier: on` 但模板态未激活同样 FAIL。仅 `level >= 2` 时生效（L1 声明 docs-tier: on 被忽略，2.x 不在 L1 判据内），`lv >= 3` 同 L2 分支处理。声明为何不是"目录存在即可"：目录在 init 时即生成模板态，存在 ≠ 已激活——若"存在即声明"，模板态实例会被误判为已启用（见 §3.3 的 L 包实施）。
> **`off` 的提示闭环**：`off` 时 `status` 提示"建议录一条 decision 说明为何不上文档分层"（对齐 `retire` 退级须录 decision 的纪律）；但 `.agents/notes/**` 下**已有文件名含 `docs-tier` 的 decision** 时该提示**静默**（已回应的建议不再重复催，避免 WARN 通胀）。上面"off + 已激活 = 矛盾 WARN"不受此静默影响——那说的是声明与事实不符，仍须对齐。

---

## 6. 停止线：以规模值不值当为准

（呼应 methodology §10「停止线：以规模值不值当为准」的原文落点）

**第 2 条停止线（与 `.meta/constitution/constitution.md`「停止线」第 2 条同源）：`meta.yaml` 的
`level:` 是「当前档位」——已经在跑的那一档，不是未来目标。** 在达到下一档之前，不新增超出当前
档位的机制（门禁 / skill / 文档分层档位）；声明高于实际验到的档位时，`ponygo status` /
`ponygo audit` 的结论行显式写「已声明 Lx，仅验证到 Ly」——声明不是验证，未验证 ≠ 通过。

**规模阈值（承诺密度 × 人数）：**

| 规模信号 | 建议动作 |
|---|---|
| 单人 + 决策密度 < 1 条/周 + 无硬约束需跨提交守 | **整体 disable L2+**：退到「纯 L0 长驻模式」（见下），只保留决策入册与最小文档家作为"人脑外挂"，不加任何门禁 |
| 单人但决策密度 ≥ 1 条/周 或 有记忆性/格式性硬约束 | 保留 L1 + 上最轻的 L2（仅 format 门禁，不上 classification / 冻结 / 文档分层——即 **2.1–2.4 + `docs-tier: off`**，2.5 显式 opt-out） |
| 2–5 人 | L1 + L2 启动，L3–L5 按 §3 选装 1–2 项，其余挂起 |
| ≥ 5 人或多服务/monorepo | L2 + 至少一项 L5 不变量 + L4 归档（语料腐烂速度随人数指数上升） |

**「纯 L0 长驻模式」定义**：`.meta/` + `meta.yaml`（`level: 0`）+ `.agents/notes/` 目录 + 最小文档家（`docs/AGENTS.md`）保留（历史决策不删），但**停止一切强制新增和门禁**。这是一个合法的长期状态，不是"半成品"——它的判据是"规模不值当"，而非"没时间做完"。

**停止线是双向的**：规模涨过头就升，规模跌破阈值就退。升级和降级都走同一个判据（§4 的退场条件），都记录为一条 decision。

---

## 附：判据真源说明

- §5 的 L0–L2 布尔检查项 + 命令，是 CLI `/ audit` 复用对齐的**唯一真源**；§1 总表是它的索引，不重复载判据。
- §1 总表「validation」列的「机械」**仅当且仅当**指 §5 里对应的命令能跑；「部分机械 / 靠 review」是 P6 形意分离的诚实条款——机器到不了的地方（真实性、价值判断、是否过度治理）显式标注，不写假门禁制造虚假安全感。**判据 2.5 为条件判据**：其「机械」身份以实例显式声明 `docs-tier: on` 为前提，未声明/`off` 时标注 SKIPPED——这是 condition 型 validation 的诚实标注（声明驱动，非恒真）。
- 本文档自身亦遵守 P2：每级判据最终都落到命令或显式"靠 review"，不写散文式"满足"。
