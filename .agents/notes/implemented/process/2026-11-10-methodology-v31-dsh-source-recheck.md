# Agent Note: 方法论 v3.1 —— 按 dsh 源码复核后的机制与事实修正

Status: implemented

## Problem

`docs/methodology.md` 以 deepseek-harness 为实证案例，但它引用的机制与数字描摹的是一个历史快照。dsh `f028f25667`（2026-09-30，1355 文件 / −15,409 行）整体删除了运行时 invariant 插件族——`@deepseek-ai/dsh-invariants`（`ctx.invariants`）、各包的 `./invariant` 伴侣、`verify-package-invariants` 等门禁与 Vitest setup——而方法论 §6.1 仍把「运行时不变量」写成第四种铸造工艺、§6.3 仍把「运行时常驻（invariant 服务）」列作捍卫层。读者照此建体系，会重建一个 dsh 已判定「让系统更安全不成立、只是满足门禁」的机制。

同类问题还有两类。其一是归因错：§6.1 把 `scripts/verify-package-dependencies.ts` 说成"禁止 Consumer import Provider"的门禁（实测职责是发布面依赖段策略，85 个包 exit 0），第 1 行引的 "divergence is structurally impossible" 在 dsh 全仓零命中，属本文自撰引语。其二是数字过期：包数、notes 四态计数、技能数、CI job 形状与聚合成员、code-review 检查项、归档体量与 manifest、词数预算清单等 14 处与 `de5d733a18`（`v0.2.1-rc.5`，2026-10-31）不符。

不修正的代价不对称。方法论的唯一价值是"可照着做"，一条指向已删除机制的指令会让下游重建维护税；而"引用实证却与实证不符"直接击穿 P2/P6 的证据链——本文档自己要求每章回答"这条如何被验证"。

## Decision

按 dsh `de5d733a18` 逐条复核后，把 `docs/methodology.md` 升到 v3.1，三类改动同时进正文与版本记录。

机制修正（P0）：§6.1 第 4 行改为「OS 级围栏（fail-closed）」，并把「类型印记（Branded）」独立成行；新增 §6.4「守护层自身也要过 P8」记录退场事实、三条可复用判据（表达否定结论的机器不叫守卫 / 形状检查已被更便宜的层覆盖 / 自我验证的探针不算独立观测）、代价（逐次执行的关系型 tripwire 消失，改由属性测试、边界校验与 keyless 快照承担）与证据链缺口；§6.3 层序改为 编译期 → 加载期 → 运行期 OS 围栏 → 顶层执行门禁 → 语义层；§4.5 删已消失的 `gen-scoped-events`；§6.1 第 2 行把 seam 的机械影子改为发布面依赖策略与生成能力图，并显式声明"Consumer 不 import Provider"只是 note + review 纪律；第 3 行改 `SESSION_FORMAT_VERSION=4`、补非对称读取三分支、反转 bump 判据；第 1 行去伪引语；§4.6 就地标注 `PONYGO_*` 段为框架侧机制。

事实数字（P1）：§0 规模与四态计数、§3.2 的 code-review 检查项与归档步数、§4.4 的 CI 形状与 failover 选择器、§5.3 词数预算的机械真值边界、§5.5 回放入口与快照体量、§7.3 的 rejected 分布、§9 记分卡数字、§10 Wave5，全部替换为实测值；收据在 `.scratch/2026-11-10-dsh5-drift-audit/report.md`（12 条可复跑命令 + exit code）。

新增实证（P2）：§6.2 补 7 条现役不变量；§4.1 钩子安装器的归属标记与自带负样本；§4.4 failover 选择器与新 workflow；§4.5 补 `verify-type-equiv`/`verify-repository-references`/`verify-export-jsdoc`/`verify-concrete-terms` 与 4 个生成器，并把「每个门都有负样本」改写为实测 14/29（≈48%）。

诚实边界：§6.4 明确写出 dsh 这次移除没有独立决策记录——理由只在 commit message 与升级指南的 Change 段（无备选），最接近的依据是归档 note `2026-08-28-omit-unneeded-invariant-companions`。本文档不替它圆场，也不据此声称"运行时不变量"这个方向本身错误：退场的是"无法独立观测违规的断言"，不是"守卫必须机械"。

## Alternatives considered

- **只改数字，把「运行时不变量」改写为"历史机制"留在 §6.1**：否决——留在工艺表里就会被读者当现行工艺照做；机制退场需要显式案例（判据 + 代价 + 证据缺口），藏在"历史"标签里等于没写。
- **§6.1 第 4 行直接换成「类型印记」并止步**：否决——系列文章第 5 篇用 Branded 作第四工艺，但只补这一行会漏掉 OS 围栏这个更硬的新守卫，§6.3 层序也会继续缺运行期围栏层。
- **等 dsh 补上移除决策记录后再改本文档**：否决——那是外部仓库的时间表，本文档引用已失效机制是本地缺陷；正确做法是本轮照实修正并标注证据缺口（P6 诚实条款）。
- **把 §4.6 的 `PONYGO_*` 段整段删除**：否决——它在本仓是真实门禁纪律，删除会丢框架侧事实；改为就地标注归属，避免被误读成 dsh 实证。
- **重写历史版本记录以消除旧数字**：否决——版本记录是演进史，回改会让"当时记录了什么"不可考；改为在节首声明历史取值不回改、当前真值以正文为准。

## Consequences

- §6 现在讲的是"dsh 当前的捍卫层 + 一次有据可查的退场"，读者照做不会再重建已删机制；证据链恢复为每个机制主张都带 `path:line` 或命令收据。
- 新义务：本文档从此承担持续复核 dsh 的责任，§6.4 还外部仓库的负面结论。正文无法自证与 dsh 同源，仍靠 review + 本次收据，不装假门禁。
- 与 `2026-11-10-audit-carrier-separation.md` 互补：那条定三层文档各归其家，本条只改 methodology 正文的事实与机制，不搬动家载体。
- 系列文章第 5 篇的沙箱小节重写与 `357→358` 等改动在 ponyfun 侧单独走，本文档不代改文章。
