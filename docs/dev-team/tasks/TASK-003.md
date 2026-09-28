# TASK-003 —— 落实三条 proposed ADR（L2 判据矛盾 / upgrade 漂移报告 / 发布校验和自动化）

| 字段 | 值 |
|---|---|
| Task ID | TASK-003 |
| 状态 | In Progress |
| 复杂度 | B（跨 CLI 判据 / 骨架模板 / workflow / 测试 / 发布动作；含两处框架规则语义） |
| 负责人 | orchestrator（主会话）+ 子智能体评审团 |
| 创建时间 | 2026-09-14 |
| spec | `docs/dev-team/specs/spec-ponygo-v2.4.md` |
| review | `reviews/review-TASK-003-*.md`（待补） |

## 背景

上一轮（TASK-002，commit `b8b7e28`，tag `v2.3.0` 未推）留下三条 proposed ADR，均经独立对抗评审，
结论**全部不通过**（方向保留，重切后可实施）：

| 提案 | 评审结论 | 关键否决点 |
|---|---|---|
| `2026-09-08-l2-minimal-representable.md`（2.5 改条件判据） | 不通过 | meta.yaml 铁律冲突 + 默认 SKIP 门禁空心化 + SKIPPED 语义冲突；需升级 consultant 三选一 |
| `2026-09-08-upgrade-drift-report.md`（漂移报告） | 不通过（4 P0） | 比对宇宙路径错 + `.meta/skeleton-owned` 第三副本 + 问错方向（"缺失才写"语义下基线不存在） |
| `2026-09-08-release-checksum-automation.md`（校验和自动化） | 不通过（无需 consultant） | README 主路径 fail-open（空 SHA 跳过校验）+ 死链当推荐 + 口径未钉裸哈希 |

现状基线：`ponygo status` = L1 / exit 0；`audit --level M` = 9/14（唯一缺口"无本地钩子"，保留）；
本地 `v2.3.0` 已打、`ls-remote` 远端无 tag、工作树干净；`gh` 已认证（`lanhui100`，scope 含 `repo`）。

## 目标

按 spec 实施 R（release）/ U（upgrade）/ L（L2）三包；推 tag 建 Release 让安装路径端到端可验证；
全量回归绿后提交并推送。

## 非目标

- 不做 `upgrade` 自动合并（v+2 能力）；不改六命令面；不动 `docs/HANDOFF.md`；
- 不升本仓库 level（停 L1，§6 停止线裁决延续）；
- 不引入 mixed 标记块机制（框架规则变更太大，留待独立提案）。

## 验收标准

| # | 判据 | 验证命令 |
|---|---|---|
| A1 | consultant 裁决书落盘（三问三选一） | `reviews/review-TASK-003-consultant.md` 存在且三问均有明确选项 |
| A2 | README 安装主路径 fail-closed | `tests/run.sh` s30：附件 404/空 SHA → 安装拒绝（非跳过校验） |
| A3 | installer 与载荷同钉 tag | `install.sh` 默认 URL 含 tag 变量；s30 断言 |
| A4 | release workflow 口径 = 裸哈希 + 钉 Linux + 最小权限 | s30 三断言（静态管线/本地动态复跑/diff/hex 格式） |
| A5 | 附件发布后安装路径端到端可验证 | `PONYGO_VERSION=v2.4.0 PONYGO_SHA256=<附件值>` 安装成功（v2.4.0 若发布；否则记录 blocked 证据） |
| A6 | `upgrade` 零假漂移 + `--check` 供 CI | s31：健康实例 exit 0 无漂移行；篡改 template-owned → 默认仍 0、`--check` 非零 |
| A7 | donot 三场景有定义且测试覆盖 | s31：无 `.meta/` die；非 git WARN；无 level 按 L0 |
| A8 | L2 按裁决落地，§1/§5/§6 口径一致 | s29 扩展断言；`ponygo status` 本仓仍 L1 exit 0 |
| A9 | 全量回归绿 | `bash tests/run.sh` fail=0；`verify-note.sh` exit 0 |
| A10 | ADR 拆条与迁移 | implemented 口径 ADR + proposed workflow ADR；三条旧 proposed 按处置迁移/归档 |

## Next Action

spec 双审（含 consultant 裁决）→ 按裁决实施 R/U/L → 双代码复审 + security 快审 → 全量回归 → 提交推送。

## Resume Hint

若中断：读 `spec-ponygo-v2.4.md` §10 审核记录表看哪一包已落地；`git status --short` 确认工作树；
`gh release list` 确认 Release 是否已建。
