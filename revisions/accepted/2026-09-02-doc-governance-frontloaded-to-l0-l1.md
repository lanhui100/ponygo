# Revision: 文档治理前置——AGENTS.md 自动加载家 + 判据门禁 L1 + 分层治理 L2 + audit 双保证

Status: accepted

## 回馈证据（ponyllm 实例实证 + dsh 机制对照）

**实证 1（ponyllm 文档真空）**：ponyllm 作为 ponygo 框架的成熟实例，`level: 2`、
14 个提交、13 条 implemented ADR、pre-commit/CI 双重门禁全绿——但 `docs/` 目录 **0 个文件**、
5 个 crate **0 个 README**、137 行 README 一个文档承载安装/上手/SDK/架构/许可证五类职责，
框架没有任何判据拦下这一切。

**实证 2（AGENTS.md vs README 机制差异）**：dsh 的文档家有两层——给 agent 自动加载的
`AGENTS.md`（根 + `docs/AGENTS.md` + `packages/AGENTS.md` 等，agent 处理子树时自动并入上下文），
与给人读的 `README`（`packages/*/README.md`，agent 不主动读就不进上下文）。
**ponygo 骨架当前生成的全是 README**（`.agents/notes/README.md`、`.agents/skills/README.md`、
`.meta/gates/README.md`、`.meta/docs-tier/README.md`）——这些治理契约 agent **不会自动加载**，
只能靠根 AGENTS.md 的三条命约主动链过去。这是"文档治理没发挥作用"的机制根源：
**家选错了载体，文档即使存在也不进 agent 上下文**。

根因：maturity-ladder 把"文档分层"整体放在 **L3**（启用条件=文档量开始互相重复/腐烂），
L0–L2 阶段文档治理完全缺位；且文档家载体选成 README（不进上下文）。两者都违背框架自己的
"宁可粗糙、不可缺席"（methodology §10）与"每个事实一个家"（methodology §5.1——ADR 有
1.1–1.8 八条格式契约且家是 `.agents/notes/`，用户文档却连"存在 + 家是 AGENTS.md"这个
最弱判据都没有）。

## 框架规则变更

### A. 阶梯重排：文档治理提前到 L1/L2，原 L3–L6 顺延上移

| 级 | 原定位 | 新定位（文档治理提前） |
|---|---|---|
| L0 | 播种 | 播种 + 最小文档家（根 AGENTS.md 投影 + docs/AGENTS.md） |
| **L1** | 决策入册 | 决策入册 + **文档存在性判据与门禁**（文档有家：AGENTS.md/README 存在、包文档覆盖或豁免） |
| **L2** | 承诺可验 | 承诺可验 + **文档分层治理**（原 L3 前移：tier 分类 + slop + 词数预算 + doc-sync 门的机械面） |
| L3 | 文档分层（并入 L2） | 流程资产（原 L4） |
| L4 | 流程资产 | 负空间（原 L5） |
| L5 | 负空间 | 领域定制（原 L6） |
| L6 | 领域定制 | （收敛，阶梯变为 L0–L5） |

> 顺延的理由：文档治理的**存在性**是比"承诺可验"更基础的纪律（先有家才能谈分层、谈门禁），
> **分层治理**的机械面（tier/slop/budgets 的判定命令）本质也是"承诺可验"，并入 L2 与门禁同层
> 自洽。原 L3–L6 整体上移一级，不影响各自语义。

### B. 文档家载体：AGENTS.md 为主（agent 自动加载），README 保留给人读

init 骨架生成（新增）：

- 根 `AGENTS.md`：投影命约（现有）+ 文档家索引链（指向 docs/AGENTS.md 与各 tier 的家）；
- `docs/AGENTS.md`：**文档标准的家**——tier 分类法、写作规则、词数预算、slop checklist，
  agent 写文档时自动加载（对齐 dsh `docs/AGENTS.md`）；
- 各包/crate 目录 `AGENTS.md`（可选，占位）：该子树规则 + 链到包 README（对齐 dsh `packages/AGENTS.md`）；
- 根 `README.md` 与各包 `README.md`：**保留为人读契约**（config/semantics/limitations），
  AGENTS.md 链到它们，不替换。

> 判据含义：L1"文档有家"判据检查的是**家载体存在**（AGENTS.md 或 README，按 tier 类型），
> 不是"必须有 README"——docs/ 的家是 AGENTS.md（自动加载），包契约的家是 README（人读），
> 各归其位。

### C. 判据与门禁落点（L1 判据 + L1 门禁 + audit 双保证）

1. **L1 判据新增"文档有家"**（机械判定，进入 verify-note.sh / ponygo status）：
   - 根 AGENTS.md 存在且含文档家索引链；
   - `docs/AGENTS.md` 存在（文档标准的家）；
   - 包/模块文档覆盖：每个包目录有 `AGENTS.md` 或 `README.md`，或列入显式豁免清单
     （`docs/exemptions.md` 或 `.meta/docs-tier/exemptions`）。
2. **L1 门禁**：上述判据进入 pre-commit/CI（非零退出命令 + 负样本 spec），
   不只 init 时生成，**每次提交都被守**。
3. **audit 双保证**：`ponygo audit` 对**既有项目**（非 init 新建）同样执行文档有家判据——
   旧项目接入时 audit 须报告文档家缺失（P1 级改进动作），并列出补全家清单。
   不因"项目已存在"而豁免。

### D. 其余改动

4. **maturity-ladder.md**：阶梯总表、L0–L2 判据表、§5 升格判据、§2 诚实声明同步重排；
5. **docs-tier/README.md 模板**：从纯模板改为"已激活文档家清单"（docs/AGENTS.md 为文档标准家，
   其余 tier 保留 TODO）；
6. **docs/methodology.md**：§5 补"文档家 = AGENTS.md（自动加载）vs README（人读）"；
   §10 迁移清单 Wave1 加入"最小文档契约（AGENTS.md 家）"；
7. **governance-review 技能**：文档面审查增强——检查"文档家是否空壳 / 家载体是否为
   AGENTS.md（自动加载）/ 文档与代码是否同提交"（呼应 dsh same-commit 规则）。

## 采纳理由（dsh 实证参照）

- dsh 51 个 packages，50 个有 README（97%）——文档存在性是默认事实；
- dsh 用 AGENTS.md 层级自动加载承载治理规则（根/docs/packages/scripts 各子树），
  README 承载人读契约——**双轨分工**，agent 一进子树规则即达上下文；
- `packages/AGENTS.md`："Update package README and JSDoc contracts in the same commit
  as behavior"——文档与代码同提交是硬规则；
- `docs/AGENTS.md` 12 个 tier 每行"Job / 不承载"写死——每个事实一个家从第一天生效；
- 文档门禁分层（lefthook 本地 + CI verify-doc-budgets / verify-doc-refs / doc-typecheck）。

结论：dsh 的文档治理从第一个包、第一行文档就生效，家载体用自动加载的 AGENTS.md，
分层只是这套纪律的高级形态。ponygo 的错误在于把"存在性"（起点）与"分层"（高级形态）混成
一个 L3 黑箱，且家载体选成不进上下文的 README。

## Alternatives considered

- **维持现状（文档治理整体留在 L3 + 家载体 README）**：否决——ponyllm 实证证明 L0–L2
  文档真空 + agent 不自动加载 README 是框架设计必然结果，双重失效。
- **只前置文档存在性判据，家载体仍用 README**：否决——README 不进 agent 上下文，
  文档生成了 agent 也不看，治理在机制上落空（实证 2）。
- **只把整套 L3 文档分层前置到 L1（tier + slop + 词数预算一起搬）**：否决——词数预算、
  doc-sync 约 30 门是 260 包大仓库才值得的（dsh 实例）；分层机械面并入 L2（与门禁同层），
  L1 只放存在性判据+门禁，保持阶梯经济。
- **只在 methodology 写声明、不改阶梯与骨架**：否决——无判据、无骨架、家不进上下文，
  声明不改机制等于没改。
- **init 生成各 crate/包 README 占位（一步到位）**：备选但本轮不采纳——包文档内容契约
  （config/semantics/limitations）在各实例语言下差异大，由实例按 L1 判据"包文档覆盖或豁免"
  自行补齐更合适；骨架只种 AGENTS.md 自动加载层 + 根/包 README 人读层。

## 影响面

- maturity-ladder.md：阶梯总表 + L0–L2 判据表 + §2/§5 说明同步重排（L0–L5 六级）；
- ponygo 脚本：write_skeleton 增三段 heredoc（根 AGENTS.md 索引链 + docs/AGENTS.md +
  根 README）+ status/audit 增"文档有家"检查 + verify-note.sh 增相应判据；
- docs-tier/README.md 模板：模板态 → 已激活清单态（与模板仓库逐字节一致，s14 类测试覆盖）；
- docs/methodology.md：§5/§10 两处补充；
- .agents/skills/governance-review/SKILL.md：文档面审查步骤增强（AGENTS.md 家 + 同提交）；
- 测试：tests/run.sh 增断言（init 生成 docs/AGENTS.md/根 README、L1 判据文档有家、
  audit 对既有项目检测文档家缺失）。
