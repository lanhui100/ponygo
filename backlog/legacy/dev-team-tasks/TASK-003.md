# TASK-003 —— 落实三条 proposed ADR（L2 判据矛盾 / upgrade 漂移报告 / 发布校验和自动化）

| 字段 | 值 |
|---|---|
| Task ID | TASK-003 |
| 状态 | Done（实施完成；全量回归 pass=339 fail=1（唯一红 = s29 版本一致性中间态，WP-P 打 v2.6.0 tag 后复核绿）；verify-note exit 0；status L1 exit 0；双代码复审 + security 快审闭环） |
| 复杂度 | B（跨 CLI 判据 / 骨架模板 / workflow / 测试 / 发布动作；含两处框架规则语义） |
| 负责人 | orchestrator（主会话）+ 子智能体评审团 |
| 创建时间 | 2026-09-14 |
| spec | `docs/dev-team/specs/spec-ponygo-v2.4.md`（**rev3** 实施依据） |
| review | `reviews/review-TASK-003-{l2,upgrade,release,consultant,architect}.md`（rev1 双审）+ code 双审/security 结论（主会话汇总，见收口记录） |

## 背景

上一轮（TASK-002，commit `b8b7e28`，tag `v2.3.0` 未推）留下三条 proposed ADR，均经独立对抗评审，
结论**全部不通过**（方向保留，重切后可实施）：

| 提案 | 评审结论 | 关键否决点 |
|---|---|---|
| `2026-09-08-l2-minimal-representable.md`（2.5 改条件判据） | 不通过 | meta.yaml 铁律冲突 + 默认 SKIP 门禁空心化 + SKIPPED 语义冲突；需升级 consultant 三选一 |
| `2026-09-08-upgrade-drift-report.md`（漂移报告） | 不通过（4 P0） | 比对宇宙路径错 + `.meta/skeleton-owned` 第三副本 + 问错方向（"缺失才写"语义下基线不存在） |
| `2026-09-08-release-checksum-automation.md`（校验和自动化） | 不通过（无需 consultant） | README 主路径 fail-open（空 SHA 跳过校验）+ 死链当推荐 + 口径未钉裸哈希 |

现状基线：`ponygo status` = L1 / exit 0；`audit --level M` = 9/14（唯一缺口"无本地钩子"，保留）；
本地 `v2.3.0` 已打、`ls-remote` 远端无 tag、工作树干净；`gh` 已认证（`lanhui100`，scope 含 `repo`）。

## 目标

按 spec 实施 R（release）/ U（upgrade）/ L（L2）三包；推 tag 建 Release 让安装路径端到端可验证；
全量回归绿后提交并推送。

## 非目标

- 不做 `upgrade` 自动合并（v+2 能力）；不改六命令面；不动 `docs/HANDOFF.md`；
- 不升本仓库 level（停 L1，§6 停止线裁决延续）；
- 不引入 mixed 标记块机制（框架规则变更太大，留待独立提案）。

## 验收标准

| # | 判据 | 验证命令 |
|---|---|---|
| A1 | consultant 裁决书落盘（三问三选一） | `reviews/review-TASK-003-consultant.md` 存在且三问均有明确选项 |
| A2 | README 安装主路径 fail-closed | `tests/run.sh` s30①：可 SHA → 空串拒绝 + README 静态守卫断言 |
| A3 | installer 与载荷同钉 tag | `tests/run.sh` s30②：README bootstrap 行与 PONYGO_VERSION 同钉 `v2.6.0` |
| A4 | release workflow 口径 = 裸哈希 + 钉 Linux + 最小权限 + action 钉 SHA + raw 回验 | `tests/run.sh` s30③④⑥（workflow 六断言） |
| A5 | 附件发布后安装路径端到端可验证 | WP-P：`PONYGO_VERSION=v2.6.0 PONYGO_SHA256=<附件值>` 安装成功 |
| A6 | `upgrade` 零假漂移 + `--check` 供 CI | s31：健康实例 exit 0 无漂移行；篡改/缺口 → 默认 0、`--check` 非零 |
| A7 | donot 三场景有定义且测试覆盖 | s31：空目录温和跳过/非空 die；非 git WARN；无 level 按 L0 |
| A8 | L2 按裁决落地，§1/§5/§6 口径一致 | s12 四分支六用例 + s13 新键 + s28 作用域；`ponygo status` 本仓仍 L1 exit 0 |
| A9 | 全量回归绿 | `bash tests/run.sh` fail=0（s29 版本一致性以 tag 落点复核）；`verify-note.sh` exit 0 |
| A10 | ADR 拆条与迁移 | implemented 口径 ADR×3 + revisions×2 + 旧 proposed 迁移/归档 |

## Next Action

~~spec 双审（含 consultant 裁决）→ 按裁决实施 R/U/L → 双代码复审 + security 快审 → 全量回归 → 提交推送。~~
已收口（2026-09-14 续跑）。WP-P（打 tag `v2.6.0` → push → 建 Release）由维护者执行，用户已授权完整发布。

## Resume Hint

若中断：读 `spec-ponygo-v2.4.md` §10 审核记录表看哪一包已落地；`git status --short` 确认工作树；
`bash .agents/skills/write-adr/verify-note.sh` 确认 ADR 格式门。

## 收口记录（2026-09-14 续跑，主会话实施轮）

- **实施**：L 包（2.5 条件判据：docs-tier 键 + 白名单 + 严格 on|off 匹配 + 结论行改写 + ladder §1/§5/§6/§附）、
  U 包（cmd_upgrade 漂移报告：宇宙十文件 + 缺口 + `--check` + donot 三场景 + tmpdir 自证）、
  R 包（README fail-closed + bootstrap 同钉 `v2.6.0` + install.sh 空 SHA 拒绝 + release.yml + s30）。
- **双代码复审**：code-reviewer-a（正确性）有条件通过；code-reviewer-b（边界/失败路径）有条件通过；
  security 快审有条件通过。P0 均无。
  - code-a P1-1 引号/畸形 docs-tier 值不得兑现 on/off（去掉 tr -d '"'，严格 case）→ 已修 + s12 引号用例；
  - code-a P1-2 + security P1-2 spec s30① 空 SHA 动态断言 + install.sh fail-closed（`${PONYGO_SHA256+x}` 显式空串拒绝）→ 已修 + s30① 动态用例；
  - security P1-1 release.yml 第三方 action 钉 commit 全 SHA（checkout `11d5960…`、gh-release `3bb1273…`，附 # v4/# v2 注释）→ 已修 + s30③ 断言放宽为 40 hex；
  - code-a P2-1 `--check` 对缺口（宇宙文件缺失）也非零 → 已修（missing_n 并入 exit 判定）+ s31 断言；
  - code-a P2-2/P2-3 s30④⑤ 与 s12 缺分支（off+已激活 WARN、on+已激活无 TODO）→ 已补；
  - code-a P2-4 off 须录 decision → CLI 提示句 + s12 断言；
  - security P2-1 README 裸 curl 改标"快速体验（无完整性校验）"；P2-3 ci.yml 顶层 `permissions: contents: read`；
    P2-4 release 触发收紧 `v[0-9]+.[0-9]+.[0-9]+`（拒绝任意 v* 重推重铸）；P2-2 workflow 加 raw 回验 step → 全部已修；
  - reviewer-b P2-1 已激活 docs-tier 实例不参与 docs-tier/README.md 比对（否则合法激活实例 `--check` 恒红）→ 已修 + s31⑦ fixture；
  - reviewer-b P3：模板侧缺失报"内部不一致"、git-init 空仓库温和跳过、s12 off+已激活单变量 → 已修；P3-4（mktemp 非 git 假设）/P3-5（--level 吞值）记录为残余，不修。
- **验证**：`bash tests/run.sh` → **pass=339 fail=1**（唯一红 = s29 版本一致性 `v2.6.0≠v2.5.0`，
  spec §9 明示"bump 后/tag 前红是预期，以 tag 落点复核"——WP-P 打 tag 后应全绿）；
  `verify-note.sh` exit 0；本仓 `ponygo status` L1 / exit 0；audit M 档 9/14（基线缺口"无本地钩子"保留）。
- **ADR**：三条旧 proposed 迁移 implemented（`2026-09-14-{l2-conditional-docs-tier,upgrade-drift-report,release-checksum-chain}.md`，
  process 类）；`revisions/accepted/` 新增两条（2.5 条件判据 + upgrade 漂移报告规则）。
- **版本漂移**：spec 全文写 `v2.4.0` 时基于 v2.3.0 时代；实际实施时 v2.5.0 已由 TASK-004 发布，
  发布目标顺延为 **v2.6.0**（README `:54` 已同步）。
