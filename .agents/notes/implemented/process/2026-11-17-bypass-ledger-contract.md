# Agent Note: 逃生口留痕的唯一路径与格式（+ audit 观察面）

Status: implemented

## Problem

审计抓到"同一框架内两套绕过语义"：`drift-strict.sh` 的 `PONYGO_DRIFT_STRICT_SKIP=1` 只往 stdout 打一行、
**无持久痕迹**；而同框架自带的 `git-flow-gate.sh` 却写 `bypass.log`（who/when/why）。后果是
"绕过"这件事没有稳定的观测面——事后复盘时，一次紧急发布到底绕了哪道门、为什么绕，只能靠翻会话日志。

## Decision

1. **路径唯一**：`<git-common-dir>/ponygo-gate/bypass.log`（`git rev-parse --git-common-dir` 解析；
   非 git 仓 = 不存在）。与既有 `git-flow-gate` 写的位置一致，不另起第二处。
2. **格式唯一**：JSONL，一行一次放行事件，键 `ts`（必填）/ `gate`（必填）/ `why`（必填，非空理由）、
   可选 `commit`/`owner`；追加-only。多出其它键不算错（向前兼容），缺任一必填键 = 该行格式不合法。
3. **可见性**：`ponygo audit` 在判据明细之后、结论行之前打印一行（仅当 ledger 存在且非空）：
   - 全部合法：`逃生口留痕：N 条（最近 <ts> <gate>：<why 前 40 字>）`
   - 含非法行：`逃生口留痕：N 条，其中 M 条格式不合法（按 gates/README 的格式修复：ts/gate/why 三键必填）`
   - **不改任何退出码、不改 `--json` 词表**（JSON 消费者看不到该行）。
4. **文档**：`.meta/gates/README.md` 新增「逃生口留痕（bypass ledger，非门禁）」小节，写明路径/格式/示例行/
   "凡逃生口放行前必须追加一行"/诚实条款："理由是否成立属语义判断（P6），门只能看到『有没有字』"。

## Alternatives considered

- **新增门禁资产 A10 `bypass-ledger.sh`（写入器 + `check` 子命令）**：本批否决——没有消费者时先造一个
  "框架担保"的写入器只是新的维护税（P9）；且把它挂进 `OPTIONAL_UNIVERSE` 会让每个实例的门禁计数、
  `status` 的可选资产行、`upgrade --check` 的缺口口径同时漂移（收益是一个 `printf` 就能完成的事）。
  等出现第二个需要写入器的门时再资产化，届时按 L3「同一流程第三次重复」判据推进。
- **把留痕做成门禁（缺 entry 即拒）**：否决——"绕过必须写理由"能被机械检查的只有"有没有字"，
  而"理由成立不成立"是语义判断；做成门就是假门禁（P6）。可见性 + review 才是这类承诺的正确守卫。
- **把 ledger 放进仓库受控文件（如 `.meta/bypass.log`）**：否决——它记录的是**运行期**的放行事件，
  与提交内容无关；放进受控树会污染 diff、并诱导"为了提交而写理由"。
- **同时改 `drift-strict.sh` 让它写 ledger**：本批不做——那是实例门（不在框架仓），
  契约先钉死路径/格式，实例侧按契约迁移（登记在提案 ADR 的 U7 项）。
- **`audit --json` 加 `bypass` 字段**：否决——`ponygo.audit/1` 的字段词表已冻结（多套测试用集合相等断言），
  加字段须与测试同批，属另一批契约变更。

## Consequences

- 绕过从"口头/日志里的传说"变成一条可数、可查的本地记录：`audit` 一行即可看到"这个仓最近绕过过几次"。
- 局限（诚实登记）：① 写入靠各门自觉（本批不提供写入器）；② 只存本地 `<git-common-dir>`，
  不进仓库、不跨机器共享——审计面因此是"单机会话级"的；③ 格式判据是**形状判据**，
  一行里写"why: 就想绕"同样合法。
- 迁移成本为零：不新增资产、不改退出码；已有 `bypass.log` 的实例（如用过 git-flow-gate 的）
  下一次 `audit` 就会看见这条新行。

## 未覆盖（留下一批）

`drift-strict.sh` 等实例门仍在用"只打印不落盘"的 env-skip；把它们迁到本契约（写 ledger）是实例侧动作，
本仓只提供路径/格式与可见性。已在提案 ADR `2026-11-17-w3-migration-designs.md` 的 U7 项登记。
