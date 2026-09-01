---
name: governance-review
description: 何时用：用户明确要求审查本项目治理体系 / 治理体检 / 找治理问题点 / 判断是否升级治理级时。**只许用户点名调用**（disable-model-invocation: true）——重型审查流程防模型自主误路由；用户在一轮对话里提出即触发。
user-invocable: true
disable-model-invocation: true
---

# governance-review —— 全面治理审查

一次可复现、证据锚定的治理体系审查。只产出**问题清单 + 证据 + 最小改进动作**，
不代为决策（值不值归用户）。

## 真相源（冲突以它们为准）

- `.agents/notes/README.md` —— 决策契约：双轴路径 / 格式 / 时序 / 多类拆条 / 计划文档的家
- `.agents/skills/write-adr/SKILL.md` + `verify-note.sh` —— 写 ADR 的程序与机械校验
- `.meta/constitution/constitution.md` + 根 `AGENTS.md` 投影体 —— 命约 / 停止线
- `.meta/` 与 `.agents/` 各目录 README —— L2/L3/L4 升级契约

## 步骤

1. **跑证据命令**（输出贴进报告，作为每一结论的锚）：

   ```bash
   ponygo status
   ponygo audit
   bash .agents/skills/write-adr/verify-note.sh
   git log --oneline
   ```

2. **逐面审查**：
   - **结构面（机械）**：骨架完整？status/audit/verify-note 全绿？WARN 有哪些（尤其游离计划文档 / 非 git / 缺 .gitignore）？
   - **决策面（语义 + 机械）**：每条 ADR 的 Status/class 与内容真实一致吗（implemented 是否真落地、proposed 是否未实施）？时序符合"先 ADR 后代码/同提交"吗（git log 对照）？有多类混装吗？Alternatives 是真实候选而非凑数吗？
   - **卫生面**：游离计划文档？.gitignore/.rgignore 有效性？构建产物入版本库？
   - **升级面**：按 maturity-ladder 判据，到 L2 差哪几条（gates / 负样本 spec / hooksPath）？哪些"承诺"至今没有非零退出命令看守、全凭自觉（这是 L2 的信号清单）？
   - **盲区声明**：明确列出"判据管不到、全靠自觉"的清单。

3. **输出报告**（表格）：

   | # | 问题 | 严重度(P0/P1/P2) | 磁盘证据(路径+命令) | 最小改进动作 |
   |---|---|---|---|---|

   末尾给：当前治理水位一句话 + 是否建议升 L2（附判据依据）。

## 校准样例

- 正例：报告每条问题都附 `git show --stat <sha>`、`ponygo status` 输出、`find` 结果等硬证据；"游离计划文档"类结论直接指向文件名与 WARN 输出；拿不准的标"靠 review 待人工定夺"。
- 反例：凭空断言"ADR 时序有问题"却不给 `git log` 对照；把"值不值升 L2"当结论输出（该做的只是列出判据差几条）；把 review 层能判的（真实性）说成"机器已验证"。
- 边界（靠 review）：某条 ADR 的 Alternatives 是否"真实"——判据管不到，只列出疑点并附原文，让用户定夺。

## 验证与报告

- 本技能无退出码门禁（审查是 review 层；机械面已由 verify-note.sh / ponygo status 各自承担）。
- 交付物 = 审查报告（上述表格 + 水位 + 升 L2 建议）。
- 后续动作：把问题清单落一条 `.agents/notes/proposed/{class}/yyyy-mm-dd-governance-audit.md`（含本轮审查证据），修复按最小改进动作逐个执行并迁移 implemented——审查完不落 note 等于没审。
