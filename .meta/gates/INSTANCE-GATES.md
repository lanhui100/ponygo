# 实例门登记（本仓自有；不属框架骨架文件）

> 为什么单独一个文件：`.meta/gates/README.md` 在 ponygo 的 `UPGRADE_UNIVERSE` 内（框架骨架文档，
> 逐字节锁定），往里追加实例门会让 `ponygo upgrade --check` 长期报漂移。框架 README 只登记 A1–A9；
> 实例门与「承诺 → 命令」写在这里，既不制造骨架漂移，也不把门禁藏进无人看的地方。
> 既有实例门 `scratch-hygiene.sh` 的登记仍在 `.meta/gates/README.md`（框架自用 dogfood 的一部分），
> 本文件只登记**此后新增**的实例门——这是锁定骨架带来的登记面分裂，不是两份真源。

## 门与负样本 spec 配对

| 门 | 脚本 | 负样本 spec | 接线 | 退出语义 |
|---|---|---|---|---|
| backlog 账本门 | `.meta/gates/backlog-gate.sh` | `.meta/gates/backlog-gate.spec.sh` | `.githooks/pre-commit`（哨兵块之外）+ `.github/workflows/ci.yml` 的 `governance` job + `ponygo audit --run-specs` | 0 放行 / 非零拒绝；账本缺失 → 明确跳过；无 `node` → fail-closed |

## 承诺 → 非零退出命令

| 承诺 | 命令 | 命中判据 |
|---|---|---|
| 账本记录合法且跨归档/租约对账干净 | `bash .meta/gates/backlog-gate.sh` | `lint`（必填字段/条件必填/状态字段合法性/租约-状态互斥/活跃池 done 残留/ID 唯一/高水位）+ `doctor`（ID 重复/高水位/孤儿租约/租约-状态互斥） |
| 门自己会拒绝非法样本 | `bash .meta/gates/backlog-gate.spec.sh` | P1 放行 + P2 编号下限 B001 + P3 真实操作闭环（record→start→resolve）+ P4 实例级在场（本仓 tasks.jsonl / .next-id / CLI 存在，防「删账本 → 门静默跳过」）+ P5 接线静态断言（CI governance 与 pre-commit 真调本门 + fail-closed 分支）+ N1–N8（缺 fingerprint / 活跃 done / 孤儿租约 / 高水位越界 / 无账本跳过 / 无 node 拒绝 / 锁存而记录非 in_progress / record 缺 --fingerprint）+ H/H2（门在场放行、账本非法被拒且证据来自门本身、门缺失 fail-closed） |
| 提交窗口内账本不劣化 | `bash .githooks/pre-commit`（门缺失 → 拒绝提交） | 同上（本地层；`--no-verify` 可绕过，CI 兜底） |
| 远端层兜底 | `ci.yml` 的 `governance` job：`bash .meta/gates/backlog-gate.sh && bash .meta/gates/backlog-gate.spec.sh` | 同上（CI 不以 `--no-verify` 参与） |

## 契约与真源

- 可读契约：`backlog/README.md`（布局/字段/状态机/租约/归档/命令/迁移）
- 判定真源：`scripts/backlog.mjs`（`validateRecord` / `lint` / `doctor`）——本目录脚本只编排，不复刻判据
- 诚实边界：spec 只证明「门会拒非法样本」；账本内容真实性靠 review。`doctor` 不解析 git 历史，
  无法识别「同时改记录与高水位」的伪装。
- 本地钩子前提：`git config core.hooksPath .githooks`（git 不克隆该配置）。未装配时本地门禁静默失效、
  CI 仍兜底——这是 git 的机制限制，不是门禁缺陷。
