# Agent Note: 归档 SHA-256 封印门（A6/A7）

Status: implemented

## Problem

DSH 系列第 2 篇把 `archived/` 定义为「永久冷冻 + 哈希封印」：归档件不仅禁止修改，
连一个字节的空格变动都必须触发非零退出。ponygo 此前只落地了「归档目录 + 冻结豁免 +
`.rgignore` 搜索隔离」：`verify-note.sh` 对 `archived/` 跳过格式检查，归档件被改一个
字节仍然 exit 0；`maturity-ladder.md` 的 L4 也如实写着「归档哈希封印脚本尚未交付」。
结果是文章宣称的退场机制在实现上缺了最关键的一半。

## Decision

新增两个框架门禁资产（零旗标）：

| 资产 | 路径 | 契约 |
|---|---|---|
| A6 | `.meta/gates/archive-verify.sh` | `check`（默认）= 校验封印；`seal` = 追加新封印。manifest 为 `.agents/notes/archived/manifest.sha256`，纯文本追加式 `<64hex>  <仓库相对路径>` |
| A7 | `.meta/gates/archive-verify.spec.sh` | A6 的负样本执行判据：篡改 / 缺条目 / 孤儿条目 / 重复条目 / 非追加，合法样本放行 |

语义：
- `check` 做 manifest 与 `archived/` 下 `.md`（排除 `README.md` / `AGENTS.md`）的双向一致：
  哈希不符、归档件未封印、manifest 条目指向不存在文件、重复条目、归档区**任何符号链接**
  （含目录链接与归档根本身）→ exit 1；
  无归档或空 → exit 0。读取 manifest 时容忍 CRLF（写回恒为 LF）。
- `seal` 先校验既有条目未被改动（append-only），只追加缺失条目；新条目要求 `Status:`
  首词 ∈ {`implemented`, `archived`}（来源代理判据），既有行内容绝不重写。写入是
  「临时文件 = 旧字节前缀 + 新块 → 同目录原子 `mv`」：中断/截断不会留下半截行；
  `read→判定→append` 整段在互斥锁内（flock 优先，退化为目录原子锁），并发 seal 不会重复追加。
- 接线：A1 在**任何 skip 之前**调用 A6 `check`（删除/移出归档件也走同一门，输出仍排在
  ADR 段之后）；A4 三段（全树 ADR 格式 / A2 spec / A6 check + A7 spec）。
- A6/A7 进入 `UPGRADE_UNIVERSE`（13 → 15 文件），由 `init` / `upgrade` / `--repair-skeleton`
  幂等落地并 `chmod +x`；仓库模板与 `ponygo` heredoc 双写，EOL 归一后逐字节一致。

## Alternatives considered

- **manifest.json + jq/python 解析**：否决——破坏单文件零包依赖；纯文本 manifest 足够
  机械校验，且不引入运行时依赖。
- **独立 `ponygo archive` 子命令或 `--write` 旗标**：否决——违反旗标预算与六条命令面；
  位置子命令 `check|seal` 已能区分读写。
- **pre-commit 自动 seal（写文件）**：否决——钩子在提交窗口改工作区/暂存区会引入 TOCTOU
  与「提交时偷偷改文件」的信任问题；`seal` 必须由写 ADR 的人显式执行，pre-commit 只 check。
- **git rename 强溯源（只允许 implemented → archived 的 `git mv`）**：本期否决——跨 Windows
  Git Bash 的重命名检测易误杀，且直接导入历史归档的合法场景会被阻断；先用 `Status:`
  首词 ∈ {implemented, archived} 做来源代理判据，并在文档标注「git 溯源靠 review」，后续有真实需求再升级。
- **`cat >>` 追加 + 无锁**：否决——并发 seal 会重复追加；写入被截断会留半截行且不可自愈。
  改为互斥锁 + 临时文件原子替换（内容层仍 append-only）。

## Consequences

- 归档件一旦封印，改一个字节即被 A1/A4/A6 拦截；`seal` 之后 manifest 既有行内容只增不改。
- 同时改归档件与其 manifest 行的攻击，纯内容校验无法分辨（无 git 历史真值）——归 review/CI
  可追溯性，本门不冒充；gates/README 已写明该边界。
- L4 状态从「脚本尚未交付」变为「A6/A7 已交付；来源溯源仍靠 review」——不夸大。
- manifest 位于 `.agents/notes/archived/`，被 `.rgignore` 一并隔离，不污染常规检索。
