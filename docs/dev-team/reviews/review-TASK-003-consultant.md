# consultant 裁决 —— TASK-003（三问三选一）

> Task: TASK-003 ｜ spec: `docs/dev-team/specs/spec-ponygo-v2.4.md` rev1 ｜ 裁决人：@consultant（最终把关）
> 日期：2026-09-14 ｜ 前提：三条 proposed ADR 经独立对抗评审全部**不通过（方向保留）**，
> 证据：`docs/dev-team/reviews/review-TASK-003-{l2,upgrade,release}.md`
> 基线核实方法：本裁决前已用 read/grep/pwsh 亲自核实下述证据，未采信转述。
> 基线快照：`git tag` 本地仅 `v2.3.0`、`ls-remote --tags origin` 为空（已实测）；
> `ponygo` 约 1705 行；`cmd_upgrade` 为空纪律打印机；`upgrade` 无 `--check` 参数；
> `release.yml` 不存在（仅 `ci.yml` 双平台自测门）。

## 基线证据索引（裁决理由引用源）

- E1 `ponygo:271`：`meta.yaml` 生成注释"唯一真值源：level"；`ponygo:1077-1086`
  `warn_meta_violations` 白名单 `grep -vE '^(level|ai-surface):'`，status 与 audit 双挂
  （`ponygo:1513,1577`）；`maturity-ladder.md:110` 铁律注释"合法键 = level + ai-surface"；
  `README.md:109,119` 同口径。
- E2 `ponygo:1258-1265`：2.5 硬判 `grep -q '## 已激活文档家清单'`，模板态即 `vl_fail`，
  缺文件亦 `vl_fail`；`maturity-ladder.md:145` 判据 2.5 行、` :149` 模板态→已激活语义、
  ` :16` §1 总表 L2 行"文档分层已激活"、` :162` §6 停止线"保留 L1 + 上最轻的 L2
  （仅 format 门禁，不上 classification / 冻结 / 文档分层）"——§5 与 §6 矛盾实锤；
  ` :172-176` 附诚实条款（§1 validation"机械"当且仅当 §5 命令能跑）。
- E3 `ponygo:1608-1621` `cmd_upgrade` 现状：只打印三行升级纪律 + remote 列表，无 diff、
  无 exit 语义分支、无 `has_meta` 检查；`tests/run.sh:557-561` s15 锁死 `upgrade exit 0`。
- E4 `ponygo:270`（`if [ ! -f "$META_YAML" ]`）与 `:274-279`"不覆盖既有文件，只在缺失时生成"——
  `write_skeleton`"缺失才写"语义实锤；`tests/run.sh:489-555` s14 十文件逐字节断言
  （notes/README、skills/README、docs-tier/README、write-adr/SKILL、
  write-adr/verify-note.sh、governance-review/SKILL、gates/README、
  change-review/SKILL、notes/AGENTS、archived/AGENTS）。
- E5 `install.sh:39-53`：`[ -n "${PONYGO_SHA256:-}" ]` 非空才校验、
  `sha256sum | awk '{print $1}'` 裸 hex 比对、失配 `rm -f + die`、无工具 `die`（fail-closed 实锤）；
  `README.md:49` 主命令 `SHA=$(curl .../releases/download/v2.3.0/ponygo.sha256 | awk ...)` 无
  `pipefail`、无 `[ -n "$SHA" ]` 守卫，`:51-52` installer 取 `main/install.sh` 浮动、
  `:55-57` 维护者裸哈希口径 + "未公布前默认路径仍可用"。
- E6 `tests/run.sh:418` s12、` :462` s13、` :980` s28、` :1003` s29；
  `.github/workflows/ci.yml:1-37` 仅自测门（无 release workflow）。

---

## Q1（L2 判据矛盾）：选项 A —— 2.5 改条件判据

**裁决：选 A。否决 B（L1.5 改名）、否决 C（删 §6 轻 L2 行）。**

### 裁决理由

1. **§6 与 §5 矛盾真实存在，删建议（C）等于删真实中间态。** E2 证明 §6`:162`
   承诺"不上文档分层"的轻 L2 可存在，而 §5`:145` + `ponygo:1261-1262` 要求
   `level>=2` 硬过 2.5——照 §6 行事的单实例 `status` 必 FAIL。C 用"停在 L1"消解矛盾，
   丢掉了"单人高决策密度、只上 format 门禁"这一 dsh 实证中间态（旧提案 Alternatives
   已自认此代价）。价值判断：保留中间态 > 删行省事。
2. **B 把门禁语义污染 L1，架构更差。** B 要求"声明只用目录内容态、轻量改称 L1+门禁"，
   但 L1 判据（1.1–1.9，全是入册/有家形状）从未含"门禁可跑且拒绝非法样本"语义；
   把 format 门禁塞进 L1 等于让 L1 同时承担"入册"与"承诺可验"两种 validation，
   违反 §1 总表每级单一核心产物划分（E2 `:14-16`）。A 反而保持分层纯洁：
   L2 仍是"承诺可验"级，只是 2.5 变为显式状态机的一支。
3. **P0-2（默认 SKIP 门禁空心化）已被 spec 的 A 形态正面回应，B/C 不用回应不等于更好。**
   L2 评审 P0-2 原话"理性实例永不声明，L2 事实退化为 2.1–2.4；SKIP-exit-0 就是 WARN 改名"。
   spec §3.3 的 A 不是旧提案的"未声明即 SKIP"：undeclared = SKIP **+ WARN 催声明**；
   off = 显式 opt-out **须录 decision 且结论禁写"全部 PASS"**（改写为
   "2.1–2.4 PASS；2.5 未启用"）；on + TODO 残留判 FAIL；off+已激活→矛盾 WARN；
   undeclared+已激活→PASS（实际做到优先于声明）；§1 与 §172–176 诚实条款同步改。
   在此形态下 exit 0 不再机械等价"全部 PASS"——结论字符串被精确锁定，
   s12 须加结论行精确字符串断言（E6 s12 联动）。理性沉默者会被每次 WARN 催声明，
   沉默豁免激励已 priced-in（spec §7"SKIPPED 常态化对策"）。
4. **与 v2.0"文档治理前置"无冲突，优先级已可裁定：v2.0 保 0.5/1.9，A 只动 2.5。**
   v2.0 核心决定是文档最小家前置到 L0/L1（`ponygo:274` 注释、判据 0.5/1.9），
   A 不动 0.5/1.9，只把 L2 的"已激活清单"（E2 `:149` 明确为 doc-sync 门依赖前的形状判据）
   改为条件判据。旧提案 Risks 自认的张力实质是误读：前置的是"有家"，
   条件化的是"分层激活"——两层不是同一物。故优先级裁定：**v2.0 前置继续有效；
   2.5 条件化在此约束下实施；若实施中发现 0.5/1.9 被弱化，立即回滚 A。**
   附加铁律条件（缺一即否决实施）：原子补丁必须全套同提交
   （1082 白名单 + E1 铁律注释 + s12 四分支 + s13 新键用例 + s28/s29），
   否则 s13 先红（L2 评审 P1-3）；标记文件须封闭命名（目录下已有 `exemptions`，
   通配"存在即声明"会误触发，评审遗漏边界条）。

---

## Q2（upgrade 漂移）：选项 A —— 按 spec §3.2 落地

**裁决：选 A。否决 B（连 mixed 标记块一起做）、否决 C（继续暂缓）。**

### 裁决理由

1. **"无基线单列"方向正确，在本宇宙内真能零假漂移。** E4 实锤 `write_skeleton`
   全员"缺失才写"：对 init 时已存在的文件（真实 README、已填 constitution、
   已有 `.gitignore`），模板从未成为基线，拿 tmp 重生成模板去 diff 是范畴错误
   （upgrade 评审 P0-2）。spec §3.2 的解法不是"三类划分治标"，而是釜底抽薪：
   比对宇宙 = s14 十文件精确路径（E4 `tests/run.sh:489-555`），根 README /
   meta.yaml / 已填 constitution **根本不在宇宙内**——"无基线单列、不判漂移"
   只是对宇宙外文件的诚实标注，不是对宇宙内文件的放水。健康实例
   （已填 constitution + 真实 README + 模板态 docs-tier）零"漂移"行是机械真命题。
   唯一诚实例外已声明：已激活 docs-tier 实例**不支持**（选 P0-1(a)，s14 `:506-511`
   逐字节锁模板态，激活即破 s14——不发明新激活机制，不假装支持）。
2. **`--check` 与 s15 无冲突：默认守 s15，新契约 opt-in。** E3 实锤 s15 只锁了
   `upgrade` 默认 `exit 0`，而漂移是**观察**不是承诺（status 管骨架缺口 exit 1，
   upgrade 管"与模板差多少"；upgrade 评审 P3-1 要求写清此差）。spec 语义：
   默认报告 exit 0（s15 原断言保留）；`--check` 漂移→非零，供 CI，
   复用 `audit --run-specs` 的 opt-in 范式（`ponygo:1692-1695` 约束"只读命令不执行
   仓库脚本"的前例）。实施时 s15 必须同步扩展为双断言
   （默认 exit 0 含漂移行 + `--check` exit 非零），否则视为未完成——冲突是
   "未更新测试"，不是"语义互斥"。
3. **B 是框架规则变更，不可搭车。** mixed `<!-- instance:begin/end -->` 标记块要求
   同提交改模板 + s14 契约 + 激活程序（现行激活是"改标题为已激活 + 填 TODO 表"，
   E2 `ponygo:844-846` 注释），且既有实例文件无标记→全量误报、迁移面未定义
   （upgrade 评审 P1-2/P2-1）。spec §2 非目标已明排除，`revisions/` 独立提案才是
   正道。把 B 塞进本次等于用十文件小报告绑架激活机制重切，否决。
4. **C（暂缓）保留的是空命令，价值为零。** E3 `ponygo:1608-1621` 现状 upgrade
   只打印升级纪律，无 `has_meta` 检查、非 git 仅打印提示（upgrade 评审 P1-4），
   donot 三场景（无 `.meta/`→die 指引 init，对齐 retire/status；非 git→WARN，
   对齐 status；无 level→按 L0 处理）无一定义。A 的 donot + 报告头
   （引用 TASK-002 双审出处，纠正"假漂移"归因，upgrade 评审 P1-1）是纯增量函数，
   可整函数 revert，风险不对称地低。暂缓只保住"措辞收敛"的幻觉。

---

## Q3（release 发布）：选项 A —— 按 spec §3.1 落地（含推 tag 建 Release 做端到端验证）

**裁决：选 A。否决 B（只做本地部分）、否决 C（只修 README）。版本号：新 tag `v2.4.0`，
严禁补 `v2.3.0` 附件。"发布后不可撤回"风险由维护者（repo owner，`gh auth` 示 `lanhui100`）承担，
实施者不得在双审全绿前推 tag。**

### 裁决理由

1. **不端到端验证等于语义空转，B 的"本地可验证"正是评审否决的 P2-1。**
   release 评审 P2-1 原话：不推 tag 只能做 YAML 文本形状断言；测试须拆三断言
   （静态管线 / 本地动态复跑 diff / hex `^[0-9a-f]{64}$`）。B 止步于此，
   远端获取路径（`README.md:49`）是否 404 永不被证伪，"首次发布后验证"的
   无负责人延期（被挑战假设 4）会永久化。A 的 WP-P（推 tag → 建 Release →
   端到端验证 → 提交推送）是唯一让 `curl releases/download/...` 从死链变活链的路径。
2. **P0-1/P0-2 是 fail-closed 生死线，C 的"只修 README"不够。** E5 实锤两端矛盾：
   `install.sh:39-53` fail-closed（空 SHA 跳过？不——非空才校验但一旦设值即整串
   比对、失配删文件；README 管道 `curl -fsSL ... | awk` 失败后经 awk exit 0 置空，
   下游被视为未设置而跳过校验）= 主路径 fail-open；且 `ls-remote` 为空而 README
   首命令块即取 `v2.3.0` 附件 = 死链当推荐。spec §3.1 必修项
   （`set -o pipefail` + `[ -n "$SHA" ] || exit 1`、未发布诚实标注、installer 同钉
   tag 变量、裸哈希管线钉死、对象 = checkout blob + `grep $'\r'` CRLF 断言、
   顶层 `permissions: {}` + job 级 `contents: write` + action 钉 SHA）缺一即维持不通过。
   C 只做"README 守卫与口径"丢掉了 installer 同钉（P1-1 全链失守）与 workflow
   最小权限（P1-3），不予接受。
3. **版本必须新切 `v2.4.0`，补 `v2.3.0` 附件是失实认证。** 本地 `v2.3.0`
  （`b8b7e28`）是 TASK-003 实施前的旧提交：它不含 fail-closed 守卫、
   不含 installer 同钉、不含 CRLF 断言 workflow。若给旧 commit 补发附件，
   等于用新口径为旧代码背书，且与 s29"版本号示例一致性"断言
   （README 示例 tag == git 最新 tag 语义，spec §8）直接冲突——下次 bump 必漂。
   正确链：WP-R/U/L 合并进 main → 全绿（`bash tests/run.sh` fail=0、
   `verify-note.sh` exit 0、本仓 `status` L1 exit 0）→ 从绿 main 切新 tag
   `v2.4.0` → 建 Release 传附件 → 跑 A5 端到端（附件发布后可验证）。
   spec §9 已预留"补充说明：A5 的 v2.4.0 以实际发布版本为准"，本次明确为新 tag。
4. **风险归属：维护者承担，实施者设门。** spec §7 已明示"tag/Release 发布后不可撤回——
   发布前必须全绿"。裁决细化：① 推 tag 的唯一责任人是维护者（`lanhui100`），
   consultant 不授权实施者在 code 双审（@code-reviewer-a/b + security 快审，
   spec §10 待补）完成前推 tag；② 预发布 checklist（s30 五断言 + s31 六断言 +
   s29 版本一致性 + CI ubuntu+windows 双绿）任一红即禁推，失败则 Release 不建、
   README 诚实标注保持（spec §7 缓解列）；③ 远端已存在境外超时探测史
   （release 评审取证基线"受限网络下超时"），端到端验证步骤必须记录
   `curl` 探测输出原文（含失败原文），不得写"几乎 surely"式断言。

---

## 三问总表

| 问 | 裁决 | 一句话 |
|---|---|---|
| Q1 L2 判据矛盾 | **A：2.5 改条件判据**（undeclared=SKIP+WARN；off=显式 opt-out 须录 decision 且禁"全部 PASS"；on+TODO 残留 FAIL；白名单+铁律+s12/s13/s28/s29 原子补丁；§1 与 §172–176 同步） | 保住真实中间态；P0-2 用 WARN+精确结论行定价；v2.0 前置（0.5/1.9）不受影响 |
| Q2 upgrade 漂移 | **A：按 spec §3.2 落地**（宇宙 = s14 十文件精确路径；"无基线"单列不判漂移；已激活声明不支持；默认 exit 0 + `--check` opt-in；donot 三场景） | 范畴错误用"宇宙外置"根治；s15 用双断言扩展，无语义冲突；mixed 走独立 revisions |
| Q3 release 发布 | **A：按 spec §3.1 落地**（README 守卫 + 同钉 tag + workflow 裸哈希/Linux/CRLF/最小权限 + 三断言测试 + **新 tag `v2.4.0` 推 tag 建 Release 端到端验证**） | 不验证即空转；禁补 `v2.3.0` 旧附件；不可撤回风险由维护者承担，全绿前禁推 |

*实施顺序建议：WP-L（A 的原子补丁）与 WP-R 静态部分可并行（文件不相交）；
`tests/run.sh` 单一实施者串行（spec §6 并行边界，TASK-002 rev2 P1-5 教训）；
WP-P 推 tag 为最后一步，以双审全绿为门。*
