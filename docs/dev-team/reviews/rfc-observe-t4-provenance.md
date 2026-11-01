# RFC：observe 动态证据（T4）的来源绑定

状态：proposed（仅提案，**未修改** `observability-onboarding` 技能本体）
动机：两次 ponygo 会话审计（`docs/dev-team/reviews/review-2026-11-01-ponygo-session-audit.md` P1-5）实证——
`ponygo observe audit` 的 ob1/ob2 动态证据只判「Tempo 里存在任意一条该 service 的 span」，
会话 A 用一条**从集群 secret 里取 token 后手工 POST 的伪造 span**（`service.name=pony-agent`、
span 名 `agent.turn`）即把 ob0 刷成 ob2 PASS。判据无法区分「线上真实流量」与「一次性人工探针」。

本轮已做的（ponygo 侧，不改技能）：新增 `ponygo observe probe` —— 受控探针，provenance 属性固定为
`ponygo.probe=true` / `ponygo.probe.version=1`，token 只从 env 读、永不落盘、`--dry-run` 零网络。
它把会话 A 里「翻 k8s secret + 手写 curl」的 ~20 步取证压缩成一条命令，但**判据仍未绑定来源**。

## 提案（技能侧需要改的三处）

1. `scripts/check-declaration.sh` 的 T4 判定增加**来源分档**：
   - `provenance=probe`（span 带 `ponygo.probe=true`）→ `T4:PARTIAL`，结论文案改为
     「管线通（由受控探针证明），但**未观测到线上真实流量**」；
   - `provenance=runtime`（无 probe 标记且 resource 属声明 service）→ `T4:PASS`；
   - 无法判定来源 → `T4:UNKNOWN`（按 fail-closed，不进 PASS）。
   理由：现在的 T4 把「管线通」与「线上有流量」混成一个 PASS，正是本次审计要消灭的
   「未验证即通过」。
2. `references/contract.json` 增加 `tracing.probe_attribute` 键（默认 `ponygo.probe`），
   供上述判定读取，避免硬编码第二真值。
3. `references/declaration-rubric.md` §6.6 增一段：动态 PASS 的**最低证据标准**（时间窗、
   来源分档、探针不得作为 ob2 的唯一证据），并把「T4 只证明管线通」写进已知局限。

## 兼容性

- 纯增量：不删字段、不改既有退出码语义；未带 `ponygo.probe` 的既有正常流量仍是 `T4:PASS`。
- 影响面：所有用该技能的实例（job_copilot / ponyfun / pony-agent / pony-sentry 等）。
  建议先用 `--strict` 之外的口径灰度（默认沿用旧 PASS 语义，新增 `observe_provenance: on` 开关），
  待三仓观察一轮后再把 probe-only 降级为默认。
- 落地前提：技能目录**不是 git 仓库**（无回滚能力），改动前须先 `tar` 备份并跑
  `scripts/check-drift.sh` 的契约门；本 RFC 不含任何对技能目录的写入。

## 本轮不做

- 不改技能任何文件；`ponygo observe probe` 只负责**产出可识别来源的探针流量**。
- 不实现「探针可以冒充线上流量」的检测（需要服务端指纹，超出 CLI 能力）。
