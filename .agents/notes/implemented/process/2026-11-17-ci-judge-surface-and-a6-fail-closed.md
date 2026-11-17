# Agent Note: 实例 CI 补判据面（A5 步骤 ②）与 A6 缺失 fail-closed

Status: implemented

## Problem

2026-11-17 植入效果审计在判定面抓到两条 P0 假放行（
`docs/dev-team/reviews/2026-11-17-qms-implant-effect-audit.md` §3 的 U1/U2）：

1. **实例 CI 不判判据面**：A5 模板只跑 `bash .meta/gates/ci-verify.sh`（A4）。而 2.1（门资产与模板
   逐字节一致）、2.4（本地钩子真接线）、2.5（文档分层）、2.6（常载命约投影）只在 `ponygo status`
   的 `verify_ladder` 里判——实测 7 个实例仓「CI 绿 / status 红」。更糟的是
   `maturity-ladder.md` 的 1.9b 归属条曾把口径写成「CI 的 `ponygo audit --run-specs` 步（A5 workflow 步骤 ②，故 CI 侧实际有看守）」，
   文档声称的看守在交付物里根本不存在。
2. **A6 缺失即 fail-open**：A1 的 `archive_probe` 是 `[ -f "$ARCHIVE_GATE" ] || return 0`——删掉
   `.meta/gates/archive-verify.sh` 一个文件，归档封印就从提交窗口里消失，且连一行提示都不打
   （实测：A6 在场时篡改归档件 exit 1，删掉 A6 后同样篡改 exit 0）。

## Decision

1. **A5 模板加判据面步骤**（`ci_adapter_template()` 第 ② 步）：
   - 定位 CLI：`./ponygo` 可执行，或 `$PONYGO_BIN` 可执行；
   - 命中 → `bash "$CLI" status`（判据不符即非零，CI 变红）；
   - 未携带 CLI → `::warning::` + `exit 0`，文案逐字声明「判据面 2.1/2.4/2.5/2.6 未验证（这不是通过）」。
   - **只改模板**：`write_ci_adapter` 已存在即返回，故旧实例的 A5 不被覆盖——新步骤随实例重新生成 A5 生效
     （避免"一次发布全部实例 CI 变红"重演绕过，这也是 W0 先行给出的迁移路径）。
2. **A1 的 A6 缺失改为 fail-closed**：`archive_probe` 在 A6 缺失时置 `ARCHIVE_RC=2` 并写一行
   「拒绝：归档封印门 A6 缺失……不可判定 = fail-closed」，由 A1 末尾的 rc 收口为 exit 1——
   退出码仍是「0 放行 / 非零拒绝」两档，不新增档位。A2 负样本同批新增「删 A6 → 必须拒」用例。
3. **文档口径修正（同批）**：`maturity-ladder.md` 的 1.9b 归属那条不再声称「CI 侧实际有看守」，
   改为「A5 步骤 ② 是 `ponygo status`，条件于实例携带 CLI；未携带时只 WARN」；
   `.meta/gates/README.md` 的 A1/A5 行与「A6 的时序」末句同步改成 fail-closed 口径（此前写的是
   「门缺失时优雅回退」——那正是被审计抓到的 fail-open 的原话）。

## 审核修正（2026-11-17 独立对抗审核，verdict=PASS / 0 BLOCKING / 5 ADVISORY）

- **A6 被清空即绕过**（实测：`: > archive-verify.sh` → A1 rc=0）：fail-closed 只认"文件不存在"不够。
  修法：`archive_probe` 跑完 A6 后要求输出含「归档封印」判定标记，缺失即 `rc=2`（不可判定 = fail-closed）；
  A2 同批补「A6 清空」「A6 换成只 exit 0 的假门」两条负样本。
- **A5 编辑被误判为「人接手治理」**：`github_only_init_artifacts` 原以"逐字节等于模板"判定 init 所有权，
  A5 是文档明示的**实例可编辑**文件，模板一改就把存量实例的 `audit` 自动档从 S 抬到 M。
  修法：A5 分支只判存在、不比对模板（自建 workflow 仍判"人接手"，机制不削弱）。
- **`PONYGO_BIN` 手误静默变「未携带」**：拆两支 WARN——已设置但不可执行时点名实际取值，
  让配置手误在 CI 日志里可见（退出码仍 0，不改变"未验证 ≠ 通过"的语义）。
- **不修（登记 B020）**：A3 钩子的哨兵调用块用 `if [ -f A1 ]` 包裹，删掉 A1 自身仍静默放行。
  修它要改 canonical 哨兵块常量与其字节级断言（s58–s70），属同族 fail-open 的下一批。
- 审核亦确认：U1/U2 的两处 P0 已真实关闭（删 A6 后篡改归档件 = 非零；A6 删除后各入口一律非零，
  含真 `git commit` 被 A3 拒绝）。

## Alternatives considered

- **A5 未携带 CLI 时直接失败**：否决——存量实例多半没有 CLI（实测 pony-agent 连 `./ponygo` 都没有），
  会让一批仓库的 CI 立刻变红，重演"出厂即红 → 绕过"的病灶；先如实 WARN，等实例带上 CLI 再收紧。
- **A5 里 `curl` 安装 CLI**：否决——引入网络依赖、版本钉死与"CI 里跑远端脚本"的执行面，违背单文件零依赖。
- **把 2.1 的字节比对搬进 `ci-verify.sh`（A4）**：否决——A4 是不可变资产（本轮不动 A1–A9 之外的也不改 A4 字节），
  且会形成 CLI / 门两份判据实现（P9）。判据面交给携带 CLI 的步骤调用同一实现。
- **A6 缺失只打 WARN**：否决——删一个文件即可让封印整段消失，与"删除不是添加的逆操作"（P9）直接冲突；
  且 `ci-verify.sh` 对缺资产本就是 fail-closed，两层应同口径。
- **给 `adr-verify.sh` 新增退出码档位区分"缺 A6"**：否决——A3 钩子与既有消费者只理解 0/非零；
  加档位等于改公共契约而无收益。

## Consequences

- 新生成的 A5 能自证判据面；旧实例的 A5 要重新生成（删掉 `ponygo-governance.yml` 后跑 `ponygo init`）才带上新步骤。
- 删 A6 从"静默放行"变为"提交被拒"：这是有意的行为变更，实例若曾删过 A6 会立刻变红（正确行为，修法是 `ponygo init` 补回）。
- 残留风险（诚实登记）：未携带 CLI 的实例仍只有 WARN，判据面在那类仓里依旧只能靠人跑 `ponygo status`；
  本批不做 A5 的 `audit --run-specs` 步（需先解决 CLI 定位与"CI 里执行仓库脚本"的边界）。
