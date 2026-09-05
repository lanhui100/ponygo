# Revision: 读侧机制完整版——change-review 技能 + 写前检索全程序 + AGENTS 双文件 + 读触发枚举

Status: accepted

## 回馈证据（ponyllm 实例三轮验证 + dsh 对照）

ponygo 框架规定了"何时写"（write-adr 触发枚举 + verify-note.sh 格式门禁），没规定
"何时读"。读侧只有一个低频入口（用户点名的 governance-review）。dsh 对照显示读是
日常动作，嵌入三个高频流程：评审 PR 时读相关 ADR（dsh-code-review）、写新 note 前
scoped audit 旧 note（dsh-archive-agent-notes："Every new Agent Note triggers
a supersession check"）、找简化/归档时读 note 树；另有 `.agents/notes/AGENTS.md`
子树自动加载把规则随上下文带进来。

该缺口在 ponyllm 造成三起实质问题（2026-09-04 合规审查实证）：

1. **8f37827 文不对题**：TUI 定价功能（11 个 `.rs`）携带无关的多协议 proposed note——
   写时没检索旧 note，评审时没人对照；
2. **error-observability 部分落地未拆分**：`AttemptObserver` 已随 76d8799 进主干，
   note 仍整体标 proposed——无人做 supersession 检查；
3. **09-05 note 滞留 proposed**：无人复查旧提案状态。

轻量补丁（只给 write-adr 加一行"检索旧 note"）已被否决：检索无程序、无样例、无自动加载
支撑等于多一条散文，复现 8f37827 类失败只是时间问题。

## 框架规则变更

### 1. 新框架交付技能 `change-review`（读侧入口，与 write-adr 配对）

评审一处变更（工作区 diff / 单个提交 / 分支）是否符合已记录决策。对标 dsh-code-review，
ponygo 化（栈无关、单文件、无外部依赖）：

- **触发**：模型可自主路由（description 内联触发条件：评审 diff/commit/分支是否合规时）；
  governance-review 保持用户点名（重型全身体检），change-review 是轻量单次评审。
- **真相源**：notes/README（契约）+ constitution（命约）+ docs/AGENTS.md（same-commit）
  + 本次检索到的相关 ADR（程序要求先检索再评审）。
- **程序**：定范围（文件清单）→ 检索相关 ADR（关键词 grep，排除 archived 判例只读史）→
  逐项检查：对应性（ADR↔代码，`grep`/`git log -S`）、same-commit 文档、Status 迁移需求、
  supersession 屏查 → 输出 blocker/non-blocker + 磁盘证据。
- **校准样例**：正例（带证据的短评审 > 一串 nit）；反例（无证据断言、把 review 判断说成
  机械、nit 堆砌）；边界（靠 review：重构归类、是否用户可见）。
- **验证与报告**：交付物 = 评审报告；后续动作（问题修、note 迁移/拆条）。
- **skills/README 豁免条款**：追加第三个框架交付技能——评审是框架判据的执行时刻，
  读旧 ADR 是每次评审的固定动作，消费者由框架自身创造（Rule of three 豁免同 write-adr）。

### 2. write-adr：写前检索全程序（不是一行提示）

在"判触发"之后插入完整步骤（程序 + 判定表 + 样例）：

- **检索**：`grep -r`/`rg` 主题词、模块路径、关键符号扫 `.agents/notes/` 活动树
 （proposed/implemented/rejected；archived 只读史不判）；
- **判定表**：无关→直接写；相关→正文链入旧条；被取代/部分取代→走 supersession
 （旧条归档或链入，同一提交处理，不 deferred）；
- **校准样例**：正例（新 note 链入被部分取代的旧条）；反例（8f37827：TUI 提交携带多协议
  note）；边界（多阶段提案部分落地：落地部分拆条，如 `AttemptObserver` 案例）。

### 3. `.agents/notes/AGENTS.md` + `archived/AGENTS.md`（自动加载层）

- `notes/AGENTS.md`：进 notes 子树自动加载——写前检索义务、supersession 义务、
  lifecycle 一句话、链到 README（全文）。对标 dsh `.agents/notes/AGENTS.md`。
- `archived/AGENTS.md`：冻结规则（永不编辑、不作现行权威、引用方式、恢复流程）。
  对标 dsh `archived/AGENTS.md`。
- 两文件由 `write_skeleton` 生成（缺失时与模板逐字节一致，s14 约束）。

### 4. notes/README.md：读触发枚举（与写触发规则对称）

新增一节"读触发规则（何时读旧 ADR）"，与现有写触发规则对称：

- 写新 ADR 前（检索 + supersession，见 write-adr）；
- 评审变更时（change-review）；
- 找简化/归档时（读 note 树理解意图、按未来价值分类）；
- 治理审查时（governance-review 决策面抽查）；
- 接手陌生模块时（先读相关 implemented 再读代码）。

### 明确不做（P6 边界）

- 不做"未读旧 note 拒绝提交"FAIL 门禁：读没读是语义，机器验不了；
- 不做实例技能副本的版本戳机械（离线断开无信道，v2.1 已定）；
- 不碰阶梯与 FAIL 判据（本次无新机械判据，L0–L5 语义不变）。

## 采纳理由

- 三起实证（8f37827 / error-observability / 09-05 滞留）都是"有写侧无读侧"的直接产物，
  轻量补丁盖不住；
- dsh 实证：读侧机制（review 技能 + 写时 supersession 检查 + AGENTS 自动加载）是其
  604 篇 notes 不腐烂的操作原因，ponygo 通用化时只搬了写侧；
- 成本：1 个新技能 + 2 个 AGENTS 小文件 + 2 处技能正文 + 1 节 README 枚举，零依赖、
  无新 FAIL 判据、无阶梯变更；版本 v2.2.0（新能力，小版本）。

## Alternatives considered

- **轻量版（只给 write-adr 加一行检索提示）**：否决——无程序、无样例、无自动加载，
  等于多一条散文；维护者已明确要求完整版。
- **只加 change-review 技能，不加 AGENTS/枚举**：否决——技能无自动加载支撑则触发靠运气；
  AGENTS 双文件是读规则进上下文的唯一通道（v2.0 家载体结论）。
- **把 supersession 做成独立第四技能**：否决——supsersession 是写流程的一步（dsh 把它放进
  archive 技能是因为 dsh 有独立归档流）；ponygo 的归档在 L4 目标画像，当前把完整程序
  放进 write-adr + AGENTS 义务，足够且少一个技能的维护税（P9）。
- **维持现状**：否决——三起实证证明缺口已造成实质伪证据与状态失准。

## 影响面

- ponygo 脚本：`write_skeleton` 新增三段 heredoc（notes/AGENTS.md + archived/AGENTS.md +
  change-review/SKILL.md）；
- `.agents/notes/README.md`：新增读触发枚举节（heredoc 双写，s14）；
- `.agents/skills/write-adr/SKILL.md`：写前检索全程序 + 判定表 + 样例（heredoc 双写）；
- 新 `.agents/skills/change-review/SKILL.md`（副本 + heredoc，s14 覆盖触发式 description 断言）；
- `.agents/skills/README.md`：豁免条款追加第三技能（heredoc 双写）；
- 新 `.agents/notes/AGENTS.md` + `.agents/notes/archived/AGENTS.md`（副本 + heredoc）；
- 测试：tests/run.sh 增断言（新文件存在 + 触发式 description + 逐字节一致）；
- methodology：§2.6（supersession 程序升格）+ §3（技能清单 11→12 口径：实例技能数）；
- 版本：v2.2.0（README 示例同步）。
