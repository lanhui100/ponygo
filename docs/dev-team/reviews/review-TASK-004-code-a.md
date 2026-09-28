# Code Review 记录 —— TASK-004 / WP-G·I·S 落地（@code-reviewer-a：正确性/回归/可维护性）

> 审核者：独立子智能体（@code-reviewer-a）｜ 2026-09-28
> 范围：spec-ponygo-v2.5 rev2 §5/§8/§10 + checklist/depth-selector/README/scorecard/gates链入行/methodology §2.8/§3.3/§4.7/§7.1/skills README/run.sh s18+s32 + 双审P0/P1处置核对
> 方法：逐段读 + grep实测（靶串对齐、计数原子性、否决表扫描、恒绿检查）

## 结论

**有条件通过**（2条P1必修，其余通过；P1闭环后可转通过，无需重审全文，只需复核修复行）。

## P0：0条

- s32靶串与落盘措辞逐字对齐已验证（`2.A 资源隔离`/`methodology §4.6`/`本行非门禁`/`旧整文件哈希记录仍有效`/`工具定义卫生`/`计数不选优`等全称均命中，唯一例外见P1-2）。
- s18 15→18、depth-selector、README、scorecard已原子同改（`机制 18`四处一致，HANDOFF冻结豁免正确未动）。
- methodology §4.7唯一家成立（F1–F7+分流+阶梯只此一家；gates仅一链入行`本行非门禁`，无第二家）。
- 否决表扫描：判据正文无`dsh-`/vitest/pnpm/tsx/benchmarks/`scripts/*.ts`/CI job名/量化规范值；`ponygo`零diff（`478`豁免行未动）；HANDOFF零diff。ADR三条出处注存在。
- s32-S恒绿已堵死（裸`卫生/证据链`靶串无残留，全部改为全称）。

## P1（必修，已在收口轮闭环）

**P1-1（s32-G用法小结靶串与落盘措辞漂移）：** 已改为`grep -qF '追加「机制层」（18 项）'`精确定位。
**P1-2（`grep -q '~2'`加`-F`）：** 实施已改`grep -qF '~2'`；spec §8 s32-I行已对齐`-F`。

## P2/P3

- P2-1 spec §8残留"以实施措辞为准二选一"已删，改为钉死表。
- P2-2 `ponygo:478` stale 已登记为例外，下次 CLI 任务同步。
- P2-3 s32-D 输出 diff 靠实施者贴输出 + review 确认（review 程序，P6 诚实）。
- P3-1 methodology §2.8 旧段 dsh 脚本名为实例注（非规范要求），实例注豁免已覆盖。

## 必须修复项（均已闭环）

1. `tests/run.sh` 用法小结靶串改 `-F` 全称。
2. spec §8 s32-G/s32-I 与实施写法对齐。

## 可接受的残余风险

- s32-D输出diff靠人工贴（review程序本就如此）。
- `ponygo:478` stale到下次CLI任务。
- I包零实例收益为零（Wave3期权，spec §1.2已诚实标注）。

---
*落款：@code-reviewer-a，2026-09-28。P1闭环后转通过。*
