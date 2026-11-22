# backlog/ —— 本仓待办与执行账本（唯一活账本，v3 批次日志）

> **判定真源 = `scripts/backlog.mjs`**（`validateTask` / `lintV2` / `lintV3` / `fold` / `doctor` / `verifyArchive`）。
> 本文是它的可读契约：冲突时以代码与命令输出为准，本文只描述模型，不复刻判据细节。
> 跨仓通用操作口径见 skill `pg-backlog`（`references/batch-log-model.md`、`references/migration-v2-to-v3.md`）；
> 本仓特化事实（迁移批次、接线、本地化差异）只在这里。

模型标记：`backlog/MODEL` = `v3`（2026-11-22 由 v2 单文件账本迁入，见下文「迁移」）。

## 布局

| 路径 | 角色 | 入仓 |
|---|---|---|
| `backlog/MODEL` | 模型标记（`v3`） | ✅ |
| `backlog/log/<batchId>.jsonl` | 活跃批次日志（**只追加**；一次会话只写自己的批次） | ✅ |
| `backlog/archive/batches/<year>/<batchId>.jsonl` | 已归档批次（**只读**、按批封存） | ✅ |
| `backlog/archive/batches/<year>/manifest.sha256` | 归档清单（`sha256  <相对路径>`，只追加） | ✅ |
| `backlog/archive/tasks-<YYYY>.jsonl` | v2 遗留归档（只读，fold 并入历史） | ✅ |
| `backlog/.locks/<ID>.lock` | 任务租约（pid/会话/心跳，**本地运行时**） | ❌ 已 gitignore |
| `backlog/.state/batch` | 当前工作区活动批次 id（**本地运行时**） | ❌ 已 gitignore |
| `backlog/legacy/` | 冻结历史（旧 md 任务单），只读、不参与校验 | ✅ |

- **账本根 = 当前 worktree 顶层**（v2 时代的「git common dir 共享单文件」已取消）：各分支写各自批次，
  随各自 PR 提交，合并天然无冲突。夹具/CI 可用 `PONY_BACKLOG_ROOT=<目录>` 覆盖。
- 布局不一致（有 `backlog/log/*.jsonl` 却缺 `MODEL`）= 迁移中断：门禁 fail-closed，先修布局再记账。

## 批次与事件

- 批次命名 `<YYYYMMDD>T<HHMMSS>Z-<surface>-<rand4>`；首行必须是 `batch.start`（`model` / `batch_id` /
  `surface` / 可选 `release` / `created_at`）。批次内事件时间必须单调不减。
- 写命令默认复用 `.state/batch`，首次写自动创建；`batch new --surface <s> [--release <v>]` 显式开新批次。
- 事件白名单：`batch.start` / `record` / `dedup` / `start` / `release` / `annotate` / `resolve`。
- 任务行字段与 v2 **逐字一致**：必填 `id`（`B\d{3,}`）/ `category`（`Defect|Task|Debt`）/
  `priority`（`P0..P3`）/ `status`（`todo|in_progress|done`）/ `title` / `created_at` /
  `metadata.fingerprint`；条件必填 `in_progress` → `owner` + `touched_paths`（≥1）、
  `done` → `evidence` + `closed_at`。未知字段一律拒绝（加字段是改契约，须同批改本文与 CLI）。
- `record` 的 `--fingerprint` **必须显式提供**；同指纹且仍在活跃池时退化为 `dedup`（`occurred_count` +1），
  不新建记录。

## 状态机

`todo → in_progress → done`，允许 `in_progress → todo`（`release`）。**`done` 是终态**：回归不复活旧单，
开新任务并在标题/描述里引用旧 ID（`backlog:B123` 引用不变）。`done` 只能由 `resolve` 写入（带 `evidence` +
`closed_at`）；从 `todo` 直接闭环也合法。手写批次事件冒充 CLI 写入会被 `lint` 抓（首行/事件白名单/时间倒退/
重复 record 或 resolve/条件必填）。

会话中断后用 `owner` / `touched_paths` / `description` 与 `git diff --stat` 交叉确认真实进度——
**不维护任何 plan 文件**。

## 租约（并发控制）

- `start` 以 `O_EXCL` 原子获取 `<ID>.lock`：同一任务同时只允许一个会话持有；`heartbeat` 刷新；
  `release` 显式释放；TTL 默认 **2 小时**（`DEFAULT_LEASE_TTL_MS`）。
  `reap --id <ID> --minutes N [--dry-run]` 只清该任务的锁（**不带 `--id` 才是全局**）。
  `reap` 走参数白名单：未知 token（`--id=B005` / `-id` / 位置参数 / 非法分钟值）一律 exit 2，不回落为全局清理。
- `.locks/` / `.state/` 是本地运行时状态，不入仓：干净克隆/CI 缺锁只 `NOTE`；只有本工作区确有 `.locks/` 时
  「锁在、记录非 `in_progress`」才判违规。
- 租约只保护「同一任务」，不保护批次追加：并发写在 v3 下各自落不同批次文件，冲突面从「同一行尾」消失。

## 读模型：fold

`list` / `fold` 是唯一读法——视图现算、不落盘、不手改：读取全部活跃批次 + 归档批次 + v2 遗留归档，
批次按 `batch.start.created_at` 升序（同刻按 batchId 字典序），批内按行序应用事件，输出活跃视图与 done 集合。

## 命令

```bash
node scripts/backlog.mjs list [--surface tui]     # fold 现算看板
node scripts/backlog.mjs record --category Defect --title "..." --fingerprint "core::x::y" --priority P1 --surface tui
node scripts/backlog.mjs start <ID> --owner lane-1 --paths "a/b.sh,c/d.md"   # 取租约 + 声明写域
node scripts/backlog.mjs heartbeat <ID> --owner lane-1
node scripts/backlog.mjs release <ID>             # 回退 todo + 清锁
node scripts/backlog.mjs resolve <ID> --evidence "bash tests/run.sh exit 0"
node scripts/backlog.mjs annotate <ID> --description "..."   # 只改注释/优先级（状态迁移无旁路）
node scripts/backlog.mjs fold                     # JSON：活跃/批次/问题（排障用）
node scripts/backlog.mjs batch new --surface <s> --release <v>
node scripts/backlog.mjs archive [--release <v>] [--before <ISO>] [--dry-run]
node scripts/backlog.mjs lint && node scripts/backlog.mjs doctor && node scripts/backlog.mjs verify-archive
node scripts/backlog.mjs reap --id <ID> --minutes 0
```

`record` 新建任务的 ID = `B` + epoch 毫秒（13 位，跨会话不撞号）；旧短 ID（`B001`…`B026`）原样保留。
提交信息/文档引用写成 `backlog:<ID>`。

## 归档（按批封存）

- 只归档**批次内引用到的任务全部 `done` 且随版本发布后**的批次；未闭环批次不归档。
- 动作：`archive` 把文件移入 `archive/batches/<year>/` + 追加 `manifest.sha256` 行 + 删 `log/` 原件
  （`git rm`/`git mv` 由提交者完成）。归档只读，`verify-archive` 逐文件校验 sha256，被改动/未入清单即红。
- fold 仍读归档批次 ⇒ 归档不丢历史。

## 门禁与验收

- 门：`bash .meta/gates/backlog-gate.sh` = `lint` + `doctor` + `verify-archive`；
  v2 过渡账本（有 `tasks.jsonl` 无 `MODEL`）走只读兼容 + `NOTE`；账本缺失 → 明确跳过；
  布局不一致 / 未知模型 / 无 `node` → fail-closed。
- 负样本自检：`bash .meta/gates/backlog-gate.spec.sh`（P1–P3 放行 + N1–N8 拒绝 + H pre-commit 接线；
  自报 `##SPEC asserts=14 rejects=9` 供 `ponygo audit --run-specs` 计数）。
- 接线三处：`.githooks/pre-commit`（**哨兵块之外**，块内须逐字节等于规范块）、
  `.github/workflows/ci.yml` 的 `governance` job（门与 spec 各占**独立 step**）、
  `ponygo audit --run-specs`（自动发现 `.meta/gates/*.spec.sh`）。
- 登记面与「承诺 → 命令」：`.meta/gates/INSTANCE-GATES.md`。
- 本仓对 skill `assets/` 模板的两处本地化（模板 ≠ 本仓真源）：
  1) spec 的 H 夹具去掉 `scripts/git-guard.mjs` 前提（本仓 pre-commit 无该依赖，哨兵块自门控）；
  2) spec 补 `##SPEC asserts=/rejects=` 计数行（本仓 spec 运行时契约 GH12/T-U4-1）。

## 迁移（一次性，已完成两次）

**① 2026-11-12 旧 md 任务单 → v2 单文件账本**（`docs/dev-team/tasks/TASK-001..005.md`）：

| 旧单 | 账本记录 | 落点 |
|---|---|---|
| TASK-001..004（Done） | `B001`..`B004` | `backlog/archive/tasks-2026.jsonl`（done + evidence + closed_at） |
| TASK-005（Backlog） | `B005` | 当时 `backlog/tasks.jsonl`（todo） |

映射规则：`source_ref` 指向冻结路径 `backlog/legacy/dev-team-tasks/TASK-00N.md`；旧单状态行原文摘入
`evidence`；旧单未记闭环时间戳者 `closed_at` 取该单创建时间并在 `evidence` 末尾标注「迁移近似」；
「复杂度」不是优先级轴，未迁移（统一 `P2`）。

**② 2026-11-22 v2 单文件账本 → v3 批次日志**（`node scripts/backlog-migrate-v2-v3.mjs --surface legacy-migration`）：

- 承接批次：`backlog/log/20261122T132921Z-legacy-migration-1532.jsonl`（`B005` 一条 `record`，字段逐字保留）；
- 26 条已闭环记录留在 `backlog/archive/tasks-2026.jsonl`（v2 遗留归档，只读，fold 并入）；
- 对账收据：迁移前 v2 活跃 1 / done 26 → 迁移后 fold 活跃 1 / done 26（脚本内对账，不一致自动回滚）；
- `backlog/tasks.jsonl` 与 `backlog/.next-id` 随迁移提交一并删除；决策见
  `.agents/notes/implemented/process/2026-11-22-backlog-v3-batch-log-migration.md`。

后续新增工作一律走 CLI（`record`/`start`/`resolve`），不再新增 md 任务单。

## 诚实边界

- `lint` / `doctor` 不解析 git 历史：无法识别「同时改记录与批次头」的伪装；
- spec 只证明「门会拒绝非法样本」，账本内容真实性靠 review；
- 本地钩子前提：`git config core.hooksPath .githooks` 不随 clone 传播（新 clone 手动装配，
  CI 已在 `ci.yml` 显式 `git config core.hooksPath .githooks`）；未装配时本地门禁静默失效、CI 兜底。
