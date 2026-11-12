# TASK-002 —— ponygo v2.3：判据 2.3 执行侧 opt-in + 口径漂移修复

| 字段 | 值 |
|---|---|
| Task ID | TASK-002 |
| 状态 | Done（实施完成；全量回归 pass=243 fail=0；三份 review 归档） |
| 复杂度 | B（跨 CLI 判据 / 骨架模板 / 测试 / 文档；含一条判据语义变更） |
| 负责人 | orchestrator（主会话）+ 子智能体四审 |
| 创建时间 | 2026-09-08 |
| spec | `docs/dev-team/specs/spec-ponygo-v2.3.md`（**rev2**） |
| review | `reviews/review-TASK-002-architect.md`、`reviews/review-TASK-002-consultant.md`、`reviews/review-TASK-002-code.md` |

## 背景

`ponygo status` 跑自己 = L1 / exit 0；`ponygo audit` 跑自己 = M 档 9/14，唯一缺口「无本地钩子」；
`tests/run.sh` 基线 pass=209 fail=0。三条实质缺口：框架自己从未走过 L1→L2 路径、
判据 2.3 是形状判据（空 spec 即过）、文档档位口径漂移（真源 L0–L5，文档写 L0–L6）。
另有两项悬空：发布校验和无发布物、`upgrade` 是空命令。

## 目标

按 spec **rev2** 实施 WP0–WP4：判据 2.3 执行侧 opt-in、仓库停 L1 + 可达性测试、
口径漂移修复 + 防复发断言、发布校验和口径。WP5（upgrade 漂移报告）与 release workflow 转 proposed ADR。

## 非目标

不提交 `level: 2` / 不激活 docs-tier / 不提交 `.githooks/` / 不建 docs-parity 门禁
（双审 P0 组 + 维护者裁决）；不交付本任务内无法执行的 workflow；不实施 upgrade 漂移报告；
不改命令面；不动 `docs/HANDOFF.md`。

## 验收标准（rev2）

| # | 判据 | 验证命令 |
|---|---|---|
| A1 | 仓库自身 `ponygo status` exit 0、报 **L1**（不声称 L2） | `bash ponygo status` |
| A2 | 默认 `status`/`audit` **不执行**仓库脚本 | `bash tests/run.sh` s27① |
| A3 | `--run-specs` 正反例 + dry-run/递归/无 spec/非 audit 护栏全过 | `bash tests/run.sh` s27②–⑦ |
| A4 | L1→L2 可达（含撤掉 hooksPath 后 2.4 FAIL 的反例） | `bash tests/run.sh` s28 |
| A5 | 口径漂移归零且被断言看守 | `bash tests/run.sh` s29 |
| A6 | 全量回归绿 | `bash tests/run.sh` → **pass=243 fail=0** |
| A7 | ADR×5 + revision×1 + spec/task/三份 review 齐备，`verify-note.sh` exit 0 | `bash .agents/skills/write-adr/verify-note.sh` |

## 交付物

- CLI：`ponygo` 新增 `run_gate_specs()` + `--run-specs` 开关 + `usage()`/文件头注释 + 2.3 标注；
- 判据真源：`maturity-ladder.md` §5 的 2.3 行与注；
- 模板：`.meta/gates/README.md`（副本 + heredoc 双写）新增「负样本 spec 的两种形态」；
- 口径：`README.md`（4 处 + §3.1 发布口径 + §4.3 只读边界）、`.meta/meta.yaml`（删副本留指针）、
  `.meta/constitution/constitution.md`、`ponygo` 的 `retire` 消息；
- 测试：`tests/run.sh` 场景 27/28/29；
- 记录：`revisions/accepted/2026-09-08-spec-execution-opt-in.md`；
  `.agents/notes/implemented/{bug-fix,process}/2026-09-08-*.md`；
  `.agents/notes/proposed/process/2026-09-08-*.md`（3 条）。

## Next Action

无（已收口）。后续可选：`git push origin main --follow-tags` 发布 v2.3.0；
`.agents/notes/proposed/` 下三条提案按需解冻。

## Resume Hint

若中断：`bash tests/run.sh` 看当前红点；`bash ponygo status` 确认仍在 L1/exit 0；
spec rev2 §6 是文件归属表，§10 是四份审核的结论与处置表。
