# 分层细目库（checklist）—— ponygo 审计的逐项检查表

> 本文件是**全量细目库**——审计打分时逐项参照的完整检查表。分量表（`scorecard.md`）判
> "维度大概在哪档"，本文件判"具体缺哪一条、命令是什么、最小改进动作是什么"。
>
> **口径声明（2026-11-11 修订，取代旧「权威以本表为准」表述）**：
>
> - **两套编号独立**：本表编号是「问×序号」（如 `4.7` = 问④第 7 条），与 `maturity-ladder.md` §5
>   的**升格判据号**（如 `1.7`）**同形不同义**——两套编号互不映射，禁止互相代入。凡引用升格判据
>   **必须写全「判据 1.7」**并指回 `maturity-ladder.md §5`；只写「1.7」时默认指判据，不是本表条目。
> - **计数派生，不手填**：命中数与总项数一律以 `ponygo audit --json` 的 `hits` / `total` 为准
>   （CLI 内嵌项是本表的**子集**——子集不是冲突）。本文不写会漂移的副本数字；正文出现的数字
>   只表示「本表条目数」（可由表格行数核对），**判分一律以 JSON 为准**。
> - **冲突以判据真源为准并同批修正双方**：`ponygo audit` 内嵌项与本文不一致时，判据口径以
>   `maturity-ladder.md` §5（及其实现 `.agents/skills/write-adr/verify-note.sh`）为唯一真源，
>   **两份都要改到一致**——不保留"以某一份为准"的单边权威。
>
> 结构：按**四问 × 三层**组织。三层 = 骨架层（判"有没有"）/ 机制层（判"对不对"）/
> 精微层（判"深不深"，首版标 `[future]` 不启用）。
> S 档只查骨架层，M 档追加机制层，L 档（future）才含精微层。

---

## 问① 决策记在哪

### 骨架层（S 档）

| # | 子项 | 判定（布尔命题） | 检查命令（现成） | 失败时最小改进动作 |
|---|---|---|---|---|
| 1.1 | 有专用决策载体 | 存在一个专门目录承载决策记录（ponygo 或替代形态均可） | `ls -d .agents/notes docs/adr docs/decisions docs/architecture/decisions 2>/dev/null \| head -1` | 建 `.agents/notes/` 或任意 ADR 目录，写第一篇 ADR |
| 1.2 | 路径编码状态 | 四态目录齐全 | `ls -d .agents/notes/{proposed,implemented,rejected,archived} 2>/dev/null` | 补齐缺失的四态目录 |
| 1.3 | 有决策记录 | 决策文件数 > 0（README 豁免） | `find .agents/notes -name '*.md' ! -name 'README.md' ! -name '*.zh.md' \| wc -l` | 写第一篇 ADR，落 `implemented/` 或 `proposed/` |

### 机制层（M 档追加）

| # | 子项 | 判定（布尔命题） | 检查命令 | 失败时最小改进动作 |
|---|---|---|---|---|
| 1.4 | 状态与内容一致 | 无缺 `Status:` 头的决策文件（README 豁免） | `find .agents/notes -name '*.md' ! -name 'README.md' -exec grep -L '^Status:' {} + \| wc -l` 应为 0 | 给缺头文件补 `# Agent Note:` + `Status:` 前两行 |
| 1.5 | 有 Alternatives 节 | 每条决策含候选方案 | `grep -rl 'Alternatives' .agents/notes \| wc -l` ≥ 记录总数 | 补 `## Alternatives considered` |
| 1.6 | 被否选项留痕 | `rejected/` 非空（排除 `.gitkeep`/`README.md` 占位），且每条留痕可追溯到来源（provenance 链回被否决方案所在的 ADR）——空目录/占位文件不计分，"某处提过一嘴"不算留痕 | `ls -A .agents/notes/rejected/ \| grep -v -e '^\.gitkeep$' -e '^README\.md$' \| wc -l` > 0；人工确认该条 `Status:` 首词为 `rejected` 且带实质理由（1.7 机械判）并有 provenance 句/段 | 把被否决的方案落一条 `rejected/{class}/` 记录（一行否决理由 + 指向来源 ADR 的 provenance + 当时的备选比较） |
| 1.7 | 触发条件枚举化 | 有一份"何时必须写"的枚举清单 | `grep -rl "非平凡变更\|触发规则" .meta/ docs/ 2>/dev/null \| head -1` | 写触发规则（命中任一即写，纯机械豁免） |
| 1.8 | supersession 当次处理 | 新增记录时替换旧记录在同一变更 | `git log --oneline -5 -- .agents/notes \| wc -l` 且无残留被弃记录（语义） | 靠 review；建 supersession 审计习惯 |

### 精微层（`[future]` 首版不启用）

- 1.9 双语/多语言配对的完整性（`.i18n.yaml` 一致性哈希）——依赖 L5 机制。
- 1.10 决策语料的 GC 卫生（被完全取代的记录是否已 consolidation）。

---

## 问② 承诺怎么强制

### 骨架层（S 档）

| # | 子项 | 判定 | 检查命令 | 失败动作 |
|---|---|---|---|---|
| 2.1 | 有实质门禁 | `gates/` 存在有效门禁文件 | `find .meta/gates -type f ! -name 'README.md' ! -name '.gitkeep'` | 放第一个非零退出的门禁脚本 |
| 2.2 | 门禁脚本可运行 | 门禁脚本语法可解析，非零退出表达拒绝 | `find .meta/gates -name '*.sh' -exec bash -n {} +` | 修语法；人工补 `<gate> --help` / 空样本非零拒绝 |
| 2.3 | 门带负样本 spec | 有实质负样本 spec，**且 L2 至少 ≥1 个实例门**（框架门 A1/A4/A6/A8 不计）、每个实例门配同 Stem、同语言后缀的 spec，**且该配对 spec 含真实拒绝断言**（`exit [1-9]` / `return [1-9]` 落在代码位置；注释与 echo/printf 字符串不算证据） | `find .meta/gates -type f -name '*.spec.*'`；`bash ponygo audit --level M` 逐门配对 + 拒绝断言扫描（扫描面 = 与门配对的 spec） | 补 `foo.sh ↔ foo.spec.sh` 或 `foo.ps1 ↔ foo.spec.ps1`，并在 spec 里写一条「违规输入必须被门拒绝」的断言；编排器 `ci-verify.sh` 豁免 |
| 2.4 | 本地 ADR 门已接线 | `core.hooksPath` 指向的 `pre-commit` 存在且可执行，含规范 ADR 接线哨兵块且位于首个顶层 `exit`/`exec` 之前；`.meta/gates/adr-verify.sh` 存在 | `bash ponygo status` 的 2.4 判据 | 用 `bash ponygo init` 补齐接线与资产；不可执行时先 `chmod +x <hook>` |

### 机制层（M 档追加）

| # | 子项 | 判定 | 检查命令 | 失败动作 |
|---|---|---|---|---|
| 2.5 | 分层（本地 vs CI）各抓各的 | 本地窄、CI 全，不重复跑 | 语义，见 `scorecard.md` 问② | 靠 review |
| 2.6 | 绕行可控 | 有 bypass 记录/上报机制 | 语义 | 靠 review |
| 2.A | 资源隔离（原子分配，靠 review） | 并行测试的共享资源由原子分配器获取，禁先探后占 | review 程序：抽新增测试各一例 → 记 F1–F7 分类 → 复现阶梯到首个签名（细则家见 methodology §4.7；检查示例非穷尽：固定路径含 POSIX `/tmp` 与 Windows `%TEMP%` 等价物，动词不限 kill/abort/close 三词） | 补原子分配 + review 记录 |
| 2.B | 就绪与完成等待（状态同步，靠 review） | 断言等被测方拥有的可观测就绪/完成信号；超时只做上界；固定 sleep 不充当证据 | 同上三步 review 程序 | 补状态等待 + review 记录 |
| 2.C | 处置到静默（quiescence，靠 review） | 清理获取后立即注册；关闭/取消后等到完成信号才算收尾 | 同上三步 review 程序 | 补完成等待 + review 记录 |

> 读者指引：2.A–2.C 为 active；2.7/2.8 仍 `[future]`；2.7/2.8 激活时顺延编号、本附录号不重编。
> 计数说明：CLI 内嵌项是本表的**子集**（子集不是冲突），命中数与总项数一律以
> `ponygo audit --json` 的 `hits` / `total` 为准，本表不再写死会漂移的副本数字。
> 编号说明：本表编号（`问×序号`）与 `maturity-ladder.md` §5 判据号同形不同义——引用判据须写「判据 1.7」。

### 精微层（`[future]`）

- 2.7 生成物漂移门（`gen-*.ts --check` 逐字节比对）——依赖 L3/L4 机制。
- 2.8 覆盖率分区合并、workflow 形状契约。

---

## 问③ 重复劳动怎么复用

### 骨架层（S 档）

| # | 子项 | 判定 | 检查命令 | 失败动作 |
|---|---|---|---|---|
| 3.1 | 有技能目录 | `skills/` 存在 | `ls -d .agents/skills 2>/dev/null` | 建 `.agents/skills/` |

### 机制层（M 档追加）

> 3.2–3.5 已由 `ponygo audit` **只读机械实现**（解析 frontmatter 与正文节，围栏感知；不执行仓库脚本、
> 不新建门禁）。不齐项输出 gap `skill_shape_incomplete` 并附逐技能最小修法。
> 技能三层归属（基线 / 模板库 / 实例自有）的规则家是 `.agents/skills/README.md`。

| # | 子项 | 判定（布尔命题） | 检查命令 | 失败动作 |
|---|---|---|---|---|
| 3.2 | 有至少一个**实例自有**资产化流程 | 排除基线三名（write-adr/change-review/governance-review）与带 `.ponygo-installed` 的库安装副本后，技能目录数 > 0 | `ponygo audit`（人工等价：`find .agents/skills -mindepth 1 -maxdepth 1 -type d` 后逐个排除上述两类） | 把"每三次重复劳动"资产化为技能（基线不算，库安装不算） |
| 3.3 | 技能带触发式 description | 每篇 `SKILL.md` 的 frontmatter `name` 与目录同名，且 `description` 内联触发条件（`何时用`/`Use when`/`When to use`/`trigger`） | `ponygo audit`（人工等价：逐篇 `grep -n '^name:\|^description:' .agents/skills/*/SKILL.md`） | 补 frontmatter 触发式 description |
| 3.4 | 技能带五要素 | 每篇含 `## 真相源` / `## 步骤` / `## 校准样例` / `## 验证与报告`（英文等价允许；围栏内标题不算在场） | `ponygo audit`（人工等价：逐篇 grep 四节标题） | 补缺的节；校准样例须正反例成对 |
| 3.5 | 三层归属可辨 | 库安装副本带 `.ponygo-installed`；基线三篇在场；库文件齐（缺失只提示，不判失败） | `bash .meta/skills-library/install.sh check`；`ponygo status`（可选资产缺口行） | 跑 `ponygo init --repair-skeleton` 补库文件；副本重新 `install` 或确认 `check` 三态 |

> **能力缺口建议（advisory，不计分）**：`audit` 读 `.meta/skills-library/catalog.tsv`，按证据规则
> （笔记类别计数、归档封印数、文档规模、Web/测试/发布面）打印候选与安装命令。**必要性是语义判断**，
> 不计分、不改退出码；未到阈值不装不失败。库技能是框架交付物，**不计入 L3 证据**。

> **L4 解冻前置**：SKILL.md 的完整格式契约（五要素 + 契约头部示例 + 五条纪律）见
> `.agents/skills/README.md`；"第三次重复"计数机制仍属 L4 依赖的未交付物（maturity-ladder §2）——
> 它是语义判断，不装假门禁；技能形状判据已以 audit 只读审计落地，不预建独立门禁（空门禁是被永久引用的死重）。

### 精微层（`[future]`）

- 3.6 调用权限分层（`disable-model-invocation`）——重型流程须只许用户点名。
- 3.7 证据链完整性（GUI 改动的真实录屏证据）——依赖 L4+。

---

## 问④ 过时怎么退场

### 骨架层（S 档）

| # | 子项 | 判定 | 检查命令 | 失败动作 |
|---|---|---|---|---|
| 4.1 | 有已封印归档件 | 存在 `manifest.sha256` 且含 **≥1 条格式合法的登记条目**（`<64 位小写 hex><两空格><仓库相对路径>`；空 `archived/`、空 manifest、只有注释行均记 0 分）。**只判存在性与格式**——"manifest 与归档件逐一一致"不在此项，由 A6 `archive-verify.sh check` 判（4.2）；只读纪律下 `audit` 不执行仓库脚本 | `test -s .agents/notes/archived/manifest.sha256 && grep -cE '^[0-9a-f]{64}  [^ ]' .agents/notes/archived/manifest.sha256`（输出 ≥1） | 归档第一条 implemented：`git mv` 进 `archived/{class}/` 后跑 `bash .meta/gates/archive-verify.sh seal` |

### 机制层（M 档追加）

| # | 子项 | 判定 | 检查命令 | 失败动作 |
|---|---|---|---|---|
| 4.2 | 归档被冻结 | 归档件有哈希封印 manifest，且封印与归档件双向一致（篡改/缺条目/孤儿/重复/非追加写入任一即不成立）——此项**由 A6 判**，审计层只给命令、不代跑（`audit` 是只读命令，不执行仓库脚本） | 人工跑 `bash .meta/gates/archive-verify.sh check`（manifest 的固定家 = `.agents/notes/archived/manifest.sha256`；CI 由 A4 第 3 段与 A5 自动跑） | 恢复归档件原字节，或按 append-only 跑 `bash .meta/gates/archive-verify.sh seal` 补封印 |
| 4.3 | 搜索隔离过期 | `.rgignore` 排除 archived | `grep -l archived .rgignore 2>/dev/null` | 在 `.rgignore` 排除 archived 目录 |
| 4.4 | 退场有判据 | 归档/拒绝不是按字数或年龄 | 语义，见 `scorecard.md` 问④ | 靠 review |
| 4.5 | supersession 同 PR | 被取代记录同一变更删除 | 语义 | 靠 review |
| 4.7 | 负空间的复活条件立法（2026-11-11 解冻：机制层，形状判据） | `implemented/simplification/` 下的 note 含**围栏外**的 `## Reintroduction conditions`；若同条含 `## Removed surface`，还须含至少一行检索收据（行内含 `rg` / `grep` / `git grep`） | `bash .agents/skills/write-adr/verify-note.sh`（判据 **1.11**，见 `maturity-ladder.md §5`） | 补 `## Reintroduction conditions`（写清"什么条件下把这块能力接回来"）与检索收据行；**复活条件是否真成立、检索是否真做过 = 靠 review** |

> 4.7 由精微层解冻到机制层（号不重编）：解锁的是**形状**（那两节在场），不是**语义**（条件能否指导
> 复活）——后者永远靠 review，登记在 `.agents/notes/README.md`「非机械项」表。判据真源在
> `verify-note.sh` 的 1.11 段，`ponygo audit` 只读不执行仓库脚本，故本项检查命令是"人工跑真源"。

### 精微层（`[future]`）

- 4.6 依赖政策审计（换依赖过审）。

> 4.7（复活条件立法）已于 2026-11-11 解冻进机制层（见上表），此处不再列为 `[future]`；
> 精微层剩下的都是依赖未交付机制或纯语义判断的项。

---

## 用法小结

- `S 档`（起步/小项目）：只跑「骨架层」各问，共 9 项；命中为 0 的层面**就此打住，不再深挖**（连 ADR 目录都没有时，问词数预算是废话）。
- `M 档`（有治理基础但欠体系）：追加「机制层」（19 项）。
- `L 档`（monorepo/多栈/强合规）：「精微层」（7 项）标 `[future]`，首版不启用——其中半数检查点依赖尚未交付的机制（双语配对、生成物漂移门、覆盖率分区）。

> 上面三个数字是**本表条目数**（可数表格行核对）。**判分计数不在这里手填**：跑
> `ponygo audit --json` 取 `hits` / `total`——CLI 内嵌项是本表的子集，两者不要求相等，
> 出现差额时按 `maturity-ladder.md §5` 判据真源对齐（见文首口径声明）。

> 打分 = 命中计数；每个 0 分点直接映射右列一条「最小改进动作」。这是审计可复现的来源——同一个盘面、不同人跑，命中数一致。
