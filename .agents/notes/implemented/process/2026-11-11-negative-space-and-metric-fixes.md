# Agent Note: 负空间判据与口径修复（1.11 + A8/A9 + 计分去冗余 + 回归接线）

Status: implemented

## Problem

对 ponygo 做负空间面与自洽性面双路审计（对照 DSH 系列第 6 篇的判别句/连根拔起/复活条件/零残留），查出三类缺陷：

1. **负空间三工艺只有散文，没有判据**：复活条件在 `audit/checklist.md` 是精微层 `[future]` 的一句名词；`verify-note.sh` 判据止于 1.10（Alternatives），删除类记录没有任何形状约束；没有任何门回答"删掉的东西还有没有残留引用"；`change-review` 不覆盖删除类变更。
2. **口径自我矛盾**：`audit/checklist.md` 自称"权威以本表为准、CLI 内嵌 10/15 是子集"，实测 CLI 为 S 11/12、M 16/17；且 checklist 的 1.4–1.8、2.5/2.6 与 `maturity-ladder.md §5` 判据真源同号不同义——照它的元规则回改 CLI 会砸烂四条判据。
3. **负空间回归网物理断开**：`tests/acceptance/` 7 套件只有 3 套接进 `tests/run.sh`；未接线的 auditfix/gate-hardening/deferred 实跑已红（auditfix 的 `期望[15] 实得[17]` 正是上面的计数漂移），而唯一接线入口全绿——红灯没人看得见。

## Decision

本波按"一份判据一份实现"（P9）补最小形状，不新建平行机制：

- **判据 1.11（负空间形状）** 落在 `verify-note.sh`：`implemented/simplification/*.md` 必须具备围栏外 `## Reintroduction conditions`；含 `## Removed surface` 时须含至少一行 `rg`/`grep`/`git grep` 检索收据。质量（复活条件是否成立）不在机器面，按 P6 标注靠 review。
- **A8/A9 新门** `.meta/gates/no-residue.sh` + 同名负样本 spec：清单驱动（`<pattern>[TAB]<scope>`，默认 `.meta/gates/no-residue.manifest`），任一命中即 exit 1；空清单/缺清单 exit 0 并打印跳过；未知参数 fail-closed。进 `UPGRADE_UNIVERSE`（15 → 17 文件）与 `ci-verify.sh` 第 4 段，`ponygo init` 双写播种。
- **计分去冗余**：删掉问② M 档里被跨平台 `has_ci` 严格覆盖的 `.github/workflows` 计分项 → M 档 total 17 → 16。共享探针（`hook_ok` 同时服务 1.7/2.4）与 2.3 配对分是**有意设计**，补注释说明，不再当缺陷改。
- **执行判据收紧**：SKIPPED 判定改独立词边界（`SKIPPED（…）`/`SKIPPED:` 不再被洗成 `[ok]`）；spec 有内容但 stdout 为空判 FAIL。
- **口径归位**：`audit/checklist.md` 与 `audit/depth-selector.md` 的计数改为派生口径（以 `ponygo audit --json` 为准，不手填），编号冲突改为显式声明"两套编号同形不同义，判据语义以 maturity-ladder §5 为真源并同批改双方"；4.7 从 `[future]` 解冻为机制层条目。`README.md`/`maturity-ladder.md`/`notes/README.md`/`change-review`/`write-adr`/`gates/README.md` 同步。
- **回归接线**：`tests/run.sh` 增 auditfix/gate-hardening/deferred/negspace 四套场景；`wave13`/`carrier-audit` 期望值适配新契约（17 文件、四段）。
- **顺手修掉一个会污染仓库的验收脚本**：`tests/acceptance/p0-fixes/verify-p0.sh` 的 `mk()` 曾在子 shell 里 `cd`，父进程 cwd 不变，相对写盘落到仓库根（曾把 `.meta/meta.yaml` 覆盖成 3 行桩、往 `.meta/gates` 塞 `my-gate.sh`、往 `adr-verify.sh` 追加 `# tampered`）。改为当前 shell 内 `cd` + `require_sandbox` 守卫（写盘前断言 cwd 在 mktemp 沙箱下，否则 exit 1），副本实测不再污染。

## Alternatives considered

- **只改文档、不动判据**：否决——审计的核心结论是"三工艺没有判据"；把 `[future]` 措辞改漂亮不改变"谁在什么时刻判定"，等于把缺口藏进散文（P2 的反例）。
- **为负空间另建独立门（`verify-negative-space.sh`）**：否决——1.11 是对既有笔记格式契约的扩展，塞进 `verify-note.sh` 才能被 A1/A4/ci-verify 已有的四件套（门 + spec + 接线 + 文档）无偿覆盖；新门要多一份维护税（P9）。
- **保留重复计分、只把测试期望从 15 改成 17**：否决——`.github/workflows` 项已被跨平台探测严格覆盖，留着是纯冗余；但另外两处重叠（共享探针、2.3 配对）是设计选择，只在代码里加注释说明，不按缺陷处理。
- **把未接线套件标注"已知红"而不接线**：否决——红灯不被任何入口执行，等于回归网物理断开；实测红点恰好指向真实漂移（total=15 断言），接线后立刻变成可发现信号。
- **改 `p0-fixes` 的其余 9 条失败断言**：否决——该套件是另一条在途工作（P0-* 语义改动）的验收面，属于他人的契约；本波只修"会污染仓库"的脚本缺陷，不动其期望值。

## Consequences

- 复活条件与删除工艺从"目标画像"降为"有形状判据 + 靠 review"：写入 `implemented/simplification` 的记录缺 `## Reintroduction conditions` 会被 A1/A4 拒绝；内容质量仍靠 review（诚实边界已登记）。
- 新义务：任何"删除/收窄"变更现在要带 `## Removed surface` 检索收据，并可挂 `no-residue.manifest` 让 A8 全局复核；清单是可选资产，空清单不假绿（exit 0 且打印跳过）。
- 代价：`UPGRADE_UNIVERSE` 多两个文件，实例侧 `ponygo upgrade` 会看到 17 文件的宇宙；A4 多一段执行，CI 时长微增。
- 遗留（不在本波范围）：`tests/acceptance/p0-fixes/verify-p0.sh` 的 9 条断言仍红，属另一条在途 P0 工作；`tests/run.sh` 中 sync/status 场景如与他人在途语义漂移冲突，按"他人契约面不擅改"原则单独排期。

**应用验证发现的第二个缺陷（A8 隐藏目录假绿）**：把新门应用到 pony-agent 后真机复现——清单登记 `HIDDEN_LIVE_777<TAB>.` 且该字面串只出现在 `.agents/probe-hidden.txt`，`no-residue.sh` 返回 **0**（应 1）。根因：`rg` 默认跳过隐藏项，`-- .` 的检索面不含 `.meta/`、`.agents/`、`.github/`。修法：rg 分支加 `--hidden --glob '!.git' --glob '!.git/**'`，A9 增第 ⑪ 类样本（隐藏目录命中必拒 + grep 退化路径同判 + 隐藏目录零命中放行），反证：去掉 `--hidden` 的旧门跑新 spec → 2 项 FAIL。这正是"真实应用才能暴露的假绿"：单元层面 spec 全绿，只有把门挂到真实实例、用真实目录形态才会红。

**收据（2026-11-11 实测）**：ponygo 仓 — `no-residue.spec.sh=0`、`ci-verify.sh=0`（四段）、`verify-note.sh=0`、`adr-verify.spec.sh=0`、`archive-verify.sh check=0`、`archive-verify.spec.sh=0`、`scratch-hygiene.sh(+spec)=0`、`ponygo audit --level M --json` = hits 15 / total 16、隐藏目录命中 = 1；pony-agent 应用后 — `status=0`、`upgrade --check=0`（17 文件零漂移）、`audit --level M --json=0`（gaps []）、`no-residue.spec=0`、`ci-verify=0`、`1.11` 活体：缺 `## Reintroduction conditions` 的 simplification 记录 rc=1、补齐后 rc=0、隐藏目录残留 rc=1。
