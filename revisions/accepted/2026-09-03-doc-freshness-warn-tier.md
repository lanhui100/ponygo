# Revision: v2.1 文档新鲜度"提醒档" + ADR 对应性校准——same-commit 与文题相符的框架级修复

Status: accepted

## 回馈证据（ponyllm 实例两轮验证）

**第一轮（2026-09-03 复检）**：v2.0 机械判据全绿但 `docs/` 零提交，5 个新功能只带 ADR
不带用户文档；`f5201b9` 改 14 个 `.rs` 不带 1 个用户文档，pre-commit 三连全绿放行——
same-commit 无机械影子。

**第二轮（2026-09-04 合规审查）**新增三条框架级证据：

1. **对应性真空（P0）**：`8f37827`（TUI 定价表单，11 个 `.rs` 含 292 行 responses.rs 重写）
   携带的是一篇未来日期的多协议声明 proposed note——TUI 定价本身零 ADR。v2.0 所有判据
   查"有没有 ADR"，没有一条查"ADR 是不是这坨代码的"。伪证据比缺席更隐蔽（形状全绿）。
2. **WARN 启发式定义错了"文档"（P1）**：第一轮加的实例 WARN 把 ADR 的 `.md` 也算作
   "文档更新"，于是"代码 + ADR、无用户文档"的 5 个提交全部静默通过——看守存在但守错了东西。
3. **未来日期机械可查却无人查（P2）**：`date -d` 只判"是不是真日子"，不判"是不是未来"；
   09-05 的 note 机械全过。日期超前要么是笔误要么是计划前置，两种都值得 WARN。
4. **语义状态抽查**：cross-provider-failover（implemented）经代码对照属实落地 ✓；
   error-observability（proposed）部分构造（`AttemptObserver`）已随 76d8799 进主干，
   note 仍整体标 proposed——落地部分与未落地部分未拆分（P2，状态失准）。

## 框架规则变更

### P0：提醒档进骨架（启发式 WARN，不碰 FAIL 语义）

1. **write_skeleton 的 gates 模板追加 `doc-freshness` WARN 片段**（ponyllm 已验证形态，
   **本次精化**：计数时**排除 `.agents/notes/`**——只认非-notes 文档为"文档更新"，
   否则 ADR-only 提交永远静默）。片段自带 P6 诚实注释与退场指引。
2. **`warn_governance_hygiene`（status/audit 双挂）追加两条启发式 WARN**：
   a. 新鲜度：近 5 提交代码大改而非-notes 文档零动 → 提示跑文档面复检；
   b. 未来日期：notes 树下有日期晚于今天的决策文件 → 提示核对（笔误或计划前置）。
   两条均明确标注启发式、误报忽略，与现有卫生 WARN 同级（不改退出码）。

### P0：对应性校准进技能（review 层，机械到不了的地方用程序+样例守）

3. **write-adr SKILL.md 追加对应性校准**：ADR 必须引用它治理的代码路径/提交；
   反例收录 8f37827（TUI 定价提交携带多协议 note = 文不对题）；边界：多阶段提案
   （如 error-observability 四层）部分落地时，落地部分拆条或链入 implemented。
4. **governance-review 决策面追加对应性抽查程序**：抽 N 条 implemented ADR，
   `grep`/`git log -S` 对照代码现实（`resolve_routed_targets` 式正例 + 8f37827 式反例）；
   文档面追加第一轮沉淀的"近 5 提交对照"新鲜度抽查程序。

### P1：给 review 定节奏

5. **bootstrap/constitution 加节奏建议一句**："每 N 个功能提交或用户点名时跑一次文档面
   复检"（建议，非硬门禁）。

### 明确不做（P6 边界）

- 不把新鲜度/对应性做成 FAIL 判据（语义判断，误报不可接受；WARN + review 是上限）；
- 不做 `pub` 扩散分析之类的精确机械判定（成本高，违背规模原则）；
- 不做实例技能副本的版本戳机械（实例与模板离线断开，无信道；靠升级纪律 + meta-review 目检）。

## 采纳理由

- ponyllm 两轮验证：WARN 形态已在实例落地有效；精化方向（排除 notes 计数）来自真实盲区，
  不是纸面设计；对应性反例（8f37827）与正例（cross-provider-failover 6 命中）都是实证；
- P6 相容：提醒档 + 技能校准都不装"机器判了语义"的假门禁——WARN 只说"形状可疑请人看"，
  技能只给"程序 + 样例"，结论归人；
- 成本：骨架片段 + 两段 WARN 探测 + 技能文字，零依赖、秒级；版本 v2.1（只加 WARN/技能，
  无新 FAIL 判据，无阶梯语义变更）。

## Alternatives considered

- **维持现状**：否决——两轮验证证明"存在性判据 + 点名 review"组合下，新鲜度欠账与伪证据
  ADR 可长期存活而框架零告警。
- **对应性/新鲜度做成 FAIL**：否决——语义判断误报不可接受，违反 P6。
- **只做提醒档不做技能校准**：备选——若认为技能文字太重，可只采纳 P0 机械部分；但对应性
  真空只能由 review 程序补，技能是唯一载体。
- **实例各自为战**：否决——same-commit 与对应性都是框架命约，命约无骨架/技能支撑等于空话。

## 影响面

- ponygo 脚本：gates/README.md 模板追加 WARN 片段（heredoc +  ponygo 自身副本同步，s14）+
  `warn_governance_hygiene` 追加新鲜度/未来日期 WARN；
- `.agents/skills/write-adr/SKILL.md`：对应性校准（heredoc 双写）；
- `.agents/skills/governance-review/SKILL.md`：决策面对应性抽查 + 文档面新鲜度抽查（heredoc 双写）；
- bootstrap/constitution：节奏建议一句（heredoc）；
- 测试：tests/run.sh 增断言（WARN 片段存在；WARN 不改退出码；未来日期 WARN；精化启发式排除 notes）；
- methodology：§3.3（设计模式：对应性）+ §4（提醒档）+ §9（新鲜度/对应性抽查法）；
- 版本：v2.1.0（README 示例同步）。
