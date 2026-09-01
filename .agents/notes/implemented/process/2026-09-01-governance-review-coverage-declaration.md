# Agent Note: governance-review 审查覆盖缺口显性化与补齐

Status: implemented

## Problem

governance-review 技能（`.agents/skills/governance-review/SKILL.md`）预置于 `ponygo init` 骨架是合理的（决策见 `revisions/accepted/2026-09-01-preset-governance-review-skill.md`），但对照 `docs/methodology.md`（dsh 实证方法论）的治理审计维度，其"五面审查"存在覆盖缺口，且缺口是**隐性的**——用户发起"治理体检"时，报告的"全面"措辞会让人误以为以下维度已被审查：

1. **负空间 / 归档退场**（methodology 审计问题四）：陈旧 implemented note 是否挤掉当前事实、supersession 债务、`.rgignore` 归档隔离——skill 完全未触及；
2. **流程资产自身健康**：`.agents/skills/` 不在审查对象内（技能触发 description 是否失真、校准样例是否漂移、技能是否还有真实消费者——L4 退场条件）；
3. **文档分层漂移（L3）**：仅"游离计划文档"浅触，tier 放置 / slop / 重复事实不查；
4. **methodology 自认的界外 6 项**（供应链安全、可观测性、发布管理、环境可复现、API 契约治理等）无任何声明；
5. **证据命令集偏薄**：无项目自身测试门禁的命令，"治理承诺是否被 CI/测试守住"无锚。

隐性盲区违背 P6 形意分离的诚实原则（机器/程序到不了的地方必须显式标注），也违背 governance-review 自身"盲区声明"面的同一精神。

## Decision

`.agents/skills/governance-review/SKILL.md` 已做如下修改，并同步更新 `ponygo` 脚本内 write_skeleton 的 heredoc 模板（与 `.agents/skills/` 副本逐字节一致，s14 测试约束）：

1. **显性边界声明**：新增「本审查不覆盖」节，列出文档分层漂移（L3）、methodology 界外项（供应链安全/可观测性/发布管理/环境可复现/API 契约治理）、语义真实性终审三类缺口，并要求报告末尾原文复述本节——把隐性盲区变为显性声明；
2. **负空间面**：新增审查面——`find .agents/notes/implemented -mtime +180` 陈旧 note 初筛（仅作候选）+ 近 90 天 supersession 对照（`git log --since`）+ `.rgignore` 归档隔离检查；归档/保留判断标"靠 review"；
3. **流程资产面（元审查）**：新增审查面——审 `.agents/skills/` 自身的触发 description、校准样例锚定、真实消费者（按 L4 退场条件）；
4. **证据命令集**：补项目测试门禁命令（`bash tests/run.sh` 或项目等价物，无则声明"无测试门禁"），并加"命令不可解析环境降级为 review、不得假装跑过"的诚实条款；
5. **校准样例**：补负空间面正例、"初筛结果当结论"反例、"不复述不覆盖节"反例（隐性盲区）。

## Alternatives considered

- **维持现状，不加声明**：否决——隐性盲区让用户高估"治理体检"结论的覆盖面，产出虚假安全感，与 P6 诚实条款冲突。
- **只做补齐，跳过显性声明**：否决——负空间面的语义部分（supersession 是否同变更处理、note 是否"陈旧到该归档"）判据管不到，补齐后仍有残余盲区；不先声明则盲区依旧隐性。
- **只做声明，永不补齐**：可选但次优——本轮采纳"声明 + 补齐"一次落地；后续若审查膨胀可按 maturity-ladder §3 菜单式回退。
- **把缺口做成新的独立技能（如 archive-review）**：否决——dsh 的 `dsh-archive-agent-notes` 是高频专用流程，ponygo 项目当前归档活动密度远未达 Rule of three；作为 governance-review 的一个审查面成本最低，达到三次重复后再按 L4 拆出。

## Consequences

- `ponygo init` 新生成的骨架与既有项目的 `.agents/skills/governance-review/SKILL.md` 同为新版内容；tests/run.sh 既有断言（s02 存在性 + 禁自主路由、s14 逐字节一致）无需改动，已用逐行比对确认 heredoc 与副本全等（75 行）。
- 本机无 bash、WSL 拒绝访问，`verify-note.sh` / `tests/run.sh` / `ponygo status` 未能在本机机械执行——按 SKILL.md 自身的诚实条款，此轮验证降级为 review（PowerShell 手工复核 L1 判据 1.1–1.8 通过）；到有 bash 的环境须补跑一次全套机械验证。
- 审查面从五面扩到七面，重型流程更重——若后续出现"用户嫌重不愿点名"的信号，按 L4 退场/降级判据处理并记录。
