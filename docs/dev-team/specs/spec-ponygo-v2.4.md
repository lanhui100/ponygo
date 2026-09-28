# Spec —— ponygo v2.4：落实三条 proposed ADR（L2 判据矛盾 / upgrade 漂移报告 / 发布校验和自动化）

> Task: TASK-003 ｜ 复杂度: B ｜ 2026-09-14 ｜ **rev3**：已纳入 consultant 三选一裁决
> （Q1=A、Q2=A、Q3=A，`reviews/review-TASK-003-consultant.md`）、architect 六条 P0
> （`reviews/review-TASK-003-architect.md`，结论不通过），以及 consultant 对 rev2 的
> 忠实度复核（D1–D5 五处偏离）与 architect 对 rev2 的复核（P0-2/P0-3/P0-6 有残留）。
> 本文件是**实施依据**，实施前需 focused 回审确认 D1–D5 已修。
> 前提：三条 proposed ADR 均经独立对抗评审，结论全部**不通过**（方向保留，重切后可实施）。
> 证据：`reviews/review-TASK-003-{l2,upgrade,release}.md`

---

## 1. 背景与目标

### 1.1 实测基线

| 检查 | 结果 |
|---|---|
| `ponygo status`（仓库自身） | L1 / exit 0（55s 超时内可完成；此前 180s 超时是 audit 的输出量问题，非 status） |
| `ponygo audit --level M` | 命中 9 / 14；唯一缺口「无本地钩子（core.hooksPath 未设）」——**本机事实，保留** |
| 本地 tag / 远端 | `v2.3.0`=`b8b7e28`=HEAD 在本地；`ls-remote --tags origin` 为空；`rev-list origin/main..HEAD`=1（**ahead 1**）；工作树 7 个未跟踪文件（TASK-003 + spec + 5 review） |
| `gh auth` | `lanhui100`，scope 含 `repo`（可建 Release） |
| 发布策略 | **新 tag `v2.4.0`**，严禁补 `v2.3.0` 附件（旧提交无守卫，补发=失实认证；consultant 裁决 Q3 理由 3） |

### 1.2 目标

1. **R（release）**：交付可验证的发布校验和链——README 主路径 fail-closed、installer 与载荷同钉 tag、
   release workflow（裸哈希 + Linux runner + 最小权限 + CRLF 断言）、测试拆三断言、ADR 拆条；
   推 tag 建 Release，让安装路径端到端可验证。
2. **U（upgrade）**：交付"零假漂移"的 `ponygo upgrade` 漂移报告——宇宙 = s14 的 10 文件精确路径
   （不另立清单文件）；默认报告 exit 0 + `--check` 供 CI（漂移→非零）；donot 三场景有定义；
   健康实例零假漂移（宇宙外文件不进报告，报告头一句话声明盲区）。
3. **L（L2 判据矛盾）**：按 consultant 裁决落地（Q1=A 已定，B/C 否决），§1/§5/§6 口径一致；本仓仍 L1 exit 0。

---

## 2. 范围与非目标

**范围内**：`ponygo`（`cmd_upgrade` 新增、`verify_ladder` 2.5 按裁决改）、`README.md`（§3.1 安装块）、
`install.sh`（默认 URL 同钉 tag）、`.github/workflows/release.yml`（新）、`tests/run.sh`
（s30 新 / s31 新 / s29 扩展版本号断言）、`maturity-ladder.md`（§1/§5/§6 按裁决改）、
`.agents/notes/`（拆条 + 迁移/归档）、`docs/dev-team/`（task/spec/review）。

**非目标**：
- 不做 `upgrade` 自动合并（v+2 能力）；不改六命令面；不动 `docs/HANDOFF.md`；
- 不升本仓库 level（停 L1；Q1=A 不改变本仓档位，§6 停止线裁决延续）；
- 不引入 mixed `<!-- instance:begin/end -->` 标记块机制（框架规则变更太大，留待独立提案）；
- 不把 `docs/AGENTS.md` 纳入 s14（upgrade 评审 P0-3 指出的归属未定项，本次只做"归属声明"，不动断言）。

---

## 3. 用户/系统行为

### 3.1 R 包：发布校验和链（评审 P0-1/P0-2/P0-3 → 必修）

- README §3.1 主命令块必须 fail-closed：`set -o pipefail`（或等价）+ `[ -n "$SHA" ] || exit 1`
  空值守卫——附件 404/空 SHA 时**安装拒绝**，绝不静默跳过校验（与 install.sh fail-closed 一致）。
- 未发布状态诚实标注：tag 未推 / 附件缺失时，命令块旁必须有一句"当前不可用，未发布时按下方口径
  本地自算"，不得把死链当推荐生产路径。
- installer 与载荷同钉 tag：`install.sh` 的默认远端 URL 从 `main/install.sh` 改为 tag 变量
  （如 `PONYGO_VERSION` 同值复用），避免 main 浮动导致全链失守。
- workflow 计算命令钉死为裸哈希管线：`sha256sum ponygo | awk '{print $1}' > ponygo.sha256`
  （整行 `hash *ponygo` 会被 fail-closed 拒绝——consumer 侧 awk 兜底不能作为附件整行也行的理由）。
- runner 钉 Linux **且**规定哈希对象 = checkout 的 `ponygo` blob（非 zip/tarball）**且**加
  `grep $'\r'` CRLF 断言（无 CRLF 才发布；`.gitattributes` 必要非充分）。
- 顶层 `permissions: {}` 默认拒绝，job 级仅开 `contents: write`；第三方 action 钉版本/SHA；
  仅 tag-push 触发，不执行 PR 非受信代码。

### 3.2 U 包：upgrade 漂移报告（评审 4 P0 → 重切；architect P0-1/P0-2/P0-6 必修）

- 比对宇宙 = **s14 的 10 个文件精确路径**（见 §8 s31 宇宙表），
  **不另立 `.meta/skeleton-owned` 文件**（第三副本，slop 第一条）。
- 宇宙外文件**根本不进报告**（architect P0-2 修法 a）：根 `README.md`、`meta.yaml`、
  已填 `constitution.md`、`docs/AGENTS.md`、`.gitignore`/`.rgignore`（追加语义）、
  sync 投影物（根 `AGENTS.md`/`CLAUDE.md`）、`classes.local`、`.meta/docs-tier/exemptions`
  均不在报告内；报告头用一句话声明盲区："本报告只覆盖 s14 宇宙内十文件；宇宙外文件无基线，
  不判定"（architect P0-2 修法 a：诚实声明盲区，而非"无基线单列"逐项放水）。
- `docs-tier/README.md` 按现状处理：本仓模板态 + s14 不变；漂移报告对"已激活"实例诚实声明
  **不支持**（P0-1(a) 路线），不发明新激活机制。
- exit 语义：漂移是**观察**不是承诺（status 管骨架缺口 exit 1，upgrade 管"与模板差多少"；
  报告头写清此差，architect P3-1）——默认报告 exit 0；新增 `--check`（漂移非零，供 CI；
  复用 `audit --run-specs` 的 opt-in 范式）。**s15 必须同步扩展为双断言**
  （默认 exit 0 含漂移行 + `--check` exit 非零），否则视为未完成（consultant Q2 理由 2）。
- donot：无 `.meta/` → die 并指引 init（对齐 retire/status）；非 git → WARN（对齐 status）；
  无 level → 按 L0 处理——其中"无 level"指 `read_level()` 的三态之"缺文件/缺 level 行"分支
  （`ponygo:61-72`），空值/畸形仍走 0.4 FAIL，不走 L0（architect P1-6）。三场景均有测试。
- `--check` 落点（architect P1-1）：入口 parser 新增 `--check` 分支 + `usage()`/s01 同步；
  仅 `upgrade` 接受（参照 `--run-specs` 互斥守卫：`ponygo:1692-1695`）；与 `--dry-run` 互斥
  （`--check --dry-run` → die，检查必须读真实文件）。
- 教训归因：`gates/README.md` 全文无"假漂移"一字，真源是 TASK-002 双审（architect P0-4 /
  consultant P1-3，spec rev2 §10 处置表）——注释与 review 记录引用此出处，
  **不塞进用户可见输出**（architect P3：docs/AGENTS.md 禁历史叙事）。

### 3.3 L 包：L2 判据矛盾（consultant 已裁决：**选 A**，`reviews/review-TASK-003-consultant.md` Q1）

**裁决**：选项 A（2.5 改条件判据）；否决 B（门禁语义污染 L1，违反 §1 每级单一核心产物划分）；
否决 C（删真实中间态）。v2.0 前置（0.5/1.9）继续有效，A 只动 2.5。

实施形态（L2 评审 P0-3 + architect P1-4 的原子补丁清单，缺一即否决实施）：

- 状态机：undeclared = SKIP **+ WARN 催声明**；off = 显式 opt-out，须录 decision 且结论禁写
  "全部 PASS"（精确改写为"2.1–2.4 PASS；2.5 未启用"，s12 断言精确字符串）；on + TODO 残留判 FAIL；
  off + 已激活 → 矛盾 WARN；undeclared + 已激活 → PASS（实际做到优先于声明）。
- 声明载体：**`meta.yaml` 加 `docs-tier:` 键**（on/off，未声明=缺键），标记文件封闭命名
  （拒绝通配"存在即声明"——目录下已有 `exemptions`，L2 评审遗漏边界条）。
- 键解析宽容度（architect P2-3 未定义项，在此钉死）：顶格无缩进（与 level/ai-surface 同规则）；
  值仅接受小写 `on`/`off`（`ai-surface` 的 Off 大小写先例**不继承**——新键从严）；
  CRLF 剥 `\r` 后判定（与 `warn_meta_violations` 同）；引号/非法值（yes/no/true/空）→ 走违例键
  WARN（`ponygo:1082` 白名单机制，不新增解析分支）。
- 同步改：`meta.yaml` 铁律注释（合法键 level + ai-surface + docs-tier，说明 docs-tier 是
  **启用声明**而非目录推导事实——目录存在≠已激活，故不是冗余副本）；`ponygo:1082` 白名单；
  `maturity-ladder.md` §1 总表 L2 行 + §5 2.5 行与注 + §6 "最轻 L2"定义（`2.1–2.4 + docs-tier: off`）
  + §172–176 诚实条款（condition 的 validation 标注）；s12 四分支 + s13 新键用例 + s28/s29 联动。
- 2.5 锚点统一：标题判据 `grep -q '## 已激活文档家清单'` 不变（`ponygo:1261`），TODO 残留模式钉为
  `【TODO】`（与模板 `ponygo:862-868` 一致）；on + 残留即 FAIL。
- 作用域：`lv>=2` 块内生效；`level:1` 声明 `docs-tier:on` → 忽略（L1 不验 2.x，静默，不告警）；
  `lv>=3` 同 L2 分支处理（P2-1 未定义项，在此钉死）。
- 回滚线：实施中若发现 0.5/1.9 被弱化，立即回滚 A（consultant Q1 理由 4）。

---

## 4. 技术方案与替代方案

| 评审否决点 | rev1 处置 |
|---|---|
| README fail-open（R P0-1） | pipefail + `[ -n "$SHA" ] \|\| exit 1`；s30 断言"空 SHA 安装拒绝" |
| 死链当推荐（R P0-2） | 未发布状态诚实标注；A5 改为"附件发布后"可验证，本轮先推 tag 发附件再验证 |
| 口径未钉裸哈希（R P0-3） | workflow 与 README 维护者口径统一为 `sha256sum ponygo \| awk '{print $1}'` |
| installer 取 main 浮动（R P1-1） | 默认 URL 同钉 `PONYGO_VERSION` |
| runner 理由不全（R P1-2） | 对象=checkout blob + CRLF 断言 |
| permissions 不足（R P1-3） | 顶层 `{}` + job 级最小 + action 钉 SHA |
| 测试不可测（R P2-1） | 拆三断言：静态管线 / 本地动态复跑 diff / hex 格式 `^[0-9a-f]{64}$` |
| 版本硬编码漂移（R P2-2） | s29 扩展"版本号示例一致性"断言（README 示例 tag == git 最新 tag 语义，见 §8） |
| 覆盖边界警示不足（R P2-3） | README 生产推荐旁标注"校验只保 `ponygo` 不保 `install.sh` 自身" |
| 提案未拆条（R P3） | 已交付口径归 implemented ADR；workflow 留 proposed（本次实施后迁移） |
| docs-tier 双重分类（U P0-1） | 选 P0-1(a)：保持模板态 + s14 不变，漂移报告声明不支持已激活实例 |
| 问错方向（U P0-2） | 宇宙外文件不进报告 + 报告头一句话盲区声明（D3 选 (b) 路线：architect P0-2 修法 a 覆盖裁决"无基线单列"术语，见 §10 采纳/覆盖记录） |
| 清单路径错（U P0-3） | 宇宙 = s14 十文件精确路径，不另立清单 |
| 第三副本（U P0-4） | 删落盘方案；单源 = heredoc 生成逻辑 + s14 测试镜像 |
| exit 未决（U P1-3） | 默认 0 + `--check` opt-in |
| donot 未定义（U P1-4） | 无 meta→die；非 git→WARN；无 level→L0 |
| meta 加键（L P0-1） | 按 consultant 裁决；若选 A 则白名单+铁律+s12/s13/s28/s29 全套原子补丁 |

---

## 5. 影响面和依赖

- **行为变更**：`upgrade` 新增漂移报告（默认 exit 0）+ `--check`；`install.sh` 默认 URL 同钉 tag；
  2.5 改为条件判据（Q1=A 已定，B/C 否决）。既有实例默认行为不变
  （upgrade 原纪律输出保留为报告头部；installer 不设版本时仍取 main——见 §7 风险）。
- **文档**：README §3.1（守卫+标注+同钉 tag+裸哈希口径+覆盖边界警示）、`maturity-ladder.md`
  （§1/§5/§6 按 Q1=A 改）、`.meta/gates/README.md`（若 upgrade 报告引用分层原则，不动模板本身）、
  `.github/workflows/release.yml`（新）。
- **测试**：s30 新（release 三断言 + fail-closed + 同钉 tag）、s31 新（upgrade 零假漂移 /
  篡改→`--check` 非零 / donot 三场景）、s29 扩展（版本号示例一致性）、s12/s13/s28 按 Q1=A 联动
  （s15 扩展为双断言：默认 exit 0 含漂移行 + `--check` exit 非零，原 exit 0 断言保留）。
- **记录**：ADR 拆条（implemented 口径 + proposed workflow→实施后迁移 accepted）；
  三条旧 proposed 按处置迁移/归档；`revisions/` 新增两条（2.5 条件判据 + upgrade 漂移报告规则，见 §7）。
- **依赖**：`gh` 已认证（建 Release 用）；tag 推送需网络；零新增外部依赖。

---

## 6. 任务拆解与并行边界

| WP | 内容 | 独占写目标 |
|---|---|---|
| WP0 | consultant 裁决 + 双审（plan/spec 审核闭环后再实现） | `reviews/` |
| WP-R | README 守卫/标注/同钉 tag + workflow + s30 | `README.md`、`install.sh`、`release.yml`、`tests/run.sh`（s30） |
| WP-U | upgrade 漂移报告 + `--check` + donot + s31 | `ponygo`（`cmd_upgrade`）、`tests/run.sh`（s31） |
| WP-L | 2.5 按裁决改 + 阶梯口径 + 联动测试 | `ponygo`（`verify_ladder`）、`maturity-ladder.md`、`tests/run.sh`（s12/s13/s28/s29） |
| WP-P | 发布：推 tag → 建 Release → 端到端验证 → 提交推送 | 远端 |

**并行边界**：`tests/run.sh` 是 WP-R/U/L 共享写目标——单一实施者串行推进，不开并行子智能体
改同一文件（TASK-002 rev2 P1-5 教训）。**执行顺序钉死**（architect P1-3：tag 一致性顺序敏感）：
WP-L 先（2.5 语义定后 s29/s12 才稳定）→ WP-U（`ponygo` 的 `cmd_upgrade` 与 L 包的 `verify_ladder`
同文件串行）→ WP-R（README tag 示例最后 bump 到 v2.4.0，避免 s29 提前红）→ WP-P。
runner 尾部调用表按 s30→s31 顺序追加，归属唯一。

---

## 7. 风险、回滚与迁移

| 风险 | 缓解 |
|---|---|
| installer 默认 URL 改 tag 后，未设版本的老用户行为变化 | 保留 `PONYGO_VERSION` 为空时回退 main 的兼容分支，并 s30 断言该分支 |
| release workflow 首次运行失败（不可预演） | 最小 job（checkout→算哈希→断言无 CRLF→upload artifact→建 Release），permissions 最小；失败则 Release 不建，README 诚实标注保持 |
| upgrade `--check` 被误读为"必须零漂移" | 输出头写清"漂移=观察"与 status"缺口=承诺违例"的区别（upgrade 评审 P3-1） |
| L 选项 A 引入"声明即豁免"激励 | SKIPPED 常态化对策：undeclared=SKIP+WARN 催声明 + audit 分层报告仍提示；结论行禁"全部 PASS" |
| 选项 A 与 v2.0 文档治理前置的张力 | 已裁决：v2.0 保 0.5/1.9，A 只动 2.5；实施中若发现 0.5/1.9 被弱化，立即回滚 A |
| `meta.yaml` 加 `docs-tier:` 键 | 必须同步改铁律注释 + `ponygo` 1082 白名单 + s13 用例，否则 s13 先红（L2 评审 P1-3） |

**回滚**：release workflow 可整文件 revert；upgrade 报告是纯增量函数；2.5 条件判据可整段 revert
回无条件形态。tag/Release 发布后不可撤回——发布前必须全绿（D4 硬门，见 §9）。

---

## 8. 测试计划

| 场景 | 断言 |
|---|---|
| s30（新，release） | ① 空 SHA → 安装拒绝（fail-closed，非跳过；直调 `PONYGO_SHA256="" install.sh`，不 mock curl）；② README 方式 A 的 bootstrap 行与 installer 同钉 `PONYGO_VERSION`（真改的是 README 行，非 install.sh——architect P1-2；另断言不设版本时仍取 main 兼容分支）；③ workflow 静态五断言：精确管线 `sha256sum ponygo \| awk '{print $1}'` + `runs-on: ubuntu-latest` + 顶层 `permissions: {}` + action 钉 SHA + `on.push.tags` 触发；④ workflow 抽取命令 vs README 维护者口径归一化 diff 一致（bypass 纯 bash YAML 脆弱性：只抽 `run:` 行比对，见 §7）；⑤ 附件值匹配 `^[0-9a-f]{64}$`；⑥ CRLF 行静态存在（`grep -F "$'\r'"` 或等价写法，按 §3.1 "CRLF 断言"字样断言，不执行 workflow） |
| s15（改，upgrade 默认契约） | 保留原 exit 0 断言并扩展为双断言：空目录 `upgrade` exit 0（含升级纪律输出行）；健康实例 `upgrade` exit 0 且含漂移报告头（两个断言同属 s15——D2 修法：双断言落点在 s15，s31 只覆盖 `--check` 与 donot） |
| s31（新，upgrade） | 宇宙表（精确路径，见本表下方）：`.agents/notes/README.md`、`.agents/skills/README.md`、`.meta/docs-tier/README.md`、`.agents/skills/write-adr/SKILL.md`、`.agents/skills/write-adr/verify-note.sh`、`.agents/skills/governance-review/SKILL.md`、`.meta/gates/README.md`（条件写入：仅空目录时生成；gates 非空缺 README → 报"缺口"（缺骨架文件）而非"漂移"，见 D2 边界）、`.agents/skills/change-review/SKILL.md`、`.agents/notes/AGENTS.md`、`.agents/notes/archived/AGENTS.md`；① 健康实例（已填 constitution + 真实 README + 模板态 docs-tier）`upgrade` exit 0 且无"漂移"行；② 篡改一处宇宙内文件（如 notes/README.md 追加一行）→ 默认仍 exit 0 **含**漂移行、`--check` exit 非零；③ 无 `.meta/` → die 指引 init（**新编号 s31，不替换 s15 原 exit 0 断言**——D2 修法：s15 空目录用例保留，die 覆盖的是"有目录但无 `.meta/`"实例，二者 fixture 不同）；④ 非 git → WARN（exit 0）；⑤ 缺 meta.yaml/缺 level 行 → 按 L0 处理（空值/畸形仍走 0.4 语义，architect P1-6）；⑥ 漂移行前缀钉为 `drift:`，断言以它为靶子；⑦ 临时目录残留检查改为"报告内自证"（upgrade 输出末行打印 `tmpdir 已清理`，不断言 /tmp 全局 diff——flaky，architect P2-3） |
| s29（扩展） | README 示例 tag 与 `git describe --tags` 一致（本轮先 bump 到 v2.4.0 再打 tag，顺序见 §6）；CLI LEVELS 仍仅 L0-L5；`docs/AGENTS.md` 归属声明不断言（只文档化，不动 s14） |
| s12/s13/s28 | 选项 A 原子补丁：s12 四分支（undeclared=SKIP+WARN / off+decision=改写结论 / on+TODO=FAIL / 未声明+已激活=PASS）+ 结论行精确字符串；s13 加 `docs-tier: on` 合法键用例；s28 加 lv1+on 忽略断言；§172–176 诚实条款改写样文随 ladder 同提交 |
| 全量 | `bash tests/run.sh` fail=0；`verify-note.sh` exit 0；`ponygo status` 本仓 L1 exit 0 |

---

## 9. 验收标准

见 TASK-003（A1–A10）。补充说明（architect P0-5 修法）：**A5 去条件化**——本轮要么走完
WP-P（推 `v2.4.0` tag → 建 Release 传附件 → A5 端到端验证真链），要么 A5 整体移出门禁并在
TASK-003 标注 `blocked（未发布）`；不许"两种结局都算交代"。**严禁补 `v2.3.0` 附件**
（consultant Q3 理由 3：失实认证，且与 s29 版本一致性冲突）。
版本号推进顺序（architect P0-5 鸡生蛋解法）：实现合并进 main 并全绿 → README 示例 bump 到
`v2.4.0` → 切 tag `v2.4.0` → 建 Release → A5 验证。s29 在 bump 后、tag 前会红是**预期**，
以 tag 落点为准复核，不以中间态判死。

---

## 10. 审核记录与采纳/不采纳说明

| 审核轮 | 审核者 | 结论 | 记录 |
|---|---|---|---|
| proposed 评审 | 独立 reviewer（L2） | **不通过**（诊断成立、方案不可原样实施） | `reviews/review-TASK-003-l2.md` |
| proposed 评审 | 独立 reviewer（upgrade） | **不通过**（4 P0） | `reviews/review-TASK-003-upgrade.md` |
| proposed 评审 | 独立 reviewer（release） | **不通过**（无需 consultant） | `reviews/review-TASK-003-release.md` |
| spec rev1 | consultant 三选一裁决 | Q1=A（2.5 条件判据）、Q2=A（按 §3.2 落地）、Q3=A（按 §3.1 落地，新 tag `v2.4.0`，禁补 `v2.3.0` 附件，不可撤回风险由维护者承担，全绿前禁推） | `reviews/review-TASK-003-consultant.md` |
| spec rev1 | architect 独立对抗评审 | **不通过**（方向保留，按 P0 修完可复审） | `reviews/review-TASK-003-architect.md` |
| code | @code-reviewer-a（正确性） | **有条件通过**（无 P0；P1-1 引号值激活状态机 / P1-2 空 SHA 缺行为测试 → 已修） | 主会话收口记录（TASK-003.md §收口记录）+ s12/s30 新用例 |
| code | @code-reviewer-b（边界/失败路径） | **有条件通过**（无 P0/P1；P2-1 已激活 docs-tier 实例 --check 恒红 → 已修跳过比对 + s31⑦ fixture） | 主会话收口记录（TASK-003.md §收口记录） |
| code | security 快审 | **有条件通过**（无 P0；P1-1 action 钉 SHA / P1-2 install.sh 空 SHA fail-open → 已修；P2 四项全修） | 主会话收口记录（TASK-003.md §收口记录）+ release.yml/ci.yml 变更 |

> **版本漂移登记**：本 spec 写 `v2.4.0` 时基于 v2.3.0 时代；实施时 v2.5.0 已由 TASK-004 发布，
> 发布目标顺延为 **v2.6.0**（README `:54`、release.yml 头注同步）。s29 版本一致性断言在
> bump 后/tag 前红是预期（spec §9），以 WP-P tag 落点复核。

*（本节在双审后回填；重大回改后重新审核受影响产物。）*
