# Spec —— ponygo v2.3：判据 2.3 执行侧 opt-in + 口径漂移修复（rev2，双审后重切）

> Task: TASK-002 ｜ 复杂度: B ｜ 2026-09-08 ｜ **rev2**：依 @architect / @consultant 双审（均判不通过）+ 维护者裁决重切
> rev1 原文已按双审逐条处置，处置表见 §10；本文件是**实施依据**。

---

## 1. 背景与目标

### 1.1 实测基线

| 检查 | 结果 |
|---|---|
| `ponygo status`（仓库自身） | L1 / exit 0 / 决策数 10 → rev2 实施后 15 |
| `ponygo audit`（仓库自身） | M 档 9/14；唯一缺口「无本地钩子」（**本机事实，保留**） |
| `bash tests/run.sh` | rev1 基线 pass=209 fail=0 |
| `git tag` | 空，而 README §3.1 推荐 `PONYGO_VERSION=v2.2.0 PONYGO_SHA256=<公布的校验和>` |

### 1.2 目标（rev2）

1. **WP1**：判据 2.3 的**执行侧**交付为 opt-in 开关 `ponygo audit --run-specs`——默认只读不执行仓库脚本，执行时带 timeout、dry-run 跳过、递归 SKIPPED 不计入 PASS、失败聚合。
2. **WP2**：仓库保持 `level: 1`（停止线裁决）；L1→L2 可达性由 CI 可复跑的测试场景证明。
3. **WP3**：修复 L0-L5/L0-L6 口径漂移（6 处），删副本 + 测试断言防复发。
4. **WP4**：发布纪律——交付**可验证**的校验和口径（不交付本任务内无法执行的 workflow）。
5. **WP5**：暂缓（登记 proposed ADR），不在本次实施。

---

## 2. 范围与非目标

**范围内**：`ponygo`、`maturity-ladder.md`、`.meta/{meta.yaml,gates/README.md,constitution/constitution.md}`、`README.md`、`tests/run.sh`、`.agents/notes/`、`revisions/accepted/`。

**非目标（rev2 明确砍掉）**：
- 不提交 `level: 2`、不激活 `.meta/docs-tier/`、不提交 `.githooks/`、不新建 docs-parity 门禁（双审 P0-1/P0-5/P1-7 + 维护者裁决）；
- 不交付 `.github/workflows/release.yml`（本任务内不可验证，转 proposed ADR）；
- 不实施 `upgrade` 漂移报告（比对宇宙未定义，转 proposed ADR）；
- 不改命令面（六命令是拍板不变量）；不动 `docs/HANDOFF.md`（历史快照）。

---

## 3. 用户/系统行为

### 3.1 判据 2.3 的两层（WP1）

| 层 | 行为 |
|---|---|
| 默认（`status` / `audit`） | 只查 `*.spec.*` **存在性**；输出如实标注「2.2 与 2.3 均为代理判据」 |
| opt-in（`audit --run-specs`） | 执行 `gates/*.spec.sh`，断言各自 exit 0 |

opt-in 执行侧契约：
- 有 `timeout` 时 30 秒上限；无 `timeout` 时如实降级（不假装跑过）；
- `--dry-run` 一律跳过并打印 `SKIPPED`；
- `PONYGO_IN_SPEC=1` 已在环境 → `SKIPPED`，**不计入 PASS**（fail-closed 语义，不是 fail-open）；
- 无 `*.spec.sh` → `SKIPPED`（不计入 PASS），**不判 FAIL**；
- 失败时报告**全部**失败 spec + 各自输出尾部；有失败 → exit 1。

### 3.2 仓库自身停在 L1（WP2）

- 不加门禁/hooks、不激活 docs-tier、`meta.yaml` 保持 `level: 1`；
- `tests/run.sh` 场景 28 在临时实例跑通 L2 四件套并断言撤掉 `hooksPath` 后 2.4 FAIL。

### 3.3 口径修复（WP3）

修正 7 处（README×4、meta.yaml 注释、constitution 槽位、`ponygo` 的 `retire` 消息）→ 真源 L0–L5 / `0-5`；
`meta.yaml` 的阶梯枚举**删除**，改为指向 `maturity-ladder.md` 的指针（删副本，不是保副本）。
防复发 = `tests/run.sh` 场景 29（4 个当前态文件 + `retire` 消息口径 + meta.yaml 指针）。

### 3.4 发布纪律（WP4）

README §3.1 给出可执行的校验和获取/生成口径（Release 附件优先，未发布时 `sha256sum ponygo` 本地自算），
版本示例同步为当前版本；自动化转 proposed ADR。

---

## 4. 技术方案与替代方案

| 曾计划（rev1） | rev2 处置 | 依据 |
|---|---|---|
| `status` 默认执行 `*.spec.sh` | 改 opt-in 开关 | 违反文件头「判定优先只读」；`--dry-run` 实测落盘 |
| 仓库升 `level: 2` | 保持 L1 + 测试证明可达 | §6 停止线；2.4 是本机事实 |
| 新建 docs-parity 门禁 + `.githooks/` | 取消，改 tests 断言 | 制度化多副本；门禁不可复用；假 PASS 风险 |
| 激活 docs-tier + 放宽 s14 | 不激活，s14 原样 | 激活必破 s14，放宽丢单源性看守 |
| 交付 release.yml | 转 proposed ADR | 本任务内永不执行 = 不可验证 |
| 实施 upgrade 漂移报告 | 转 proposed ADR | 健康实例必报假漂移 |

---

## 5. 影响面和依赖

- **行为变更**：新增 `audit --run-specs`（默认行为不变，无破坏性迁移面）；`retire` 错误消息口径修正。
- **文档**：README（§3.1/§3.2/§4.3 + 4 处口径）、`maturity-ladder.md` §5 的 2.3 行与注、`meta.yaml` 注释、
  `constitution.md` 槽位、`.meta/gates/README.md`（仓库副本 + `ponygo` heredoc 双写，s14 看守）、
  `docs/methodology.md` §4.6（新增「只读判定不执行仓库代码」一条）。
- **测试**：新增场景 27/28/29；s14 不变。
- **决策记录**：ADR×5（2 implemented + 3 proposed）+ revision×1（见 §10）。
- **依赖**：零新增外部依赖。

---

## 6. 任务拆解与并行边界

| WP | 内容 | 独占写目标 |
|---|---|---|
| WP0 | 决策与演进记录（ADR + revision） | `.agents/notes/`、`revisions/` |
| WP1 | 2.3 执行侧 opt-in | `ponygo`、`.meta/gates/README.md`(+heredoc)、`maturity-ladder.md` |
| WP2 | 停 L1 + 可达性场景 | `tests/run.sh`（s28） |
| WP3 | 口径修复 + 防复发 | `README.md`、`meta.yaml`、`constitution.md`、`tests/run.sh`（s29） |
| WP4 | 发布口径 | `README.md` |

**并行边界（rev2 修正）**：`tests/run.sh` 与 `README.md` 是独占写目标——本次由单一实施者串行推进，
不开并行子智能体改同一文件（rev1 的并行表是错的，双审 P1-5 已指出）。

---

## 7. 风险、回滚与迁移

| 风险 | 缓解 |
|---|---|
| opt-in 执行侧引入脚本执行面 | 默认关闭 + timeout + dry-run 跳过 + 递归 SKIPPED 不计 PASS + README 披露 |
| 口径断言误报（历史文档正当提及） | 白名单只含 4 个当前态文件；历史记录豁免 |
| 新增 `--run-specs` 被误用为默认 | `usage()` 与 README 均标注 opt-in 与只读边界 |
| 仓库仍停 L1 被读成"没做" | ADR 写明停止线依据 + 场景 28 提供可达性证据 |

**回滚**：`--run-specs` 是纯增量开关，删除即回到 rev1 前行为；口径修复可按文件 `git revert`。

---

## 8. 测试计划

| 场景 | 断言 |
|---|---|
| s27（新） | ① `status`/`audit` 默认不执行脚本（WITNESS 不出现）；② `--run-specs` 全过 exit 0 且确实执行；③ 有失败 spec → exit 1 + 回显；④ `--dry-run` SKIPPED 且不执行；⑤ `PONYGO_IN_SPEC=1` → SKIPPED 且不并入 PASS；⑥ 无 `.sh` spec → SKIPPED 非 FAIL；⑦ `--run-specs` 用在非 audit 命令 → exit 1（显式拒绝，不静默忽略） |
| s28（新） | L2 四件套齐 → exit 0 且报 L0-L2；撤掉 `hooksPath` → exit 1 报 2.4 |
| s29（新） | 4 个当前态文件无 `L6`/`0-6`；`retire` 消息为 `0-5`；`meta.yaml` 指向真源 |
| s12/s14 | 原样保留（L2 判据 + 逐字节一致性） |
| 全量 | `bash tests/run.sh` fail=0；`verify-note.sh` exit 0 |

---

## 9. 验收标准（rev2）

| # | 判据 | 验证命令 |
|---|---|---|
| A1 | 仓库自身 `ponygo status` exit 0、报 L1（**不声称 L2**） | `bash ponygo status` |
| A2 | 默认 `status`/`audit` 不执行仓库脚本 | `bash tests/run.sh` s27① |
| A3 | `--run-specs` 正反例 + dry-run/递归/无 spec/非 audit 护栏全过 | `bash tests/run.sh` s27②–⑦ |
| A4 | L1→L2 可达（含 2.4 反例） | `bash tests/run.sh` s28 |
| A5 | 口径漂移归零且被断言看守 | `bash tests/run.sh` s29 |
| A6 | 全量回归绿 | `bash tests/run.sh` |
| A7 | ADR/revision/spec/task/review 齐备，`verify-note.sh` exit 0 | `bash .agents/skills/write-adr/verify-note.sh` |

> 说明（rev1 P1-4 的教训）：A2–A5 都是**可在 CI 复跑**的测试断言，不依赖本机 git 配置；
> A1 明确只声明 L1；不再出现"仓库自身为 L2""audit 无强制层缺口"这类依赖本机状态的验收项。

---

## 10. 审核记录与处置

| 审核轮 | 审核者 | 结论 | 记录 |
|---|---|---|---|
| spec rev1 | @architect（独立） | **不通过**（5 P0） | `reviews/review-TASK-002-architect.md` |
| spec rev1 | @consultant（独立） | **不通过**（4 P0） | `reviews/review-TASK-002-consultant.md` |
| code | @code-reviewer-a（独立） | 有条件通过（无 P0/P1，2 条 P2 必修） | `reviews/review-TASK-002-code.md` |
| code | @code-reviewer-b（独立） | 不通过（1 P0 + 3 P1）→ 已逐条修复 | 同上 |
| 维护者裁决 | 用户 | 保持 L1 + 执行改 opt-in | 本 spec rev2 |

**处置摘要**：P0-1 停 L1（采纳）；P0-2 执行改 opt-in（采纳）；P0-3 s14 不动（采纳）；
P0-4 WP5 暂缓（采纳）；P0-5 不提交 `.githooks/`（采纳）；P1-1/P1-7 门禁取消改测试断言（采纳）；
P1-2 清单补齐（采纳，含 `retire` 真实 bug）；P1-3 删除"改后缀绕过"（采纳）；
P1-4 验收改述（采纳）；P1-5 独占写目标（采纳）；P1-6 workflow 转 ADR（采纳）；
P2-1/P2-3/P2-6 护栏与聚合（采纳）；P3-2 根 `AGENTS.md` 待办（不采纳，登记）。
