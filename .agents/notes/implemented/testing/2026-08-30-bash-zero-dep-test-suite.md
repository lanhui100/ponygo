# Agent Note: 自测用纯 bash 场景化脚本，不引测试框架

Status: implemented

## Problem

CLI 的回归门禁必须满足：与 CLI 同为零依赖（否则"零依赖"承诺被测试击穿）、
场景可隔离（init/sync/retire 都落盘）、git 配置可消毒（命中数判定不得读机器全局配置）。

## Decision

`tests/run.sh` 纯 bash 实现：mktemp 场景化（cwd 隔离，trap 清理），
`bash "$ROOT/ponygo"` 调用（规避 clone 后 exec bit/shebang 问题），
pass/fail 计数、任一失败 exit 1。git 配置消毒用 `GIT_CONFIG_GLOBAL/SYSTEM`
指向空文件。场景覆盖到边界：CRLF、路径深度、封闭集越界、占位文件豁免、
sync 三分支、install.sh 安装与校验。文档口径数字（骨架 8/机制 15/精微 8）
用 grep 断言钉进场景 18，防口径漂移复发。

## Alternatives considered

- **bats 等 bash 测试框架**：引入依赖，违背零依赖约束，否决。
- **在仓库内跑场景（不用 mktemp）**：污染工作区，否决。
- **只测快乐路径**：否决——三轮对抗审核证明边界（CRLF/深度/消毒）才是 bug 密集区。

## Consequences

- 测试证据 = 一条命令（`bash tests/run.sh`），挂进 CI（2026-08-31 起，
  ubuntu + windows Git Bash 双平台）后才算"承诺可验"闭环。
