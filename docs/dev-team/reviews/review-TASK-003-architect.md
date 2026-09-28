# 对抗评审结论 —— spec-ponygo-v2.4.md rev1

**结论：不通过。**（方向保留，按 P0 修完可复审为有条件通过；rev1 不可直接实施。）

亲自核对：spec 全文 201 行；三条 proposed ADR 全文；三份 review-TASK-003-{l2,upgrade,release}.md 全文；ponygo warn_meta_violations(1078-1086)/verify_ladder 2.5(1258-1265)/cmd_upgrade(1608-1621)/write_skeleton `if [ ! -f` 全集/read_level(61-73)/入口 parser(1678-1705)；maturity-ladder §1/§5/§6；tests/run.sh s12(418-460)/s14(489-555)/s27(886-978)/s28(980-1001)/s29(1003-1019)/runner 尾部(1021-1036)/helper 头部(1-60)；install.sh 全文；README §3.1(44-57)。另实测：`status -sb`=ahead 1（spec §1.1 写 ahead 0，错）、tag v2.3.0=b8b7e28=HEAD 未推、工作树 6 个未跟踪文件（spec 写"仅 TASK-003.md"已过期）。

## P0（每条独立否决）

- **P0-1 s15 锁与 donot 直接冲突，spec 漏改 s15。** s15(557-561)在全新空目录（无 init、无 .meta）跑 `upgrade` 断言 exit 0；spec §3.2 donot 要求"无 .meta/→die 指引 init"（exit 1）。实施后 s15 必红。spec §8 只新增 s31、不改 s15——upgrade 评审 P1-3 的 exit 争议没闭环，只是挪了位置。
- **P0-2 "无基线"单列的判定函数不可写。** write_skeleton 全员 `if [ ! -f ]`（constitution/README/meta.yaml 从未留"来源 marker"），事后 tmp 重生成 + diff 无法区分"init 时已存在"与"模板生成后用户填写"——两者 diff 都非空。按 spec"diff 非空即无基线、不判漂移"，已填 constitution 恒进"无基线"，其内部的真破坏（Standing Orders 被删）永漏；meta.yaml 的 level 是实例状态 vs 模板 `level: %s` 参数，永远 diff，同样恒"无基线"。这是把 upgrade 评审 P0-2"问错方向"的反方向问题又藏回去：基线从未建立的文件，spec 用"不判"一笔勾销，而不是诚实声明盲区。
- **P0-3 s30 欠覆盖 §3.1，验收会漏。** §3.1 承诺：CRLF 断言（`grep $'\r'`）、哈希对象=checkout blob（非 zip/tarball）、action 钉 SHA、仅 tag-push 触发；§8 s30③只断言"精确管线+runs-on: ubuntu-latest+顶层 permissions:{}"。四项少三项半—— release 评审 P1-2/P1-3 的教训 spec 自己正文写了、测试没收。
- **P0-4 §1.1 基线事实错误。** "HEAD 与 origin/main 一致（ahead 0）"实测 `rev-list origin/main..HEAD`=1、`status -sb`=ahead 1。基线错则"干净/一致"不可信，且与 release 评审取证（ahead 1）自相矛盾。
- **P0-5 A5 条件验收不可执行=散文。** TASK-003 A5"v2.4.0 若发布，否则记录 blocked 证据"+spec §9"以实际发布版本为准，可改为 v2.3.0"——发布与否取决于本任务外的动作（推 tag/建 Release/网络），两种结局都算"交代"，验收恒过。这正是 release 评审 P0-2 否决的"不可验证的交付=散文"的同构复发。另与 s29 tag 一致性打架：README 先 bump 到 v2.4.0 则 s29 红直到 tag 打上；不 bump 则 A5 无物可验——鸡生蛋顺序 spec 没写。
- **P0-6 宇宙不完备，未分类文件去向未定义。** s14 十文件与 spec §3.2 名单逐项对得上（10 个 diff 块+2 个 grep，表面过关），但 write_skeleton 文件集更大：docs/AGENTS.md、constitution、meta.yaml、根 README、.gitignore/.rgignore（追加语义）、gates/README（条件写入：`[ ! -s ] && [ -z "$(ls -A)" ]`，非空目录不生成）。docs/AGENTS.md 既不在宇宙也不在"无基线"三名单——静默忽略。gates 非空缺 README 时报漂移还是缺口？未定义。upgrade 评审 P2-2（eol/.gitignore 追加/sync 投影 AGENTS.md/CLAUDE.md/classes.local/exemptions）零处置——spec 自称"评审 4 P0→重切"，P2 被无声丢掉。

## P1

- **P1-1 `--check` 落点缺失。** 入口 parser(1678-1695)无 `--check` 分支（现报未知参数 die），usage/s01、与 `--run-specs` 互斥守卫、与 `--dry-run/--yes` 交互全未写。`--check` 与 s15 的关系需 s15 补断言，spec 没列。
- **P1-2 installer"同钉 tag"指代混淆。** install.sh L7-8 的 REPO_RAW_URL 已是 `$VERSION` 变量——真要改的是 README 方式 A 的 `.../main/install.sh` bootstrap 行。spec 独占写目标写 install.sh，s30②"默认 URL 含 tag 变量且为空回退 main"在 install.sh 上恒过、无意义。
- **P1-3 WP 串行无顺序=冲突排队。** R 改 README tag 示例 vs L 的 s29 tag 一致性——谁先谁后决定红绿；R/U/L 都写 tests/run.sh 尾部线性调用表(1021-1036)，spec §6 说串行但不定序。另 WP0"裁决与 R 静态并行（文件不相交）"未经证（consultant.md vs code.md 同在 reviews/）。
- **P1-4 L 选项 A 原子补丁缺件。** 缺 init 模板联动、§172-176 诚实条款改写样文、2.5 锚点统一（ladder §5 写 `grep -q '已激活'`，ponygo 1261 行判 `## 已激活文档家清单`）、TODO 残留模式（`【TODO】`？）、四分支精确字符串、lv1+on/lv3-5 行为。§3.3 说含"1082 白名单+铁律"，§5 WP-L 只列测试文件——ponygo 正文谁改？归属缺。
- **P1-5 "三问三选一"指代不明。** TASK-003 A1 的"三问"是 L 三选项，还是 upgrade 三项裁决（revisions/exit/P6）？consultant.md 验收无法写。R 明明无需 consultant，WP0 并行安排下裁决选 B/C 对 R 的 s29 扩展有无影响？未分析。
- **P1-6 read_level 与"无 level 按 L0"语义分裂。** read_level：缺文件/缺 level 行→"0"，但空值/畸形→""（交 verify 0.4 FAIL）。upgrade 的"无 level 按 L0"若复用 read_level，空值 case 会走 FAIL 而非 L0——spec 没定义"无 level"是三种缺失中的哪种。

## P2

- **P2-1 s30 harness 未定义。** 404 模拟（mock curl vs `SHA=""` 直调 install.sh）、README 命令抽取 vs workflow 抽取 diff 的归一化、纯 bash 解析 YAML 的脆弱成本（R P2-1 原话，未评估依旧）。
- **P2-2 悬空引用与 orphan 工作。** §5"revisions 见 §7"但 §7 无 revisions 一字；notes 拆条无 WP 认领；gates/README"引用不动模板"即第二副本，slop 第一条撞线未讨论。
- **P2-3 s31 fixture 与输出格式未钉。** "真实 README"无判定（非占位即真实？grep TODO？）；"无漂移行"要求漂移行前缀先钉否则 assert 无靶子；"临时目录清理（无残留）"断言法（/tmp 前后 diff flaky）未给。

## P3

- 输出头"观察 vs 承诺"一句话字符串未钉，不可测；教训归因注释要求塞进用户可见输出，把评审史写进产品输出，撞 docs/AGENTS.md"禁历史叙事"写作规则，未讨论。

## 被挑战的假设

1. "宇宙=s14 即完备"——反例 docs/AGENTS.md 等生成物无家。2. "diff 非空+名单=无基线可判定"——反例模板生成后填 vs 先存后生成不可区分。3. "默认 0+--check 即调和 s15 与 P2"——反例 s15 空目录用例与 donot die 直接冲突。4. "串行即解决共享文件冲突"——反例无顺序的串行只是排队，tag 一致性顺序敏感。5. "A5 条件化是诚实"——反例恒过的验收=散文。6. "install.sh 改 tag 即同钉"——反例真动的是 README bootstrap 行。

## 建议修改（rev2 必修）

1. 重测 §1.1（ahead/未跟踪文件）。2. s15 同步改（空目录 die）或 donot 降级，二选一写死。3. "无基线"二选一：a)宇宙外文件根本不进报告（ leds"不在宇宙"诚实声明盲区），或 b)init 落盘来源 marker（新机制，走 revisions）。4. s30 补 CRLF/对象/pin/trigger，或 §3.1 降级。5. A5 去条件化：本轮要么推 tag 发附件验真链，要么移出门禁——不许"blocked 即过"。6. 钉 `--check` 的 parser/usage/s15 联动。7. 定 WP 顺序与 runner 尾部归属。8. 澄清 consultant 三问清单。

## 是否升级 consultant

**是。** L 三选一（价值判断）+ upgrade 的 exit 语义（P2 边界）与"无基线"盲区可接受性（P6 诚实）仍需裁决；R 按 release 评审结论无需 full consultant（双代码复审+security 快审即可）。
