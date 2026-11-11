# docs/dev-team/ —— 工程过程记录（tier：工程过程记录）

> 承载**已完成的交付证据**：spec / task / review / 交接快照。**不作当前契约**——当前契约的家是
> 根 `README.md`（人读契约）、`maturity-ladder.md`（判据语义）、`.meta/constitution/constitution.md`
> （常载命约）；文档标准与写作规则在 `docs/AGENTS.md`。
> 过程记录只增不改结论：历史正文保留当时原貌，失效口径**就地标注现值**（不改写历史）。

## 文件与家

| 路径 | 是什么 |
|---|---|
| `HANDOFF.md` | v0 收口交接快照（换窗口续接用；路径/档位/计数口径已按现值校正，映射见其 §六） |
| `specs/` | 版本化实施规格（`spec-ponygo-vX.Y.md`：范围 / 不变量 / 验收） |
| `tasks/` | 任务单（`TASK-NNN.md`：范围 / 不变量 / 验收） |
| `reviews/` | 对抗审核报告（architect / adversarial / `review-EXTERNAL-NNN`） |

> 交付过程证据的另一半曾放在本仓 `.dev-team/`——那是**本地工作区（不入库），不作为文档家**，
> 只在单次交付期间存在；长期可寻址的记录一律落本目录。

## 写作规则

- 历史正文保留当时原貌；失效口径就地标注现值，不改写历史结论；
- **新决策一律落 `.agents/notes/`**（lifecycle × class 双轴，决策记录的唯一真源），不在本目录新增决策；
- 交付收束时把可机械复核的收据（命令 + exit code + 关键断言）留在对应 spec / task 正文，删过程性副产物。
