# consultant 裁决 —— TASK-004 / spec-ponygo-v2.5 rev1 + 3条proposed ADR

> Task: TASK-004 ｜ spec: docs/dev-team/specs/spec-ponygo-v2.5.md rev1 ｜ 裁决人：@consultant（最终把关，证伪立场）
> 日期：2026-09-28 ｜ 前提：已用read/grep亲自读完全文，未采信转述（TASK-004 55行 / spec 205行 / 3条ADR全文 / checklist 126行 / skills README 70行 / gates README 66行 / methodology §0/§2.8/§3.2-3.3/§4.6/§7.1抽读 / review-TASK-003-consultant格式范例 / tests/run.sh s18+s29段）。
> 基线快照：checklist问②机制层止于2.6（2.7/2.8为[future]）；skills README仅三条纪律；methodology §2.8为dsh三元组口径；tests/run.sh s18锁机制层数15；gates README首版为空目录+三时间经济层。

## 1. 结论：有条件通过（rev2满足P1清单方可实施；任一P1未闭环即转不通过）

P0红线扫描结论：本次rev1文本无通用化红线命中（判据/纪律正文无dsh-/vitest/pnpm/tsx/benchmarks/scripts专名/CI job名/包数词数数字；无CLI改动、无升level、无追溯返工要求）。但有5个P1（rev2必修）、3个P2、2个P3。方向保留：G/I/S三包通用化方向正确，不做整套testing tiers/性能门禁/UI技能移植的非目标线守住了。

## 2. P0/P1/P2/P3问题

**P0：0条。**（明确声明：逐项扫§10 DSH特异否决表，未命中。既有基线.skills/README:62本身含dsh-translate-docs范式注，属祖父缺口，本次新增纪律4/5未扩大。）

**P1-1（s32-S验收空转，致命/必修）：** 位置spec §8 s32-S + TASK-004 A5。实证：methodology:236已含"卫生"（提醒档与卫生WARN同级），:357已含"证据链"（模型可见⟺已记录的证据链），故`grep -q '卫生\|证据链' docs/methodology.md`在实施前即PASS，无法区分前后。为什么致命：验收标准不可证伪，"放个空提交"过得了s32-S，复刻gates README:47-48警告的反模式。非红线但属测试完整性P0级，必须修（rev2把s32-S方法论侧靶串钉到新增句，如"计数不选优"/"每事实只说一次"/"证据链四件套"）。

**P1-2（编号时间炸弹，必修）：** 位置spec §3.1/§4（2.9–2.11追加）+ checklist:61-64（2.7/2.8 [future]夹在中间）。实证：2.6 active → 2.7/2.8 future → 2.9-2.11 active，未来激活2.7/2.8需重编号或永久留洞。为什么必修：顺序阅读断裂+未来迁移成本；spec §4"不动2.7/2.8防误读"只解一半。rev2二选一：(a)新条编为附录2.A/2.B/2.C或2.9起但§4写死"2.7/2.8激活时顺延不重编"；(b)把[future]2.7/2.8移至精微层末尾注释。推荐(a)。

**P1-3（gates README错位，必修）：** 位置spec §1.2/§3.1（gates新增可靠性节+节首声明无执行语义）vs .meta/gates/README.md:18-21（脚本放本目录+必须非零退出=拒绝语义+负样本spec）。实证：gates家载体契约是可执行门禁，把"无执行语义"节塞进去违反docs/AGENTS.md"每个事实一个家"。为什么必修：家污染，后续L2门禁实现者误把review程序当门禁。rev2：可靠性节正家改为methodology §4.6（原则+分类表唯一家），gates README只留一链入行+显式"本节非门禁"；或放cookbook/how-to。checklist判据链到methodology，不链gates节。

**P1-4（I包slug欠定义+合并判据不可验证，必修）：** 位置spec §3.2（slug路径/~/~2/代码块生成区不入哈希/相邻节落不同文本块review校验）。实证：未定义slugify（大小写/空格/标点/CJK/层级分隔符）、~2作用域（同级vs全局）、"生成区"边界（ponygo无.i18n.yaml实现，checklist 1.9仍[future]）、"互不干扰"无合并验证程序（git hunk 3行上下文+YAML块边界未量化）。为什么必修：推荐格式不可一致review，两人各判各的；"review校验"无程序=假门禁（P6要求语义判断配校准样例）。rev2：补slug最小规范5行+正反例一对（重名/首节/代码块排除），"互不干扰"降格为启发式（目标非保证）+给merge验证命令（改A节merge改B节清单实例）。

**P1-5（零影响与scorecard证明空洞，必修）：** 位置TASK-004 A4/spec §9（未声明双语实例零影响由本仓L1 exit 0证明）+ spec §2/§5 scorecard"可选实施者定"。实证：status/audit不读methodology正文，改§2.8永远L1 exit 0，A4恒真；scorecard变更无靶串、无验收覆盖。为什么必修：A4是恒真命题，scope含无断言文件=不可审计范围蔓延。rev2：A4改为前后输出diff断言（status/audit输出逐字节比对或fixture未声明实例跑status对比），scorecard要么删出范围要么给精确行靶串+s32断言。

**P2-1（2.9检查命令`|| true`违反checklist契约）：** spec §3.1的`grep ... || true`恒exit 0，按checklist:120-126"每个0分点映射最小改进动作+不同人跑命中数一致"，恒真命令无判定力；且`/tmp/固定`是POSIX专名（本仓CI有windows先例），`kill|abort|close`误报工厂。rev2：检查命令改为"review程序三步（抽新增测试各一例+记录F1-F7分类+复现阶梯到首个签名）"，删`|| true`，/tmp改为"固定路径（POSIX /tmp、Windows %TEMP%等价物）"。

**P2-2（证据链断裂：ADR零出处注）：** 三条ADR全文无dsh出处、无section-keyed回放数、无token实测、无链接，而spec §1.2/§3.2要求"实证来源只进ADR出处注"。方向对（判据侧干净）但可追溯性为零，变"无据断言"。rev2：每条ADR补"实证出处注"3行（dsh侧文件/提交/数据+等价物说明），spec §10 code复审加"ADR出处存在性"扫项。

**P2-3（S包token测量不可复现）：** spec §3.3"改动前后测首轮token变化"无命令、无基线、无模型/温度钉死，跨模型不可比，违反P2。rev2：降格为"有条件记录（模型名+提示版本+输入token数），无条件者标注未测"，methodology侧只留"有界输出/每事实一次"原则句，测量细则链到skills README且标靠review。

**P3-1（s32-G `grep -q '18'`弱靶）：** 匹配2018/1800任意18。rev2改为用法小结行精确匹配（`M 档.*18.*项`或实施后实际措辞）。

**P3-2（F1-F7分类重叠无决策树）：** F3全局污染vsF5平台差异vsF7外部瞬态在"仅CI红"时三可归，ADR Risks自认"分类只定位举证方向"。rev2 methodology §4.6补三问分流（隔离后显式overlap仍现→F6；换OS/shell消失→F5；串行消失→F3/F4），每类配一最小复现动作。

## 3. 被挑战的假设

A1"静态存在性断言足够守文档增量"—— false：s32只能证存在，不能证"旧格式仍有效首句""只约束新增节首""本节无执行语义"三句救命话存在，implementation drift时全绿说谎。需加三句精确断言。
A2"review程序会被读成review" —— false：无程序的review=自觉（methodology §0 P6诚实条款要求标注靠review+校准样例），本次G/I/S全是语义判断却只给0样例。至少I包slug、S包证据链各一对样例。
A3"15→18只是计数变更" —— false：s18锁15，scorecard/审计习惯/外部引用可能锁15，不止一处。WP-G原子补丁清单须列全（checklist用法小结+s18靶串+scorecard若动）。
A4"分节键降低merge冲突" —— 未证伪也未证实：ADR无-46%出处，ponygo无双语实例，收益函数在零实例上为零，成本（§2.8膨胀+slug学习）为正。I包价值仅在"首个双语实例出现时"兑现，应标注为Wave3期权而非当期收益。

## 4. 遗漏的边界或测试

B1 CJK标题slug（中文标题如何slug？拼音/哈希/原文？英文侧缺失时键取谁？）；B2 首节（首个标题前内容）键`/`与路径`/`冲突消解；B3 生成区定义（dsh生成区归一化 vs ponygo无生成器，谁判定某块是生成区？）；B4 YAML文本块边界与git merge hunk的量化关系（相邻节几行间隔才算不同块？）；B5 Windows等价物（2.9-2.11命令POSIX假设）；B6 scorecard联动（M档18后scorecard问②校准句是否漂）；B7 s18更新原子性（改checklist不同步s18则全量红，spec §7已预见但未列s18新靶串）。

## 5. 建议修改（具体到文件节）

M1 spec §3.1：2.9命令删`|| true`，补Windows等价物注；2.10/2.11写成三步review程序（抽样+分类+阶梯），掩盖清单六项明确只进gates链入行。
M2 spec §3.2：补slug 5行规范+正反例；"互不干扰为目标"后加"（启发式，非保证；验证见合并实例）"；旧格式有效首句给出精确行文。
M3 spec §4 S包追溯行：skills README节首精确行文"本节仅约束本提交之后新增/改写，既有三技能豁免（Rule of three）"。
M4 spec §8：s32-S方法论靶串改为新增句精确串；s32-G的18改为用法小结行匹配；新增s32-D（三句救命话断言：仍有效/只约束新增/无执行语义）。
M5 spec §2/§5：scorecard要么删出范围，要么给出一句精确文案+s32覆盖；WP-G原子补丁清单追加s18。
M6 TASK-004 A3-A5：grep关键词改为节标题精确串（'2.9 资源隔离'/'分节键记录'/'工具定义卫生'），A4改为前后输出diff。
M7 三条ADR：各补"实证出处注"节（dsh证据指针+等价物），否则§10 code复审无法执行"只许进出处注"扫项。

## 6. 是否需要升级/重切（rev2方向）

需要重切rev2，不升级level、不改CLI（硬约束保持）。rev2方向：(1)修P1-1..P1-5（靶串精确化+编号方案+家归位+slug规范+零影响diff）；(2)三ADR补出处注；(3)§10回填本裁决+architect裁决后方可WP-G→WP-I→WP-S串行实施（methodology/tests/run.sh单实施者串行，TASK-002 rev2 P1-5教训延续）。若P1任一未闭环，实施自动转不通过。无P0红线，故不否决方向。

---
*落款：@consultant 最终把关裁决，2026-09-28。若P1任一未闭环，实施自动转不通过。*
