# Agent Note: 审计判据改为 fail-closed（F1–F7 修复集）

Status: implemented

## Problem

两次 ponygo 运行会话的轨迹审计（`docs/dev-team/reviews/review-2026-11-01-ponygo-session-audit.md`）
暴露出一组**判定与声明不一致**的缺陷，核心是「未验证被当成验证通过」：

1. `ponygo audit --run-specs` 的执行判据**结构性空转**：`run_gate_specs` 向 spec 注入
   `PONYGO_IN_SPEC=1`，而框架唯一交付的 A2 spec 在该变量下直接 `SKIPPED; exit 0` →
   opt-in 执行判据永远「未真正跑门」。真实缺口只能靠绕过 CLI 手工跑 spec 才发现。
2. 即使 SKIPPED，结论行仍写「L0-L2 机械判据全部 PASS」、命中仍 14/14、exit 仍 0——
   「SKIPPED 不计入 PASS」只是一句文案，没有任何判定后果（同一屏内自相矛盾）。
3. `ponygo upgrade` 对缺失骨架文件提示「跑 'ponygo init' 补全」，而 `init` 在 `has_meta`
   分支明确不重铺骨架 → 闭环指引是死循环；`status` 同时报「骨架完整」且 exit 0，
   与 `upgrade` 的「缺口 N」对同一实例结论相反。
4. M 档「负样本 spec」判据用全仓 `*.spec.ts / *_test.go …` 匹配，把普通单测算成
   「门会拒绝非法样本」，白送一分且与判据 2.3 的 `gates/*.spec.*` 口径冲突。
5. 文案硬伤：未传 `--level` 也输出 `below_target`（硬编码「--level 断言」）；零缺口仍打印
   「缺口与最小改进动作」空标题；`init --dry-run` 承诺「创建 + chmod +x」而实跑走
   「沉睡钩子不改权限」；输出引用实例中不存在的 `checklists/audit.md` / `maturity-ladder.md`。
6. A4 资产双写纪律已破：`ponygo` 内 `ci-verify.sh` 的 heredoc 落后于仓库文件
   （仓库已加 scratch-hygiene 两步），既有测试恒红；且 `ponygo init` 会用落后的
   heredoc **自愈覆盖**，等于静默删掉仓库里的一个门禁步骤。

## Decision

1. **执行判据 fail-closed**：`run_gate_specs` 不再向 spec 注入 `PONYGO_IN_SPEC=1`，改注入
   深度变量保证第一层真跑；若 `--run-specs` 最终没有任何 spec 被真正执行（0 个 / 全部自报
   SKIPPED / 递归护栏拦截），`audit` 退出码为 **3（证据不足）**，且结论行禁止出现
   「机械判据全部 PASS」。判定优先级：**FAIL(1) > 未验证(3) > 通过(0)**。
   不带 `--run-specs` 时行为不变（2.3 仍是形状判据，exit 0/1）。
2. **骨架缺口补全并入 `init`，不开新命令**：`ponygo init --repair-skeleton` 按
   `UPGRADE_UNIVERSE` 从 `write_skeleton` 模板**只补缺失**、绝不覆盖已存在文件；
   `upgrade` 与 `status` 的缺口指引一律指向该旗标。`status` 增加骨架文件口径（有缺失 → exit 1）。
   依据 `2026-08-30-six-command-surface.md`：新能力并入现有命令，不加命令。
3. **M 档负样本判据收窄**到 `.meta/gates/*.spec.*`（与 2.3 同口径），总项数仍 14；
   且**框架交付的 spec 资产不计分**（A2 等）——与 ② 既有的「框架侧证据不计分」同源，
   否则每个新实例白送一分、四问失去区分度。实例自建 `gates/*.spec.sh` 才 +1。
4. **文案/语义与实跑对齐**：`below_target` 仅随显式 `--level` 出现；零缺口不打印缺口标题；
   `--dry-run` 与实跑走同一判定分支；实例侧输出不再引用框架仓独有文件（改 URL 形态）。
5. **A4 heredoc 与仓库文件重新逐字节同步**（EOL 归一口径），恢复双写纪律。A4 回到
   **两步**（全树 ADR 格式 + 负样本 spec 自检）；本仓的 scratch-hygiene 门改为挂在本仓
   `.github/workflows/ponygo-governance.yml`（A5 属实例可编辑、不进 `UPGRADE_UNIVERSE`）
   的独立 step 上。否决"存在资产才跑该门"的守卫式挂载：那等于把门禁做成可选——删一个文件
   即整段消失且 rc=0，末行仍宣称门跑过。也否决把 `scratch-hygiene.sh/.spec.sh` 提升为
   框架资产随 `init` 交付：那会让所有既有实例在下次 `init` 后新增 E1/E2/E3 检查
   （E2 要求 `.gitignore` 声明 `.scratch/`），属跨仓破坏性变更，超出本轮闭包。
6. `tests/run.sh:1262` 的旧断言「无 .sh spec → exit 0」按契约演进改为 exit 3：
   该断言固化的正是本次要修的 P0-2（SKIPPED 无判定后果）。护栏载体由 `PONYGO_IN_SPEC`
   迁移到 `PONYGO_AUDIT_SPEC_DEPTH`（`②b` 同批演进），因为 `PONYGO_IN_SPEC=1` 表示
   「已在 spec 内」，而 audit 作为父进程并不在 spec 内——旧断言固化的正是 P0-1。
7. **`init --repair-skeleton` 只做骨架补缺**：不触发电缆装配（`ensure_gate_wiring`）、
   不写适配任务书、不投影 AI 常载命约——否则"只补不覆盖"的承诺会被随后的
   `gate_asset_put` 自愈覆盖推翻（实例加固过的 A1/A2 被静默回滚），且输出自相矛盾。
8. **0 字节 `*.spec.*` 不计入任何判据**：既不计 2.3 形状、不计 M 档负样本分、不计
   「gates/ 有实质门禁」，`--run-specs` 对 0 字节 spec 直接判 FAIL——空文件证明不了任何
   拒绝语义，把它当通过正是本次要消灭的"未验证即通过"。

## Alternatives considered

- **保持 SKIPPED = exit 0，仅改文案**：否决。文案已经写着「不计入 PASS」，问题不在措辞而在
  没有判定后果——不动退出码就等于把缺陷留在原地。CI 只读退出码，读不到那句注脚。
- **用 exit 1 表示「未验证」**：否决。exit 1 已被「有缺口/未达标」占用，混用会让 CI 无法区分
  「门不合格」与「门没跑」；沿用 observe 子域已有的 `3=证据不足` 语义更一致。
- **`--run-specs` 默认开启**：否决。本 CLI 的设计约束是「判定优先只读」，执行陌生仓库脚本
  必须 opt-in；本次只修「opt-in 之后假装验证过了」。
- **新增 `ponygo repair` 独立命令**：否决——违反 `2026-08-30-six-command-surface.md`
  「新能力的默认处置是并入现有命令或拒绝」；且 `init` 本就是骨架铺写与幂等装配的唯一入口，
  旗标形态（`--repair-skeleton`）闭包更小、文档三处口径只需补一个旗标。
- **让 `init` 默认重铺缺失骨架**：否决。`init` 对既有 `.meta` 实例承诺「不重铺骨架、既有文件
  一字不动」，默认改写会让「跑一次 init 修修补补」变成隐式副作用；只补缺必须是显式旗标。
- **本轮一并做 `ponygo observe probe`（受控探针 + 证据溯源）与「AI 常载命约投影」L2 判据**：
  否决（延后，另立项）。前者要动 `observability-onboarding` 的技能契约，后者会给既有实例
  新增 FAIL 判据——两者都不是本仓内可闭环的改动，须跨仓灰度。

## Consequences

- CI 侧新增一种合法退出码 `3`（证据不足）：流水线必须区分 `1`（门不合格）与 `3`（门没跑），
  只写 `!= 0 即红` 的用法仍安全（fail-closed），但报错信息应分别处理。
- 本仓 dogfood 位置：`ponygo audit --run-specs` 从此**真的**执行
  `.meta/gates/adr-verify.spec.sh` 与 `.meta/gates/scratch-hygiene.spec.sh` 两个 spec，
  任一失效将直接红 —— 执行判据不再是可以靠护栏绕开的空转。
- **跨实例语义变化（必须点名）**：`status` 由「骨架完整 → exit 0」变为「骨架文件缺口：N →
  exit 1」。只在骨架文件确实缺失的实例上触发（齐全实例不变），但这类实例此前的绿是假绿；
  若某实例 CI 因此转红，正确处置是补骨架（`ponygo init --repair-skeleton`）而非放宽判据。
- **CI 执行面**：本仓 A5 增加 `bash ponygo audit --run-specs` 一步，使 `exit 3` 真正可达
  （此前仓内没有任何 CI 步骤会跑执行判据，3 这个码等于没有执行面）。
- 观察（本轮不修，已另记 backlog）：`observe` 作为治理维度入口使顶层命令词实态为七个，
  与 `2026-08-30-six-command-surface.md` 的「六条」表述已漂移。本次只保证**不新增**
  命令词（冻结验收断言即按「命令词集合相对基线不变」而非「恰为六条」判定）。
