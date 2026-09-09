# Revision: 负样本 spec 的执行判据改为 opt-in（`ponygo audit --run-specs`）

Status: accepted

## 回馈证据（TASK-002 双审 + 本仓实测）

判据 2.3「至少一个门禁带负样本 spec（构造非法样本证明门会拒绝）」的机械化实现长期只查
`*.spec.*` 文件存在性——空文件即命中（EXTERNAL-001 P1-2 已指出，当时只补了诚实标注）。
为把它变成真判据，TASK-002 初版让 `status`/`audit` **默认执行** `*.spec.sh`。双审实测否决：

- `ponygo audit --dry-run` 执行了 spec 并落盘 `WITNESS.txt`——`--dry-run` 的"不落盘"承诺被破；
- `PONYGO_IN_SPEC=1 ponygo status` 跳过 spec 后仍打印「L0-L2 机械判据**全部 PASS**」——
  判据从执行降级为形状却仍宣称通过（fail-open）；
- 无超时（挂死的 spec 会拖死体检）；
- 违反文件头写死的设计约束「判定优先只读」：`git clone && ponygo status` 等于对陌生仓库
  执行其自带脚本（`audit` 更是"旧项目改造"入口）。

## 框架规则变更

1. **`status`/`audit` 默认只读**：2.3 的机械化实现回到存在性判据，并在输出里如实标注
   "2.2 与 2.3 均为代理判据"。
2. **新增 opt-in 开关 `ponygo audit --run-specs`**：执行 `gates/*.spec.sh` 并断言各自 exit 0。
   - 有 `timeout` 时施加 30 秒上限；无 `timeout` 则如实降级（不假装跑过）；
   - `--dry-run` 下一律跳过并打印 SKIPPED；
   - `PONYGO_IN_SPEC=1` 已在环境中 → SKIPPED，**不计入 PASS**（递归护栏，fail-closed 语义）；
   - 无 `*.spec.sh` → SKIPPED（不计入 PASS），不判 FAIL；
   - 失败时报告**全部**失败 spec 及其输出尾部（不只最后一个）；有失败则 exit 1。
3. **`.meta/gates/README.md` 模板新增"负样本 spec 的两种形态"节**（仓库副本与 heredoc 双写）：
   给出 `*.spec.sh` 契约（自包含 / 只读仓库 / 秒级 / exit 0 语义 / 防递归）与诚实标注
   ——"执行判据只证明脚本自检通过，证明不了脚本真的构造了非法样本；后者靠 review"。
4. **`maturity-ladder.md` §5 的 2.3 行与注同步**：2.3 的机械实现 = 存在性；执行判据是
   opt-in 开关或 CI/pre-push 层直接跑 spec。

## 采纳理由

- 保住 `ponygo` 的架构不变量（只读命令不执行仓库脚本），同时把执行判据**交付出来**而不是取消；
- 迁移面清晰：既有实例默认行为不变（2.3 仍是形状判据，不会 PASS→FAIL）；想用真判据的实例
  加一个开关或把它挂到 pre-push/CI；
- 诚实标注随判据走（P6）：SKIPPED 必须出现在输出里且不并入 PASS，杜绝 fail-open；
- 成本：一个函数 + 一个开关 + 模板一段说明，零依赖、无新机械判据、无阶梯语义变更。

## Alternatives considered

- **默认执行 + 加护栏**（timeout / dry-run 跳过 / fail-closed）：否决。护栏能缓解但不能消除
  "只读命令执行任意脚本"这一架构面；`--dry-run` 的破坏已实测。
- **框架注入非法样本**（框架造坏样本 → 断言门非零退出）：方向更正确，但要求门声明输入契约，
  是新的框架能力，且执行门本身仍是执行仓库代码；留作独立提案。
- **完全回滚，只在文档里写契约**：否决。那样执行判据没有任何可运行入口，2.3 永远停在形状。
- **把非 `.sh` 后缀也算执行判据**：否决。后缀只是入口约定，且会诱导"改后缀绕过"这种自认
  可绕过的公告；诚实标注形态强度才是正解。

## 影响面

- `ponygo`：新增 `run_gate_specs()`、`--run-specs` 开关、`usage()` 与文件头注释、
  `verify_ladder` 2.3 注释与结论行标注；
- `.meta/gates/README.md`（仓库副本 + `ponygo` heredoc 双写，s14 逐字节看守）；
- `maturity-ladder.md` §5 的 2.3 行与注；
- `README.md` §3.2 命令说明 + §4.3 只读边界；
- `docs/methodology.md` §4.6 元门禁纪律：新增「只读判定不执行仓库代码」一条；
- 测试：`tests/run.sh` 场景 27（只读默认 / 执行通过 / 执行失败 / dry-run / 递归护栏 / 无 .sh / 非 audit 拒绝）；
- 版本：v2.3.0（README 示例同步）。
