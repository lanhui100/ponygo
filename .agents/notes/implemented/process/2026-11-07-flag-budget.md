# Agent Note: 旗标预算——无必要不加旗标

Status: implemented

## Problem

ponygo 的命令面已经是六条核心命令 + `observe`，但每次加能力时最容易顺手加一个
`--with-*` / `--enable-*` / `--doctor` 开关。旗标是永久契约：每个旗标都要进 usage、
测试矩阵、文档与兼容性承诺，且组合态会指数膨胀。用户在 2026-11-07 的审查反馈中明确
要求：能直接做进命令行为的，不要新增旗标。

## Decision

旗标预算固定为三条：

1. 只允许三类旗标：`--json`（机读输出）、`--dry-run`（安全预览）、`--run-specs`
   （显式执行仓库脚本的 opt-in）。
2. 其余能力一律用**位置子命令**或**默认行为**表达，不新增行为开关：
   - 归档封印门禁用 `archive-verify.sh check|seal`（位置子命令，零旗标）；
   - 状态/审计的新信息默认打印（如骨架漂移、环境依赖行），不设 `--drift` / `--doctor`；
   - 三层门禁的 pre-push 只给文档一行命令，不生成 hook、不加 `--with-pre-push`。
3. 不新增子命令：归档封印是门禁脚本，不是 `ponygo` 的第七个子命令；命令面仍为
   `init` / `audit` / `status` / `upgrade` / `sync` / `retire` + `observe`。

## Alternatives considered

- **每个能力配一个旗标**（`init --with-pre-push`、`status --doctor`、`audit --drift`）：
  否决——旗标组合与文档/测试成本线性增长，且默认行为被切成多条互不覆盖的路径。
- **新增顶层子命令**（`ponygo doctor` / `ponygo archive`）：否决——破坏六条命令面的
  既有 ADR 契约，收益只是一个可复用脚本就能提供的检查。
- **环境变量开关**（`PONYGO_ARCHIVE_SEAL=1`）：否决——隐式开关比旗标更难发现，且与
  「零确认、可预测」的 CLI 语义冲突。
- **完全不加任何开关**：部分否决——`--json` / `--dry-run` / `--run-specs` 分别对应
  机读、安全预览、执行面 opt-in，三者是安全/契约边界，保留。

## Consequences

- 后续任何能力提案必须先回答「能否做成默认行为或位置子命令」；答不出才允许讨论旗标。
- `archive-verify.sh` 的写操作（`seal`）与读操作（`check`）共享一个脚本，不靠旗标区分。
- pre-push 层按需由使用者在自己的 hook 里加一行，框架不生成、不设开关。
