# Agent Note: backlog 账本升级到 v3 批次日志（fold 现算 + 按批归档封存）

Status: implemented

Supersedes: `.agents/notes/implemented/process/2026-11-12-backlog-v2-onboarding.md`——本记录取代其
「单文件 JSONL 载体」决策（v2 的落地事实与三处本地差量取舍仍以该条为准）。

## Problem

本仓账本是 v2 单文件形状：`backlog/tasks.jsonl`（活跃池）+ `backlog/.next-id`（ID 高水位）+
`backlog/archive/tasks-<YYYY>.jsonl`（闭环滚动归档）。两个**并发会话只要都记账就必然撞同一处**：

- 同一文件的行尾（追加冲突、合并时人工挑行，容易丢行）；
- 同一 `next-id` 计数器（两个会话按同一高水位取号 → 撞号，过去只能靠「record 后立即提交 + 冲突人工合并」兜底）。

v2 的租约只保护「同一任务」，不保护账本追加——这不是纪律问题，是**载体形状问题**。同时 v3 还缺两件配套：
**归档只读封存**（现只有整体滚动归档，无逐文件 sha256 校验）与**门禁对 v3 形状的看守**（现门禁的负样本
P4/P5 断言的是 v2 尺寸：`tasks.jsonl`/`.next-id` 在场、CI 里 `gate && spec` 合并一行）。

## Decision

**把账本整库迁移到 v3 批次日志模型，并在同一提交内完成「载体 + 工具链 + 门禁 + 契约文档」四件事。**
迁移是**单提交**、可物理回滚、带条数对账；不做半迁移。

1. **载体**：写入单位 = 批次（`backlog/log/<batchId>.jsonl`，只追加、只写自己的批次）；读取 = `fold` 现算
   （活跃批次 + 归档批次 + v2 遗留归档三者并集，不落盘、不手改）。账本根 = **当前 worktree 顶层**
   （v2 的「git common dir 共享单文件」取消——那是撞车的来源）。
2. **工具链随仓**（禁止跨仓绝对路径调用）：`scripts/backlog.mjs`（v3 判定真源：`validateTask`/`lintV2`/
   `lintV3`/`fold`/`doctor`/`verifyArchive`）、`scripts/backlog-migrate-v2-v3.mjs`（整库迁移 + `--adopt-v2`
   在途分支接管）、`.meta/gates/backlog-gate.sh`（lint + doctor + verify-archive）、
   `.meta/gates/backlog-gate.spec.sh`（负样本自检）。
3. **ID 映射规则**：旧短 ID **原样保留**（`B001`…`B026` 不改号、引用写法 `backlog:B005` 不变）；新任务改用
   `B` + epoch 毫秒（13 位，仍匹配 `B\d{3,}`），跨会话按时间取号，天然不撞号。**不做新旧 ID 转换表**——
   转换会污染历史引用（提交信息、ADR、`source_ref`）。
4. **丢字段取舍**：v2 的 `.next-id` 高水位**随载体一起废弃**（v3 不再需要单调计数器）；`tasks.jsonl` 中
   已 `done` 的记录不复制进批次（它们本就在 `archive/tasks-2026.jsonl`，fold 并入），**不丢任何任务行**：
   迁移只搬「活跃池 1 条」（`B005`），26 条 done 留在 v2 遗留归档只读。`archived_at`/`leased_at`/
   `heartbeat_at`/`triage_context` 等既有字段一字不改。
5. **归档时机**：只归档「批次内任务全部 `done` **且随版本发布后**」的批次，动作 = 移入
   `archive/batches/<year>/` + 追加 `manifest.sha256` + 删 `log/` 原件；归档只读，`verify-archive` 抓篡改。
   未闭环批次不归档（本批 `legacy-migration` 承载 `B005` 仍 `todo`，故**不归档**，这是预期状态）。
6. **门禁接线**：`.githooks/pre-commit` 的 gate 调用保留在 ponygo-gate 哨兵块**之外**（块内必须逐字节等于
   规范块）；`ci.yml` 的 `governance` job 把门与 spec 拆成**两个独立 step**（`&&` 合并会把「门红」与
   「spec 红」糊成一个失败信号）；`core.hooksPath` 已是 `.githooks`（无需改）。
7. **与 skill 模板的两处刻意偏离**（模板 ≠ 本仓真源，写进 `backlog/README.md` 与 `INSTANCE-GATES.md`）：
   spec 的 H 夹具去掉 `scripts/git-guard.mjs` 前提（本仓 pre-commit 无此依赖，哨兵块自门控）；
   spec 补 `##SPEC asserts=14 rejects=9` 计数行（本仓 spec 运行时契约 GH12/T-U4-1 要求）。

迁移执行（可复跑）：

```bash
git tag backup/backlog-v2-20261122-2129
node scripts/backlog.mjs lint && node scripts/backlog.mjs doctor          # v2 上先转绿
node scripts/backlog-migrate-v2-v3.mjs --dry-run --surface legacy-migration
node scripts/backlog-migrate-v2-v3.mjs --surface legacy-migration
node scripts/backlog.mjs lint && node scripts/backlog.mjs doctor && node scripts/backlog.mjs verify-archive
git add backlog/MODEL backlog/log && git rm backlog/tasks.jsonl backlog/.next-id
```

## Alternatives considered

- **保持 v2 不动（继续用旧工具）**：技能明确允许存量仓不迁。否决理由：撞车是载体形状决定的，纪律无法补偿；
  且 v3 的「按批归档 + sha256 封存」与「批次为写入单位」正是本仓 §2.4/§4 想要的机械看守。成本 = 一次单提交迁移。
- **迁移时重编 ID（B001…→B<epoch>）**：否决理由：ID 是历史引用锚点（提交信息、`.agents/notes/` 的 ADR、
  `source_ref`、legacy md 任务单），重编等于制造一份必然漂移的映射表，收益只是「编号好看」。
- **保留 `.next-id` 作高水位、只把写入拆成批次**：否决理由：计数器是**单一共享写入点**，正是要消灭的撞车源；
  epoch 毫秒取号让「分配」退化为「生成」，无需协调。
- **把 done 记录也搬进迁移批次（一个批次装 27 条）**：否决理由：done 已有 v2 遗留归档承载，fold 会并入；
  重复搬运 = 同 ID 两处 record，`lint` 直接判「重复 record」，且把「活跃迁移」与「历史封存」混成一批，归档条件失真。
- **迁移后立即归档 `legacy-migration` 批次**：否决理由：该批承载 `B005`（`todo`），归档条件要求批内任务全 done；
  提前归档会让后续 `start/resolve` 无落点，只能开新批次补正——这正是「未闭环批次不归档」要防的。
- **CI 里继续用 `gate && spec` 单 step**：否决理由：一个失败信号无法区分「账本非法」与「门自己失效」，
  排障成本高于一行 YAML；且技能要求独立 step。
- **spec 逐字照抄 assets 模板**：否决理由：模板假设 pre-commit 无条件依赖 `scripts/git-guard.mjs`，本仓没有；
  照抄会让 H 夹具在 `cp` 处直接红（假红），且缺 `##SPEC` 计数行会让本仓 GH12 判 legacy spec。
- **用 `--adopt-v2` 走在途分支接管模式**：不适用——本仓 main 尚未 v3，接管模式要求目标已是 v3；那是给
  「已迁移后旧分支又带回 `tasks.jsonl`」的场景。

## Consequences

- **正面**：并发会话各写各的批次文件，合并零冲突；读取永远现算，不再有「落盘视图与真源不一致」；
  归档逐文件 sha256 封存，篡改被抓；v2 遗留归档仍只读并入历史，历史不丢。
- **代价 / 新增约束**：账本只经 CLI 改（手写事件会被 lint 抓）；一次会话只写自己的批次；
  `done` 是终态（回归要开新任务引用旧 ID）；`.state/batch` 是本地运行时，需 gitignore（已加）。
- **迁移期风险**：迁移提交前的未落库改动（本仓 `B026` 的 resolve+归档在工作区尚未提交）会被一并折叠进批次，
  回滚 tag 只回到 `b6bcd06`（`B026` 仍 todo）——回滚时该条账本进展需从迁移提交里取回，或重放
  `resolve --evidence`。此风险已写在 `backlog/README.md` 的迁移节。

## 验证收据

| 检查 | 命令 | 实测 |
|---|---|---|
| 模型标记 | `cat backlog/MODEL` | `v3` |
| 旧文件已删 | `git ls-files backlog/tasks.jsonl backlog/.next-id` | 空（`git rm` 后） |
| 条数对账 | `node scripts/backlog.mjs fold` | 迁移前 v2 活跃 1 / done 26 → 迁移后 fold 活跃 1 / done 26 |
| 记录合法性 | `node scripts/backlog.mjs lint` | exit 0（`活跃 1 / 已闭环 26 / 批次 1 活跃 + 0 归档`） |
| 跨归档/租约对账 | `node scripts/backlog.mjs doctor` | exit 0（`ok:true`，legacyArchived 26） |
| 归档封存 | `node scripts/backlog.mjs verify-archive` | exit 0（校验 0 个归档批次） |
| 门禁 | `bash .meta/gates/backlog-gate.sh` | exit 0 |
| 门禁自检 | `bash .meta/gates/backlog-gate.spec.sh` | exit 0（`##SPEC asserts=14 rejects=9`） |
| 回滚点 | `git tag -l 'backup/backlog-v2-*'` | `backup/backlog-v2-20261122-2129` → `b6bcd06` |

文档的家（same-commit 更新）：`backlog/README.md`（v3 契约与迁移节）、`.meta/gates/INSTANCE-GATES.md`
（承诺 → 命令）、本记录。
