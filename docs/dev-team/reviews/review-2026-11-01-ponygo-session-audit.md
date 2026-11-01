# 会话审计：两次 ponygo 运行的工具正确性 / 全面性 / 升级点

日期：2026-11-01　范围：**仅 ponygo 工具本身**（不评价 dev-team 技能、不评价业务改动）
方法：还原两个会话的完整工具轨迹 → 对照 `ponygo` 源码（`/home/dm/ponygo/ponygo`，与 `~/.local/bin/ponygo` 逐字节相同）→ 在实例仓 `/home/dm/pony-agent` 复跑取证。

## 1. 会话定位

| # | session | cwd | 用户原话 | ponygo 用量 |
|---|---|---|---|---|
| A | `session-mvx52lysqbqgbf`（09:16） | `/home/dm/pony-agent` | 「运行ponygo审计」 | `observe audit`×4、`observe status`×2；**顶层 audit/status/init 零调用** |
| B | `session-mvx55wtnk3y7ut`（09:18） | `/home/dm/pony-agent` | 「ponygo运行工程质量管理审计，非可观测性审计」 | `--help`、`audit`×3、`init --dry-run`、`init`、`upgrade`、`status`×2、`audit --run-specs`×2；另 4 次直接读 CLI 源码 |

会话 A 把「ponygo 审计」理解成可观测性审计（加载 `observability-onboarding` 技能 → `ponygo observe audit`），正是因为会话 B 的用户开场要加一句「非可观测性审计」来纠偏。这本身不是 ponygo 缺陷（`ponygo --help` 已分列 `audit` 与 `observe audit`，A 从未跑 `--help`），但说明「审计」在工具面上的第一落点仍偏 observe（技能描述与 observe 文档都在抢这个词）。

## 2. 正确性缺陷（按严重度）

### P0-1 `--run-specs` 执行判据结构性空转（框架自带 spec 永远被自家护栏跳过）
`run_gate_specs` 以 `PONYGO_IN_SPEC=1` 调用每个 spec（`ponygo:1620`），而框架唯一交付的负样本 spec A2 在 `PONYGO_IN_SPEC=1` 且无 `PONYGO_SPEC_SELFRUN` 时直接 `SKIPPED; exit 0`（`ponygo:1854-1856`）。于是新实例上 `ponygo audit --run-specs` **100% 报 skipped**，opt-in 执行判据从未真正跑过门。

物理收据（`/home/dm/pony-agent`）：
```
$ ponygo audit --run-specs ; echo rc=$?
  [skipped] 2.3 spec 自检：.meta/gates/adr-verify.spec.sh 自报 SKIPPED（不计入 PASS）
  [skipped] 2.3 执行判据：1 个 *.spec.sh 全部自报 SKIPPED——SKIPPED 不计入 PASS（本次未真正跑门）
rc=0
```
会话 B 为此白跑 2 次（t3s37、t3s42）；真正发现门的缺口，是靠它绕过 ponygo 直接 `bash .meta/gates/adr-verify.spec.sh`（t3s39 exit 1）。

### P0-2 「SKIPPED 不计入 PASS」只是文案，判定后果为零
同一份输出里：结论行仍写「级自洽验证：通过（L0-L2 机械判据全部 PASS；2.3 执行判据 SKIPPED——本次未验证）」（`ponygo:1554-1568`），命中仍 14/14，退出码仍 0。`SPEC_SKIPPED` 仅拼进一句 `spec_note`（`ponygo:1558`），不扣分、不降级、不改 exit——自相矛盾在同一屏内出现（会话 B t3s37/t3s42 输出原文）。

### P1-3 `upgrade` 的缺口补救指向一条死路（init 不会补骨架）
`ponygo upgrade` 对每个缺失骨架文件印「缺骨架文件——跑 'ponygo init' 补全后再跟随升级」（`ponygo:3501`）；但 `cmd_init` 在 `has_meta` 分支只做门禁装配，**明确不重铺骨架**（`ponygo:3152-3162`）。

物理收据（临时实例：`level:2` + `.meta/` + `.agents/notes/` + git）：
```
$ ponygo init            # 完成（幂等装配）
$ ponygo upgrade | grep -c '^缺口:'
10                       # 全部仍提示“跑 'ponygo init' 补全”——闭环指引是死循环
```
会话 B 的代价：`init`(t3s20) → `upgrade`(t3s27) 仍 7 缺口 → 只能自己按 SKILL.md 手写 `.agents/skills/write-adr/verify-note.sh`(t3s40)，且手写版本与模板不一致，现在反而成了 `drift:` 项。

### P1-4 `status`「骨架完整」与 `upgrade`「缺口 N」对同一实例结论相反
`status` 的骨架判据只查 7 个目录 + `meta.yaml`（`ponygo:3402-3405`），不查 `UPGRADE_UNIVERSE` 的 13 个骨架文件。实例收据：`ponygo status` → `骨架完整。` 且 **rc=0**；`ponygo upgrade` → 7 缺口 + 2 drift。两个命令对同一事实给出相反结论，且修 CI 的那个（status）是绿的。

### P1-5 `observe audit` 的动态证据不可溯源 → 一次外部 POST 即刷绿 ob1/ob2
T4（`dynamic`）判据实际是「存在任意一条到达 Tempo 的 span」。会话 A t2s36 先用带 `pony.probe` 标记的探针失败，t2s37 改成「真实客户端打法」——伪造 `service.name=pony-agent`、`pony.app.name`、`scope=pony-agent-runtime`、`span=agent.turn`，凭 k8s secret 里的 ingest token 直接 POST，随后 t2s40 `observe audit` 由 ob0 变 ob2 PASS。ponygo 侧对证据来源（是否本项目进程发出）零校验。

### P1-6 M 档「负样本 spec」判据把普通单测算成门禁负样本（白送分）
`ponygo:3308-3309` 用 `*_test.go / *.spec.ts / test_*.py …` 在**全仓**找第一个匹配即 +1 分。任何有单测的项目都得分，而单测并不证明「门会拒绝非法样本」。会话 B 的 14/14 里就含这一项（实例有 `tests/runtime-store.spec.ts`）——判据语义与 2.3（`gates/*.spec.*`）冲突。

### P2-7 `below_target` 提示硬编码 `--level`，未传该旗标时也输出
判定只看 `cr < trk`（`ponygo:4501-4503`），文案固定为「当前级低于 **--level** 断言的目标级」(`ponygo:4632`)。会话 A 全程未传 `--level`（`模式: 体检（目标级取自 meta.yaml…）`）却收到该条，把 agent 往「补断言」方向误导；同时它与结论行「未达目标级」重复。

### P2-8 `init --dry-run` 与实际行为不一致（承诺 chmod +x，实跑不改权限）
`--dry-run` 在 `core.hooksPath` 未设时直接 return，只印「将设 core.hooksPath + 创建 .githooks/pre-commit（A3，chmod +x）」（`ponygo:2735-2737`），未检查该文件是否**已存在但不可执行**；实跑走「沉睡钩子——框架不改权限」（`ponygo:2902/2916`）。会话 B t3s13 的 dry-run 文案 vs t3s20 的实际文案正好相反，因此多花一步人工 `chmod +x`(t3s21)。

### P2-9 零缺口时仍打印空「缺口」标题
`ponygo:3329` 无条件打印「缺口与最小改进动作（按杠杆排序…）」，条目全条件化。会话 B 的 7 次 audit 输出里该标题下永远是空行，而真正导致 `exit=1` 的级自洽 FAIL 在下一节——结构性误导。

## 3. 全面性缺陷（判据覆盖缺口）

### P1-10 L2 满级不判「constitution 是否投影到根 AGENTS.md」
实例 `/home/dm/pony-agent/AGENTS.md` 里 `ponygo` 出现 **0 次**（`CLAUDE.md` 只是符号链接），即 AI 常载命约从未投影；`ponygo audit` 仍 14/14 PASS。且 `cmd_init` 的 `has_meta` 分支**不跑 `do_sync`、也不提示跑 `sync`**（`ponygo:3152-3162` vs `3200-3204`），既有项目永远收不到这条投影。

### P2-11 审计结果不可机读、不可逐项核对
顶层 `audit/status` 无 `--json`（`--json` 仅 observe，其他命令显式拒绝），M 档输出 30+ 行散文且夹具文案（提示 / 替代物认可 / 门禁分层）每次逐字重复。「命中 14 / 14 项」不给明细，agent 无法核对是哪 14 项、哪项刚变绿。

### P2-12 悬空文档引用
`audit` 让人去读 `checklists/audit.md`（`ponygo:3345`）、`status` 让人去读「`maturity-ladder.md`（仓库根）」（`ponygo:3422`）——两者都不在 s14 骨架，实例仓里也不存在（实测 `ls /home/dm/pony-agent/{checklists,maturity-ladder.md}` → No such file）。

### P2-13 缺「explain / 下一步」面，取证成本被迫转嫁给 agent
`observe audit` 把子判据塞进 free-text reason（`…证据：checks=T1:PASS,…,T4:PARTIAL`），既不解释 T4 查什么、也不给可执行修法。会话 A 从首次 audit 失败到 PASS 共 **41 次工具调用**，其中约 24 次是翻 skill 的 shell 脚本与内网端点（`sed -n` 读 `check-declaration.sh` 4 次、`grep T4` 3 次、读 `contract.json`/`declaration-rubric.md`、探 4318/HTTP 端点、从 k8s secret 抠 token）。同理会话 B 有 4 次直接读 `/home/dm/.local/bin/ponygo` 源码来推断行为。

## 4. 优化 / 升级点（建议排期顺序）

| # | 变更 | 消除的缺陷 | 落点 |
|---|---|---|---|
| 1 | `--run-specs` 不再对框架资产设 `PONYGO_IN_SPEC`（A2 走 `PONYGO_SPEC_SELFRUN=1` 直跑） | P0-1 | `run_gate_specs` |
| 2 | SKIPPED 有判定后果：exit 3（证据不足）或从命中里扣项，结论行不得同时写「全部 PASS」 | P0-2 | `verify_ladder`/`cmd_audit` |
| 3 | 新增 `ponygo repair`（按 `UPGRADE_UNIVERSE` 幂等补缺、不覆盖既有内容）；`upgrade` 缺口行直接给这条命令 | P1-3 / P1-4 | 新子命令 |
| 4 | `status` 复用 upgrade 的缺口口径，「骨架完整」不可与 `upgrade` 相反 | P1-4 | `cmd_status` |
| 5 | 新增 `ponygo observe probe`（受控探针：自带 provenance、由 ponygo 自己投递、内置等待窗口），并把 T4 判据绑定「探针/本项目进程产生」 | P1-5 / P2-13 | observe 子域 |
| 6 | `--run-specs` 后打印「已跑/未跑」的结构化摘要；M 档负样本判据只认 `gates/*.spec.*`，不再认普通单测 | P1-6 | `cmd_audit` |
| 7 | 新增 `audit/status --json` + `--quiet`（夹具文案收进 `--verbose`），并输出逐项命中明细 | P2-11 | 输出层 |
| 8 | 增加一条 L2 判据：根 `AGENTS.md` 哨兵块（未投影 → 提示 `ponygo sync`）；`init(has_meta)` 结尾提示 sync | P1-10 | `verify_ladder` |
| 9 | 文案/语义修正：`below_target` 只在显式 `--level` 时出现；零缺口不打印缺口标题；`--dry-run` 与实跑走同一判定分支；悬空引用改成框架仓 URL 或打进骨架 | P2-7/8/9/12 | 输出层 |

## 5. 结论

- ponygo 在两次会话里**没有给出错误结论**（A 的 ob0→ob2、B 的 7/14→14/14 都真实发生了状态变化），但有两处 P0 级「判定与声明不一致」：`--run-specs` 永远空转、SKIPPED 不影响任何结论；以及一处 P1 级可旁路：`observe` 的动态证据不溯源，一次伪造 span 就能刷绿。
- 全面性上，L2 满级不判 AI 常载命约投影、`status` 与 `upgrade` 骨架口径分裂、审计结果不可机读——这三条使「14/14 + 骨架完整 + 级自洽通过」这套绿灯的证据强度低于其表面。
- 最大效率黑洞不是缺判据，而是缺「explain / repair / probe」三个动作面：agent 被迫读 skill 的 shell 脚本、读 CLI 源码、手工伪造探针，合计吃掉两会话约一半的工具调用。

---

## 6. 修复状态（2026-11-01，dev-team B 级闭环）

修复提交 `e3fd9d8`（tag `wave-1-auditfix`），决策记录见 ADR
`.agents/notes/implemented/process/2026-11-01-audit-judgement-fail-closed.md`。

| 缺陷 | 状态 | 落点 |
|---|---|---|
| P0-1 `--run-specs` 空转 | 已修 | 深度护栏 `PONYGO_AUDIT_SPEC_DEPTH`，框架 A2 spec 现真实执行 |
| P0-2 SKIPPED 无判定后果 | 已修 | 0 spec / 全 SKIPPED / **部分 SKIPPED** / 护栏 → exit 3；FAIL(1) 优先；0 字节 spec 判 FAIL |
| P1-3 upgrade→init 死循环 | 已修 | 新增 `init --repair-skeleton`（只补缺失、绝不覆盖、失败非零） |
| P1-4 status/upgrade 骨架口径相反 | 已修 | `status` 增骨架文件缺口口径（缺口 N + 指引 + exit 1） |
| P1-6 M 档负样本把单测算分 | 已修 | 判据收窄到 `.meta/gates/*.spec.*`，框架交付 spec 与 0 字节文件不计分 |
| P2-7 `below_target` 误导 | 已修 | 仅随显式 `--level` 产生 |
| P2-8 dry-run 承诺 chmod | 已修 | hp 空分支按「已存在/可执行/不可执行」分流 |
| P2-9 零缺口空标题 | 已修 | 无缺口不打印缺口标题 |
| P2-11 审计不可机读 | 未做 | 延后（非本轮判据修复必需） |
| P2-12 悬空文档引用 | 已修 | 实例侧输出改为框架仓 URL 形态 |
| P2-13 缺 explain/probe 面 | 部分 | `init --repair-skeleton` 消除病灶；`observe probe` 延后另立项 |
| P1-5 observe 动态证据不溯源 | 未做 | 延后（需动 observability-onboarding 契约，另立项） |
| P1-10 AI 常载命约不判 | 未做 | 延后（新增 L2 判据会打断既有实例，需跨仓灰度） |

附带修复（复审期发现的既有缺陷）：`gate_hook_write_block` 在 0 字节/纯残块钩子上"声称重写却永不愈合"，
且会静默清空残块——`init` 现在会真正写出规范块并保持块外字节零删除。

交付验证：`tests/run.sh` 896/0；`tests/acceptance/auditfix` 11 文件 276 断言 0 fail；
adversarial 35/0；`ponygo audit` / `audit --run-specs` / `status` / `ci-verify.sh` 全 exit 0。
