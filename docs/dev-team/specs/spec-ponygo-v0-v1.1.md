# Spec — ponygo v0 收口修复（F1-F6）+ v1.1 增强（rev2，含 reviewer-1 采纳）

> Task: TASK-001 ｜ 复杂度: B ｜ 2026-08-30 ｜ rev2：已采纳 reviewer-1 全部 P0/P1 及主要 P2

## 1. 背景与目标

ponygo 首版（六命令 CLI + 治理骨架 + 审计文档族）已通过三轮对抗审核，但独立复核发现
6 个新问题（F1-F6）。本 spec 覆盖：F1-F6 修复、commit 初版、v1.1 增强（L1/L2 机械判据
入 `status`、meta.yaml 违例告警、自测脚本 tests/run.sh）。

设计不变量（勿破坏）：
- 单文件 CLI、零依赖 bash、`set -u`、LF 行尾、中文输出风格。
- 命令面固定六命令：init/audit/status/upgrade/sync/retire。
- level 唯一真源 = 整数 0-6；meta.yaml 合法键 = `level` + `ai-surface`，其余键违例告警。
- audit 内嵌细目口径 = S 档 10 项 / M 档追加 4 项共 14。
- audit/checklist.md 是全量细目权威真源（骨架8/机制15/精微8）；本次对真源做
  **三处显式判据修订并回写**（见 §2 V1 附注），非"仅实现不改判据"。
- maturity-ladder.md §5 是 L0-L2 判据唯一真源；本次机械化实现 + 回写修订。
- 机器可查缺口 → 非零退出；语义判断 → 显式"靠 review"。
- 三处决策/文件计数共用同一排除集 `{README.md, *.zh.md}`（audit n_dec、status 决策数、
  verify_ladder 1.2），写死、不各搞一套。

## 2. 范围

**修（F1-F6）：**
- F1 口径复发：README.md §4.3 与 audit/depth-selector.md 头注中"骨架 10 + 机制 9 + 精微 8"
  改为"骨架 8 / 机制 15 / 精微 8"；README §4.1 的 `level: L2` 示例改为 `level: 2`，
  "仅一个 level 字段"表述改为"仅 level + ai-surface 两个合法键"。
- F2 空目录：`.meta/decisions/{proposed,implemented,rejected,archived}` 与
  `revisions/{proposed,accepted}` 各加 `.gitkeep`。
  **配套（reviewer-1 P0-2）**：audit 的 rejected 非空判定、gates/skills 非空判定
  同步排除 `.gitkeep`（防占位文件把判据恒真化）。
- F3 init 落地 decisions 契约：`write_skeleton` 在 `.meta/decisions/README.md` 缺失时
  生成与模板仓库 `.meta/decisions/README.md` **逐字节一致**的全量版（内容源收敛为
  CLI 内 heredoc 常量；tests 断言两者一致），修复 constitution 治理结构表的死链。
  定位说明：存量实例要等 upgrade 才能补，本次只保证新 init 完整（reviewer-1 P2-5）。
- F4 占位 README 污染审计：
  a) audit 的 `n_dec`、`n_alt` 排除 `README.md`；
  b) audit 的 gates/skills "非空"判定排除 `README.md` 与 `.gitkeep`；
  c) audit 的 bad_status 排除 `README.md`（把注释里声称的"README 豁免"真正实现）；
  d) 与 `status` 的决策数口径对齐（同一排除集，见 §1 不变量）；
  e) **同步修 audit/checklist.md 1.3/1.4 的检查命令**（加 README 豁免），
     维持"checklist 为准"不变量（reviewer-1 P1-2）。
- F5 守卫与参数健壮性：
  - `cmd_retire` 入口：先无参打印用法（保持现状），带 `--level` 时 `has_meta || die`
    （reviewer-1 P3-3：用法路径不死）；
  - **全局**参数解析 `--level` 缺值时不触发 `set -u` 崩溃：`[ $# -ge 2 ] || die
    "--level 需要取值"`（覆盖 audit 与 retire 两条路径，reviewer-1 P1-5）。
- F6 audit `--level` 校验：非 S/M 时 `die`（帮助文本承诺 S|M）。

**增（v1.1）：**
- V1 status 一键验级：新增独立函数 `verify_ladder`（status 调用；audit 输出尾部
  追加一行"级自洽验证请跑 status"衔接，reviewer-1 P2-1a）。按 maturity-ladder §5 实现：
  - **验级基准（reviewer-1 P2-4 裁决）**：无条件验 `min(声明级, 2)` 及以下全部判据
    （L0-L2 是地基，声明 L3+ 也必须 0-2 自洽）；声明 L3+ 时追加 §2 自证提示（现状行为）。
    纯 L0 长驻（level: 0）只验 0.x，是合法终态。
  - L0：0.1-0.3（.meta 存在 / meta.yaml 存在 / level 字段存在）；0.4 = level 取值
    经 `read_level` 归一（剥 L 前缀）后必须匹配 `^[0-6]$`（reviewer-1 P1-1：加行尾锚）。
  - L1（声明 ≥1 时验）：1.1 decisions 存在；1.2 决策文件数 > 0（排除集见 §1）；
    1.3 lifecycle 顶层目录 ⊆ 四态封闭集；1.4 二级 class 目录 ⊆ 六类封闭集；
    1.5 **每个决策 .md 必须位于 `{lifecycle}/{class}/` 两级之内**（深度 1-2 的裸文件
    即违例；README 豁免；机械化为真源 1.5"人工核对深度"的子集，输出中如实标注）；
    1.6 文件名匹配 `^[0-9]{4}-[0-9]{2}-[0-9]{2}-.+\.md$`（README 豁免；GNU date 可用
    时附带校验日期合法性，不可用降级为"靠 review"提示，且此时不输出无限定的
    "验级通过"字样——reviewer-1 P2-3）；1.7 `Status:` 首词（trim 后、区分大小写）
    与所在 lifecycle 目录一致；**archived/ 豁免规则：Status ∈ {implemented, archived}
    均判过**（真源内部矛盾的显式裁决，回写 maturity-ladder §5 1.7 附注）。
  - L2（声明 ≥2 时验）：2.1 gates/ 存在非 README/.gitkeep 文件；2.2 gates/ 下 *.sh
    过 `bash -n` 语法校验——**输出中标注这是"可运行"的代理判据**，并提示真判据命令
    （`<gate> --help` / 空样本拒绝非零退出）供人工补验；2.3 gates/ 存在负样本 spec
    （文件名 `*.spec.*`，收紧防误配）；2.4 **声明 level ≥ 2 且 hooksPath 未设 → FAIL**
    （"若交付"在声明 L2 时即视为已承诺；WARN-only 会构成假门禁，reviewer-1 P1-4）。
  - 判级失败 → 逐项列出失败项 + 最小修正动作，exit 1；失败项输出**取代**
    现有"去下一级"建议文本（不叠床架屋，reviewer-1 P2-1b）。
- V2 meta.yaml 违例告警：违例键 = 非注释/非空/非 level/非 ai-surface/非缩进行。
  **audit 与 status 都调用同一告警函数**（真源字面说"audit 应告警"，双挂消灭归属
  偏离，reviewer-1 P2-2）。WARN 不改 exit code（真源只要求告警）。
- V3 tests/run.sh：纯 bash 自测（mktemp 场景化，pass/fail 计数，失败 exit 1）。
  场景：
  1. help 六命令；2. init 骨架 + 不投影；3. status 完整（exit 0）；
  4. TODO 拒投影（exit 非 0 且无投影文件）；5. 填槽后 sync 投影 + 幂等；
  6. ai-surface off 跳投影；7. retire off / N / 非法值 / 无 meta（用法不死）；
  8. level L 前缀归一 + `level: 12` 拒绝；9. audit 新 init 确定性命中数
  **断言精确值 `命中 4 / 10`**（.gitkeep 与 README 均不计分）；
  10. `audit --level` 缺值 / 非法值；11. L1 判据（合法决策通过；缺 class 轴、
  坏文件名、Status 不符、archived 态各一例）；12. L2 判据（门禁+spec+钩子齐 → 过；
  缺钩子 → FAIL）；13. meta.yaml 违例键告警（WARN，exit 0）；
  14. 生成 decisions/README 与模板逐字节一致；15. upgrade exit 0。

## 3. 非目标

- 不改 audit 四问记分卡的项数与语义（只修 F4 的判定细节）。
- 不实现 upgrade 实际合并（v+2）、L3-L6 机制、双语配对。
- 不改 HANDOFF 已拍板决策表。

## 4. 技术方案与替代方案

- V1 放独立函数 `verify_ladder`、由 status 调用：audit 回答"四问水位"，status 回答
  "级自洽"；两者退出语义不同，不互相污染（reviewer-1 认可，附 P2-1 毛边已纳入）。
- F4 用"排除 README.md/.gitkeep"而非移走占位文件：保持骨架自解释，判定层豁免。
- F3 全量版常量而非精简版：单一内容源，消灭"两份真相"（reviewer-1 P0 级建议）。
- tests/run.sh 自包含（mktemp 场景），不依赖 bats：零依赖约束与 CLI 一致。

## 5. 影响面与依赖

- 文件：`ponygo`、`tests/run.sh`（新）、`README.md`、`audit/depth-selector.md`、
  `audit/checklist.md`、`maturity-ladder.md`（§5 判据修订回写）、`.gitkeep`×6（新）、
  `.meta/meta.yaml`（注释补 ai-surface 合法键）、HANDOFF.md（挪 docs/HANDOFF.md 归档）。
- 语义变化需同步的文档点（一次列全，防 F1 式复发）：
  README §4.1（level 示例/合法键）、§4.2（"部分需手工跑命令"改为"status 一键验级"）、
  §4.3（细目数字）；CLI 头注与 usage 的 status 描述（补"判据不符 exit 1"）；
  checklist.md 1.3/1.4 命令；maturity-ladder §5（0.4 锚、1.5 子集范围、1.7 archived
  豁免、2.2 代理判据、L0 注合法键）。
- 并行边界：A 线 = `ponygo`、`tests/run.sh`、`.gitkeep`×6、`.meta/meta.yaml` 注释；
  B 线 = 全部文档（README、depth-selector、checklist、maturity-ladder、HANDOFF 搬移）。
  文件不相交（rev2 修正：F4e 的 checklist 同步归 B 线）。

## 6. 风险与回滚

- F4 收紧后存量实例 audit 命中数下降（预期，README 说明）。
- V1 对"目录混入杂项"的项目 FAIL 是判据本意（路径即标签）。
- Windows Git Bash 兼容：sed -i 已验证；date 做可用性探测后降级。
- 回滚 = 3 个 commit（docs 口径 / v0 代码修复 / v1.1），任一可单独 revert。
  （rev2 说明：README 同文件承载 F1 数字与 v1.1 语义两类变更，为避免同文件跨
  commit 拆 hunk，README 整文件归入 docs commit——部分采纳 reviewer-1 P2-6。）
- 实例侧残留不回收：revert 模板不会撤掉已落盘实例中的精简/全量 README 与 .gitkeep
  （reviewer-1 P3-5，可接受）。

## 7. 测试计划

tests/run.sh 场景清单见 §2 V3；实施后全量跑 + 手工回归 HANDOFF §五 验收路径。
测试失败即门禁失败，不得带病收口。

## 8. 验收标准

见 TASK-001。补充（reviewer-1 P2-7）：测试断言精确命中数（`4 / 10`）；F3 一致性
由测试 14 机械断言；README 索引一致性由文件存在性断言覆盖。

## 9. 审核

- [x] reviewer-1（架构/契约视角）：有条件通过 → P0×2、P1×6 全部采纳；
      P2 采纳 P2-1/2/3/4/5/6(部分)/7/8；P3 采纳 P3-1/3/4/5，备忘 P3-2/6。
- [ ] reviewer-2（边界/测试视角）

---

## 10. rev3 — reviewer-2 采纳记录（2026-08-30）

结论：有条件通过。以下条目并入实施范围：

**P0（全部采纳）：**
- P0-1 新增 `.gitattributes`：`* text=auto eol=lf`（至少覆盖 ponygo / tests/run.sh / *.md），
  验收补"新 clone 下 bash ponygo 可运行"。F3"逐字节一致"定义为 **eol 归一后一致**。
- P0-2 测试 9 确定性前提写死：temp 目录**非 git 仓库** + `GIT_CONFIG_GLOBAL`/`GIT_CONFIG_SYSTEM`
  指向空文件 + 显式 `--level S`；所有场景以 `ROOT=$(cd "$(dirname "$0")/.." && pwd)` +
  `bash "$ROOT/ponygo"` 调用（规避 clone 后 exec bit / shebang 问题）。

**P1：**
- P1-1 **不采纳**"修 `||`/`&&` 优先级 bug"——经实证（三种 CASE），shell 左结合下
  `[ a ] || [ b ] && c` 语义为"a 或 b 命中即执行 c"，行为正确，reviewer 误报。
  采纳其精神：V3 增加 M 档确定性计数断言 `命中 4 / 14`（同 P0-2 环境前提）。
- P1-2 真源回写清单补全：maturity-ladder §5 增补 1.2（排除集）、1.6（README 豁免）、
  2.1（README/.gitkeep 豁免）；audit/checklist.md 增补 1.6（rejected 非空加 .gitkeep
  豁免）；status 决策数（ponygo cmd_status）补 `! -name '*.zh.md'` 对齐。
- P1-3 1.5 判据闭合：决策 .md 必须**恰好**位于 `{lifecycle}/{class}/` 两级（depth 1-2
  与 depth ≥4 均违例，README 豁免）；文件遍历用 `find -print0` + `while IFS= read -r -d ''`。
- P1-4 CRLF 防御：verify_ladder / V2 判定前统一剥 `\r`；V3 增加 CRLF meta.yaml 场景
  （不得假 WARN）与 CRLF 决策文件场景（1.7 不得假 FAIL）。
- P1-5 非法 level 裁决：归一后不匹配 `^[0-6]$` → **只验 L0、报 0.4 FAIL、跳过 L1/L2**
  （不做任何未验证值的算术比较）；行内注释不支持（`level: 2 # x` 判 0.4 违例）；
  缩进的 `level:` 行属 V2 违例告警对象（非豁免）。
- P1-6 测试 12 正向分支前置：temp 目录 `git init` + `git config core.hooksPath .githooks`。
- P1-7 TASK-001 非目标同步修订（"不改 §5 真源"→"按 spec rev2/rev3 显式回写"）。
- P1-8 测试 11 补非法日期用例（`2026-02-30-topic.md`：格式合法、date 分支拒绝）。
- P1-9 F3 逐字节一致 = eol 归一后一致；接受实例 README 含模板仓内相对引用（死链）
  并在 spec/风险节文档化——实例定制留待 upgrade 能力。

**P2：**
- P2-1 补场景：重复 init（exit 0 不覆盖）；status 无 .meta（exit 1 不崩）；
  `--dry-run`（init/retire 零落盘）；未知子命令 die；`ai-surface: Off`（**顺带修复**：
  sync 的 off 判定改大小写不敏感，F8）。
- P2-2 测试 13 双命令断言（audit 与 status 都 WARN 且 exit 0）。
- P2-3 降级模式可断言锚：date 不可用时输出固定行 `日期合法性：靠 review`。
- P2-4 记录为已知问题（不修）：sync 的 awk -v body 对反斜杠槽位的转义缺陷；
  CRLF 既有 AGENTS.md 的标记区匹配失效。写入 spec 已知问题清单，留 P9。
- P2-5 2.4 与 checklist 2.2 口径对齐：hooksPath 已设 **且** 钩子目录非空（非 git
  目录等价于未设，FAIL 语义可接受）。
- P2-6 F5 的 `[ $# -ge 2 ] || die` 必须位于 `shift` 之前；测试 7 区分
  "无参用法路径 exit 0"与"--level 无 meta 时 die exit 1"。
- P2-7 V3 增加 F1 口径机械断言（grep 骨架8/机制15/精微8 于 checklist.md）。

**P3 备忘（不实施）：** retire 可升不可降的命名歧义、`level: 08` 八进制边缘（已被
`^[0-6]$` 前置校验挡住）、heredoc 内避免行首 EOF、quoted heredoc 防反引号展开。

## 11. 最终实施清单（A/B 线）

- **A 线（代码）**：`ponygo`（F3 全量常量、F4 a-d、F5、F6、F8、V1 verify_ladder、
  V2 告警函数双挂、cmd_status 决策数对齐、CLI 头注/usage 同步）、`tests/run.sh`（新，
  18 场景）、`.gitkeep`×6、`.gitattributes`（新）。
- **B 线（文档）**：`README.md`（§4.1/4.2/4.3）、`audit/depth-selector.md`、
  `audit/checklist.md`（1.3/1.4/1.6）、`maturity-ladder.md`（§5：0.4/1.2/1.5/1.6/
  1.7/2.1/2.2/L0 注）、HANDOFF.md → `docs/HANDOFF.md` 归档。
- 提交切分：commit-1 docs 口径（B 线全部 + 归档搬移）→ commit-2 v0 代码修复
  （F2-F8 + .gitkeep + .gitattributes）→ commit-3 v1.1（V1-V3）。
