# TASK-005 —— Windows 平台缺口收敛（sync 的 ai-surface 行为 + gh6/A16 诊断口径）

| 字段 | 值 |
|---|---|
| Task ID | TASK-005 |
| 状态 | Backlog（wave-14 实跑暴露，已定位未修） |
| 复杂度 | B（产品侧行为差异 + 冻结验收诊断口径；不涉计数/分层契约） |
| 负责人 | 待指派 |
| 创建时间 | 2026-11-12 |
| 来源 | wave-14 Windows 实跑：run `43053605488`（commit `d1b922d`，windows-core） |
| 关联决策 | `.agents/notes/implemented/testing/2026-11-11-test-tiering-and-ci-convergence.md`（§Windows 缺口） |

## 背景

wave-14（测试分层与 CI 计数收敛）把 Windows 从「一个全量 job、从无绿证」拆成
`windows-core`（PR，core 层 27 场景）+ `windows-full`（nightly/手动，全量 94 场景）。
首轮真跑即暴露平台差异，其中**与 wave-14 契约无关**的两项残留未修：

- **产品侧（P0）**：`tests/acceptance/p0-fixes/verify-p0.sh` 的 A/B 两条断言在 Windows 红：
  1. `A 填槽+无键：不应投影命约（AGENTS.md 含 BEGIN constitution）`
     —— `ponygo sync` 在 `ai-surface` 键缺失时仍在 Windows 投影常载命约；
  2. `B off+残留：未提示残留投影`
     —— `ai-surface: off` + 残留 `AGENTS.md` 时未告警。
  判据：Linux 全绿、本机 CRLF 仿真亦绿 → 属 Windows 专属行为差异（路径/权限/换行之外，
  疑与 `git`/文件系统语义或 `sync` 的键解析相关，需在 Windows runner 上抓 `WIN-DIAG`）。
- **测试口径（P2）**：`gh6/A16` 的折叠行不变量（`fold + RED == 7`）在 Windows 得 0，
  需确认派生副本在 Windows 的 `core` 层实际执行路径。

## 为什么不在 wave-14 修

- wave-14 的交付面是**计数模型 / 分层 / 超时预算 / CI 拓扑**；上述两项是**历史遗留**
  （Windows 在 wave-13 及以前从未有过全量绿证，`verify-p0` 的 A/B 从未在 Windows 上跑绿过）。
- 每轮 Windows core 验证 ≈30 分钟，且产品侧修复需先定位（不能靠猜），超出本波闭环预算。

## 验收标准（完成条件）

1. `windows-core`（GitHub Actions，PR 事件）**实跑绿**：`bash tests/run.sh` exit 0 且
   汇总行 `scenarios=27 ... skipped=67`；
2. `verify-p0.sh` A/B 两条在 Windows 上绿，且**断言不放宽**（不得改成 skip、不得只比子串）；
3. `gh6/A16` 在 Windows 上绿；
4. `windows-full` 至少一次**完整绿证**（历史欠账），并在 README 写明真实耗时；
5. 决策入册（`## Alternatives considered`）与 CI 运行 ID 收据同批提交。

## 反例与收据

- Linux 全绿：`scenarios=94 pass=1054 fail=0 checks=2835 skipped=0`（本机）。
- Windows 红：run `43053605488` → windows-core `FAIL A`、`FAIL B`、`FAIL GH6/A16 ... 期望 [7]，实得 [0]`，
  汇总 `==== 结果：FAIL（嵌套失败 0 / 折叠失败 5）====`。
- 已修（wave-14 收尾，勿回退）：cp1252 编码崩溃、WSL `bash` 存根误用、gh6 guard 过窄、
  autocrlf 导致场景计数为 0、红相失败行被截断。
