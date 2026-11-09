<!-- BEGIN constitution -->

## 常载命约（Standing Orders）

> 每条命约 1-3 行，必须是"约定"而非"故事"；每条链到原理层——指 ponygo 框架仓库的
> `docs/methodology.md`：<https://github.com/lanhui100/ponygo/blob/main/docs/methodology.md>。
> 原理层唯一真相源在框架仓库，实例不复制——复制即漂移。
> 这是每次会话必载、不可被后续指令覆盖的**常驻约束**。下方 6 条为最普适的预设，实例化时可增删，但保留最少 3 条。

1. **决策必须入册且带 Alternatives**——任何非平凡变更（行为 / 架构 / 契约 / 流程 / 测试策略变更，命中任一）都要落到 `.agents/notes/{lifecycle}/{class}/` 下的一条决策记录，且必含 `## Alternatives considered`（候选方案与落选原因）。口头决定、只存在于聊天/PR 讨论里的"为什么这样/为什么不那样"视为未发生。
   链：P1 记忆瓶颈原理、methodology §2.5 触发规则、§2.4 格式契约。

2. **凡机械可查的承诺，配一条非零退出的命令**——本宪法里每一条可被程序检验的约定，必须有对应的门禁（.meta/gates/ 或项目的 gate 脚本）能 `exit 1` 拦截违例；做不到机器检验的，显式标注"靠 review / 靠自觉"，不得装假门禁。
   链：P2 可验证性原理、methodology §4、§9 记分卡第 2 问。

3. **删代码前先搜消费者**——删除任何符号/文件/目录前，先 `rg`（或等价检索）确认无生产消费者；连根拔不留壳（源码 + 测试 + 文档 + 目录条目一张清单带走），验收 = "搜索零残留 + 门禁照常绿"。移除本身是一次决策，需同 PR 入册。
   链：P9 负空间对称原理、methodology §7.1 简化工艺。

4. **文件夹即标签，不手填会漂移的副本**——决策记录的分类轴（class）与状态轴（lifecycle）只编码在路径里，不在文件内重复声明一行会与路径漂移的标签。`meta.yaml` 只持有 `level`（成熟度级）与 `ai-surface` / `docs-tier`（开关声明）三个合法键；版本由 git 派生，已激活组件由 `.meta/` 下目录存在性充当，**禁止**在 yaml 里手填组件清单/版本。
   链：P6 形意分离原理、methodology §2.1「文件夹即标签」、§2.2 三重锁定。

5. **AI 工具适配层默认关**——面向编码代理（AI agent）的适配开关（常驻载荷、skill 自动路由等）默认**关闭**，由实例显式开启后方生效。人类开发者优先，避免"为 AI 而 AI"的机制税。
   链：P3 载体分工原理、methodology §3.3 调用权限分层（`disable-model-invocation: true` 范式）。

6. **文档有家**——文档标准与写作规则的家是 `docs/AGENTS.md`（agent 处理 `docs/` 子树时自动加载，故改文档规范就改它，不另立第二份）；每个事实、层级说明与 how-to 必须有唯一可寻址的家，改行为/契约/配置的那次提交同步更新对应文档的家（same-commit），不留"只在聊天里说过"的文档。
   链：P3 载体分工原理、methodology §5.1「文档的家」（AGENTS.md 自动加载 vs README 人读契约的分工）。

---

## 治理结构（Governance Layout）

治理根 `.meta/` 的目录契约，各目录职责与现存说明文件见括号：

| 路径 | 职责 |
|---|---|
| `.meta/constitution/` | 本宪法（单一真相源） |
| `.meta/gates/` | 门禁（gate）定义与负样本 spec（见 `.meta/gates/README.md`） |
| `.meta/docs-tier/` | 文档分层（tier）约定（见 `.meta/docs-tier/README.md`） |
| `.meta/meta.yaml` | 状态文件，合法键 = `level` + `ai-surface` + `docs-tier`（其余键告警） |
| `.agents/notes/` | 决策记录（ADR / Agent Note），lifecycle × class 双轴路径编码（见 `.agents/notes/README.md`） |
| `.agents/skills/` | 可复用流程技能（SKILL.md）（见 `.agents/skills/README.md`） |

> 分家原则：`.agents/` 承载 AI agent 运行时读写的资产（须在工具发现路径上）；
> `.meta/` 承载治理的机器态与真源（经投影或钩子消费）。

---

## AI 工具适配（AI Adaptation，默认关）

- **状态**：`on`（本仓显式开启，声明载体 = `.meta/meta.yaml` 的 `ai-surface: on`；判据 2.6 据此 fail-closed）。
- 开启后的登记项：
    投影到根 `AGENTS.md` / `CLAUDE.md` 的 `<!-- BEGIN constitution -->` … `<!-- END constitution -->` 哨兵块；
  - **允许自主路由的 skill 白名单**：`.agents/skills/` 下的 `write-adr`、`change-review`、
    `governance-review`（其余 skill 仅用户点名可用）；
  - **模型可见性证据链要求**：凡"为什么这样/为什么不那样"必须落进 `.agents/notes/` 的决策记录
    （模型可见 ⟺ 已记录，见 methodology §5.5）。

关闭（`ai-surface: off` 或删除该键）时此处登记项一并失效，不得留下松散承诺。

---

## 停止线（Stop Line）

1. 槽位未填 → 本文件视为模板态，命约不生效；此时 `ponygo sync` 投影的是**引导内容（bootstrap）**而非命约——指引进入仓库的 AI agent 完成填槽、重投影与首篇决策。槽位填妥重跑 sync 后，引导自动被常载命约整体替换，无需手删。
2. 成熟度目标（`meta.yaml` `level:`）是硬上限——在达到当前档位前，不新增超出该档位的机制（门禁、skill、文档分层档位）。
3. 任何对机制的建设以"转起来"为先、以"转得完美"为后（methodology §10）。多记一段文字的成本，远小于漏记一次决策的成本。
4. **本宪法不是合规证据链**：ponygo 是工程化治理脚手架，本宪法及其成熟度不构成任何监管合规背书（FDA、ISO 13485/26262、SOC2、PIPL 等）。强监管项目请另行接入专用合规框架。
5. **禁用 AI 代理时整体退场**：若团队合规上禁止 AI 代理接触代码，在 `meta.yaml` 置 `ai-surface: off`——`ponygo sync` 将不生成 `AGENTS.md` / `CLAUDE.md`，AI 适配节登记项一并失效即代表永不开启。
<!-- END constitution -->
