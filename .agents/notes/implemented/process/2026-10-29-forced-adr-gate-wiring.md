# Agent Note: 交付即接线——ADR 格式门强制挂载（A1–A5，非破坏性前置插入）

Status: implemented

## Problem

ponygo 的 L1 判据（`maturity-ladder.md` §5 的 1.1–1.9）已经能机械校验 ADR 的**形状**，
`.agents/skills/write-adr/verify-note.sh` 是这条判据的唯一真源。但它只在**人主动跑**时生效：

- 没有任何提交时点的强制——`git commit` 不会调用它，写坏的 ADR（`proposed` 里写现在时
  `## Decision`、`implemented` 里留着 `## Proposal`、`Status` 与目录不一致）照常进主干，
  等到某人某天跑 `ponygo status` 才变红——此时已经是历史债；
- 而"只写不跑"的根因不是缺脚本，是**装配缺失**：`ponygo init` 在 `.meta` 已存在时直接 `exit 0`
  （ponygo:1486-1490），于是 **ponyfun / job_copilot / ponyllm 这些"已初始化实例"——
  也就是真正需要门禁的人群——永远不会获得任何本地钩子接线**。骨架铺得再好，只要"交付即结束、
  不接线"，框架就停在"提供工具"而不是"兑现承诺"。
- 更隐蔽的一层：即使挂了钩子，`verify-note.sh` 读的是**工作区**，而 pre-commit 的输入是
  **暂存区文件名**——`git add` 之后又改文件，校验的就不是将要提交的那份字节（TOCTOU）。
  "门看起来在跑"和"门真的守住了这次的字节"是两件事。

## Decision

把"落了 ADR"这一事实接到**提交时点**的两层门禁上，并保证装配**幂等、非破坏、不可静默缺席**。
资产契约（冻结，A1–A5 同时存在于仓库模板与 `ponygo` 内 heredoc，EOL 归一后逐字节一致）：

| 资产 | 路径 | 契约 |
|---|---|---|
| A1 | `.meta/gates/adr-verify.sh` | 无参 = 校验暂存区改动的 ADR（`--diff-filter=ACMR`，豁免 `README.md`/`AGENTS.md`）；带参 = 校验指定相对路径。自包含 `ROOT=$(git rev-parse --show-toplevel)`；非 git / 无 `.agents/notes` / 无 ADR 变更 → exit 0；任一不合规 → 非零。**不自己判格式**，只补判定真源做不到的两件事：R6 暂存态与工作区**字节比对**（不一致即「ADR 有未暂存改动，请先 git add」并 exit 1）、R7 重命名覆盖。**不写仓库任何文件**（`mktemp -d` + `trap … EXIT`） |
| A2 | `.meta/gates/adr-verify.spec.sh` | A1 的负样本执行判据：临时仓造非法样本 → 断言非零；合法样本 → 断言 0；`PONYGO_IN_SPEC=1` 已存在 → SKIPPED 且**不计入 PASS**；自包裹 `timeout 30`；exit 0 = 自检通过 |
| A3 | `.githooks/pre-commit`（或既有钩子内的哨兵块） | 首行 `#!/usr/bin/env bash`；含精确 marker 行 `# ponygo-gate: adr-verify v1`；哨兵块**插在 shebang 之后**且**逐字节等于规范块**；由 `init` 生成/插入后 `chmod +x` |
| A4 | `.meta/gates/ci-verify.sh` | forge 无关的**门禁逻辑本体**：`verify-note.sh` 整树 + `adr-verify.spec.sh`；恒生成、可本地复现远端结论 |
| A5 | `.github/workflows/ponygo-governance.yml` | 薄适配器：checkout + `bash .meta/gates/ci-verify.sh`，触发 push/pull_request；**按 forge 证据生成**，不进宇宙表 |

装配语义（`ensure_gate_wiring`，`cmd_init` 在 `.meta` 已存在时也执行——R1/R2 的最高优先项）：

- `core.hooksPath` **未设** → 设为 `.githooks` 并**回读校验**；**已设**（含 husky 绝对路径）→
  **一律不动**，直接对该目录下的 `pre-commit` 插入哨兵块（改 hooksPath 会静默停用 husky v9 的
  `.husky/_` 链，属破坏性副作用）；
- `pre-commit` 不存在 → 新建 A3 + `chmod +x`；已接线（含 marker）→ 什么都不做；
  存在但未接线**且可执行** → 把哨兵块**插在 shebang 之后**（无 shebang 则文件最前），
  **原有字节顺序与内容零改动、不动权限**（末尾追加不算接线：以 `exit 0` 结尾的钩子里该块永不执行）；
  存在但**不可执行** → 不改权限（激活沉睡钩子是破坏性副作用），判据 2.4 FAIL 并给出
  「`chmod +x` 或删除该文件后重跑 init」；
- 判据 2.4（`maturity-ladder.md` §5）同步加强为五条 AND：① `hooksPath` 已设 ② 先展开 `~` 再归一化
  （`pwd -P`/`realpath`）后目录内 `pre-commit` 存在 ③ 可执行（`-x`） ④ 哨兵块（BEGIN..END 区间）
  **逐字节等于**规范块（含 marker 行与非注释调用行；"含某行"式判据被封死） ⑤ `<root>/.meta/gates/adr-verify.sh` 存在。
  ①–⑤ 全真才 PASS（编号不变，结论行文案不变）；FAIL 文案**按因分支**给补救
  （非 git / 目录不可达 / 钩子不可执行 → `chmod +x` / 块不合规 → `bash ponygo init`）。

## Alternatives considered

以下逐条对应终裁的 R1–R15 裁决（`plan-freeze.md` §1 + §6 v2 修订），尤其登记**被否决**的方向，
因为它们是下次最容易被人"重新发现"的诱人选项。

**R1 `.meta` 已存在即 `exit 0` 早退** → **采纳**（废除早退，改为不重铺骨架但仍执行
`ensure_gate_wiring`）。备选"实例请手动重跑 `ponygo init`"：否决，目标人群正是"已初始化"的仓，
让他们手动补装配等于把装配责任推回用户，实测不会发生。

**R2 `cmd_upgrade` 用 mktemp 非 git 目录造基准** → **采纳**（`git config` 只许出现在
`cmd_init`/`ensure_gate_wiring`，严禁进 `write_skeleton()`）。备选"把 git config 放骨架生成里统一处理"：
否决，会让 `upgrade --check` 的基准生成在非 git 目录必失败，把一条稳定命令变成 flaky。

**R3 全仓无 `chmod`（非可执行钩子被 git 静默忽略）** → **采纳**（生成即 `chmod +x`；2.4 查 `-x`）。
备选"信任用户自行 chmod"：否决，git 对不可执行钩子**无声跳过**，没有任何反馈面，属于必然会复发的
静默失败。

**R4 "内容不同 → 覆盖"会销毁用户既有 pre-commit** → **采纳**（禁止覆盖）。终裁 v2 进一步把
v1 的"fail-closed 拒绝 + 打印补救片段"也否决了：**fail-closed 在正常装配路径上制造非零退出**，
把"框架没接线"变成"你的提交失败"，代价转嫁给用户且对 husky 项目无从自助（见 §6.1）。
故最终形态 = **哨兵块非破坏性插入**（shebang 之后、既有字节零改动、可删块回退、可重复执行不重复插入，
写入走「临时文件 + `chmod` + `mv -f` 原子替换」并由 `flock` 保护）。
**被否决的两条**：① 覆盖（销毁用户逻辑）；② fail-closed 非零退出（正常路径不应红色）。

**R5 `grep 'adr-verify\|verify-note'` 一行注释即骗过** → **采纳**（判据要求哨兵尾行 + 块内
**非注释**行调用 + `test -x` + A1 存在）。备选"只查 marker 行存在"：否决，注释即证据等于没有证据。

**R6 TOCTOU（verify-note 读工作区，pre-commit 喂暂存区文件名）** → **采纳**（先 `git show :<path>`
与工作区字节比对，不一致即拒绝并要求 `git add`）。备选"让 verify-note 支持读暂存区"：否决——
真源是只读资产，改它要动 L1 判据的行为面；把"读哪份字节"的差异留在门禁层（A1）处理，真源保持
"读工作区"的单一语义。附带处理：属性层 EOL 归一（`.gitattributes eol=lf`）不是未暂存改动，
用 `git diff --quiet` 兜住该假阳性。

**R7 `--diff-filter=ACM` 漏掉重命名（`git mv` 绕过）** → **采纳**（`ACMR`，并豁免 `README.md`/
`AGENTS.md`）。备选"只查 `A`/`M`，重命名交给 review"：否决，`git mv` 是最省事的绕过路径。

**R8 把实例可编辑文件塞进 `UPGRADE_UNIVERSE` 会永久 drift 红** → **采纳**（宇宙表只加 A1/A2/A4）。
备选"全部五个资产都进宇宙表以保证一致性"：否决，A3/A5 注定被用户编辑（追加自己的钩子逻辑、
换 CI 触发），把它们当不可变资产 = 让每个实例长红。

**R9 hooksPath 字符串相等判等（绝对路径/符号链接误判）** → **采纳**（`realpath`/`pwd -P` 归一后比较）。
备选"同时接受字符串相等或 `cd && pwd` 相等"：等价，选归一化单一路径以免两套比较分叉。

**R10 `maturity-ladder.md:143` 2.4 真源未同步（ADVISORY）** → **采纳**（本次同步改写 ladder 2.4 行 +
注，判据加强但不改编号）。备选"只在 CLI 里加强、文档滞后"：否决，ladder 是 CLI 判据的**唯一真源**，
代码领先文档 = 下一次评审必抓的漂移。

**R11 钩子执行受版本控制脚本 = 供应链面（ADVISORY）** → **部分采纳**（登记为下面 Consequences
的 Known risk，论证见该节："只读/无网络"**不是**有效缓解；钩子内 sha256 pin 不在本期范围）。
备选"立刻给钩子加内容 pin"：推迟——pin 需要发布侧生成清单 + 校验时机设计，本期做会造出半成品的
假安全感。备选"用 `CODEOWNERS` 做缓解"：接受为**后续事项**（本次不实现，见 Consequences）。

**R12 维护税/最小闭包：建议砍 CI 资产（ADVISORY）** → **部分否决**（保留 CI，但拆成
「forge 无关的真实门脚本 A4」+「薄适配器 A5」）。备选"全砍，只留本地钩子"：否决——本地钩子
`--no-verify` 可绕且每台机器都要装；备选"直接写 GitHub workflow 当门禁本体"：否决——门禁逻辑
落在平台 YAML 里就不再"真实可执行"，非 GitHub 项目等于零覆盖。**被否决的两条**：砍 CI、
把逻辑写进平台壳。

**R13 并行两条 `ponygo init` 竞态（ADVISORY）** → **部分采纳**（写 hooksPath 后**回读校验**；
不加 flock）。备选"加文件锁"：推迟——锁的获取/释放本身要新增失败模式，本期用"写后回读"把
最痛的静默失败面收掉即可。

**R14 非 git 目录下 `git config` 不可用** → **采纳**（非 git → 不设 hooksPath、打印
`git init` 后重跑的指引；`init` 保持 exit 0，多场景测试依赖这一语义；2.4 在非 git 下自然 FAIL）。

**R15 空 stdin 下 `confirm_or_skip` 静默 no-op** → **已作废**：`--yes` 与交互确认整体移除
（确认既不防误操作，又制造两条逃逸路径：非 TTY 直接失败 / 交互读失败静默取消）。原裁决是
"非 TTY 且未给 `--yes` → `die`「非交互环境请显式 --yes」"，属在一个不该存在的机制里做局部修补；
正确修法是删掉"要不要确认"这个问题本身——写入路径本就幂等/只增不改，"确认"无法变更任何结果。
现行语义：`init` 不读 stdin、无 `--yes`，`--dry-run` 是唯一预览手段。取代者见
`implemented/process/2026-10-29-remove-yes-and-adapt-alt-governance.md`。

**否决：新增 `ponygo gate adr` 子命令**（终裁 §6.4）。它看起来最"框架正统"——一个统一的
门禁入口。否决理由：会在 CLI 内造**第三份** 1.1–1.9 判定逻辑副本（真源 = `verify-note.sh`，
CLI 已有一份 `verify_ladder`），违反 P9 负空间；判定真源必须保持单一可读脚本。
备选"让 CLI 直接 exec `verify-note.sh`"：那正是不需要新子命令的理由。

**否决：无条件生成 A5（GitHub workflow）**（终裁 §6.3）。备选"无论什么仓都铺 `.github/workflows/`"：
否决——非 GitHub 仓被塞入一堆从不运行的 YAML = 假接线（静默缺席的反面：静默假在场）。
改为按 forge 证据生成：检出 GitHub → 生成 A5；检出其它 provider → 不生成，`status`/`audit`
输出一行可执行指引「远端层未接门 → 在你的 CI 里加一步 `bash .meta/gates/ci-verify.sh`」；
都没有 → 「远端层：无 CI（本地层已强制）」。**已否决的是"无条件生成"，不是"不告知"**。

**否决：`audit`/`status` 加 `--strict`**（终裁 §6.4）。备选"加严格档让某些实例先宽后严"：
否决——`ponygo audit` 无此旗标（仅 `observe` 有），且"零开关、零逃生舱"是本次的用户硬约束 C2；
真正需要分档的场景是"非 GitHub 的远端层"，那已由 6.3 的证据式生成解决。

**推迟：dev-team L3-P「六问 + 第 7 问决策追溯」**（终裁 §6.4）。跨仓依赖 `dev-nfr-lint.py` 的
`REQUIRED_FIELDS`，本期不动；作为独立 ADR 后续交付，避免这次变更把两个仓的判据耦合在同一提交内。

**保留但收紧：A2 负样本 spec**（终裁 §6.4）。备选"ponygo 自己不做负样本 spec"：否决——
ponygo 自身纪律是"每门配负样本执行判据"，框架仓自己豁免就是双标；但必须 `mktemp -d` +
`trap … EXIT` 清理，且 `PONYGO_IN_SPEC=1` 时 SKIPPED（不计入 PASS）。

## Consequences

**已知代价（四条，诚实登记）**：

1. **R11 供应链面（论证已订正，Wave-2 B5/F13）**：钩子在每次提交时执行受版本控制的脚本
   （`.meta/gates/adr-verify.sh`），**钩子跑的是工作区字节而非 index 字节**——实测在第 2 行插一句
   `touch /tmp/x`，此后任意 `git commit` 都会执行它。因此"该脚本只读、无网络、无写操作，可 review 验证"
   **不是有效缓解**（循环论证：能改这个文件的人，恰恰就是被 review 假设排除掉的那个人）。
   诚实表述：**仓库写权限本来就等价于代码执行权**——同一个人还能改 CI 配置、改 `.gitattributes`
   （`filter.*.clean` 直接执行命令）、改 `Makefile`/`package.json` 脚本。**本机制不新增特权面**，
   它只是把"已存在的能力"挪到一个每次提交都必然经过的位置（可见性上升，权限不变）。
   缓解方向（登记为**后续事项，不在本次实现**）：`CODEOWNERS` 覆盖 `.meta/gates/**` 与 `.githooks/**`，
   让这些路径的改动至少需要一个非作者的 reviewer；内容 sha256 pin 同理推迟（需发布侧清单 + 校验时机设计，
   本期硬做只会造出半成品的假安全感）。
2. **6.1 不改 hooksPath 的代价**：husky（或其它外来钩子目录）项目的本地层归属 `husky` 目录，
   门禁块被插入到 `.husky/pre-commit` 的 shebang 之后；`git config core.hooksPath` **无法一键复原**——
   想撤掉门禁必须编辑那个文件（删哨兵块）。对 husky 用户，这是"非破坏性"换来的可逆性折损。
3. **6.3 CI 条件生成的代价**：非 GitHub 项目没有 A5，远端层需要人工加一步
   `bash .meta/gates/ci-verify.sh`——门禁在那里不是自动的，只被显式告知（不静默）。
4. **双写维护税**：A1/A2/A4 三处同源（仓库模板文件 + `ponygo` 内 heredoc + 实例落盘），
   外加 A3/A5 的两处（模板 + heredoc）。任何资产改动必须三处齐改并 diff 验证，后期若某实例
   长期落后，`upgrade --check` 会报 drift（宇宙表只登记 A1/A2/A4，正是为了让这个信号可控）。

**已知边界（ADVISORY，Wave-2 审核接受，登记不实现）**：

1. **`git mv` 把 ADR 移出 `.agents/notes/`、或 `git rm` 删除 ADR → 不做格式校验**。
   理由：这两种操作之后该路径**已不再是 ADR**（不再有被提交的决策记录语义），门禁对"没有 ADR 的提交"
   本就放行（`无暂存 ADR 变更 → exit 0`）。守它需要一条"删除/搬走也必须校验"的路径级判据，
   收益低而误报高（README/AGENTS 豁免、跨目录搬家的中间态都会被误伤）。
2. **钩子主路径上的本地子进程没有 `timeout`**（`git` / `find` / `bash` 全为本地进程，超时风险低）。
   与 A2 不同：spec 里包 `timeout 30` 是因为 spec 会**执行**仓库脚本（不可信代码）；A1/A3 主路径只调
   `git`/`find`/`bash` 与判定真源，挂死面来自本机文件系统而非外部代码。真要兜底应由钩子层加
   `timeout` 包装——那是实例可编辑面（A3），不在框架资产里硬编码。

**覆盖缺口（本次实测发现，登记为已知限制）**：`.agents/notes/README.md` 规定每条决策必含
`## Alternatives considered`，但判定真源 `verify-note.sh` 的 1.1–1.9 **不含**这一项
（`grep -c Alternatives verify-note.sh` = 0）。因此 A1/门禁**不拒绝**缺备选节的 ADR——
A2 把该 case 做成**探针**：真源将来覆盖则断言拒绝，未覆盖则 `WARN` 并声明不计入 PASS。
为什么不在 A1 里补一个 grep：同一判据两份实现必然漂移（P9），且会造成"`ponygo status` 绿、
门禁红"的双真值。**修法方向**：给 verify-note 加 1.10（真源侧），由下一次框架变更统一做。

**配套改动（同一次变更内）**：

- `.meta/gates/` 新增 A1/A2/A4，`README.md` 增「承诺 → 非零退出命令」表、负样本 spec 说明、
  非破坏性挂载方式；
- `.githooks/pre-commit` 落地（本仓 dogfood，需 `git config core.hooksPath .githooks` 激活）+
  `chmod +x`；
- `.github/workflows/ponygo-governance.yml`（A5）；
- `maturity-ladder.md` §5 判据 2.4 行与注同步加强（R10）；
- `.agents/skills/write-adr/SKILL.md` 增「非平凡判定边界」一节：非平凡/平凡清单 + 明写
  「判定权在模型，框架只锁落盘后的格式门」（用户硬约束 C1）；
- `ponygo` 侧（Executor 写域）：`ensure_gate_wiring` + `has_meta` 早退废除 + `write_skeleton`
  去 `git config` + `verify_ladder` 2.4 五条 AND + `cmd_upgrade` 基准不受
  git config 污染（原 R15 非 TTY `die` 已作废，见 `implemented/process/2026-10-29-remove-yes-and-adapt-alt-governance.md`）；
  `tests/` 侧（Test Agent 写域）：s12/s24/s28 正例夹具补 marker + wiring +
  chmod + 新增装配/追加/不可执行分支用例。

**连锁效应（预期，非缺陷）**：已声明 L2 但尚未接线的实例（如 ponyfun / job_copilot），
`ponygo status` 会由 0 变 1——这是判据加强的**正确**结果（原先的"PASS"只是因为旧 2.4 只看了
`core.hooksPath` 字符串）。补救 = 重跑 `ponygo init`（幂等补齐）后 `chmod +x`。

**框架规则细节、Migration 与验收口径**：见 `revisions/accepted/2026-10-29-forced-adr-gate-wiring.md`
（框架自身演进提案：Problem / Decision / Alternatives / Consequences / 验收）。
