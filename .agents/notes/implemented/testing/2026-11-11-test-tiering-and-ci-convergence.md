# Agent Note: 测试分层与 CI 计数收敛

Status: implemented

## Problem

ponygo 的测试规模与 CI 反馈已经失真，继续按现状扩展会把维护成本转移到每次平台兼容修复上：

1. **计数口径混杂且存在假绿**：`pass` 由叶子 `ok()` 累加（实施前 `tests/run.sh:14`），但 `s78`/`s81` 把子套件 `##CASE pass=` 直接加进 `PASS`，而 `s88–s94` 把整卷折叠成 1 个 `ok`。输出 `pass=1817` 既不是用例数也不是断言数；更严重的是 s78/s81 在子进程 `rc≠0` 而解析出 `fail=0` 时**只打印 `RED` 不记账**（实施前 `tests/run.sh:3938-3942`/`:4467-4471`），s88 连输出都不捕获（`:4902`）——三处叠加构成既有假绿入口。
2. **测试分层不清**：平台无关的重型套件与 Windows 专属断言混在同一全量任务里；Windows 全量在可见日志中约 91.7 分钟，且**没有一次全绿证据**（旧运行 `42983056504` 于约 2h47m 被人工取消）。
3. **失败定位成本高**：`tests/run.sh` 用 `out=$(...)` 整体缓冲整卷套件，没有逐场景开始/结束时间戳；CI 的 Windows 任务没有 `timeout-minutes`，只能靠人工取消。
4. **契约漂移**：README/决策记录中的数字与真实口径不一致（如 `2026-11-11-p0-anti-entropy-fixes.md:25` 的 `pass=1816` 是混合口径的旧收据）。

## Decision

按「先统一计数、再分层、最后收敛平台预算」实施；四段契约冻结在 `.dev-team/contract-wave14.md`（rev5，仓外账本）。

1. **叶子计数模型**：`PASS`/`FAIL` 只由叶子 `ok()`/`bad()` 增加；s78/s81 记 `NESTED_*`，s88–s94 记 `FOLDED_*`（先缓冲再解析；优先级 `##CASE` 求和 > `断言：pass=` > `PASS=` > `##SUMMARY`；不可解析记回退条，只进 `checks` 并判失败）。唯一汇总行：
   `==== 测试结果：scenarios=<N> pass=<leaf> fail=<leaf-fail> checks=<三类之和> skipped=<K> ====`；
   `checks` 走**恒等式**（叶子+嵌套+折叠），不设独立累加器。
2. **fail-closed 加强**：`exit 1` ⟸ 叶子 fail>0 或 `NESTED_FAIL>0` 或 `FOLDED_FAIL>0` 或**任一被调用子套件 `rc≠0`**（修掉上述三处既有假绿）；`exit 2` 保留给配置类错误（非法 `PONYGO_TEST_LAYER`/`PONYGO_SCN_TIMEOUT`）。
3. **测试分层**：`PONYGO_TEST_LAYER ∈ {full(默认), core}`；core = CORE-27（平台专属 + init/gate/聚合门核心），排除 6 个慢套件（s78/s81/s89/s91/s93/s94）。CORE/NONCORE 以带标记的数据块落盘（块内行必须带前缀，否则 94 场景计数会翻倍并打断 `verify-p0.sh:121` 的硬数字断言；数据块须包在 here-doc 中，否则裸 `CORE sNN` 会被 shell 当命令执行）；过滤由场景体首/末的 `scn_begin`/`scn_end` 双守卫完成（`FUNCNAME[1]` 派生 id），**94 个顶层裸调用行逐字不动**。
4. **可观测性**：每场景打印可解析开始行 `  >> sNN_name <ISO8601>` 与结束行 `  << sNN_name <Ns>`；嵌套/折叠套件红相只回显尾部 ≤25 行；可选单场景看门狗 `PONYGO_SCN_TIMEOUT`（正整数秒，**默认禁用** ⇒ 行为零变化；陈旧 watcher 通过落盘 `scn-current` 二次校验防误杀——纯变量校验在 bash 中无效，子进程持有 fork 时的副本）。
5. **spec 超时按平台/资产分档**：`PONYGO_SPEC_TIMEOUT`（正整数秒，非法 `exit 2`）优先，未设时 Windows 180 / 其他 90（Linux 逐字保持 90）；`command -v timeout` 仅存在性不足 → 追加**语义探针** `timeout 1 bash -c 'exit 0'`，失败则 WARN 降级并 `export PONYGO_SPEC_NO_GUARD=1`；预算一次算定并 `export PONYGO_GATE_SPEC_TIMEOUT` 下传给出厂 spec；三个出厂 spec 自包裹只读该 env（未设默认 30），**spec 内零平台判定**（平台真值收敛到 `ponygo` 一处）；`audit --run-specs` 打印可 grep 的 `spec 预算=<N>s（来源：…）`。
6. **CI 双层 Windows**：删 `selftest-windows` → `windows-core`（PR/push，`PONYGO_TEST_LAYER=core`，`timeout-minutes: 60`）；新增 `windows-full`（仅 `schedule` nightly + `workflow_dispatch`，全量，`timeout-minutes: 240`）；`selftest-linux: 45`、`governance: 10`；`all-checks-passed` 名字不变、needs 四项、required 三元组须恰三 success，`windows-full` 允许 `skipped` **仅当非 schedule 事件**（事件感知，禁止 nightly 下「没跑」被当成「跑绿」）。文档指针去行号（`.meta/gates/README.md` 与 `ponygo` heredoc 同步，受 `upgrade --check` 逐字节校验）。

## Alternatives considered

- **保持现状，只改文档措辞**：否决。计数混淆会让「通过数」继续被误读，既有假绿入口仍在，Windows 长静默问题也不消失。
- **直接删除或跳过 Windows 全量**：否决。CRLF/EOL、symlink、hooksPath 是 Windows 独有覆盖；删除违背 README 双平台承诺，也让聚合门对 skipped 的语义失去意义。拆 job 保留覆盖，而不是删覆盖。
- **只减少测试数量**：否决。当前问题是分层与计数，不是断言本身无价值；先砍测试会把真实门禁边界一起削弱。
- **只加 `timeout-minutes`，不改计数**：部分缓解取消成本，但仍无法解释 `pass=1817`，也无法定位慢场景。
- **把 90s 全局超时当最终方案**：否决。它只是 Windows 负载下的临时缓解，会放大所有慢 spec 的最坏等待并让 AT2 外层兜底失真。
- **用 `RETURN` trap 产生逐场景结束行**：否决。`set -T` 会污染嵌套函数语义，且 94 个裸调用行不可改；改用函数体首/末双守卫。
- **在三个出厂 spec 内各写一份平台判定**：否决（门禁复审 F6）。5 份平台真值必然漂移；改为 `ponygo` 单点判定并 `export PONYGO_GATE_SPEC_TIMEOUT` 下传，spec 只读 env。
- **新增第 95 个场景承载契约用例**：否决。会改动 94 场景硬数字（README、`verify-p0.sh`、CORE/NONCORE 分区），故契约用例挂在既有折叠套件 `gate-hardening` 的 `gh6_test_tiering_contract.sh`，由 s90 执行且属 core 层。

## Verification criteria

- `tests/run.sh` 汇总行含 `scenarios/pass/fail/checks/skipped` 四类计数，`pass` 只来自叶子，`checks` 为三类之和；退出码 fail-closed（含子进程 rc）。
- 既有行为断言不删除、不弱化；计数变更只改变汇总口径。
- `windows-core` 在 PR 上跑 core 层并有 `timeout-minutes`；`windows-full` 在 nightly/手动跑全量；聚合门不把 skipped 当通过（schedule 下 windows-full=skipped 判失败）。
- 每场景有开始/结束时间戳，可选看门狗能点名场景；嵌套/折叠套件红相尾部回显 ≤25 行。
- spec 超时按平台/资产分档，文档与实现一致；AT2 外层兜底与内层预算同源推导。
- 机器收据：`bash tests/run.sh` exit 0；`gate-hardening`/`auditfix`/`carrier-audit` exit 0；`bash .meta/gates/ci-verify.sh` exit 0；`gh6_test_tiering_contract.sh` 149 断言 exit 0。

## Receipts

- 改动前基线：`bash tests/run.sh` → `==== 测试结果：pass=1817 fail=0 ====`，exit 0，13m19s（`.dev-team/regression-baseline-wave14.json`）。
- 改动后全量（实现冻结后的最终一次，Lead 亲跑）：`==== 测试结果：scenarios=94 pass=1054 fail=0 checks=2833 skipped=0 ====`，exit 0（叶子 1054 + 嵌套 756 + 折叠 1023 = 2833，恒等式自校验通过；折叠数随 gh6 断言增长，属预期）。
- core 层：`==== 测试结果：scenarios=27 pass=368 fail=0 checks=643 skipped=67 ====`，exit 0（`grep -c '^  ok   '` == `pass=`，`fold` 行 == 折叠套件数）。
- 契约与门禁：`gh6_test_tiering_contract.sh` **171 断言** exit 0；`gh2_ci_aggregate.sh`、`auditfix/run-all.sh`、`carrier-audit/run-all.sh`、`.meta/gates/ci-verify.sh`、`scratch-hygiene.sh`、`verify-note.sh` 全 exit 0。
- 配置类错误：`PONYGO_TEST_LAYER=bogus bash tests/run.sh` → 2；`PONYGO_SCN_TIMEOUT=abc bash tests/run.sh` → 2；`PONYGO_SPEC_TIMEOUT=abc ./ponygo audit --run-specs` → 2。
- 守卫降级：`PATH=/tmp/wtstub:$PATH ./ponygo audit --run-specs` → WARN + `PONYGO_SPEC_NO_GUARD=1` 下 spec 不再被假 timeout 假杀。

### Windows CI 实跑证据（首轮真值，含缺陷修复）

- 运行 `43031069740`（push 8edd7cf，windows-core）：**失败**，但拿到了第一份真实的 Windows core 层日志。
- 根因（Lead 本机复现）：Windows 控制台默认 cp1252 → 所有打印中文的 `python3` 调用抛 `UnicodeEncodeError` 并 rc=1、无 stdout。复现：`PYTHONIOENCODING=cp1252 python3 tests/acceptance/gate-hardening/gh2_ci_aggregate.py .`。CI 症状即 gh2 3/1、gh3 9/1、gh6 83/8（「解析器未产出 #PARSE-END 哨兵」是连锁反应）、verify-p0 15/2。
- 另两处 Windows 差异一并修掉：gh6 的 CLI guard 过窄（Windows 更慢 → C14 空串探针被判 124）、`autocrlf` 使 `^sNN_...$` 行尾多 `\r` 导致场景计数为 0（I-1 类断言）。
- 修法（测试侧，未弱化任何语义断言、未新增 SKIP）：14 个套件入口 `export PYTHONUTF8=1 PYTHONIOENCODING=utf-8`；`gh2/gh3/probe_server.py` 做 stdout/stderr `reconfigure(utf-8)` 与 `open(..., encoding=)`；gh6 内联 heredoc 统一 `python3 -X utf8 -`；gh6 guard 平台感知（Windows 60/300/300、Linux 8/20/90）；p0 计数 `tr -d '\r'`、沙箱比对改 `pwd -P`。
- 修复后本机全量仍绿：`scenarios=94 pass=1054 fail=0 checks=2833 skipped=0`；`gate-hardening`/`auditfix`/`carrier-audit`/`ci-verify`/`verify-note` 全 exit 0；`PYTHONIOENCODING=cp1252 python3 gh2_ci_aggregate.py .` → 0。
- 可诊断性同时修掉：汇总行 `fail=` 只数叶子、折叠失败也会 exit 1（CI 曾出现「`fail=0` 却红」）；现当 `NESTED_FAIL+FOLDED_FAIL>0` 追加 `==== 结果：FAIL（嵌套失败 N / 折叠失败 M）====`，红相回显改为**先输出全部失败行**再补关键行尾部（≤45 行），失败断言不再被 tail 截掉。

## Risks and known limits

- **Windows 真值（部分获得）**：本波首轮 windows-core 实跑**失败并已定位修复**（cp1252 编码 + guard 过窄 + autocrlf，见上节）；修复后的 Windows 结果以修复提交后的 CI 运行为准。`windows-full` 全量在 Windows 上**仍未有绿证**，预算 240min 仍属估算。未取得修复后 Windows 绿证前不得宣称「CI 全绿」。
- **分支保护无机器收据**：仓内无 `required_status_checks` 证据，`all-checks-passed` 是否真被分支保护引用属 `[UNVERIFIED]`，需 `gh api` 取外部收据。
- **双份真值残留**：AT2 夹具内仍自带一份平台判定（`is_windows()`），与 `ponygo` 的推导规则重复，已登记待办；后续可由 SUT 打印的预算行反向校验。
- **看门狗默认关闭**：`PONYGO_SCN_TIMEOUT` 未设 = 禁用，故「超时点名」是**可配置护栏**而非默认护栏；默认兜底仍依赖 CI 的 job 级 `timeout-minutes`。
- **`scn_end` 为 best-effort**：场景体内早退（`return`）会缺结束行，测试只断言「已开始者成对」。
- **nightly 冗余**：`windows-core`(27) ⊂ `windows-full`(94)，nightly 下同一 commit 会在 Windows 上跑两遍（估算 ≈28min 冗余）。本波不优化：core 是 PR 必跑语义、full 是覆盖语义，合并会破坏 PR 时延目标。
- **Windows 缺口（wave-15 待办，已登记）**：修复后 `windows-core` 仍红，仅剩 2 项且均已定位到最小面：
  1. **产品侧**：`verify-p0` 的 A/B 两条（`ponygo sync` 在 Windows 下「`ai-surface` 未声明仍投影常载命约」与「`off` + 残留 `AGENTS.md` 不告警」）。Linux 全绿、本机 CRLF 仿真也绿 → 属 Windows 专属行为差异，**早于本波存在**（历史 Windows 从未有绿证），非计数/分层改动引入。
  2. **测试口径**：`gh6/A16` 折叠行不变量在 Windows 得 0（诊断口径问题，非产品缺陷）。
  处理决定：本轮**不发 Windows 绿证**，按「Linux + governance 绿、Windows core 红」诚实交付，并把上述 2 项登记为 wave-15 backlog（主责=产品侧 `sync` 行为，验收=windows-core 实跑绿 + 保留同一组断言不放宽）。
- **94 场景守恒的自指风险**：`verify-p0.sh:121-122` 的 SCN 是现算后与 README 文本比对，两处同改即可洗白；独立锚是 `gh6` 内的字面 94 断言，三锚同改仍需 review 发现。
