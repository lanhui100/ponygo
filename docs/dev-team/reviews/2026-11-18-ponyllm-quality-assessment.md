# ponyllm 软件质量管理水平评估（ponygo 植入后实测）

> 记录类型：外部仓库评估（工程过程记录）。执行人：ponygo 维护侧；被评仓：`/home/dm/ponyllm`。
> 原始中间产物（若有）在 `.scratch/2026-11-18-ponyllm-assess/`，结论以本文为准。

- 评估对象：`/home/dm/ponyllm`（HEAD `e3090b5`，工作区在本次应用前干净）
- 评估时间：2026-11-18
- 工具：ponygo `2.10.x`（HEAD `5d35d19`，含 W0–W3 全部升级）
- 口径：`ponygo audit --level M --json` + `status --json` + 门禁自检 + 语料统计 + git 同提交率

## 0. 本次"应用"做了什么（3 步，均有物理收据）

| 步骤 | 命令 | 结果 |
|---|---|---|
| 同步框架资产 | `ponygo upgrade apply` | 刷新 7 个文件（A1/A2/A7/A8/A9 + gates README + verify-note），重签 `.meta/.ponygo-seed`；`upgrade --check` = 0、`seed 分类：in-sync 16/0/0/0`、2.1 漂移归零 |
| 冻结存量债 | `ponygo upgrade adopt` | 写入 `.meta/notes-baseline.json`：**48 条**（1.8×29 / 1.11×13 / 1.10×6），到期 **2027-02-16**；`verify-note.sh` 由 exit 1 → **0** |
| 门禁复验 | 三个负样本 spec + `ci-verify.sh` + `backlog-gate.spec.sh` | 全 exit 0 |

未提交（`.meta/.ponygo-seed`、`.meta/notes-baseline.json` 为新增；6 个资产文件被刷新）——留给项目自己 commit。

## 1. 机械画像（四问 + PMI 事实）

| 维度 | 事实 | 判读 | 分 |
|---|---|---|---|
| ① 决策记忆 | 决策 **427** 条（implemented 403 / proposed 24 / **rejected 0** / archived 1 未封印）；45 天 **388** commits，369 个含非 ADR 改动中 **115 带 ADR（31%）** | 语料量大、同提交率在本生态属中上；但 29 条 implemented 仍是"提案时代正文"（1.8），rejected 留痕为 0 | **7/10** |
| ② 强制 | 本地 hook 已接线（**v1 块**）、远端 `ponygo-governance.yml` + 主 `ci.yml`（9 job：script-gates / backlog-ledger / test / web / audit / build-and-push-image / deploy）双接线；A1/A2/A4/A6/A7 负样本全绿 | 形到位；但判据面 2.x 在 CI 无看守（A5 是实例可编辑文件，未随升级刷新，缺「判据面」步骤）；1.8 存量债使 `status` 仍 exit 1 | **7/10** |
| ③ 复用 | 实例自有技能 **0**（只有框架基线三名 change-review/governance-review/write-adr） | 高频流程未资产化，`q3.instance_skill` 未命中 | **3/10** |
| ④ 文档 | `docs/AGENTS.md` 在场（家有）；`docs-tier` **未声明** → 2.5 SKIPPED；`archived/` 有 1 件但**无 manifest 封印** | 文档体系半激活；负空间（归档冻结）未落地 | **6/10** |
| ⑤ 卫生 | 根目录**被跟踪的游离过程文档**：`audit_report.txt`、`audit_report_final.md`、`TASK-2026-09-29-alerting-handover.md`；`target/`、`__pycache__/` 已 ignore | 临时/过程产物未下沉 `.scratch/` 或归档 | **5/10** |

`ponygo audit --level M` 命中 **12 / 16**；未命中 5 项：`1.8`、`q1.lifecycles`（**rejected/ 目录缺失**）、
`q1.rejected_trace`、`q3.instance_skill`、`q4.sealed_archive`。

## 2. 主要缺口（按严重度，含最小改进动作）

| # | 缺口 | 严重度 | 证据 | 最小改进动作 |
|---|---|---|---|---|
| 1 | **1.8 存量债 29 条**：implemented 记录仍是 `## Proposal` 时代正文（proposed→implemented 迁移未改写） | P0 | baseline 统计 1.8×29；`status --json` fails=[1.8] | 逐条把 `## Proposal` 改写为现在时 `## Decision`（29 条），`status` 转 0 后重跑 `upgrade adopt`（基线自然收缩） |
| 2 | **基线只对门禁生效、判据面不认**：adopt 后 A1/A4 绿，但 `status/audit` 仍判 1.8 红 → 若启用 A5 判据面步骤，CI 依旧红 | P0（**上游缺陷，已登记 ponygo B023**） | `status --json` exit 1 / fails=[1.8]；`verify-note` exit 0 | 等 ponygo 出裁决（CLI 读基线 / 基线升级指纹 / A5 改跑真源）；期间可先按 #1 清偿 |
| 3 | **无 rejected 留痕且 rejected/ 目录缺失** | P1 | `q1.rejected_trace`、`q1.lifecycles` 未命中；rejected=0 | 建 `.agents/notes/rejected/{class}/`，把历史被否方案补 1-3 条（带一行否决理由 + provenance） |
| 4 | **归档未封印**：archived 1 件无 `manifest.sha256` | P1 | `q4.sealed_archive` 未命中 | `bash .meta/gates/archive-verify.sh seal` 后提交 |
| 5 | **1.11 存量债 13 条**：simplification 缺 `## Reintroduction conditions` | P1 | baseline 1.11×13 | 补齐复活条件（并补检索收据，若写了 `## Removed surface`） |
| 6 | **AI 投影残留**：`ai-surface: off` 但 `AGENTS.md`/`CLAUDE.md` 仍含 constitution 哨兵块 → 旧常载命约仍被 AI 工具载入 | P1 | `status` 两条 WARN 原文 | 删两文件里的哨兵区（或整文件）；若决定启用则改 `ai-surface: on` 后 `ponygo sync` |
| 7 | **本地 hook 仍 v1**（无「A1 缺失即拒绝」） | P1 | `status` WARN「pre-commit 哨兵块为 v1」 | 跑一次 `ponygo init`（会把 v1 原子升级为 v2） |
| 8 | **A5 缺判据面步骤**：CI 不判 2.1/2.4/2.5/2.6 | P1 | `grep -c 'ponygo 判据面' .github/workflows/ponygo-governance.yml` = 0 | 删旧 A5 后跑 `ponygo init` 重新生成（新模板带步骤②），或手工补该步骤 |
| 9 | **docs-tier 未声明** → 2.5 SKIPPED（L2 该判据不计入 PASS） | P2 | meta.yaml 无 `docs-tier` 键 | 决定激活（`docs-tier: on` + 已激活家清单）或显式 `off` |
| 10 | **实例技能 0** | P2 | audit `q3.instance_skill` 未命中 | 把"发布/回滚/配额排查"等高频流程沉淀为 `.agents/skills/*/SKILL.md`（≥1 个即可得分） |
| 11 | **根目录游离过程文档** 3 件 | P2 | `git ls-files` 命中 `audit_report*.md`、`TASK-...md` | 移入 `.scratch/`（不入库）或归档进 `docs/`（按 docs 标准定家），提交里同批删根文件 |
| 12 | 1 个 legacy spec（`backlog-gate.spec.sh` 无 `##SPEC` 计数） | P2 | `audit --run-specs` 的 `[warn] legacy` | 在 spec 末尾补 `##SPEC asserts=/rejects=`（v3 前必须做） |

## 3. 结论

- **水位：L2「承诺可验」形到位、语义债明显**。门禁与负样本机械面（A1–A9 + 三套 spec + backlog 账本）已全绿，
  同提交率 31% 在本生态属中上；但 427 条语料里有 **48 条存量形状债**（1.8×29 / 1.11×13 / 1.10×6，已冻结到 2027-02-16），
  负空间（rejected 留痕、归档封印）几乎空白，实例技能为 0。
- **一句风险**：如果不先清偿 #1，2027-02-16 基线过期当天 `verify-note`/A1/A4 会整体转红——这是"债到期"而非新缺陷。
- **建议顺序**：① 29 条 1.8 改写（去掉最大债）→ ② 归档封印 + rejected 留痕（负空间从 0 到 1）
  → ③ AI 投影残留与 v1 hook（两条命令：编辑/`ponygo init`）→ ④ A5 重生成（判据面进 CI）
  → ⑤ 13 条 1.11 补齐 → ⑥ docs-tier 决策 + 首个实例技能。
- **上游新发现**：ponygo B023——存量基线未进入 CLI 判据面（`status/audit` 不读 `.meta/notes-baseline.json`），
  导致"实例 adopt 后门禁绿、判据面红"。已在 ponygo 账本登记，需一次设计裁决。
