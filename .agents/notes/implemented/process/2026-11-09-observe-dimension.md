# Agent Note: observe —— 命令面之外的第七个治理维度（ob0/ob1/ob2 + 位置子命令）

Status: implemented

## Problem

六条核心命令（`init` / `audit` / `status` / `upgrade` / `sync` / `retire`）判的全是**通用治理形状**：
有没有决策载体、门禁是否真接线、文档是否分层。它们**不看任何一个具体能力维度的接入质量**——
"可观测性接没接、接到哪一级"在 L0–L5 判据里没有任何落点，于是这类承诺只能停在文档里，声明腐烂
（`anchor` 指向的文件已删）、漏接（有 SDK 无 exporter）、越界（同一横切能力出现第二份实现）三类
漂移全靠人偶然发现。

而"该不该有这一维"又随部署形态变化（desktop 无常驻监听地址、library 无进程边界），不能一刀切成
"四维必须齐全"——那样的判据只会被整体绕过。同时判据所需的领域知识（endpoint、标签约定、采集模型、
rubric）已沉淀在外部 skill（`observability-onboarding`）里，框架不该复制它的正文，也不该在没有判据时
假装能判。

缺的是一条**级别化**的维度判据线：把"接到哪一级"变成可机械判定的 ob0/ob1/ob2，并把"靠 review 的
目标画像"单独放 ob3，不混进判定。本仓此前对这一维**没有任何 `.agents/notes/` 决策记录**——唯一的书面
痕迹在框架轨道的 `revisions/accepted/2026-10-25-observe-dimension.md`（该轨道现已冻结只读，见
`implemented/process/2026-11-09-revisions-track-frozen.md`），属于"决策在，工程决策树里查不到"的覆盖
缺口。

## Decision

**`observe` 是一个治理维度，不是第七条核心命令。** 它是带命名空间的一组位置子命令，命令面计数仍是
六条（见 `implemented/process/2026-08-30-six-command-surface.md`）；维度自身的判据线独立于 L0–L2 的
阶梯判据，由 `ponygo observe` 子系统负责。

**1. 五条位置子命令（扁平命名空间：`observe` 之下无第二层子命令；旗标面见第 4 条）**

| 子命令 | 语义 | 退出码 |
|---|---|---|
| `observe status` | 静态报告（不判定）：声明在场、占位残留、skill 在场与版本 | 恒 0（只读） |
| `observe init` | 落地四维归属声明 `docs/observability.yaml`（**唯一写命令**；已有声明需 `--force`，缺它即 exit 2、不静默覆盖） | 0 成功（含 `--dry-run` 预览）/ **2** 用法错、缺 `--force`、skill 契约门不过或写入失败（**无 1**） |
| `observe audit` | 判定是否达到目标级；缺口只作 backlog | 0 达目标级 / 1 未达或用法错 / 2 工具或输入错 / 3 证据不足 |
| `observe upgrade` | 与技能契约的版本兼容门（CI 用 `--check`） | 0 兼容（不带 `--check` 的纯报告恒 0）/ **2** `--check` 下不兼容 |
| `observe probe` | 受控探针：投递带 provenance 的 OTLP span（凭据只读 env，永不回显） | 0 投递成功 / 1 用法错 / 2 网络或非 2xx |

**2. 级判据：ob0 / ob1 / ob2 机械，ob3 advisory**

| 级 | 判据 | 谁判 |
|---|---|---|
| ob0 | `docs/observability.yaml\|yml` 在场，且**非注释行**无占位符 | ponygo 自己（文件 + 行扫描） |
| ob1 | 声明与现实一致：skill 的巡检脚本退出码 0 | skill 脚本；ponygo 只看退出码 |
| ob2 | 声明有真实收口点 + 挂载载体里真有 `audit-diff` 调用 | skill 脚本 + ponygo 的载体 grep |
| ob3 | 采样策略 / 成本归因 / SLI 告警组（目标画像） | 人不判机器：`--level ob3` 被显式拒绝 |

- **唯一判据是「当前级 ≥ 目标级」**：`0` 已达目标级（`gaps` 可非空，缺口是距下一级的 backlog）；
  `1` 未达目标级或用法错；`2` 工具或输入错误（不是"未达标"）；`3` 证据不可得。`audit-diff` 的
  `rc=3` 原样升为 `3`，`rc≥4` 升为 `2`："判不了"既不伪装成"未达标"，也不伪装成"达标"。
- **阻断语义只有两档**：默认（缺口进 backlog，退出码只由级比较决定）与 `--strict`（任一缺口即非零，
  供 CI 一票否决）。没有第三个 scope 维度。

**3. 判定权不下沉，数据块随 CLI 走**

- 领域判断全在 skill：ponygo 只做（a）定位 skill、（b）调用脚本、（c）聚合退出码、（d）把 gap 映射到
  固定词表。判据口径的唯一真源是 `<skill>/references/declaration-rubric.md`，ponygo 侧任何"看起来
  像判据"的文案都只是指针。
- 维度映射（kind 枚举、挂载载体清单、版本下限、锚点与占位符定义）以**数据块形式嵌在 `ponygo` 单文件**
  里，`--mapping <file>` / `PONYGO_OBSERVE_MAPPING` 可覆盖。skill 定位唯一口径：
  `--skill-dir` > `PONYGO_SKILL_DIR` > `$HOME/.agents/skills/observability-onboarding`；版本源唯一：
  `<skill>/references/contract.json` 的 `contract_version`。

**4. 旗标面登记在预算内（含两个"行为开关"，各自单一职责）**：`observe` 的旗标分三类——
① **检查模式**：`observe upgrade --check`（与 `upgrade --check` 同名同义）；
② **行为开关**：`observe init --force`（唯一能覆盖既有 `docs/observability.yaml` 的开关；缺它真实落盘
exit 2，绝不静默覆盖）、`observe probe --dry-run`（零网络预览，与全局 `--dry-run` 同类）；
③ **调用者输入**：`--kind` / `--service` / `--dims` / `--anchor-<dim>` / `--reason-<dim>` / `--level` /
`--base` / `--strict` / `--endpoint` / `--env` / `--timeout` / `--skill-dir` / `--mapping`。
`--force` 是 observe 面**唯一**"改变写入行为"的旗标，理由与 `init` 的"只补缺失、绝不覆盖"互补：
声明是这条维度里唯一的写产物，覆盖必须显式。不新增其它行为开关的原则见
`implemented/process/2026-11-07-flag-budget.md`。

**5. 记录归属**：本维度此后由 `.agents/notes/` 承载（框架级规则变更同样记这里，`revisions/` 只读）。
`observe probe`（受控探针）与 `audit/status --json` 的机读面属后续决策，见
`implemented/process/2026-11-01-audit-machine-surface-and-ai-projection.md`。

## Alternatives considered

- **并入 `audit`，做成子旗标**（如 `ponygo audit --observe` 或 `audit --dims tracing,logs`）：否决。
  三条硬冲突：① `audit` 的退出码表达"四问治理打分"，observe 的退出码表达"是否达到目标级 + 证据不足(3)"，
  一个进程码承载两套语义，CI 无法分流处置（rc=3 在 audit 侧是"spec 未执行"，在 observe 侧是
  "skip 无法证明"，混装后都变成"随便一种不够格"）；② `audit` 是**只读体检**，而 `observe init` 是
  仓库**写命令**——写与读不共用一条命令面是既有边界；③ 维度是可选的横切面，把它塞进每条实例都会跑的
  `audit` 会给不用可观测性的项目增加一个恒真的判定段（假门禁的温床）。
- **做成独立的第七核心命令**（与六条平级、自带一套打分）：否决。六条命令面是拍板不变量
  （`2026-08-30-six-command-surface.md`），其价值就在于**数量固定**——加一条命令意味着 usage、
  README 三处口径、测试矩阵、兼容性承诺全部同步扩面。更实际的一点：observe 自己就有五个位置子命令
  （一写 + 三只读 + 一探针），平铺成顶层命令会把"六条"变成十一条；命名空间化让命令面计数不变，同时
  保证 `ponygo probe` 这类漏写命名空间的调用被当未知参数拒绝（而不是静默跑成探针）。
- **把维度映射数据块放进 skill 的 `references/`**：否决。skill 不在本仓 git 下（改动无法随 git 审阅）、
  重装或升级会覆盖目录（框架数据被静默回退）、且单文件安装模型只允许依赖 skill 的**脚本契约**
  （退出码），不允许依赖它的数据文件格式。
- **让 `audit --run-specs` 承载 `audit-diff`（变更级门禁）**：否决。`--run-specs` 的语义是"执行本仓
  `gates/*.spec.sh` 负样本自检"，与"变更级 diff 门禁"在目标（自检 vs 变更拦截）、输入（仓库自带
  spec vs 基线 diff）、退出码语义上全不同；混进去会让 `audit` 的 rc 同时表达两种越界。
- **按 `kind` 自动推断"这一维适不适用"**：否决。同 kind 的项目在"有没有跨进程调用"上可以完全不同；
  自动推断会把"该有却没有"这一最该被发现的情形直接写成 `applicable: false` 掩盖掉。`--dims` 由人给出，
  `kind` 只进声明供 review。

## Consequences

- 可观测性接入第一次有了非零退出的判据线：`ponygo observe audit --level ob1 --strict --json` 可进 CI，
  ob0/ob1/ob2 三级各有明确的"谁判"与退出码语义，"判不了"用 `3` 单独表达。
- 命令面计数不变（六条），但多了一个命名空间维度；`ponygo status` 会把 observe skill 的在场情况并入
  环境行（缺项显示 `✗`，见 `implemented/process/2026-11-07-evidence-coverage.md`）。
- **已知局限（诚实登记，均是"机器到不了的地方"）**：ob1 只判"声明与巡检一致"，四维全 `false` 的声明
  照样 PASS（识别谎言是非机械项，属 review）；ob2 的挂载是**形状判据**（grep 载体、已排除纯注释行，
  不解析 AST，也不验证钩子真被执行），真执行证据是 `audit-diff` 本身；`kind` 是单值，多形态靠附加声明
  `docs/observability.d/*.yaml`（主声明定 ob 级，附加声明只扩覆盖，不一致进 backlog，`--strict` 才影响
  退出码）。
- **本条的记录归属变更**：本决策原只存在于框架轨道 `revisions/accepted/2026-10-25-observe-dimension.md`
  （含 K1–K11 的完整局限清单与退出码语义附录，仍可查）；该轨道冻结后，工程决策树侧以本条为入口。
