# Agent Note: 载体分工与 audit 历史项目误报收口

Status: implemented

## Problem

ponygo 的载体分工与审计面存在两类相互放大的失真：文档把同一事实复制到不同自动加载载体，Scratch 规则又只驻留于处理 `docs/` 时才加载的文件；audit 则把空目录、局部 lifecycle、浅 hook 形状或不可判定结果当成有效证据。历史项目因此收到与其真实治理状态不符的分数、gap、WARN 或 JSON verdict。

具体缺陷如下：

1. methodology 的 P3 把 note/doc/skill/gate 四类载体都汇总指向 §5.1，没有分别链接各自展开章节；通用文档标准、外部 DSH 实证与本仓实例路径的边界不清，架构地图也没有指向真实新家 `docs/architecture.md`。
2. Scratch 卫生规则只在 `docs/AGENTS.md` 驻留，非文档任务不会自动加载它，与「每次会话必载」的约束不符。
3. 空 `.agents/notes/` 可凭 `bad_status=0` 的 vacuous truth 获得 Status 分，lifecycle 项只要求四态中的任意一个；hook 评分与 `no_local_hook` gap 各自使用浅探测，和 2.4 的 `gate_24_probe` 结论可能相反。
4. `audit --json` 在 exit 3 时可能经通用非零兜底写成 `fail`；模板基准不可得时 drift 仍可能表现为 `count:0`；ladder 未运行时 coverage 仍可能列出已验证范围。
5. 贡献者探测以 `[ -d .git ]` 为前置条件，linked worktree 的 `.git` 是文件，因而被误判为没有贡献者历史。
6. `revisions/` 冻结检查是 ponygo 框架仓专属规则，但无 `revisions/` 的普通实例也会因父仓历史或冻结提交不可见而收到 WARN。

既有决策边界不变：双根载体分工见 `implemented/architecture/2026-08-31-agents-runtime-vs-meta-truth.md`；Scratch 三级分家见 `implemented/process/2026-10-30-temp-artifact-workspace-standard.md`；Tier 激活见 `implemented/process/2026-10-29-activate-docs-tier.md`；四问审计见 `implemented/process/2026-08-30-audit-four-question-two-tier.md`；exit 3 的 fail-closed 语义见 `implemented/process/2026-11-01-audit-judgement-fail-closed.md`；机读面与覆盖诚实化见 `implemented/process/2026-11-01-audit-machine-surface-and-ai-projection.md`、`implemented/process/2026-11-07-evidence-coverage.md`；`revisions/` 冻结的适用范围见 `implemented/process/2026-11-09-revisions-track-frozen.md`。本条是对这些当前态决策的收口，不撤销其载体边界，也不把 1.9b 搬进 `verify-note.sh`；该备选仍由 `rejected/process/2026-11-09-move-1.9b-criterion-into-verify-note.md` 否决。

## Decision

1. **P3 四类分节引用修正**：`docs/methodology.md` 的 P3 将 note（决策记录）、doc（文档）、skill（技能）、gate（门禁）分别链接到 §2、§5、§3、§4，不再把四类都汇总到 §5.1。本项不新增 P3 direct anchor，不改 constitution、根投影或生成模板；它们保持既有原理链接。
2. **三层文档事实各归其家**：`docs/methodology.md` 承载原理与外部 DSH 实证；`docs/AGENTS.md` 承载通用文档标准（Tier 职责、写作规则、slop checklist）；`.meta/docs-tier/README.md` 是本仓「tier → 实例路径」的唯一映射。不得把通用标准搬回 methodology，也不在 docs/AGENTS 复制实例路径。架构地图的实例路径指向真实新家 `docs/architecture.md`，不再以 methodology + 根 README 冒充架构地图。
3. **Scratch 常载**：`.meta/constitution/constitution.md` 增加 Scratch standing order，经 `ponygo sync` 投影到根 `AGENTS.md` / `CLAUDE.md`。常载摘要至少指明 `.scratch/<yyyy-mm-dd>-<topic>/` 唯一临时边界并链接完整契约；完整规则仍可归 `docs/AGENTS.md`，但它不再是唯一入口。
4. **audit 不让空 notes 白送 Status 分**：真实决策沿用 `count_decisions` 口径（`.md`，排除 `README.md`、`AGENTS.md`、`*.zh.md`）。Status 项必须同时满足 `n_dec > 0 && bad_status == 0`；空 notes 不得因 `bad_status=0` 的 vacuous truth 得分，0 字节或其它缺 Status 的 md 同样不得分。四态结构分独立，要求 `proposed/`、`implemented/`、`rejected/`、`archived/` 同时存在，不再以任意一个目录命中，也不附加 n_dec/bad_status 条件。S/M 总项数仍分别为 10/14。
5. **hook 单一口径**：hook 评分与 `no_local_hook` gap 都消费 `gate_24_probe`；probe 成功才加分且不得产生该 gap，probe 失败则不加分并产生该 gap。不得再用 `core.hooksPath` 非空、目录存在或 `.githooks/pre-commit` 存在另造评分/gap 真值；`gates.local`、2.4 与人读接线报告继续共用同一 probe。
6. **机读 verdict 与证据同源**：`audit --run-specs --json` 的证据不足路径固定为进程 exit 3、JSON `exit:3`、`ladder.verdict:"unverified"`，不得写成 `pass` 或 `fail`；级自洽硬失败仍按既有优先级 exit 1 / `fail`。`exit` 字段始终等于真实进程码，stdout 仍为单行 JSON。
7. **drift 未知不等于零**：`ponygo.audit/1` 的 `drift` 键集合与类型保持 `count` 整数 + `files` 数组，不新增字段。模板基准不可得或比较未完成时固定为 `count:-1, files:[]`，人读仍为「漂移未判定」；README 登记 -1 = 未判定而非数量/错误码。只有真实完成比较才可报告非负 count 与对应 files，0 只表示已判定零漂移。drift 仍是观察项，不改变退出码。
8. **未跑 L1 不得声称 verified**：新增内部 `L1_JUDGED` 真实运行标记，不得只看 `VL_VERDICT` 推断。无 meta、`level:0`、非法 level、提前退出或其它未实际执行 L1 的路径，固定输出 `coverage.verified=[]`、`coverage.unverified=["1.1-1.10"]`、`coverage.reason="l1-not-run"`。只有 L1 实际判定过（判成 FAIL 也算跑过）才可列相应 verified；SKIPPED、未执行与 FAIL 不得互相冒充。
9. **worktree 贡献者可达**：贡献者探测以 `git rev-parse --is-inside-work-tree` 判定仓库上下文，并以 `git rev-parse --verify HEAD` 确认可读历史，再执行既有 `git shortlog -sne HEAD` 计数。不得再以 `.git` 必须是目录为前置条件；同一提交的主工作树与 linked worktree 必须得到相同贡献者数与自适应档位。非 git 或 unborn HEAD 不产生贡献者重型信号。
10. **框架专属检查按适用性退场**：仓库没有 `revisions/` 时，冻结轨道检查为 not-applicable，不读取父仓或框架冻结提交来制造 WARN，人读输出不打印该检查的 PASS/WARN/SKIPPED 结论，分数与退出码不变。框架仓存在 `revisions/` 时，既有 PASS/WARN/SKIPPED 判定、冻结提交 `cbc6f15` 与 README 豁免保持原样。

逐项可观测断言、夹具与兼容边界冻结于 `.dev-team/contract-matrix-carrier-audit.md`。本任务不新增网络或外部 IO，不设置没有测量依据的时延、吞吐或资源阈值，NFR 记录为 not-applicable。

## Alternatives considered

- **为 P3 新增 direct anchor 并同步 constitution/投影/模板**：否决。本任务的断链是四类载体的展开章节指向错误，分别链到 §2/§5/§3/§4 即可；扩到常载投影链是无关改造。
- **把通用文档标准搬回 methodology，或在 docs/AGENTS 与 `.meta/docs-tier/` 双写实例路径**：否决。前者混淆原理/外部实证与通用标准，后者制造实例映射漂移；三层载体各守一种事实。
- **继续以 methodology + 根 README 充当架构地图**：否决。二者分别承载原理/分层与人读骨架，不能替代组合、核心模块、接缝与扩展点的有序地图；真实家是 `docs/architecture.md`。
- **Scratch 继续只放 `docs/AGENTS.md`，依靠 agent 主动阅读**：否决。该文件只在处理 `docs/` 子树时自动加载，无法满足全仓任务的常载要求；常载约束必须进入宪法投影链。
- **空 notes 仍凭 `bad_status=0` 获得 Status 分**：否决。没有决策时「缺 Status 的文件数为零」是 vacuous truth，不证明任何决策合规；但四态是独立结构分，不把内容条件偷塞进结构项。
- **hook 评分/gap 保留浅探测，仅让 2.4 使用 `gate_24_probe`**：否决。同一仓会出现「评分命中但 gap 报缺」或「gap 消失但 2.4 FAIL」；同一事实必须有同一探针。
- **exit 3 沿用「非零即 fail」兜底，或把证据不足写成 pass**：否决。前者混淆硬失败与未验证，后者直接制造假绿；exit 3 的既有语义就是 unverified。
- **drift 不可判时报告 `count:0`**：否决。零是可复现的比较结果，未知是证据缺失；二者不能共用一个机器值。
- **drift 新增 `status:"judged"|"unknown"` 并把 unknown 的 count 改为 null**：否决（Gate-1 重裁）。`ponygo.audit/1` 的键集合与类型已有冻结测试，additive 仍会迫使下游改 schema 消费；复用整数 sentinel `-1` + 空 files 可在不改键型的情况下区分未知，README 明确登记其非数量语义。
- **L1 未跑也保留默认 verified 范围，或只看 VL_VERDICT 推断**：否决。静态默认与 verdict 都无法证明本次进程执行过 L1 判定；必须由真实 `L1_JUDGED` 标记驱动覆盖声明。
- **继续用 `[ -d .git ]` 排除非标准仓库布局**：否决。linked worktree 是合法且常见的 Git 形态，`git rev-parse` 才是布局无关的事实来源。
- **所有仓库都执行 `revisions/` 冻结检查**：否决。该检查依赖 ponygo 框架仓专属轨道与提交历史，对无该轨道的实例没有判定对象，WARN 属于噪声。
- **为本轮新增网络预算、外部 IO 超时或性能数字**：否决。变更只校正本地文档载体、只读判定与报告语义，没有新增网络/外部 IO，也没有可支持数字阈值的测量。

## Consequences

- `ponygo.audit/1` 的 drift 键集合与类型不变，unknown 固定为 `count:-1, files:[]`；schema 名不变，deferred/wave13 的两键字段集合断言不需改写。README 同步登记 -1 的固定语义，消费者不得把 -1 当实际数量或进程码。
- 空 notes 不再获得 Status 分，缺 Status/0 字节文件同样阻止该项得分；四态结构分保持独立。缺任一 lifecycle 不再获得四态项；hook 评分、gap、JSON 与 2.4 报告必须同屏一致。这些变化是在去除误报，不得通过恢复浅探测来凑回旧分数。
- 无 `revisions/` 的普通实例少一类无意义 WARN； ponygo 框架仓自身的冻结检查不放宽。
- 回归基线锚定 `7f991de`：`tests/run.sh` Exit 0、1380/1380；deferred Exit 0、160/160；auditfix Exit 1、297 pass / 39 fail，主要因旧文案与新增 archive 资产使既有夹具失效；当前 `audit --run-specs` Exit 0。完整机器账本见 `.dev-team/regression-baseline-carrier-audit.json`，auditfix 的已知红不得写成全绿。
- 本任务只冻结契约与 ADR，不写 ponygo 业务实现、不写 tests、不执行 git 写操作；本 Agent 未运行 ladder 或回归套件，因此不声称本轮已 verified。收据仅登记当前会话已提供的事实。
