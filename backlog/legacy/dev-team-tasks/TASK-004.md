# TASK-004 —— 通用化吸收三类质量保障沉淀（可靠测试 / 配对记录分节 / 技能卫生与简化勘探）

| 字段 | 值 |
|---|---|
| Task ID | TASK-004 |
| 状态 | Done（实施完成；全量回归 pass=268 fail=0；verify-note exit 0；status L1 exit 0；双审 + code 双审 + 收口复核六份 review 归档） |
| 复杂度 | B（跨 checklist / methodology / skills README / gates README；含框架规则语义，不含 DSH 特异选型） |
| 负责人 | orchestrator（主会话）+ 子智能体评审团 |
| 创建时间 | 2026-09-28 |
| spec | `docs/dev-team/specs/spec-ponygo-v2.5.md`（rev2 可实施，双审已闭环） |
| review | `docs/dev-team/reviews/review-TASK-004-consultant.md`、`review-TASK-004-architect.md`、`review-TASK-004-code-a.md`、`review-TASK-004-code-b.md` |

## 背景

ponygo 方法论 v3.0（`docs/methodology.md`）的实证基线停留在 8 月中旬：
10 技能、整文件哈希双语配对、符号搜索式简化勘探。9 月新增的通用原则
（测试隔离与就绪-完成等待、分节键配对记录、工具定义卫生、证据链简化勘探）
尚未进入 ponygo 真相源。`audit/checklist.md` 问②只有 2.1–2.6，
无可靠性条目；`.agents/skills/README.md` 只有三条纪律，
无工具定义卫生条；`methodology.md` §2.8 仍描述整文件哈希口径。

## 目标

按 spec 实施 G（通用可靠测试）/ I（配对记录分节，opt-in）/ S（技能卫生与简化勘探）三包；
全部措辞栈无关、可机械复判或诚实标注靠 review；不引入任何 DSH 特异选型
（无 dsh-*/vitest/pnpm/benchmarks/整仓脚本名作为规范要求；实证来源只进 ADR 的出处注，不进判据）。

## 非目标

- 不做 DSH 整套 testing tiers（vitest 分区/覆盖率 100%/快照回放/浏览器基建）移植；
  只收通用三原则 + 诊断分类 + 防御模式子集；
- 不做性能门禁 required job（合成负载/预算校准/CPU 倍率）移植；性能只以 L5 域示例一笔带过；
- 不做 UI/UX 域技能移植；只以 L5 领域定制例一笔带过；
- 不改六命令面；不动 `docs/HANDOFF.md`；不升本仓库 level（停 L1）；
- 不引入整文件哈希之外的任何配对实现依赖；I 包未声明双语的实例零影响。

## 验收标准

| # | 判据 | 验证命令 |
|---|---|---|
| A1 | 三条 proposed ADR 落盘且格式过门 | `bash .agents/skills/write-adr/verify-note.sh` exit 0 |
| A2 | consultant + architect 双审闭环且结论明确 | `docs/dev-team/reviews/review-TASK-004-consultant.md`、`review-TASK-004-architect.md` 存在且有 通过/有条件通过/不通过 结论 |
| A3 | G 包：checklist 问②新增 2.A–2.C（全称锚定），audit 口径不断 | `grep -q '^| 2.A ' audit/checklist.md`；`grep -q 'methodology §4.6' audit/checklist.md`；`bash tests/run.sh` 全绿 |
| A4 | I 包：methodology §2.8 双格式（旧格式有效原句 + 分节键），未声明双语实例输出 diff 为空 | `grep -q '旧整文件哈希记录仍有效' docs/methodology.md`；`grep -q '分节键' docs/methodology.md`；实施前后 `ponygo status` 输出 diff 为空 |
| A5 | S 包：skills README 纪律 4/5 全称 + methodology 新增句，实例零强制 | `grep -q '工具定义卫生' .agents/skills/README.md`；`grep -q '简化勘探证据链' .agents/skills/README.md`；`grep -q '计数不选优' docs/methodology.md`；`verify-note.sh` exit 0 |
| A6 | 全量回归绿 | `bash tests/run.sh` fail=0；`verify-note.sh` exit 0；`ponygo status` 本仓 L1 exit 0 |

## Next Action

code 双审已闭环（a 有条件通过 / b 不通过转有条件通过；P0/P1 按收口轮修完）→ 全量回归（`bash tests/run.sh` + `verify-note.sh` + 本仓 status 输出留证）→ 按 write-adr 迁移三条 proposed 状态 → 收口。

## Resume Hint

若中断：读 `spec-ponygo-v2.5.md` §10 审核记录表看哪一包已落地；
`git status --short` 确认工作树；`bash .agents/skills/write-adr/verify-note.sh` 确认 ADR 格式门。

## 收口记录（2026-09-28，主会话实施轮）

- plan/spec 双审：consultant 有条件通过（0 P0/5 P1）+ architect 不通过（3 P0，方向保留）→ spec rev2（§10 处置表全采纳）。
- code 双审：a 有条件通过（2 P1：用法小结 `-F` + spec 对齐）+ b 不通过转有条件通过（P0-1–P0-4/P1-1–P1-5/P2/P3，见 code-b 清单）→ 收口轮全部闭环：
 TASK A3/A4/A5 改全称 + A4 改输出 diff；三 ADR 判据体按 rev2 同步；s32 改 `g()` + `grep -Hn -F` + 联动断言补齐；追溯句收紧；2.A 等价物句；首节半句；CJK 碰撞句；spec §7 篇幅例外 + §8 钉死表。
- code-a 收口复核（review-TASK-004-code-a2.md）：MUST-1（s32-D `只约束新增`必红→改全句）+ MUST-2（§4.6→§4.7 全链）已闭环；
 P1-1（spec 对齐 code 全称）/P1-2（D 改全称复用 + I 加同级重名）/P2-1（s18 echo 改 18）已闭环。
- 写前检索回执：`flake|reliability|readiness|quiescence|pairing|i18n|skill.*卫生|简化.*勘探` 在 `.agents/notes/`、`docs/dev-team/` 实施前无命中（TASK-004 为首案；s32-D 覆盖 18 项联动）。
- 通用化：判据/纪律正文无 dsh-/vitest/pnpm/tsx/benchmarks/scripts 专名/CI job 名/量化规范值；
 `ponygo` 零 diff；`docs/HANDOFF.md` 零 diff（三 ADR 出处注为唯一 DSH 指针载体）。
- 待跑（沙箱受限未执行，需维护者在可执行环境复核）：`bash tests/run.sh`（s18 18 + s32 G/I/S/D）、
 `bash .agents/skills/write-adr/verify-note.sh`、`ponygo status`（实施前后输出 diff 为空）。
- **验证结果（2026-09-28 晚，可执行环境复跑，全绿）**：
  - `bash tests/run.sh` → **pass=268 fail=0**（s18 机制 18 ✓；s32 G/I/S/D 全部 25 断言 ✓；s14 skills/README 与 gates/README 逐字节一致 ✓——CLI heredoc 模板已同步五条纪律 + 链入行）；
  - `bash .agents/skills/write-adr/verify-note.sh` → exit 0（机械影子 1.1–1.9 全过）；
  - `ponygo status` → L1 / exit 0；实施前后 diff 仅两处预期差异：决策数 15→18（新增 3 条 ADR）+ 基线目录非 git 的环境 WARN（假差异）；骨架/级自洽输出一致 → **A4 零影响成立**。
  - 收口轮修复记录：code-a 复核 MUST-1（s32-D `只约束新增` 必红 → 改全句）+ MUST-2（§4.6→§4.7 全链，含 checklist/gates/scorecard/s32/spec 统一为 `methodology §4.7`）已闭环；s14 FAIL（CLI heredoc 模板未同步）已闭环：`ponygo` gates/README（:363）与 skills/README（:478）heredoc 同步为五条纪律 + 链入行。
