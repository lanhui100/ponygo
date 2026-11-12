# Task TASK-001 — ponygo v0 收口：F1-F6 修复 + commit 初版 + v1.1 增强

| 字段 | 值 |
|---|---|
| Task ID | TASK-001 |
| 状态 | Done（2026-08-30 收口）|
| 复杂度 | B |
| 负责人 | @orchestrator + @implementation-engineer A/B |
| 创建时间 | 2026-08-30 |
| spec | ../specs/spec-ponygo-v0-v1.1.md |
| review 记录 | ../reviews/review-TASK-001.md |
| 测试证据 | tests/run.sh pass=117 fail=0（19 场景）+ 手工回归记录（见 review 记录）|

## 背景

HANDOFF.md 交接的三轮对抗审核后的 ponygo 首版，经独立复核发现 6 个新问题（F1-F6），
另有 v1.1 增强（L1/L2 判据入 CLI、meta.yaml 违例告警、自测脚本）待实施。

## 目标

1. 修复 F1-F6（详见 spec）。
2. commit 初版（两个 commit：初版修复 → v1.1 增强）。
3. v1.1：`ponygo status` 一键验级（L0-L2 机械判据）+ meta.yaml 非 level 键告警 + tests/run.sh。

## 非目标

- 第 3 步（真实项目试点）——需真人参与。
- 第 4 步（v2：upgrade diff 合并、L3-L6 机制解冻）。
- 不改命令面（保持六命令）。maturity-ladder.md §5 按 spec rev2/rev3 的**显式清单**
  回写修订（0.4/1.2/1.5/1.6/1.7/2.1/2.2/L0 注），不做清单外改动。

## 验收标准

- [ ] `bash tests/run.sh` 全部通过（exit 0）。
- [ ] 审计得分不再被占位 README/.gitkeep 污染（新 init 非 git 目录、git 配置消毒、
  `--level S` 下命中恰为 `4 / 10`；`--level M` 恰为 `4 / 14`）。
- [ ] 六个空目录有 .gitkeep；存在 `.gitattributes`（eol=lf），新 clone 下 `bash ponygo` 可运行。
- [ ] `ponygo status` 对声明 level（及 min(level,2) 地基）逐项机械验证，缺口 exit 1。
- [ ] meta.yaml 违例键在 status 与 audit 均告警（WARN，exit 0）。
- [ ] README / depth-selector 细目数量口径与 checklist.md 一致（骨架8/机制15/精微8，
  测试 grep 断言）。
- [ ] init 生成的 decisions/README.md 与模板 eol 归一后逐字节一致（测试 cmp 断言）。
- [ ] 三个 commit 完成（docs 口径 / v0 代码修复 / v1.1），README 索引与实际一致。

## 状态流

Backlog → Ready → **In Progress** → Review → Validation → Done
