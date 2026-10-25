# ponygo

> 项目工程化治理的**生成器 + 演进控制器**：帮你长出并持续维护一套治理体系，而非替你做管理。
> `pony` 取品牌义，`go` 取"治理体系的开跑 / 推进"义——合写为元框架名 **ponygo**。

---

## 1. ponygo 是什么

一句话定位：**ponygo 是一套"生成 + 演进"你项目治理体系的脚手架**——它落地带领项目走完从"播种"到"领域定制"的成熟度阶梯，并随时给你一份可被命令检验的现状报告；它**不替你决策、不替你评审、不替你写那些必须由人做的语义判断**。

必须区分的三样东西（三者是"为什么 vs 怎么做 vs 具体某家"的关系）：

| 名称 | 是什么 | 定位 |
|---|---|---|
| `docs/methodology.md` | 原理层：这套方法论的**设计依据**（源自 deepseek-harness 的工程化沉淀） | 讲"为什么"——为什么约定要可验证（P2）、为什么靠自觉会衰减 |
| `ponygo`（本仓库 + CLI） | 机制层：把原理固化成**可实例化的脚手架 + 命令面** | 讲"怎么做"——`init`/`audit`/`status`/`upgrade`/`sync`/`retire` 六条命令 + `observe` 维度 |
| 某个具体实例（如 deepseek-harness） | 一个真实项目的 `.meta/` 治理根 | 讲"某家是怎么落地的"——一份实证案例，非模板 |

**阅读顺序**：先本文档（拿到命令面与路径），再按需回读 `docs/methodology.md`（理解每一条命令背后的原理）。

---

## 2. 三句话讲清它解决的问题

- **为什么治理靠自觉会衰减？** 约定（"必须 / 禁止"）的生命力等于它的**可验证性**（verifiability）。靠人自觉遵守的约定，在规模与人员变化下必然衰减——凡机械可查的承诺，必须配一条非零退出（non-zero exit）的命令去锁住它；凡语义判断，配校准样例；凡不可判，诚实标注"靠自觉"。
- **为什么需要一个可实例化的脚手架，而非一篇文档？** 一篇文档只描述"好治理长什么样"，读完仍要照抄、仍要靠人记得去照做。脚手架直接**生成骨架、生成门禁、生成报告命令**——"照做"不需要读文档。
- **为什么项目要"转起来"而非"转完美"？** 停止线原则：以**规模值不值当**为准，宁可粗糙、不可缺席。多记成本一段文字，漏记成本永久丢失。

---

## 3. 安装与快速开始（六条核心命令 + observe）

### 3.1 安装（一键安装 / 单文件零依赖）

`ponygo` 是纯 bash 实现的治理演进脚手架，无外部包依赖。任选以下一种方式安装：

**方式 A：一行命令远端安装（快速体验，无完整性校验；生产环境请用下方"钉版本 + 校验和"块）**

```bash
curl -fsSL https://raw.githubusercontent.com/lanhui100/ponygo/main/install.sh | bash
```

> 注：上行为**快速体验路径**——`curl|bash` 不验证内容，仅适合尝鲜；生产环境务必用下面
> 钉版本 + 校验和的块（fail-closed：校验和取不到即拒绝安装）。

生产环境建议钉版本 + 校验和（防"curl|bash 拉的是未知内容"；**fail-closed**：校验和取不到时**拒绝安装**，绝不静默跳过）：

```bash
# 1) 取该版本的校验和（发布物 = Release 附件 ponygo.sha256，内容为裸哈希；
#    未发布时按下方口径本地自算。awk 剥掉文件名列，与 install.sh 的整串比对口径对齐）
#    fail-closed 守卫：SHA 为空（附件 404 / 下载失败）→ 立即退出，不安装
set -o pipefail
SHA=$(curl -fsSL https://github.com/lanhui100/ponygo/releases/download/v2.6.0/ponygo.sha256 | awk '{print $1}')
[ -n "$SHA" ] || { echo "无法获取校验和（未发布或网络失败），拒绝安装。" >&2; exit 1; }
# 2) 钉版本 + 校验和安装（installer 与载荷同钉 tag：bootstrap 行取 tag 化 install.sh，不再浮动 main）
curl -fsSL https://raw.githubusercontent.com/lanhui100/ponygo/v2.6.0/install.sh | \
  PONYGO_VERSION=v2.6.0 PONYGO_SHA256="$SHA" bash
```

校验和的生成口径（维护者）：`git checkout v2.6.0 && sha256sum ponygo | awk '{print $1}' > ponygo.sha256`，
随 Release 附件发布。`ponygo` 在仓库中以 LF 存储（`.gitattributes: eol=lf`），故 raw 下载与本地自算口径一致；
`install.sh` 不设 `PONYGO_VERSION` 时仍取 main（兼容分支，供未发布新版本时使用）。
**注意：校验和只保 `ponygo` 本体，不保 `install.sh` 自身**——bootstrap 行钉 tag 后 installer 与载荷同源，
但首次 curl 的那段仍是信任链起点（可自审后落盘再执行）。
未发布状态诚实标注：tag 未推 / 附件缺失时，上方命令块的 Releases 链接会 404——此时按下方"本地自算"口径
手动生成校验和并安装，不要把 404 的链接当可用路径。

**方式 B：源码目录一键安装（clone 本仓库后）**

```bash
./install.sh
```

**方式 C：保留 git 血缘手动挂载（跟随升级靠 `git fetch && git merge`；`ponygo upgrade` 首版只打印升级纪律、不做合并）**

```bash
git clone https://github.com/lanhui100/ponygo.git && export PATH="$PWD/ponygo:$PATH"
```

平台要求：Git Bash（Windows）/ Linux / macOS（GNU 用户态，见 §6.2）。
安装后验证：`ponygo --help`

### 3.2 命令面（六条核心命令 + observe）

```bash
ponygo init      # 新项目：在仓库根生成 .agents/ + .meta/ 治理骨架 + meta.yaml（level: 0）
ponygo audit     # 旧项目改造（或随时体检）：按自适应审计打分，输出缺口与最小改进动作；有治理根时内嵌级自洽验证，判据不符 exit 1。加 --run-specs 执行 gates/*.spec.sh 负样本自检（opt-in，默认不执行仓库脚本）
ponygo status    # 查看当前成熟度级（L0-L5）与骨架完整性，并对声明级（L0-L2）判据逐项机械验证，不符即非零退出
ponygo upgrade   # 跟随框架升级：把本仓库新版 ponygo 的命令面/判据同步进已有治理根
ponygo sync      # 把 constitution 投影到根 AGENTS.md / CLAUDE.md（生成物，勿手编；槽位未填的模板态投影初始引导 bootstrap）
ponygo retire    # 退级 / 整体退场（停止线执行器）：--level <N|off>
  ponygo observe  status|init|audit|upgrade  可观测性治理维度（ob0/ob1/ob2 判定；详见 'ponygo observe --help'）
```

`ponygo` 是单文件 CLI（shell、零依赖）。核心命令面固定为上述六条；`observe` 是独立的一组子命令
（四级判据、skill 定位与 CI 用法见 §4.4）。

---

## 4. 它如何工作

### 4.1 目录骨架（双根：`.agents/` 运行时资产 + `.meta/` 机器态真源）

**分家原则**：`.agents/` 承载 AI agent **运行时读写**的治理资产（必须在工具发现路径上）；`.meta/` 承载治理的**机器态与真源**（constitution 经投影消费、gates 由钩子/CI 消费、meta.yaml 是状态文件）。另有根目录 `AGENTS.md` / `CLAUDE.md` 常载投影面与 `.rgignore` 归档搜索隔离。

```
.agents/
├── notes/                     # 决策记录（ADR）：路径即标签，文件夹即 lifecycle × class
│   ├── README.md              #    路径规范 + 格式契约 + 触发规则（唯一真源）
│   ├── proposed/
│   ├── implemented/
│   ├── rejected/
│   └── archived/              # .rgignore 隔离：防陈旧事实挤掉当前搜索结果
└── skills/                    # 流程资产：高频+高判断力流程的可复用技能（预置 write-adr 自动路由 +
                                #   governance-review 用户点名调用，其余按 Rule of three 生长）
    ├── README.md              #    SKILL.md 五要素契约
    ├── write-adr/SKILL.md     #    框架交付的自动路由技能（写 ADR）
    └── governance-review/SKILL.md  # 框架交付的用户点名技能（全面治理审查）
.meta/
├── meta.yaml                  # 合法键仅三个：level（成熟度级，整数 0-5，如 level: 2）、ai-surface、docs-tier（on|off，L2 判据 2.5 的启用声明）；版本由 git 派生，组件清单由目录存在性充当
├── constitution/              # 宪法：语义规范（"什么是好的"），供投影到 AGENTS.md / CLAUDE.md
│   └── constitution.md        #    模板态（槽位未填）时 sync 投影初始引导 bootstrap：AI agent 进场即有指引，
│                              #    由 agent 完成填槽/重投影/首篇 ADR；填槽后重跑 sync，引导自动被常载命约替换
├── gates/                     # 门禁：把承诺转成非零退出命令（每门配负样本 spec）
└── docs-tier/                 # 文档分层：按 tier 分类法给每个事实安一个家
```

**关键约定**（其它文件据此派生命令名与路径）：

- `meta.yaml` 仅 `level` / `ai-surface` / `docs-tier` 三个合法键 + 注释（其它键是规格违例）；`docs-tier: on|off` 是 L2 判据 2.5 的**启用声明**（未声明=SKIP+WARN；`off`=显式 opt-out；目录存在不等于已激活，故不是冗余副本）；**版本由 git 派生，组件清单由 `.meta/` + `.agents/` 目录存在性充当**——不冗余声明能被机械推导的东西。
- 决策文件路径：`.agents/notes/{lifecycle}/{class}/yyyy-mm-dd-topic-title.md`，其中
  - `lifecycle ∈ {proposed, implemented, rejected, archived}`
  - `class ∈ {feature, bug-fix, simplification, architecture, process, testing}`（领域扩展：`notes/classes.local` 每行追加一个 class，见 `.agents/notes/README.md`）
- 文件夹即标签：lifecycle/class 编码进路径，文件内容里无需重复声明，二者永不漂移。

### 4.2 成熟度阶梯（L0–L5，v2.0：文档治理前置）

| 级 | 名称 | 判据类型 |
|---|---|---|
| L0 | 播种 + 最小文档家 | 真判据（机械可判） |
| L1 | 决策入册 + 文档有家 | 真判据（机械可判） |
| L2 | 承诺可验 + 文档分层 | 真判据（机械可判，分层激活形状） |
| L3 | 流程资产 | 目标画像（靠 review） |
| L4 | 负空间 | 目标画像（靠 review） |
| L5 | 领域定制 | 目标画像（靠 review） |

> L0–L2 的判据以 `maturity-ladder.md` §5 的真值表为准，`ponygo status` 已对声明级（L0-L2）的判据逐项机械验证（v1.1 起；v2.0 起文档判据 0.5/1.9/2.5 并入），判据不符时非零退出。L3–L5 是"目标画像"，靠 review 校准。

### 4.3 自适应审计（首版两档）

`ponygo audit` 用四问记分卡兜底 + 内置精简布尔项打分 + 自适应深度选择器选档（`audit/` 下的细目库为全量参照）：

| 档 | 适用规模 | 细目层级 |
|---|---|---|
| S（Small） | 起步 / 小项目 | CLI 内嵌精简子集 10 项（判"有没有"） |
| M（Medium） | 有治理基础但欠体系 | + CLI 内嵌追加 4 项（共 14 项，判"对不对"） |

> 上方是 **CLI 内嵌的精简子集**（其"10/14 项"与下文 checklist 的"骨架 8 / 机制 18 / 精微 8"是两套计数，勿混用；CLI 内嵌是 checklist 子集故免改）；全量细目见 `audit/checklist.md`（骨架 8 / 机制 18 / 精微 8 标 future，为权威真源——CLI 与文档口径不一致时以 checklist 为准）。四问记分卡：决策记在哪 / 承诺怎么强制 / 重复劳动怎么复用 / 过时怎么退场。

> **只读边界**：`status` / `audit` 默认**不执行**仓库里的任何脚本（对陌生遗留仓库执行脚本 = 任意代码执行）。
> 判据 2.3 的**执行侧**（跑 `gates/*.spec.sh` 并断言 exit 0）由显式开关承担：`ponygo audit --run-specs`，
> 或在 CI / pre-push 层逐个跑 `bash .meta/gates/<name>.spec.sh`（**勿写 `*.spec.sh` 通配**——
> shell 只会把第一个匹配当命令、其余沦为参数，静默漏跑）。`--dry-run` 下一律跳过。

### 4.4 可观测性维度（observe）

`ponygo observe` 把"可观测性接入"变成一个可判定的维度：**判据在外部 skill，ponygo 只做骨架扫描与退出码聚合**。
四级里 ob0/ob1/ob2 参与判定，ob3 是目标画像（advisory）。

| 级 | 判据 | 未达时的 gap |
|---|---|---|
| ob0 | `docs/observability.yaml\|yml` 在场，且**非注释行**无占位符 | `declaration_missing` / `placeholder_present` |
| ob1 | 声明与现实一致：skill 的 `check-declaration.sh` 退出码 0 | `declaration_inconsistent`（rc=2）/ `evidence_insufficient`（rc=3）/ `tool_error`（rc=4） |
| ob2 | 声明有真实收口点 + 挂载载体里真有 `audit-diff` 调用 + 其退出码 0 | `enforcement_points_missing` / `mount_missing` / `diff_warn`（rc=1）/ `enforcement_violation`（rc=2） |

四条子命令（与 `ponygo observe --help` 逐字一致）：

```
  ponygo observe status                           静态报告（不判定）：声明在场/占位残留/skill 在场与版本；只读，exit 0
  ponygo observe init   --kind <k> [--service <s>] [--dims a,b] [--anchor-<dim> <path>]
                        [--reason-<dim> <text>] [--force] [--dry-run] [--yes]
                                                  落地四维归属声明（唯一写命令；已存在声明需 --force）
  ponygo observe audit  [--level ob0|ob1|ob2] [--base <rev>] [--json]
                                                  判定是否达到目标级（缺口仅作 backlog，不决定退出码）
  ponygo observe upgrade [--check]                与技能契约的版本兼容门（CI 用 --check）
```

- **退出码**：`0` 已达目标级（`gaps` 可非空——缺口是距下一级的 backlog）/ `1` 未达目标级（含 `below_target`）/ `2` 工具或输入错误（**不是"未达标"**）/
  `3` 证据不可得。`2` 与 `3` 都不是通过，见 `checklists/observe-audit.md`。
- **判定权不下沉**：ponygo 只做 ob0 的文件/占位扫描；ob1/ob2 调用 skill 的
  `check-declaration.sh` / `audit-diff.sh` 并聚合退出码，判据口径在
  `<skill>/references/declaration-rubric.md`。维度映射（kind 枚举、挂载载体清单、版本下限）以数据块形式
  嵌在 `ponygo` 单文件里——skill 不在 git 下、重装即丢，故不把承接面放在 skill 一侧。
- **skill 定位**：`--skill-dir <dir>` > 环境变量 `PONYGO_SKILL_DIR` > `~/.agents/skills/observability-onboarding`；
  版本取 `<skill>/references/contract.json` 的 `contract_version`，兼容门是 `ponygo observe upgrade --check`。
  目录或契约文件缺失 ⇒ `audit`/`upgrade` 直接 exit 2（fail-closed，不降级判定）；`status` 不因此失败。
- **ob3 只作 advisory**：报告末尾固定三条待办（采样策略 / `gen_ai.*` 成本归因 / SLI 告警组），
  `--level ob3` 被显式拒绝——它是成本与 SLO 的目标画像，不参与判定。
- **CI 用法**：`ponygo observe audit --level ob1 --json`（stdout 只有一行固定词表 JSON，rc 决定门禁红绿）；
  变更级门禁用 skill 的 `audit-diff.sh` 并以"变更起点"作 `--base`（别用 `HEAD`），ob2 才真的在拦。
- **已知局限**（诚实标注）：
  - ob1 只判"声明与巡检一致"；四维全 `false` 的声明同样 PASS——识别谎言是非机械项（K4）。
  - ob2 的挂载证据是形状判据（grep 载体里出现 `audit-diff`），真执行证据是 `audit-diff` 本身（K7）。

> 清单：落地看 `checklists/observe-init.md`，审计与门禁看 `checklists/observe-audit.md`；
> 决策背景与被否选项见 `revisions/proposed/2026-10-25-observe-dimension.md`。

---

## 5. 与旧项目的关系

`ponygo` CLI 进入任意项目时**自判三场景**，一条命令即可：

| 场景 | 判定信号 | 入口命令 |
|---|---|---|
| 新项目 | 无 `.meta/`、无既有治理痕迹 | `ponygo init` |
| 旧项目改造 | 无 `.meta/`，但已有部分治理资产（决策记录 / 门禁散落） | `ponygo audit`（先体检，再决定迁移） |
| 已有治理 | 已有 `.meta/` | `ponygo status` / `ponygo upgrade` |

CLI 从不假设项目是空仓；它对"已有治理"与"零治理但历史厚重"两种情况都只做**增量**，不要求推倒重来。
对第二种场景，`init` 也会先探测既有治理形态（`docs/adr/`、CONTRIBUTING.md、CODEOWNERS、pre-commit/lefthook、CI 配置等）并提示"先 `audit` 再决定迁移"——探测只是提示，不是拦截；确认后仍可注入（你是裁"值不值"的人，机器只裁"有没有"）。

---

## 6. 停止线与边界

### 6.1 停止线

- **规模太小不值当就别用**：单文件脚本、一次性原型、无持续维护者的小工具——不建 `.meta/`。
- **该停就停**：成熟度阶梯**不是终点冲刺**，L0–L2 转起来后，L3+ 按需推进；飞轮的价值在每一圈"转起来"，不在"转得完美"。
- **双向可退**：涨过头就升、跌破阈值就退。退级用 `ponygo retire --level <N|off>`——`off` 整体退场到"纯 L0 长驻模式"（`ai-surface: off`，不再生成 AI 投影）。删除是独立工程（P9），退级须录一条 decision。

### 6.2 本文不覆盖的维度（各一句话）

- **依赖 / 供应链安全**：审计（supply-chain audit）、SBOM（软件物料清单）、许可证合规、锁文件校验——另配 `npm audit` / `osv-scanner` 等专业工具，本框架门禁语料外。
- **可观测性**：遥测 / 日志 / 告警 / oncall 的**基础设施与选型**属运维域，独立成体系；本框架只承载"接入到哪一级"的可达判定（`ponygo observe`，见 §4.4）与变更级门禁挂载，不替你做埋点设计与容量规划。
- **安全与密钥管理**：secret 扫描、权限最小化——属独立安全规范。
- **发布与版本管理**：语义化版本与发布通道的专业治理——不在本框架语料内（版本派生仅由 git 承担）。
- **开发环境可复现**：devcontainer / Nix——本框架不替它虚构，不覆盖。
- **API 契约治理**：跨大版本迁移的契约治理（OpenAPI / protobuf 演进）——本框架仅承载部分不变量，未展开。
- **非 GNU 平台**：CLI 判据部分依赖 GNU 语义（`find -printf`、`sed -i`、`date -d`），承诺平台为 Windows Git Bash / GNU 用户态；BSD/macOS 裸环境不承诺（见 `ponygo` 头注）。

### 6.3 合规免责（重要）

**ponygo 是工程化治理脚手架，爬满 L5 不构成任何监管合规背书**（FDA、ISO 13485、ISO 26262、SOC2、PIPL 等），不替代贵组织的质控与审计流程。强监管项目请另行接入专用合规框架——`ponygo audit` 检测到 `compliance/`、`traceability/` 目录时也会输出此免责。

---

## 7. 仓库文件索引

| 文件 / 目录 | 是什么 | 给谁看 |
|---|---|---|
| `README.md` | 门面 + 使用总纲：命令面、路径、阶梯、边界 | 所有人；第一入口 |
| `ponygo` | 单文件 CLI（shell、零依赖），六条核心命令 + `observe` 维度 | 使用者；执行入口 |
| `tests/run.sh` | CLI 自测（纯 bash、零依赖、36 场景，含 `observe` 的 s33~s36），`bash tests/run.sh` 全绿为准 | 维护者；回归门禁 |
| `.github/workflows/ci.yml` | 回归门禁挂载：ubuntu + windows Git Bash 双平台跑 tests/run.sh + 聚合门 | 维护者；分支保护依赖 |
| `.github/workflows/release.yml` | 发布校验和链：tag-push 触发，生成并发布 ponygo.sha256（裸哈希 + CRLF 断言 + 最小权限） | 维护者；发布动作 |
| `docs/methodology.md` | 原理层：方法论设计依据（源自 deepseek-harness） | 想懂"为什么"的人；机制层的理论源头 |
| `.meta/` + `.agents/` | 治理根骨架（双根）：.meta/ = constitution / gates / docs-tier / meta.yaml；.agents/ = notes / skills | 实例化产物；由 `ponygo init` 生成进用户项目 |
| `maturity-ladder.md` | 成熟度阶梯定义（L0–L5 逐档判据） | `ponygo status` 与 review 的判定来源 |
| `audit/` | 四问记分卡 + 分层细目库 + 自适应深度选择器 | `ponygo audit` 的执行依据 |
| `audit/checklist.md` | 分层细目（骨架 / 机制 / 精微三层条目） | 审计打分时的逐项参照 |
| `checklists/` | 四入口清单：init（冷启动）/ audit（改造）/ observe-init（维度落地）/ observe-audit（维度审计） | 使用者；落地动作指引 |
| `revisions/` | 框架自身演进记录：proposed / accepted | 维护者；框架"吃自己狗粮"的 ADR |
| `LICENSE` | MIT 许可证 | 分发与二次使用依据 |