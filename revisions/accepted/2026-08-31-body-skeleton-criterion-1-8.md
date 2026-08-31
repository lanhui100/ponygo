# Revision: 判据 1.8——正文骨架与 lifecycle 匹配机械校验（accepted）

Status: accepted

## 框架规则变更

1. **decisions/README 格式契约补全**：原契约只规定 implemented/ 骨架，proposed/ 与
   rejected/ 是真空。补 lifecycle → 正文骨架对照表：proposed/ = `## Proposal`（将来时）
   + Alternatives + Acceptance criteria + Risks；implemented/ = `## Decision`（现在时）
   禁提案时代标题；rejected/ = 提案原文冻结、verdict 只在 Status 行；archived/ 冻结豁免。
   补"迁移即改写"条款（proposed → implemented 必须把 Proposal 改写为现在时）。
2. **write-adr 技能**：步骤 6 改为 lifecycle 骨架对照表；校准样例补"时态错位"反例。
3. **新增机械判据 1.8**：proposed/rejected 缺 `## Proposal` 或含现在时 `## Decision`
   即 FAIL；implemented 含提案时代标题（`## Proposal`/`## Plan`/`## Migration plan`/
   `## Acceptance criteria`）即 FAIL；archived/ 与 README 豁免。maturity-ladder §5
   同步回写（判据真源）。

## 采纳理由（回馈证据）

ponyllm 实例实证：agent 按 bootstrap 引导写出的第二条 ADR（proposed/ 架构提案）
误用了 implemented 专属的现在时 `## Decision`——1.1–1.7 全 PASS，因为路径/文件名/
Status 三重影子锁不到正文骨架。根因是框架契约真空（proposed 骨架在 ponygo 化精简时
从 dsh 契约中丢失）+ 技能以 implemented 为中心把真空教成了错误。时态与状态一致是
决策记录可审计的前提：提案用现在时等于未批准的方案伪装成已落地的决定。

## Alternatives considered

- **只补文档契约、不加机械判据**：否决——这次漂移恰恰是"契约没写 + 判据没有"双重
  缺席；只补文档，下次照样 1.1–1.7 全绿地漂（P2：凡机械可查必配命令）。
- **proposed 也允许 ## Decision（放宽契约而非收紧判据）**：否决——时态错位损害
  "当前态 vs 提案"的可区分性，这是 decisions 体系的审计基础。
- **rejected/ 豁免 ## Proposal 要求**：否决——rejected 的定义就是"提案原文冻结"，
  无提案原文则冻结无从谈起。

## 影响面

- ponygo 仓库自身 8 条 ADR 全部 implemented + `## Decision`，天然合规。
- 存量实例：含 proposed/ 记录的实例升级后 status 可能从绿变 exit 1——判据生效的
  预期行为，按提示改写即可。
- 测试：s11 追加 1.8 三例（合法 / proposed 误用 Decision / implemented 含提案标题）。
