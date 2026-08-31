# Agent Note: CLI 形态定为单文件 bash、零依赖

Status: implemented

## Problem

ponygo 要进入任意项目（包括非 JS、非 Python 项目）做治理骨架铺设与体检。
CLI 的运行时依赖越重，进入门槛越高，与"宁可粗糙、不可缺席"的停止线原则冲突。

## Decision

CLI 实现为**单文件 bash 脚本**（仓库根 `ponygo`），零外部包依赖，`set -u`，
命令面固定六条（init/audit/status/upgrade/sync/retire）。跨平台承诺边界为
Windows Git Bash / GNU 用户态（`find -printf`、`sed -i`、`date -d` 按 GNU 语义），
BSD/macOS 裸环境不承诺，诚实写入头注与 README §6.2。

## Alternatives considered

- **Node/Python 单文件**：引入运行时依赖，进入非对应栈的项目时门槛变高，否决。
- **多文件框架（bat 等测试框架、模块化源码）**：违背"单文件拷走即用"的分发模型，否决。
- **全平台兼容（含 BSD 裸环境）**：GNU/BSD 参数差异的兼容层维护税大于收益，
  选择收窄平台承诺并诚实标注（P6），否决。

## Consequences

- 安装器可以是 `cp` 一个文件（install.sh），分发极简。
- 测试也只能用纯 bash（见 testing 类决策），与 CLI 的零依赖约束保持一致。
