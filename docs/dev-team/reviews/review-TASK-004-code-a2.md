# Code Review 复核 —— TASK-004 / code-reviewer-a 指出的 2×P0（收口轮已闭环）

> 复核人：orchestrator（主会话）｜ 2026-09-28
> 对象：@code-reviewer-a 收口复核消息（结论"不通过"，MUST-1/MUST-2 + P1-1/P1-2 + P2-1/P2-2/P2-3）

## 结论

**全部闭环**（MUST-1/MUST-2 已修；P1-1/P1-2 已对齐；P2-1 echo 已改；P2-2 S 段本就全称无需回退；P2-3 以 read 为准，快照以当前落盘为准）。

## 逐项回执

- **MUST-1 s32-D `只约束新增`必红**：已修。`tests/run.sh` 改为 `本节仅约束本提交之后新增/改写`
 （与 skills README:61 落盘全句逐字对齐）；spec §8 s32-D 同改。另把 D 段 `仍有效` 改为
 `旧整文件哈希记录仍有效` 全称复用（堵 consultant P1-1 点名的裸词模式在 D 段复活）。
- **MUST-2 §4.6/§4.7 全链错节**：已修。家在 methodology §4.7（`### 4.7`，:303）不动；
 checklist:60、gates:16、scorecard:61、run.sh s32、spec §1.2/§3.1/§4/§5/§8/§9/§10 全部改为 §4.7。
 基线行不动：methodology §4.6 旧节名、spec §1.1 基线"§4.6 只有只读判定/三禁令"、
 scorecard:52 dsh 实证旧引用。
- **P1-1 spec 与 code 靶串漂移**：已修。spec §8 s32-G 改为与 code 一致的
 `grep -qF '追加「机制层」（18 项）'`（checklist:129 原文含 `」`）。
- **P1-2 弱锚残留**：已修。D 改全称复用；I 加 `同级重名` 合判（`~2` 保留 + `同级重名` 并存）。
- **P2-1 s18 echo stale**：已修。`场景18` echo 改"骨架8/机制18/精微8"。
- **P2-3 快照不一致**：以 read 为准；当前 s32 为 `g()` 版（1029–1062），无双版残留。

## 通用化复核（code-a P3-2 同意）

新判据段无 dsh-/vitest/pnpm/tsx/benchmarks/job 名/量化值；`/tmp`+`%TEMP%`+非穷尽声明合规；
skills:64 `dsh-translate-docs` 为旧纪律祖父注；methodology §4 旧文属基线；
HANDOFF 15 + `ponygo:478` 三条零改动 = 豁免正确；CLI 零改动守住。

---
*落款：orchestrator 收口复核，2026-09-28。待可执行环境重跑 `bash tests/run.sh`（s18 + s32）即转绿。*
