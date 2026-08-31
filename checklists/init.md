# checklists/init.md —— 冷启动（新项目 / 有代码无治理）

> 给**从 0 开始**或**有代码但无治理**的项目。目标：以最小骨架转到 L0→L1，"宁可粗糙、不可缺席"。
> 每一步动作都指向 ponygo 已交付的骨架文件；凡指向"未来才有的生成器"的步骤，一律删除或标 TODO。

---

## 前提判断（先跑这几条）

```bash
ponygo status        # 若报缺少 .meta/，进入下方流程；若已存在，则不该走 init（转 audit）
git rev-parse --is-inside-work-tree 2>/dev/null   # 是否在 git 仓库内
```

---

## 步骤清单（逐项勾选）

### 阶段 A：铺骨架（机械，`ponygo init` 完成）

- [ ] 运行 `ponygo init`，确认它正确识别了"空项目 / 有代码无治理"两场景之一
- [ ] 验证骨架落地：`ponygo status` 应显示 `[ok]` 满格、`level: 0`
- [ ] 核对 `.meta/meta.yaml` 只有 `level: 0` 一个字段（版本/组件别手填，git 和目录说了算）

### 阶段 B：填宪法槽位（人做，1 次）

- [ ] 编辑 `.meta/constitution/constitution.md`，填 4 个槽位（项目名 / 一句话定位 / 技术栈 / 成熟度目标）
- [ ] 勾掉常载命约里不适用项，但保留最少 3 条预设命约
- [ ] 确认停止线理解到位：`level` 是硬上限，达到前不抢跑下一档

### 阶段 C：投影（机械）

- [ ] 运行 `ponygo sync`，把填好的宪法投影到根 `AGENTS.md` / `CLAUDE.md`
- [ ] 验证投影标记区存在：`grep -l "BEGIN constitution" AGENTS.md CLAUDE.md`

### 阶段 D：写下第一篇决策（升 L1 的起手）

- [ ] 用骨架预置的 `.meta/skills/write-adr/SKILL.md`（框架交付的唯一预置技能）落第一篇 ADR：
  `implemented/{class}/yyyy-mm-dd-<topic>.md`（或先 `proposed/`）
- [ ] 确保头部两行 `# Agent Note: <title>` + `Status: implemented`，正文有 `## Problem` 和 `## Alternatives considered`

### 阶段 E：复核（机械）

- [ ] `ponygo status` —— 决策数应 ≥ 1，去 L1 的提示应出现
- [ ] `ponygo audit --level S` —— 骨架层应基本命中

---

## 停手条件

- **槽位未填完** → 别投影、别抢跑，回到阶段 B。
- **规模太小（单文件脚本/一次性原型/无持续维护者）** → 别建 `.meta/`，见 README §6.1 停止线。

---

## TODO（未来从 ponygo 回收的自动化）

- [ ] init 后自动填槽（交互式问项目名/定位/栈）——当前用 sed 手填
- [ ] init 后自动写第一篇决策模板——当前手写
