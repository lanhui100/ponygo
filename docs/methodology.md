# 软件工程化经验沉淀：Notes × Skills × 门禁 × 文档分层

> **状态**: v3.3 —— 按 deepseek-harness `v0.2.1-rc.5`（`de5d733a18`，2026-10-31）源码逐条复核后的机制与事实修正；将 deepseek-harness 从"叙述主体"降格为"实证案例"。v3.3 补齐两处门禁统计口径（负样本 spec 覆盖、doc-sync 门数，见版本记录）；v3.2 追加笔记/快照计数修正与复活条件落点定位
> **来源**: `.agents/notes/`（决策记忆）+ `.agents/skills/`（19 个流程技能）+ `lefthook.yml`/`.github/workflows/`（三层门禁）+ `docs/AGENTS.md`（文档分层）+ `scripts/`（机械验证与生成器）—— 均为 deepseek-harness 实证配置
> **用途**: 通用软件项目的工程化落地经验沉淀；deepseek-harness 是本文的一套完整实证案例（标注为"实例"的段落是其具体选型，等价物见括号）

---

## 读者定位与术语约定

- **本文面向两类读者**：启动期的软件项目团队（想要一套可落地的工程化体系）与既有项目的健康审查者（用 §9 记分卡体检）。
- **通用原则 vs dsh 实证分层**：正文陈述的是普适原则；凡标注"**实例**"或以"（dsh 实例：…）""（dsh 选型，等价物 X）"注明的，是 deepseek-harness 的具体实现，读者应换为自己的等价工具体。deepseek-harness 的脚本名/配置是可信的实证证据，但**不是**必须照抄的命令。
- **英文术语翻译约定**：本文首见英文术语/工具名/方法论名词/首字母缩写（acronym）均附中文翻译一次（如 leverage（借力点）、SDK（软件开发工具包）、CoT（思维链）），后续出现不再加；命令、文件名、路径、脚本名、job 名、代码标识符不加（如 `verify-md-links.ts`、`pre-commit`、`.i18n.yaml`）。

---

## 使用方式

- **新项目启动**：按 §10 的迁移清单逐项建立最小机制，宁可粗糙、不可缺席 —— 把 (dsh 实例：lefthook.yml) 换成你自己的钩子管理器，把 `verify-*` 脚本换成你的门禁。
- **既有项目审查**：按 §9 记分卡打分（证据优先），每个缺口必须落成一个最小改进动作。
- **本文档自身**：遵守它宣讲的原则——每个章节最终都要回答"这条如何被验证"，不能只停留于散文（凡本文只给散文、未给验证命令的章节，已在 §0 表末"验证命令"列显式标注"靠自觉/靠 review"，见 P6 的诚实条款）。
- **阅读顺序**：先 §0 全景（体系由哪些模块构成），再按需深挖——决策记忆 §2、流程资产 §3、强制 §4、文档 §5、不变量 §6、负空间 §7。

---

## 0. 全景：这套体系由什么构成

一个依赖编码代理（AI agent）为主要开发者的大型仓库，其工程化可析出为五个相互咬合的子系统。本文以 deepseek-harness（workspace 366 个包，其中 8 个 private、358 个发布；Node 引擎范围、Python SDK（软件开发工具包）、原生层）为**实证案例**陈述；每个子系统都有一个**机械可验证的影子（mechanical shadow，即"可被命令检验的痕迹"）**——这是本文全部方法论的支点。

> 规模口径：`pnpm ls -r --depth -1 --json` 报 367 个项目（含根）= 366 个 workspace 成员；逐包读 `private` 字段得 8 / 358。

| 子系统 | 落地载体（dsh 实例） | 规模证据 | 守护者（机械验证面） | 本人验证命令 |
|---|---|---|---|---|
| 决策记忆 | `.agents/notes/` | implemented 296 活态 / proposed 42 / rejected 8 / archived 924 冻结（均含双语配对；归档另受 manifest 封印，2772 条 = 924×3 件） | verify-agent-note-format / classification / archived | `git ls-files .agents/notes \| wc -l`；依赖 dsh 脚本 |
| 流程资产 | `.agents/skills/`（19 个流程技能） | 覆盖体验/UI/评审/测试可靠性/推送/文档/归档/简化/翻译/性能/升版/升级指南等 | skill 元数据门禁 | 靠 review（本文档未附通用 skill 门禁） |
| 强制体系 | lefthook（L1/L2）+ GitHub Actions（L3） | pre-commit 6 项、pre-push typecheck、CI 聚合 job + 25 个 workflow | run-gates + 负样本 spec | `git config core.hooksPath` + 本地 `lefthook run` |
| 文档分层 | `docs/AGENTS.md` + 各 AGENTS.md | 14-Tier 分类法、词数预算、slop checklist、双语配对 | doc-sync 43 叶（`docSyncLeafGates`，quick 21） | `pnpm run doc-sync`（dsh 实例） |
| 架构不变量 | `AGENTS.md` 约定 + packages/AGENTS.md | 注册即 effect、branded id、fail loud、fail-closed 沙箱等 | 类型 + 加载期拒绝 + OS 围栏 + 顶层执行门禁 + 语义评审 | 类型层可 `tsc`；门禁见 §4.5；语义层靠 review |

**核心观察**：这不是"写了文档再靠自觉执行"的体系，而是**每个子系统都把约定转成可执行命令**（P2 可验证性原理的极端实践）。全文要点一句话——**凡机械可查的承诺，必配非零退出的命令；凡语义判断，必配校准样例；凡不可判，诚实标注"靠自觉"。**

**本文不覆盖的维度（列为界外，说明理由一句话）**：
- **依赖/供应链安全**：审计（supply-chain audit）、SBOM（软件物料清单）、许可证合规、锁文件校验——dsh 有 `gen-third-party-notices` 的雏形（§4.2），但深度安全扫描不在本文门禁语料内，读者应另配 `npm audit`/`osv-scanner` 等。
- **可观测性（遥测/日志/告警/oncall）**：dsh 只做了"模型可见 ⟺ 已记录"的证据链（§5.5），未建生产告警与值班响应；这是运维域，独立成体系。
- **安全与密钥管理**：secret 扫描、权限最小化（本仓库以编码代理为主开发者，权限模型不同），属独立安全规范。
- **发布与版本管理**：发布门禁 dsh 有 `ci-master` 与版本一致性约束（§4.4/§4.5），但语义化版本与发布通道的专业治理不在本文语料内。
- **开发环境可复现（devcontainer/Nix）**：dsh 未采用，本文不替它虚构。
- **API（应用程序接口）契约治理 / 向后兼容与迁移策略**：dsh 以 `branded id`、单调版本、`SCHEMA_VERSION`（§6）承载了部分不变量，但跨大版本迁移的契约治理（OpenAPI/protobuf 演进）未展开。

---

## 1. 第一性原理（first principles，已定稿）

### P1 记忆瓶颈原理
代码只承载"是什么"；团队真正丢失的是"为什么这样"和"为什么不那样"。任何只存在于人脑或聊天记录里的决策都会随人员流动蒸发。

### P2 可验证性原理（verifiability）
约定的生命力 = 它的可验证性。靠自觉遵守的约定在规模和人员变化下必然衰减。凡机械可查的承诺，配一条非零退出的命令。这一原理的极端形式是：**甚至门禁本身也被门禁检验**（负样本 spec（negative sample 规格，构造非法样例证明门会拒绝），见 §4.7）。

### P3 载体分工原理
一次性判断（note，决策记录）、当前事实（doc，文档）、重复程序（skill，技能）、恒定约束（gate，门禁）必须分开存放。四类载体分别展开见 §2（决策记忆）、§5（文档分层）、§3（流程资产）、§4（门禁强制）。

### P6 形意分离原理
语义规范定义"什么是好的"；结构设计把语义承诺转成可检验的影子（状态入路径、哈希冻结、强制链接化）；机械门禁只锁影子、从不判断语义。机器到不了的地方（真实性、意义、价值判断），用显式标记承认盲区、用校准样例（calibration examples，正反例成对）传递判断力——唯独不写假门禁制造虚假安全感。

### P7 分层强制原理
门禁按"反馈速度 × 拦截类别"分层，每层只抓该层性价比最高的缺陷。本地窄、CI 全，两层跑同样检查 = 白付延迟。

### P8 不变量经济原理（invariant）
架构质量 ≈ Σ(不变量强度 × 捍卫者机械程度) ÷ 不变量数量。**没有捍卫者的不变量不是架构，是愿望。**

该原理同样适用于守护层自身：**无法独立观测违规的断言不是守卫**。dsh 曾为每个包强制发布"运行时不变量伴侣"（含 209 个"解释为空的伴侣"），退役判据正是"让每个伴侣都可执行，却没有让系统更安全"——断言退化成了满足门禁的仪式（§6.4 案例）。

### P9 负空间对称原理
每次添加隐含终身维护税。删除不是添加的逆操作，而是需要同等判据、同等验证、同等记录基础设施的独立工程。

> 说明：课程笔记中的 P4/P5（决策记录相关）未在本册展开定义，编号从 P6 起沿用原稿。

---

## 2. 决策记忆：Agent Notes 体系（实际结构）

**通用原则**：任何"为什么这样/为什么不那样"的决定，都要落到一个专门的、可被路径编码和门禁校验的**决策记录**载体，而不是散落在人脑、聊天记录或拉取请求（PR）线程里。业界通用名是 **ADR（Architecture Decision Record，架构决策记录）**；dsh 选型叫 **Agent Note（代理笔记）**，把它推广到所有非平凡变更（不止架构，还有 bug-fix、simplification、process）。本节用 dsh 的 Agent Note 作实证，读者可把"Agent Note"整体换成"ADR"或"决策记录"。

> 术语对照：Agent Note（代理笔记）≈ ADR（架构决策记录，一般团队更熟悉的名字）。二者差别只在覆盖面——ADR 传统上只记架构，Agent Note 记一切非平凡变更。

### 2.1 双轴路径：lifecycle × class

**通用原则**：把记录的两个分类维度直接编码进**文件路径**，让"标签"和"存储位置"是同一件事（文件夹即标签），从而无需在文件内容里重复声明标签、也无需担心二者漂移。dsh 的两个轴是 lifecycle（状态轴）× class（类别轴）。

每条决策记录的两个轴都编码在**路径**里：`{lifecycle}/{class}/yyyy-mm-dd-topic-title.md`。

- **Lifecycle**（状态轴，顶层文件夹，随状态迁移）：
  - `proposed/` — 提案，未实现或部分实现
  - `implemented/` — 决策已落地，记录**当前态**（事实随代码更新）
  - `rejected/` — 已否决，保留判据见 §2.5
  - `archived/` — 冻结历史快照（只有 implemented 能进入，§2.3）
- **Class**（类别轴，嵌套文件夹）来自**封闭集合**（`scripts/agent-note-tree.ts` 定义，分类门禁拒绝其它文件夹）：

| Class | 覆盖 | dsh 规模（implemented 英，当前快照） |
|---|---|---|
| `feature` | 新用户/模型可见能力 | 40 |
| `bug-fix` | 修正缺陷或闭合 postmortem（事故复盘）暴露的缺口 | 11 |
| `simplification` | 移除代码/行为/表面积，不加能力 | 13 |
| `architecture` | **交付源码**的结构决策（包关系、运行时词汇） | 180 |
| `process` | **代码周围**的工具/政策/工作流（门禁、包管理、vendoring（第三方代码收编）） | 34 |
| `testing` | 测试基础设施与策略 | 18 |

**architecture / process 分界线**：architecture 是关于交付的源码，process 是周边工具与工作流。`refactor`（重构）刻意缺席——它与 `simplification` 重叠，判别器"可观察行为是否改变"已被后者覆盖。

> 关键设计：**文件夹即标签**。分类线写进文件里会产生"行与文件夹不一致"的漂移，而路径编码让标签和存储是同一件事——没什么需要同步（元 note：`2026-06-20-agent-note-classification`）。
>
> 非对称（dsh 实例）：`archived` 不是合法 lifecycle。`scripts/agent-note-tree.ts` 的 `AGENT_NOTE_LIFECYCLES` 只列 `proposed/implemented/rejected`，归档由 `AGENT_NOTE_ARCHIVE` 特例分支承载——三态闭集 + 一个冻结特例，比"四态平铺"更贴近状态机实际形状。

### 2.2 生命周期状态机与迁移

```
proposed/ ──→ implemented/ ──→ archived/
    │              │
    └──→ rejected/  └──→ (consolidation 合并删除)
```

- **状态编码在路径 + 文件头 `Status:` 行交叉验证**（三重锁定：结构 + 内容 + 门禁）；
- **转换即改写**：proposed → implemented 时 `## Proposal` 必须重写为现在时 `## Decision`，验收标准/风险折叠进 `## Consequences`——移动文件夹的那次提交必须完成改写，门禁强制；
- **implemented 是活的当前态描述**：路径、名称、默认值随代码同 PR 更新（事实可改）；**决定本身不可改**——推翻 = 新增记录 + 双向链接，历史不可篡改。

### 2.3 archived：冻结归档（dsh 独有的第三态）

超过一半的"退场"设计集中在 archived，这是原笔记最大的盲区：

- **只有 implemented 能归档**。归档判据是语义判断：决策已闭合 + 其理由/备选/负面保证/回归条件不太可能指导未来工作。**基础性边界、持久/线语义、安全规则、复发诱惑、未决回归条件必须保持 active**——与字数、年龄、配额无关（用 `dsh-archive-agent-notes` skill 的校准样例判断，而非 word count）；
- **归档路径** `archived/{class}/...`，刻意省略 `implemented` 段（只有它可进入）；
- **归档动作最小化**：移动完整 EN（英文）/ZH（中文）/i18n（国际化）三元组 + 在两侧 `Status: implemented` 下插 `Archived: YYYY-MM-DD` + 重录 sidecar + 修复/删除入站链接。**不允许其它内容改动**；
- **永久冻结**：归档后永不编辑/翻译/重排/移动/删除，不视为当前权威。`.rgignore` 把 archive 排除出父目录搜索（防陈旧事实按词法命中挤掉当前结果）；文档门禁跳过 archived 源及其出链（link 门禁只验证入链、从不把 archived 当链接源）；
- **append-only 封印**：`verify-archived-agent-notes` 以 SHA-256（安全散列算法）内容哈希把每个归档件封进 manifest；`--write` 先证明既有封印未变、再追加新件（dsh 实测：manifest 在 `.agents/notes/archived/manifest.json`，`version: 1`，2772 条 = 924 篇 × 3 件三元组）。CI 用 PR base SHA 做基线（防浅克隆缺基线）；
- 元 note：`2026-07-26-frozen-agent-note-archive`。

### 2.4 文件格式契约（verify-agent-note-format 门禁）

所有 active note 遵循单一文件内格式，机器强制：

**头部**（前两行固定）：
```markdown
# Agent Note: <title>

Status: <status>
```
`Status:` 是三种形式之一，必须与所在文件夹一致：`proposed` / `implemented` / `rejected — <一行理由>`。状态行**无日期无括号**——文件名持有首次提出日期，git 持有其余历史。拒绝理由允许带内容，因为它是读者来看的东西。

**正文骨架**（每篇以 `## Problem` 开头，先写动机、脱离方案也能成立）：
- `proposed/`：`## Proposal`（可将来时）+ 定制节 + `## Alternatives considered` + `## Acceptance criteria` + `## Risks`
- `implemented/`：现在时 `## Decision` + 定制节 + `## Alternatives considered` + `## Consequences`。**提案时代标题禁入**：`## Proposal`/`## Plan`/`## Migration plan`/`## Acceptance criteria` 不允许出现在 implemented note（spec-speak，门禁拒绝）；
- `rejected/`：提案原文冻结，verdict 只在 `Status:` 行。

**Alternatives considered 强制**：每条记录必含"候选方案与落选原因"，格式门禁检查其存在性。"记录无备选的决策是在邀请重开争执。"备选只能记录、不能编造——2026-07-05 前的旧件若无据可查，用固定标记 `<!-- agent-note-format: alternatives-not-recorded (pre-format Agent Note) -->` 承认空白。

> 元 note：`2026-07-05-uniform-agent-note-format` 记录了它击败的方案——完整刚性模板（大型设计 note 有 8-15 个定制节，刚性序列会造成破坏性重写）、仅头部规范化、无状态行、带日期状态、裸 `# <title>` H1（一级标题）、纯约定无门禁（"19 个文件证明约定单独能做到什么"）。

### 2.5 触发规则与豁免（谁在什么时候必须写）

机制入口是散文规则，但配了**枚举化触发条件**才成立（元 note：`2026-07-19-require-agent-notes-for-non-trivial-changes`）：

**非平凡变更 = 命中任一**：行为变更 / 架构 / 跨文件或跨包契约 / 流程与工具链 / 测试策略 / 磁盘-线-配置格式 / 维护者可能再访的决定。命中即**同一 PR** 内新增或更新 note（更新既有 owner 即满足，不重复建）。纯机械或局部编辑豁免（无行为/契约/结构/流程/理由变化）。

**Consolidation（完全取代才可删）**：旧 note 被现任 note 完全取代时，现任 owner 先保住每个独特理由/备选/后果/验证契约/命名覆盖缺口，修复所有入站链接，**同一次变更**删除英文 + 中文对 + 一致性记录。部分取代不删——保持交叉链接。不得把旧决策改写成反面，不得让 git 历史当理由的唯一副本。

**Added-then-removed 特例**：当且仅当功能从生产代码/配置/模式/持久格式/迁移/兼容行为中完全消失、无文档宣称可用、无测试把它当支持行为时，移除 note 才能成为唯一 owner——它必须保住原动机、为何不再合理、全移除的备选、放弃的能力、回归条件、完全缺席的证据。

**dsh 的诚实条款**：**没有 CI 门禁做 diff 平凡性分类**——"是否平凡"是语义判断，机械分类会产生假阳性和表面合规。语义边界由 review 强制。这是 P6 的完整执行：机器到不了的地方不装假门禁。

### 2.6 Supersession 审计（语料的 GC（垃圾回收））

每次新增 note 触发一次范围化审查：搜索覆盖同一决策/机制/被拒备选的既有记录，分类完全/部分取代并**在同一变更中处理**（债务不过夜）。作者拥有最新的所有权证据，因此审查发生在写作时、而非延迟到定期整理。无 supersession 检查，决策语料会在几个月内腐烂成噪音。

**ponygo 落地（v2.2）**：写前检索程序进 write-adr（判定表：无关直写/相关链入/被取代同提交归档/部分落地拆条）+ `.agents/notes/AGENTS.md` 自动加载检索义务 + change-review 评审时复查对应性。dsh 的 archive 技能是独立重型流；ponygo 把 supersession 收为写流程的一步（P9：少一个技能的维护税），归档冻结本身在 L4 目标画像。

### 2.7 反索引：不要集中式 INDEX.md

`2026-07-19-remove-generated-agent-note-index` 记录了反索引决策：集中式索引重复路径/文件名日期/H1 已编码的事实，且成为无关分支的 merge hotspot。active tree 本身就是 inventory——树导航 + 仓库搜索提供发现，README 是精修入口。

### 2.8 双语配对：双格式说明（旧格式仍有效）

**旧整文件哈希记录仍有效，已落盘实例无需迁移。** 本节同时说明新推荐的分节键格式；
判据 1.9/精微层 1.9 口径不变；未声明双语的实例本节零影响。

旧格式（dsh 实例：每对 `foo.md` + `foo.zh.md` + `foo.i18n.yaml` 存两侧完整 blob 哈希 +
结构签名；配对门禁校验签名一致 + 生成区归一化字节相同 + 互链 + blob 哈希一致；
两侧等权、briefing-driven 更新、术语表约束；机器只证相同不证翻译质量）继续有效，
已落盘记录无需重写。

新格式（分节键记录，推荐新双语实例采用）最小规范：

1. 键取标题 slug 路径，层级以 `/` 连接；首个标题前内容键为 `/`（仅作首节键，
 与路径根同形但不作文件系统根，review 时称"首节"）。
2. 英文小写字母数字连字符直用；空格/下划线转连字符；CJK 与其它原文保留原文去空格
 （不强制拼音或哈希；非英双语任取一侧为键侧，两侧节数对齐即可，不假设英文存在；
 去空格后重名同 `~2` 规则，靠 review）。
3. 同级重名依次 `~2`/`~3`（作用域 = 同级同名；跨级重名不编号）。
4. 代码块与生成区（双语逐字节一致的内容；实例自认并在记录旁注生成区定义）不入哈希；算法由实例自选。
5. 条目排布以相邻节变更落不同文本块为目标（启发式，非保证）；验证见合并实例：
 改 A 节内容 → 与改 B 节分支合并 → 记录应无冲突。

正例：两节 `getting-started`/`getting-started~2` 各改一处，合并无记录冲突。
反例：同节两侧改同一哈希节，合并仍冲突（先合 Markdown 再重算该节）。

---

## 3. 流程资产化：19 个技能

### 3.1 SKILL.md 解剖（五要素 + dsh 新增模式）

每篇 SKILL.md 由五要素构成：**触发式 description**（写"何时用"——路由条件）/ **真相源清单**（先读 AGENTS.md 与契约）/ **程序步骤**（机械部分写成命令）/ **校准样例**（正反例成对，判定线用具体事实锚定）/ **验证 + 报告格式**。

description 自足性原则：技能路由发生在"只有摘要可见"的懒加载时刻，因此**触发条件必须内联**进 description（用变更本身的可见特征），权威出处放正文，宪法层（AGENTS.md 常载）兜底漏触发。

### 3.2 流程技能清单（触发条件 → 核心模式）

| 技能 | 触发式 description（何时用） | 核心模式 |
|---|---|---|
| `dsh-pre-push-checks` | 推送/强推/标记 ready/声称 check 通过前，以及 `gh stack sync` 发布重写分支后 | 用 `change-scope --base` 精确刻画 outgoing diff；**按证据面选最小测试**（行为→聚焦测试、文档→doc-sync、模型可见→快照、包→build+hygiene+built smoke、真实提供者→e2e（端到端））；绝不手动重跑已过检查；`--force-with-lease=<branch>:<oid>` 保护历史重写；post-sync 四步验证 |
| `dsh-code-review` | 评审 deepseek-harness 的 PR | 先 `change-scope` 定向而非通读 diff；6 条 blocking requirements（prose 语义评审、docs 匹配代码、core type docs 匹配（subsystems 页 + `type-equiv` 条目）、Cordis 归属与清理、证据存在、UI（用户界面）copy locale-owned）；17 项 manual checks；"一个可证实 blocker 的短评审 > 一串 nit" |
| `dsh-doc` | 新建/重构/评审/审计/迁移 Markdown 文档、README、文档站 | **kind 系统**（package-group/reference/library/bundle 四模板，由机械事实推导预期 kind）；**fact-check 程序**（每个操作声明必须实跑，跑不了的删除或指名验证 owner）；voice rules（Summary 说能做什么、Dev Note 是唯一 slop 区、当前态禁历史）；quality criteria |
| `dsh-prose-standard` | 写/审/修/裁剪/审计任何 prose（Markdown/JSDoc（JavaScript 文档注释）/注释/prompt/诊断/UI 串） | **输入契约**：缺 scope 就停、不推断不采访；`mode: automatic\|interactive` 控制提问不控制写权限；**完整命题保留**（actor/action/condition/modality/负面保证/归属/副作用一个不漏）；按位置规定必需覆盖；borderline 决策协议 |
| `dsh-trim-cot-leakage` | 审计/修复像泄漏推理转写的 prose | 一句话测试：**HEAD 上的读者无任何会话转写/PR 线程/未提交草稿能否解析每个引用**；8 类 taxonomy（死会话引用/栈与 PR 视角/变更叙事/评审编排/自我辩护/转写/含糊计划残留/语言滑移）；**召回电池**（正则探针初筛 + 语义裁决）+ 承认每轮有漏网；overcorrection 陷阱清单 |
| `dsh-archive-agent-notes` | 增/审/剪/归档/恢复 note，检查 supersession | 语义按未来价值分类；**校准样例**：归档/保留/删除各列正反例，字数与结论刻意无关（533 词归档、248 词保留）堵死按大小分类的捷径；归档五步（移动完整三元组→只在 `Status:` 下插 `Archived:` 行→机械重录 sidecar→改入链→`--write` 追加封印并复跑校验）；报告格式含 borderline 案例 |
| `dsh-find-simplifications` | 找非显然简化候选、写 proposed note、审计合并被取代 note | 强候选判据（无生产消费者/镜像事实/投机功能/手搓可换依赖）；**证明或拒绝每个候选**（rg + 读调用点，生产/非生产/歧义三语料分类）；依赖换购判据（净删除 + 健康度 + 边界契合 + 不击败已记录接缝）；consolidation 流程 |
| `dsh-merging-stacked-prs` | 落一栈依赖 PR 到 master，或提及 stacked PR | **硬停条款**：无官方 stack 支持就停、不手动 retarget 复刻；要求 PullRequest.stack 对象为权威（GraphQL 查询）；`gh stack merge <stack-number>` 全栈合并；落栈后验证每 PR 报 MERGED，删分支前验证零依赖 |
| `dsh-translate-docs` | 显式用户点名运行扩展双语工作流 | **`disable-model-invocation: true`**——只许用户点名、禁模型自主路由（重型流程防误入）；briefing-driven 更新路径；whole-document 路径委托子代理（read, don't re-summarize）；术语表先行加载 |
| `record-browser-gif` | 录制浏览器/Web 交互 GIF，且每个改 GUI（图形用户界面）行为的 PR 必须带 | **证据链完整性**：一次演示=一次孤立运行、真实 server + 真实模型轮、禁 fixture/mock/合成事件；发布到 assets 分支（永久引用不变性：branch 永不重写） |
| `agent-experience` | 编写或变更模型可见工具定义（name/desc/schema/prompt），设计上下文与工作流 | **上下文效率与发现性**：最小上下文启动；参数规则就近写在参数上；行为描述禁实现细节；单事实只说一次；量化首轮 Prompt Token 变化 |
| `dsh-create-upgrade-guide` | 变更破坏对外可感知契约（CLI/配置/持久化数据/SDK/包导出）或修订单一升级指南 | **破坏性变更显式引导**：统一在 `docs/upgrade-guide/` 维护单调向后的迁移方案；包含受影响表面、破坏原因、前置检查与确定性迁移操作 |
| `dsh-error-handling` | 设计或评审错误分支、恢复策略、重试、后台任务与用户可见报错 | **非防御性吞错与因果可追溯**：禁止隐式吞异常；区分可恢复（降级/重试带退避）与致命故障；错误信息必须携带定位上下文与补救动作 |
| `dsh-ci-test-reliability` | 设计、评审与排查高并发/共享资源/时钟/全局状态/异步回收下的 Flaky 测试 | **并发与环境确定性**：隔离进程级状态；时钟与异步清理显式 await；真实端口与资源带生命周期销毁；禁止靠加 `sleep` 掩盖竞态 |
| `dsh-speed-up-perf` | 排查或优化 Harness 运行时性能、长会话内存与 Web 响应度，设计基准测试 | **实测驱动的无损优化**：先 profile 拿基线热点再动手；保留语义与不变量不变；必须提供量化收据对比（CPU/内存/时延前后对照） |
| `dsh-client-ui-ux` | 设计与审查 Web/客户端界面变更（视觉 Token、复用、反馈面、弹窗、加载态） | **反馈表面纪律与设计系统复用**：遵循既有视觉 Token；轻反馈（Toast）vs 原地提示 vs 破坏性操作模态的严格边界；加载中骨架与错误文案就近归属 |
| `dsh-responsive-ui` | 设计或评审响应式布局、文本截断、标题折行、无障碍与移动端触控交互 | **极窄/宽屏无损适配**：禁硬编码固定像素宽高导致溢出；长文本有策略截断或 tooltip 展开；小屏下自动降级为折叠或抽屉，键盘导航焦点闭环 |
| `dsh-official-plugin-artwork` | 绘制与审查官方/实验性插件的图标与预览视觉资产 | **视觉规范与包清单同步**：像素网格对齐、矢量比例、SVG 语义化透明度与高低色模式适配；同步登记至插件元数据清单 |
| `cordis-styling-nitpicking` | 审查 Cordis 插件及入口可达模块的代码质量、单例与生命周期挂载 | **Cordis 生命周期洁癖**：单例状态显式释放、副作用双向清理对称（mount/unmount 必配对）、清理依赖在消费者退出前禁止提前销毁 |

### 3.3 设计模式提炼（超越原笔记）

1. **调用权限分层**：`disable-model-invocation: true` 把技能分成"模型可自主路由"与"只许用户点名"两级（dsh-translate-docs）；
2. **输入契约**：缺 scope 就停下报告，不推断不采访（dsh-prose-standard / dsh-trim-cot-leakage 都要求显式 scope，且排除 vendor/ 与 archived/）；
3. **证据面匹配**：改动表面决定最小充分证据——行为→聚焦测试；文档→doc-sync；模型可见输出→快照；清单/导出→build+hygiene；真实提供者→e2e（dsh-pre-push-checks 全文主题）；
4. **召回电池**：正则探针初筛 + 语义裁决双层，且承认"每轮都有电池漏掉的案例"，辅以无模式通读（dsh-trim-cot-leakage）；
5. **硬停条款**：危险操作预先封死"聪明的降级路径"——工具缺失就停，不许手动绕（dsh-merging-stacked-prs 无 stack 就停，dsh-translate-docs 不授权就不跑）；
6. **证据链完整性**：一次演示=一次孤立运行，禁拼接帧；发布前重验 HEAD 未移动（record-browser-gif）；
7. **校准样例锚定判据**：样例间差异维度 = 判断的真实依据；判定线用具体事实（"foundational authority"）不用形容词（dsh-archive-agent-notes 归档样例）；
8. **被永久引用的资产获得不变性义务**：assets 分支永不重写——与归档哈希冻结同源。
9. **对应性校准**：ADR 必须与其治理的代码对应——标题文题相符、Problem/Decision 引用代码路径或提交；多阶段提案部分落地时拆条或链入。存在性判据查"有没有 ADR"，对应性只能由 review 按"抽 implemented 对代码现实、抽 proposed 查已落地未迁移"程序守（ponyllm 8f37827 反例：TUI 功能提交携带多协议提案）。
10. **读写配对**：写技能（write-adr：落笔前检索旧 ADR）与读技能（change-review：评审时先检索再对照）是同一循环的两端；读触发规则（写前/评审/找简化/归档/接手）与写触发规则对称载入 notes/README。只给写触发不给读触发，决策记录就是只写存档（ponygo v2.2 补齐）。
11. **工具定义卫生**：最小上下文优先；延迟加载资源可检索；关键约束前置；输出有界；每事实只说一次（细则见 skills README 纪律 4）。
12. **简化勘探证据链**：证据链四件套 + 计数不选优（细则见 skills README 纪律 5）。

---

## 4. 强制体系：三层门禁（实际配置）

### 4.1 分层哲学

本地钩子用 **lefthook**（非 husky），`postinstall` 安装。lefthook.yml 顶部注释自陈分工："Keep these local checkpoints fast; CI owns the full repository-wide gate matrix."

安装器 `scripts/install-lefthook.mjs` 把钩子装进 worktree 本地的 `dsh-hooks` 目录，带 `.dsh-lefthook-owned` 归属标记与安装锁；`core.hooksPath` 被外部占用时拒绝覆盖，除非显式设 `DSH_LEFTHOOK_ALLOW_HOOKS_PATH_OVERRIDE`。它自带负样本 `install-lefthook.spec.ts`——**钩子装载本身也是被门禁检验的机制**，不是安装脚本的信任边界。

**提醒档（v2.1，ponygo 通用化）**：FAIL 门禁与 review 之间还有一档——**启发式 WARN**（只 echo，
不改退出码）。适用条件：语义判断机器到不了（P6），但形状可疑值得人看一眼。两条实例：
文档新鲜度（源码变而非-notes 文档不变 → 提示跑文档面复检，计数排除 `.agents/notes/`，
否则 ADR-only 提交永远静默）与未来日期（决策文件名日期晚于今天 → 提示核对）。
提醒档与卫生 WARN 同级（status/audit 双挂），自带退场指引（噪声过大按 L2 退场 disable）。

### 4.2 L1 pre-commit（秒级，本地）

| 顺序 | 触发文件 | 命令 | 抓什么 |
|---|---|---|---|
| 1 | `*.i18n.yaml`（排除 archived） | `verify-translation-pairing.ts --cached` | 暂存 i18n 配对与源/中文三件套的 git 索引字节哈希一致 |
| 2 | `.agents/notes/archived/**` | `verify-archived-agent-notes.ts` | 冻结归档封印不可改/删，新增须先 `--write` |
| 3 | `*.{ts,tsx,mts,cts,mjs}`（排除 `vendor/*/src/**`） | `run-oxlint.ts --config .oxlintrc.staged.json --fix` + `stage_fixed: true` | 项目无关的暂存 lint 自动修复后重新暂存 |
| 4 | 全部 | `git diff --cached --check` | 空白错误/冲突标记 |
| 5 | 提供者元数据与配置相关 | `gen-provider-data.ts --check --cached` | 模型 provider 元数据定义生成代码与 lockfile 强一致 |
| 6 | 无 glob（每次 pre-commit 必跑） | `check-vendor-manifest.sh` | 改 `vendor/*/src` 或 `bin.js` 必须同提交改 `vendor/README.md` |

另有 `pre-merge-commit` 复用 1、2 两项，保证 merge 提交也过冻结门。依赖变更时的第三方声明验证（`verify-third-party-notices`）已收拢至 CI 静态检查流水线。

> 措辞精度（dsh 实测）：第 1 项命令末尾追加 `{staged_files}`；第 3 项追加 `--no-error-on-unmatched-pattern {staged_files}`；第 5 项的触发 glob 是显式 5 文件清单（`pnpm-lock.yaml` 与 `packages/llm/llm-pi-ai/…` 的元数据/配置），不是通配目录。

### 4.3 L2 pre-push（十秒级）

只有一项：`pnpm run typecheck`（Host + Client 全量 tsc）。**没有 lint-staged/pre-push 全量 lint**——全仓质量矩阵归 CI。

### 4.4 L3 CI（分钟级，GitHub Actions）

统一调度器 `scripts/run-gates.ts`（18 个 Mode：`ci-primary` / `ci-linux-primary` / `ci-static` / `ci-lint-contracts-ready` / `ci-coverage` / `ci-unit` / `ci-bench` / `ci-snapshot` / `ci-artifacts` / `ci-consumers` / `ci-windows-blocking` / `ci-windows-complete` / `ci-windows-observational-ready` / `node-compat` / `check-all` / `hygiene` / `doc-sync` / `doc-quick`），支持依赖图、限流、allowFailure、整体 exit 1。

- **ci.yml**（PR）：node 24 四个并行 job —— `node-24`（`check:ci:static`：共享静态门 + doc-sync + module-graph + knip）、`node-24-coverage`（分区覆盖率）、`node-24-bench`（`check:ci:bench` 性能基准）、`node-24-consumers`（消费者面门：build + publint + lint/dup + snapshot + expected-output + doc-typecheck + node-next-types + built-bin smoke）；`node-compat` 矩阵（22.19 / 24.9 / 26，第三腿专门覆盖 24.0–24.11.1 的 loader 边界）；`python-sdk` + `python-runtime`（release-shaped matrix）；三个 windows job（`windows-build`，其中 `windows-observational` 已降为该 job 的一个 step；`windows-coverage`；`windows-native-tests`）；`all-checks-passed` 聚合——`needs` 固定 9 个 job（含 `node-24-bench`，**不含**暂时非阻塞的 `windows-coverage`），`if: ${{ !cancelled() && github.event_name == 'pull_request' }}`，任一 failure/cancelled/skipped 即红——分支保护只依赖这一个聚合检查；
- **ci-master.yml**（push master）：`windows`（Wine-on-Linux）、`serial-linux-selfhosted` failover 演练（完整 unsharded primary 作为热备池）、`serial-windows`、`serial-macos`、`ssh-helper`、`python-runtime`、手动 runner 基准（`larger-runner-benchmark`/`consolidated-runner-benchmark`）；`cancel-in-progress: true`（"push 时不取消"的旧方案已被否决，见归档 note `2026-09-09-cancel-superseded-ci`）；
- **运行池选择**：仓库变量 `DSH_CI_FAILOVER_LINUX`（`hosted`/`selfhosted`/`blacksmith`）与 `DSH_CI_FAILOVER_WINDOWS` 决定 hosted 故障时的替换池；聚合 job 跟随同一个 Linux 选择器，否则热备切换会把分支保护判决留在故障池上；
- 其它 workflow：`expected-filenames.yml`（拒 `*golden*` 文件名）、`issue-policy.yml`（PR 校验门）、`docs-pages.yml`（手动发布，强制 dsh-v 标签 + 双环境 reviewers）、`sandbox.yml`/`e2e.yml`（沙箱与端到端独立面），合计 25 个 workflow。

### 4.5 机械验证脚本家族（scripts/）

多数通过 run-gates 组合进 CI，**部分门配同名负样本 spec**（构造非法样例证明门会拒绝）：dsh 实测按 §4.5 逐一点名的脚本集——19 个 `verify-*`/`check-*`/覆盖率脚本中 8 个有同名 `*.spec.ts`（另 `run-gates` 自带 `run-gates.spec.ts`），13 个 gen 生成器中 9 个同名 spec；全仓口径 `scripts/verify-*.ts` 共 76 个、同名 `*.spec.ts` 30 个（≈39%）。其余由模块级 spec（如 `archived-agent-notes.spec.ts` 覆盖 `verify-archived-agent-notes` 的实现）或 workflow 形状契约间接覆盖。"每个门都有负样本"是**目标**，不是现状——本文不把它写成现状。

- **verify-agent-note-format.ts**：头/状态语法（按 lifecycle 正则）、必备节、implemented 禁提案标题、Alternatives 与 grandfather 注释互斥；
- **verify-agent-note-classification.ts** + **agent-note-tree.ts**（封闭集合源）：拒绝未知 lifecycle/class 目录、深度非法、非 `yyyy-mm-dd` 文件名、根 `INDEX.md`；
- **verify-archived-agent-notes.ts**：封闭类树、完整三元组、归档元数据、sidecar 哈希、append-only manifest（见 §2.3）；
- **check-workspace-constraints.ts**：包清单不变量（实验包前缀/private、release 必须 public+repository、`workspace:` 协议、版本一致、dsh 包 main/types/exports 精确匹配）。负样本 spec 证明错前缀/非 private/依赖实验包均拒绝；
- **coverage-exempt.ts / coverage-partitions.ts**：免插桩重型套件 + 分区覆盖率合并；
- **doc-standard.spec.ts / doc-typecheck.ts**：kind 系统机械推导 + Markdown 内 `ts` fence 按 workspace API 编译，`ignore-check` 计为 opt-out 比例；
- **verify-md-links.ts / verify-md-wrap.ts / verify-mermaid.ts / verify-doc-refs.ts / verify-package-paths.ts / verify-subsystem-pages.ts / verify-doc-budgets.ts**：链接存在性 + fragment 命中真实 heading slug、单物理行、Mermaid 语法、源码注释里的 docs 引用漂移、包 README→subsystems 链接、词数预算；
- **verify-translation-pairing.ts**：双语完整性 + 结构签名 + blob 哈希（§2.8）；
- **verify-type-equiv.ts / verify-repository-references.ts / verify-export-jsdoc.ts / verify-concrete-terms.ts**：`type-equiv` 条目的 1:1 校验（清单在 `scripts/type-equiv.manifest.json`）、仓库内引用可达、导出 JSDoc 完整性、禁用隐喻命名——把"应当如此"的语义诉求尽量下沉成可执行门；
- **gen-*.ts --check 家族**（`gen-cordis-catalog`/`gen-client-catalog`/`gen-tool-catalog`/`gen-config-catalog`/`gen-persistence-catalog`/`gen-session-format-catalog`/`gen-cli-help`/`gen-dependency-catalog`/`gen-official-bundle-catalog`/`gen-doc-graphs`/`gen-module-graph`/`gen-tsconfig-paths`/`gen-third-party-notices` 等）：**生成物漂移门**——再生成后与已提交产物逐字节比较，生成目录永不手编（`gen-scoped-events` 已随运行时 invariant 插件族一同删除，§6.4）；
- **run-gates.ts / ci-workflow.spec.ts**：门调度器 + **workflow 形状契约**（断言 ci.yml 必须有某 job、concurrency 表达式的确切值、push-reachable job 集合被钉死）。

### 4.6 元门禁纪律

- **门被门检验**：每个验收路径有负样本 spec（`archived-agent-notes.spec.ts` 构造"删 sidecar + 错头"拒绝 incomplete triplet、"改 content"拒绝 sealed hash changed）；`ci-workflow.spec.ts` 把整个 CI 形状钉死——门本身也是代码，配置变更像任何变更一样评审；
- **窄例外优于全局关闭**（`.oxlintrc.staged.json` 是 staged 专用精简档，非全仓降标）；
- **门与负样本同名配对**：实例 `foo.sh` / `foo.ps1` 分别由 `foo.spec.sh` / `foo.spec.ps1` 承担负样本证明；`ci-verify.sh` 仅是编排器，不要求同名 spec，框架内置 A1/A2/A6/A7 与实例门分边界。`audit` 只读检出缺配对门并给出稳定 `gate_spec_missing` 缺口且非零拒绝；`--run-specs` 只执行受支持的 `.sh`，`.ps1` 的执行证据由其平台 CI 或 review 提供，不冒充已运行；
- **聚合覆盖治理执行面**：承载 `all-checks-passed` 的 workflow 必须在同一文件定义治理 job，并把其 `needs.<job>.result` 纳入只允许全部 `success` 的聚合；跨 workflow 的独立检查不能替代可聚合依赖；
- **spec 不得自我跳过**：`PONYGO_IN_SPEC` 仅是兼容环境信息；CLI 用 `PONYGO_AUDIT_SPEC_DEPTH` 拦截嵌套执行，A2 与实例 spec 不得用旧变量把直接调用或 CI 调用洗成 `SKIPPED`；编排器还必须把 spec 输出中的 `SKIPPED` 判为失败；
  > 归属声明：本条是 **ponygo 框架侧**机制——dsh 内 `grep -rn PONYGO_` 零命中、也没有 `.meta/` 治理根；放在 §4.6 仅为对照，别把 `PONYGO_*` 当成 dsh 实证；
- **只读判定不执行仓库代码**：`status`/`audit` 这类判定命令默认只读——不执行实例里的脚本
  （对陌生遗留仓库执行脚本 = 任意代码执行）。执行型判据（跑负样本 spec 证明门会拒绝）须显式
  opt-in（`ponygo audit --run-specs`）或挂在 CI/pre-push 层；护栏命中时如实报 `SKIPPED`，
  **不得并入"全部 PASS"**——结论行必须限定它到底验证了什么；
- **证据面三禁令**：不默认全量、不重复已过检查、不为遮掩降低阈值；
- 绕行仅经用户同意并报告实情（dsh-pre-push-checks：bypass 本地 hook 只在用户明确同意时，且报告失败与 CI 为何预期不同）。

### 4.7 并发下测试可靠性的通用三原则（checklist 2.A–2.C 的唯一家，靠 review）

本节是 2.A–2.C 的原则 + 分类表唯一家；gates README 只留一链入行（非门禁、无执行语义）。

- **2.A 资源隔离**：并行测试的共享资源（端口、套接字、固定路径、外部命名空间、全局可变状态）
 由资源所有者的原子分配器获取，禁先探后占。review 程序：抽新增测试各一例 → 记 F1–F7 分类 → 复现阶梯到首个签名。
- **2.B 就绪与完成等待**：断言等被测方拥有的可观测就绪/完成信号；超时只做等待上界；固定 sleep 不充当证据。同上三步。
- **2.C 处置到静默**：清理获取后立即注册；关闭/取消后等到子进程退出、服务关闭或等价完成信号。同上三步。

| # | 分类 | 一句话判据 | 最小复现动作 |
|---|---|---|---|
| F1 | 宿主资源碰撞 | 独立进程/job 争同一资源 | 并发双跑同签名 |
| F2 | 生命周期不完整 | teardown 在静默前返回 | 断言后查残留 |
| F3 | 进程全局污染 | 结果依赖执行顺序 | 换序/串行对比 |
| F4 | 负载敏感同步 | sleep 替代状态等待 | 替换为状态等待再跑 |
| F5 | 平台或入口差异 | 某 OS/shell/入口下稳定复现 | 换 OS/shell/入口对比 |
| F6 | 产品并发缺陷 | 隔离 + 显式 overlap 仍复现 | 显式 overlap 复现 |
| F7 | 外部依赖瞬态 | 归属 live 外部边界；无已文档化重试政策时不得归 F7 | 查重试政策原文 |

分流三问：隔离后显式 overlap 仍现 → F6；换 OS/shell/入口消失 → F5；串行消失 → F3/F4。
复现阶梯：单测进程 → 并发文件 → 多测试进程 → 归属门禁全量 → 跨 job 共享资源；到首个签名为止。

---

## 5. 文档分层：docs/AGENTS.md

### 5.0 家载体分工：AGENTS.md（agent 自动加载）vs README（人读）

**这是 ponygo v2.0 起文档治理的地基**（实证：dsh 双轨，ponygo 骨架 v2.0 起播种）：

- **AGENTS.md**（根 + `docs/AGENTS.md` + 各子树/包 `AGENTS.md`）：**agent 自动加载**——
  agent 处理某路径下的文件时，该路径及所有祖先目录的 AGENTS.md 自动并入上下文
  （Claude Code / Codex / Cursor / opencode 等均实现）。治理规则、触发契约、文档标准
  必须放这里，否则 agent 不主动读就不进上下文，治理在机制上落空。
- **README**（根 + 各包）：**人读契约**——config/semantics/limitations/Model Experience。
  agent 不主动读不进上下文；它是给人（和 agent 被显式要求时）看的契约层，不是治理规则的载体。

**判据含义**（maturity-ladder §5 0.5 / 1.9 / 2.5）：L0 播种 `docs/AGENTS.md`（文档标准的家，
自动加载）；L1 判"文档有家"（docs/AGENTS.md 存在 + 根 AGENTS.md 索引链 + 包文档覆盖或豁免）；
L2 判"分层已激活"（docs-tier 从模板态推进为已激活清单）。**判据检查的是"家载体存在"**——
docs/ 的家是 AGENTS.md（自动加载），包契约的家是 README（人读），各归其位，不混用。

### 5.1 Tier 分类法：每个事实一个家

dsh 把"事实"按职责分到 14 个 tier，**每一 tier 的 Job 与该 tier 不承载的东西都写死**：

| Tier | Job | 不承载 |
|---|---|---|
| 根 AGENTS.md | 常载 standing orders（每次会话必载，1-3 行每条，链到 home） | 故事/示例/复述 |
| 子树 AGENTS.md | 该子树特定规则 | 根已载的全仓规则 |
| architecture.md | 有序地图：组合、核心包、环、接缝、扩展点 | 类型定义/单包细节/决策理由/状态标注 |
| subsystems/ | 每子系统一参考页（类型定义 + 生成 API） | 行为叙事 |
| Agent Notes | 活动决策记录（当前态现在时） | 迁移计划/验收清单/spec-speak |
| defensive-patterns/ | 审查中捍卫的规则集（通用缺陷类与按工件划分的防御规则） | 类型定义/运行时理由（→ subsystems / Agent Notes） |
| postmortem/ | 事故故事（唯一允许战争叙事层） | —— |
| Persistence 历史与格式 | 类型变更记录、发布差异对比与持久化历史格式 Schema | 纯运行时行为变更/当前契约 |
| cookbook/ | 带编号验证步的 how-to | 设计理由（→ note） |
| user/ | 产品面向指南（文档站发布） | 生成表/贡献流程/决策史 |
| 包 README | 单包契约：配置/语义/限制/扩展点/Model Experience | JSDoc 复述/生成目录复述 |
| development.md | 贡献者设置/日常流程/CI 摘要 | 运行时理由 |
| 生成参考 | 从源码再生成的穷尽英文源 + 新鲜度门禁 | 手编生成源 |
| Skills | 可复用工作流 | 产品/运行时契约 |

**放置速查**：bug→postmortem；理由→note；过程→cookbook；类型定义→subsystems；包契约→README；standing orders→根 AGENTS.md + 理由链；审查防御模式→defensive-patterns/；持久化演进→Persistence 历史。

### 5.2 写作规则

- **当前状态，不写变更历史**：durable prose 禁 "previously/now/no longer"、禁 PR/提交/栈位；变更故事进 commit/PR/note/postmortem（后两者可引已合并 PR/issue 为证据）；
- **一行一段**（verify-md-wrap 强制，编辑器软换行）；
- **`ts` 栅栏必须编译**（doc-typecheck）；粘贴的声明用 ` ```ts type-equiv `，删主体的公开类用 ` ```ts public-api `；两类条目都注册进 `scripts/type-equiv.manifest.json`，由 `verify-type-equiv` 按 1:1 校验防漂移；
- **命名具体**：写确切检查/类型/API/操作/行为，不用隐喻"gate/vocabulary/surface"；保留 `seam` 给已定义能力接缝（元 note：`2026-08-09-concrete-prose-names-actors-and-recorded-facts`）；
- 注释与 JSDoc 陈述**完整契约**（行为/失败/时序/归属/模态/例外/后果/非显然定位），删叙事/测试走查/评审分析/代码复述（→ dsh-prose-standard）。

### 5.3 Wordcount budgets

`scripts/doc-budgets.manifest.json` 定 standing-doc 上限；`verify-doc-budgets` 拒绝超限/缺文件。红门按 **relocate → condense → raise** 顺序处理（raise 须在 PR 里 justify manifest diff）。**上限是护栏不是压减目标**：目标线下保留至少 5% 余量。manifest 核心清单实测：根 AGENTS.md ≤2080、docs/AGENTS.md ≤1430、docs/architecture.md ≤2410、docs/cordis-primer.md ≤600、docs/testing.md ≤1350、packages/AGENTS.md ≤810、packages/README.md ≤994；实测值 2015/1351/2403/600/1347/769/963 全绿。

> 诚实边界（dsh 实测）：**只有这 7 个 key 是机械真值**。"子树 AGENTS.md 默认 ≤600"仅存在于 `docs/AGENTS.md` 散文；早期版本引的 `examples/AGENTS.md` ≤310 所指文件已不存在（`examples/` 下只有 `node_modules`）——这两条是 review 口径，不是门禁。另：`docs/AGENTS.md` 自身散文写 architecture ≤2,400 / testing ≤1,300，与其 manifest 的 2410/1350 不一致——**引用时以 manifest 为准**。

### 5.4 Slop checklist（审计清单）

- 同一条规则出现在多个家（grep 特色短语，留一个家链其余）；
- 叙述历史/战争故事（previously/now/no longer/renamed/was moved/PRs/commits）；
- 实现状态标注（"implemented!"/"future:"——状态会腐烂，布局与 manifest 携带它）；
- 手抄目录/JSDoc/测试包状态清单（源码或生成器是权威）；
- 推理转写（逐步实现叙事/显而易见分支的证明/测试走查/被拒的局部备选）；
- 理由在兄弟方法旁重复（应只在 owning 能力处一次）；
- 段落墙（一段多规则多括号插入语——拆分或降级到它的家）；
- 强调通胀（bold/CAPS/"critically" 到处都是 = 没有强调；只保留给改变行为的从句）；
- implemented note 里的 spec-speak（should/迁移计划/验收清单——implemented 描述"是什么"）。

### 5.5 postmortem / snapshots / 证据链

- **postmortem/**：编号 0001+，事故作用域参考——年表记录证据而非教学顺序；保留事故序列/证据/因果链/影响/预防，删重复说服与不确立因果的实现细节；双语配对（dsh 实测：`docs/postmortem/0001`–`0004` 共 4 篇 + README，各带 `.zh.md` + `.i18n.yaml`）；
- **snapshots/**：keyless recorded-session 回放，穿过 shipped profiles 跑（dsh 实测：位于**仓库根** `snapshots/` 而非 `docs/`，4 组 acp/sdk/session/web 共 354 个 `snapshot.yml`，另有 `packages/test-support/session-snapshot` fixtures 9 个，合计 363 个）；回放入口是**世代号最高的** `session[.vN].jsonl`（子角色 `session.<ordinal>[.vN].jsonl`），`snapshot.yml` 钉住 profile/composition/header 类与 sidecar 归属。**模型可见 ⟺ 已记录**：凡到达模型请求的东西必须能从会话日志重建；新模型可见输入要求新 session event；
- **GUI 证据链**：改产品可见 GUI 行为的 PR 必须带真实服务器 + 真实模型轮录制的 GIF（record-browser-gif）——一次演示 = 一次孤立运行，禁 fixture/mock/合成事件。

---

## 6. 架构不变量设计

### 6.1 五种铸造工艺（dsh 实例）

| 工艺 | dsh 落点 | 关键句 |
|---|---|---|
| 单一真源 | 会话日志即状态；`session-projection` 把已提交事件折叠成类型化状态（`stateOf()`），标题与遥测各是一个投影单元 | 派生面永不反向写回；缺投影服务即显式失败，不静默默认 |
| 接缝三角色 | capability seam = Service Definition（Cordis `Service`，不是 TS `interface`）/ Provider / Consumer；机械影子是**发布面依赖策略**（`verify-package-dependencies`，`client-only`/`client-host`/`configured-host` 三角色）与生成的能力图 `docs/capability-seams.md` | 用"变化速率与原因"定义拆分；单提供者单消费者保持一包。**"Consumer 不 import Provider"只是 note + review 纪律——dsh 没有这条门禁**（别把它写成机械事实） |
| 方向感知版本 | 单调 `SESSION_FORMAT_VERSION`（实测 **4**，`packages/core/session/src/types.ts:90`）；读取三分支：等版本→读；更高版本→拒绝并提示升级；更低版本→内存内相邻迁移链（源字节与 inode 不变） | bump 判据是"既有判别字段无法阻止不安全解读"——**结构差异本身不足以 bump**；权威页 `docs/session-format-status.md` 把 writer / 接受基线 / 已发布格式分开 |
| 类型印记（Branded） | `packages/util/brand/src/index.ts`：`Branded<B>`、`BrandedNumber<B>` + `brandString`/`brandNumber`，零运行时开销 | 只用于**跨边界不透明的 id**（`SessionId`/`ToolCallId`/`SessionLogOffset` 等）；裸 string 无法赋值，编译器先于运行时判错 |
| OS 级围栏（fail-closed） | 三模式 `read-only`/`workspace-write`/`danger-full-access` + 封闭升级梯；后端 Linux `bwrap`→`landlock-run`（原生 addon）、macOS `sandbox-exec`/Seatbelt、Windows 受限令牌 ACL；`fs-sandbox` 在用户态对写操作加同策略围栏 | 拒绝面是**逐后端 errno 方言**（EROFS / EACCES / EPERM / access is denied）；后端不可用即 `SANDBOX_UNAVAILABLE` **拒绝免隔离运行**——宁可不跑，也不降级放行 |

### 6.2 一行不变量主题表（dsh AGENTS.md 实况）

显式 > 隐式（`resolve(request): Spec`，禁隐藏 `?? default`）· fail loud（配置错误在自足时 loading 期爆炸，否则最早可解析点爆炸；空 catch 必须点名错误且只包一条语句）· 边界验证同进程信任（trust TypeScript at typed same-process boundaries，验证只发生在 parser/config/queued/model-tool JSON/durable-file/worker/process/wire）· 注册即 effect 返回 disposer · 封闭 union assertNever + merge 可扩展 union 走有记录的默认分支 · **跨边界不透明 id 一律 Branded**（非裸 string）· waterfall 必须 next() · Model-visible ⟺ logged · 禁硬编码 tunables（部署可变选择 = 验证过的 Config 字段，`DEFAULT_*` 常量不是可配置性）· 源码平面与产物平面永不混合 · 编译面显式（Host/Client 面叶配置 + 仅 solution 根）· **禁新增 `as unknown` 断言**（保留 legacy baseline）· **产品可见文案 locale-owned**（`verify-client-ui-i18n` 拒硬编码）· `cordis.yml` 裸插件必须登记进 resolver manifest 的 `dependencies` · 两套 SDK（TS/Python）同 PR 投影 loop 契约 · 快照所有权归场景（`snapshots/AGENTS.md`）· 新行为走插件扩展点，改 agent-loop 必须同变更更新 `docs/architecture.md` · 破坏对外可感知契约必须配升级指南。

### 6.3 捍卫层分布（P6 再应用）

编译期（类型/branded/派生函数）→ 加载期（方向感知版本拒绝 + 相邻迁移链 + 配置 fail loud）→ **运行期 OS 围栏**（每调用一次策略判定，报告完全/部分强制；不可执行即拒绝执行）→ **顶层执行门禁**（每个可机械检验的不变量接入一个被真正执行的 gate，并证明每条验收路径会拒绝非法输入）→ 语义层（review + note）。同一不变量选最便宜能抓住违例的层；机器到不了的地方由 review + note 捍卫并诚实标注。**dsh 现状没有运行时不变量服务**（§6.4）。

### 6.4 案例：守护层自身也要过 P8（运行时 invariant 的退场）

**事实**：`f028f25667`（2026-09-30，1355 文件 / −15,409 行）删除 `@deepseek-ai/dsh-invariants`（`ctx.invariants` 服务）、各包的 `./invariant` 伴侣及其测试、`scripts/package-invariants.ts`/`test-invariants.ts`/`verify-package-invariants.ts` 等门禁与 Vitest setup、scoped-event 生成器，以及 `INVARIANT` 码 listener rethrow 路径。今天 `scripts/` 与 `package.json` 中 `invariant` 命名**零命中**；迁移路径见 `docs/upgrade-guide/v0.2.0-rc.2/remove-runtime-invariants/`。

**退役判据（可复用的三条）**：

1. **表达否定结论的机器不叫守卫**——曾为每个包强制发布伴侣，其中 **209 个是"解释为空的伴侣"**：一个源文件、一条公开导出、一条发布入口、专属依赖、构建接线和测试，只为说明"本包没有可断言的运行关系"。
2. **形状检查已被更便宜的层覆盖**——幸存断言退化为插件名、注入、方法存在、固定示例返回值；这些形状 TypeScript、Cordis 启动、包测试与模块加载测试本来就在看守。
3. **自我验证的探针不算独立观测**——`dsh-host-webserver` 的伴侣在插件生命周期上改自己的路由表再查残留，没有第二个数据源，真实路由/HMR 测试已覆盖。

判据句（dsh 原话）：**"让每个伴侣可执行，却没有让系统更安全"**；**"一个有用的运行时不变量必须关联跨时间或跨可变数据结构的观测"**。

**代价（诚实条款）**：逐次执行的**关系型 tripwire 消失**——turn/step 嵌套、tool-call/result 配对、LLM 流块语法、重试单调性、审批配对等，改由属性测试（`packages/core/session/tests/properties.spec.ts` 断言 seq 严格单调、replay-from-seed 复现派生消息）、边界校验（append/restore 校验事件数据与 surface 元数据、`seq` 从 0 连续、header 版本必须为 4）与 keyless 录制快照承担。覆盖从"每次执行都在边界断言"降为"CI 抽样 + 评审"——这是 P8 的显式交换，不是免费午餐。

**证据链缺口（照实写）**：这次移除**没有独立的决策记录**。理由只在 commit message 与升级指南的 `## Change` 段（无备选），最接近的决策依据是归档 note `archived/simplification/2026-08-28-omit-unneeded-invariant-companions`（含 4 条备选，先砍空伴侣、后删服务）。按本文 §2.5 的触发规则，这类 −15k 行机制退场本应有同 PR 记录——此处标为 dsh 自身的一处**未达标**，不替它圆场。

**方法论结论**：守护层自身也过 P8。**"可执行"不等于"机械"**——机械程度取决于能否独立观测到违规；一个只能自证的断言，价值与写在散文里的愿望同阶，只是多了维护税。

---

## 7. 负空间：简化、拒绝与遗忘

### 7.1 简化工艺（dsh-find-simplifications + rejected 语料）

判决句模式：唯一消费者是自己 = 无真消费者。**连根拔不留壳**：源码+测试+快照+依赖补丁+目录条目+文档一张清单带走，验收 = "搜索零残留 + 门禁照常绿"。复活条件立法（拒绝"以后可能用得上"式怀旧；dsh 实例：`## Reintroduction conditions` 段落在 implemented/simplification 笔记，如 `2026-09-11-remove-e2b-providers`，rejected 语料只冻结否决判据、不承载复活条件）。**搬家不创造产品需求**（留别处 ≠ 简化）。

证据链四件套（靠 review）：owner、producer/consumer 路径、消失/保留清单、最强反方。
符号零命中不等于可删；历史案例只作提问清单；**计数不选优**（提案数量不证明方法优劣）。

### 7.2 依赖政策（`2026-07-26-dependencies-over-hand-rolling`）

引入依赖是**合法的简化动作而非政策例外**。净删除门槛：替换真实拥有的实现 + 专属测试 + 文档才算简化；只加能力的依赖是 feature 决策。健康度：无人维护的小包 = 用别人的弃码换自己的活码。边界契合：残余还得手搓的语义计入交换成本。不动已定案接缝（推翻了有笔记立法的设计须击败记录的理由）。警惕"没人决定过的规则靠惯例统治"（隐性 NIH）。政策双向同宽——换依赖方案自身也过审（rejected 语料里有 `dependency-swaps-rejected-by-nih-audit`）。

### 7.3 遗忘分级

rejected（8 篇保留：`simplification/` 7 + `architecture/` 1——**不是**"全部集中在单一 class"，v2.0 的单一 class 结论已被后续语料推翻）/ archived（未来指导价值判据 + 哈希冻结，924 篇；manifest 2772 条）/ supersession 审计（债务不过夜）。**遗忘是分流不是丢失；缺席必须是显式决定**。

---

## 8. 综合：决策飞轮

触发(枚举化覆盖规则) → 决策记录(格式契约 + Alternatives) → 门禁(P2/P7) → 技能(P3) → 评审/审计(supersession/负空间) → 反馈(bug/simplification/rejected) → 回到触发。**飞轮的意义不在环而在升维**：每圈让笔记库变记忆、门禁挡回归、skill 加快、负空间清债，对后续所有圈叠加。

---

## 9. 审查记分卡（四问法）

对任何项目依次回答，**先找磁盘证据再打分，不看 README 自述**：

1. **决策记在哪？** 有没有专门载体？覆盖面靠规则还是靠自觉？被击败的选项有没有留痕？（对照：dsh 有 296 篇 implemented + 强制 Alternatives 节 + 枚举化触发）
2. **承诺怎么强制？** 文档里的"必须/禁止"有几条变成了非零退出命令？强制是单点（本地 hook）还是分层（本地+CI）？**门有没有负样本证明**？（对照：dsh 的 verify 脚本 + spec 配对 + workflow 形状契约）
3. **重复劳动怎么复用？** 高频+高判断力流程是口传、一次性交接文件，还是入库的可复用资产？技能是否带触发式 description + 校准样例？（对照：dsh 19 个技能，全带内联触发 + 证据面匹配）
4. **过时的怎么退场？** 归档机制存在吗？归档后是否冻结（哈希封印）？工作区里有没有过期产物堆积？（对照：dsh 的 archived/924 篇 + append-only manifest（2772 条）+ `.rgignore` 隔离）

评分纪律：每问 0–10 分；每个缺口 → 一个最小改进动作；缺口之间找杠杆——**强制层是其他三层的放大器**，资源不足时优先投它。

**新鲜度/对应性抽查法（v2.1）**：取近 5 个功能提交，逐个对照有无对应文档更新
（计数排除 `.agents/notes/`——ADR 不算用户文档更新）；抽 N 条 implemented ADR，
用 `grep`/`git log -S <关键符号>` 对照代码现实，同提交携带的 ADR 是否文题相符。
两项都是 review 程序（语义判断），输出疑点 + 证据原文，不做机械 FAIL。

---

## 10. 迁移清单（按性价比排，勿照抄全套）

- **Wave1**：ADRs + 状态（路径编码 lifecycle）+ 枚举化触发条件 + **最小文档契约**（`docs/AGENTS.md` 文档标准的家，agent 自动加载；根 README 人读层）——文档存在性是 L0/L1 纪律，不是 L3 的事；
- **Wave2**：write-adr skill（触发内联 + 校准样例）+ verify 门禁（格式/链接 + 负样本）+ 最小 CI + 文档有家判据（L1，包文档覆盖或豁免）；
- **Wave3**：文档分层（tier 分类 + slop checklist + 词数预算，L2 起激活已激活清单）+ 双语配对（若双语）；
- **Wave4**：归档冻结（archived/ + 哈希 manifest + supersession 同 PR）；
- **Wave5**（按需）：顶层执行门禁自证（每条验收路径配一条负样本）+ OS 级围栏（fail-closed 模式与升级梯）+ 生成物漂移门 + 覆盖率分区；
- **长期**：每三次重复资产化为 skill。

**停止线：以规模值不值当为准。** 飞轮的起始条件是"转起来"而非"转得完美"——多记成本一段文字，漏记成本永久丢失。

---

## 终态提醒

本文档自身也应孵化配套脚手架（ADR 模板、gate 示例脚本、SKILL.md 模板），使"照做"不需要读文档——这是 P2 对本文档自身的应用。

---

## 版本记录

> 历史条目保留其发布时的取值（不回改），仅作为演进史；**当前真值以正文为准**。

- **v0.1–v1.2**：原按课次演进版本，从"七个维度课程"视角渐进记录（决策生命周期、门禁分层、流程资产化、不变量、负空间等章节的早期形态）。
- **v2.0（体系重写）**：依据对 deepseek-harness 落地体系的全面扫描（`.agents/notes` 全树 + 10 个技能 SKILL.md + lefthook.yml/CI workflows + docs/AGENTS.md + scripts/ 验证脚本）重写。主要变化：
  - 结构从"按课次"重构为"按体系模块"：决策记忆 §2 / 流程资产 §3 / 强制 §4 / 文档分层 §5 / 不变量 §6 / 负空间 §7；
  - 补齐原缺的子系统：archived 冻结归档（§2.3）、i18n 双语配对（§2.8）、文档 tier 分类与 slop checklist（§5）、postmortem/snapshots/证据链（§5.5）、生成物漂移门与负样本 spec（§4.5）、可执行 lint 契约（§4.5）、CoT 泄漏清理（§3.2）；
  - 修正失真：实际规模（implemented 604 英 + 中文配对、10 技能而非 11）、实际门禁配置（lefthook 而非自造钩子、L2 仅 typecheck）、"pony 已落地"表述改为 dsh 实证；
  - 补全第一性原理编号说明（P4/P5 未定义注明）；
  - 校准样例（归档 keep/archive/delete 正反例）从 dsh skill 原文收录。
- **v3.0（通用化重构 + 对抗审核）**：派两路子智能体对代码库再次扫描与对抗审核（核实 + 方法论），主要变化：
  - **事实修正**（核实子智能体逐条比对代码库）：§0 规模「120+ 包」→「约 260 个包」、「CI 8+ 聚合门」→「9 个聚合 job」；§4.2 lint 触发 glob `*.ts`→`*.{ts,tsx,mts,cts,mjs}`、vendor guard 由「vendor 改动」改为「无 glob 每次必跑」；§4.4 CI job 名由 display name 改正为真实 job key（`node-24`/`node-24-coverage`/`node-24-consumers`）、windows 由 1 个改 5 个、补 `python-runtime` 与 `serial-macos`/`wine-apt-cache`/`consolidated-runner-benchmark`、cancel-in-progress 措辞精化；§5.3 词数预算由 3 例补全为 8 项清单；§7.3 补「rejected 10 篇全集中在 simplification/ 类」。
  - **通用化重构**（对抗审核子智能体）：标题与定位从「dsh 工程化体系全解剖」改为「软件工程化经验沉淀」，deepseek-harness 由叙述主体降格为实证案例；新增「读者定位与术语约定」「本文不覆盖的维度（界外 6 项）」两节；正文普适原则与 dsh 实证分层（标注「实例」/「dsh 选型，等价物 X」）；§0 表格新增「验证命令」列，诚实标注哪章靠自觉/靠 review。
  - **英文术语中文翻译规范**：首见英文术语/工具名/方法论名词附中文翻译一次（如 leverage（借力点）、seam（接缝）），命令/文件名/路径/脚本名/job 名/代码标识符不加。
- **v3.1（对 dsh `v0.2.1-rc.5` 源码复核）**：按 `de5d733a18`（2026-10-31）逐条复核全部事实断言与机制主张，改动分三类：
  - **机制修正（P0）**：§6.1 第 4 行「运行时不变量」整行失效——`@deepseek-ai/dsh-invariants`、各包 `./invariant` 伴侣、相关门禁与 Vitest setup 已由 `f028f25667`（2026-09-30，−15,409 行）整体删除；改为「OS 级围栏（fail-closed）」入表，另新增 §6.4 记录退场判据、代价与证据链缺口；§6.3 层序去「运行时常驻（invariant 服务）」、换成「运行期 OS 围栏 + 顶层执行门禁」；§4.5 移除已删的 `gen-scoped-events`；§6.1 第 2 行把 `verify-package-dependencies` 的职责从「禁止 Consumer import Provider」改正为发布面依赖段策略（该禁令在 dsh 只是 note + review）；§6.1 第 3 行 `SESSION_FORMAT_VERSION` 由 0 更正为 **4**，bump 判据从「结构变更才 bump」反转为「既有判别字段无法阻止不安全解读才 bump」，并补非对称读取三分支；§6.1 第 1 行删除 dsh 全仓零命中的伪引语；§4.6 标注 `PONYGO_*` 段为框架侧机制。
  - **事实数字（P1）**：§0 规模 500+ → **366**（8 private / 358 发布）、notes 298/42/**8**/**924**（manifest 2772 条）、doc-sync 30 → **42** 门、CI 聚合 9 job（含 `node-24-bench`、排除 `windows-coverage`、`!cancelled() && pull_request`）、windows 5 → 3 个 job、`node-compat` 22.19/24.9/26、`wine-apt-cache` 已删、`cancel-in-progress: true`；§3.2 code-review **6** blocking / **17** manual checks、归档 **五**步；§5.3 删除不存在的 `examples/AGENTS.md` 预算并标出只存在于散文的两条；§5.5 `session.vN.jsonl` 回放入口、`snapshots/` 在仓库根 250 个、postmortem 4 篇；§7.3 rejected 8 篇跨 2 个 class；§9 记分卡 604→298、10→19 技能、169→924 归档；§10 Wave5 去「运行时不变量」。
  - **新增实证（P2）**：§6.1 增「类型印记（Branded）」独立成行（对齐系列文章口径）与「OS 级围栏」；§6.2 补 7 条现役不变量（禁新 `as unknown`、locale-owned 文案、`cordis.yml` resolver manifest、双 SDK 投影、快照所有权、插件扩展点、升级指南）；§4.1 补钩子安装器的归属标记/安装锁/自带负样本；§4.4 补 failover 选择器与新增 workflow；§4.5 补 `verify-type-equiv`/`verify-repository-references`/`verify-export-jsdoc`/`verify-concrete-terms` 与 4 个生成器，并把「每个门都有负样本」改写为实测 **14/29（≈48%）**。
- **v3.2（对 dsh `de5d733a18` 的计数复核与落点定位）**：按 `git ls-files` 复核笔记规模与快照计数，修正两处数字、补一处落点：
  - **事实修正（P1）**：§0/§9「implemented 298 活态」→ **296**（按 `.agents/notes/implemented` 去重 id 计数；298 系误计目录内 AGENTS.md/CLAUDE.md，§2.1 六类合计 40+11+13+180+34+18=296 自洽）；§5.5「250 个 snapshot.yml」→ **363**（四组 acp 11 / sdk 40 / session 239 / web 64 = 354 + `packages/test-support/session-snapshot` fixtures 9）；
  - **口径补全（P2）**：§7.1 标注复活条件的 dsh 落点——`## Reintroduction conditions` 在 implemented/simplification 笔记（如 `2026-09-11-remove-e2b-providers`），rejected 语料只冻结否决判据、不承载复活条件（对齐系列文章口径，防误指 rejected/simplification）。
- **v3.3（对 dsh `de5d733a18` 的门禁统计口径复核）**：按 `scripts/run-gates.ts` 与 `scripts/*.spec.ts` 实存文件复核两处口径，修正一处数字结构、一处措辞（源仓库自身上一轮修订的延续，v3.2 已预留）：
  - **口径补全（P1）**：§4.5 负样本覆盖由不可复现的「29 个具名脚本中 14 个（≈48%）」改为可复现双口径——点名集 19 个 verify/check/coverage 脚本中 8 个同名 spec（另 `run-gates` 自带 `run-gates.spec.ts`）、13 个 gen 生成器中 9 个；全仓 `verify-*.ts` 76 个、同名 spec 30 个（≈39%）。
  - **事实修正（P2）**：§0 doc-sync 由「42 门」→ **43 叶**（`run-gates.ts` `case 'doc-sync'` 直接返回 `docSyncLeafGates()`，实测 43 个叶门、quick 21；「42」系不含 doc-typecheck 或按聚合再取的旧口径，无命令可复现）。
