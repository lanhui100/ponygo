# Agent Note: 双根骨架——.agents/ 运行时资产与 .meta/ 机器态真源分家

Status: implemented

## Problem

骨架 v1 把全部治理资产收进 `.meta/` 单根。实证发现两个错位：

1. **`.meta/` 不在任何 AI 工具的发现路径上**——skills 的定义是"被路由、被加载"，
   放错位置的 skill 不是资产是文件；notes 每次非平凡变更都要被 agent 读写。
   ponyllm 实例中 agent 只能靠 bootstrap 投影点名找到 write-adr，常载命约阶段桥即断。
2. DSH 全解剖证实其形状：`.agents/`（notes + skills，agent 运行时资产，在发现路径上）
   + 根 AGENTS.md 常载面 + `.rgignore` 归档隔离 + 门禁外置（scripts/lefthook/CI）。
   本仓库迁移后，本会话的技能目录立即出现了 write-adr——`.agents/` 发现性被当场实证。

## Decision

治理根从 `.meta/` 单根改为**双根**：

- `.agents/` = AI agent **运行时读写**的资产：`notes/`（决策记录，自 `.meta/decisions`
  迁家，路径规范/lifecycle×class 双轴/classes.local 均不变）、`skills/`（流程资产，
  自 `.meta/skills` 迁家）；
- `.meta/` = 治理的**机器态与真源**：`meta.yaml`、`constitution/`（经投影消费）、
  `gates/`（消费者是钩子/CI）、`docs-tier/`（约定文档）；
- 新增 `.rgignore`（`/.agents/notes/archived/`）进骨架：归档搜索隔离，防陈旧事实
  按词法命中挤掉当前结果（DSH 实证同构）。

判据、audit、status、骨架文档、write-adr 技能、bootstrap 引导、宪法模板全部同步新路径。
本记录部分取代 `2026-08-30-meta-governance-root-layout.md`（其"单根 .meta/"布局被推翻；
meta.yaml 两键铁律、文件夹即标签、双轴路径编码**维持不变**——旧记录保留作历史，不篡改）。

## Alternatives considered

- **保持 .meta 单根，靠投影/指针桥接（.claude/skills 指针 + AGENTS.md 索引）**：
  否决——对"直接加载 `.agents/`"的工具链无效；桥接是间接引流，不如资产直接在发现路径上。
- **sync 生成 `.agents/skills/` 壳（.meta 保持唯一真相源）**：否决——skill 的文件结构
  （SKILL.md + references/ + templates/）比文本投影复杂，壳的保真与漂移门成本高；
  且 skill 的读者正是 agent 运行时，让它看副本是本末倒置。
- **整体迁入 .agents/（含 constitution/gates）**：否决——constitution 经投影消费、
  gates 由钩子消费，运行时可见性对它们无收益；留在 .meta 保住"机器态单根可判定"。

## Consequences

- 骨架完整度判定从 6 目录变 7 目录（两个已知根仍是常数可枚举，单根核心收益保留）。
- 存量实例（如 ponyllm）为旧形状：迁移 = `git mv .meta/decisions .agents/notes &&
  git mv .meta/skills .agents/skills` + 补 `.rgignore`，一次提交可完成。
- 旧形状实例跑新版 status 会报 1.1 缺失（notes/ 不在新路径）——判据生效的预期行为。
