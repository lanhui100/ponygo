# backlog/ —— 本仓待办与执行账本（唯一活账本）

> **判定真源 = `scripts/backlog.mjs`**（`validateRecord` / `lint` / `doctor`）。本文是它的可读契约：
> 冲突时以代码与命令输出为准，本文只描述模型，不复刻判据细节。
> 跨仓通用操作口径见 skill `pg-backlog`；本仓特化事实（迁入路径、接线、ID 下限）只在这里。

## 布局

| 路径 | 角色 | 入仓 |
|---|---|---|
| `backlog/tasks.jsonl` | 唯一活账本，一行一任务 | ✅ |
| `backlog/archive/tasks-<YYYY>.jsonl` | 闭环滚动归档（`resolve` 幂等追加，按 `closed_at` 年份切片） | ✅ |
| `backlog/.next-id` | ID 高水位 = **下一个候选编号**（单调不减，永不回退） | ✅ |
| `backlog/.locks/<ID>.lock` | 任务级租约（pid/会话/心跳，**本地运行时**） | ❌ 已 gitignore |
| `backlog/legacy/` | 冻结历史（旧 md 任务单），只读、不参与校验 | ✅ |

## 记录模型

- 必填：`id`（`B\d{3,}`）/ `category`（`Defect|Task|Debt`）/ `priority`（`P0..P3`）/
  `status`（`todo|in_progress|done`）/ `title` / `created_at` / `metadata.fingerprint`。
- 条件必填：`in_progress` → `owner` + `touched_paths`（≥1）；`done` → `evidence` + `closed_at`。
- 可选：`description`（≤2000 字符）、`source_ref`（来源指针：旧单路径 / 会话标识）、
  `updated_at` / `leased_at` / `heartbeat_at` / `archived_at`、
  `metadata.triage_context`（≤8KiB）/ `metadata.occurred_count`。
- `record` 的 `--fingerprint` **必须显式提供**（缺省 → exit 1）：指纹是去重键——同指纹且仍在活跃池
  （`todo`/`in_progress`）时 `record` 不新建记录，而是把 `metadata.occurred_count` +1 并打印
  「去重命中」。缺省会退化成"所有任务共用一个指纹并在第一条上静默合并"，账本直接丢行。
- 未知字段一律拒绝（`TOP_KEYS` / `META_KEYS` 白名单）——加字段是改契约，须同批改本文与 CLI。
- ID 分配：候选编号 = `max(高水位, 活跃∪归档已见最大编号 + 1, ID_FLOOR)`，`ID_FLOOR = 1`。
  高水位只增不减，归档/删除都不会让编号复用。
- 账本根默认由 git common dir 解析（同仓所有 worktree 共享一份账本）；夹具/CI 可用
  `PONY_BACKLOG_ROOT=<目录>` 覆盖。

## 状态机

`todo → in_progress → done`，允许 `in_progress → todo`（`release`）。**`done` 只能由 `resolve` 写入**
（写入证据并归档；从 `todo` 直接闭环也合法）；活跃池残留 `done` 由 `lint` 判违规。

手改 JSONL 的状态跳变不被 CLI 拦截，但「记录非 `in_progress` 却仍持锁」会被 `lint`/`doctor`
判违规（手改降级 / `start` 中断都走这一条）。会话中断后用 `owner` / `touched_paths` /
`description` 与 `git diff --stat` 交叉确认真实进度——**不维护任何 plan 文件**。

## 租约（并发控制）

- `start` 以 `O_EXCL` 原子获取 `<ID>.lock`：同一任务同时只允许一个会话持有；`heartbeat` 刷新；
  `release` 显式释放；租约 TTL 默认 **2 小时**（`DEFAULT_LEASE_TTL_MS`），
  `reap --id <ID> --minutes N [--dry-run]` 回收指定任务的超龄租约（`--minutes` 缺省 **120**）。
  `reap` 走参数白名单：未知 token（`--id=B005` / `--ide` / `-id` / 位置参数 / 非法分钟值）一律
  exit 2，**不会**回落为全局清理；只有「参数合法且不带 `--id`」才会清达到阈值的全部租约。
- `.locks/` 是**本地运行时状态**，不入仓：干净克隆/CI 上缺锁只提示（`NOTE`），不阻断；只有在
  「本工作区确实存在 `.locks/`」时才把缺锁判为手改状态的强信号。
- 反向组合「锁在、记录不是 `in_progress`」一律判违规。`resolve` 归档后即时释放租约。
- 租约只保护「同一任务」，不保护账本追加：并发 `record` 仍可能丢行，靠「record 后立即提交 +
  冲突人工合并」兜底。

## 命令

```bash
node scripts/backlog.mjs list                 # 看板（状态/优先级排序）
node scripts/backlog.mjs record --category Defect --title "..." --fingerprint "core::x::y" --priority P1
node scripts/backlog.mjs start B005 --owner lane-1 --paths "a/b.sh,c/d.md"   # 取租约 + 声明写域
node scripts/backlog.mjs heartbeat B005 --owner lane-1
node scripts/backlog.mjs release B005         # 回退 todo + 清锁
node scripts/backlog.mjs resolve B005 --evidence "bash tests/run.sh exit 0"
node scripts/backlog.mjs annotate B005 --description "..."   # 只改注释/优先级；传 --status 直接报错（状态迁移无旁路）
node scripts/backlog.mjs lint                 # 记录不变量（非零 = 违规）
node scripts/backlog.mjs doctor               # 跨归档/高水位/孤儿租约对账
node scripts/backlog.mjs reap --id B005 --minutes 0        # 只清该任务的锁
```

提交信息/文档引用写成 `backlog:B005`（裸 `B005` 视为旧编号）。

## 门禁与验收

- 门：`bash .meta/gates/backlog-gate.sh` = `lint` + `doctor`；账本缺失 → 明确跳过；无 `node` → fail-closed。
  「跳过」分支只为**尚未启用账本**的仓留口——本仓已启用，故 spec 常驻断言
  `backlog/tasks.jsonl` / `.next-id` / `scripts/backlog.mjs` 在场（删账本会让门静默跳过、整链变绿）。
- 负样本自检：`bash .meta/gates/backlog-gate.spec.sh`（P1–P5 放行与实例级在场/接线断言 + N1–N8 拒绝 + H/H2 pre-commit 接线与真执行）。
- 接线三处：`.githooks/pre-commit`（**哨兵块之外**，判据 2.4 要求哨兵块内逐字节等于规范块）、
  `.github/workflows/ci.yml` 的 `governance` job、`ponygo audit --run-specs`（自动发现 `gates/*.spec.sh`）。
- 登记面与「承诺 → 命令」：`.meta/gates/INSTANCE-GATES.md`（`.meta/gates/README.md` 是骨架文档、
  逐字节锁定，实例门不入该表）。

## 迁移（旧 md 任务单，一次性，已完成）

2026-11-12 由 `docs/dev-team/tasks/TASK-001..005.md` 迁入：

| 旧单 | 账本记录 | 落点 |
|---|---|---|
| TASK-001..004（Done） | `B001`..`B004` | `backlog/archive/tasks-2026.jsonl`（done + evidence + closed_at） |
| TASK-005（Backlog） | `B005` | `backlog/tasks.jsonl`（todo） |

映射规则（迁移不改写事实，只补最小可判定字段）：

- `source_ref` 一律指向冻结路径 `backlog/legacy/dev-team-tasks/TASK-00N.md`；
- 旧单的「状态」表行原文摘入 `evidence`（保留当时口径，含 pass/fail 计数与 review 指针）；
- 旧单**大多未记录闭环时间戳**（例外：TASK-001 的状态行明写 `Done（2026-08-30 收口）`，`B001` 直接采用该日期）；
  其余记录 `closed_at` 取该单 `创建时间`，并在 `evidence` 末尾显式标注「迁移近似」——不得把它读成事实时间；
- 旧单的「复杂度」不是优先级轴，未迁移；迁移记录统一 `priority: P2`（已闭环，排序不承载信息）。

后续新增工作一律走 CLI（`record`/`start`/`resolve`），不再新增 md 任务单。

## 诚实边界

- `lint` / `doctor` 不解析 git 历史：无法识别「同时改记录与高水位」的伪装；
- spec 只证明「门会拒绝非法样本」，账本内容真实性靠 review；
- 本地钩子前提：`git config core.hooksPath .githooks` 不随 clone 传播（新 clone 手动装配，
  CI 已在 `ci.yml` 显式 `git config core.hooksPath .githooks`）；未装配时本地门禁静默失效、CI 兜底。
