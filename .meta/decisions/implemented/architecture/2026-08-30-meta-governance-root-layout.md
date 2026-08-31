# Agent Note: 治理根 .meta/ 布局与 meta.yaml 两键铁律

Status: implemented

## Problem

治理体系需要一个可寻址的根目录承载宪法、决策、门禁、技能、文档分层五类资产，
同时需要一个状态文件标记成熟度。状态文件若承载多字段（版本/组件清单/演进记录），
字段间互相派生、手填必漂移——重演"行与文件夹不一致"的老问题。

## Decision

治理根为 `.meta/`：`constitution/` + `decisions/` + `gates/` + `skills/` +
`docs-tier/` + `meta.yaml`。`meta.yaml` 合法键仅 `level` 与 `ai-surface` 两个：
版本由 git 派生，组件清单由目录存在性充当，演进记录由 git 历史 + decisions/ 充当。
出现其它键由 `ponygo status`/`audit` 双挂 WARN（不改退出码）。
decisions 双轴编码进路径：`{lifecycle}/{class}/yyyy-mm-dd-topic-title.md`，
lifecycle 四态 + class 六类封闭集合（classes.local 开放领域扩展）。

## Alternatives considered

- **多字段 yaml（版本/组件/成熟度并记）**：否决——凡能被机械推导的东西不冗余声明，
  推导源（git、目录）与手填副本必然漂移。
- **决策标签写在文件 frontmatter 里**：否决——文件夹即标签，路径与内容二选一，
  双写必漂移（methodology §2.1 实证）。
- **治理根用 docs/ 或根目录散放**：否决——单一根目录才可被 `test -d` 一条命令判有无，
  也是"组件清单由目录存在性充当"的前提。

## Consequences

- 骨架完整度、决策数、级判据全部可由 `find`/`grep`/`test` 机械判定（P2 落地）。
- meta.yaml 的键白名单写死在 CLI 的 `warn_meta_violations`，是规格的一部分。
