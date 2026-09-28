# Review 记录 —— TASK-003 提案评审（upgrade 骨架漂移报告）

> 对象：`.agents/notes/proposed/process/2026-09-08-upgrade-drift-report.md`
> 评审者：独立对抗 reviewer（子智能体）｜ 结论：**不通过**（4 条 P0，每条独立足以推翻；方向保留，重切后可达有条件通过）
> 核实方法：提案全文 + `ponygo` 的 `write_skeleton` 与 `cmd_upgrade` 逐段核对 + `tests/run.sh`
> s14/s15/s29 + `.meta/gates/README.md` 全文 + `maturity-ladder.md` 附 + TASK-002 双审记录交叉验证
> 记录人：@orchestrator（转录子智能体上报消息，结论与分级原样保留）

## P0 问题

- **P0-1 `docs-tier/README.md` 双重分类自相矛盾，且 mixed 设计与已交付的激活契约不兼容。**
  提案把 `docs-tier/README.md` 列为 instance-owned，同时 mixed 又列"docs-tier 激活"用标记块断言。
  现实三重打架：(a) s14 对 `.meta/docs-tier/README.md` 做逐字节断言，激活即破 s14；(b) 已交付的
  激活机制是"改标题为已激活 + 填 TODO 表"，根本不是 `<!-- instance:begin/end -->` 标记块。
  提案发明了一套新激活机制，却未将其纳入 scope——Acceptance 第二条"已激活 docs-tier 零假漂移"
  在现有契约下不可实现。
- **P0-2 "缺失才写"语义下漂移基线不存在，提案问错了方向。** `write_skeleton` 全员 `if [ ! -f ... ]`。
  对 init 时已存在的文件（真实 README、已填 constitution、已有 `.gitignore`），模板**从未成为基线**——
  拿 tmp 重生成的模板去 diff，不是"漂移检测"而是范畴错误。提案只谈"用户已改文件误判"（实际不会误判），
  漏掉了真正的反方向问题；"三类划分"治标不治本，且划分清单本身与 s14 冲突，分类即新漂移源。
- **P0-3 template-owned 清单路径错误且不全，照此实施必错。** 提案路径缺 `.agents/`/`.meta/` 前缀；
  `verify-note.sh` 实路径是 `.agents/skills/write-adr/verify-note.sh`；`skills/*/SKILL.md` 实为 3 个
  具名技能，通配符掩盖了确切集合；遗漏 `docs/AGENTS.md`；`gates/README.md` 的条件写入语义与其他
  文件不同，不可同列。清单共 7 项，s14 断言 10 个文件——"比对宇宙"出生第一天就与 s14 对不上。
- **P0-4 `.meta/skeleton-owned` 是同一事实的第三副本。** 真源现状：`ponygo` heredoc（生成逻辑）+
  s14 断言（测试镜像）。新清单是第三份"模板所有"陈述，直接撞 `docs/AGENTS.md` slop 第一条与
  spec rev2 §4"制度化多副本"否决理由；缓解措施"清单 ⊇ 生成集测试"是第二层看守，加维护税且看守本身也会漂移。

## P1 问题

- **P1-1 教训归因错误。** "`gates/README.md` 自己写过的教训"——该文件全文无"假漂移/误报"一字。
  真源是 TASK-002 双审（architect P0-4 与 consultant P1-3），处置见 spec rev2 §10。
- **P1-2 mixed 标记块是框架规则变更，scope 漏项。** 改骨架模板 + s14 契约 + 激活程序三处，且既有实例
  文件无标记→全量误报，迁移面未定义。须进 scope 或砍。
- **P1-3 exit 语义未决。** s15 锁 `upgrade exit 0`；P2"凡机械可查的承诺必配非零退出"适用于"承诺"，
  漂移是观察还是承诺提案未裁决。若恒 exit 0，CI 无法消费；若漂移非零，则与 s15/Acceptance 冲突。
  缺机器可消费格式或 `--check` 开关定义。
- **P1-4 `donot` 三场景全未定义。** 现状 `cmd_upgrade` 无 `has_meta` 检查；非 git 仅打印提示；
  提案对无 `.meta/`、非 git、未声明 level 零规定。

## P2/P3 问题

- **P2-1** constitution 双重分类：instance-owned 列了 `constitution.md`，mixed 又列"constitution 槽位"——同一文件两类，判定函数不可写。
- **P2-2** 边界漏项：eol 归一；`.gitignore`/`.rgignore` 追加语义；`ponygo sync` 投影物（根
  `AGENTS.md`/`CLAUDE.md`，非 `write_skeleton` 生成）入不入宇宙；`classes.local`、
  `.meta/docs-tier/exemptions` 豁免项。
- **P2-3** `.meta/skeleton-owned` 自身归属悖论：谁生成它？若 template-owned 则自举；若实例文件则旧实例
  缺失→upgrade 先 die？与"upgrade 不落盘"承诺的关系也未写清。
- **P3-1** 与 status 语义差一句话：status 对骨架缺口 exit 1，upgrade 对漂移 exit 0——若保留此差异，
  需解释"缺口=承诺违例 vs 漂移=观察"，否则用户困惑。

## 被挑战的假设

1. "缺失才写文件的用户修改会被误判"——反了：用户修改是真阳性，真问题是基线从未建立的文件必报假阳性。
2. "三类划分能消灭假漂移"——划分清单与 s14/激活契约冲突，分类本身即漂移源。
3. "清单落盘 = 单源"——实际是第三副本；单源方向应是"源码 heredoc 即真源，测试动态派生"或
   "s14 的断言列表就是宇宙"。
4. "报告型 exit 0 无争议"——与 P2 适用边界、CI 消费、s15 三方未对齐。
5. "标记块是小改动"——实为框架规则变更 + 激活机制重切 + 全量实例迁移。

## 遗漏边界/测试

健康实例 fixture 零假漂移测试无定义；块外一致断言方式；清单⊇生成集看守的归属；donot 三场景测试；
CRLF；sync 投影物；`verify-note.sh` 式"只锁机械影子"的诚实标注缺失。

## 建议修改（重切方向）

1. template-owned 改精确路径并与 s14 逐项对齐，差异逐项解释（`docs/AGENTS.md` 归属先定）。
2. docs-tier 二选一：(a) 保持模板态+s14 不变，漂移报告诚实声明不支持已激活实例；(b) 重切激活机制为
   标记块——走 `revisions/`，同提交改模板+s14+激活程序。Acceptance 按所选重写。
3. 删 `.meta/skeleton-owned` 落盘方案；单源二选一：测试从 `ponygo` heredoc 动态派生清单，或直接以
   s14 断言列表为宇宙。
4. 基线定义：drift 基线 = 当前 CLI 模板生成物，并对"init 时已存在、从未以模板为基线"的文件在报告中
   单列标注（"无基线"，非"漂移"）。
5. exit：报告默认 exit 0 + `--check`（漂移非零，供 CI），复用 `audit --run-specs` 的 opt-in 范式。
6. donot：无 `.meta/`→die 指引 init；非 git→WARN；无 level→按 L0 处理。补三场景测试。
7. 归因修正为 TASK-002 双审记录（spec rev2 §10 处置表）。

## 是否需要升级 consultant

**是。** 标记块属框架规则变更须走 `revisions/`；exit 语义触及 P2 适用边界是价值判断；
新增清单 vs slop 单源是 P6 判断。建议三项裁决后再回审 rev2。
