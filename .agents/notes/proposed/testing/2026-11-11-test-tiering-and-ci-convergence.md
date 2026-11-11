# Agent Note: 测试分层与 CI 计数收敛

Status: proposed

## Problem

ponygo 的测试规模与 CI 反馈已经失真，继续按现状扩展会把维护成本转移到每次平台兼容修复上：

1. **计数口径混杂**：`tests/run.sh` 的 `pass` 由 `ok()` 累加（`tests/run.sh:14`），但 `s78`/`s81` 把子套件的 `##CASE pass=` 直接加入 `PASS`，而 `s88–s94` 把整卷折叠成 1 个 `ok`。当前输出 `pass=1817` 既不是用例数，也不是完整断言数；真实场景为 94 个，嵌套套件另有约 756 条被累加、约 700 条被折叠漏计。
2. **测试分层不清**：平台无关的重型套件与 Windows 专属断言（CRLF/EOL、symlink、hooksPath）混在同一全量任务里；Windows 全量在可见日志中约 91.7 分钟，耗时集中在 `s78` Wave13、`s81` carrier-audit、`s88`/`s89` auditfix 等少数套件。
3. **失败定位成本高**：`tests/run.sh` 用 `out=$(...)` 整体缓冲（如 `tests/run.sh:4918`），缺少逐场景看门狗与流式时间戳；长时间无输出会被误读为死锁。CI 的 Windows 任务也没有 `timeout-minutes`，只能靠人工取消。
4. **契约漂移**：README/决策记录中的场景数、检查数与实际输出不一致（如 `2026-11-11-p0-anti-entropy-fixes.md:25` 的 1816 已过时）。把 `pass=1817` 当“1800+ 测试”会误导质量判断。

## Proposal

按“先统一计数，再分层 CI，最后优化平台预算”的顺序实施：

1. **叶子计数模型**：`tests/run.sh` 只让叶子断言增加 `PASS`；子套件输出单独解析为 `NESTED` 汇总，不再并入叶子 `PASS`；折叠套件另记 `FOLDED`。最终输出固定为 `scenarios=<N> pass=<leaf> checks=<leaf+nested+folded> skipped=<N>`，并保留旧的 `pass/fail` 退出语义。同步更新 README、HANDOFF 与相关 ADR 中的数字口径。
2. **Windows 双层验证**：PR 必跑 `windows-core`，只覆盖平台专属与门禁核心（CRLF/EOL、symlink、hooksPath、init/gate 关键路径）；`windows-full` 作为 nightly/手动任务保留全量覆盖，两者都加 `timeout-minutes`。禁止把 Windows 全量直接删除。
3. **逐场景可观测性**：`tests/run.sh` 为每个场景输出带时间戳的开始/结束行，并加单场景看门狗；超时报告场景名而不是整段静默。CI 日志按场景流式输出，禁止用整体命令替换缓冲全部输出。
4. **按平台/spec 设定预算**：回退“所有 spec 统一 90s”的临时策略，A2/A7 等按平台设置独立上限；AT2 的外部兜底随之内收，避免把 90s 当成 A2 正常耗时。超时值必须在 README 与 ADR 同步。
5. **落 ADR 与收据**：本提案转 implemented 时，附本地 `tests/run.sh`、`gate-hardening`、`auditfix`、`carrier-audit` 的原生退出码，以及一次 Windows core/nightly 的真实结果；未取得 Windows 证据前不得宣称 CI 全绿。

## Alternatives considered

- **保持现状，只改文档措辞**：否决。计数混淆会让“通过数”继续被误读，且 Windows 长静默问题不消失。
- **直接删除或跳过 Windows 全量**：否决。CRLF/EOL、symlink、hooksPath 是 Windows 独有覆盖；删除会违背 README 的双平台承诺，也会让 `ci.yml` 聚合门对 skipped 的处理失去意义。应拆 job 保留覆盖，而不是删覆盖。
- **只减少测试数量**：否决。当前问题主要是分层与计数，不是断言本身无价值；先砍测试会把真实门禁边界一起削弱。
- **只加 `timeout-minutes`，不改计数**：部分缓解取消成本，但仍无法解释 `pass=1817` 的含义，也无法定位慢场景。
- **把 90s 全局超时当作最终方案**：否决。它是 Windows 负载下的临时缓解，会放大所有慢 spec 的最坏等待，并让 AT2 的外层兜底失真；应按平台/spec 收敛。

## Acceptance criteria

- `tests/run.sh` 输出包含 `scenarios/pass/checks/skipped` 四类计数；`PASS` 只来自叶子断言，子套件不得直接加 `PASS`，折叠套件单独计数。
- 现有行为断言不删除、不弱化；计数变更只改变汇总口径，退出码仍为 fail-closed。
- `windows-core` 在 PR 上稳定结束并覆盖平台专属断言；`windows-full` 在 nightly/手动任务完整运行；两者均有 `timeout-minutes`，且聚合门不会把 skipped 计为通过。
- 每个场景有开始/结束时间戳与看门狗；单场景超时能点名场景。
- spec 超时按平台/资产分档，文档与实现一致；AT2 外层兜底与内层预算匹配。
- 本地 `tests/run.sh`、`gate-hardening`、`auditfix`、`carrier-audit` 原生 exit 0；Windows core/full 结果有真实日志；未验证项明确标注。

## Risks

- 计数口径会改变既有断言与文档数字，必须同批更新所有消费者，否则会出现“代码改了、测试仍按旧数断言”的二次漂移。
- 拆分 Windows job 会改变分支保护依赖，必须确认聚合门仍覆盖 core 任务；nightly 不能替代 PR 的平台必跑覆盖。
- 逐场景看门狗与流式输出可能改变 CI 日志体积/时序，需要限制单场景输出尾部，避免日志爆炸。
- 现有 `tests/run.sh` 是单文件大脚本，改动集中且回归面大；必须分小步提交并在每步保留旧输出兼容层。
