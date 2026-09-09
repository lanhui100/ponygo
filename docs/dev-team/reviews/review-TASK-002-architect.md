# Review 记录 —— TASK-002 / spec-ponygo-v2.3 rev1（@architect 独立对抗审核）

> 审核者：独立子智能体（@architect 角色）｜ 2026-09-08
> 快照：`ponygo` md5 `59f1b68…`（审核期间实施并发落盘，结论针对 rev1 spec 文本）
> 方法：通读 spec + 源码逐段核实 + 实测复现（`--dry-run` 落盘、护栏 fail-open、索引模式、暂存绕过）

## 结论

**不通过**（5 条 P0，每条独立足以推翻；P0-1/P0-2 是框架级自洽性问题）。

- 可保留：WP3 口径修正本体、2.3 执行判据的**方向**（实测有效）、`tests/run.sh` 基线 pass=209 fail=0。
- 必须重切：WP2 的 `level: 2` 路径、WP5 的比对宇宙、WP4 的验收方式、WP1 的执行位置与护栏语义。

## P0 问题

### P0-1 WP2 违反停止线，且 §5 判据无法表示 §6 的建议状态

`maturity-ladder.md:161`「单人 + 决策密度 ≥ 1 条/周 → 保留 L1 + 最轻的 L2（仅 format 门禁，
**不上**文档分层）」；实测 1 位贡献者、24 commits、10 notes + 14 revisions。而 §5 的 L2 判据
在 `level >= 2` 时全为硬判据（`ponygo` 的 `if [ "$lv" -ge 2 ]`），含 2.5 文档分层激活
→ **§6 建议的"最轻 L2"在 §5 里不可表示**。spec 全文未讨论停止线，且 §6:167 要求升级录
decision，而 WP 表无任何 ADR/revision 归属。

### P0-2 `status`/`audit` 成为仓库内任意代码执行器

实测三项：① `audit --dry-run` 执行 spec 并生成 `WITNESS.txt`（违反 `--dry-run` 不落盘承诺）；
② `PONYGO_IN_SPEC=1 ponygo status` 跳过 2.3 后仍打印「L0-L2 机械判据**全部 PASS**」（fail-open）；
③ 无 timeout（Git Bash 有 `/usr/bin/timeout` 可用），CWD = 实例根。违反文件头「判定优先只读」。

### P0-3 s14 放宽造成单源性缺口并撤销已记录处置

实测：当前 `.meta/docs-tier/README.md` 与 init 生成物**逐字节相同**；激活后 s14（唯一看守）
必红。放宽后"模板改了、仓库副本没跟"不再被任何测试捕获；且 `review-EXTERNAL-001.md:85`
明记 P2-5 的处置是"纳入 s14 逐字节测试"——本次属撤销。另：spec 引的"先例"不成立，
实测 `docs/AGENTS.md` 与生成物**相同**（不是"已分叉"）。

### P0-4 WP5 漂移报告在健康实例上必然假阳性

实测：`constitution.md` / `meta.yaml` / `README.md` 三处必报漂移（实例本就该分叉）；
仓库还有 40+ 实例独有文件与"模板独有"文件（根 `AGENTS.md`/`CLAUDE.md` 根本不存在）。
比对宇宙未定义，§7 风险表无此行。

### P0-5 `.githooks` 以 100644 提交 → POSIX 上钩子被静默跳过，2.4 仍 PASS（假 L2）

实测 `core.filemode=false` → `git add` 记录 `100644`；POSIX 上 Git 跳过不可执行钩子。
另实测 pre-commit 读**工作区**而非索引：暂存含 L6、工作区改干净 → 钩子 PASS，提交里 L6 落地。

## P1 摘要

| # | 问题 | 要点 |
|---|---|---|
| P1-1 | 门禁白名单不含 `ponygo` | heredoc 的 `0-5` 无看守；`ponygo:34` 正当历史引用逃过 |
| P1-2 | spec 修正清单漏 `README.md:101` 与 `retire` 消息 | 实施已补，但 spec 作为契约不完整 |
| P1-3 | 2.3 可"改后缀绕过"，且 spec 把它写成官方降级路径 | 应删该路径；s27③ 不该锁弱形态 |
| P1-4 | A1/A2/A5/A8 不可机械判定 | A1/A2 依赖本机 hooksPath 且 CI 不跑 status；A5 实为测试脚本手写；A8 与断言无蕴含 |
| P1-5 | 并行边界错 | `tests/run.sh` 被 4 个 WP 共享、README 被 3 个共享；ADR/revision 无归属 |
| P1-6 | release.yml 本任务内永不执行 | 不可验证交付物；README 示例版本未同步 |
| P1-7 | docs-parity 门禁不可复用且制度化多副本 | 建议降为 tests 断言 |

## P2/P3 摘要

- **P2-1** 无 timeout / 无 `PONYGO_CLI` 句柄 → s27④ 递归测试无法确定性实现。
- **P2-2** spec 要求 spec 支持 `--root`，实现契约里没有 → spec/实现已分叉。
- **P2-3** 门禁只禁 token、不校验正确值（`L0-L4`、`0-4` 放过）。
- **P2-4** README「18+ 场景」与实际 26 个不符，无看守。
- **P2-5** 提交 `.githooks` 后 `audit` 的"无本地钩子"缺口与分层报告打架。
- **P2-6** 2.3b 只报最后一个失败 spec，空输出时"输出尾部"为空串。
- **P2-7** s14 未覆盖 constitution（而 WP3 双写它）。
- **P3-1** `docs/HANDOFF.md` 豁免后，其 §六 的规范指引仍传播旧口径。
- **P3-2** 框架自身无根 `AGENTS.md`/`CLAUDE.md` → 判据 1.9 的根链检查被条件跳过。
- **P3-3** 过程风险：spec §10 双审未完成而实施已并发落盘。

## 与 @consultant 的关系

architect 独立复核并**同意** consultant 的 P0-1～P0-4、P1-1～P1-7 实质判断；新增证据是
`audit --dry-run` 实测落盘、护栏 fail-open 原始输出、索引模式 100644/100755、暂存绕过复现、
WP5 假漂移完整清单、`docs/AGENTS.md` 实测 SAME（推翻"先例已分叉"）、§5/§6 不可表示
"最轻 L2"这一结构性矛盾。

## 处置（2026-09-08，维护者裁决 + spec rev2）

| 发现 | 处置 |
|---|---|
| P0-1 停止线 | **采纳**：仓库保持 `level: 1`；L1→L2 可达性由 `tests/run.sh` 场景 28 证明；ADR `implemented/process/2026-09-08-framework-stops-at-l1.md`；§5/§6 矛盾登记为 proposed ADR |
| P0-2 只读不变量 | **采纳**：回滚默认执行；新增 opt-in `ponygo audit --run-specs`（timeout / dry-run 跳过 / 递归 SKIPPED 不计入 PASS / 聚合全部失败）；revision `2026-09-08-spec-execution-opt-in.md` |
| P0-3 s14 | **采纳**：不激活 docs-tier，s14 原样保留 |
| P0-4 WP5 | **采纳**：暂缓，登记 proposed ADR（比对宇宙未定义） |
| P0-5 `.githooks` | **采纳**：不提交 `.githooks/`（与 P0-1 一并撤销） |
| P1-1 门禁范围 | **部分采纳**：门禁整体取消（见 P1-7），口径防复发改由 `tests/run.sh` 场景 29 承担，扫描范围限定 4 个当前态文件 |
| P1-2 清单遗漏 | **采纳**：README:101 与 `retire` 消息已修（后者是真实 bug） |
| P1-3 改后缀绕过 | **采纳**：删除该"降级路径"；设计上不再以扩展名作绕过口 |
| P1-4 验收自欺 | **采纳**：A1/A2 改述（不再声称仓库自身为 L2）；A5 改述为"可达性证据"；A8 拆分 |
| P1-5 并行边界 | **采纳**：spec rev2 标注 `tests/run.sh`/`README.md` 为独占写目标；新增 WP0 拥有 ADR/revision 交付物 |
| P1-6 release workflow | **采纳**：不交付不可验证的 workflow；README 交付可执行的校验和口径；自动化登记 proposed ADR |
| P1-7 门禁复用 | **采纳**：门禁取消，防复发降为测试断言 |
| P2-1/P2-3/P2-6 | **采纳**：timeout 已加；失败聚合已实现；口径断言改"与真源一致" |
| P2-5 audit 口径打架 | **采纳**（间接）：不提交 `.githooks/` 后不再打架 |
| P3-2 根 AGENTS.md | **不采纳（本次）**：框架仓库不投影（宪法处模板态），登记为待办；1.9 的条件跳过行为不变 |
