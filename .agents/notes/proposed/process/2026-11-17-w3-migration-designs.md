# Agent Note: W3 三项（哨兵块 v2 / 逃生口 ledger / spec 运行时契约）的迁移设计

Status: proposed

## Problem

审计的 U4（零断言 spec）、U7（逃生口无痕跳过）、B020（删 A1 自身即摘掉判定）到 2026-11-17 仍未实施。
三项都卡在同一个东西上：**它们都要改"每个实例都有的东西"**——哨兵块字节、spec 输出契约、逃生口语义。
直接改会让全部实例在升级瞬间变红（重演"出厂即红 → 绕过"的病灶，见 W0 的成因分析），
而"灰度只在文档里说"又不构成机械承诺。故本提案把三项的**迁移策略**先定下来，实施按此执行。

## Proposal

1. **B020：哨兵块 v1 → v2，双接受灰度**
   - v2 canonical 块把现有 `if [ -f "$ROOT/.meta/gates/adr-verify.sh" ]; then … fi` 改成
     `then … || exit 1; else printf '[pre-commit] 拒绝：缺失 A1（不可判定 = fail-closed）→ 跑 ponygo init 补回' >&2; exit 1; fi`。
   - 判据（2.4 ④）同时持有 v1、v2 两份 canonical：v2 命中 = PASS；**v1 命中 = PASS + WARN**
     （"钩子为 v1，无『A1 缺失』fail-closed，建议重跑 `ponygo init` 升级"）；其余 = FAIL。
   - `init` 写钩子时把 v1 块**原子替换**为 v2 块（幂等：已是 v2 则不动）；实例可自行选择升级时机。
   - 验收：v1 钩子的实例 2.4 仍 PASS（不制造全红）；重跑 init 后变 v2 且 WARN 消失；
     `rm A1` 后 v2 钩子拒绝提交（v1 钩子放行——这正是 v1 的已知缺口，由 WARN 提示迁移）。
2. **U7：逃生口统一落 append-only bypass ledger**
   - 新增**可选**门资产 A10 `.meta/gates/bypass-ledger.sh`（`log --gate <名> --why <理由>` / `list` /
     `check`）：写 `<git-common-dir>/ponygo-gate/bypass.log`（JSONL：`ts/gate/why/commit/owner`），
     只追加、不重写；`check` 校验每行 schema。
   - 约定（写进 `.meta/gates/README.md`）：**凡门禁提供逃生口（env-skip / `--no-verify` 等价物），
     放行前必须调 `bypass-ledger.sh log`**；框架不把它设为必装（没有逃生口的实例不需要它 =
     不制造空仪式，同 W2b 的 U9 裁决）。
   - `ponygo audit` 观察项：若存在 bypass.log，打印一行「逃生口留痕 N 条（最近 <ts> <gate>）」；
     不改退出码。
   - 验收：`log` 后 `list` 可见、`check` exit 0；手工截断一行 → `check` 非零；无 ledger 的实例零噪音。
3. **U4：spec 运行时契约（灰度）**
   - spec 结尾输出机读行 `##SPEC asserts=<n> rejects=<n>`；`run_gate_specs` 解析：
     - 有该行且 `rejects≥1` → 通过；
     - 有该行且 `rejects=0` → 判 FAIL（文案点名"没有拒绝断言"）；
     - **无该行（legacy spec）→ 本轮 WARN + 计入"legacy"计数，仍按退出码放行**；
       下个大版本（v3）起转为 FAIL。
   - 框架自带的 5 个 spec（A2/A7/A9/scratch-hygiene/backlog-gate）**本轮**就补该行，作为校准样例。
   - 验收：零断言假 spec（`if false; then exit 1; fi` + `echo`）在本轮 WARN 且下轮 FAIL 的灰度表可查；
     自带 5 spec 输出该行且 self-check 绿。
   - 为什么灰度而不是立即 fail：立即 fail 会把所有写过 spec 的实例（含其 CI）打红，而"spec 质量"
     属可逐步收紧的语义面；WARN 期给出迁移窗口与机械文案，比一次性破门更符合"转起来再完美"。

## Alternatives considered

- **三项一起破门（不做灰度）**：否决——与 W0 的成因分析直接冲突：一次发布让全实例变红，
  唯一理性反应是绕过；灰度不是妥协，是把"迁移成本"显式化。
- **B020 直接换 v1 语义（保持 marker v1、改块字节）**：否决——块字节是 2.4 的判据原子，改它等于让
  全部实例 2.4 立刻 FAIL；版本化 marker 才能区分"旧"与"错"。
- **U7 把 ledger 设为必装资产**：否决——没有逃生口的实例（大多数）会多一个永远空转的门，
  正是 W2b 判为"空清单仪式"的同款反模式。
- **U4 立刻要求 rejects≥1**：否决——同上（实例的 spec 会一次性打红），且"零断言 spec"与"没写 spec"
  应给不同处置：前者是质量问题（灰度收紧），后者已由 2.3 硬判。
- **U4 用"spec 必须在 5 秒内跑完并打印 ≥3 行"之类替代判据**：否决——行数不是拒绝证据，
  与审计抓到的"横幅可伪造"同源。

## Acceptance criteria

- B020：v1 实例 2.4 PASS+WARN；`init` 升级后 v2；`rm A1` 后 v2 钩子 exit 1；既有 s58–s70 全部迁移后绿。
- U7：ledger 三子命令与 schema 校验可复现；audit 观察行只在 ledger 存在时出现；A4 不因缺 ledger 变红。
- U4：框架 5 spec 输出 `##SPEC` 行；灰度表（本轮 WARN / v3 FAIL）写入 `maturity-ladder.md` 与
  `.meta/gates/README.md`；零断言 spec 的处置可被 `audit --run-specs` 输出复现。

## Risks

1. 灰度期可能被当作"已完成"——须在文档里写死到期版本（v3），并让 `audit` 输出 legacy 计数。
2. B020 的 WARN 若被忽略，v1 钩子的缺口会一直存在；A4 远端仍能兜住，本地层缺口属已声明风险。
3. U7 的 ledger 只证明"有人写了理由"，不证明理由成立（P6 盲区，靠 review）。
4. 三项都改动实例侧常用文件，实施时必须逐项独立 PR/提交 + 独立回归，不做捆绑发布。
