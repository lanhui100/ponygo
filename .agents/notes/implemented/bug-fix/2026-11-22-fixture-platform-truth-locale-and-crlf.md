# Agent Note: 两处「平台真值在夹具里复刻」的缺陷修复（B005：C locale 填槽失效 + CRLF 前缀解析）

Status: implemented

## Problem

B005 从 wave-14 的 Windows 实跑（run `43053605488`）挂账，被记为「**产品侧 P0**：
`ponygo sync` 在 `ai-surface` 键缺失时仍在 Windows 投影常载命约」。近一年无人能修，因为它**不是产品缺陷**。

重新定位后的真实根因是两处**夹具自身复刻平台真值**的缺陷，两处都只在 Windows 的默认环境参数下暴露：

### 缺陷 A：`verify-p0.sh` 的填槽用 UTF-8 正则做字节匹配

`tests/acceptance/p0-fixes/verify-p0.sh` 的 `fill_const()`：

```bash
sed -i 's/【TODO[^】]*】/filled/g' .meta/constitution/constitution.md
```

Windows Git Bash 默认 `LC_ALL=C`。C locale 下 sed 的正则**按字节**匹配：
`【` = `E3 80 90`、`】` = `E3 80 91`，字符组 `[^】]` 实际变成「非 `E3`/`80`/`91` 任一字节」，
于是遇到 `【TODO: 填项目名】` 时，`[^】]*` 无法跨过正文里的中文字节 → **整条替换失配、静默不动**。

连锁反应（这才是「产品侧 P0」假象的来源）：

1. 宪法仍是模板态（含 `TODO:`）→ `ponygo` 的 `projection_is_bootstrap()` 返回真；
2. 断言 A「填槽 + 无 ai-surface 键 → 不得投影命约」：模板态走的是 bootstrap 投影分支，
   `AGENTS.md` 里出现 `BEGIN constitution` → **A 红**；
3. 断言 B「`ai-surface: off` + 残留投影 → 必须告警」：`warn_residual_projection()` 第一行就是
   `projection_is_bootstrap && return 0`（模板态不判定残留，设计如此）→ 不告警 → **B 红**。

产品语义在 Linux（UTF-8 locale）下完全正确。**本地铁证**：
`LC_ALL=C LANG=C bash tests/acceptance/p0-fixes/verify-p0.sh` → `FAIL A`、`FAIL B`、`PASS=15 FAIL=2`，
与 Windows CI 日志逐字一致；而把填槽改成 ASCII 锚后，同一命令 → `PASS=17 FAIL=0`。

### 缺陷 B：`gh6` 的折叠前缀解析被 Python 的文本模式 CRLF 污染

`tests/acceptance/gate-hardening/gh6_test_tiering_contract.sh` 里，A16 用 Python 解析 `tests/run.sh` 源码
求出折叠行前缀 `  fold `，以 `#FOLD-PREFIX|<prefix>|` 回传给 shell；shell 侧用
`awk -v p="$FOLD_PREFIX" 'index($0,p)==1'` 数前缀匹配行。

Windows 上 `python3` 的 stdout 是**文本模式**，输出 `\r\n`。于是 shell 读到的那一行是
`#FOLD-PREFIX|  fold |\r`，`FOLD_PREFIX` 尾部被塞进一个 `\r`（长度 9 而非 8）→
`index()` 对 `  fold s88_…` 的所有行都返回 0 → `FOLD_LINE_N = 0`。

而同一段里 `FOLD_RED_N` 用 `grep -c '^  RED  '`（前缀匹配，行尾 `\r` 不影响）计红相行。
Windows 上派生副本恰好全绿 → `FOLD_RED_N = 0`。
于是断言 `fold + RED 合计 == 7` 实得 `0`，而正则口径的 `FOLD_MIX_N` 正确得到 `7`
→ 报 `FAIL …（期望 [7]，实得 [0]）`。

**本地铁证**：把 `#FOLD-PREFIX|  fold |\r` 喂给同段 shell + `awk index` → `prefix len=9, FOLD_LINE_N=0`。

两处共同的形状：**平台事实（locale、行尾）被夹具自己重新编码了一遍**，而产品侧的真值只有一份。
夹具一复刻，就在非 Linux 环境下与产品脱钩，且**脱钩时表现为「产品错了」**——这就是 B005 被误记成
产品 P0 一年之久的原因。

## Decision

1. **修夹具，不修产品。** 产品侧 `ai_surface_state()` / `do_sync()` / `warn_residual_projection()`
   的语义正确，不做任何改动（已分别在 UTF-8 与 C locale 下验证）。
2. **缺陷 A**：`fill_const()` 改用 **ASCII 安全锚** `sed -i 's/TODO:/filled:/g'` ——
   它与 `ponygo` 判定模板态用的锚**同源**（`projection_is_bootstrap()` 就是 `grep -q 'TODO:'`），
   把「什么算已填槽」的判定权交回产品一处。
   并加一条**填槽生效守卫**：替换后若 `grep -c 'TODO:' != 0` → `bad "填槽失效"`，
   不占 PASS 名额。防的是同类 locale 问题换了宿主再次静默退化（守卫一旦失效立刻响）。
3. **缺陷 B**：解析侧剥 `\r`，**A16 的断言语义一个字不改**。
   实现为唯一真源 helper `fold_prefix_of()`（先 `%$'\r'` 再 `%|`，保留缩进两空格），
   A16 的实测解析改为调用它（原来是把赋值与剥壳内联在 `case` 分支里）。
   **顺序不可颠倒**：必须先剥 `\r` 再剥 `|`——反过来的话 `|` 后面还挂着 `\r`，剥完仍带脏字节。
4. **补常驻回归守卫**：新增 3 条 CRLF 回归断言（不剥 → 必 0 / 剥后 → 必数到 7 / 前缀逐字节一致）。
   这样平台差异不再依赖「在 Windows 上跑一遍」才被发现，本地随时可验。

## Alternatives considered

- **修产品，让 `projection_is_bootstrap()` 在 C locale 下也判对**：否决——`grep -q 'TODO:'` 是**纯 ASCII**
  锚点，本来就是 locale 无关的。缺陷在夹具用了 UTF-8 正则去做替换，不在产品判定。
  改产品等于为了让一个坏夹具变绿而改正确代码。
- **在 `verify-p0.sh` 里 `export LC_ALL=C.UTF-8` 强制好 locale**：否决——治的是这台机器的环境，
  不是夹具的健壮性。而且 Windows Git Bash 常常**没有** `C.UTF-8` locale（装了也不一定有），
  设置会失败或静默回退到 C，缺陷照样复现。且这种写法把「依赖某种特定 locale 才对」的假设固化进了夹具。
- **把 `【TODO: …】` 换成 `sed` 的 `s/.*TODO.*/…/` 这类粗粒度替换**：否决——会连带删掉行内其它内容，
  且「填槽」这个动作的语义（把槽位替换成具体值）被模糊化；ASCII 锚最小且与产品同源。
- **缺陷 B 只在 `awk` 侧做 `sub(/\r$/,"")`**：否决——脏字节会同时污染
  `assert_eq` 的期望值比较（`FOLD_PREFIX` 若被直接打印或比对就会带 `\r`）。
  剥在**赋值入口**（`fold_prefix_of()`）才是一次性、无遗漏的。
- **缺陷 B 对 `$RUN_PY` 整体 `tr -d '\r'`**：可行但否决——`tr` 在超大变量上有平台差异风险，
  且它会把**所有** `\r` 剥掉（未来若某条输出真的需要保留 `\r` 就无法表达）。
  定点剥（只在前缀赋值处）语义最小、可解释。
- **缺陷 B 只修解析、不加回归断言**：否决——不加守卫的修复无法防回归。本次的整个教训就是
  「平台差异只在特定平台暴露」，若连本地判据都不留，下一次同样的问题还会以同样方式挂一年。
- **把 B005 按原描述「修产品 P0」处理**：否决——那是误诊。若照原描述动手，会去改
  `ai_surface_state()` 或 `do_sync()`，既修不好 Windows 红（夹具仍坏），又破坏已正确的产品语义。
  本条记录的核心价值就是**把误诊纠正为夹具缺陷**。

## Consequences

- `LC_ALL=C LANG=C bash tests/acceptance/p0-fixes/verify-p0.sh` → `exit 0`，`PASS=17 FAIL=0`；
  UTF-8 locale 下同（两种 locale 结果一致，不再依赖运行环境的 locale）。
- `gh6` 的 A16 获得 3 条 CRLF 回归断言；变异测试（删掉剥 `\r` 那一行）→ 2 条 FAIL，
  证明守卫真会翻红，不是空样本。
- B005 的**原验收标准第 1、4 项**（windows-core 实跑绿、windows-full 完整绿证）仍需 CI 实跑取证，
  **在拿到前 B005 不得 resolve**。本轮只交付根因纠正 + 夹具修复 + 本地双 locale 绿证。
- 顺带确立一条可复用的口径：**夹具里出现 `is_windows()` / locale 假设 / 行尾假设时，
  先问「这份平台事实是不是已经在产品里有一份？」** —— 若有，夹具应做消费者，不做第二真值。
  这与 B008（AT2 自查平台分档）是同一条口径的两个实例。

## 测试分权：夹具缺陷由谁修（L3 审查 B-6 裁决）

本条的缺陷**位于冻结验收测试自身**（`verify-p0.sh` 的填槽、`gh6` 的前缀解析），这与宪法命约 3
「验收测试一经冻结，实施者只读不可改」形成张力。裁决如下：

1. **修夹具的人只能是测试方，不能是 Executor。** 命约 3 防的是「既当运动员又当裁判」——
   即由**业务代码作者**去改验收标准，使自己的实现看起来合规。本条的情形相反：
   夹具里有 bug，而业务代码作者对 `tests/**` 本就只有读权。若为了「避免测试方改测试」
   而让 Executor 去改夹具，才是真正破坏分权。
2. **补偿必须真实存在，不能只写在纸上。** 三条：
   - **独立 L3 对抗审查**复核全部夹具 diff，且必须实跑判别（本轮审查产出 7 blocking，
     其中 B-1 直接推翻了 Lead 计划里写的修复顺序——证明它是在审，不是在背书）；
   - **断言强度由审查方量化核对**：`verify-p0` PASS 15→17（+2，新增填槽生效守卫）、
     `gh6` PASS 172→179（+6 净增，含 C8 同源载体翻转加强 + 3 条 CRLF 回归）、`a2` 11/0；
     **无任何一条断言被放宽、跳过或改弱**；
   - **整卷绿证由 Lead 独立执行**，不采信测试方自报的整卷结论。
3. **若本轮不是「夹具自身有 bug」而是「断言写错/太松」**，则处置不同：必须由 Lead 冻结新断言、
   测试方只提交红相证据，不得自行修改期望值。两者的分界线是「缺陷在夹具的**基础设施**（locale、行尾、
   平台判定）还是在其**判据本身**」。本条属前者。

附：`test-agent` 的职责描述里写了「修夹具缺陷」——这本身与命约 3 的字面有张力，
但按上述分界，它修的是夹具基础设施、不是验收判据，且判据强度经第三方量化核对未降。
**这条分界应写入 dev-team skill 的分权条款**，否则下一轮还会撞同一个问题。
