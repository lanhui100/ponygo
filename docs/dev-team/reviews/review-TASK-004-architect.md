# Review 记录 —— TASK-004 / spec-ponygo-v2.5 rev1（@architect 独立对抗审核）

> 审核者：独立子智能体（@architect 角色）｜2026-09-28
> 方法：通读 TASK-004 + spec rev1 + 3条proposed ADR + 判据真源（maturity-ladder §5、checklist、gates/skills README、methodology、tests/run.sh、scorecard/depth-selector）逐段核实 + grep实测计数与交叉引用
> 快照：本仓 `level: 1`（.meta/meta.yaml:20），`review-TASK-004-*` 尚无文件（glob零命中）

## 1. 结论

**不通过**（3条P0，每条独立足以推翻；另有6条P1）。方向可保留（G/I/S三包落点选择正确：checklist形状+review、不进L2硬门禁、不加CLI门禁均符合停止线），但rev1作为实施契约不可执行：口径原子补丁缺失、验收断言真空/脆弱、跨文件联动漏改，三者任一落地即制造口径漂移。

- 可保留：G包不进L2硬门禁、I包纯文档双格式不加门禁、S包只约束新增/改写，均符合P6/P9与停止线；DSH特异否决表（spec §10）方向正确。
- 必须重切：§5影响面/WP归属补齐联动文件；§8 s32靶串钉死；§3.3编号与追溯定义写死；scorecard可选范围澄清。

## 2. P0/P1/P2/P3问题

### P0-1 checklist 15→18原子补丁缺失，且与“不碰既有s01–s31”自相矛盾

- 实证：
  - `audit/checklist.md:123` M档“追加机制层（15项）”；`audit/depth-selector.md:16` “骨架8/机制15/精微8，权威真源”；`README.md:147` “骨架8/机制15/精微8…两套计数勿混用”；`docs/HANDOFF.md:33,56,108` 同口径三处；`tests/run.sh:591-594` s18断言 `机制15`。
  - spec `spec-ponygo-v2.5.md:57` 要求“8+15→8+18，用法小结同步改数”；`§5:129-132` 影响面只列checklist用法小结+gates+methodology+skills README+s32，不含depth-selector/README/HANDOFF；`§5:132` “不碰既有s01–s31”；`§6:145-147` WP-G独占写目标不含上述联动文件 ولا s18修改权；`§7:160` 却说“既有s29口径类断言若锁15则同提交更新（WP-G原子补丁）”。
- 推翻理由：按rev1实施，checklist变18而depth-selector/README/HANDOFF/s18仍锁15，违反checklist“口径以本文件为准”之外的多副本一致性（slop：同一规则多家复述）。且§5“不碰”与§7“同提交更新”直接矛盾，实施者无论动不动s18都违约。另§7引“s29”实为s18（s29是`tests/run.sh:1003` L6口径），指引错误，证明作者未实测。
- 同一缺陷在TASK-002 P1-2/P1-5已犯过（修正清单漏文件、并行边界错），属复发。

### P0-2 s32静态断言脆弱/真空，验收外包给实施者，不可机械判定

- 实证（`spec-ponygo-v2.5.md:175-177`）：
  - s32-G：`grep -q '2\.9'` 未锚定（会命中2.90/版本号）；用法小结“`grep -q '18'` 或等价行，实施者按实际措辞定靶串，review确认”——spec把靶串定义推给实施者，验收标准在评审时不存在，违反P2“凡机械可查必配命令”。
  - s32-I：`grep -q '仍有效'` 通用短语，误报率高；未要求新旧格式并存的负向断言。
  - s32-S：`grep -q '卫生\|证据链' docs/methodology.md` 实施前已绿——实测`docs/methodology.md:218（证据链完整性）、236（卫生WARN）、354,358（证据链）、42（证据链）`均命中，`audit/checklist.md:39`亦有“GC卫生”。该断言真空，通过证明不了S包落地。skills侧`证据链`虽当前未命中（skills README仅有“证据面”），但methodology侧真空已足以推翻“全量回归绿即正确”。
- 推翻理由：A3/A4/A5依赖s32，而s32或过于宽松（裸18/仍有效/证据链）或未定义（等实施者定），A3“audit口径不断”、A4“零影响”无法机械复判。

### P0-3 “三条纪律”跨文件引用联动漏改，S包落地即制造 stale 副本

- 实证：
  - `.agents/skills/README.md:59` “三条纪律”；`audit/checklist.md:84` “五要素+契约头部示例+三条纪律”；`ponygo:478` “三条纪律（源自dsh实证，methodology §3.3）”。
  - spec §3.3/`§5:129` WP-S只拥有skills README+methodology §3.3/§7.1+s32-S，未列checklist:84与ponygo:478。实施后skills变五条而两处仍写三条，复述即漂移（docs/AGENTS.md slop首条）。
- 推翻理由：与P0-1同类，独立足以造成口径漂移；且`ponygo`是CLI可执行文件，改它即违反“CLI零改动硬约束”（`spec §5:135-136`），不改则stale——spec把实施者推进两难，须在rev2明确豁免或放行清单。

### P1摘要

| # | 问题 | 要点与证据 |
|---|---|---|
| P1-1 | §3.3编号事实错误+“由实施者定” | methodology §3.3实为1–10（10=读写配对，`docs/methodology.md:211-222`），spec `§3.3:109` 却写“11读写配对已存在，本次追加为11/12，编号顺延由实施者定”。事实错+编号权外包，code复审无法判定。 |
| P1-2 | I包双格式欠定义 | `spec §3.2:90-93` slug算法（中文/标点/大小写？）、`~2/~3`冲突域、文件载体（新文件还是.i18n.yaml内？）、新旧区分、相邻节“不同文本块”形状均无示例与review程序。零影响vacuously成立但不可实施。 |
| P1-3 | scorecard“可选，实施者定” | `spec §2:37-38` audit/scorecard问②校准一句可选。若实施者跳过，A3是否仍过？验收不可判定。 |
| P1-4 | 2.9–2.11跨层跳号 | 机制层2.4–2.6后接2.9–2.11，中间隔精微层future 2.7–2.8（`audit/checklist.md:53-64`）。读者易误读2.9+为future。spec §4只说不动2.7/2.8，未给读者指引句。 |
| P1-5 | 并行边界名实不符 | §6一面切WP-G/I/S三包，一面定“单一实施者串行、不开并行子智能体改同一文件”（methodology+run.sh共享）。切分无并行收益；WP0的consultant/architect两份review可并行（不同文件）却未明示。 |
| P1-6 | “栈无关”自称 vs 平台特异示例 | §3.1检查命令`grep -rE 'free port\|探活后绑定\|/tmp/固定\|predictable'`含POSIX `/tmp`（Windows无此路径），`kill\|abort\|close`仅三动词（漏cancel/shutdown/terminate/Dispose）。作review起点可接受，但spec未声明“示例非穷尽”，易被读成穷尽清单。 |

### P2摘要

- P2-1 “8+15→8+18”混用两套计数：README:147已警告CLI内嵌10/14与checklist 8/15/8勿混用，spec §3.1:57写法未注明是checklist口径，易误导改CLI。
- P2-2 “英文侧标题slug”假设英方存在（`spec §3.2:90`），非英双语（如中-日）无定义，不够通用。
- P2-3 checklist 2.x与ladder 2.x命名空间碰撞（ladder §5有2.1–2.5门禁判据），spec未说明二者无关，读者易串。
- P2-4 I包dsh实例去留未定：methodology §2.8现含verify-translation-pairing/gen-translation-brief等脚本名，重写后删还是留实例标注？通用化红线（§2:4-6）未给methodology侧执行指引。
- P2-5 F7“符合其已文档化的重试政策”（spec:80）举证链缺失：无重试政策何来F7？易成逃逸口。

### P3摘要

- P3-1 复现阶梯“跨job共享资源”（spec:82-83）与本地判定只读原则的张力未说明。
- P3-2 §1.1“写前检索无命中”断言未附命令回执，复核时应补`grep -r`证据。
- P3-3 本仓`ponygo status`仍L1的基线未钉（A4/A6依赖它，但spec未要求实施前后输出diff留证）。

## 3. 被挑战的假设

1. “CLI零改动真守住”——表面守住（G/I/S均无执行语义），但P0-3证明纪律数联动迟早撞上CLI文本；checklist权威条款（“CLI与这里不一致以这里为准并回改CLI”）与本次“CLI零改动硬约束”并存，若未来CLI内嵌扩到机制层，硬约束即破。rev2应写明本次CLI是“子集故免改”，而非“永不改”。
2. “旧格式有效+零影响”——vacuously真（status/audit不查i18n，`checklist 1.9`仍future），但双格式无载体定义，零影响是“未定义故无影响”，不是“已证明无影响”。
3. “review程序可执行”——F1–F7分类与复现阶梯、卫生/证据链纪律均缺校准样例与抽查程序（抽几例、谁抽、输出何格式），与methodology §3.3现有“校准样例锚定判据”要求自相矛盾。
4. “串行即解决共享写目标”——依赖编排纪律而非机制，TASK-002 P1-5/ TASK-003 §6教训重申正确，但WP切分本身仍暗示可分包并行，应直接定单WP串行或显式钉顺序与归属。

## 4. 遗漏的边界或测试

- 联动文件：depth-selector:16、README:147、HANDOFF:33,56,108、checklist:84、ponygo:478、s18:591-594，无一在WP归属内。
- s32真空：methodology既有“证据链/卫生”命中未排除，应改钉新标题全称（工具定义卫生/简化勘探证据链/分节键+旧格式有效声明行全称），并对裸数字/通用词加锚定（如`^| 2\.9 `、`用法小结.*18`）。
- 中文标题slug、CRLF、首标题前`/`键、重名`~2`的负样本（review程序应列）。
- CLI内嵌M 14 vs checklist M 18分歧的读者指引（否则下一轮有人“顺手”改CLI计数）。
- 实施前后`ponygo status`/`audit`输出diff留证（A4零影响的真证据）。

## 5. 建议修改（rev2最小集）

1. §5影响面补齐：checklist用法小结、depth-selector、README §4、HANDOFF三处、checklist:84、ponygo:478（后者若坚持CLI零改动则显式豁免并登记stale为已知例外，或放行“文本数词”为例外清单）；WP-G获s18修改权并删去“不碰既有s01–s31”一刀切，改为“除s18计数行外不碰”。
2. §7风险表“s29”改“s18”，并与§5/§6统一。
3. §8钉死靶串：2.9–2.11锚定行首、用法小结`18`锚定整句、methodology侧用全称（工具定义卫生/简化勘探证据链/分节键/旧格式仍有效原句），删去“实施者定靶串”；s32-S methodology断言改为全称，不用裸`证据链/卫生`。
4. §3.3修正“10读写配对已存在，本次追加11/12”，删“由实施者定”，直接钉11=工具定义卫生、12=简化勘探证据链（与skills 4/5同序）。
5. skills README节首追溯句写死：“新增指新目录；改写指工具定义/提示节语义变更，纯 typo/格式除外；既有三技能未来语义改写亦触发”。
6. scorecard一句去“可选”二选一：要么纳入WP-G验收，要么移出范围并说明不影响A3。
7. §3.1检查命令加“示例非穷尽”句，`/tmp`示例补等价物说明（如Windows TEMP）；§3.2补最小格式示例（三节YAML/JSON片段）与新旧区分规则；§10否决表加“methodology正文数字断言”已覆盖，保持。
8. WP顺序与runner尾部归属已钉（WP0→G→I→S），保留；另明示两份review可并行（不同文件）。

## 6. 与consultant可能分歧的预判

- G包方向（不进L2硬门禁、形状+review）预计一致；若consultant主张“部分机械化”（如端口分配 lint），architect坚持跨栈不可机械判、review程序需先有校准样例，否则是假门禁。
- I包价值：consultant可能质疑双格式是否为过度设计（单语实例占多数）；architect认为结构性冲突真实（ADR Problem成立），分歧在优先级而非正确性，可接受opt-in文档包但要求补格式示例。
- S包追溯：预计一致（不返工）；分歧可能在“改写”定义严宽，architect取严定义（语义变更即触发）以防逃逸。
- 计数口径：consultant可能放过P0-1为“实施细节”，architect坚持这是单源性红线（既往复发），不让步。

---
*落款：@architect 独立对抗评审，2026-09-28。重大回改后须重审受影响产物（§10惯例）。*
