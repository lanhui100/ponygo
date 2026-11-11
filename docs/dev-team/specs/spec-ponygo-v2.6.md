# spec-ponygo-v2.6：技能体系三层化（基线 / 模板库 / 实例自有）

> Task: SKILL-TIERS ｜ 复杂度: B ｜ 2026-11-10 ｜ rev1
> 通用化红线：本 spec 只收**栈无关**判据；技能正文不得出现 `dsh-` 名、`pnpm`/`tsx`/`vitest`、
> `benchmarks/`、CI job 名、包数/词数规范值（照 `spec-ponygo-v2.5.md` §10 DSH 特异否决表）。

## 1. 目标与非目标

**目标**：让 `ponygo init` 播种"可选技能模板库"，让 `ponygo audit` 既能机械审计技能形状，
又能给出"是否缺技能、是否需要装、怎么装"的建议；历史项目经 `init --repair-skeleton` 获得库。

**非目标**：新旗标/新子命令；自动写 `.agents/skills/`；自动计数 Rule of three；symlink 安装；
把库技能计入 L3 证据；改基线 3 技能正文。

## 2. 三层归属与命名

| 层 | 位置 | 所有者 | 计入 L3 | init |
|---|---|---|---|---|
| 基线 | `.agents/skills/{write-adr,change-review,governance-review}/` | 实例可改，模板逐字节锁 | 否 | 必播 |
| 模板库 | `.meta/skills-library/` | 仅模板 | 否 | 必播、**不安装** |
| 实例自有 | 其余 `.agents/skills/*/` | 实例 | 是 | 不生成 |

库技能名**必须**带 `pg-` 前缀（本项目命名空间）。基线名不变（既有契约引用遍布 gates/tests/docs，
改名是破坏性变更且无收益）。

六个库技能：`pg-delivery-checks`、`pg-find-simplifications`、`pg-doc-hygiene`、
`pg-test-reliability`、`pg-upgrade-guide`、`pg-gc-agent-notes`。

## 3. 库文件契约

```
.meta/skills-library/
  README.md                 # 三层归属 / 三态 / marker 格式 / 不计 L3（唯一家）
  install.sh                # list | install <name> | check（位置子命令，零旗标）
  catalog.tsv               # 必要性元数据（audit B3 唯一数据源）
  pg-<name>/SKILL.md        # 6 个
```

### 3.1 `catalog.tsv` 语法

制表符分隔五列，`#` 起注释，空行忽略：

```
name <TAB> evidence_kind <TAB> evidence_arg <TAB> min <TAB> hint
```

`evidence_kind` 封闭集合与求值口径（`arg` 缺省写 `-`）：

| kind | 求值 |
|---|---|
| `notes_class` | 计数 `.agents/notes/implemented/<arg>/` 下 `*.md`（去 `README.md`/`*.zh.md`） |
| `archive_sealed` | 计数 `.agents/notes/archived/manifest.sha256` 有效行（`^[0-9a-f]{64}  `） |
| `docs_scale` | 计数非 `.agents/notes/` 的 `*.md`（`min` 为阈值） |
| `web_dirs` | 命中 `src`/`app`/`web`/`ui`/`packages/client` 任一（`min` 忽略，写 1） |
| `test_dirs` | 命中 `tests`/`test`/`spec`/`__tests__` 且存在 CI 配置（`min` 忽略，写 1） |
| `release_surface` | 存在 `CHANGELOG*` 或 git tag 或 `bin/`（`min` 忽略，写 1） |
| `none` | 永不建议 |

`min` 为正整数；`hint` 是给人读的一句"何时需要"。

### 3.2 `install.sh` 动词与退出码

| 调用 | 行为 | 退出码 |
|---|---|---|
| `install.sh list` | 每技能一行：`<name>\t<installed\|absent>\t<ok\|stale\|modified\|->` | 0 |
| `install.sh install <name>` | 复制库技能到 `.agents/skills/<name>/`；目标已存在 → 拒绝且不写 | 0 成功 / 1 已存在 / 2 用法或未知技能 |
| `install.sh check` | 逐已安装项判 `ok`/`stale`/`modified` | 0（只读、advisory） |

约束：只读 `check` 不得写盘；全部错误走 stderr；`install` 成功后写
`.agents/skills/<name>/.ponygo-installed`：

```
library_sha256=<安装时库内 SKILL.md 的 sha256>
installed_at=<yyyy-mm-dd>
```

三态判定：`installed_sha256 != marker.library_sha256` → `modified`（优先）；
否则 `library_current_sha256 != marker.library_sha256` → `stale`；否则 `ok`。
**永不覆盖**实例文件。

### 3.3 技能正文契约

五要素（`## 真相源` / `## 步骤` / `## 校准样例` / `## 验证与报告` + frontmatter），
`description` 内联触发词（`何时用`/`Use when`/`When to use`/`trigger`），
每篇 ≤120 行，不写项目专名。英文等价节名允许：`## Truth sources` / `## Steps` /
`## Calibration examples` / `## Verification and report`。

## 4. `init` / `upgrade` / `status` 接线

- `write_skeleton` 生成库文件（heredoc，与 repo 内库文件 EOL 归一后逐字节一致）。
- 新增 `OPTIONAL_UNIVERSE`（库 9 文件），与 `UPGRADE_UNIVERSE`（15 文件，不变）并列：
  - 库文件缺失 → `status` 行 `骨架可选资产缺口：N` + `init --repair-skeleton` 指引，**不计入 exit 1**；
  - `upgrade` 对可选资产缺失输出 `缺口（可选资产）`，**不判 drift、不改退出码**；
  - 库文件存在但与模板不一致 → 照常报 `drift:`（模板所有）。
- `init --repair-skeleton` 补缺失库文件（只补不覆盖）。

## 5. `audit` 改造

### 5.1 B1 归属完整性（机械）

| 项 | 判据 | 结果 |
|---|---|---|
| 基线 5 文件 | `UPGRADE_UNIVERSE` 内 `.agents/skills/**` 全在 | 缺 → `vl_fail` + gap `skill_baseline_missing`，非零退出 |
| 库 9 文件 | `OPTIONAL_UNIVERSE` 全在 | 缺 → gap `skill_library_missing`，**仅提示**，不改退出码 |
| 已装副本 | 存在 `.ponygo-installed` 且三态非 ok | gap `skill_library_stale` / `skill_library_modified`，仅提示 |

### 5.2 B2 形状审计（机械、计分）

问③ 由 1 项改为 3 项（替换原「目录非空」）：

| # | 判据 | 计分 |
|---|---|---|
| 3.2 | **实例自有**技能 ≥1（排除基线 3 与带 `.ponygo-installed` 的副本） | 是 |
| 3.3 | 全部技能 frontmatter `name` 与目录同名、kebab-case、`description` 含触发词 | 是 |
| 3.4 | 全部技能五要素齐（围栏感知：围栏内标题不算在场） | 是 |

不齐项 → `vl_fail` + gap `skill_shape_incomplete`，逐技能逐项打印缺什么与最小修法。

**项数变化**：S 10 → 12；M 15 → 17（本仓在被并行改动后 M 基线为 15）。空实例（仅基线）期望
`命中 4 / 12` 与 `命中 4 / 17`（3.2 不得分，3.3/3.4 得分）——以实跑值为准并锁死。
基线技能文件缺失必须 fail-closed（打印硬失败即非零退出，含未初始化目录）；库缺失只提示。
`install.sh check` 输出冻结为 `<name>\t<state>`（state ∈ ok|stale|modified）；`list` 行序不冻结。

### 5.3 B3 能力缺口建议（advisory）

`catalog.tsv × evidence` 求值，未安装且证据达阈值 → 打印：

```
能力缺口建议（advisory，靠 review 判定；不计分、不影响退出码）：
  - <pg-name>：<证据摘要>（<hint>）
    安装：bash .meta/skills-library/install.sh install <pg-name>
```

已安装但证据不再成立 → 一行 `退场候选：<pg-name>（证据已消失）`。
**不安装、不计分、不改退出码**；一行一条技能，禁止刷屏。

### 5.4 输出前缀（测试锚点，冻结）

- `技能：基线 <n>/3 齐；库 <n> 安装；实例自有 <n>`
- `能力缺口建议（advisory` （re 锚）
- `install.sh install `
- gap id 字符串：`skill_baseline_missing` / `skill_library_missing` /
  `skill_library_stale` / `skill_library_modified` / `skill_shape_incomplete`

### 5.5 JSON

`audit --json` / `status --json` 增 `skills` 块：

```json
{"skills":{"baseline_missing":[],"library":{"missing":[],"installed":[{"name":"pg-x","state":"ok"}]},
"instance_owned":["my-skill"],"candidates":[{"name":"pg-x","evidence":"...","hint":"..."}]}}
```

未真判过（提前退出分支）不得投影为 `[]` 通过——保持既有 coverage 保守语义。

## 6. 验收

| # | 命令 | 期望 |
|---|---|---|
| A1 | `bash tests/run.sh` | fail=0 |
| A2 | `ponygo status` | 骨架完整；库缺失时可选资产行不计 exit 1 |
| A3 | `ponygo audit --run-specs` | exit 0；问③ 三项如实 |
| A4 | `bash .agents/skills/write-adr/verify-note.sh` | exit 0 |
| A5 | 临时仓 fixture：`init` → `install.sh list` → `install pg-doc-hygiene` → `check` → 二次 install | 依次 0 / 0 / 1（拒绝覆盖） |
| A6 | 同一 fixture 手工改已装技能 → `check` | 报 `modified` 且文件未被覆盖 |
| A7 | 删库内一 SKILL.md → `status` | 可选缺口行；exit 0 |
| A8 | 删基线 `change-review/SKILL.md` → `audit` | 非零 + `skill_baseline_missing` |
| A9 | fixture 造缺 `## 校准样例` 的技能 → `audit` | `skill_shape_incomplete` + 非零 |

## 7. 波次与写域（正交）

| 波 | 任务 | 写域 |
|---|---|---|
| W1 | 库契约件（`install.sh`/`catalog.tsv`/`README.md`） | `.meta/skills-library/install.sh`、`.meta/skills-library/catalog.tsv`、`.meta/skills-library/README.md` |
| W1 | 6 个库技能正文 | `.meta/skills-library/pg-*/` |
| W1 | CLI 改造（audit/status/universe，不含 heredoc 注入） | `ponygo` |
| W1 | 验收测试 | `tests/run.sh` |
| W2 | heredoc 注入（依赖 W1 库件） | `ponygo`（同 owner 串行） |
| — | 文档 + ADR + spec | Lead |

## 8. 风险

- CLI 单文件膨胀约 +700 行 → 每技能 ≤120 行；heredoc 由脚本注入避免手抄漂移。
- 问③ 恢复区分度 → 既有 `命中 N / M` 断言必改；ADR 记录知情变更。
- 库/副本漂移 → marker + 三态，永不覆盖。
- 必要性误判 → advisory only + 打印证据。
