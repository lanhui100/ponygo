# revisions/ —— 框架自身演进记录（**已冻结：历史只读**）

> **状态：冻结（frozen）**。本目录不再接收新条目，也不再作为"现行规则是什么"的权威。
> 框架级决策此后一律归口 `.agents/notes/`（`implemented/` 记现值、`proposed/` 记待定），
> 与实例的工程决策共用同一套触发规则、同一条判据真源（`write-adr/verify-note.sh`）与同一份
> 归档封印门。决策与理由见 `.agents/notes/implemented/process/2026-11-09-revisions-track-frozen.md`。

## 冻结边界（三条）

1. **停止新增**：`proposed/` 不再接收提案（当前仅 `.gitkeep`），`accepted/` 不再接收新条目。
   实例对框架的回馈改落 `.agents/notes/proposed/`——回馈本质就是"这条约定在原实例为何失效"的决策记录。
2. **历史件不改造**：21 篇 `accepted/` 保持原貌（`Status: accepted`、`## 回馈证据` / `## 框架规则变更`
   的旧骨架照旧），继续作为"当时规则怎么写的"的原文快照。**唯一边界例外**是可机械验证的事实失真就地
   修正（如漂移宇宙文件数 十→十五，与 `.agents/notes/` 侧同批修）——留着与现状矛盾的数字等于让历史件
   冒充现行事实。
3. **不接门禁**：不给旧轨道挂 ADR 判据。实测 21 篇中 5 篇无 `## Alternatives considered`、1 篇无
   `Status:` 行，接上即恒红；"历史件按现在的判据合格"不是冻结语料该背的债。

## 原双轨边界（历史口径，读旧条目时按此理解）

| 载体 | 记什么 | 例子 |
|---|---|---|
| `revisions/`（冻结前） | **框架规则的演进**——ponygo 这套元框架自身的约定/判据/命令面如何变（"框架应该怎么治理别人"） | 新增一条 L1 判据；audit 增加一档；命令面调整 |
| `.agents/notes/`（唯一在写） | **决策记录**，含框架级规则变更与"本仓库作为软件项目怎么实现" | 判据 1.10 的加装与迁移面；CLI 用单文件 bash；某 bug 的修复方案 |

- `proposed/` —— 提案（冻结前：实例回馈、待定夺的框架改动；现仅 `.gitkeep`）
- `accepted/` —— 已采纳（冻结前：随下一版本号发布；现为历史快照）

实例项目只有 `.agents/notes/`（`revisions/` 不进实例骨架）。

> 悬空引用已清零：`ponygo observe --help` 与根 `README.md` 的 observe 指路均指向
> `accepted/2026-10-25-observe-dimension.md`（冻结不豁免悬空引用，故指向历史条时同句标注「轨道已冻结」）。
