# Review 记录 — TASK-001（spec rev2/rev3 + 实现）

> 2026-08-30 ｜ 编排：@orchestrator ｜ 审核：独立子智能体 ×4（串行派发，防 429）

## Spec 审核（实施前）

| reviewer | 视角 | 结论 | 处置 |
|---|---|---|---|
| reviewer-1 | 架构/契约 | 有条件通过 | P0×2、P1×6 全部采纳；P2 采纳 8 条（P2-6 部分采纳）；P3 采纳 4 条。详见 spec §10 前的 rev2 修订。 |
| reviewer-2 | 边界/测试 | 有条件通过 | P0×2、P1×9 全部采纳；P2 采纳 7 条。详见 spec §10（rev3）。**P1-1 不采纳**：其声称的 `||`/`&&` 优先级 bug 经三 CASE 实证为 shell 左结合下的正确行为（任一存在即命中），属误报；采纳其精神补 M 档确定性计数断言。 |

## 代码审核（实施后）

| reviewer | 视角 | 结论 | 处置 |
|---|---|---|---|
| reviewer-a | 正确性/回归 | 有条件通过 | **必修 P2-1**（audit rejected 非空漏排 README.md）→ 已修；P2-2（commit 切分）→ 收口执行。P3 采纳：`-type f`/决策计数统一为 `count_decisions()`、read_level 空值显示、tests trap、sync 三分支测试、README §4.3 撞名措辞、maturity-ladder 0.4 宽容度注、平台边界声明。 |
| reviewer-b | 边界/失败路径 | 有条件通过 | **必修 P1-1**（verify_ladder 2.4 在非 git 目录读全局配置假 PASS + s12 未消毒）→ 已修（CLI 加 `git rev-parse` 守卫 + 测试消毒）；**必修 P2-1**（retire 对非常规文件 meta.yaml 假成功）→ 已修（`-f` 守卫）。P2-2 补盲场景（1.3/1.4/缺 Status/sync 分支）→ 场景 19 落地。不采纳：1.5/1.6/1.7 合并单次遍历的重构（有测试覆盖，收口前不做无谓 churn）；BOM 剥除（fail-closed 可接受）。 |

## 实施偏离 spec 的记录

1. **commit 切分 3→2**：spec §11 规定 commit-2（v0 修复）/commit-3（v1.1）分开，但 A 线对单文件
   `ponygo` 的两类变更一次落地，事后无法干净拆分（hunk 手术风险 > 收益）。实际切分为：
   commit-1 文档口径 + 过程记录，commit-2 CLI + 测试 + 骨架 + v1.1。
2. **1.7 比对对象为 lifecycle 顶层目录**（A 线自测发现并修正，非 spec 偏离，备查）。

## 已知问题（不修，留 P9）

- sync 的 `awk -v body` 对含反斜杠槽位的转义缺陷（rev3 P2-4）。
- 既有 CRLF AGENTS.md 的标记区匹配失效（rev3 P2-4）。
- depth-3 空目录对 1.3/1.4/1.5 不可见（git 不跟踪空目录，风险低）。
- `retire --level N` 实为双向改写，命名是"降级"却可升。

## 测试证据

- `bash tests/run.sh`：**pass=117 fail=0**（19 场景）。
- `bash -n ponygo`、`bash -n tests/run.sh`：通过。
- 手工回归：HANDOFF §五 验收路径（init 不投影 / 填槽 sync / status / audit）在 temp 目录实测通过。
