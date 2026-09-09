# Review 记录 —— TASK-002 / spec-ponygo-v2.3 rev1（@consultant 对抗审核）

> 审核者：独立子智能体（@consultant 角色，证伪立场）｜ 2026-09-08
> 对象：`docs/dev-team/specs/spec-ponygo-v2.3.md` rev1 + `docs/dev-team/tasks/TASK-002.md`
> 方法：通读 spec + 仓库实证核实（`ponygo` 源码逐段、`tests/run.sh` s12/s14、`maturity-ladder.md` §3/§5/§6、`git shortlog`）

## 结论

**不通过**（4 条 P0，每条独立足以推翻）。WP3 的口径修正本体与 s28 证据可保留；
WP1 / WP2 / WP4 / WP5 各有 P0 级自相矛盾。重切后可达"有条件通过"。

## P0 问题

### P0-1 `status`/`audit` 执行任意 `*.spec.sh`，违反 CLI 自己的设计约束

- 位置：spec §3.1（2.3b）+ §5（自认"新增副作用面"）；`ponygo:12`「设计约束：判定优先只读；破坏性动作前必须确认（或 --yes）」。
- 问题：把只读判定命令变成仓库内任意代码执行器——`git clone && ponygo status` = 无确认、无超时、无沙箱的任意代码执行；`audit` 更甚（README 把它定义为"旧项目改造"入口，即对陌生遗留仓库执行脚本）。
- 建议：执行判据移出 `status`（opt-in 或 CI 层）；真判据方向是**框架注入非法样本**而非信任用户脚本自证；若坚持执行须 `--no-exec` 默认关、per-spec timeout、递归命中 fail-closed、README 显式披露。

### P0-2 `level: 2` 把本机事实写进仓库真值源

- 位置：spec §3.2 / §7（自认"不可提交/本机事实"）；`ponygo:1248-1256`（2.4 = `git config core.hooksPath`）；`.meta/meta.yaml:5-15`（"不要手填会与目录漂移的副本"）。
- 问题：`level` 是唯一真值源，2.4 判的是本机 git 配置 → 提交 `level: 2` 后任何新鲜克隆/CI 都在声明它不满足的等级；A1/A2 在克隆上必然失败。
- 建议：二选一——(a) 保持 `level: 1`，用 s28 证明 L1→L2 可达 + ADR 记"框架自身为何停在 L1"（停止线，P9）；(b) 坚持 level 2 则先改 2.4 为仓库可观察形状（钩子文件存在且可执行），把 hooksPath 挂载降为 WARN。

### P0-3 WP3 修正清单与门禁断言不一致

- 实测：`README.md:101` 也有"整数 0-6"（spec 漏列）；`ponygo:1538`（用户可见 `retire 目标非法…用 0-6 或 off`）；`ponygo:34` 注释含 `L4-L6`（正当历史引用，但会被全文扫描误报）。
- 问题：门禁扫描范围未定义——扫整个 `ponygo` 立即误报，只扫 heredoc 片段则 `ponygo:1538` 漏检。
- 建议：定义扫描范围（家清单）；补全 README:101 / `ponygo:1538`；断言改"禁止重述档位区间字面量"而非"禁止 L6 token"。

### P0-4 2.3b 以扩展名为判据入口 = 形状判据的伪装

- 位置：spec §3.1 + §7（"降级路径：改成非 `.sh` 后缀"）+ §4.2（否决"解析 spec 内容"的理由）。
- 问题：`mv foo.spec.sh foo.spec.bash` 即从 FAIL 变 PASS，且 spec 官方文档教用户这么做；框架仍只验证"脚本 exit 0"，无法验证"真的构造了非法样本并断言拒绝"——与它否决的方案同属代理判据伪装。
- 建议：诚实标注为"执行型代理判据"；删掉"改后缀绕过"的降级路径。

## P1 问题（摘要）

| # | 问题 | 建议 |
|---|---|---|
| P1-1 | docs-parity 门禁把"同一事实多副本"制度化，与 `docs/AGENTS.md` slop 第一条（留一个家、链其余）冲突；且该门禁断言 ponygo 自己的 README 口径，实例无法复用 | 优先"删副本 + 链家"；确要防复发降级为 `tests/run.sh` 一条断言 |
| P1-2 | docs-tier"激活"= 追加一行标题即过 2.5（s12 即如此），文件顶部仍写"模板态"、仍有 5 个 `【TODO】`；`docs/dev-team/` 在 tier 表无家 | 2.5 补"无 TODO 残留 + 家路径存在"，否则如实降级为 review；tier 表补"工作流记录 → `docs/dev-team/`" |
| P1-3 | WP5 漂移报告在健康实例上必然假阳性（README/constitution/docs-tier 本就该分叉） | 砍掉留 proposed ADR，或先分"模板所有/实例所有"两类 |
| P1-4 | WP4 交付本任务无法验证的 workflow；README 会同时出现 v2.3.0 tag 与 v2.2.0 示例 | release.yml 降 proposed ADR；README 示例版本同步 |
| P1-5 | A1/A2/A5/A8 自欺：audit 报告型不改退出码且依赖本机 hooksPath；s28 走的是测试脚本而非骨架产物；verify-note.sh 只管 `.agents/notes/` | 验证命令补 `git config core.hooksPath`；A5 改述；A8 拆分 |
| P1-6 | 提交 `.githooks/` 会让 audit 不再报"无本地钩子"，但分层表仍说"无"；2.4 只查目录非空、不查可执行 | 2.4 补 `-x`；统一口径；s28 断言钩子真被 git 调用 |
| P1-7 | pre-push 跑全部 `*.spec.sh` 无预算上限，与"中继层 10 秒级"冲突，且 CI 已覆盖 | 改增量或加 timeout/数量上限 |

## P2/P3（摘要）

- **P2-3** `PONYGO_IN_SPEC` 命中时静默降级 PASS 是 fail-open → 应输出 SKIPPED 且不并入"全部 PASS"。
- **P2-4** 停止线论证缺失：`maturity-ladder.md:161`（单人 + 决策密度 ≥1/周 → "仅 format 门禁，**不上**文档分层"）、`:56`（小而美可停 L2/退 L0）、`:52`（框架类型优先 **L4 → L3 → L5**）；实测 1 位贡献者、24 commits、10 notes + 14 revisions、无归档 → spec §4.2 完全没讨论"停 L1 / 先上 L4"。
- **P2-2** 影响面漏项（init 提示、status 描述披露执行副作用）。
- **P3-1** s14 的"模板所有 vs 实例所有"是散在测试里的逐文件白名单 → 落盘 `.meta/skeleton-owned`。
- **P3-2** WP1 会与判据真源漂移（`maturity-ladder.md:142/147`、`ponygo:1257-1259` 标注行未列入影响面）。

## 建议砍掉 / 降级

- **砍**：WP1 的 `status` 执行；WP2 的 `level: 2`；pre-push 全量 spec；"改后缀绕过"降级路径。
- **降级为 proposed ADR**：docs-parity 门禁本体（保留一次性修口径 + tests 断言）；release workflow + tag 验收；upgrade 漂移报告；docs-tier 激活。
- **保留**：WP3 口径修正本体；s27（随 WP1 改写）；s28（改述为"L1→L2 可达性证据"）。

## 升级裁决请求

**是**。理由：①"ponygo 自身该不该到 L2"是停止线价值判断，按 `maturity-ladder.md:167` 须录 decision；② `status` 执行仓库脚本改变 `ponygo:12` 架构不变量，需维护者同意；③ 2.4 判据语义修改属框架规则变更，须走 `revisions/`；④ 2.3 破坏性变更缺迁移面。

## 审核局限

- 未运行 `tests/run.sh` 全量（耗时 5–8 分钟）；s12/s14 结论来自源码通读。
- 审核时工作区为脏树（WP3 已并发实施），`ponygo:34` 的 `L4-L6` 当时仍在。
