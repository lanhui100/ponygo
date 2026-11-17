# Agent Note: 存量违例基线棘轮（`upgrade adopt`）与植入版本可追溯（seed）

Status: implemented

## Problem

ponygo 的判定面在实例侧有两处结构性缺口，2026-11-17 的植入效果审计给了实证
（`docs/dev-team/reviews/2026-11-17-qms-implant-effect-audit.md` §3 的 U6/U8 两行）：

1. **存量债让门"出厂即红"**：判据是框架统一发布的（1.8/1.10/1.11），新增判据抵达旧实例后，
   历史决策记录会成批不达标。ponyllm 实测 `verify-note.sh` exit 1、48 条存量 FAIL；同一会话里
   agent 的理性选择是 `git commit --no-verify` 提交并 push。门没有"存量豁免/清零路径"，
   唯一的出路就是绕过——这是体系缺陷，不是执行者偷懒。
2. **跨仓植入无版本可追溯**：实例不携带 CLI，判据 2.1（框架门资产逐字节等于模板）只能与
   "当前 PATH 上的 CLI"比对。CLI 一升级，所有实例的 2.1 立刻变红（upgrade cliff）；
   而 `upgrade apply` 又会一次性覆盖实例侧可能的弱化证据，两条路都不可用。
   实测本机 12/12 实例门 spec 停在旧代（缺 `PONYGO_GATE_SPEC_TIMEOUT` 平台派生）。

## Decision

1. **存量违例基线棘轮 = `upgrade` 的位置模式 `ponygo upgrade adopt`**（不是第七个顶层命令）
   - 依据 `implemented/process/2026-08-30-six-command-surface.md`（命令面固定 7 词）与
     `implemented/process/2026-11-07-flag-budget.md`（新增旗标只允许 `--json`/`--dry-run`/`--run-specs`）；
     位置子命令有 `upgrade apply`、`archive-verify.sh check|seal` 的先例。
   - 基线文件 `.meta/notes-baseline.json`（机器写入、禁手填）：`schema`/`generated_at`/`expires_at`/
     `framework_ref`/`entries[].{file,criterion,fingerprint}`。
   - fingerprint = `sha256(criterion \t file \t 规范化明细)`——同一文件同一判据的**明细变了就是新违例**，
     否则冻结等于给该判据开永久后门。
   - **判定真源单一**：`upgrade adopt` 只解析 `verify-note.sh --json`，CLI 不复刻任何 1.x 判据（P9）；
     基线豁免逻辑也长在 `verify-note.sh` 里，于是 A1（暂存区门）/A4（全树门）**字节零改动**即获得棘轮语义。
   - **防停车场三支柱**：① 到期日硬上限 365 天（缺省 +90 天，非法即 exit 2 零落盘）；
     ② 过期后基线整体失效、全部违例重回生效，必须显式重跑 adopt 才留下 git 证据；
     ③ 每次运行必打印 `存量 N（较上次 +M/-K）`，`status`/`audit` 默认打印存量行——增长靠人看见，不设批不批的开关。
   - 出册（旧条目已不再违例）自动删除：棘轮只收紧不膨胀。

2. **植入版本可追溯 = `.meta/.ponygo-seed`**
   - `init` 幂等写入（已存在不覆盖）；刷新唯一路径 = `upgrade apply` 重签；`init --repair-skeleton` 不碰 seed
     （补缺失 ≠ 改 provenance）。不新增 `--refresh-seed` 旗标。
   - `files` 键集**从 `UPGRADE_UNIVERSE` 派生**（禁第二份清单），sha 按 EOL 归一口径（与 skeleton_drift 同源）。
   - `upgrade --check` 在既有 `drift:` 行尾追加 `[in-sync|stale|modified|unknown]` 分类：
     当前 sha == 模板 → in-sync（不打印）；== seed 记录 ≠ 模板 → `stale`（实例仍是植入时字节）；
     两者都不等 → `modified`（实例侧被改过）。**退出码语义不变**——provenance 不是判定面，
     把它变成门会重演 upgrade cliff。

3. **人读摘要行（只追加，不改 JSON）**：`status`/`audit` 各加一行「植入基线 / 存量基线」；
   `status --json`/`audit --json` 的冻结字段词表本批零改动（加字段须与冻结测试同批，留待 U8-b）。

4. **文档同批**：`README.md`、`.meta/gates/README.md`、`maturity-ladder.md` 与
   `implemented/architecture/2026-08-30-meta-governance-root-layout.md`（`.meta` 布局枚举）
   随本次提交更新。

## Alternatives considered

- **新增顶层命令 `ponygo adopt`**：否决——破坏六条命令面 ADR 与冻结的命令面不变量测试
  （`tests/acceptance/auditfix/f3_repair_idempotent.sh` 把 7 词集合钉死），收益只是一个位置模式就能表达的能力。
- **`--allow-growth` 开关**：否决——存量违例都是真违例，"批不批"没有判据可依，开关只会把治理退化成一次点击；
  改为"每次必打印存量行"。
- **`--refresh-seed` 旗标**：否决——刷新语义已存在（`upgrade apply` 重写模板后重签），再加旗标等于给 provenance 开第二写路径。
- **把基线过滤做在 A1/A4 门里**：否决——门资产字节冻结（本轮铁律），且会形成暂存区门/全树门两份实现（P9）。
- **基线按 (file, criterion) 冻结**：否决——明细变化会被误判为"同一条"，等于永久后门。
- **seed 缺失/损坏让 `--check` exit 2**：否决——provenance 不是判定面，只降级为 `unknown` + 修法提示。
- **基线到期自动顺延**：否决——"永久冻结所有债"正是该机制最大的风险。

## Consequences

- 旧实例的迁移路径变成可机械执行的：`upgrade apply`（同步判据 + 重签 seed）→ `upgrade adopt`
  （冻结存量债，带到期日）→ CI 转绿；"一次发布全实例变红"不再是必然。
- 新增两条**机器态文件**（`.meta/notes-baseline.json`、`.meta/.ponygo-seed`）进入 `.meta` 布局枚举。
- 遗留风险（诚实登记）：基线可能被反复重跑当作"停车场"（三支柱只能提高成本、不能禁止）；
  `modified` 分类只报告不阻断，改门资产仍靠 review 与 2.1 判据。
- 本批不做（登记为后续）：`upgrade --json`、`upgrade apply` 对 `modified` 的二次确认、
  `status`/`audit` 的 seed/baseline **JSON** 字段（须与冻结的 f8 词表断言同批改）。
