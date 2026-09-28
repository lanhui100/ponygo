# Review 记录 —— TASK-003 code 双审 + security 快审（实施后）

> Task: TASK-003 ｜ spec: `docs/dev-team/specs/spec-ponygo-v2.4.md` rev3 ｜ 记录人: @orchestrator（主会话，转录子智能体结论与分级原样保留）
> 日期: 2026-09-14（续跑实施轮）｜ 审查对象: 工作树 diff（.meta/meta.yaml、README.md、install.sh、maturity-ladder.md、ponygo、tests/run.sh、.github/workflows/{ci,release}.yml）

---

## 结论总表

| 审复合 | 视角 | 结论 | 必须修项（合并闸） |
|---|---|---|---|
| @code-reviewer-a | 正确性/回归/可维护性 | **有条件通过**（无 P0） | P1-1 引号值激活状态机；P1-2 spec 强制测试缺失 + install.sh 空 SHA fail-open |
| @code-reviewer-b | 边界/失败路径 | **有条件通过**（无 P0/P1） | P2-1 已激活 docs-tier 实例 --check 恒红 |
| @security-reviewer | 发布链供应链/权限/注入 | **有条件通过**（无 P0） | P1-1 action 钉 SHA；P1-2 install.sh 空 SHA 不透明 |

三项均"有条件通过"，无 P0——核心设计面（2.5 状态机、upgrade 无执行面、发布 fail-closed + 最小权限）与 spec §3.1-3.3 对齐。

---

## code-reviewer-a（正确性）摘要

- **P1-1（真实行为缺陷，实测复现）**：`ponygo:1279` 原用 `tr -d '[:space:]"\r'` 归一 docs-tier 值，
  使 `docs-tier: "off"` 这类引号值**同时**被 warn_meta_violations 判非法键 WARN、又被 2.5 状态机当 off 兑现
  （实测输出：WARN 非法键 + 结论行"2.1–2.4 PASS；2.5 未启用" exit 0）——违反 spec §3.3
  "引号/非法值走违例键 WARN，不新增解析分支"。
  **处置：采纳**。值读取改只剥 `\r`（保留引号/空白），`case` 严格 `on|off`，任何变体落"未声明"支
  （保守方向）；补 s12 引号值回归用例（断言"非法键 WARN + 不写 off 结论行"）。
- **P1-2（spec §8 s30① 强制测试缺失 + install.sh fail-open）**：spec 要求"直调 `PONYGO_SHA256="" install.sh`
  → 安装拒绝"；实测 `install.sh:39` 空串视同未设置跳过校验。README 块守卫本身正确，installer 级未落实。
  **处置：采纳**。install.sh 用 `${PONYGO_SHA256+x}` 区分 unset 与显式空串（空串 → rm + die）；
  s30① 补动态断言（本地 cp 路径无网络，确定性可复跑）。
- P2：① `--check` 不把"缺口"算漂移（CI 漏删文件）→ **已修**（missing_n 并入 exit 判定）；② s30④⑤ 断言未落地 →
  **已修**（hex 断言 + raw 回验 + 口径 awk）；③ s12 缺 off+已激活 / on+无TODO / 引号用例 → **已修**；
  ④ spec §3.3 "off 须录 decision" 未落实 → **已修**（off 分支提示句 + s12 断言）；⑤ 汇总进缺失测试节。
- P3 清理：meta.yaml 头注口吻（"唯一内容字段"）→ **已修**；README "18+ 场景" 过时 → **已修**（31 场景）；
  DT_OFF/DT_SKIP 未 local（函数入口重置，风险低）→ 记录不修；多行 docs-tier 首行生效 → 记录；其余随行。

## code-reviewer-b（边界/失败路径）摘要

- **P2-1（已激活 docs-tier 实例）**：注文声称"只报其余九文件"，但循环遍历 10 个宇宙文件（含
  .meta/docs-tier/README.md），激活必改写该文件 → 合法激活实例 `upgrade --check` 恒 exit 1（CI 假红）。
  **处置：采纳**。已激活实例跳过该文件比对（s14 锁模板态，P0-1(a) 诚实声明），其余九文件照常；
  补 s31⑦ fixture（upgrade exit 0 不报 drift + --check exit 0）。
- P3：模板侧缺文件误报 drift（加"内部不一致"分支）→ **已修**；`ls -A` 把 .git/ 计入"有内容"
  （git-init 空仓库应温和跳过）→ **已修**（grep -v '^\.git$'）；s12 off+已激活 fixture 非单变量
  （混 TODO）→ **已修**（全新独立 case）；s31④ 依赖 mktemp 非 git 目录（套件整体假设）→ 记录不修；
  parser `--level` 吞值（畸形用法，非守卫绕过）→ 记录不修。
- 已验无问题：set -u 全变量初始化、空目录温和跳过、donot 三场景、--check/--dry-run 互斥顺序无关、
  s30 空 SHA 确定性、s29 多 tag/无 tag 稳定性（★确认 s29 红 = spec §9 预期中间态）。

## security 快审摘要

- **P1-1（action 钉 SHA）**：release.yml 的 checkout@v4 / action-gh-release@v2 为可变标签，该 workflow
  铸造全链信任锚 + job 级 contents:write，任一 action 被攻陷即可发布任意 ponygo+伪造哈希。
  **处置：采纳**。两 action 钉 commit 全 SHA（checkout `11d5960…` # v4；gh-release `3bb1273…` # v2），
  s30③ 断言改为 40 hex。
- **P1-2（install.sh 空 SHA 语义不透明）**：与 code-a P1-2 同一缺陷，处置同（显式空串拒绝 + WARN 分支）。
- P2：①README 裸 curl 标"推荐" → 改标"快速体验（无完整性校验）"；②发布端到端缺 raw 回验 →
  workflow 加回验 step；③ci.yml 无顶层 permissions → 补 `contents: read`；④tags: ['v*'] 过宽 →
  收紧 `v[0-9]+.[0-9]+.[0-9]+`（拒绝任意 v* 重推重铸哈希）。**全部已修**。
- P3 记录：2.5 重复键/一行混写告警一致性瑕疵（无 FALSE-PASS 注入逃逸）、upgrade 宇宙路径无 symlink/FIFO
  防御（无 RCE，只读 DoS 面）、UPGRADE_CHECK env 绕过 parser（仅 exit code）、CRLF 断言未覆盖 install.sh。
- 残余风险书面化：curl|bash 信任链起点（README 已诚实标注）、GitHub 托管/HTTPS 背书、
  install.sh 默认 main 回退分支（明示仅供未发布新版本使用）、--run-specs opt-in + 递归护栏 + timeout。

---

## 需升级 consultant 的分歧

无。三份审复合无相互冲突的 P0/P1；P2 处置全部采纳且互不矛盾。

## 复验证据

- `bash tests/run.sh` → **pass=339 fail=1**（唯一红 = s29 版本一致性 `v2.6.0 ≠ v2.5.0`，
  spec §9 明示"bump 后/tag 前红为预期，以 tag 落点复核"；WP-P 打 v2.6.0 tag 后应全绿）；
- `bash .agents/skills/write-adr/verify-note.sh` → exit 0（ADR 状态轴迁移后 1.1–1.9 全过）；
- 本仓 `bash ponygo status` → L1 / exit 0（骨架 + 级自洽全过，决策数 18→18 且 3 proposed → 3 implemented）；
- `ponygo audit --level M` → 9/14（基线唯一缺口"无本地钩子"保留，非本次引入）。