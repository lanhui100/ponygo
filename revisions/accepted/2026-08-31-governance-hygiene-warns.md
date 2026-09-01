# Revision: 治理卫生 WARN 三条 + bootstrap 第 0 步 git init + 决策时序成文（accepted）

Status: accepted

## 框架规则变更

1. **bootstrap 第 0 步「建载体」**：不在 git 仓库则先 `git init` 并提交骨架——版本派生、
   提交边界、"同一次变更"的锚定、L2 钩子挂载全部依赖 git。自证步（第 4 步）达标线
   从"无 FAIL"升级为"**无 FAIL 且无 WARN**"。
2. **决策时序成文**：write-adr 步骤 1 与 notes/README 触发规则补"先 ADR 后代码
   （先于或同一提交）；事后补记是债务"；时序本身诚实标注靠 review（git log 校准）。
3. **计划文档的家**：实施计划 = `proposed/` note（Proposal + Acceptance criteria）；
   禁止根目录游离 `*plan*.md` / `ROADMAP.md`。
4. **机械层三条卫生 WARN**（status/audit 双挂，不改退出码）：治理根已建但非 git 仓库 /
   根目录游离计划文档 / git 仓库内无 `.gitignore`。init 骨架开始生成最小 `.gitignore`。

## 采纳理由（回馈证据）

ponyllm 实例（Antigravity CLI agent）实证：bootstrap 四步全做（指引到达），但
(a) 项目无 git——"同一次变更"的时序锚在物理上不存在，先代码后 ADR 与先 ADR 后代码
产物不可区分；(b) 产出根目录 `IMPLEMENTATION_PLAN.md` 游离件——契约没说计划放哪；
(c) `target/` 裸放无 `.gitignore`。诊断结论：机械校验锁不住时序（语义，dsh 诚实条款
同款），锁得住的是"时序的可判定性载体"（git 存在）与形状（游离计划/缺 gitignore）。

## Alternatives considered

- **时序硬门禁（提交必须含 notes/ 变更）**：否决——diff 平凡性分类是语义判断，
  机械门禁一周即被关掉（dsh 诚实条款）；仅作 L2 选装示例并标注假阳性代价。
- **三条卫生项硬 FAIL**：否决——非 git 临时项目、合法 ROADMAP.md、无构建产物的仓库
  都是合法场景；WARN 是形状可查与价值靠 review 的正确分层（沿用 meta 违例键先例）。

## 影响面

- CLI 新增 `warn_governance_hygiene()`（status/audit 双挂）；write_skeleton 生成
  `.gitignore`（已存在不覆盖）；bootstrap_body 第 0 步与自证线；write-adr 与
  notes/README 双写。测试 s22 覆盖三条 WARN 正反面 + 干净场景无 WARN。
