# Agent Note: 命令面固定为六条

Status: implemented

## Problem

元框架的命令面若随功能膨胀，学习成本与文档同步成本（README 三处口径）
都随命令数线性上升；且每条命令都是终身维护税（P9）。

## Decision

命令面固定六条：`init`（铺骨架）/ `audit`（体检打分）/ `status`（现状 + 级自洽验证）/
`upgrade`（升级纪律）/ `sync`（宪法投影）/ `retire`（退级/退场）。
新能力的默认处置是并入现有命令或拒绝，不是加命令。命令面唯一真源是 CLI 的
`usage()` + case 分发，改动必须同步 README §3/§1 表/§7 索引三处。

## Alternatives considered

- **能力到命令一一映射**（如 verify/guide 独立成命令）：否决——命令面膨胀史
  （四→五→六）已证明每次膨胀都造成文档口径漂移。
- **upgrade 首版移出命令面**（EXTERNAL-001 P1-5 强方案）：否决——六命令是拍板不变量，
  改名/移除是破坏性变更；以措辞收敛消除期望落差（2026-08-31 修复）。
- **子命令嵌套**（如 ponygo gate add）：首版无此复杂度，否决。

## Consequences

- 六条命令各有一个非零退出语义明确的判定面；help 测试（场景 1）把命令面钉死。
