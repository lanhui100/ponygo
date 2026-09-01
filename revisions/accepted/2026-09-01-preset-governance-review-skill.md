# Revision: 预置 governance-review 技能——第二类框架交付技能（用户点名调用）（accepted）

Status: accepted

## 框架规则变更

`ponygo init` 骨架预置第二个技能 `.agents/skills/governance-review/SKILL.md`：
对用户"审查治理体系 / 治理体检 / 找治理问题点 / 判断是否升级"请求的入口封装。
frontmatter 标 `disable-model-invocation: true` + `user-invocable: true`（dsh-translate-docs
范式）——重型审查流程只许用户点名，禁模型自主路由。技能内容 = 全面治理审查程序：
真相源清单 → 证据命令（status/audit/verify-note/git log）→ 五面审查（结构/决策/
卫生/升级/盲区）→ 证据锚定的问题清单表格 + 水位 + 升 L2 判据依据。skills/README
例外条款更新为两类：write-adr（自动路由）+ governance-review（用户点名），
两者均为框架交付物、不计入 L4 实例资产证据。

## 采纳理由（回馈证据）

用户要求"下达质量指令让 AI 审查治理体系"——审查程序若只作为 prompt 存在于对话中，
每次都要重写、不可复现；若作为 `.meta/` 游离文档，无触发机制、必成死资产
（框架最警惕的"无触发的文件"）。技能形态是唯一同时满足"可复现 + 有触发 +
进发现路径"的载体（`.agents/skills/` 对 agent 可见）。审查是重型 review 流程，
故按调用权限分层（methodology §3.3 设计模式 1）禁自主路由。

## Alternatives considered

- **审查 prompt 放 `.meta/` 或 docs/ 当普通文档**：否决——无触发机制，agent 不会
  主动读，退化为死资产。
- **做成 CLI 第七子命令（ponygo review）**：否决——六命令面是拍板不变量；且审查面
  语义部分机器到不了，命令会退化成"prompt 打印器"。
- **挂进 bootstrap 自动执行**：否决——审查会消耗大量上下文且属于"用户点名才做"
  的重型流程，自动跑违背 P7/停止线。

## 影响面

- write_skeleton 新增 governance-review heredoc（与模板仓库逐字节一致，s14 覆盖）；
  skills/README 例外条款双写；bootstrap 日常步补"用户要求治理审查→governance-review"。
- 测试：s02 断言技能预置 + 禁自主路由；s14 逐字节覆盖 governance-review/SKILL.md。