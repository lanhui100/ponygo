# Agent Note: ponygo 植入效果审计（2026-11-17）与升级接线提案

Status: proposed

## Problem

ponygo 已在 15 个实例仓植入（`.meta` 骨架 + ADR 门 A1/A2 + 全树门 A4/A5 + 归档封印 A6/A7 +
零残留 A8/A9 + 常载命约投影 + 文档分层），但**没有任何机制回答"植入之后它还在起作用吗"**：
框架假设"门装上了就会拦住违例"，实例假设"CI 绿就等于治理健康"。本轮用会话归档 + 逐仓收据 +
只读反例做了首次植入效果审计，发现三类错漏：

1. **判定面有假放行（P0）**：实例 CI 只跑 `ci-verify.sh`，而 2.1/2.4/2.5/2.6 只在 `ponygo status`
   里判 —— 实测 7 仓「CI 绿 / status 红（2.1 门资产漂移）」，且 `maturity-ladder.md:153` 明文声称
   "CI 的 `ponygo audit --run-specs` 步（A5 workflow 步骤 ②）"存在，与实际模板
   （`ponygo:5668-5684` 只有一行 `ci-verify.sh`）矛盾；`adr-verify.sh:59-65` 在 A6 缺失时静默
   `return 0`，删掉一个文件即可让归档封印从提交窗口中消失。
2. **出厂即红 → 绕过成为理性选择**：ponyllm `verify-note.sh` exit 1（48 条存量 ADR 债），
   会话 `4108a85a` 的 agent 因此用 `--no-verify` 提交并 push；框架没有存量豁免/清零路径。
3. **绕过语义不统一**：`drift-strict.sh:188` 的 env-skip 只打印一行（无持久痕迹），而同一框架
   自带的 `git-flow-gate` 写 `bypass.log` —— cluster-infra 生产合并即走了无痕那条。

行为面证据同时说明**治理是有效的**：11-10～11-17 的 615 个会话里，有提交的 49 个会话中
80% 提交前跑过门禁、76% 跑过测试；门禁调用 2127 次 exit 0 占 97.3%；出现"红相先冻结""独立
验收抓出变异假绿"等主动治理行为。**缺口是接线与诚实面，不是机制不够多。**

相邻决策（非同源、未取代）：`implemented/process/2026-11-11-p0-anti-entropy-fixes.md`（框架自审的三条断点，已修「门与负样本可被同时掏空而无观测者」；本轮的 U1 是同一病灶在**实例侧 CI** 的残留）、`implemented/process/2026-11-10-gate-negative-evidence-hardening.md`（负样本执行与聚合证据加固；本轮 U4/U5 是它未覆盖的"零断言 spec"与"结论行诚"两面）。两条均无需归档或改写，本提案不取代其任何判据。

## Proposal

分三批，只做"把已有承诺接上线"的最小闭环（完整证据与验收命令见
`docs/dev-team/reviews/2026-11-17-qms-implant-effect-audit.md` §3/§4）：

1. **P0 堵假放行**
   - U1：A5 模板加判据面步骤（`ponygo status` 或 `audit --run-specs`，模板自带 CLI 定位，
     缺失则 SKIP + WARN），同批修正 `maturity-ladder.md:153` 的 A5 口径。改 A5 = 实例可编辑文件，
     不动不可变资产。
   - U2：`archive_probe` 在 A6 缺失时 fail-closed（打印 + 非零），与 `ci-verify.sh:65-67` 对齐。
     改 A1 = 不可变资产 → 必须同批改 `ponygo` heredoc、仓库副本与 `adr-verify.spec.sh` 负样本。
2. **P1 治存量债与绕过语义**
   - U6：`ponygo adopt` 基线棘轮 —— 存量违例冻结进带到期日的 manifest，门只拦新增；
   - U7：逃生口统一落 append-only bypass ledger（who/when/why/gate），并接入审计面；
   - U3：A1 的 `--diff-filter` 加 `D`，删除决策记录须同提交 simplification note（1.11 已锁形状）；
   - U8：`init` 写 `.meta/.ponygo-seed`（框架 commit + 17 文件 sha，机器写入），
     `upgrade --check` 分类 `stale`/`unknown`，消除 upgrade cliff。
3. **P1/P2 诚实面与平台面**：U5（结论行不再在 1.10 未判定时写"通过"、`miss_ids` 覆盖 hits<total）、
   U4（spec 输出机读计数，`rejects≥1` 才算过）、U9（补 `no-residue.manifest`，不让 A8 空转）、
   U10（rg 分支加 `--no-ignore`，与 grep 退化路径同判）。

**落地进度**：W0（U6→B012、U8→B015）与 W1（U1→B010、U2→B011）已于 2026-11-17 落地并闭环，决策记录见
`.agents/notes/implemented/process/2026-11-17-baseline-ratchet-and-seed-provenance.md` 与
`.agents/notes/implemented/process/2026-11-17-ci-judge-surface-and-a6-fail-closed.md`
（`upgrade adopt` 位置模式 + `.meta/notes-baseline.json` + `.meta/.ponygo-seed`；A5 判据面步骤 + A6 缺失 fail-closed）；
本提案继续承载 W2/W3 余项（U3/U4/U5/U7/U9/U10）。

backlog 账本已登记对应待办：U1→B010、U2→B011、U6→B012（已闭环）、U7→B013、U3→B014、U8→B015（已闭环）、U5→B016、U4→B017、U9/U10→B018。

每一项的验收都是**非零退出命令**，不接受"改完看起来对"：如 U2 的
`rm .meta/gates/archive-verify.sh && bash .meta/gates/adr-verify.sh; [ $? -ne 0 ]`。

## Alternatives considered

1. **不升级，只用 review 兜**——落选：7 仓「status 红 / CI 绿」是机械可判的假放行，review 抓不到
   逐仓逐判据的漂移；A6 缺失 fail-open 的那次实测连一行提示都没有，靠自觉等于没有守卫（P2）。
2. **加更多机制（新增判据、再写一套门）**——落选：审计显示机制数量不是瓶颈，缺口全在"承诺→
   命令"的接线（U1/U2 都是已有承诺未上线）与负空间债务（存量债、空转门）。按 P8/P9，加机制
   只会在已有维护税上再加一层。
3. **把门资产一次性同步到所有实例（直接跑 `upgrade apply`）**——落选：治标且危险——它会一次性
   覆盖实例侧可能的本地弱化证据，而 upgrade cliff（U8）未解，下次框架升级又会全红；且本轮审计
   约束是只读，不能改被审仓。
4. **把 1.10/1.11 也在 CLI 里实现一份，让 status 全判**——落选：`maturity-ladder.md:155` 已按 P9
   拒绝（一份判据一份实现，两份必然漂移）。解法是 U1/U5（把门接进 CI + 结论行诚实），不是复制判据。
5. **本轮选定方案**：接线优先的小批升级（上文 U1/U2 先做，其余进 backlog 排期），并**同批**修正
   文档口径（ladder:153）与负样本证据，避免用新文档掩盖旧缺口。

## Acceptance criteria

- U1：`cd /tmp/x && ponygo init && grep -q 'ponygo status' .github/workflows/ponygo-governance.yml`；
  删掉该步后 `tests/run.sh` 应红。
- U2：`rm .meta/gates/archive-verify.sh && bash .meta/gates/adr-verify.sh; [ $? -ne 0 ]`；
  `bash .meta/gates/adr-verify.spec.sh` 全绿（新增负样本覆盖"缺 A6 → 必须拒"）。
- U6：`ponygo adopt` 生成的 baseline manifest 在存量债仓（ponyllm）上让 A1 绿、且新增违例仍红。
- U7：任一逃生口放行后 `git-dir/ponygo-gate/bypass.log` 必有对应行（含 gate 名与理由）。
- U3：`git rm .agents/notes/implemented/process/x.md && bash .meta/gates/adr-verify.sh; [ $? -ne 0 ]`。
- U8：`cd /tmp/x && ponygo init && test -s .meta/.ponygo-seed`；`upgrade --check` 每项漂移带
  `stale`/`unknown` 分类。
- U5/U4/U9/U10：分别以 `status` 结论行不含"通过"、`audit --run-specs` 拒绝零断言 spec、
  `no-residue.sh` 在框架仓非"跳过"、两分支同判为验收。
- 全部改动入册：每次实施提交携带对应 ADR（proposed → implemented），并同批更新
  `.meta/gates/README.md` 与 `maturity-ladder.md` 的口径。

## Risks

1. **改 A1 触发实例 A2 红**：U2 改 A1 后旧实例的 `adr-verify.spec.sh` 自检会因字节漂移红——
   须与 U8 一起做（seed 分类 + 升级路径），否则"修一个缺口换来一片红"。
2. **U6 基线棘轮被滥用**：manifest 可能变成"合法冻结所有债"的停车场——须带到期日与计数看板，
   到期未清零转红（否则是假门禁）。
3. **U1 在实例无 CLI 时形同虚设**：模板必须显式 SKIP+WARN 而不是静默通过，且 U8 提供版本可追溯，
   否则"CI 有这一步"本身会变成新的虚假安全感。
4. **治理成本感知**：审计样本 1 显示存量红会直接诱发绕过；若 U6 不先做，U1 上线后实例 CI 会变红
   并加剧绕过。**顺序不可颠倒**：U6 → U1 → U2。
5. 本轮只做审计与提案，不改被审仓、不跑 `upgrade apply`；"同步后是否仍红"留给实施轮验证。
