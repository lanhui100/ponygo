# Agent Note: 技能三层化——基线、模板库与实例自有

Status: implemented

## Problem

ponygo 的 `init` 只播种三个框架技能（`write-adr`、`change-review`、`governance-review`），
其余通用工程流程（推送前选证、简化勘探、文档卫生、测试可靠性、破版迁移指引、决策语料回收）
在每个项目里靠口传或现写。同时 `audit` 的流程资产判据只问「`.agents/skills/` 是否非空」——
框架必然播种三个技能，于是每个实例都无条件得分，该问对「是否真的沉淀过流程」没有区分度；
而 checklist 3.2–3.4（触发式 description、校准样例、至少一个资产化流程）从未在 CLI 落地，
历史项目缺哪个技能文件、已有技能缺哪个要素，`audit` 都报不出来。

## Decision

技能按**三层归属**组织，同批交付：

1. **基线**（`.agents/skills/`）：三个框架技能，正文不变，模板逐字节锁；不计入 L3 证据。
2. **模板库**（`.meta/skills-library/`）：新增六个 `pg-` 前缀的通用流程技能
   （`pg-delivery-checks`、`pg-find-simplifications`、`pg-doc-hygiene`、`pg-test-reliability`、
   `pg-upgrade-guide`、`pg-gc-agent-notes`）+ `install.sh`（`list`/`install`/`check` 位置子命令，
   零旗标）+ `catalog.tsv`（必要性元数据）+ `README.md`。`init` 必播但**不安装**，
   安装由用户显式执行 `bash .meta/skills-library/install.sh install <name>`；
   副本带 `.ponygo-installed` 标记，`check` 报 `ok`/`stale`/`modified`，**永不覆盖**本地改造。
3. **实例自有**：其余技能，是 L3 唯一证据来源。

配套三处机制改造：

- `init`/`upgrade`/`status` 增 `OPTIONAL_UNIVERSE`（库 9 文件）与可选资产语义：库缺失只提示，
  不判 drift、不改退出码；`init --repair-skeleton` 只补缺失、不覆盖（历史项目的获取路径）。
- `audit` 问③ 由 1 项改为 3 项：实例自有技能 ≥1、全部技能触发式 description 完整、
  全部技能五要素齐（围栏感知）。机械实现落在 CLI 只读解析，**不新建门禁**。
- `audit` 增能力缺口建议（advisory）：`catalog.tsv` × 证据求值（笔记类别计数、归档封印数、
  文档规模、Web/测试/发布面），命中则打印候选与安装命令，**不计分、不改退出码**，
  判据文案显式标注「靠 review」——必要性是语义判断，不装假计数。

规格与逐项判据见 `docs/dev-team/specs/spec-ponygo-v2.6.md`。

## Alternatives considered

- **把通用技能全部设为基线（init 直接装进 `.agents/skills/`）**：否决——空技能是被永久引用的
  死重（`.agents/skills/README.md` 既有结论），且每个新基线都要进升级宇宙与逐字节测试。
- **库用符号链接接入 `.agents/skills/`**：否决——跨沙箱/Windows/打包风险，且与归档区拒绝
  symlink 的既有立场冲突；复制 + marker 的漂移可被三态观测。
- **新增 `ponygo skill install` 子命令**：否决——违反六命令面与旗标预算（
  `implemented/process/2026-11-07-flag-budget.md`）；脚本位置子命令是既有先例
  （`archive-verify.sh check|seal`）。
- **audit 自动安装或自动计数「第三次重复」**：否决——只读命令不得写盘；重复计数不可机械判定，
  装成门禁即假门禁（P6）；连续性/必要性留 review。
- **库技能计入 L3 证据**：否决——一条命令即可"买"到 L3，等级失去含义；框架交付物一律不计。
- **基线技能也加 `pg-` 前缀**：否决——破坏性重命名，引用遍布 gates/tests/docs，收益仅是命名统一。

## Consequences

- `audit` 项数：S 10 → 12，M 15 → 17（本仓在被并行改动后 M 基线为 15）；空实例（仅基线）由「白送 1 分」
  变成 3.2 不得分、3.3/3.4 得分（实跑 `命中 4 / 12`、`4 / 17`），既有 `命中 N / M` 断言必须同批更新。
- `ponygo` 单文件增约 700 行 heredoc（库技能正文），由脚本注入保证与仓库内库文件逐字节一致。
- 删除库文件是合法的显式决策（可选资产），但须录 decision；库存在即模板所有，与模板不一致照常报 drift。
- 未交付：Rule of three 计数机制、skill 元数据门禁（仍属 L4 未解冻项）；本变更只做只读审计建议。
