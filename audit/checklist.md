# 分层细目库（checklist）—— ponygo 审计的逐项检查表

> 本文件是**权威细目库**——审计打分时逐项参照的完整检查表。分量表（`scorecard.md`）判
> "维度大概在哪档"，本文件判"具体缺哪一条、命令是什么、最小改进动作是什么"。
>
> **与 CLI 的分工（首版）**：`ponygo audit` 内嵌了一套精简四问布尔项（骨架层 + 部分机制层，
> 只为"秒出结果"）；本文件是**全量**细目（含精微层画像），供人工深查 / 未来 CLI 精化时迁入。
> 二者口径以本文件为准——若 CLI 内嵌项与这里不一致，以这里为真源并回改 CLI。
>
> 结构：按**四问 × 三层**组织。三层 = 骨架层（判"有没有"）/ 机制层（判"对不对"）/
> 精微层（判"深不深"，首版标 `[future]` 不启用）。
> S 档只查骨架层，M 档追加机制层，L 档（future）才含精微层。

---

## 问① 决策记在哪

### 骨架层（S 档）

| # | 子项 | 判定（布尔命题） | 检查命令（现成） | 失败时最小改进动作 |
|---|---|---|---|---|
| 1.1 | 有专用决策载体 | 存在一个专门目录承载决策记录（ponygo 或替代形态均可） | `ls -d .meta/decisions docs/adr docs/decisions docs/architecture/decisions 2>/dev/null \| head -1` | 建 `.meta/decisions/` 或任意 ADR 目录，写第一篇 ADR |
| 1.2 | 路径编码状态 | 四态目录齐全 | `ls -d .meta/decisions/{proposed,implemented,rejected,archived} 2>/dev/null` | 补齐缺失的四态目录 |
| 1.3 | 有决策记录 | 决策文件数 > 0（README 豁免） | `find .meta/decisions -name '*.md' ! -name 'README.md' ! -name '*.zh.md' \| wc -l` | 写第一篇 ADR，落 `implemented/` 或 `proposed/` |

### 机制层（M 档追加）

| # | 子项 | 判定（布尔命题） | 检查命令 | 失败时最小改进动作 |
|---|---|---|---|---|
| 1.4 | 状态与内容一致 | 无缺 `Status:` 头的决策文件（README 豁免） | `find .meta/decisions -name '*.md' ! -name 'README.md' -exec grep -L '^Status:' {} + \| wc -l` 应为 0 | 给缺头文件补 `# Agent Note:` + `Status:` 前两行 |
| 1.5 | 有 Alternatives 节 | 每条决策含候选方案 | `grep -rl 'Alternatives' .meta/decisions \| wc -l` ≥ 记录总数 | 补 `## Alternatives considered` |
| 1.6 | 被否选项留痕 | `rejected/` 非空（排除 `.gitkeep`/`README.md` 占位）或含被否候选记录 | `ls -A .meta/decisions/rejected/ \| grep -v -e '^\.gitkeep$' -e '^README\.md$' \| wc -l` > 0 | 把被否决的方案落一条 `rejected/` 记录 |
| 1.7 | 触发条件枚举化 | 有一份"何时必须写"的枚举清单 | `grep -rl "非平凡变更\|触发规则" .meta/ docs/ 2>/dev/null \| head -1` | 写触发规则（命中任一即写，纯机械豁免） |
| 1.8 | supersession 当次处理 | 新增记录时替换旧记录在同一变更 | `git log --oneline -5 -- .meta/decisions \| wc -l` 且无残留被弃记录（语义） | 靠 review；建 supersession 审计习惯 |

### 精微层（`[future]` 首版不启用）

- 1.9 双语/多语言配对的完整性（`.i18n.yaml` 一致性哈希）——依赖 L5 机制。
- 1.10 决策语料的 GC 卫生（被完全取代的记录是否已 consolidation）。

---

## 问② 承诺怎么强制

### 骨架层（S 档）

| # | 子项 | 判定 | 检查命令 | 失败动作 |
|---|---|---|---|---|
| 2.1 | 有门禁目录 | `gates/` 目录存在 | `ls -d .meta/gates 2>/dev/null` | 建 `.meta/gates/` |
| 2.2 | 本地钩子已挂 | `core.hooksPath` 指向非空钩子目录，或 `.githooks/` 存在 | `git config core.hooksPath`（非空）+ `ls -A $(git config core.hooksPath)` | 挂本地钩子（这是强制层放大器，优先） |
| 2.3 | CI 存在 | 有 CI 配置 | `ls .github/workflows/*.yml .gitlab-ci.yml 2>/dev/null \| head -1` | 加最小 CI（聚合门） |

### 机制层（M 档追加）

| # | 子项 | 判定 | 检查命令 | 失败动作 |
|---|---|---|---|---|
| 2.4 | 门带负样本 spec | 每个门有构造非法样例证明会拒绝 | `find . -path ./node_modules -prune -o \( -name '*_test.go' -o -name '*_test.rs' -o -name 'test_*.py' -o -name '*_test.py' -o -name '*.spec.ts' -o -name '*.spec.js' -o -name '*.Spec.cs' \) -print \| head -1` 非空 | 给门配负样本 spec（后缀随项目栈而定，此处仅给常见样例） |
| 2.5 | 分层（本地 vs CI）各抓各的 | 本地窄、CI 全，不重复跑 | 语义，见 `scorecard.md` 问② | 靠 review |
| 2.6 | 绕行可控 | 有 bypass 记录/上报机制 | 语义 | 靠 review |

### 精微层（`[future]`）

- 2.7 生成物漂移门（`gen-*.ts --check` 逐字节比对）——依赖 L3/L4 机制。
- 2.8 覆盖率分区合并、workflow 形状契约。

---

## 问③ 重复劳动怎么复用

### 骨架层（S 档）

| # | 子项 | 判定 | 检查命令 | 失败动作 |
|---|---|---|---|---|
| 3.1 | 有技能目录 | `skills/` 存在 | `ls -d .meta/skills 2>/dev/null` | 建 `.meta/skills/` |

### 机制层（M 档追加）

| # | 子项 | 判定 | 检查命令 | 失败动作 |
|---|---|---|---|---|
| 3.2 | 有至少一个资产化流程 | 技能文件数 > 0 | `find .meta/skills -name 'SKILL.md' -o -name '*.md' \| grep -v README \| wc -l` > 0 | 把"每三次重复劳动"资产化为技能 |
| 3.3 | 技能带触发式 description | description 内联触发条件 | `grep -l '何时用\|trigger\|When to use' .meta/skills/*/SKILL.md 2>/dev/null` | 补触发式 description |
| 3.4 | 技能带校准样例 | 正反例成对 | `grep -l '校准样例\|calibration\|Examples' .meta/skills/*/SKILL.md 2>/dev/null` | 补校准样例 |

### 精微层（`[future]`）

- 3.5 调用权限分层（`disable-model-invocation`）。
- 3.6 证据链完整性（GUI 改动的 GIF 证据）——依赖 L4+。

---

## 问④ 过时怎么退场

### 骨架层（S 档）

| # | 子项 | 判定 | 检查命令 | 失败动作 |
|---|---|---|---|---|
| 4.1 | 有归档目录 | `archived/` 存在 | `ls -d .meta/decisions/archived 2>/dev/null` | 建 `archived/`（只有 implemented 能进） |

### 机制层（M 档追加）

| # | 子项 | 判定 | 检查命令 | 失败动作 |
|---|---|---|---|---|
| 4.2 | 归档被冻结 | 归档件有哈希封印 manifest | `ls .meta/decisions/archived/*.manifest* 2>/dev/null \| head -1` | 加 append-only 封印 manifest |
| 4.3 | 搜索隔离过期 | `.rgignore` 排除 archived | `grep -l archived .rgignore 2>/dev/null` | 在 `.rgignore` 排除 archived 目录 |
| 4.4 | 退场有判据 | 归档/拒绝不是按字数或年龄 | 语义，见 `scorecard.md` 问④ | 靠 review |
| 4.5 | supersession 同 PR | 被取代记录同一变更删除 | 语义 | 靠 review |

### 精微层（`[future]`）

- 4.6 依赖政策审计（换依赖过审）。
- 4.7 负空间的复活条件立法。

---

## 用法小结

- `S 档`（起步/小项目）：只跑「骨架层」各问，共 8 项；命中为 0 的层面**就此打住，不再深挖**（连 ADR 目录都没有时，问词数预算是废话）。
- `M 档`（有治理基础但欠体系）：追加「机制层」（15 项）。
- `L 档`（monorepo/多栈/强合规）：「精微层」（8 项）标 `[future]`，首版不启用——其中半数检查点依赖尚未交付的机制（双语配对、生成物漂移门、覆盖率分区）。

> 打分 = 命中计数；每个 0 分点直接映射右列一条「最小改进动作」。这是审计可复现的来源——同一个盘面、不同人跑，命中数一致。
