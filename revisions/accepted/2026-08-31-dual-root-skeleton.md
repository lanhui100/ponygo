# Revision: 骨架 v2 双根制——.agents/notes + .agents/skills 迁入工具发现路径（accepted）

Status: accepted

## 框架规则变更

实例骨架从 `.meta/` 单根改为双根：`.agents/`（notes/ 决策记录 + skills/ 流程资产，
agent 运行时读写、须在工具发现路径上）+ `.meta/`（meta.yaml / constitution / gates /
docs-tier，机器态与真源）。路径规范、lifecycle×class 双轴、classes.local、判据 1.1–1.8
语义全部不变，仅根路径 `.meta/decisions` → `.agents/notes`、`.meta/skills` →
`.agents/skills`。骨架新增 `.rgignore`（`/.agents/notes/archived/` 归档搜索隔离）。

## 采纳理由（回馈证据）

1. `.meta/` 对一切 AI 工具不可见：skills 须被路由加载、notes 须被 agent 高频读写，
   放错位置即死资产（ponyllm 实证：常载命约阶段 write-adr 的引用链断裂）。
2. DSH 全解剖：`.agents/`（notes+skills）+ 根 AGENTS.md 常载面 + `.rgignore` 归档隔离
   + 门禁外置，是被多工具加载验证过的形状。
3. 迁移当天实证：ponygo 仓库自身迁家后，同会话的 AI 工具技能目录立刻发现 write-adr。
4. 完整决策与 Alternatives 见 `.agents/notes/implemented/architecture/2026-08-31-agents-runtime-vs-meta-truth.md`
   （部分取代 2026-08-30-meta-governance-root-layout 的单根布局，双向链接）。

## 影响面

- CLI 常量、write_skeleton、status 骨架清单（6→7 目录）、audit 问③、判据消息、
  bootstrap 引导、宪法模板、全部骨架 heredoc 与仓库文件双写、tests 全量路径更新。
- 存量实例迁移：两条 `git mv` + 补 `.rgignore`，一次提交完成；旧形状跑新版 status
  报 1.1 缺失属判据生效的预期行为。
