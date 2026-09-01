# Revision: write-adr 配机械验证器 verify-note.sh + 多类拆条成文（accepted）

Status: accepted

## 框架规则变更

1. **`verify-note.sh` 随骨架生成**（`.agents/skills/write-adr/verify-note.sh`）：
   write-adr 的机械验证脚本，等价 ponygo verify_ladder 1.1–1.8——路径两轴（1.3/1.4/1.5）、
   文件名与日期合法性（1.6）、Status 与目录一致（1.7）、骨架标题与 lifecycle 匹配（1.8），
   无参整树或指定单文件；exit 0/1。影子来自 DSH `verify-agent-note-format` /
   `verify-agent-note-classification`（脚本 + 负样本 + 门禁的模式）。
   write-adr 的「验证与报告」步改为：先 `verify-note.sh` 全绿，再 `ponygo status` 无 WARN。
2. **多类拆条成文**：notes/README 触发规则补"一次变更命中多个类别 → 拆多条记录，不合并"；
   write-adr 校准样例补"混合 ADR"反例（ponyllm 实证：治理采纳 + 未实施架构混装进
   同一条 implemented/process note → 状态轴失真 + class 污染）。

## 采纳理由（回馈证据）

ponyllm 试点：agent 把"采纳治理"（真实已落地）与"架构设计"（零代码，纯提案）合并成
一条 implemented note——1.8 只锁标题结构、锁不住内容真实态。诊断：缺"拆条"条款 +
  缺可执行的机械校验器（DSH 的 skill 依赖 verify 脚本，ponygo 的 skill 此前只依赖
  `ponygo status`，而 status 是 CLI 外部依赖，改由 skill 自带脚本自证）。
  分家后的正确形态：已落地 → implemented（现在时），未实施 → proposed（Proposal 将来时）。

## Alternatives considered

- **只依赖 `ponygo status` 做验证**：否决——status 是外部 CLI 依赖，skill 应自带
  零依赖校验器；且 status 的 WARN/模拟语义与"单条 note 校验"粒度不同。
- **校验器放 `.meta/gates/`**：否决——gates 属 L2 基建；L0/L1 阶段 skill 自带脚本
  即可用，将来挂 L2 钩子时直接引用该脚本（与 lefthook 引用 scripts/ 同构）。

## 影响面

- write_skeleton 新增 verify-note.sh heredoc（与模板仓库逐字节一致，s14 覆盖）；
  SKILL.md 验证步与校准样例更新（双写）；notes/README 多类拆条（双写）。
- 测试：s23 覆盖合规树 exit 0 / 坏文件名 exit 1 / implemented 含提案标题 exit 1 /
  指定单文件抓违例 exit 1；s02 断言脚本随骨架生成。
- 存量实例（如 ponyllm）：技能目录缺 verify-note.sh 属 init 前特性，重 init 或
  从框架仓库复制即可获得。

## 设计快照补充（2026-09-01 复核问答留存）

**为何 .sh 而非 .ts/.py**：bash 与 CLI 同源（单文件、零依赖铁律，
`2026-08-30-single-file-zero-dependency-cli.md`）。ponygo 是栈无关元框架，
实例可能是任意语言栈——只要装了 ponygo，bash 必然存在；TS/Python 脚本会要求
实例自带 Node/Python 工具链，把门禁变成实例的进入税。DSH 用 TS 因其本身是
Node monorepo，工具链现成——两种定位的正确分岔，已写入 verify-note.sh 头注。

**为何一个脚本而非 dsh 的 format/classification 两个**：dsh 拆两个 gate 是服务
其门禁矩阵的粒度（分开挂钩子/CI、独立负样本 spec）；ponygo 的判据真源合一
（maturity-ladder §5 一张表，CLI 的 verify_ladder 本就合在同一个函数），且
verify-note.sh 的消费者是 write-adr 的"写一条验证一次"自证步——单出口优于
双出口。未来实例升 L2 建门禁矩阵时再按 format/classification 拆分，YAGNI。