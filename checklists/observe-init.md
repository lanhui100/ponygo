# checklists/observe-init.md —— 可观测性维度落地（首次接入 / 新项目）

> 给**还没有 `docs/observability.yaml`** 的项目：把四维（metrics / tracing / logs / issues）的
> 归属声明落地，清掉占位，再交给 `ponygo observe audit` 判定。与 `checklists/init.md` 并行——那份管治理骨架，
> 这份只管可观测性这一个维度；顺序上先 `init`（骨架）再本文（维度）。
>
> 铁律：**`init` 的退出码只说明"参数合法 + 文件写成功"，不说明"达标"**。达标只看 `ponygo observe audit`。

---

## 何时用

- 新项目第一次接入本集群的可观测性底座（skill `observability-onboarding` 已装）。
- 老项目要补一份可观测性声明（先按 `checklists/observe-audit.md` 摸清现状，再回本文落地）。
- 已有声明但要重写（`--force` 覆盖）；改 `kind` 也走重生成——声明是生成物，别手改成"看起来对"的样子。

不适用：项目规模太小、不打算长期维护（见 README §6.1 停止线）；或没有 skill 安装条件——
`observe audit` 会 rc=2 fail-closed，不会降级成"通过"。

---

## 前置（先跑这几条）

### 1. skill 是否已装、版本是否够

```bash
ponygo observe status        # 只读：报告声明在场/占位残留/skill 在场与版本；exit 0
ponygo observe upgrade --check   # 版本兼容门：兼容 exit 0；不满足 exit 2（CI 用法）
```

定位顺序（唯一口径）：`--skill-dir <dir>` > 环境变量 `PONYGO_SKILL_DIR` > `$HOME/.agents/skills/observability-onboarding`。
版本源是 `<skill>/references/contract.json` 的 `contract_version`（不是 `<skill>/contract.json`）。

- 技能目录或 `references/contract.json` 缺失 ⇒ `audit`/`upgrade` **exit 2** 并打印安装提示
  （`从所属 skill 仓把 observability-onboarding 安装到 ~/.agents/skills/observability-onboarding`）；
  `status` 不因此失败，只报 `skill: …（contract_version=unknown，兼容=no）`。
- 版本低于要求 ⇒ `ponygo observe upgrade --check` **exit 2**（`audit` 不中止判定，但 `--json` 里 `skill.compatible=false`）。

### 2. `kind` 取值（必填）

`--kind` 无既有声明时**必填**，取值只在下面枚举内，否则 exit 2：

```
desktop  k8s-service  cli  batch  library  frontend  pipeline
```

`kind` 不是标签，是适用性推论的起点：凡以 `kind` 作推论，理由必须写进对应 `reason`（"kind 决定"不算理由）。

> **复合架构裁决原则（以最外层交付的进程边界为准）**：
> - **全栈桌面端（如 Tauri = 前端 React + Rust Core）**：进程生命周期随用户本地窗口启停，无稳定网络常驻监听，**必须声明为 `kind: desktop`**（前端代码是其内部视图层，不单独声明为 frontend）。
> - **独立部署的 Web SPA / SSR（部署在 CDN/Nginx/Node 托管）**：独立发布给浏览器访问，**声明为 `kind: frontend`**。
> - **前后端分离工程**：若在同一仓库中但独立构建部署，应拆分或分别治理；若作为单一服务交付，按对外暴露的主要进程形态判定。
> - **CI/CD 自动化构建与工程脚本**：声明为 `kind: pipeline`。

### 3. `--service` 规则

- 缺省 = 项目目录 basename，经 sanitize（`[^A-Za-z0-9._-]` 逐字符换成 `-`）；sanitize 后为空 ⇒ exit 2。
- 显式 `--service <s>` 优先；取值必须是 `[A-Za-z0-9._-]+`，否则 **exit 2**（`--service 取值非法`）。
- 因此生成的声明里 `service` / `kind` **永远是真实值**；占位只可能落在四维的 `anchor` / `reason`。

### 4. 四维参数规则

| 参数 | 含义 |
|---|---|
| `--dims a,b` | 声明为 `applicable: true` 的维度清单；未列出的维度写成 `applicable: false` **并留 reason 占位**，必须填结构性理由 |
| `--anchor-<dim> <path>` | 该维在仓库里的**唯一实现落点**（`applicable: true` 必填） |
| `--reason-<dim> <text>` | `applicable: false` 的结构性理由（部署形态 / 进程模型 / 数据归属导致的必然不适用，不是排期理由） |
| `--force` | 覆盖已存在声明（唯一写命令的覆盖开关） |
| `--dry-run` | 只打印将写入的内容，不落盘 |
| `--yes` | 破坏性动作前不再确认 |

---

## 步骤（逐项勾选，每步都验证）

### 阶段 A：落地声明

- [ ] 1. 选 `kind`，并决定四维各自 applicable（本项目**该不该**有这一维）：

```bash
ponygo observe init --kind k8s-service \
  --dims metrics,tracing,logs,issues \
  --anchor-metrics src/otel/metrics.js --anchor-tracing src/otel/tracing.js \
  --anchor-logs src/log.js --anchor-issues src/sentry.js
```

- [ ] 2. 验证写入位置与形状：`docs/observability.yaml` 存在（判定侧查找路径也含 `.yml`，`init` 只写 `.yaml`），且
      头部是注释、`service` / `kind` 已是真实值：

```bash
grep -nE '^(service|kind):' docs/observability.yaml
```

- [ ] 3. 有维度不适用时，按 `applicable: false` + 结构性 reason 生成（示例：桌面端无 pull 模型）：

```bash
ponygo observe init --kind desktop --dims logs,issues --force \
  --anchor-logs src/log.js --anchor-issues src/sentry.js \
  --reason-metrics "纯本地单进程，无常驻监听地址，pull 模型不成立" \
  --reason-tracing "无跨进程边界，进程内无跨进程 trace 语义"
```

- [ ] 4. 验证 `--force` 语义：不带 `--force` 重跑同一条命令应 **exit 2**（`声明已存在`），
      带 `--force` 才重写——覆盖前先跑 `ponygo observe status` 确认现有声明不值得保留。

### 阶段 B：填占位（唯一的手工步）

- [ ] 5. 列出未清的占位（**只看非注释行**；注释里的"占位符"是说明文字，不算占位）：

```bash
grep -v '^#' docs/observability.yaml | grep -n '__REPLACE_ME__'
```

  输出为空即这一步完成；有输出就按提示填（模板：把 `<dim>` 换成实维名，`<path>`/`<text>` 换成真实落点与理由）：

```bash
ponygo observe init --kind k8s-service --force \
  --anchor-metrics src/otel/metrics.js --anchor-tracing src/otel/tracing.js \
  --anchor-logs src/log.js --anchor-issues src/sentry.js \
  --reason-<dim> "结构性理由"   # 将 <dim> 换成 applicable: false 的那一维
```

- [ ] 6. 验证 `applicable: false` 的理由是**结构性**的：写成"暂不需要 / 后续再说 / 排期"即不合格
      （会被 review 打回；机器只能查"reason 非空"，查不了"理由是否诚实"）。

### 阶段 C：验证 ob0（静态判据）

- [ ] 7. `ponygo observe status` —— 期望 `声明: docs/observability.yaml`、`占位符: 无`，exit 0：

```bash
ponygo observe status
```

- [ ] 8. `ponygo observe init` 的输出里应出现 `当前静态级别: ob0 达成`；若打印 `ob0 未达` 且列出
      `仍是占位符` 的缺口，说明阶段 B 没填完——此时 `init` 仍 exit 0，**别把 exit 0 当达标**。

### 阶段 D：判定（交给 audit）

- [ ] 9. 跑判定，并读懂退出码：

```bash
ponygo observe audit            # 走向目标级（字段 target）
ponygo observe audit --level ob2   # 断言"至少到 ob2"
```

- [ ] 10. 记下 `当前级:` 与 `目标级:` 以及每条 `缺口: <gap_code> —— <白话>`；gap 词表见
      `checklists/observe-audit.md`。声明落地阶段到此结束，ob1/ob2 的处置转那份清单。

---

## 常见失败与处置

| 现象 | 退出码 | 处置 |
|---|---|---|
| `声明已存在：docs/observability.yaml` | 2 | 加 `--force` 重写；先 `ponygo observe status` 确认要覆盖 |
| `缺必填 --kind` | 2 | 补 `--kind`（枚举 `desktop k8s-service cli batch library`） |
| `--kind 不在枚举内` | 2 | 按提示枚举改；`kind` 决定适用性推论起点，不是自由标签 |
| `--service 取值非法` | 2 | 只用 `[A-Za-z0-9._-]`；或省掉 `--service` 走目录 basename |
| `技能目录不可用` / `references/contract.json` 缺失 | 2 | 装 skill 到 `~/.agents/skills/observability-onboarding`，或 `--skill-dir` / `PONYGO_SKILL_DIR` 指过去 |
| `skill 契约版本不满足` | 2（`upgrade --check`） | 升级 skill；`audit` 不中止，但 `--json` 的 `skill.compatible=false` |
| `ob0 未达` + `仍是占位符` | `init` 仍 0 | 占位未清 ⇒ ob0 不达；回阶段 B（`grep -v '^#' …` 必须为空） |
| `未知 observe 子命令` | 1 | 子命令只有 `status\|init\|audit\|upgrade`；`ponygo observe --help` 看全量 |
| `--level` 收到 `S`/`M` | 1 | observe 侧 `--level` 只收 `ob0\|ob1\|ob2`（`ob3` 也拒绝） |
| `--json` 用于 init/upgrade | 1 | `--json` 只属 `status\|audit` |
| `未知参数或子命令：observe` | 1 | 本机安装的 `ponygo` 不含 observe（旧版）；用仓库内 `bash ponygo observe …`，或重装/升级后再用命令名 |

---

## 验收判据

1. **落地**：`docs/observability.yaml` 存在，`service`/`kind` 为真实值，非注释行无 `__REPLACE_ME__`
   （`grep -v '^#' docs/observability.yaml | grep -c '__REPLACE_ME__'` 输出 `0`）。
2. **只读自检**：`ponygo observe status` exit 0，且`占位符: 无`。
3. **判定**：`ponygo observe audit` 的退出码按下面含义解读——达标要求是 **0**，其余一律不算通过：

| 退出码 | 含义 | 是不是"通过" |
|---|---|---|
| 0 | 已达目标级（`gaps` 可非空——缺口是距下一级的 backlog） | 是 |
| 1 | 未达目标级，或用法错误（如 `--level ob3`、`--level S`） | 否 |
| 2 | 工具或输入错误（skill 缺失、skill 脚本 rc=4、参数非法）——**不是"未达标"**，是判不了 | 否 |
| 3 | 证据不可得（skill 判据跑不出结论） | 否，且**不得当通过** |

> `0` 的条件是**当前级 ≥ 目标级**（目标 = `--level obN`，否则 `.meta/meta.yaml` 的 level）。缺口列表是
> 距下一级的 backlog，不决定退出码：`target: ob0` 且 `当前级: ob0` 时即使 ob1 判定项 FAIL，`audit` 仍 exit 0
> （`gaps` 里带 `declaration_inconsistent`）；要看门禁把项目卡住，请把目标写在 `.meta/meta.yaml` 的 level
> 或显式传 `--level`。

> 判定权不在 ponygo：`ob0` 的文件存在性/占位扫描由 ponygo 自己做，`ob1`/`ob2` 交给
> skill 的 `check-declaration.sh` / `audit-diff.sh`，ponygo 只聚合退出码。判据口径见
> `<skill>/references/declaration-rubric.md`。

---

## 停手条件

- skill 装不上（无安装条件 / 内网隔离）⇒ 停在 `observe status` 的只读报告，别手写一份"看起来对"的声明骗门禁；
  `audit` 的 rc=2 是诚实的结论。
- 声明填不出**结构性** reason ⇒ 说明这维其实该有（缺实现），不是"不适用"；按 gap 去补实现，别把 reason 写成排期。
