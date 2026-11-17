# ponygo 软件质量管理体系的"植入效果"审计报告

- 审计对象：ponygo（`/home/dm/ponygo`，HEAD `9e55ffc`，工作区干净）及其**在本机的 15 个植入实例仓**
- 审计日期：2026-11-17
- 方法：① 会话归档机械取证（615 个会话，命令→退出码逐条抽取）② 逐仓磁盘收据（status/audit/门禁自检/ci-verify/ADR↔提交对应性）③ 机制面只读审计（承诺→门禁覆盖矩阵 + 假放行反例）
- 三路原始证据（会话 / 逐仓 / 机制）与复算脚本留档于 `.scratch/2026-11-17-qms-audit/`（临时区，按 Scratch Hygiene 不承诺长期存活；结论已蒸馏进本文，交付时以本文为准）

---

## 0. 一句话结论

**植入效果 = 中等偏强；ponygo 需要升级，但缺口在"接线与诚实面"，不在"机制数量"。**

- 行为面：有提交的会话里 **72–80% 提交前跑过门禁、62–76% 跑过测试**；决策记录写入 81 会话（13.3%）；出现"红相先冻结""独立验收抓出假绿"等**主动治理行为**——这些是植入生效的硬证据。
- 判定面：**存在 P0 假放行**——7 仓「`ponygo status` 判 2.1 红 / `ci-verify` 绿」；A6 缺失时归档封印静默 fail-open；决策记录被 `git rm` 不受任何门看守；零断言 spec 双面全过。
- 工程面：12/12 实例停在旧代门资产（缺 `PONYGO_GATE_SPEC_TIMEOUT` 平台派生）；2 仓实质未植入（`chat` 不是 git 仓、`job_copilot` 无 `meta.yaml`/notes 且未登记 alt-governance）。

---

## 1. 会话面：治理是否真的改变了 agent 行为

窗口 2026-11-10 → 11-17，13 个已植入仓，615 个会话（退出码取自 `job/settled.data.detail`）：

| 指标 | 数值 | 口径/命令 |
|---|---|---|
| 有 `git commit` 的会话 | 49 | `grep -c '"commits": \[{' index2.jsonl` |
| 其中提交前跑过门禁 | 39（80%） | 同上，`gates` 非空 |
| 其中提交前跑过测试 | 37（76%） | 同上，`tests` 非空 |
| 门禁/审计调用 | 2127 次，exit 0 = 2069（97.3%），非 0 = 53 | 非 0 里有 32 次是 `ponygo status\|audit` 报缺口 |
| 测试调用 | 1968 次，exit 0 = 1850（94%） | 61 次失败后多被修复（同会话复跑绿） |
| 写决策记录（严格口径） | 81 会话（13.3%） | `mine/findings.md` 表B |
| `--no-verify` 字面命中 | 57 次 / 11 会话 → **真实绕过 15**（commit 4 + push 10 + CI 配置改写 1），`/tmp` 探针 20，纯文本 22 | `mine/novfy.py` |

**独立复算**（session-miner，609 会话）得 72% / 62%，同一量级——两个口径的差异来自窗口边界与命令分类口径，不是方法分歧。

8 个深读样本的判定（Q1 入册 / Q2 门禁 / Q3 测试分权）：

| # | 会话 | Q1 | Q2 | Q3 | 要点 |
|---|---|---|---|---|---|
| 1 | ponyllm `4108a85a` | 遵守 | **违反** | 遵守 | 主动写 ADR + 4 条备选；pre-commit 被 40+ 存量 note 打红 → 直接 `--no-verify` 提交并 push |
| 2 | cluster-infra `mwjggciad3406w` | 遵守 | 部分 | 遵守（26 例 spec + 42 例独立审计） | 生产合并用 `PONYGO_DRIFT_STRICT_SKIP=1` 跳过 drift 门，**不留持久痕迹** |
| 3 | pony-agent `b4c2eeb9` | 遵守 | 遵守 | 遵守且强（11 轮验收，第 10 轮抓出"变异假绿"） | 治理反向增强了质量 |
| 4 | pony-agent `mwfrg711` | 遵守 | 部分 | 遵守（红相先冻结、自证无 `#[ignore]`） | commit exit 码不可信（exit=1 但提交落地） |
| 5 | ponygo `d3358f20` | 遵守 | 遵守 | 部分（基线 `tests/run.sh` fail=1 先存红） | 存量红基线未清零 |
| 6 | dsh-q20-web `mwe96ka9` | 部分 | 遵守 | 遵守（`RED_EXIT=1` 固化） | — |
| 7 | obsidian `20795a85` | 部分 | 部分 | 遵守且强（Executor 对冻结测试只读） | 常载命约 × 任务 write_scopes 冲突致漏记 |
| 8 | pony-agent `mwaak5l` | 部分 | 部分 | 部分（自造验证分支自裁 PASS） | 测试分权被绕过 |

**关键判断**：正面证据集中在"agent 主动加门禁/主动写备选/主动做独立验收"；负面证据集中在"**门出厂即红 → 绕过成为理性选择**"（样本 1）与"**两套绕过语义并存**"（样本 2 无痕 env-skip vs 框架自带的 `bypass.log` 留痕机制）。这两条属**体系缺陷**，不记在执行者账上。

---

## 2. 磁盘面：逐仓收据（15 仓）

- 只有 ponygo 自身 status + audit + ci-verify 全绿；其余 14 仓各有至少一项红。
- **7 仓：`ponygo status` 判 2.1 FAIL（门资产漂移）而 `ci-verify` exit 0** —— 实测 `/home/dm/pony-agent`、`ponyfun`、`dsh-q20-web` 等。根因：A4 四段不含"不可变资产字节比对"（`.meta/gates/README.md:14-22`），A5 模板只有 `- run: bash .meta/gates/ci-verify.sh`（`ponygo:5668-5684`）。
- **12/12 实例门 spec 停在旧代**：`grep -c PONYGO_GATE_SPEC_TIMEOUT .meta/gates/*.spec.sh` = 0，框架侧 2026-11-11 起的平台派生/超时预算修复未下发。
- `chat`：骨架完整但 `git status` exit 128（不在 git 仓）→ 钩子、ADR↔提交、门禁边界全悬空，工具只给 WARN。
- `job_copilot`：无 `meta.yaml`/constitution/notes，`ponygo audit` 命中 3/16；真实载体是 `docs/decisions`（47 条）+ husky 替代物，但**未登记 alt-governance**。
- `ponyllm`：`verify-note.sh` exit 1、48 条 FAIL（1.8/1.10）→ 存量 ADR 债使本地层永久红；这正是该仓会话里 `--no-verify` 的成因。
- ADR↔提交 same-commit 比例：pony-agent 11.3% / social 19.6% / ponygo 29.0% / job_copilot_marketing 30.1% / cluster-infra 32.7% / ponyfun 37.2% / dsh-q20-web 43.6%（"代码提交携带同主题 ADR"的口径；空头 ADR 0 例，13 仓 × 3 条符号级抽查）。

---

## 3. 机制面：需要升级的错漏（按严重度）

| # | 问题 | 严重度 | 证据 | 最小改进动作 |
|---|---|---|---|---|
| U1 | **实例 CI 不判判据面**：A5 模板只跑 `ci-verify.sh`，2.1/2.4/2.5/2.6/1.2/1.9b/1.9c 在实例 CI 无看守；与 `maturity-ladder.md:153`「CI 的 `ponygo audit --run-specs` 步（A5 workflow 步骤 ②）」直接冲突 | P0 | `ponygo:5668-5684`；实测 pony-agent「CI 绿(0) / status 红(1)」 | A5 模板加 `ponygo status`（或 `audit --run-specs`）步，模板自带 CLI 定位与"缺失则 SKIP+WARN"；同批修正 ladder 口径 |
| U2 | **A6 缺失即静默 fail-open**：`adr-verify.sh:59-65` 的 `[ -f "$ARCHIVE_GATE" ] \|\| return 0` | P0 | 删 A6 后篡改归档件 → A1 exit 0 且无任何提示（实测） | 缺失时打印 SKIP 并存 rc=2 或直接 die（与 `ci-verify.sh:65-67` 对齐）；改 A1 = 不可变资产 → 需 ADR + 双写 |
| U3 | **决策记录可被删除且无门**：`adr-verify.sh:126` 的 `--diff-filter=ACMR` 缺 `D`；A6 只管 `archived/` | P1 | `git rm` 一条 ADR → A1 exit 0「无暂存 ADR 变更」；A4 亦绿 | diff-filter 加 `D`，删除路径要求同提交 simplification note（1.11 已锁形状） |
| U4 | **零断言 spec 双面全过**：`if false; then exit 1; fi` + `echo` + `exit 0` 既满足静态"拒绝断言"扫描，真跑又记 `[ok]` | P1 | `audit --run-specs` 记 `[ok] 2.3` 并计入"4 个 spec 全通过"（实测） | spec 输出机读计数（`asserts=/rejects=`），`run_gate_specs` 断言 `rejects≥1` 且 `fail=0` |
| U5 | **CLI 结论行虚绿**：1.10 未判定时仍打印「级自洽验证：通过」并 exit 0；`hits<total` 时 `miss_ids` 仍为空 | P1 | `/tmp` 夹具 level:1 + 缺 Alternatives 的 ADR → `status=0` 而 `verify-note=1`；`audit --json` 15/16 但 `miss_ids=[]` | 结论行改「已判定部分通过（1.10/2.3 未判定）」；每项检查登记稳定 id |
| U6 | **存量债无清零/豁免路径**（出厂即红）→ 绕过理性化 | P1 | ponyllm `verify-note` 48 条 FAIL / ponygo 基线 `tests/run.sh` fail=1 / 会话样本 1 | 引入 `ponygo adopt` 基线棘轮：把存量违例冻结进 manifest（带到期日），门只拦**新增**；到期未清零转红 |
| U7 | **绕过语义不统一**：`drift-strict.sh:188` 的 env-skip 只打印一行、无持久痕迹；框架自带 `git-flow-gate` 却写 `bypass.log` | P1 | `cluster-infra` 生产合并不留痕迹（会话样本 2）；两套语义在同一框架内并存 | 框架层约定"凡逃生口必须落 append-only bypass ledger（含 who/when/why/gate）"，并把 ledger 接入 1.11/审计 |
| U8 | **跨仓植入无版本可追溯**：实例不带 CLI，2.1 只与"当前 PATH 的 CLI"比对 → CLI 升级即全实例变红（upgrade cliff），`upgrade apply` 又会一次性覆盖本地弱化证据 | P1 | 12/12 实例旧代资产；`pony-agent` 无 `./ponygo`（exit 127） | `init` 写 `.meta/.ponygo-seed`（框架 commit + 17 文件 sha，机器写入），`upgrade --check` 分类 `stale/unknown` |
| U9 | **A8 在框架仓自身空转**：`no-residue.manifest` 不存在 → 门恒「跳过」exit 0，CI 每天跑但从未判过任何东西 | P2 | `bash .meta/gates/no-residue.sh` → exit 0「跳过」 | 补 manifest（至少登记已删符号族）或把"清单缺失"升为 CI WARN 汇总 |
| U10 | **no-residue 平台口径分裂**：rg 分支尊重 `.gitignore`、grep 退化分支不尊重 → 同树两判 | P2 | `/tmp` 夹具：rg exit 0 vs `NO_RESIDUE_FORCE_GREP=1` exit 1 | rg 加 `--no-ignore` 对齐，或两侧同口径并声明"被 ignore 的文件不属于生产树" |

---

## 4. 升级建议（排序，不改机制数量）

**第一批（P0，先堵假放行）**：U1（B010）→ U2（B011）。两者都是"把已有承诺接上线"，不新增机制税。
**第二批（P1，治"出厂即红"与绕过语义）**：U6（B012）→ U7（B013）→ U3（B014）→ U8（B015）。
**第三批（P1/P2，诚实面与平台面）**：U5（B016）→ U4（B017）→ U9/U10（B018）。

**明确不做（负空间）**：不把 1.10/1.11 在 CLI 里复制第二份；不冻结 A3/A5（实例会追加钩子逻辑）；不让只读命令执行仓库脚本；不为"价值判断/合规背书"造门。

---

## 5. 盲区（本报告不覆盖，防止结论被高估）

1. ADR 语义质量（备选是否真权衡、Decision 是否真落地）——仅做符号级抽查，靠 review。
2. 远端 CI 实跑状态（只核本地可跑的 A4/A5 形态），平台侧 required checks 未核。
3. Windows 实机未跑（`PONYGO_GATE_SPEC_TIMEOUT` 平台派生只做静态检查）。
4. `upgrade apply` 未执行（避免改被审仓）；"同步后是否仍红"未验证。
5. 文档分层语义（tier 放置/slop 预算）不在本轮范围；只查"家是否存在且自动加载"。
6. 会话样本 8 个为深入样本，聚合数字为机械口径；"agent 内心是否绕过"不可判，只判可观测行为。
