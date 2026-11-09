# Agent Note: `revisions/` 轨道冻结——框架级决策归口 `.agents/notes/`

Status: implemented

## Problem

ponygo 仓有两条决策轨道，边界写着"框架规则演进 → `revisions/`，本仓工程决策 → `.agents/notes/`"
（`revisions/README.md` §双轨边界）。这条分工在实践中失效了，原因是**它判不开**：

- **同一件事两处都能算**。"新增一条 L1 判据"既是在改框架规则（`revisions/` 的语义），也是本仓自己的
  流程/工具链变更（`.agents/notes/` 的触发条件）。判据 1.10 的两篇记录就是活样本：同一变更同时落了
  `revisions/accepted/2026-10-29-alternatives-criterion-1-10.md` 与
  `implemented/process/2026-10-29-forced-adr-gate-wiring.md`，两边都不完整。
- **旧轨道没有任何看守**。`revisions/` 只有 `proposed/` `accepted/` 两态，没有 lifecycle × class 双轴，
  也**不进任何门禁**（`verify-note.sh` 只扫 `.agents/notes/`；`.meta/gates/` 与 `ponygo` 对它的引用
  全是注释出处，0 条判据）。实测其 21 篇 accepted 中 **5 篇没有 `## Alternatives considered`、1 篇连
  `Status:` 行都没有**——给它接上判据真源，当天就有 6 篇恒红。写进无看守的轨道 = 写了也没人验。
- **它事实上已被弃用**。`revisions/accepted/` 最新一篇的日期是 `2026-10-29`；此后框架级决策
  （临时产物分家、审计机读面、旗标预算、归档封印、证据覆盖……）**全部**落在 `.agents/notes/implemented/`。
  轨道静默停摆，但 `revisions/README.md` 仍写着"框架维护者两套都用"——文档与事实相反。
- **不冻结点会继续付税**：每次框架规则变更都要先回答"这条算框架规则还是工程决策"，而答案无法机械判定；
  答错的代价是语料分叉（同一决策两份、各自缺一半），这正是 L4 负空间要清理的垃圾堆形态。

## Decision

**`revisions/` 轨道冻结为历史只读；框架级决策此后一律归口 `.agents/notes/`。**

1. **停止新增**：`revisions/proposed/` 不再接收提案（该目录现仅有 `.gitkeep`），
   `revisions/accepted/` 不再接收新条目。实例对框架的回馈改落 `.agents/notes/proposed/`——
   回馈即是"这条约定在原实例为何失效"的决策记录，本来就该走与其它决策同一条触发规则与同一套判据。
2. **历史件不改写、不迁移、不删除**：21 篇 accepted 保持原貌（`Status: accepted` 与 `## 回馈证据` /
   `## 框架规则变更` 的旧骨架照旧），继续作为"当时规则怎么写的"的引用目标。
   **冻结的唯一边界例外**：可机械验证的事实失真就地修正（如漂移宇宙文件数 十→十五——
   同一错误在 `.agents/notes/` 侧同批修，见 `implemented/process/2026-09-14-upgrade-drift-report.md`），
   因为留着与现状矛盾的数字等于让历史件冒充现行事实。表述、结论、判据口径一律不动。
3. **不再作现行权威**：任何"现行规则是什么"的问题以 `.agents/notes/implemented/` + `maturity-ladder.md`
   + `.meta/gates/` 为准；`revisions/` 只回答"当时为什么那样定"。`revisions/README.md` 头部同步标注冻结
   与归口去向（同一次变更内）。
4. **不接门禁**：不给旧轨道挂 `verify-note.sh`——按判定真源现在的契约逐轴实测，21 篇里有 **6 篇不合格**
   （5 篇缺 `## Alternatives considered`、1 篇缺 `Status:` 行，两者并集即这 6 篇；其余 15 篇过这两轴），
   而 1.7 的 `Status:` 词表只认 `proposed` / `implemented` / `rejected`，20 篇的 `Status: accepted`
   一条都不符。接上就是全树恒红门；"历史件按现在的判据合格"不是冻结语料该背的债。
5. **悬空引用的处置（冻结不免除引用可达）**：冻结只免除"历史件不再改动"，不免除"引用必须指向真实存在的
   文件"——指向 `revisions/` 的引用若指向不存在的路径，同批必须修（改指向真实存在的那篇，并在同句标注
   "`revisions/` 轨道已冻结，仅作历史只读"）。**本仓这一面当前已清零**：`ponygo observe --help`
   的「已知局限」现指向 `revisions/accepted/2026-10-25-observe-dimension.md` 并带冻结标注（K4 的完整
   局限清单在那里）；`README.md` 的 observe 段同样改指该篇并带冻结标注。**核实**：`grep -rn
   'revisions/proposed' ponygo .meta/gates docs README.md` 零命中；`.agents/notes/` 下仅剩本条对
   "该目录不再接收提案"的说明（3 处，均是对目录本身、不指向任何文件）。

## Alternatives considered

- **合并迁移**（把 21 篇 accepted 迁进 `.agents/notes/implemented/` 并转成现行格式）：否决。转格式意味着
  逐篇补 class 轴二选一、补 `## Alternatives considered`（5 篇没有）、把 `Status: accepted` 改写为
  `implemented`——这是为历史语料重开一次溯源工程，工作量与重新做一遍决策同级；更关键的是**改写即失去
  引用价值**：这些 Revision 的用处正是"框架规则当时怎么写的"的原文快照，改一字就不再有资格被当时的
  口径引用。冻结能保留的，迁移会毁掉。
- **删除**（连目录一起带走）：否决。现存引用面是硬的（实测 `grep -rn 'revisions/accepted' …`）：
  `ponygo` 与 `.meta/gates/*.sh` 共 7 处、`.agents/notes/` 17 处、`docs/` 与根 `README.md` 5 处指向
  `revisions/`，删掉全部变悬空引用。而且删除不是添加的逆操作
  （P9）——删除本身要配同等判据、验证与记录基础设施，收益却只是"少一个目录"。冻结是零成本的等价收益。
- **保持双轨**（继续按"框架规则 vs 工程决策"往两处写）：否决，这正是上文的病根。判不开的分工不是分工，
  是两套不完整记录的生成器；且旧轨道无看守、无备选门禁，写进去的承诺不会被任何命令验。
- **给 `revisions/` 也接上 `verify-note.sh`，用判据逼它合格**：否决。21 篇里 6 篇不合格（5 缺备选节、
  1 缺 `Status:`），接看守即全树恒红；而"补齐历史件"等于把冻结语料重写成现行语料，与"合并迁移"同一
  代价、还多一道假红期。
- **只冻结新增、不写文档**（静默停摆）：否决。静默停摆就是当前状态——README 仍宣称两套都用，下一位
  维护者会照着它再写一篇进无看守的轨道。冻结必须是**写下来的决定**，否则它只是一次遗忘。

## Consequences

- 决策语料单轨化：一处（`.agents/notes/`）承载"为什么这样/为什么不那样"，一份判据真源
  （`verify-note.sh`）看守它的形状，`revisions/` 退为历史层。
- 代价（诚实登记）：① 旧轨道里"框架规则演进"的连续叙事从此需要跨两棵树拼读（`revisions/accepted/`
  史前 + `.agents/notes/` 现值），本条即是拼读入口；② 冻结不等于清理——21 篇里 6 篇的格式债永久留在
  树内（登记为已知，不修）；③ 悬空引用面已清零（`ponygo`、`.meta/gates`、`docs`、`README.md` 对
  `revisions/proposed` 零命中，`.agents/notes/` 下只剩本条对该目录本身的说明）——冻结不免除
  "引用必须可达"，此后新增引用若指向历史条，同句须标注该轨道已冻结。
- 与相邻决策的关系：本条不改"决策必须入册且带 Alternatives"（常载命约 1）与"文件夹即标签"（命约 4），
  只是把入册的**唯一去向**钉死；`revisions/README.md` 的冻结标注同批落盘。
