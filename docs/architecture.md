# ponygo 架构地图

> 本文只描述当前组合、执行方向与扩展接缝。命令用法见根 `README.md`，设计理由见 `.agents/notes/`。

## 1. 入口与命令路由

`ponygo` 是单文件 Bash CLI。入口解析全局旗标后路由到 `init`、`audit`、`status`、`upgrade`、`sync`、`retire` 或独立的 `observe` 子命令组；非法旗标在进入写路径前拒绝。

## 2. 只读判定面

`audit` 与 `status` 共用项目状态读取、`verify_ladder` 判据、钩子接线和机读覆盖函数。
默认路径只读仓库：不执行仓内脚本；骨架模板在临时目录生成并用于漂移比对。
`audit --run-specs` 是唯一显式执行仓内负样本 spec 的开关。

执行方向：项目形状 → 四问评分 / 声明级判据 → 人读报告或单行 JSON → 原生退出码。
JSON 只序列化实际判定结果；未运行、证据不足与不适用不得投影为通过。

## 3. 写入与投影面

- `init` 播种或修复骨架，并装配本地 ADR 钩子；已有实例文件不得被普通修复覆盖。
- `sync` 把 `.meta/constitution/constitution.md` 投影到根 `AGENTS.md` / `CLAUDE.md` 哨兵区。
- `upgrade` 比较或刷新受管模板；实例化后的 docs-tier 清单不参与模板覆盖。
- `retire` 调整声明级；`observe init` 管理可观测性声明。
- 写路径使用临时文件、原子替换与适用的锁；`--dry-run` 只报告计划。

## 4. 治理载体接缝

- `.meta/`：机器态与治理真源（状态、constitution、gates、docs-tier）。
- `.agents/notes/`：活动与冻结决策；`.agents/skills/`：可复用流程及判定真源脚本。
- `docs/AGENTS.md`：通用文档标准；`.meta/docs-tier/README.md`：本仓实例路径。
- `.githooks/` 与 forge CI：门禁执行接缝；本地窄、远端全。

## 5. 扩展点

新增判据先登记到 `maturity-ladder.md`，再在唯一判定层实现并让 `status` / `audit` 复用。
新增实例门禁放 `.meta/gates/` 并配负样本 spec；新增流程只有达到复用阈值才进入 `.agents/skills/`。
新增文档事实先按 `docs/AGENTS.md` 选 tier，再只在 `.meta/docs-tier/README.md` 登记本仓路径。
