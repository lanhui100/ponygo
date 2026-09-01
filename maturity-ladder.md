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
| **L2** | 承诺可验 + 文档分层 | 把"必须/禁止"转成非零退出的门禁命令；tier 分类落地为已激活清单 | L1 成立，且出现需要被跨提交守住的硬约束 | `gates/` 门禁脚本 + 负样本 spec + 本地钩子 + docs-tier 激活 | format/classification 门禁可跑且拒绝非法样本；文档分层已激活 | 机械 + 部分 | 已交付 |
| **L3** | 流程资产 | 高频+高判断力流程沉淀为带触发式 description 的技能 | L2 成立，且同一流程第三次重复 | `skills/` SKILL.md（触发内联 + 校准样例） | 技能元数据门禁 + 触发条件可路由 | 靠 review + 部分机械 | 目标画像（依赖 skill 资产化） |
| **L4** | 负空间 | 删除/归档/遗忘成为有验证的独立工程 | L3 或 L2 成立，且语料开始腐烂需要 GC（垃圾回收） | `notes/archived/` + 哈希封印 manifest + supersession 审计 | 归档冻结可查、supersession 同变更处理 | 部分机械 | 目标画像（依赖归档哈希封印 + supersession 审计） |
| **L5** | 领域定制 | 架构不变量 + 生成物漂移门等按领域量体裁衣 | 各领域问题已稳定出现，值得投资更贵捍卫层 | 运行时不变量 + gen-\* 漂移门 + 分层 CI | 不变量有捍卫者且漂移被命令拦住 | 靠 review + 部分机械 | 目标画像（依赖运行时不变量） |

> **validation 列诚实标注**：L0→L1→L2 的可判定判据标「机械」（可被现成 `git`/`test`/`grep`/`find` 命令判定，见 §5）；L3–L5 标「靠 review」或「部分机械」——它们的判据要么依赖尚未交付的脚本，要么依赖语义判断，首版不复检。

---

## 2. 首版止步 L2 的诚实声明

**首版只交付 L0–L2 的可机械闭环。** 这三个等级里的每一个判据，都锚定一条现成的 `git`/`find`/`grep`/`test` 命令（§5 展开）。L3–L5 在此文档中是**目标画像（名词 + 依赖清单）**，不是可判定等级——谁声称"我们到了 L4"，必须同时掏出 L4 依赖的那套未交付机制，否则只是散文。

**每一级依赖"尚未交付的脚本/机制"清单：**

| 级 | 依赖的未交付物 | 交付前判据只能靠什么 |
|---|---|---|
| **L2 文档分层（部分）** | **doc-sync 门**——能把 tier 放置、slop（重复/历史叙事/手抄目录）清单、词数预算转成非零退出命令的脚本族（dsh 实证约 30 门，ponygo 首版只交付"已激活清单"这一形状判据） | 已激活清单态机械可查；tier 放置正确性靠 review |
| **L3** | **skill 资产化**——SKILL.md 五要素（触发式 description / 真相源清单 / 程序步骤 / 校准样例 / 验证报告格式）的模板 + 一个 skill 元数据门禁；以及"每三次重复资产化"的计数机制 | 靠 review（人工判断某流程是否已到"第三次重复"该入库） |
| **L4** | **归档哈希封印 + supersession 审计**——`verify-archived-*` 脚本（append-only SHA-256 manifest）、`.rgignore` 隔离归档、新增 note 触发的 supersession 范围审查程序 | 部分机械（归档目录存在可查），但"封印是否被改过""supersession 是否同变更处理"靠脚本，脚本尚未交付 |
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
- **退场 / 降级**：**过度治理检测**——当某条门禁连续 N 次提交只拦到"注定在 PR 里也会被 review 抓到"的琐碎项（false-positive 疲劳），或门槛命令本身成为小团队摩擦主因时，**降级回 L1**：把该门禁 disable，保留决策入册与文档有家。降级本身要过同样的判据（记录一条"为何关掉"的 decision + 保留负样本 spec 以便日后复活）。

### L3 流程资产

- **启用**：同一高频+高判断力流程第三次重复出现（Rule of three，三次法则）。
- **退场 / 降级**：当技能失去真实消费者（对应流程不再发生），或技能本身成了需要 skill 维护的"第二次跳"，删除技能。判据同 §2 的诚实原则——删除技能要证明"无消费者 + 无恢复计划"，不是随手删。

### L4 负空间

- **启用**：决策语料开始腐烂——陈旧的 implemented note 挤掉当前 facts，或 supersession 债务开始堆积（新增决策覆盖旧决策却不清理）。
- **退场 / 降级**：负空间这套 (归档封印 + supersession 审计 + `.rgignore`) 本身有维护税。当语料规模小到"人工扫一眼就知道哪些过期"时，降级：解除哈希封印门禁，归档退为普通移动 + 人工抽查。

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

> 注：`meta.yaml` **仅含 `level` 字段**（跨任务统一契约）。若出现其它键，是规格违例，audit 应告警——合法键 = `level` + `ai-surface`，其余均为违例。
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
| 1.7 | 每条决策含 `Status:` 行且与所在 lifecycle 一致 | `grep -Rl '^Status:' .agents/notes/proposed` / `…/implemented` 等，交叉验证 | 无不一致 |
| 1.8 | 正文骨架与 lifecycle 匹配：proposed/rejected 含 `## Proposal` 且无现在时 `## Decision`；implemented 无提案时代标题 | `grep -rE '^## (Proposal\|Plan\|Migration plan\|Acceptance criteria)([[:space:]]\|$)' .agents/notes/implemented` 应为空；`grep -rLE '^## Proposal([[:space:]]\|$)' .agents/notes/proposed .agents/notes/rejected` 应为空 | 无错位 |
| 1.9 | 文档有家：`docs/AGENTS.md` 存在（文档标准的家，agent 自动加载）+ 根 `AGENTS.md` 含 `docs/AGENTS.md` 索引链 + 包文档覆盖或豁免 | `test -f docs/AGENTS.md`；`grep -q 'docs/AGENTS.md' AGENTS.md`；`find packages crates src -mindepth 1 -maxdepth 1 -type d` 下每子目录有 `AGENTS.md` 或 `README.md`，或列入 `.meta/docs-tier/exemptions` | 全 PASS |

> 1.5 的机械化实现为"每个决策 `.md` **恰好**位于 `{lifecycle}/{class}/` 两级之内"——depth 1-2 的裸文件与 depth ≥4 的过深层均违例；`README.md` 豁免。
> 1.6 的 `grep -vE` 命令豁免 `README.md`（占位说明不算决策记录）；文件名中的日期必须真为 `yyyy-mm-dd` 而非占位符。1.6 的 `grep -vE` 只查格式；日期**合法性**可再机械判一条：
> `find .agents/notes -name '*.md' -printf '%f\n' | sed -E 's/^([0-9]{4}-[0-9]{2}-[0-9]{2})-.*/\1/' | while read d; do date -d "$d" >/dev/null 2>&1 || echo "非法日期: $d"; done`
> 输出为空即法合法。命令不可解析的环境（如无 GNU date）降级为 review——不得自称"机械判过"。
> 1.4 的扩展口：L5 领域定制常需新增 class——在 `.agents/notes/classes.local` 每行写一个额外 class 名（小写字母/数字/连字符，`#` 起注释）即被 1.4 认可；封闭集本身不放开，扩展须显式落盘留有审计载体。
> 1.8 的豁免规则：`archived/` 冻结豁免（保持归档时原貌）；`README.md` 豁免。原理：时态与状态一致——提案用现在时 `## Decision` 等于未批准的方案伪装成已落地的决定，状态轴在正文层失真；proposed → implemented 迁移时必须把 `## Proposal` 改写为现在时（Acceptance criteria / Risks 折叠进 `## Consequences`）。该判据源自 ponyllm 实例的实证漂移（proposed ADR 误用 `## Decision`，1.1–1.7 全 PASS——路径/文件名/Status 三重影子锁不到正文骨架）。
> 1.7 的 `archived/` 豁免规则：archived/ 下决策的 `Status:` ∈ {`implemented`, `archived`} 均判一致（冻结归档保留原 implemented 态）；`README.md` 豁免。`*.zh.md`（双语配对）**不在豁免之列**——须独立满足头部契约。CLI 实现对带引号（`level: "2"`）与 CRLF 行尾比上方锚定命令更宽容（归一后判定），复判时以 `ponygo status` 输出为准。
> 1.9 的"文档有家"三连判据由 `ponygo init` 骨架播种（0.5 已覆盖 docs/AGENTS.md 存在）；根 AGENTS.md 索引链在 `ponygo sync` 投影的常载命约中（v2.0 起）；包文档覆盖的豁免清单放 `.meta/docs-tier/exemptions`（每行一个免检包名，`#` 起注释）。

### L2 本身的退出标准（升到 L3+ 前，L2 必须自洽）

| # | 布尔检查项 | 锚定命令 | 判读 |
|---|---|---|---|
| 2.1 | `gates/` 目录存在且非空 | `find .meta/gates -type f ! -name 'README.md' ! -name '.gitkeep' \| wc -l` | 结果 > 0 |
| 2.2 | 门禁脚本可运行（非零退出是"拒绝"语义） | `<gate-script> --help` 或跑一次空样本 | 返回可理解的帮助 / 退出码 |
| 2.3 | 至少一个门禁带负样本 spec（构造非法样本证明门会拒绝） | `test -f .meta/gates/*.spec.*`（按实际命名） | 存在 |
| 2.4 | 本地钩子已挂载（若交付） | `git config core.hooksPath` | 指向已配置路径 |
| 2.5 | 文档分层已激活：`docs-tier/README.md` 非模板态（含"已激活文档家"标记） | `grep -q '已激活' .meta/docs-tier/README.md` | 存在 |

> L2 判据的关键不在"脚本多"，而在**每条"必须/禁止"承诺都能被一条非零退出命令抓到**（P2）。2.2–2.3 是 L2 能被称为"承诺可验"的最低自证。
> 2.1 的 README/`.gitkeep` 豁免：占位说明文件不算门禁落地。2.2 的机械化实现以 `bash -n` 语法校验为**代理判据**，真判据仍是 `<gate> --help` / 空样本拒绝非零退出，供人工补验。
> 2.5 的"文档分层已激活"由 `ponygo init` 生成**模板态**（仅骨架占位）——升到 L2 时把 `.meta/docs-tier/README.md` 推进为"已激活文档家清单"（doc-sync 门作为 L3 依赖，§2），判据只锁"已从模板态离开"这一形状。tier 放置正确性靠 review（§2 诚实声明）。

---

## 6. 停止线：以规模值不值当为准

（呼应 methodology §10「停止线：以规模值不值当为准」的原文落点）

**规模阈值（承诺密度 × 人数）：**

| 规模信号 | 建议动作 |
|---|---|
| 单人 + 决策密度 < 1 条/周 + 无硬约束需跨提交守 | **整体 disable L2+**：退到「纯 L0 长驻模式」（见下），只保留决策入册与最小文档家作为"人脑外挂"，不加任何门禁 |
| 单人但决策密度 ≥ 1 条/周 或 有记忆性/格式性硬约束 | 保留 L1 + 上最轻的 L2（仅 format 门禁，不上 classification / 冻结 / 文档分层） |
| 2–5 人 | L1 + L2 启动，L3–L5 按 §3 选装 1–2 项，其余挂起 |
| ≥ 5 人或多服务/monorepo | L2 + 至少一项 L5 不变量 + L4 归档（语料腐烂速度随人数指数上升） |

**「纯 L0 长驻模式」定义**：`.meta/` + `meta.yaml`（`level: 0`）+ `.agents/notes/` 目录 + 最小文档家（`docs/AGENTS.md`）保留（历史决策不删），但**停止一切强制新增和门禁**。这是一个合法的长期状态，不是"半成品"——它的判据是"规模不值当"，而非"没时间做完"。

**停止线是双向的**：规模涨过头就升，规模跌破阈值就退。升级和降级都走同一个判据（§4 的退场条件），都记录为一条 decision。

---

## 附：判据真源说明

- §5 的 L0–L2 布尔检查项 + 命令，是 CLI `/ audit` 复用对齐的**唯一真源**；§1 总表是它的索引，不重复载判据。
- §1 总表「validation」列的「机械」**仅当且仅当**指 §5 里对应的命令能跑；「部分机械 / 靠 review」是 P6 形意分离的诚实条款——机器到不了的地方（真实性、价值判断、是否过度治理）显式标注，不写假门禁制造虚假安全感。
- 本文档自身亦遵守 P2：每级判据最终都落到命令或显式"靠 review"，不写散文式"满足"。
