# Spec —— ponygo v2.5：通用化吸收三类质量保障沉淀（rev2，可实施）

> Task: TASK-004 ｜ 复杂度: B ｜ 2026-09-28 ｜ **rev2**：依 @consultant（有条件通过）+ @architect（不通过）双审重切。
> 通用化红线：本 spec 只收**栈无关、可跨语言复用的原则与形状判据**；任何 DSH 特异选型
> （技能名 `dsh-*`、vitest/pnpm/benchmarks 目录、TS/JS 脚本名、整仓 CI 形状、双语中文配对实例值、
> 回放百分比/毫秒预算规范值）只允许出现在 ADR 的"实证出处注"，不得进入 checklist 判据、
> gates 链入行之外正文、skills README 纪律正文、methodology 原则句。
> rev1 处置：architect P0-1/P0-2/P0-3 与 consultant P1-1..P1-5 全采纳，见 §10 处置表。
> 前提：三条 proposed ADR 已落盘并补"实证出处注"；本文件是**实施依据**。

---

## 1. 背景与目标

### 1.1 实测基线

| 检查 | 结果 |
|---|---|
| `docs/methodology.md` | v3.0；§3.1/§3.2 收录 10 条模式/10 技能；**§3.3 实为 1–10（10=读写配对）**；§2.8 为整文件哈希配对口径（含脚本专名）；§4.6 只有只读判定/三禁令；§7.1 为符号搜索式简化勘探；§0/§5.2/§5.5 已含"证据链/卫生"词（s32 靶串须避开，见 §8） |
| `audit/checklist.md` | 问②机制层止于 2.6（绕行可控）；2.7/2.8 为 `[future]`（生成物漂移/覆盖率分区）；无可靠性条目；`:84` 写"三条纪律"；`:123` 用法小结"M 档追加机制层（15 项）" |
| `audit/depth-selector.md:16` | "骨架 8 / 机制 15 / 精微 8，权威真源"（WP-G 原子补丁须同步，见 §5） |
| `README.md:147` | "骨架 8 / 机制 15 / 精微 8…两套计数勿混用"（WP-G 须同步第二数；CLI 内嵌 10/14 口径不动，见 §5） |
| `docs/HANDOFF.md` | v0 历史快照（首部写死"保留收口时点原貌"）——**冻结豁免，不在本次原子补丁内**（见 §5/§7） |
| `.agents/skills/README.md` | 三条纪律（调用权限分层/输入契约/证据面匹配）；`:62` 含 `dsh-translate-docs` 范式注（祖父缺口，本次不扩大）；无卫生/证据链 |
| `.meta/gates/README.md:18-21` | 家载体契约=可执行门禁（脚本+非零拒绝+负样本）；故可靠性 review 程序**正家不在此**，本文件只留链入行（见 §3.1） |
| `ponygo:478` | "三条纪律"文本数词——**本次显式豁免**（CLI 可执行文件零改动硬约束；登记为已知 stale 例外，下次触碰 CLI 的任务顺手同步，见 §5/§7） |
| `tests/run.sh:591-594` | s18 断言机制层数 15（WP-G 获 s18 计数行修改权；除此行外不碰 s01–s31，见 §5/§6） |
| 写前检索 | `flake|reliability|readiness|quiescence|pairing|i18n|skill.*卫生|简化.*勘探` 在 `.agents/notes/`、`docs/dev-team/` 实施前无命中；TASK-004 为首案（复核命令见 §8 全量行之外的 `grep -r` 回执要求，实施者贴输出） |
| 本仓档位 | `ponygo status` 全程保持 L1 / exit 0（TASK-002/003 停止线裁决延续）；实施前后留输出 diff（见 §8 s32-D） |

### 1.2 目标

1. **G（通用可靠测试）**：三原则 + 七类诊断收为 checklist 问②机制层新条（**编号 2.A/2.B/2.C**，见 §4）；
 原则+分类表**唯一家 = methodology §4.7**，gates README 只留一链入行；checklist 判据链到 methodology。
2. **I（配对记录分节，opt-in 文档包，Wave3 期权）**：methodology §2.8 改为双格式说明（旧整文件哈希仍有效；
 新分节键格式为推荐，附 slug 最小规范 + 正反例）；未声明双语实例零影响以输出 diff 证明；I 包价值在首个双语实例出现时兑现，本次只备形状不等收益。
3. **S（技能卫生与简化勘探）**：skills README 增补纪律 4/5（11=工具定义卫生、12=简化勘探证据链与 skills 4/5 同序；
 methodology §3.3 现 1–10 不动，直接追加 11/12）；§7.1 增补证据链四件套 + 计数不选优。只约束新增/改写（精确行文见 §3.3）。

---

## 2. 范围与非目标

**范围内**：`audit/checklist.md`（问②新增 2.A–2.C + 用法小结计数 15→18 + `:84` 三条→五条 + 读者指引句）、
`audit/depth-selector.md:16`（15→18）、`README.md:147`（第二数 15→18，注明 checklist 口径）、
`audit/scorecard.md`（问②校准补一句精确文案，纳入 WP-G 验收，见 §3.1 末）、
`.meta/gates/README.md`（只加一链入行，不加节）、`docs/methodology.md`（§2.8 重写、§3.3 追加 11/12、§4.7 新增原则+分类+分流、§7.1 增补一段）、
`.agents/skills/README.md`（纪律 4/5 + 节首追溯句）、`.agents/notes/proposed/`（3 条 ADR 出处注已补）、
`docs/dev-team/`（task/spec/review）、`tests/run.sh`（新增 s32 + s18 计数行修改，见 §8）。

**非目标**：
- 不移植任何 DSH 整套 testing tiers（runner 分区、每文件覆盖率 100%、快照回放、浏览器基建）；
 不出现 runner/框架专名作为规范要求；
- 不移植性能门禁 required job（合成负载维度、预算校准倍率、CI job 名）；性能只在 methodology 界外声明加一句"通用证据驱动流程见 S 包出处注链"；
- 不移植 UI/UX 域技能；L5 域示例一笔带过，不断言；
- 不改六命令面（含 `ponygo:478` 数词豁免）；不动 `docs/HANDOFF.md`（冻结历史快照）；
 不升本仓库 level（停 L1）；
- 不要求既有单语实例补配对记录；不要求既有技能补卫生条；
- 不新增任何可执行门禁脚本（本次全是文档 + checklist 形状判据 + 静态断言，无执行语义变更）；
- `checklist 1.9` 仍 `[future]`，status 不检查配对。

---

## 3. 用户/系统行为

### 3.1 G 包：通用可靠测试三原则 + 诊断分类（编号 2.A/2.B/2.C）

checklist 问②机制层新增（S 档 8 项不变；M 档 15→18；用法小结同步；附读者指引句"2.A–2.C 为 active，
2.7/2.8 仍 future；2.7/2.8 激活时顺延编号、本附录号不重编；checklist 口径与 CLI 内嵌 10/14 是两套计数，勿混改 CLI"）：

- **2.A 资源隔离（原子分配，靠 review）**：并行测试的共享资源（端口、套接字、固定路径、
 外部命名空间、全局可变状态）由资源所有者的原子分配器获取，禁止先探后占。
 review 程序三步：抽新增测试各一例 → 记录 F1–F7 分类 → 复现阶梯升到首个签名。
 检查命令示例（**示例非穷尽**，等价物自认）：固定路径含 POSIX `/tmp` 与 Windows `%TEMP%` 等价物；
 动词示例含 cancel/shutdown/terminate/dispose，不限三动词。
- **2.B 就绪与完成等待（状态同步，靠 review）**：断言等待被测方拥有的可观测就绪或完成信号
 （就绪事件、握手、状态迁移、已拥有的 promise/退出码）；超时只做等待上界、不做正确性条件；
 固定 sleep 不得充当证据。同上三步 review 程序。
- **2.C 处置到静默（quiescence，靠 review）**：清理在获取后立即注册，覆盖断言失败路径；
 关闭或取消后等到子进程退出、服务关闭或等价完成信号，才算收尾完成。同上三步 review 程序。

诊断分类（**唯一家 methodology §4.7**；gates README 只留链入行"可靠性 review 程序见 methodology §4.7，本行非门禁、无执行语义"；checklist 判据链到 methodology，不链 gates）：

| # | 分类 | 一句话判据 | 最小复现动作 |
|---|---|---|---|
| F1 | 宿主资源碰撞 | 独立进程/job 争同一端口、套接字、固定路径、外部命名空间 | 并发双跑同签名 |
| F2 | 生命周期不完整 | teardown 在子进程/流/回调静默前返回，输出或变更漏到别的测试 | 断言后查子进程/流残留 |
| F3 | 进程全局污染 | 结果依赖执行顺序；env/cwd/时钟/随机种子/全局 mock 泄漏 | 换序/串行对比 |
| F4 | 负载敏感同步 | sleep/轮询间隔替代可观测就绪或完成信号 | 替换为状态等待再跑 |
| F5 | 平台或入口差异 | 在某 OS/某 shell/某构建物入口下稳定复现，他处通过 | 换 OS/shell/入口对比 |
| F6 | 产品并发缺陷 | 资源已隔离 + 显式 overlap 仍稳定复现（真 bug，归产品修） | 显式 overlap 复现 |
| F7 | 外部依赖瞬态 | 失败归属 live 外部边界；无已文档化重试政策时不得归 F7（防逃逸口） | 查重试政策原文 |

分流三问：隔离后显式 overlap 仍现 → F6；换 OS/shell/入口消失 → F5；串行消失 → F3/F4。
复现阶梯：单测进程 → 并发文件 → 多测试进程 → 归属门禁全量 → 跨 job 共享资源；每级只升到首个复现签名为止。
掩盖式修法清单（加超时/加重试/全串行/吞错/弱断言/加 sleep）**只进 gates 链入行附注**，不进 checklist 判据。
scorecard 问②校准补一句（精确文案，WP-G 同提交）："7–8 分要求 2.A–2.C 任一有 review 记录；9–10 分要求分类表可指到 methodology §4.7。"（s32-D 断言覆盖，见 §8）

### 3.2 I 包：配对记录分节（文档包，opt-in，Wave3 期权）

methodology §2.8 重写为双格式说明，首句精确行文为"**旧整文件哈希记录仍有效，已落盘实例无需迁移。**"：

- 旧格式段保留一节（有效性 + 判据 1.9 口径不变 + 现有 dsh 脚本实例标注保留为实例注，不删）。
- 新格式（分节键记录，推荐**新双语实例**采用）slug 最小规范 5 行：
 1. 键取标题 slug 路径，层级以 `/` 连接；首个标题前内容键为 `/`（与路径根同形但仅作节键，review 时以"首节"称之）。
 2. 英文小写字母数字连字符直用；空格/下划线转连字符；CJK 与其它原文保留原文去空格（不强制拼音或哈希；非英双语任取一侧为键侧，两侧节数对齐即可，不假设英文存在）。
 3. 同级重名依次 `~2`/`~3`（作用域=同级同名；跨级重名不编号）。
 4. 代码块与生成区（双语逐字节一致的内容；ponygo 侧由实例自认并在记录旁注"生成区定义见实例"）不入哈希；算法由实例自选。
 5. 条目排布以相邻节变更落不同文本块为**目标（启发式，非保证）**；验证见合并实例（改 A 节内容 → 与改 B 节分支合并 → 记录应无冲突）。
- 正例：两节 `getting-started`/`getting-started~2` 各改一处，合并无记录冲突。
 反例：同节两侧改同一哈希节，合并仍冲突（须先合 Markdown 再重算该节）。
- 未声明双语的实例：本节零影响（1.9 仍 `[future]`，status 不检查；零影响以 §8 输出 diff 证明，非恒真断言）。
- DSH 回放数字只许进 ADR 出处注，不进 methodology 正文。

### 3.3 S 包：技能卫生与简化勘探（11/12 钉死）

skills README 新增两条纪律，节首精确行文为"**本节仅约束本提交之后新增/改写，既有三技能豁免；改写指工具定义/提示节语义变更，纯 typo/格式除外；既有三技能未来语义改写亦触发。**"：

- **4. 工具定义卫生**：模型可见的工具定义改动（名/描述/参数/系统提示节）遵循最小上下文优先；
 延迟加载资源全部可检索；关键约束（权限/破坏性/必备校验）前置到动作前；输出有界（给标识或路径而非全文倾倒）；
 每事实只说一次；有条件者记录（模型名 + 提示版本 + 输入 token 数），无条件者诚实标注未测（token 测量为有条件记录，非门禁）。
- **5. 简化勘探证据链**：删除或收窄类提案给出**证据链四件套**（owner、producer/consumer 路径、消失/保留清单、最强反方）；
 符号零命中不等于可删（动态消费者/已安装消费者/生成资产/扩展点需单独举证）；历史案例只作提问清单；
 **计数不选优**（提案数量不证明方法优劣）。

methodology §3.3 直接追加 **11=工具定义卫生、12=简化勘探证据链**（10 读写配对不动；细则只留 skills README 一家，
methodology 只留原则句 + 链入）。§7.1 增补同一四件套 + 计数不选优一句。

---

## 4. 技术方案与替代方案

| 决策 | 采用 | 否决的替代 |
|---|---|---|
| G 包落点 | checklist 附录号 2.A–2.C + methodology §4.7 唯一家 + gates 一链入行；判据=形状+review（P6） | 进 L2 硬门禁（跨栈语义不可机械判；小项目 friction，违反停止线）；gates 加"无执行语义"节（家污染，consultant P1-3） |
| G 包编号 | 2.A/2.B/2.C；2.7/2.8 激活时顺延不重编（consultant P1-2 方案 a） | 2.9–2.11（与 future 2.7/2.8 跳号，时间炸弹；architect P1-4） |
| I 包形态 | 纯文档双格式 + slug 5 行 + 正反例 + 启发式声明；旧格式有效；无 CLI 变更 | 加记录格式门禁（无实现，空门禁死重）；强制迁移旧记录（违反停止线） |
| S 包追溯 | 精确追溯句（§3.3），既有三技能豁免 | 全量返工（无消费者驱动，违反三次法则） |
| S 包编号 | methodology 11/12 钉死（architect P1-1），与 skills 4/5 同序 | "由实施者定"（验收不可判定） |
| scorecard | 纳入 WP-G（一句精确文案 + s32-D），去"可选" | 移出范围则 A3 链断；留"可选"则验收不可判定（architect P1-3） |
| 测试形态 | 静态存在性断言（全称锚定靶串）+ 输出 diff；无执行语义 | 动态自检（判据是 review 程序，无机械可执行体）；实施者定靶串（P2 假门禁） |

---

## 5. 影响面和依赖

- **文档**：`docs/methodology.md`（§2.8/§3.3/§4.7/§7.1 + 界外声明一句性能链）、`.agents/skills/README.md`（纪律 4/5 + 追溯句）、
 `.meta/gates/README.md`（**一链入行**）、`audit/checklist.md`（2.A–2.C + 用法小结 15→18 + `:84` 三条→五条 + 读者指引句）、
 `audit/depth-selector.md:16`（15→18）、`README.md:147`（第二数 15→18 + checklist 口径注）、
 `audit/scorecard.md`（问②一句精确文案）。
- **显式豁免**：`docs/HANDOFF.md`（冻结历史快照，不动）、`ponygo:478`（CLI 零改动；已知 stale 例外，见 §7）。
- **测试**：`tests/run.sh` 新增 s32（G/I/S/D 四段，见 §8）+ s18 计数行 15→18（WP-G 原子补丁；**除 s18 该行外不碰 s01–s31**）。
- **记录**：3 条 proposed ADR（出处注已补）+ 本 spec rev2 + 2 份 review；实施后按 write-adr 迁移状态。
- **依赖**：零新增外部依赖；零网络动作。
- **行为变更**：无。M 档 15→18 是计数变更，S 档 8 不变；CLI 本次零改动是因为"CLI 内嵌是 checklist 子集故免改"，非"永不改"
 （checklist 权威条款"CLI 与此不一致以此为准并回改 CLI"继续有效）。

---

## 6. 任务拆解与并行边界

| WP | 内容 | 独占写目标 |
|---|---|---|
| WP0 | 3 条 proposed ADR 出处注 + 本 spec rev2 + 双审闭环（两份 review **可并行**，不同文件） | `.agents/notes/proposed/`、`docs/dev-team/` |
| WP-G | checklist 2.A–2.C + 用法小结/`:84` + depth-selector + README:147 + scorecard 一句 + methodology §4.7 + gates 一链入行 + s18 行 + s32-G/D(G 部分) | 上述文件（methodology/tests 按序串行） |
| WP-I | methodology §2.8 重写 + s32-I/D(I 部分) | `docs/methodology.md`、`tests/run.sh`(s32-I/D 段) |
| WP-S | skills README 纪律 4/5 + methodology §3.3/§7.1 + s32-S/D(S 部分) | `.agents/skills/README.md`、`docs/methodology.md`、`tests/run.sh`(s32-S/D 段) |

**并行边界**：`docs/methodology.md` 与 `tests/run.sh` 是 WP-G/I/S 共享写目标——
单一实施者串行推进，不开并行子智能体改同一文件（TASK-002 rev2 P1-5、TASK-003 §6 教训）。
**执行顺序钉死**：WP0（本 rev2，双审已闭环）→ WP-G → WP-I → WP-S → 全量回归。
s32 按 G/I/S/D 顺序追加，归属唯一；runner 尾部调用表同序。

---

## 7. 风险、回滚与迁移

| 风险 | 缓解 |
|---|---|
| checklist 15→18 下游红 | WP-G 原子补丁含用法小结 + depth-selector + README:147 + s18 行 + scorecard 句；同提交落地 |
| `ponygo:478` stale | 显式豁免为已知例外；下次触碰 CLI 的任务同步"三条→五条"；本次 code 复审不以此打回 |
| HANDOFF 被顺手改 | 冻结豁免；实施者不得改 HANDOFF（历史快照），review 见 HANDOFF diff 即打回 |
| review 程序被读成机械门禁 | 每条行内"靠 review"；gates 链入行"本行非门禁、无执行语义"；methodology 家段标靠 review + 正反例 |
| I 包被读成强制迁移 | §2.8 首句精确行文（§3.2）；未声明双语零影响以输出 diff 证明 |
| S 包追溯返工压力 | 节首精确追溯句（§3.3） |
| DSH 特异回流 | §10 否决表 + ADR 出处存在性扫项；methodology 正文数字断言已覆盖 |
| methodology 篇幅 | 原则句 ≤3 段；slug 规范表/正反例表/分类表为例外（只此三表，不另开附录） |

**回滚**：每包纯文档增量，可整段 revert；s32/s18 行可整段 revert。无 tag/Release 动作，无不可逆点。

---

## 8. 测试计划（靶串全部钉死，无"实施者定"）

| 场景 | 断言 |
|---|---|
| s32-G（新，静态，全称锚定；失败报 file:line） | `grep -q '^| 2\.A '`；`^| 2\.B `；`^| 2\.C `；`grep -qF '追加「机制层」（18 项）'`；`五条纪律`；`methodology §4.7`；`本行非门禁` + `加超时`（gates 掩盖附注） |
| s32-I（新，静态） | `分节键`；`旧整文件哈希记录仍有效`；`grep -qF '~2'`（+ spec 本行对齐 `-F`）；未声明实例零影响见 s32-D |
| s32-S（新，静态，全称） | `工具定义卫生`；`简化勘探证据链`；`本提交之后新增/改写`；`计数不选优`；`每事实只说一次`；`证据链四件套` |
| s32-D（新，救命话 + 联动） | `约束本提交之后新增`；`仍有效`；`2.A–2.C 任一有 review 记录`；`分类表可指到`；`机制 18`（depth-selector + README）；实施前后 `ponygo status` 输出 diff 为空（未声明双语实例；实施者贴前后输出，review 确认）+ `ponygo audit --level M` 条目数 15→18 变化唯一 |
| s18（改，计数行） | `tests/run.sh` s18 靶串 15→18（WP-G 同提交； старше "s29"指引作废，以本行为准） |
| 全量 | `bash tests/run.sh` fail=0；`bash .agents/skills/write-adr/verify-note.sh` exit 0；`ponygo status` 本仓 L1 exit 0；另附写前检索 `grep -r` 回执（§1.1 最后一个复核点） |

---

## 9. 验收标准

见 TASK-004（A1–A6，rev2 配套修订：A3 靶串改为 `2.A 资源隔离`/`methodology §4.7`/`本行非门禁`；
A4 改为"分节键 + 旧格式有效原句 + status 输出 diff 为空"；A5 改为"工具定义卫生/简化勘探证据链/计数不选优"全称）。
补充说明：A4 的"零影响"以输出 diff 为证，非恒真断言；任何实施中发现的 CLI 改动需求一律退回 spec
（本次 CLI 零改动是硬约束，`ponygo:478` 除外登记为例外）。

---

## 10. 审核记录与采纳/不采纳说明

| 审核轮 | 审核者 | 结论 | 记录 |
|---|---|---|---|
| proposed 评审 | @consultant（对抗，证伪） | **有条件通过**（0 P0 / 5 P1 必修 / 3 P2 / 2 P3；P1 任一未闭环转不通过） | `docs/dev-team/reviews/review-TASK-004-consultant.md` |
| proposed 评审 | @architect（独立对抗） | **不通过**（3 P0 独立推翻 + 6 P1；方向保留，重切可实施） | `docs/dev-team/reviews/review-TASK-004-architect.md` |
| spec rev1→rev2 | orchestrator（主会话） | 已重切 | 本文件；处置表见下方 |
| code | @code-reviewer-a / @code-reviewer-b | a：有条件通过（2 P1，已闭环）→ 收口复核转通过；b：不通过转有条件通过（P0-1–P0-4/P1-1–P1-5 全闭环） | `docs/dev-team/reviews/review-TASK-004-code-a.md`、`review-TASK-004-code-b.md`、`review-TASK-004-code-a2.md`（收口复核） |

rev1→rev2 处置表：

| 来源 | 处置 |
|---|---|
| architect P0-1（15→18 原子补丁 + 不碰矛盾 + s29 笔误） | 采纳：§5 补齐 depth-selector/README/scorecard/checklist:84 + s18 修改权；"除 s18 该行外不碰 s01–s31"；§7/§8 "s29"改 s18；HANDOFF 冻结豁免 |
| architect P0-2（s32 真空/脆弱/外包） | 采纳：§8 全靶串钉死锚定全称，删"实施者定"；S 侧避开既有"卫生/证据链"裸词，改全称 |
| architect P0-3（三条纪律联动 + CLI 两难） | 采纳：checklist:84 进 WP-G；`ponygo:478` 显式豁免为已知例外 |
| architect P1-1（§3.3 编号事实错） | 采纳：10 不动，直钉 11/12 |
| architect P1-2/P1-6/P2-2/P2-4/P3（I 包欠定义/栈无关/载体/实例去留） | 采纳：§3.2 slug 5 行 + 正反例 + 启发式 + 非英说明 + 载体自认 + 旧段保留 |
| architect P1-3（scorecard 可选） | 采纳：纳入 WP-G，一句精确文案 + s32-D |
| architect P1-4（2.9 跳号） | 采纳：改 2.A–2.C + 不重编规则 + 读者指引句 |
| architect P1-5（并行名实） | 采纳：§6 明示两份 review 可并行；WP-G/I/S 串行 |
| consultant P1-1（s32-S 空转） | 采纳：方法论靶串改新增句全称（计数不选优/每事实只说一次/四件套） |
| consultant P1-2（编号炸弹） | 采纳：方案 a（2.A–2.C + 顺延不重编） |
| consultant P1-3（gates 家错位） | 采纳：methodology §4.7 唯一家；gates 一链入行 |
| consultant P1-4（slug + 合并不可验证） | 采纳：5 行规范 + 正反例 + 合并实例 |
| consultant P1-5（零影响恒真 + scorecard 空洞） | 采纳：A4 改输出 diff；scorecard 给精确文案 + s32-D |
| consultant P2-1（`|| true` + /tmp + 动词） | 采纳：删恒真式，改三步 review 程序 + 等价物注 |
| consultant P2-2（ADR 零出处） | 采纳：三 ADR 已补"实证出处注"；§10 否决表加出处存在性扫项 |
| consultant P2-3（token 不可复现） | 采纳：降格有条件记录 |
| consultant P3-1/P3-2 | 采纳：18 锚定整句；§4.7 补分流三问 |
| code-reviewer-a 复核（收口轮） | 采纳：s32-D 靶串改全句 + §4.6→§4.7 全链 + spec 对齐 code（`追加「机制层」（18 项）`/`-F`）+ s18 echo 改 18 |

DSH 特异否决表（code 复审逐项扫，命中任一即打回）：

- 判据/纪律正文出现 `dsh-` 前缀技能名、vitest/pnpm/tsx、benchmarks 目录、`scripts/*.ts` 专名、
 CI job 名、整仓包数量/词数预算数字、回放百分比/毫秒预算规范值；
- checklist 检查命令限定单一语言栈（如只给 `*.spec.ts` 不给等价物说明）；
- methodology 正文引用 DSH 量化值作为规范值（只许进 ADR 出处注）；
- 三条 ADR 任一缺"实证出处注"；
- `docs/HANDOFF.md` 出现 diff；`ponygo` 除外出现非预期的 diff（`ponygo:478` 豁免行除外）。

*（重大回改后重新审核受影响产物。）*
