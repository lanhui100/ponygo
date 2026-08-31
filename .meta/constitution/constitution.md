# 宪法（Constitution）—— 单一真相源（Single Source of Truth）

> **本文件是本项目工程化命约的单一真相源。**
> 根目录的 `AGENTS.md` / `CLAUDE.md` 里那一小段常载命约，是**由本文件投影（projection）派生**的，而非独立编辑的第二份。
> 投影由 ponygo CLI 的 `sync` 命令维护，标记区为 `<!-- BEGIN constitution -->` … `<!-- END constitution -->`。
> **禁止手编投影区**——改这里，再跑 `ponygo sync`。两份内容若漂移，以本文件为准，投影视为待同步。

---

## 槽位（Slots，实例化时填写）

将下方 `【TODO: …】` 槽位替换为真实值后方可作为实例宪法启用。槽位未填时，本文件处于"模板态"，约定的约束强度降级（见文末「停止线」）。

| 槽位 | 应填内容 | 当前值 |
|---|---|---|
| 项目名 | 仓库名 / 项目代号 | 【TODO: 填项目名】 |
| 一句话定位 | 这个项目"是什么"，一句话 | 【TODO: 填一句话定位】 |
| 技术栈 | 语言 / 运行时 / 关键框架 | 【TODO: 填技术栈】 |
| 当前成熟度目标 | 本阶段在治理层级（meta.yaml `level:`）上的目标档位 | 【TODO: 填成熟度目标，如 2】 |

---

## 目标（Mission）

【TODO: 填目标——这个项目要建成什么、为谁。用 1-3 句陈述"为什么存在"，而非罗列功能。】

成熟度目标锚定：当前 `meta.yaml` 的 `level:` 是【TODO: 填 level，整数 0-6】，治理机制的启用范围、门禁数量、skill 数量均以该档位为上限（见 `../meta.yaml` 字段注释）。**不要在达到目标前抢跑下一档位**——停止线见文末。

---

<!-- sync-body --><!-- 投影体起点：ponygo sync 从此锚点之后抽取（语言无关；勿删，删了回退中文标题匹配） -->

## 常载命约（Standing Orders）

> 每条命约 1-3 行，必须是"约定"而非"故事"；每条链到原理层——指 ponygo 框架仓库的
> `docs/methodology.md`：<https://github.com/lanhui100/ponygo/blob/main/docs/methodology.md>。
> 原理层唯一真相源在框架仓库，实例不复制——复制即漂移。
> 这是每次会话必载、不可被后续指令覆盖的**常驻约束**。下方 5 条为最普适的预设，实例化时可增删，但保留最少 3 条。

1. **决策必须入册且带 Alternatives**——任何非平凡变更（行为 / 架构 / 契约 / 流程 / 测试策略变更，命中任一）都要落到 `.agents/notes/{lifecycle}/{class}/` 下的一条决策记录，且必含 `## Alternatives considered`（候选方案与落选原因）。口头决定、只存在于聊天/PR 讨论里的"为什么这样/为什么不那样"视为未发生。
   链：P1 记忆瓶颈原理、methodology §2.5 触发规则、§2.4 格式契约。

2. **凡机械可查的承诺，配一条非零退出的命令**——本宪法里每一条可被程序检验的约定，必须有对应的门禁（.meta/gates/ 或项目的 gate 脚本）能 `exit 1` 拦截违例；做不到机器检验的，显式标注"靠 review / 靠自觉"，不得装假门禁。
   链：P2 可验证性原理、methodology §4、§9 记分卡第 2 问。

3. **删代码前先搜消费者**——删除任何符号/文件/目录前，先 `rg`（或等价检索）确认无生产消费者；连根拔不留壳（源码 + 测试 + 文档 + 目录条目一张清单带走），验收 = "搜索零残留 + 门禁照常绿"。移除本身是一次决策，需同 PR 入册。
   链：P9 负空间对称原理、methodology §7.1 简化工艺。

4. **文件夹即标签，不手填会漂移的副本**——决策记录的分类轴（class）与状态轴（lifecycle）只编码在路径里，不在文件内重复声明一行会与路径漂移的标签。`meta.yaml` 只持有一个 `level` 字段；版本由 git 派生，已激活组件由 `.meta/` 下目录存在性充当，**禁止**在 yaml 里手填组件清单/版本。
   链：P6 形意分离原理、methodology §2.1「文件夹即标签」、§2.2 三重锁定。

5. **AI 工具适配层默认关**——面向编码代理（AI agent）的适配开关（常驻载荷、skill 自动路由等）默认**关闭**，由实例显式开启后方生效。人类开发者优先，避免"为 AI 而 AI"的机制税。
   链：P3 载体分工原理、methodology §3.3 调用权限分层（`disable-model-invocation: true` 范式）。

---

## 治理结构（Governance Layout）

治理根 `.meta/` 的目录契约，各目录职责与现存说明文件见括号：

| 路径 | 职责 |
|---|---|
| `.meta/constitution/` | 本宪法（单一真相源） |
| `.meta/gates/` | 门禁（gate）定义与负样本 spec（见 `.meta/gates/README.md`） |
| `.meta/docs-tier/` | 文档分层（tier）约定（见 `.meta/docs-tier/README.md`） |
| `.meta/meta.yaml` | 状态文件，仅 `level` 字段 |
| `.agents/notes/` | 决策记录（ADR / Agent Note），lifecycle × class 双轴路径编码（见 `.agents/notes/README.md`） |
| `.agents/skills/` | 可复用流程技能（SKILL.md）（见 `.agents/skills/README.md`） |

> 分家原则：`.agents/` 承载 AI agent 运行时读写的资产（须在工具发现路径上）；
> `.meta/` 承载治理的机器态与真源（经投影或钩子消费）。

---

## AI 工具适配（AI Adaptation，默认关）

- **状态**：`【off | on，默认 off】`。
- 当且仅当该项目的主要开发者是编码代理（AI agent）时，由实例显式开启，并在此登记：
  - 常驻载荷来源（投影到根 `AGENTS.md` / `CLAUDE.md`）；
  - 允许自主路由的 skill 白名单（其余 skill 仅用户点名可用）；
  - 模型可见性证据链要求（模型可见 ⟺ 已记录，见 methodology §5.5）。

开启前，此处为空即代表"未开启"，不得有任何松散承诺。

---

## 停止线（Stop Line）

1. 槽位未填 → 本文件视为模板态，命约不生效；此时 `ponygo sync` 投影的是**引导内容（bootstrap）**而非命约——指引进入仓库的 AI agent 完成填槽、重投影与首篇决策。槽位填妥重跑 sync 后，引导自动被常载命约整体替换，无需手删。
2. 成熟度目标（`meta.yaml` `level:`）是硬上限——在达到当前档位前，不新增超出该档位的机制（门禁、skill、文档分层档位）。
3. 任何对机制的建设以"转起来"为先、以"转得完美"为后（methodology §10）。多记一段文字的成本，远小于漏记一次决策的成本。
4. **本宪法不是合规证据链**：ponygo 是工程化治理脚手架，本宪法及其成熟度不构成任何监管合规背书（FDA、ISO 13485/26262、SOC2、PIPL 等）。强监管项目请另行接入专用合规框架。
5. **禁用 AI 代理时整体退场**：若团队合规上禁止 AI 代理接触代码，在 `meta.yaml` 置 `ai-surface: off`——`ponygo sync` 将不生成 `AGENTS.md` / `CLAUDE.md`，下方 AI 适配节留空即代表永不开启。
