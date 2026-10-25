# Revision: 新增 observe 维度（ob0/ob1/ob2 三级判定 + ob3 advisory）

Status: accepted

## Context

可观测性接入长期停在"文档约定 + 人肉巡检"：没有一条非零退出锁住"声明与实现一致"，于是三类漂移只能靠人偶然发现——

- **声明腐烂**：声明里 `anchor` 指向的文件/落点已删或改名，声明还写着"已接入"；
- **漏接**：声明说该有这一维，代码里没有或只写了一半（有 SDK 无 exporter、有 logger 无结构化字段）；
- **越界**：同一条横切能力（HTTP 客户端、错误分类、错误边界）出现第二份实现，于是在别处发出的请求漏掉 `traceparent`、漏掉 timeout。

ponygo 既有判据（L0–L5）只看治理骨架与声明级通用判据，**不看任何一个具体维度的接入质量**；"该不该有这一维"又随部署形态而变（desktop 没有常驻监听地址，pull 模型不成立；library 没有进程边界，日志归宿属于宿主），不能一刀切要求四维齐全。同时，判据所需的领域知识（本集群的 endpoint、标签约定、采集模型、判定 rubric）已经沉淀在一个外部 skill 里，ponygo 不该复制它的全部正文，也不该在没有判据时假装能判。

结论：需要一个**级别化**的维度判据——把"接入到哪一级"变成可机械判定的 ob0/ob1/ob2，并用 ob3 承载"靠 review 的目标画像"。

## Decision

### 1. 命令面

`ponygo observe` 是一组子命令，与既有六条核心命令并列：

```
ponygo observe status                           只读静态报告（不判定），exit 0
ponygo observe init   --kind <k> [--service <s>] [--dims a,b] [--anchor-<dim> <path>]
                      [--reason-<dim> <text>] [--force] [--dry-run] [--yes]
                                                落地四维归属声明（唯一写命令）
ponygo observe audit  [--level ob0|ob1|ob2] [--base <rev>] [--json]
                                                判定是否达到目标级（缺口仅作 backlog，不决定退出码）
ponygo observe upgrade [--check]                与技能契约的版本兼容门（CI 用 --check）
```

- `--level` 的**值**决定语义（与位置无关）：`ob0|ob1|ob2` 是断言；`ob3` 与 `S|M` 被显式拒绝（exit 1）。
- `--json` 只属 `status|audit`：stdout 只有一行固定词表 JSON，人读与 skill 原始输出走 stderr。
- skill 定位唯一口径：`--skill-dir` > `PONYGO_SKILL_DIR` > `$HOME/.agents/skills/observability-onboarding`；
  版本源唯一：`<skill>/references/contract.json` 的 `contract_version`。
- `--kind` 必填且限定枚举（`desktop k8s-service cli batch library`）；`service` 缺省取目录 basename 经
  sanitize，显式值必须匹配 `[A-Za-z0-9._-]+`。生成物里 `service`/`kind` 永远是真实值，占位只落在四维
  `anchor`/`reason` 上。

### 2. 三级判据

| 级 | 判据 | 谁判 |
|---|---|---|
| ob0 | `docs/observability.yaml\|yml` 在场，且**非注释行**无占位符 | ponygo 自己（文件 + `awk`/`grep` 级扫描） |
| ob1 | 声明与现实一致：skill `check-declaration.sh` 退出码 0 | skill 脚本；ponygo 只看退出码 |
| ob2 | 声明有真实收口点 + 挂载载体里真有 `audit-diff` 调用 + 其退出码 0 | skill 脚本 + ponygo 的载体 grep |

配套的退出码纪律（K11）：**唯一判据是「当前级 ≥ 目标级」**——`0` 已达目标级（`gaps` 可非空，缺口是
距下一级的 backlog）；`1` 未达目标级（含 `below_target`）或用法错；`2` 工具或输入错误；`3` 证据不可得。
`audit-diff` 的 `rc=3` 原样升为 ponygo `rc=3`（gap 记 `evidence_insufficient`），`rc=4`/其它升为 `rc=2` +
`tool_error`："判不了"既不伪装成"未达标"，也不伪装成"达标"。

### 3. 数据块策略：嵌入 ponygo，而不是 skill `references/`

维度映射（kind 枚举、挂载载体清单、版本下限、锚点/占位符定义）以数据块形式**嵌在 `ponygo` 单文件里**，
`--mapping <file>`（等价 `PONYGO_OBSERVE_MAPPING`）可覆盖。

理由（三条，任一成立即可否决"放在 skill 侧"）：

1. **skill 不在本仓库 git 下**：放进 skill 的 `references/` 就没有版本血缘，框架侧改动无法随 git 审阅；
2. **重装即丢**：skill 是外部安装物，重装/升级会覆盖目录，框架数据会被静默回退；
3. **单文件安装**：ponygo 的安装模型是"一个 bash 文件即可用"，运行期依赖只允许 skill 的**脚本契约**（退出码），
   不允许依赖 skill 的数据文件格式。

### 4. 判定权不下沉

ponygo 不做领域判断：ob1/ob2 一律交给 skill 脚本，ponygo 只负责（a）定位 skill、（b）调用脚本、（c）聚合退出码、
（d）把 gap 映射到固定词表。判据口径的唯一真源是 `<skill>/references/declaration-rubric.md`；ponygo 侧任何
"看起来像判据"的文案都只是指针。

### 5. ob3 是 advisory

ob3 = 采样策略 / `gen_ai.*` 成本归因 / SLI 告警组。它依赖流量画像与业务判断，没有可机械判定的形状；
把它写成判据会退化成仪式。故 `observe audit` 只在报告末尾打印固定三条待办 + 一句口径指针，
**不解析任何 skill JSON**；`--level ob3` 被显式拒绝。

## Alternatives considered

- **R1：把维度数据块放进 skill 的 `references/`** —— 否决。见 Decision §3 的三条理由；最致命的是"重装即丢"，
  框架行为会随一次 skill 重装而静默改变。
- **按 `kind` 推断 applicable** —— 否决。`kind` 只能给"为什么可能不适用"的**起点**，不能替代声明：
  同类项目（都是 `k8s-service`）在"有没有跨进程调用"上可以完全不同。自动推断会把"该有却没有"这一最该被
  发现的情形，直接写成 `applicable: false` 掩盖掉。故 `--dims` 由人给出，`kind` 只进声明供 review。
- **解析 skill `--json` 的输出做聚合** —— 否决。那等于把 skill 的自由文本/字段结构变成 ponygo 的隐式
  接口：skill 改一个字段名，ponygo 的判定语义就漂移，而且无法为它写"不改代码就能升"的契约。改为只认
  退出码（粗粒度但稳定），字段解释留给 skill 的 stderr 与 rubric。
- **把 skill 正文内嵌进 ponygo** —— 否决。正文是领域知识且随基础设施演进（endpoint、标签、采集模型），
  内嵌会产生第二份真源，且与"skill 与基础设施同步演进"的契约维护方式冲突。
- **init 直接调 skill 的 `scaffold.sh` 生成声明** —— 否决。那会把"唯一写命令"的实现权交给外部脚本：
  写什么文件、写到哪、能否 `--dry-run`、`--force` 语义如何，全部不可控，且测试无法用 stub 覆盖。
  声明模板由 ponygo 自己生成，形状契约由 skill 的 `declaration.schema.json` 事后校验（ob1）。
- **用 `--run-specs` 把 `audit-diff` 包进 `ponygo audit`** —— 否决。`--run-specs` 的语义是"执行本仓库
  `gates/*.spec.sh` 负样本"（只读边界下的显式 opt-in），与"变更级 diff 门禁"是两件事：目标不同（自检 vs
  变更拦截）、输入不同（仓库自带 spec vs 基线 diff）、退出码语义不同。混进去会让 `audit` 的 rc 同时
  表达"治理打分"和"变更越界"，无法判读。

## Consequences / 已知局限

逐条如实记录（编号 K* 沿用交接单；括号内标注该条对应的目标修正 G*）：

- **K1（G1 修正）**：ob 级别不是 skill 四维 verdict 的复述。级别由 ponygo 的判据链定义
  （声明在场 → 一致 → 收口挂载）：ob0 与 ob2 的挂载证据由 ponygo 自己判，skill 的四维结论只经退出码
  进入 ob1 那一段。因此"skill 侧四维 PASS"既不说明 ob0 的占位已清，也不说明 ob2 有收口点与挂载；
  两套结论各管一段，不能互换。
- **K3 / K7**：ob2 的"挂载"是**形状判据**——在载体文件里 grep 到 `audit-diff` 调用即算挂载，证明不了它
  真的在 CI 里跑、也证明不了它跑的是哪条基线。真执行证据是 `audit-diff` 本身（K7），所以 ob2 的挂载
  只是必要条件。默认载体是 CI/钩子配置（`.github/workflows/*.yml`、`.gitlab-ci.yml`、
  `.pre-commit-config.yaml`、`lefthook.yml`、`.githooks/pre-push`）；写在 `Makefile`/`package.json` 里不算。
- **K4**：ob1 只判"声明与巡检一致"，不判"声明是否诚实"。四维全 `false`、理由写得漂亮的声明同样 PASS
  （只要巡检侧也认为"没有该维实现"）。识别"全 false 的谎言"是非机械项，属 review；这条已写进
  `ponygo observe --help` 与 README，避免把 PASS 误读成"接入合格"。
- **K6（G3 修正）**：判据链是**代码**，不是数据。数据块只承载词表与载体清单（kind 枚举、挂载载体、
  版本下限）；新增一种判定类型（新的 judge）必须改 `ponygo` 代码并补测试，不能靠改映射文件"配置出来"。
  这是单文件自洽的代价：可预期、可测，但扩展要发版。
- **K8（NFR 偏差）**：NFR 基线要求 `logging.format=json`。ponygo 是零依赖 bash CLI，无法在全命令面
  统一结构化输出；折中是 `status|audit` 的 stdout 单行固定词表 JSON + 人读文本走 stderr，其余命令保持
  人读文本。`upgrade` 没有 JSON 形态——这是**已知偏差**，不是遗漏。
- **`audit-diff` rc=3 → ponygo rc=3 的裁决**：证据不可得既不能升成 1（会被当成"未达标"从而被"修绿"），
  也不能降成 0。故原样传递 3；`--json` 的 `gaps` 记为 `evidence_insufficient`（与
  `check-declaration` rc=3 同义；`tool_error` 只留给 rc=4 与非白名单工具失败），`current` 记 `unknown`。
  CI 必须据此红。
- **`observe upgrade --json` 不可达**：`--json` 只对 `status|audit` 开放，`upgrade --json` 与 `init --json`
  都 exit 1。理由：upgrade 的输出是版本门报告（skill 路径 + 版本 + 结论），没有稳定词表；给它造一套
  只为对称而存在的字段，会扩大必须长期维护的接口面。守卫是显式的（die 并说明），不是静默忽略。

## 验收证据

- `tests/run.sh` 场景 **s33~s36**：observe 命令面与判据链的回归断言（逐字 JSON、退出码分支、stub skill
  与单文件自洽）。
- `.dev-team/` 审核链：`review-plan*.json`（方案对抗审核与闭合裁定）、`review-plan2*.json`（工程审核
  BLOCKING 项与闭合复核）——本决策的每条"被否选项"与"已知局限"都对应其中的一条裁定。
- 本仓实测（人读复核）：`ponygo observe status|audit|upgrade`、ob2 全通的临时仓库（`当前级: ob2`、
  `gaps: []`、exit 0）、`--base` 非法基线的 rc=2 + `tool_error`。

## 影响面

- `ponygo`：新增 `observe` 解析分支与四个子命令、`--level/--json/--skill-dir/--mapping` 归一、数据块、
  `usage()` 与两行已知局限；
- `README.md`：命令面列表 + §4.4 小节；
- `checklists/observe-init.md`、`checklists/observe-audit.md`：两条操作程序；
- `tests/run.sh`：s33~s36；
- 不做阶梯语义变更：L0–L5 判据与既有计数不变，observe 是并列维度；
- 版本：v2.7.0（README 示例同步）。

## 附：`observe audit` 的退出码语义（K10/K11，审核 B 指出的歧义）

**唯一判据：当前级 ≥ 目标级**（优先级 `2`（工具/输入错误）> `3`（证据不可得）> `1`（未达目标级）> `0`（已达））。
目标级来源有两种，只是目标来源不同，判据完全相同：

| 目标来源 | 触发 | 说明 |
|---|---|---|
| `.meta/meta.yaml` 的 level 经映射表 | 不给 `--level` | 项目自报的成熟度级决定它"该到哪一档"（G4：`observe_level = f(ponygo_level)`） |
| `--level obN` | 显式给 | CI 分档推进用：断言"至少到 ob0/ob1/ob2" |

**缺口列表（`gaps`）是「距下一级的 backlog」，默认不直接决定退出码**：目标级已达时 `gaps` 仍可能非空，
人读输出会打印当前模式（`模式: 体检|断言`）以免误读。若 CI 需要零容忍门禁，显式传 `--strict` 即可强制任一缺口 exit 1（`模式: [strict]`）。

被否决的备选：「默认任一缺口即 exit 1」。否决理由：目标级已达仍 exit 1 会让 CI 无法分档推进，
且与交接单验收「`observe audit` 与 `check-declaration.sh` 同结论」冲突（试点项目 pony-agent
`current=ob1 = target=ob1`、`check-declaration` rc=0，旧规则却 exit 1）。通过引入可选 `--strict` 旗标两全其美。

`--json` 的字段词表与目标来源无关（`current/target/judges/gaps` 一致），故 CI 若需区分模式，
应按是否传 `--level` 判断，不要从 JSON 猜。
