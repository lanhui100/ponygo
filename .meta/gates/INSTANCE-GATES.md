# 实例门登记（本仓自有；不属框架骨架文件）

> 为什么单独一个文件：`.meta/gates/README.md` 在 ponygo 的 `UPGRADE_UNIVERSE` 内（框架骨架文档，
> 逐字节锁定），往里追加实例门会让 `ponygo upgrade --check` 长期报漂移。框架 README 只登记 A1–A9；
> 实例门与「承诺 → 命令」写在这里，既不制造骨架漂移，也不把门禁藏进无人看的地方。
> 既有实例门 `scratch-hygiene.sh` 的登记仍在 `.meta/gates/README.md`（框架自用 dogfood 的一部分），
> 本文件只登记**此后新增**的实例门——这是锁定骨架带来的登记面分裂，不是两份真源。

## 门与负样本 spec 配对

| 门 | 脚本 | 负样本 spec | 接线 | 退出语义 |
|---|---|---|---|---|
| backlog 账本门（v3 批次日志） | `.meta/gates/backlog-gate.sh` | `.meta/gates/backlog-gate.spec.sh` | `.githooks/pre-commit`（哨兵块之外）+ `.github/workflows/ci.yml` 的 `governance` job（门与 spec 各占独立 step）+ `ponygo audit --run-specs` | 0 放行 / 非零拒绝；v2 过渡账本 → 只读兼容 + NOTE；账本缺失 → 明确跳过；布局不一致（有 `log/` 缺 `MODEL`）/ 未知模型 / 无 `node` → fail-closed |

## 承诺 → 非零退出命令

| 承诺 | 命令 | 命中判据 |
|---|---|---|
| 账本记录合法且跨归档/租约对账干净、归档未被篡改 | `bash .meta/gates/backlog-gate.sh` | `lint`（批次头匹配文件名/事件白名单/批内时间单调/同 ID 不重复 record·resolve/`done` 必带 evidence+closed_at/`in_progress` 必带 owner+paths/租约-状态互斥/ID 全账本唯一）+ `doctor`（跨活跃·归档·v2 遗留归档的 ID 与租约对账）+ `verify-archive`（归档批次 sha256 封存清单） |
| 门自己会拒绝非法样本 | `bash .meta/gates/backlog-gate.spec.sh` | P1 v3 单批次放行 + P2 双批次并集放行 + P3 v2 过渡只读放行 → N1 首行非 batch.start / N2 未知事件 / N3 v2 缺 fingerprint / N4 归档被改动 / N5 归档未入清单 / N6 锁存而记录非 in_progress / N7 有 log 缺 MODEL / N8 无 node → 全拒 + H（门在场放行、门缺失 fail-closed）；自报 `##SPEC asserts=14 rejects=9` |
| 提交窗口内账本不劣化 | `bash .githooks/pre-commit`（门缺失 → 拒绝提交） | 同上（本地层；`--no-verify` 可绕过，CI 兜底） |
| 远端层兜底 | `ci.yml` 的 `governance` job：`bash .meta/gates/backlog-gate.sh` 与 `bash .meta/gates/backlog-gate.spec.sh` 两个独立 step | 同上（CI 不以 `--no-verify` 参与） |

## 契约与真源

- 可读契约：`backlog/README.md`（布局/批次事件/状态机/租约/归档/命令/迁移/本地化差异）
- 判定真源：`scripts/backlog.mjs`（`validateTask` / `lintV2` / `lintV3` / `fold` / `doctor` / `verifyArchive`）
  ——本目录脚本只编排，不复刻判据
- 迁移工具：`scripts/backlog-migrate-v2-v3.mjs`（整库迁移 + `--adopt-v2` 在途分支接管；对账失败自动回滚）
- 与 skill 模板的差异（刻意如此，模板≠本仓真源）：spec 的 H 夹具不依赖 `scripts/git-guard.mjs`；
  spec 补 `##SPEC asserts=/rejects=` 计数行以满足本仓 spec 运行时契约（GH12/T-U4-1）
- 诚实边界：spec 只证明「门会拒非法样本」；账本内容真实性靠 review。`doctor` 不解析 git 历史，
  无法识别「同时改记录与批次头」的伪装。
- 本地钩子前提：`git config core.hooksPath .githooks`（git 不克隆该配置）。未装配时本地门禁静默失效、
  CI 仍兜底——这是 git 的机制限制，不是门禁缺陷。
