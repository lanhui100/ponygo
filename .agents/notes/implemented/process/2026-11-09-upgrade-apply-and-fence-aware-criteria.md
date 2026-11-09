# Agent Note: 围栏感知的标题判据 + CJK 标点不充理由 + `upgrade apply` 写路径

Status: implemented

## Problem

三处都属同一类缺陷——**判据或工具把"形态"当"事实"，而形态可以被轻易伪造或被工具自身绕过**：

1. **1.7 的理由判据能被标点骗过**。Wave-1 的口径是"分隔符后剥空白、剩余 ≥2 字节"，于是
   `Status: rejected — 。` 直接过：`。` 是 3 字节（`e3 80 82`），远超阈值。后果是"写一个标点"
   与"写一条真理由"在判据眼里同形，而 Wave-1 刚立的 1.7 正是为了不让 `rejected` 只有位置没有内容。
2. **标题判定不认围栏**。判据 1.8/1.10 用 `grep -q '^## Decision'` 之类按行首匹配，于是**写进
   代码围栏（fence）里的示例标题**同样算"在场"——`## Decision` 只作为文档示例出现时，implemented 条会被
   判绿。Wave-1 已把这点登记为假阴性面（`2026-11-09-adr-criteria-hardening.md` 的诚实边界），
   Wave-2 收口。
3. **"手抄双写"没有写路径**。`ponygo upgrade` 一直是**只读报告**（`--check` 报告漂移并非零退出），
   但"跟随框架升级"的实际动作仍是人肉把 15 个宇宙文件的内容复写一遍——`UPGRADE_UNIVERSE`
   与 `ponygo` 内嵌 heredoc 是同一份资产的两次落盘，人肉同步必然漏项与打错，这是本仓最大的熵源。

## Decision

**1. 判据 1.7 的理由剥离集合加入 CJK 标点（闭集），实现必须逐字符替换**

- 剥离顺序：分隔符本身（`—` / `-` / `:`）→ 空白 → ASCII 标点（`[:punct:]`）→ em dash / 全角空格 →
  **CJK 标点闭集**（`，。、；：！？「」『』（）【】《》…～·﹁﹂“”‘’`）。剥完剩余 ≥2 字节才算理由。
  于是 `Status: rejected — 。` 与 `Status: rejected ——` 一律按"缺一行理由"拒绝。
- **实现要点（踩过的坑）**：闭集必须用**逐字符独立的 `sed -e 's/，//g'`**，不能用字符组 `[。，、]`——
  C locale 下字符组按**字节**匹配，会连带剥掉恰好共享字节的正常汉字：实测 `突` = `e7 aa 81`、
  `、` = `e3 80 81`，两者共享 `0x81`；用字符组会把 `突` 残成非法 UTF-8 序列。逐序列替换是精确的
  UTF-8 序列匹配，不误伤正文。
- 两面同口径：判定真源 `verify-note.sh` 与 `ponygo` 内的镜像实现（`reason_body_of`）同批改、
  同闭集；新增标点必须两侧同时加（否则 pre-commit 与 `status` 给出不同结论）。

**2. 全部 `## ` 标题判定改为围栏感知**

- 唯一入口 `heading_outside_fence <file> <ERE>`：awk 状态机，`^[[:space:]]*``` ` 开头的行**切换**
  围栏态（` ```text ` / ` ```bash ` 等带语言标记的行同样是围栏行）；围栏态内一律不认标题；
  **未闭合的围栏 → 其后全部视为围栏内**（fail-closed：宁可误拒"标题真的缺"，也不假绿"标题只在示例里"）。
- 覆盖面：1.8 的 `## Decision` 在场判定、1.8 的中英文提案标题禁入、1.10 的
  `## Alternatives considered` 在场判定，全部改走该函数；真源与 CLI 镜像同批改。
- **诚实边界（写进契约，不冒充 Markdown 解析器）**：只认 ``` 围栏，**不认 `~~~`**；4 空格缩进式
  代码块与 HTML 注释里的 `## ` 标题**仍会被认**作在场。这三处由 review 兜（`governance-review` 抽查），
  要彻底消除得引入完整的 Markdown 解析器，与"零依赖单文件 CLI"的成本不对等。

**3. `ponygo upgrade apply`——位置子命令形式的写路径**

- **位置子命令，零新旗标**：`ponygo upgrade apply`，不新增 `--apply`（旗标预算见
  `2026-11-07-flag-budget.md`：只允许三类新增旗标；写路径藏进旗标还会让"只读/写"在 argv 层不可辨）。
  其它命令收到 `apply` 仍是未知参数；`upgrade` 的未知位置参数一律 usage + exit 1；
  `apply` 与 `--check` / `--dry-run` 组合一律拒绝（写路径不与只读检查组合）。
- **与 `--check` 共用同一套口径（禁第二份判断）**：同一宇宙表 `UPGRADE_UNIVERSE`（十五文件）；
  同一模板基准（`write_skeleton 0` 到 `mktemp` 目录）；同一 docs-tier 跳过规则（已激活实例的
  `.meta/docs-tier/README.md` 不参与比对/刷新）；同一内容比较口径（EOL 归一后 `diff`）。
  **唯一差别是"有漂移时做什么"**：`--check` 报 drift 并非零退出，`apply` 原子写回模板字节。
- **写纪律**：只处理宇宙内文件（宇宙外一概不动——根 `README.md` / `meta.yaml` / 已填 constitution /
  根 `AGENTS.md` / `CLAUDE.md` / `classes.local` / docs-tier 激活版无模板基线）；写入走同目录临时文件 +
  `mv` 原子替换；权限位取模板（A1/A2/A4 = 755）；内容 EOL 归一后一致则**一字不动**，故第二次
  `apply` 必报"零变更"（幂等由这条比较保证，不是靠状态文件）；**不备份**——模板即权威，旧内容在
  git 历史里，`.bak` 只会变成第二份会漂移的副本。
- 输出契约：「应用 N 处」/ `apply 零变更`；写入失败逐项 WARN 并在结尾报未完成（exit 1）。

## Alternatives considered

- **给 `upgrade` 加 `--apply` 旗标**：否决。破了旗标预算（只允许 `--json`/`--dry-run`/`--run-specs`
  三类新增旗标，`--check`/`--repair-skeleton` 只是存量登记），而且旗标把"这次是只读还是写入"藏进
  选项解析——位置词在 argv 层就是可见的意图，读命令历史的人一眼能分辨。
- **新增第七个顶层命令（`ponygo apply` / `ponygo refresh`）**：否决。六条命令面是拍板不变量
  （`2026-08-30-six-command-surface.md`）；一个只作用于 `upgrade` 语义的动词不值一条顶层命令的
  终身维护税（usage、README 三处口径、测试矩阵、兼容承诺）。
- **围栏同时支持 `~~~` 与 ``` 双语法**：否决。两套围栏规则要判"哪个先闭合"，歧义面凭空翻倍；
  实际语料里 `~~~` 只出现在极少数 Markdown 方言中，YAGNI。只认 ``` 且未闭合按"其后全在内"
  fail-closed，是更小的假设面。
- **CJK 标点用字符组 `[。，、；：！？]` 剥离**：否决。C locale 按字节匹配，会误删共享字节的汉字
  （`突` = `e7 aa 81`，与 `、` 的末字节 `0x81` 相同）——判据会把正常理由剪成残字节，反而制造
  假 FAIL。逐字符独立 `sed -e` 是唯一不依赖 locale 的精确写法。
- **`apply` 前自动备份（`<file>.bak`）**：否决。备份即第二份副本，会与模板持续漂移，且没人清理；
  "旧内容去哪了"这个问题 git 已经答了。

## Consequences

- **"手抄双写"这一熵源被收口**：`UPGRADE_UNIVERSE` 与 `ponygo` 内嵌 heredoc 的同步从"人肉复写 15 个
  文件"变成 `bash ponygo upgrade --check`（看差多少）→ `bash ponygo upgrade apply`（写回模板）→
  再 `--check`（复核零漂移）。漂移仍是**观察**（默认 exit 0），CI 用 `--check` 转成门。
- **口径共享点清单**（改任一项必须四处同改）：宇宙表 `UPGRADE_UNIVERSE`、模板基准 `write_skeleton 0`、
  docs-tier 已激活跳过规则、EOL 归一比较。`apply` 与 `--check` 只有"漂移时做什么"不同。
- **判据侧的代价与收益**：`rejected/` 的"一句话应付"被拒（纯标点、纯分隔符不再算理由）——
  这正是想要的：理由是否决理由唯一不可再生的载体；围栏感知让"在文档里贴示例标题"不再能骗过
  1.8/1.10，代价是**误拒**风险（未闭合围栏之后全被当围栏内，fail-closed）。
- **残余边界（诚实登记，不装假门禁）**：4 空格缩进代码块与 HTML 注释内的标题仍被认作在场；
  `~~~` 围栏不被识别；`apply` 不备份、不处理宇宙外文件；`apply` 需要能写工作区（只读检出会逐项
  WARN 并 exit 1）。
- **加严当天本仓零红**：`bash .agents/skills/write-adr/verify-note.sh` 整树 exit 0；
  同批新增的 `rejected/process/2026-11-09-move-1.9b-criterion-into-verify-note.md` 使
  `ponygo audit --level M` 由 13/14 升到 14/14（S 档 9/10 → 10/10），该条的留痕理由本身即按本条的
  1.7 新口径写成（含实质内容，不是标点）。
- 相邻决策：判据加固的完整背景见 `2026-11-09-adr-criteria-hardening.md`；旗标预算见
  `2026-11-07-flag-budget.md`；命令面不变量见 `2026-08-30-six-command-surface.md`；
  漂移报告宇宙见 `2026-09-14-upgrade-drift-report.md`。
