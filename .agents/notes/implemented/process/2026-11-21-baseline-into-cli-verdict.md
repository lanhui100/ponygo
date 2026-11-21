# Agent Note: 存量基线进入 CLI 判据面（status/audit 的 1.8 不再对已 adopt 的实例恒红）

Status: implemented

## Problem

W0 交付 `upgrade adopt`（存量违例基线棘轮）后，实机暴露一个**两面结论相反**的缺陷（B023）：

- ponylm 上 `upgrade apply` + `upgrade adopt` 完成（48 条存量冻结、到期 2027-02-16），
  `verify-note.sh` / A1 / A4 / `ci-verify` **全绿**；
- 同一棵树 `ponygo status` 仍 `exit 1`，`ladder.fails=["1.8"]`（29 条 implemented 迁移未改写的存量债）。

根因：基线豁免只长在**判定真源** `verify-note.sh` 里；CLI 的 `verify_ladder` 自己复刻了 1.1–1.9 的判定、
且**不读基线**。后果是 adopt 只修好了门禁面，判据面（`status`/`audit`，也是 A5 判据面步骤要跑的东西）
依旧红——实例"花了力气 adopt，CI 还是红"，这正是 W0 想消灭的绕过诱因。

## Decision

1. `verify_ladder` 读 `.meta/notes-baseline.json`，按 **criterion == "1.8"** 的条目把 `file` 收成集合；
   1.8 循环里命中者**不计入** `n18/n18d`，并累计 `BL_SKIP`；循环后打一行 stderr：
   `WARN 判据 1.8：N 条存量违例由存量基线覆盖（…，到期 <YYYY-MM-DD>）——本命令按文件豁免，真源 verify-note.sh 仍按指纹校验（A1/A4）`。
2. **基线可用性三态**：不存在 → 不豁免（行为与旧版一致）；`expires_at` 不可解析/已过期 → **不豁免** +
   `WARN 存量基线已过期（…）→ 判据 1.8 按全量判定；跑 'ponygo upgrade adopt' 重签`；可用 → 生效。
3. **粒度诚实条款**（写进代码注释与 `.meta/gates/README.md`）：CLI 面按 **(file, criterion)** 豁免，
   比真源的 **(criterion, file, 规范化明细) 指纹**更粗——同一文件"换一种 1.8 违例"在 CLI 面会被一并豁免；
   但真源（A1/A4 与 CI 全树门）仍按指纹拒绝，**故 CLI 面只是摘要视图，不替代真源**。
4. `--json` 的 `ladder.fails` / `miss_ids` / `exit` 随判定自然变化，**字段词表零改动**；
   1.1–1.7、1.9、2.x 与命令面/旗标零改动；不新增判据编号。

## Alternatives considered

- **让 CLI 调 `verify-note.sh --json` 拿指纹级结论**：否决——`status`/`audit` 是只读命令，
  `methodology.md` §4 明确"只读判定不执行仓库脚本"（对陌生遗留仓库 = 任意代码执行）。
  这也是 1.10/1.11 一直只由真源判定的同一条边界。
- **在 CLI 里复算 fingerprint**（复刻明细规范化）：否决——同一算法两份实现必然漂移（P9）；
  而且 CLI 的 1.8 检查本身不产出"明细字符串"，复刻等于把真源整段搬过来。
- **CLI 完全不再判 1.8**（与 1.10/1.11 同口径，全部交给真源）：否决——那会让**没有基线**的实例的
  `status` 失去 1.8 看守（`status` 是很多实例唯一会跑的判定面）；且结论行范围措辞（"1.1–1.9 PASS"）
  与多套冻结断言要一起改，收益小于风险。收窄到"有基线才豁免"是最小闭包。
- **改成"只要基线存在就整体跳过 1.8 判定"**：否决——比按文件豁免更粗：会连"基线外新违例"一起放过；
  按文件豁免至少要求该文件确实在基线里登记过（`T-B023-3` 看守这一点）。
- **让 `adopt` 顺手把 status 的结论钉进 JSON**：否决——判定与记录混在一处，`status` 会退化成读缓存。

## Consequences

- adopt 之后判据面与门禁面结论一致：`status` 转 0、`--json` 的 fails 不再含 1.8；新增违例仍被点名。
- 基线一旦过期，CLI 立刻回到全量判定（不静默放行）——这与真源的过期语义一致（同一份 `expires_at`）。
- 代价（诚实登记）：颗粒度差异（按文件 vs 按指纹）意味着"同一文件换一种 1.8 违例"在 `status` 面不可见；
  该风险由真源门（A1/A4）兜底，属"摘要视图 + 真源裁决"的分工，不是新增放行面。
- 本批不动 `verify-note.sh`（真源零改动）与基线文件格式；存量基线无需迁移。
- 后续（B023 之外）：`1.7`/`1.6` 等其它判据若将来也需要基线豁免，应复用同一 helper 而不是各自读 JSON。
