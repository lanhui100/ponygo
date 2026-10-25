# checklists/observe-audit.md —— 可观测性维度的审计（老项目接入 / 变更门禁）

> 给**已有代码、要判"可观测性到哪一级"**的项目：只读摸底 → 判定 → 按 gap 处置 → 把 ob2 的门禁挂进 CI。
> 配套：落地声明用 `checklists/observe-init.md`；本文只管"审计与门禁"。
>
> 铁律：**rc=3 不是通过，rc=2 也不是"未达标"**。判不了就报判不了，不许把它写成绿。

---

## 何时用

- 老项目第一次接入：先摸清现状，再决定补什么（不推倒重来）。
- 声明改完 / 架构变更后复判当前级。
- CI 里做变更级门禁（ob2）与级别断言（`--level`）。

不适用：项目还没有声明——先跑 `ponygo observe init`（唯一写命令），或按
`checklists/observe-init.md` 走一遍。

---

## 第 1 步：只读摸底（不改任何东西）

```bash
ponygo observe status            # 声明在场 / 占位残留 / skill 在场与版本；只读，exit 0
ponygo observe status --json     # 同上，固定词表单行 JSON
ponygo observe upgrade --check   # 版本兼容门：不满足 exit 2
```

`status` 恒 exit 0：它**不判定**（`current` 恒 `unknown`，`declaration_consistent` /
`enforcement_mounted` 恒 `skip`），所以别拿它当验收；验收看第 2 步。

## 第 2 步：判定

```bash
ponygo observe audit               # 判到"目标级"为止（target 由项目 meta 派生）
ponygo observe audit --level ob2   # 断言"至少到 ob2"
ponygo observe audit --json        # CI 用：stdout 只有一行固定词表 JSON
```

人读报告两段：三行判定项（`[PASS]/[FAIL]/[SKIP] ob0|ob1|ob2`）+ `当前级 / 目标级 / 缺口: <gap> —— <白话>`。
`[SKIP]` 表示该档未执行（前置档已失败），**不是通过**。

达标线是"没有缺口"，不是"够到 target"：实测一个 `target: ob0` 且 `当前级: ob0` 的项目，因 ob1 判定项
FAIL 仍 exit 1（`缺口: declaration_inconsistent`）。`--level` 只是断言"至少到哪一档"。

## 第 3 步：按 gap 处置

| gap | 含义 | 处置 |
|---|---|---|
| `declaration_missing` | 找不到 `docs/observability.yaml\|yml` | `ponygo observe init`（然后走 observe-init 清单） |
| `placeholder_present` | 非注释行仍有占位符 | 填实（`--anchor-*` / `--reason-*` + `--force`） |
| `declaration_inconsistent` | 声明与巡检不一致（`check-declaration.sh` rc=2） | 按 stderr 逐维修正：漏接就补实现，声明过期就改声明 |
| `evidence_insufficient` | 证据不可得（`check-declaration.sh` rc=3） | 见下节"rc=3 的处置" |
| `enforcement_points_missing` | 声明没有真实收口点 / 门禁空转 | 在声明里补 `enforcement_points`（path + guarantees + forbidden_in_other_files） |
| `mount_missing` | 挂载载体里没有 `audit-diff` 调用 | 见"ob2：收口点 + 挂载" |
| `diff_warn` | `audit-diff.sh` rc=1（非阻断告警） | 读 stderr 的 WARN，能消就消；消不掉要显式接受风险并写进声明 `note` |
| `enforcement_violation` | `audit-diff.sh` rc=2（有违规） | 按 hint 把越界实现收回唯一收口点 |
| `tool_error` | 工具/输入错误；本次判定不可信 | 读 stderr：skill 缺失、脚本 rc=4、`--base` 不可解析等 |
| `below_target` | 当前级低于 `--level` 断言 | 补到目标级，或把断言降到已达成级（断言不是愿望） |

## 第 4 步：把 ob2 挂进 CI（门禁真正开跑）

在 CI/钩子里调 skill 的 `audit-diff.sh`（**唯一变更级门禁**），并在声明里声明收口点。

---

## `--level ob0|ob1|ob2` 的断言语义

- `--level` 是**断言**，不是"判到哪一档"的开关：判据总是从 ob0 往上判，`--level` 只决定
  "当前级够不够"这一档。
- 值的语义：`ob0` = 声明在场且无占位；`ob1` = 加上"声明与现实一致"；`ob2` = 再加上"收口点 + 变更门禁"。
- 当前级 < 断言级 ⇒ exit 1，`gaps` 追加 `below_target`（实测：`--level ob2` 在 ob1 项目上得到
  `gaps: ["diff_warn","below_target"]`）。
- 不给 `--level` 时按项目 meta 派生目标级（无 `.meta/` ⇒ `ob0`；实测 `.meta/meta.yaml` 的 `level: 2`
  对应 `target: ob1`）。
- `ob3` 与 `S`/`M` 都被拒：`ponygo observe audit --level ob3` → exit 1
  （"ob3 是成本与 SLO 的目标画像，不参与判定"）；`--level S` → exit 1（"observe 侧 --level 只收 ob0|ob1|ob2"）。
- `--level` 只属 `audit`；写在 `init`/`status`/`upgrade` 上不改变判定，别指望它"顺手升级"。

---

## rc=3 / rc=2 的处置（不得当通过）

判据在 skill 脚本里，ponygo 只聚合退出码，所以"判不了"与"未达标"必须分开：

| 来源 | rc | ponygo 侧 | 处置 |
|---|---|---|---|
| `check-declaration.sh` | 3 | `gaps: [evidence_insufficient]`，`current: unknown`，**ponygo rc=3** | 补证据后重跑：确认项目可被巡检（代码可达 / 事实可采集）；rc=3 是"没结论"，不是"没缺口" |
| `check-declaration.sh` | 4 | `gaps: [tool_error]`，`current: unknown`，ponygo **rc=2** | 声明层不可判定（声明不合规 或 工具/环境错误）；先看 stderr，再 `bash <skill>/scripts/check-declaration.sh --help` 自检 |
| `audit-diff.sh` | 3 | ponygo **rc=3**，`gaps: [tool_error]`（实测：不可得与工具错误共用该标签） | 同"证据不可得"：修取证条件后重跑 |
| `audit-diff.sh` | 4/其它 | ponygo **rc=2**，`gaps: [tool_error]` | 用法/环境错（最常见：`--base` 不可解析、目录不是 git 仓库、找不到声明） |
| 任一 | skill 目录 / `references/contract.json` 缺失 | `audit`/`upgrade` **rc=2** + 安装提示 | 装 skill 到 `~/.agents/skills/observability-onboarding`，或 `--skill-dir` / `PONYGO_SKILL_DIR` 指过去 |
| 任一 | 契约版本不满足 | `upgrade --check` **rc=2**；`audit` 不中止（`--json` 的 `skill.compatible=false`） | 升级 skill 后重跑；别把 `compatible=false` 当"能用" |

- **无集群/取不到事实时**：`audit` 的结论是 rc=3（或 rc=2），CI 必须据此**红**。禁止写
  `|| true`、禁止把 rc=3 映射成 0；"没证据"与"没缺口"是两件事。
- ob1/ob2 的判定权在 skill：ponygo 不解析 skill 的四维 verdict，只看退出码。

---

## ob2：收口点 + 挂载（两个都要）

ob2 不是"声明写得漂亮"，而是"变更时真的有门禁在拦"。实测两半：

1. **收口点在声明里**（`docs/observability.yaml` 的 `enforcement_points`）：每条横切能力
   （`http_client` / `error_classifier` / `error_boundary` / `journey`）声明**唯一实现路径**
   `path` + 承诺 `guarantees`（enum：`traceparent` / `timeout` / `classify` / `breadcrumbs` /
   `trace_id` / `anchor_events`），可加 `forbidden_in_other_files`（正则 + hint，规则由项目自己声明）。
2. **挂载载体里真的有调用**：在 CI / 钩子配置里出现 `audit-diff`。实测被认的载体包括
   `.github/workflows/*.yml`、`.gitlab-ci.yml`、`.pre-commit-config.yaml`、`lefthook.yml`、
   `.githooks/pre-push`；`Makefile` 与 `package.json` 不在默认载体清单里（写在那里 = `mount_missing`）。

两半齐了才会看到 `[PASS] ob2 收口与变更门禁`（实测可达 `当前级: ob2`、`gaps: []`、exit 0）。
缺一半的表现：缺挂载 ⇒ `mount_missing`（exit 1）；缺收口点/规则集空 ⇒ 门禁空转，`audit-diff` 报
WARN 或 violation（exit 1）。

---

## `audit-diff` 的 `--base`（CI 干净树 vs 本地工作区）

`--base <rev>` 是**取证基线**：脚本比"当前状态 vs 该基线"的差异，只扫差异里的新增行。

| 场景 | 用法 | 实测语义 |
|---|---|---|
| 本地预检（工作区，含未提交改动） | `audit-diff.sh --repo . --base HEAD` | 干净树扫 0 文件；改动 `src/http.js` 后扫 1 文件 / 1 行新增 |
| CI（干净树，只比本次提交） | `audit-diff.sh --repo . --base "$BASE_SHA"`（PR 的目标分支 sha / 上次发布 tag） | 干净树上"未提交改动"为空，差异恰是提交范围 |
| 只审暂存区 | `audit-diff.sh --repo . --staged` | 只扫 `git diff --cached` |

- `ponygo` 侧有同名透传：`ponygo observe audit --base <rev>`（默认 `HEAD`）。实测非法基线会
  被 skill 判为工具错：`FAIL 基线不可解析为 commit: nosuchrev` ⇒ ponygo **rc=2** + `tool_error`。
- CI 里**不要用 `HEAD` 当基线**：干净树的 `HEAD` 等于"没有差异"，门禁会空转成 PASS。
  基线取"变更起点"（目标分支 sha / 上次 tag），并保证 CI 里该 commit 可达（`fetch-depth: 0`
  或显式 `git fetch origin <base>`）。
- `audit-diff.sh` 必须在 **git 仓库**里跑：非 git 目录 / 无 commit 的仓库都是 rc=4
  （实测），经 ponygo 表现为 rc=2 + `tool_error`——不是"没问题"。

---

## `--json` 在 CI 里的用法

```bash
ponygo observe audit --level ob1 --json > observe.json
rc=$?
# rc 决定门禁红绿；JSON 只用来出报告/定位 gap，不用来改判
jq -r '.gaps[]' observe.json
```

- `--json` 时 **stdout 只有一行 JSON**（末尾一个 `\n`），人读文本与 skill 原始输出全走 stderr。
- 只属 `status|audit`：`init --json` / `upgrade --json` 都 exit 1（"仅适用于 … status|audit"）。
- 字段词表（固定，无自由文本，故无需转义）：

| 字段 | 取值 |
|---|---|
| `schema` | 恒 `ponygo.observe/1` |
| `command` | `status` \| `audit` |
| `declared_kind` | `desktop` \| `k8s-service` \| `cli` \| `batch` \| `library` \| `unknown`（声明里读不到合法枚举即 `unknown`） |
| `current` | `ob0` \| `ob1` \| `ob2` \| `unknown`（`status` 恒 `unknown`） |
| `target` | `ob0` \| `ob1` \| `ob2` |
| `skill` | `{present: bool, contract_version: string, compatible: bool}`（缺失时 `contract_version: "unknown"`, `compatible: false`） |
| `judges[]` | `id` ∈ `declaration_present` \| `no_placeholder` \| `declaration_consistent` \| `enforcement_mounted`；`status` ∈ `pass` \| `fail` \| `unknown` \| `skip` |
| `gaps[]` | `declaration_missing` / `placeholder_present` / `declaration_inconsistent` / `evidence_insufficient` / `enforcement_points_missing` / `diff_warn` / `enforcement_violation` / `mount_missing` / `tool_error` / `below_target` |

`status --json` 的定值：`command: "status"`、`current: "unknown"`、`declaration_consistent` 与
`enforcement_mounted` 恒 `skip`。

---

## ob3 为何只作 advisory

- ob3 是**成本与 SLO 的目标画像**（采样策略 / `gen_ai.*` 成本归因 / SLI 告警组），依赖业务判断与
  流量画像，不是"有/没有"的形状判据——机械判定会把它降级成仪式。
- 因此 `--level ob3` 被显式拒绝（exit 1），`observe audit` 只在报告末尾打印固定三条待办 + 一句指针
  （"判定口径见 `<skill>/references/declaration-rubric.md` §6.6"），**不解析任何 skill JSON**。
- 想让 ob3 变成判据，得先有可机械判定的形状（例如 SLI 定义文件 + burn-rate 阈值），那属于新增判定类型，
  需改 `ponygo` 代码与测试，不是改一句文案。

---

## 验收判据

- 摸底：`ponygo observe status` exit 0，声明/skill 两行如实（`compatible=no` 不是"能用"）。
- 判定：`ponygo observe audit` 的 rc 与第 2 步结论一致；达标只认 rc=0 且 `gaps: []`。
- 门禁：CI 里 `audit-diff` 用"变更起点"做 `--base`（不是 `HEAD`），且失败时门禁红；
  rc=3/rc=2 一律红，不得 `|| true`。
- 报告：需要机器可读就加 `--json`，并按上表字段消费；不要从 stderr 的文本里抠结论。
