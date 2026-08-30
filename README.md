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
| `ponygo`（本仓库 + CLI） | 机制层：把原理固化成**可实例化的脚手架 + 命令面** | 讲"怎么做"——`init`/`audit`/`status`/`upgrade`/`sync`/`retire` 六条命令 |
| 某个具体实例（如 deepseek-harness） | 一个真实项目的 `.meta/` 治理根 | 讲"某家是怎么落地的"——一份实证案例，非模板 |

**阅读顺序**：先本文档（拿到命令面与路径），再按需回读 `docs/methodology.md`（理解每一条命令背后的原理）。

---

## 2. 三句话讲清它解决的问题

- **为什么治理靠自觉会衰减？** 约定（"必须 / 禁止"）的生命力等于它的**可验证性**（verifiability）。靠人自觉遵守的约定，在规模与人员变化下必然衰减——凡机械可查的承诺，必须配一条非零退出（non-zero exit）的命令去锁住它；凡语义判断，配校准样例；凡不可判，诚实标注"靠自觉"。
- **为什么需要一个可实例化的脚手架，而非一篇文档？** 一篇文档只描述"好治理长什么样"，读完仍要照抄、仍要靠人记得去照做。脚手架直接**生成骨架、生成门禁、生成报告命令**——"照做"不需要读文档。
- **为什么项目要"转起来"而非"转完美"？** 停止线原则：以**规模值不值当**为准，宁可粗糙、不可缺席。多记成本一段文字，漏记成本永久丢失。

---

## 3. 快速开始（六条命令）

```bash
ponygo init      # 新项目：在仓库根生成 .meta/ 治理骨架 + meta.yaml（level: 0）
ponygo audit     # 旧项目改造（或随时体检）：按自适应审计打分，输出缺口与最小改进动作
ponygo status    # 查看当前成熟度级（L0-L6）与骨架完整性，并对声明级（L0-L2）判据逐项机械验证，不符即非零退出
ponygo upgrade   # 跟随框架升级：把本仓库新版 ponygo 的命令面/判据同步进已有治理根
ponygo sync      # 把 constitution 投影到根 AGENTS.md / CLAUDE.md（生成物，勿手编）
ponygo retire    # 退级 / 整体退场（停止线执行器）：--level <N|off>
```

`ponygo` 是单文件 CLI（shell、零依赖）。命令面固定为上述六条。

---

## 4. 它如何工作

### 4.1 目录骨架（治理根 `.meta/`）

```
.meta/
├── meta.yaml                  # 合法键仅两个：level（成熟度级，整数 0-6，如 level: 2）与 ai-surface；版本由 git 派生，组件清单由目录存在性充当
├── constitution/              # 宪法：语义规范（"什么是好的"），供投影到 AGENTS.md / CLAUDE.md
│   └── constitution.md
├── decisions/                 # 决策记录（ADR）：路径即标签，文件夹即 lifecycle × class
│   ├── proposed/
│   ├── implemented/
│   ├── rejected/
│   └── archived/
├── gates/                     # 门禁：把承诺转成非零退出命令（每门配负样本 spec）
├── skills/                    # 流程资产：高频+高判断力流程的可复用技能（触发式 description + 校准样例）
└── docs-tier/                 # 文档分层：按 tier 分类法给每个事实安一个家
```

**关键约定**（其它文件据此派生命令名与路径）：

- `meta.yaml` 仅 `level` 与 `ai-surface` 两个合法键 + 注释（其它键是规格违例）；**版本由 git 派生，组件清单由 `.meta/` 目录存在性充当**——不冗余声明能被机械推导的东西。
- 决策文件路径：`decisions/{lifecycle}/{class}/yyyy-mm-dd-topic-title.md`，其中
  - `lifecycle ∈ {proposed, implemented, rejected, archived}`
  - `class ∈ {feature, bug-fix, simplification, architecture, process, testing}`
- 文件夹即标签：lifecycle/class 编码进路径，文件内容里无需重复声明，二者永不漂移。

### 4.2 成熟度阶梯（L0–L6）

| 级 | 名称 | 判据类型 |
|---|---|---|
| L0 | 播种 | 真判据（机械可判） |
| L1 | 决策入册 | 真判据（机械可判） |
| L2 | 承诺可验 | 真判据（机械可判） |
| L3 | 文档分层 | 目标画像（靠 review） |
| L4 | 流程资产 | 目标画像（靠 review） |
| L5 | 负空间 | 目标画像（靠 review） |
| L6 | 领域定制 | 目标画像（靠 review） |

> L0–L2 的判据以 `maturity-ladder.md` §5 的真值表为准，`ponygo status` 已对声明级（L0-L2）的判据逐项机械验证（v1.1 起），判据不符时非零退出。L3–L6 是"目标画像"，靠 review 校准。

### 4.3 自适应审计（首版两档）

`ponygo audit` 用四问记分卡兜底 + 内置精简布尔项打分 + 自适应深度选择器选档（`audit/` 下的细目库为全量参照）：

| 档 | 适用规模 | 细目层级 |
|---|---|---|
| S（Small） | 起步 / 小项目 | CLI 内嵌精简子集 10 项（判"有没有"） |
| M（Medium） | 有治理基础但欠体系 | + CLI 内嵌追加 4 项（共 14 项，判"对不对"） |

> 上方是 **CLI 内嵌的精简子集**（其"10/14 项"与下文 checklist 的"骨架 8 / 机制 15 / 精微 8"是两套计数，勿混用）；全量细目见 `audit/checklist.md`（骨架 8 / 机制 15 / 精微 8 标 future，为权威真源——CLI 与文档口径不一致时以 checklist 为准）。四问记分卡：决策记在哪 / 承诺怎么强制 / 重复劳动怎么复用 / 过时怎么退场。

---

## 5. 与旧项目的关系

`ponygo` CLI 进入任意项目时**自判三场景**，一条命令即可：

| 场景 | 判定信号 | 入口命令 |
|---|---|---|
| 新项目 | 无 `.meta/`、无既有治理痕迹 | `ponygo init` |
| 旧项目改造 | 无 `.meta/`，但已有部分治理资产（决策记录 / 门禁散落） | `ponygo audit`（先体检，再决定迁移） |
| 已有治理 | 已有 `.meta/` | `ponygo status` / `ponygo upgrade` |

CLI 从不假设项目是空仓；它对"已有治理"与"零治理但历史厚重"两种情况都只做**增量**，不要求推倒重来。

---

## 6. 停止线与边界

### 6.1 停止线

- **规模太小不值当就别用**：单文件脚本、一次性原型、无持续维护者的小工具——不建 `.meta/`。
- **该停就停**：成熟度阶梯**不是终点冲刺**，L0–L2 转起来后，L3+ 按需推进；飞轮的价值在每一圈"转起来"，不在"转得完美"。
- **双向可退**：涨过头就升、跌破阈值就退。退级用 `ponygo retire --level <N|off>`——`off` 整体退场到"纯 L0 长驻模式"（`ai-surface: off`，不再生成 AI 投影）。删除是独立工程（P9），退级须录一条 decision。

### 6.2 本文不覆盖的维度（各一句话）

- **依赖 / 供应链安全**：审计（supply-chain audit）、SBOM（软件物料清单）、许可证合规、锁文件校验——另配 `npm audit` / `osv-scanner` 等专业工具，本框架门禁语料外。
- **可观测性**：遥测 / 日志 / 告警 / oncall——属运维域，独立成体系。
- **安全与密钥管理**：secret 扫描、权限最小化——属独立安全规范。
- **发布与版本管理**：语义化版本与发布通道的专业治理——不在本框架语料内（版本派生仅由 git 承担）。
- **开发环境可复现**：devcontainer / Nix——本框架不替它虚构，不覆盖。
- **API 契约治理**：跨大版本迁移的契约治理（OpenAPI / protobuf 演进）——本框架仅承载部分不变量，未展开。
- **非 GNU 平台**：CLI 判据部分依赖 GNU 语义（`find -printf`、`sed -i`、`date -d`），承诺平台为 Windows Git Bash / GNU 用户态；BSD/macOS 裸环境不承诺（见 `ponygo` 头注）。

### 6.3 合规免责（重要）

**ponygo 是工程化治理脚手架，爬满 L6 不构成任何监管合规背书**（FDA、ISO 13485、ISO 26262、SOC2、PIPL 等），不替代贵组织的质控与审计流程。强监管项目请另行接入专用合规框架——`ponygo audit` 检测到 `compliance/`、`traceability/` 目录时也会输出此免责。

---

## 7. 仓库文件索引

| 文件 / 目录 | 是什么 | 给谁看 |
|---|---|---|
| `README.md` | 门面 + 使用总纲：命令面、路径、阶梯、边界 | 所有人；第一入口 |
| `ponygo` | 单文件 CLI（shell、零依赖），六条命令 | 使用者；执行入口 |
| `tests/run.sh` | CLI 自测（纯 bash、零依赖、18+ 场景），`bash tests/run.sh` 全绿为准 | 维护者；回归门禁 |
| `docs/methodology.md` | 原理层：方法论设计依据（源自 deepseek-harness） | 想懂"为什么"的人；机制层的理论源头 |
| `.meta/` | 治理根骨架：constitution / decisions / gates / skills / docs-tier / meta.yaml | 实例化产物；由 `ponygo init` 生成进用户项目 |
| `maturity-ladder.md` | 成熟度阶梯定义（L0–L6 逐档判据） | `ponygo status` 与 review 的判定来源 |
| `audit/` | 四问记分卡 + 分层细目库 + 自适应深度选择器 | `ponygo audit` 的执行依据 |
| `audit/checklist.md` | 分层细目（骨架 / 机制 / 精微三层条目） | 审计打分时的逐项参照 |
| `checklists/` | 双入口清单：init（冷启动）+ audit（改造） | 使用者；落地动作指引 |
| `revisions/` | 框架自身演进记录：proposed / accepted | 维护者；框架"吃自己狗粮"的 ADR |