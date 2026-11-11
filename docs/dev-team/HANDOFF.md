# HANDOFF —— ponygo 元框架任务交接（v0 收口快照）

> **tier：工程过程记录（不做当前契约）。** 本文是 v0 收口时的换窗口交接快照：保留当时的推进顺序、
> 已拍板决策与踩坑记录，供后来者理解"为什么长成现在这样"。**路径、档位与计数口径已按现值校正**，
> 校正映射见 §六。
> 当前契约的家不在本文：人读契约 = 根 `README.md`；判据语义 = `maturity-ladder.md`；
> 常载命约 = `.meta/constitution/constitution.md`（经 `ponygo sync` 投影到根 `AGENTS.md` / `CLAUDE.md`）。
> 最近校正：2026-11-11（P1-5 归家 + 失效口径对齐）。

---

## 一、任务一句话目标

构建一个**与具体项目隔离、通用、可复用**的「软件项目工程化治理元框架」——**ponygo**：
治理体系的"生成器 + 演进控制器"，回答"一个项目如何长出并持续维护自己的治理体系"，
而不是"好项目怎么管理"（那是原理层 `docs/methodology.md` 的事）。

品牌：pony（马）。命令名 **ponygo**（pony + go，取"治理体系的开跑/推进"义）。

---

## 二、已拍板的决策（勿再重议）

| 决策点 | 定论 |
|---|---|
| 载体 | 独立 git 仓库（模板仓库），单文件 CLI 零依赖可跑 |
| CLI 形态 | 单文件 shell，零依赖（bash），跨平台靠 Git Bash |
| CLI 命令面 | 六命令：`init` / `audit` / `status` / `upgrade` / `sync` / `retire`（另有 `observe` 维度子命令） |
| 治理根 | **双根**：`.meta/` = constitution + gates + docs-tier + adaptation + meta.yaml；`.agents/` = notes + skills（AI 运行时资产须在工具发现路径上） |
| 决策记录双轴 | `.agents/notes/{lifecycle}/{class}/yyyy-mm-dd-topic-title.md`；lifecycle 四态；class 六类封闭集合 |
| meta.yaml | **三键**：`level`（当前档位，整数 `0`…`5`）/ `ai-surface` / `docs-tier`；版本由 git 派生、组件由目录存在性派生 |
| 成熟度阶梯 | L0-L5；**L0-L2 真判据（机械），L3-L5 目标画像（靠 review）**；菜单式非线性、双向可退 |
| 审计 | 四问分量表 + 分层细目库 + 自适应深度选择器（S/M 两档）；细目条目以 `audit/checklist.md` 为准 |
| AI 适配 | 可开关插件——声明载体 `.meta/meta.yaml` 的 `ai-surface: on\|off`（默认关），constitution 投影到根 `AGENTS.md` / `CLAUDE.md` 的哨兵块 |
| 升级合并 | **降级 v+2**：`upgrade apply` 只刷新宇宙内骨架，逐文件语义合并仍靠人 |
| 自我迭代 | 实例 `meta.yaml`(level) / 框架 `revisions/`(proposed→accepted) / 版本号，三级分离 |

---

## 三、已完成进度

### 构建

首版骨架（CLI + 阶梯 + 审计细目 + 宪法 + 文档标准）已落地并随仓库演进。
**文件清单与场景数的真源是根 `README.md` §7 与 `bash tests/run.sh` 自身枚举**——本文不复写，
复写即第二份副本（必漂移）。

### 三轮对抗审核（完成 + 修复）

| 路 | 视角 | 结果 |
|---|---|---|
| A 逻辑自洽 | 跨文件咬合 | 14 条发现 → 修 8 类（命令面数量、level 取值统一、sync 守卫、项数虚高等） |
| B 通用性 | 换场景碎不碎 | 6 崩点 → 修 6（`retire` 退级、`ai-surface` 开关、合规免责、替代物认可、CI/负样本跨栈） |
| C 可实现性 | 承诺能否兑现 | 5 项 Top → 修 5（**致命**投影守卫 bug、README 六命令、口径统一、L0-L2 承诺收敛、`retire` 联动） |

### 收口时已修复并回归验证的关键 bug

- ✅ 投影守卫：constitution 含 `TODO:` 时按模板态投影 bootstrap 引导，不把模板当命约发出去
- ✅ `read_level` 剥 `L` 前缀（`level: L2` 不报 `LL2`）
- ✅ `retire --level N|off` 退级 + `ai-surface` 联动
- ✅ `audit` 输出含「替代物认可」+「合规免责」提示
- ✅ CI 探测跨平台（GitHub / GitLab / Bitbucket / Azure / Drone / Jenkins）
- ✅ 负样本 spec 探测语言无关（`*_test.go/rs/py` / `*.spec.ts/js` / `*.Spec.cs`）

---

## 四、剩余工作（收口时清单，现值标注）

1. **commit 初版** —— 已完成（见 `git log`）。
2. **L1/L2 判据进 CLI** —— 已落地：`status` / `audit` 内嵌 `verify_ladder`（L0-L2 机械判据）；
   L3-L5 不冒充已验证，声明高于实际验证时结论行显式写「已声明 Lx，仅验证到 Ly」。
3. **`meta.yaml` 非 `level` 键违例告警** —— 已落地（合法键白名单 `level` / `ai-surface` / `docs-tier`）。
4. **v+2 升级 diff 合并** —— 部分：`upgrade apply` 刷新宇宙内骨架；逐文件语义合并仍是人的工作。
5. **L3-L5 的精微门禁 / 生成物漂移门 / 双语配对** —— 未交付，候选提案见 `revisions/proposed/`。

---

## 五、验收标准（首版是否可交付）

**一个从没见过这套框架的人，拿到本仓库后：**

1. `bash ponygo --help` → 看到命令面；
2. `bash ponygo status` → 报骨架完整度 + 决策数 + 去下一级提示；
3. `bash ponygo audit` → 自适配深度档、四问打分、缺口→最小改进动作、替代物/合规提示；
4. 在空项目 `bash ponygo init` → 铺 `.meta/` + `.agents/` 骨架；constitution 仍是模板态时投影
   bootstrap 引导（**不是**把模板当命约）；
5. 填槽后 `bash ponygo sync` → 投影到根 `AGENTS.md` / `CLAUDE.md` 的哨兵块区间。

**当前状态：可交付。** 仅剩可选的后续能力（上文 §四 4-5）。

---

## 六、口径校正映射（旧稿 → 现值）

| 校正项 | 现值 |
|---|---|
| 档位区间 | `level:` 取 `0`…`5`；阶梯 `L0`–`L5`（L0–L2 机械判据，L3–L5 目标画像） |
| 决策记录路径 | `.agents/notes/`（双根分家后，决策归 AI 运行时根，不在 `.meta/` 下） |
| AI 技能路径 | `.agents/skills/`（同上） |
| 文件清单 | 不在本文枚举，真源 = 根 `README.md` §7（手抄清单是漂移源） |
| 判据细目计数 | 不在本文枚举，真源 = `audit/checklist.md`（骨架 / 机制 / 精微三层条目） |

---

## 七、关键文件中的"单一真相源"约定（改东西前必读）

- **命令面唯一真源**：`ponygo` 的 `usage()` + case 分发。改命令后必须同步根 `README.md` §1 表 / §3 用法 / §7 索引。
- **level 取值唯一真源**：整数 `0`…`5`（语义 = **当前档位**，不是未来目标）。`meta.yaml` 注释、`maturity-ladder.md` §5/§6、constitution 槽位示例三方一致。
- **判据细目唯一真源**：`audit/checklist.md`（骨架 / 机制 / 精微三层条目）。CLI 内嵌是精简子集，口径不一致以细目库为准。
- **决策 class 封闭集合**：`feature` / `bug-fix` / `simplification` / `architecture` / `process` / `testing`（连字符，勿写成斜杠）。
- **文档家唯一真源**：`.meta/docs-tier/README.md`（本仓实例路径）；tier 职责与写作规则在 `docs/AGENTS.md`。

---

## 八、本轮踩过的坑（防复发）

1. **子智能体越权改约定**：曾把阶梯/审计塞进 `.meta/`，与仓库根契约冲突 → 并行子任务必须把路径/命名契约写死进每个 prompt。
2. **投影守卫用了"截断后的 body"判 TODO**：槽位在「## 常载命约」之前被截掉导致守卫失效 → 改为对全文件判 `TODO:`。
3. **命令数量漂移**：四→五→六命令，每次都要同步 README 三处（§1 表 / §3 用法 / §7 索引），容易漏。
4. **"约 N 项"计数虚高**：三处文档各报不同数字 → 收敛为单一真源，一律以细目库为准。
5. **API 限流（429）**：并发派多个子智能体会打满额度 → 审核阶段串行派发，不要并发。
