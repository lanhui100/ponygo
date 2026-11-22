# Agent Note: B027 四项收口——observe 载体发现、子组件巡检、多声明巡检与单文件 mount 假绿

Status: implemented

## Problem

B027 从 job_copilot 跨仓迁入（原 B-OBS-01/02/03），记的是 `ponygo observe` 适配层的四项缺陷。
迁入时状态是「未修」，但实际进度是**混合的**：①②③ 已被 `7379930`
（`fix(observe): husky/core.hooksPath carriers, comment-free mount judgment, subcomponent audit (B200)`，
2026-10-26）实现，而 ④ 只修了一半。B027 之所以挂着，是因为从来没有人对这四项做过**独立验收**——
`7379930` 的提交信息声称做了，但没有任何判据能证明它做对了、做全了。

因此本条的实质是：**补验收，并修掉验收暴露出来的半修复**。

### ④ 半修复的根因：两条 grep 分支的输出格式不一致

`ponygo` 的 `observe_mount_hit()` 要判断「门禁载体里是否真的接了 `audit-diff`」，
并且必须**排除纯注释行**（防「只在注释里提一句 audit-diff」就拿分）。实现是 grep 出命中行，
再用 `grep -qvE ':[0-9]+:[[:space:]]*(#|//|/\*|\*|<!--)'` 过滤掉「行号 + 注释符」开头的行。
这条正则隐含假设：grep 输出的行形如 `<path>:<lineno>:<content>`。

但函数有两条分支，输出格式不同：

- 目录分支：`grep -rIn …` —— `-r` **自带文件名**，行形如 `path/file:12:# bash scripts/audit-diff.sh` → 正则能匹配 → 纯注释被正确排除 ✓
- 单文件分支：`grep -In …` —— 单文件时 grep **不输出文件名**，行形如 `12:# bash scripts/audit-diff.sh` → 正则要求冒号前是「行号前面还有 `:` 和路径」的形态，**永不匹配** → `grep -qvE` 认为「存在非注释行」→ `mounted=1` → ob2 白送一分 ✗

后果：四条**单文件载体**（`.githooks/pre-commit`、`.git/hooks/pre-commit`、
`.pre-commit-config.yaml`、`lefthook.yml`）上，只写一行注释就能拿到 ob2 分。
而这四条恰好是**最主流的本地门禁载体**——缺陷正好落在覆盖最广的地方。
目录载体（`.husky/`、`.github/workflows/`）因为 `-r` 自带文件名反而是对的，掩盖了问题。

讽刺的是，同一批修法里 `7379930` 已经引入了 `observe_mount_hit()` 来做「排除纯注释」这件事——
它做对了目录形态，漏了单文件形态，而没有任何用例覆盖单文件形态。

## Decision

1. **④ 的修复：一行。** 单文件分支 `grep -In` → `grep -HIn`。
   `-H` 强制输出文件名前缀，使两条分支的**输出格式统一**，于是排除正则对两者同口径生效。
   不动目录分支、不动正则、不动 ob2 计分逻辑、不动任何文案。
   （选 `-H` 而非「为单文件写第二条正则」：两份正则就是两份真值，下次改一处必漏另一处。）
2. **①②③④ 全部补独立验收**，落在新目录 `tests/acceptance/observe-b027/`（不进 `tests/run.sh`
   的 94 场景，不动 CORE/NONCORE 分区——那两处字面是别处断言的硬锚）：
   - `c1_carriers`：`.githooks/`、`.husky/`、husky v9（`core.hooksPath=.husky/_`）、自建 hooksPath 目录
     四形态各一例；**每条都配归因负样本**（移除 `audit-diff` → 必须 `mount_missing`，不得报 ob2 PASS）。
   - `c2_subcomponent`：坏子声明 → `subcomponent_inconsistent`；rc=3 → `subcomponent_evidence_insufficient`；
     `--strict` → exit 1；正对照（子声明一致 → 不得误报缺口）；越界负样本（二级声明不得进缺口）。
   - `c3_multi_declaration`：`docs/observability.d/*.yaml` 与根声明并存、各自独立判定；
     坏附加声明 → `extra_declaration_inconsistent`；正对照（全一致 → 缺口消失）；
     递归负样本（`nested/deep.yaml` 不得被纳入）。
   - `c4_comment_mount`：**负样本为主**——纯注释伪装在单文件与目录两类载体上都必须判负；
     **配归因正对照**（同文件去掉注释符写成真调用 → 必须 ob2 PASS），防本次修复把真挂载误杀。
3. **先红后绿的证据链**：整套用例对 `7379930^`（修复前）的 ponygo 跑一次 → `cases=4 pass=75 fail=38`；
   对当前树跑 → `cases=4 pass=113 fail=0`。两次独立取得，计数逐字一致。
   这证明这套用例**真的能区分修复前后**，不是「写出来就绿」的仪式。

## Alternatives considered

- **④ 修法：为单文件分支写第二条排除正则**：否决——两份正则就是第二份真值。
  今天目录分支用 `:[0-9]+:` 形态、单文件用 `^[0-9]+:` 形态，未来任何一侧的 grep 参数变一下
  （比如给目录分支也去掉 `-r`、或换 `-o`）就静默失配，且**没有任何断言会响**。
  统一输出格式（`-H`）是让「一条正则管两种形态」这件事成立，而不是打补丁。
- **④ 修法：不用 grep，改用 shell 逐行读并 `case` 过滤**：否决——性能与跨平台行为都劣于 grep，
  且要自己处理二进制文件、编码、超大文件。为一行修复引入一个手写解析器，违反最小闭包。
- **④ 修法：加 `-o` 或改成正则匹配 `audit-diff` 后再判断前导字符**：否决——`-o` 会把行内容裁掉，
  排除注释的判断失去依据（注释符不在输出里了）。
- **不修 ④，只改 B027 描述为「已修复」**：否决——这是本条最危险的选项。缺陷客观存在（单文件载体假绿），
  把它写成「已修」等于用文档抹掉一个安全漏洞：消费仓会以为「我接了本地门禁所以拿到 ob2」，
  而实际上可能只写了一行注释。**B027 之所以挂了一个月，正是因为它被误当成「已修」。**
- **把新套件接进 `tests/run.sh` 成为第 95 个场景**：否决——94 场景字面是 `gh6/R1` 与 `verify-p0`
  的硬锚，CORE/NONCORE 两集合必须是 94 的分区（`gh6/B6`）。加场景要同步改两处数据块 + 硬数字 +
  CORE 计数，属于范围变更，收益（多一层常驻看守）小于风险（把刚稳定的分层契约再动一次）。
  本套件以独立目录 + 独立 run-all 存在，需要时手动/专项调用。
  若日后要常驻，应作为一条独立的决策来做（并同批改所有硬锚）。
- **①②③ 也重写一遍实现**：否决——`7379930` 的实现是对的（独立验收全绿）。
  把「没有验收」误当成「实现有问题」，会导致无谓重写并破坏已验证的行为。
- **只在 Linux 上验（不跑 `LC_ALL=C`）**：否决——`c4` 的载体形态与 locale 无关，
  但整条 B005/B027 线的教训就是「平台差异只在特定环境暴露」；`c1`/`c2`/`c3`/`c4` 都在
  `LC_ALL=C` 下复跑过，避免重演本仓反复踩过的 locale 坑。

## Consequences

- 单文件载体的注释伪装现在**判负**（`rc=1` + `mount_missing`），真挂载仍 `rc=0`/ob2 PASS（双向都验）。
- `tests/acceptance/observe-b027/` 成为 observe 适配面的独立验收入口：
  `bash tests/acceptance/observe-b027/run-all.sh` → `exit 0`，`cases=4 pass=113 fail=0`。
- 本仓自检口径订正：`./ponygo observe audit` 在本仓是 **`rc=1`（`declaration_missing`），不是 SKIP**——
  本仓没有 `docs/observability.yaml`。修复前后输出逐字节 IDENTICAL，故「本条不引入本仓回归」成立。
- B027 的四项现已全部有独立判据。**这条待办以前挂着是因为没人验证，不是因为没人实现**；
  现在的状态是「已验证 + 半修复已补齐」，可以据实 resolve。
- 遗留：`tests/acceptance/observe-b027/` 未接入 `tests/run.sh`。这是有意取舍（见 Alternatives），
  若日后接入需作为独立决策并同批迁移所有 94/CORE 硬锚。
