# Review 记录 — EXTERNAL-001（ponygo 全面外部审核）

> 2026-08-30 后某会话 ｜ 审核者：外部独立审核（对照 deepseek-harness 实证基准）
> 范围：ponygo 全仓（CLI / 文档族 / 治理骨架 / 测试 / 安装器），逐文件通读 + DSH 治理资产实地探查对照。
> 方法：原理自洽性审核 + 与 DSH 实证逐条对照 + 用 ponygo 自己的四问记分卡给它自己打分。

## 总体结论

**设计质量 A-，自我执行 C+。** ponygo 把 DSH 经验抽象成元框架的**原理层工作是一流的**——P2 可验证性、P6 形意分离、P9 负空间三条原理在 CLI 与文档中贯彻得罕见地干净；停止线、双向退级、"已认可替代物"、合规免责等设计甚至超出了 DSH 的显性表述。但存在一个损害其全部可信性的结构性问题：**ponygo 自己没有吃自己的狗粮**——`.meta/decisions/` 与 `revisions/` 均为空，回归测试无任何钩子/CI 挂载。一个以"实证"为立身之本的框架，其自身治理停留在 `level: 0` 的字面合法态。

## 做对了什么（对照 DSH 确认）

1. **三层定位干净**：methodology（为什么）/ CLI（怎么做）/ 实例（某家怎么落地）分离，DSH 被正确降格为"实证案例"而非模板。
2. **P2 贯彻到位**：meta.yaml 仅两合法键 + 违例 WARN、文件夹即标签、status 对 L0-L2 逐项机械验证 exit 1、决策计数排除集 `{README.md, *.zh.md}` 三处共用同一函数。
3. **P6 诚实条款执行出色**：L3-L6 标"目标画像 + 未交付物清单"、2.2 如实标注 bash -n 是代理判据、无 GNU date 时日期判据降级"靠 review"、S/M 档不代劳价值判断、合规免责双挂（README + audit 输出）。
4. **对抗审核文化**：A/B/C 三轮 + spec rev2/rev3 + reviewer 处置表 + "已知问题不修留 P9"登记——这本身就是 DSH dev-team 实践的忠实复刻。
5. **测试纪律**：20 场景 117 断言，覆盖 CRLF、路径深度、封闭集越界、git 配置消毒、sync 三分支；s18 用 grep 把文档口径数字钉成测试（防 F1 复发）——"门被门检验"。
6. **双向停止线**：`retire --level N|off`、纯 L0 长驻模式、"删除是独立工程须录 decision"——业界治理框架几乎没有做这个的。

## 发现（按严重度）

### P0-1 ponygo 自身治理根为空——自我违例
- `.meta/meta.yaml` 为 `level: 0`；`.meta/decisions/` 下**零条 ADR**；`revisions/{proposed,accepted}/` 全空。
- 而 ponygo 经历了三轮对抗审核、v0→v1.1（F1-F6、V1-V3），决策实际落在 `docs/dev-team/` 与 HANDOFF——按其宪法命约第 1 条"非平凡变更命中任一即入册"，这些全部命中却零入册。
- 结构性漏洞：L0 的判据不要求任何决策记录，所以 `ponygo status` 永远绿——**申报最低级即可豁免自身全部规则**。"吃自己的狗粮"（revisions/README 原话）目前碗里是空的。
- 建议：把 dev-team 已有决策（六命令面、单文件零依赖、双轴路径、S/M 两档、首版止步 L2 等）回溯为 5-8 条 `.meta/decisions/implemented/process|architecture/` 记录；revisions 至少录一条 v1.1 的 accepted。

### P0-2 回归门禁无挂载，且宣称的测试证据本机不可复跑
- `tests/run.sh` 是合格的非零退出门禁，但**没有任何自动化挂载**：无 lefthook/CI/hooksPath——按它自己的记分卡问②只能得 2-3 分（"约定只在文档里/有 1-2 条本地 hook 无 CI"）。
- 实证：审核本机无 Git Bash、WSL 拒绝访问，`tests/run.sh` 无法复跑验证 pass=117 的宣称。README 承诺平台含 Windows Git Bash，但仓库无 CI 证明这一点。
- 建议：加一个最小 CI（GitHub Actions 一个 job：`bash tests/run.sh`，ubuntu + 可选 windows Git Bash 矩阵）；这同时补上 scorecard 问②的"CI 存在"命中。

### P0-3 install.sh 的 curl|bash 无完整性校验
- README 推荐方式 A 为 `curl | bash`，无版本钉住（raw/main 头）、无 checksum、无签名。治理框架的分发门面应当是供应链纪律的示范。至少：提供 tag-pinned URL + 公布 SHA-256，或在 install.sh 里支持 `PONYGO_VERSION` 钉版。

### P1-1 audit 与 status 判据分裂
- HANDOFF §四-2 自承 audit M 档只覆盖 L1/L2 判据一小部分；v1.1 把判据补进了 status 的 `verify_ladder`，但 audit 不调用它——用户跑一次 audit 拿不到判据级结论，只有一行提示。建议 audit 尾部直接内嵌 `verify_ladder`（声明级存在时），或合并两条命令的心智模型。

### P1-2 audit 可被"形状合规"刷分
- 2.3 只查 `*.spec.*` 文件存在（一个空文本即命中）；2.2 已诚实标注代理判据，2.3 没有对应的诚实标注。DSH 对照：负样本 spec 是真实构造非法样例并断言拒绝的测试。
- 深度选择器信号 4"已有治理痕迹 ×1 即 M 档"意味着凡 init 过的项目永远 M 档——S 档只在零治理时出现，与 README"S 档=起步/小项目"的表述有偏差（小项目 init 后即被升档）。

### P1-3 sync 投影硬编码中文标题
- `awk '/^## 常载命约/'` 写死中文。框架自称通用，英文实例改写宪法标题后 sync 直接 die。建议改为标记注释锚点（如 `<!-- sync-body -->`）或把节名列为 constitution 契约的一部分并写入模板注释。

### P1-4 read_level 对空值/畸形值归一为 0（判据宽于真源）
- `level: `（空）或 `level: L` 经 `tr -d '[:space:]"L'` 归一为空串，`${lv:-0}` 默认 0 → 假 L0 PASS。maturity-ladder 0.4 要求合法枚举，空值应 FAIL。建议：空串不落默认，直接报 0.4。

### P1-5 upgrade 是空命令却占命令面 1/6
- 首版只打印纪律（已诚实声明），但 README 方式 C 以"方便 ponygo upgrade 跟随升级"为卖点，期望落差大。建议：改名 `ponygo guide upgrade`，或命令面收敛为五命令、upgrade 能力交付时再入面。

### P2 组
- **P2-1** class 封闭集 6 类写死在 CLI，无实例扩展机制——与 L6"领域定制"矛盾（领域定制的第一个诉求往往就是加一个 class）。
- **P2-2** revisions/（框架演进）与 decisions/（实例演进）双轨的适用边界未写清，且 revisions 为空（同 P0-1）。
- **P2-3** 无 LICENSE 文件——curl|bash 分发 + GitHub 公开仓库，缺法律许可。
- **P2-4** `docs/HANDOFF.md` 含"尚未 commit"等已过期陈述，按 ponygo 自己的 slop 纪律（历史叙事挤进当前态）应归档或更新；docs/ 渐多但 docs-tier/ 仍是占位 README（自身 L3 未启动，level 0 下自洽，但文档分层需求已实际出现）。
- **P2-5** 对 DSH 经验的取舍整体明智（i18n/快照/词数预算等正确地未进入首版），但 methodology §5.1 的 12-tier 表未沉淀为 `.meta/docs-tier/` 的可填模板——L3 解冻时使用者仍要照抄文档，违背"照做不需要读文档"的自我要求。L3-L6 各缺一页"解冻手册"。

## 用 ponygo 自己的四问记分卡给 ponygo 打分

| 问 | 分 | 证据 |
|---|---|---|
| ① 决策记在哪 | 3/10 | 载体与路径编码完备，但 `.meta/decisions/` 与 `revisions/` 均为空；决策实际散在 dev-team/ 与 git log |
| ② 承诺怎么强制 | 3/10 | tests/run.sh 存在且质量高，但无钩子无 CI；本机无法复跑宣称证据 |
| ③ 重复劳动怎么复用 | 3/10 | dev-team 的 spec→review→收口已是事实流程资产，未按自己的五要素资产化（L4 未到属合法，但流程已重复 ≥3 次） |
| ④ 过时怎么退场 | 4/10 | retire 命令 + archived 目录 + P9 留债登记到位；无实际归档发生 |

**杠杆结论（按它自己的纪律）**：优先投强制层——补 CI 挂 tests/run.sh，它是其余三层的放大器；其次是把既有决策回溯入册（成本一段文字/条，漏记成本永久丢失——它自己的话）。

## 处置记录（2026-08-31）

P1/P2 组全部修复并回归（决策入册：`.meta/decisions/implemented/process/2026-08-31-external-review-p1-p2-fixes.md`）：

| 发现 | 处置 |
|---|---|
| P1-1 audit/status 判据分裂 | 已修：audit 内嵌 verify_ladder，判据不符 exit 1 |
| P1-2 形状合规刷分 | 已修：深度信号 4 剔除 .meta；2.3 补代理判据诚实标注 |
| P1-3 sync 中文标题硬编码 | 已修：`<!-- sync-body -->` 锚点 + 中文标题回退兼容 |
| P1-4 空 level 假 L0 | 已修：read_level 空值不默认归 0，0.4 判 FAIL |
| P1-5 upgrade 期望落差 | 部分采纳：README 方式 C 措辞收敛（不改命令面——六命令是拍板不变量） |
| P2-1 class 无扩展口 | 已修：`decisions/classes.local` 实例扩展 |
| P2-2 双轨边界 | 已修：写入 revisions/README.md |
| P2-3 缺 LICENSE | 已修：MIT |
| P2-4 HANDOFF 过期 | 已修：头部标注历史快照 |
| P2-5 docs-tier 无模板 | 已修：占位 README 扩为 8-tier 可填模板 + slop checklist，纳入 s14 逐字节测试 |

P0 组已于 2026-08-31 修复（决策入册：`.meta/decisions/implemented/process/2026-08-31-dogfooding-ci-and-install-integrity.md`）：

| 发现 | 处置 |
|---|---|
| P0-1 自身狗粮 | 已修：回溯 6 条核心 ADR + 修复 ADR 2 条入册；revisions/accepted 补录 v1.1 与 classes.local 两条框架演进；meta.yaml 升 level: 1（status 机械看守 L1 判据） |
| P0-2 门禁无挂载 | 已修：`.github/workflows/ci.yml`（ubuntu + windows Git Bash 双平台跑 tests/run.sh + all-checks-passed 聚合门） |
| P0-3 curl\|bash 无校验 | 已修：install.sh 支持 PONYGO_VERSION 钉版 + PONYGO_SHA256 强制校验（fail-closed，失败删文件）；README 同步；s20 补正反场景 |

回归证据：`tests/run.sh` 新增场景 21（各修复点正反对照例）+ s14 追加 docs-tier 逐字节断言；
三份骨架 heredoc 与仓库文件经 eol 归一逐字节比对一致（本机无 bash，run.sh 全量待有 bash 环境复跑——这本身印证了 P0-2）。

## 审核局限声明

- `tests/run.sh` 未能在审核环境复跑（无 bash 环境），测试结论采信 `docs/dev-team/reviews/review-TASK-001.md` 记录的 pass=117 fail=0，未独立验证。
- DSH 侧探查为抽样（AGENTS.md / lefthook.yml / workflows / scripts / .agents 结构），非全量逐行。
