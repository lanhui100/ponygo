# Revision: 骨架预置 write-adr 技能——Rule of three 的唯一例外（accepted）

Status: accepted

## 框架规则变更

`ponygo init` 生成的 `.meta/skills/` 从"空目录 + 占位 README"改为**预置唯一一个技能**
`.meta/skills/write-adr/SKILL.md`（触发式 description + 真相源 + 步骤 + 校准样例 +
验证报告五要素齐备）。该技能是**框架交付物，不计入** L4"实例已长出流程资产"的证据——
L4 判据仍要求实例按 Rule of three 自己长出第一个 skill（豁免条款写入 skills/README）。
其余技能一律不预置：空技能是被永久引用的死重。

## 采纳理由（回馈证据）

1. **消费者由框架自身创造**：L1 判据强制每个实例持续写决策记录——"写 ADR"是唯一
   第一天就保证重复三次的流程，Rule of three 对它天然满足，第一次重复就值得资产化。
2. **高频 + 高判断力**：何时写、写哪个 class、Alternatives 怎么写、何时算纯机械豁免，
   正是 skill 的定义域；校准样例可从 decisions/README 的触发规则直接锚定，可移植。
3. **文档承诺与交付物不一致**：methodology §10 Wave2 本就列了"write-adr skill"，
   但 init 未交付——与 EXTERNAL-001 P2-5 同类（"文档承诺生成物，脚手架没给"）。
4. **其余 dsh 式技能不可预置**：dsh-pre-push-checks 绑定 dsh 命令面，
   dsh-archive-agent-notes 的校准样例用 dsh 语料事实锚定——校准样例可移植性为零，
   预置即假资产。故例外仅 write-adr 一个。

## Alternatives considered

- **保守版：skill-library/ 放 ponygo 仓库、不进实例骨架**：否决——"照做不需要读文档"
  要求生成物直接落位；取用动作本身又是一条容易忘的口传流程。
- **预置 archive-decisions 等更多技能**：否决——归档流程的消费者（语料腐烂）不是
  框架创造的，不满足"保证重复"条件。

## 影响面

- 新实例 audit 问③"有技能目录"天然命中：S 档命中 4→5/10，M 档 4→5/14（测试断言同步）。
- 骨架 heredoc 与模板仓库文件双写，s14 逐字节测试看守。
