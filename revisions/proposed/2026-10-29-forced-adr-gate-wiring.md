# Revision: ADR 格式门接线——`ensure_gate_wiring` + 资产 A1–A5 + 判据 2.4 五条 AND

Status: proposed

## Problem

ponygo 的 L1 判据已能把 ADR 形状机械化（1.1–1.9，真源
`.agents/skills/write-adr/verify-note.sh`），但它只在人主动跑时生效——**框架本身不保证
"落了 ADR 就会被校验"**。三处结构性缺口（TASK 双审 15 条 finding 的收敛）：

1. **装配断链**：`cmd_init` 在 `.meta` 已存在时 `exit 0`（ponygo:1486-1490）→ ponyfun /
   job_copilot / ponyllm 等"已初始化实例"（正是目标人群）永远收不到钩子接线；
2. **判据可骗**：旧 2.4 只查 `git config core.hooksPath` 字符串非空——一行注释、一个不可执行
   钩子（git 静默忽略）、一个指向空目录的配置都能让它 PASS（R3/R5）；`git mv` 还能绕过
   pre-commit 传播的 `--diff-filter=ACM`（R7）；
3. **校验错字节**：`verify-note.sh` 读工作区，pre-commit 的输入是暂存区文件名——`git add`
   后再改文件，门校验的不是将要提交的内容（R6 TOCTOU）。

框架改动的判据：**"落了 ADR 就必须过机器格式门"这条承诺，能不能被一条非零退出命令抓到**（P2）。
当前答案是"不能"——这是 L2「承诺可验」尚未自洽的实证缺口。

## Decision

三条同时落地，缺一即承诺空心：

1. **装配恒等（`ensure_gate_wiring`）**：`cmd_init` 在 `.meta` 已存在时**不重铺骨架**，但仍执行
   幂等装配——缺什么补什么：补 A1/A2/A4 缺失文件、钩子生成/追加、`core.hooksPath` 设置
   （未设时设置并回读校验）、`chmod +x`。`--dry-run` 下只打印。
   装配是**非破坏性追加**：`pre-commit` 存在且未接线（可执行）→ 追加哨兵块，既有字节零改动；
   存在但不可执行 → 不改权限，判据 FAIL 并给出「`chmod +x` 或删除后重跑 init」；
   `hooksPath` 已设（含 husky 绝对路径）→ 一律不动，直接对该目录钩子追加块。
2. **资产契约 A1–A5 冻结**（双写：仓库模板 + `ponygo` heredoc，EOL 归一后逐字节一致）：
   A1 暂存区 ADR 格式门（含 R6 字节比对、R7 `ACMR`）、A2 负样本执行判据、A3 `.githooks/pre-commit`、
   A4 forge 无关全树门 `ci-verify.sh`、A5 GitHub 薄适配器（**按 forge 证据生成**）。
   宇宙表只登记 A1/A2/A4（A3/A5 是实例可编辑文件，进宇宙表会让实例永久 drift 红）。
3. **判据 2.4 加强为五条 AND**（`maturity-ladder.md` §5）：①`hooksPath` 已设 ②归一化
   （`pwd -P`/`realpath`）后目录内 `pre-commit` 存在 ③可执行 ④含哨兵尾行
   `# <<< ponygo-gate: adr-verify v1 <<<` 且块内有非注释行调用 `adr-verify.sh`
   ⑤`<root>/.meta/gates/adr-verify.sh` 存在。①–⑤ 全真才 PASS，编号与结论行文案（`2.1–2.4 PASS`）不变。
4. **非平凡判定边界写进技能**：`write-adr/SKILL.md` 增一节，五条非平凡（破坏契约/换核心依赖/
   改数据模型或协议/改架构分层与并发模型/改门禁与发布语义）与五条平凡（纯格式/纯文案/纯重命名/
   依赖 lock 更新/生成物），并明写「**判定权在模型，框架只锁落盘后的格式门**」（用户硬约束 C1）。

## Alternatives

- **新增 `ponygo gate adr` 子命令统一门禁入口**：否决。会在 CLI 内造**第三份** 1.1–1.9 判定副本
  （真源 + `verify_ladder` 已有两份），违反 P9；判定真源必须保持单一可读脚本。
- **fail-closed（未接线即非零退出 + 补救片段）**：否决（终裁 v2 §6.1）。把"框架没接线"变成
  "你的提交失败"，代价转嫁给用户；husky 项目无从自助。改为非破坏性追加，正常装配路径不再返回非零。
- **覆盖既有 `pre-commit`**：否决。job_copilot_marketing / cluster-infra / dsh-q20-web 均已跟踪
  自定义钩子，覆盖 = 销毁用户逻辑（R4）。
- **无条件生成 A5（`.github/workflows/`）**：否决。非 GitHub 仓被塞入从不运行的 YAML = 假接线；
  改为按证据生成 + `status`/`audit` 显式告知（不静默缺席，也不静默假在场）。
- **砍掉 CI 资产、只留本地钩子（维护税论）**：部分否决。本地钩子 `--no-verify` 可绕；改为拆出
  forge 无关的 A4（门禁逻辑本体）+ 薄适配器 A5，逻辑永远真实可执行。
- **只改 CLI 判据、ladder 文档滞后**：否决。ladder §5 是 CLI 的唯一真源，代码领先文档 = 漂移（R10）。
- **钩子内做 sha256 pin（供应链面）**：推迟（R11）。pin 需发布侧清单 + 校验时机设计，本期只登记
  Known risk，避免半成品的假安全感。
- **`init` 加 flock 防并行竞态**：推迟（R13）。锁本身新增失败模式；本期以"写 hooksPath 后回读校验"
  收掉最痛的静默失败面。
- **`audit`/`status` 加 `--strict` 分档**：否决（`ponygo audit` 无此旗标；且零开关是硬约束 C2）。
- **`dev-team` L3-P「六问 + 第 7 问决策追溯」并入本期**：推迟。跨仓依赖 `dev-nfr-lint.py`
  的 `REQUIRED_FIELDS`，独立 ADR 后续交付。

## Consequences

- **正常装配路径不再返回非零**（唯一非零 = 非 TTY 且无 `--yes`，R15）；C2「不得静默缺席」由
  "恒定装配"满足，而非由"失败报错"满足；
- **既有 L2 实例可能由绿变红**：旧 2.4 只看 `hooksPath` 字符串，新判据要求真接线——ponyfun /
  job_copilot / ponyllm / pony-sentry 的 `status`/`audit` 退出码快照需重录（预期 L2 未接线实例
  0 → 1，可解释且补救 = 重跑 `ponygo init`）。这是判据加强的**正确**结果，不是回归；
- **双写维护税**：A1/A2/A4 三处同源 + A3/A5 两处，任何资产改动必须三处齐改并 diff 验证；
- **已知代价四条**（R11 供应链面 / 不改 hooksPath 的可逆性折损 / 非 GitHub 远端层需人工一步 /
  双写税），登记于 `.agents/notes/implemented/process/2026-10-29-forced-adr-gate-wiring.md`；
- **覆盖缺口**：`## Alternatives considered` 是 notes/README 的强制契约，但 `verify-note.sh`
  1.1–1.9 不含该项 → A2 该 case 为探针（不私设第二真值）。修法方向：真源侧新增 1.10，
  随下一次框架变更统一做；
- **版本**：随 v2.8.0 发布（`README.md` 安装示例与校验和链路口径同步）；模型面/命令面不变，
  已有命令语义仅 `init` 在装配上变强。

## 验收

1. `bash .agents/skills/write-adr/verify-note.sh` → 0（整树 1.1–1.9）
2. `bash -n` 对 A1/A2/A3/A4 逐个 → 0（判据 2.2 代理）
3. `bash .meta/gates/adr-verify.spec.sh` → 0（拒绝语义 + 放行语义 + TOCTOU 文案）
4. `bash .meta/gates/ci-verify.sh` → 0（= 全树格式 + 门自检，远端层与本地层同结论）
5. `bash tests/run.sh` → `fail=0`（基线 587 pass 之上新增装配/追加/不可执行分支用例）
6. 真实 git 行为（非模拟）：临时仓 `ponygo init --yes` → `git commit` 触发钩子；非法 ADR 提交
   被真实拒绝（rc≠0）、合法 ADR 提交放行；`git add` 后再改文件 → 以「ADR 有未暂存改动」拒绝
7. 本仓 dogfood：`git config core.hooksPath .githooks` 后一次真实提交走 A3 → A1 → `verify-note.sh`；
   本仓 `bash ponygo status` 仍 0（L1，2.x 不在判据内，判据加强不抬等级）
