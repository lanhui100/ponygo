# HANDOFF —— ponygo 元框架任务交接文档

> 本文为 v0 交接历史文档，已于 2026-08-30 收口。后续过程记录见 `docs/dev-team/`。

> 本文件给"换新窗口/新会话继续本任务"用。读完本文 + 下方「剩余工作」，即可无缝接续。
> 最后更新：2026-08-30

---

## 一、任务一句话目标

构建一个**与具体项目隔离、通用、可复用**的「软件项目工程化治理元框架」——**ponygo**：
治理体系的"生成器 + 演进控制器"，回答"一个项目如何长出并持续维护自己的治理体系"，
而不是"好项目怎么管理"（那是原理层 `docs/methodology.md` 的事）。

品牌：pony（马）。命令名 **ponygo**（pony + go，取"治理体系的开跑/推进"义）。

---

## 二、已拍板的全部决策（勿再重议）

| 决策点 | 定论 |
|---|---|
| 载体 | **独立 git 仓库**（模板仓库），物理位置 `D:\Documents\ponygo\` |
| CLI 形态 | **单文件 shell，零依赖**（bash），跨平台靠 Git Bash |
| CLI 命令面 | **六命令**：`init` / `audit` / `status` / `upgrade` / `sync` / `retire` |
| 治理根目录 | `.meta/`（constitution/ + decisions/ + gates/ + skills/ + docs-tier/ + meta.yaml） |
| decisions 双轴 | `{lifecycle}/{class}/yyyy-mm-dd-topic-title.md`；lifecycle=4 态；class=6 类封闭集合 |
| meta.yaml | **仅 `level` 字段**（整数 0-6），版本由 git 派生、组件由目录存在性派生 |
| 成熟度阶梯 | L0-L6；**L0-L2 真判据（机械），L3-L6 目标画像（靠 review）**；菜单式非线性、双向可退 |
| 审计 | 四问分量表 + 分层细目库（骨架8/机制15/精微8）+ 自适应深度选择器（S/M 两档） |
| AI 适配 | 可开关插件（`ai-surface: off`），constitution → AGENT.md/CLAUDE.md 投影同步 |
| 升级合并 | **降级 v+2**，首版只留"禁止 cp -r 抹历史"纪律 |
| 自我迭代 | 实例 meta.yaml(level) / 框架 revisions(proposed→accepted) / 版本号，三级分离 |

---

## 三、已完成进度

### 构建（18 个文件全部产出，均在 `D:\Documents\ponygo\`，**尚未 commit**）

```
README.md                      入口 + 使用总纲（六命令、目录约定、停止线、合规免责）
ponygo                         CLI 单文件（六命令，实测可跑）
maturity-ladder.md             成熟度阶梯（L0-L2 判据锚定命令，L3-L6 画像）
docs/methodology.md            原理层（由 pony-agent 迁入，改名）
.meta/meta.yaml                仅 level 字段
.meta/constitution/constitution.md   宪法模板（槽位 + 常载命约 + AI 适配 + 停止线）
.meta/decisions/{README,proposed,implemented,rejected,archived}/
.meta/gates/README.md          首版空（注明"升 L2 放第一个门禁"）
.meta/skills/README.md         首版空
.meta/docs-tier/README.md      首版空
audit/scorecard.md             四问分量表
audit/checklist.md             分层细目库（权威真源：骨架8/机制15/精微8）
audit/depth-selector.md        自适应深度选择器（5 信号探测）
checklists/init.md             冷启动入口
checklists/audit.md            改造入口
revisions/{proposed,accepted}/README.md   框架自我迭代
```

### 三轮对抗审核（全部完成 + 修复）

| 路 | 视角 | 结果 |
|---|---|---|
| A 逻辑自洽 | 跨文件咬合 | 14 条发现 → 修 8 类（四→五命令、level 取值统一、sync 守卫、项数虚高等） |
| B 通用性 | 换场景碎不碎 | 6 崩点 → 修 6（retire 退级命令、ai-surface 开关、合规免责、替代物认可、CI/负样本跨栈） |
| C 可实现性 | 承诺能否兑现 | 5 项 Top → 修 5（**致命**投影守卫 bug、README 六条、口径统一、L0-L2 承诺收敛、retire 联动） |

### 关键 bug 已修复并回归验证
- ✅ 投影守卫：constitution 含 `TODO:` 时 `sync` 正确拒绝（不再生成 AGENTS.md/CLAUDE.md）
- ✅ `read_level` 剥 `L` 前缀（`level: L2` 不报 `LL2`）
- ✅ `retire --level N|off` 退级 + `ai-surface` 联动
- ✅ audit 输出含「替代物认可」+「合规免责」提示
- ✅ CI 探测跨平台（GitHub/GitLab/Bitbucket/Azure/Drone/Jenkins）
- ✅ 负样本 spec 探测语言无关（`*_test.go/rs/py`/`*.spec.ts/js`/`*.Spec.cs`）

---

## 四、剩余工作（按优先级）

1. **【可选】commit 初版**：当前 ponygo 全部文件 `git status` 为未跟踪。是否 commit、commit message，由用户定（未要求则不主动提交）。
2. **【可选】补 L1/L2 完整判据进 CLI**：C 路指出 `audit` 的 M 档只覆盖 L1/L2 判据的一小部分（1.3-1.7、2.4-2.6 未做）。README 已按"部分机械 + 部分手工跑 maturity-ladder §5"诚实收敛，但若要 `ponygo status` 真"一键验出 L1/L2"，需补这些布尔项进 `cmd_audit`。
3. **【可选】`meta.yaml` 非 level 键违例告警**：maturity-ladder 注释承诺"audit 应告警"，CLI 未实现。可在 `cmd_status` 加一条 `grep -vE '^#|^$|^level:|^ai-surface:|^[[:space:]]' .meta/meta.yaml` 告警。（注：加了 ai-surface 字段后，这条要白名单放行 ai-surface。）
4. **【后续版本】v+2 升级 diff 合并**：`upgrade` 首版只给纪律提示，实际 merge 是 v+2 能力。
5. **【后续】L3-L6 的精微门禁/生成物漂移门/双语配对**：依赖未交付机制，`[future]` 已标注。

---

## 五、验收标准（首版是否可交付）

**一个从没见过这套框架的人，拿到 `D:\Documents\ponygo\` 后：**
1. `bash ponygo --help` → 看到六命令；
2. `bash ponygo status` → 报骨架完整度 + 决策数 + 去下一级提示；
3. `bash ponygo audit` → 自适配深度档、四问打分、缺口→最小改进动作、替代物/合规提示；
4. 在空项目 `bash ponygo init` → 铺 `.meta/` 骨架，constitution 含 TODO 时**不投影**；
5. 填槽后 `bash ponygo sync` → 投影到 AGENTS.md/CLAUDE.md 标记区。

**当前状态：A/B/C 三轮审核的 Top 问题已全部修复并回归通过，达到可交付。** 仅剩 commit（需用户授权）与可选增强（上文 §四 2-3）。

---

## 六、关键文件中的"单一真相源"约定（改东西前必读）

- **命令面唯一真源**：`ponygo` 的 `usage()` + case 分发（六命令）。改命令后必须同步 README §3 + §1 表 + §7 索引。
- **level 取值唯一真源**：整数 `0-6`。`meta.yaml` 注释、`maturity-ladder.md` §5 grep、`constitution.md` 槽位示例（已改"如 2"）三方一致。
- **审计细目唯一真源**：`audit/checklist.md`（骨架8/机制15/精微8）。CLI 内嵌是精简子集（10/14），口径不一致以 checklist 为准。
- **决策 class 封闭集合**：`feature/bug-fix/simplification/architecture/process/testing`（连字符，勿写成斜杠）。

---

## 七、本轮踩过的坑（防复发）

1. **子智能体越权改约定**：README 子智能体曾把 maturity-ladder/audit 塞进 `.meta/`，与仓库根契约冲突 → 已被我纠正。教训：并行子任务必须把路径/命名契约**写死进每个 prompt**。
2. **投影守卫用了"截断后的 body"判 TODO**：槽位在 `## 常载命约` 之前，被 awk 截掉导致守卫失效 → 已改成对全文件判 `grep -q 'TODO:' "$CONSTITUTION"`。
3. **命令数量漂移**：四→五→六命令，README 每次都要同步三处（§3 标题/代码块、§1 表、§7 索引），容易漏。
4. **"约 N 项"计数虚高**：三个文档报了 4 个不同数字 → 已收敛，一律以 checklist.md 为真源。
5. **API 限流（429）**：并发派多个子智能体会打满额度。教训：审核阶段用**串行派发**，不要并发。
