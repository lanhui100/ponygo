# Agent Note: upgrade 骨架漂移报告（暂缓）——比对宇宙未定义前不做

Status: proposed

## Problem

`ponygo upgrade` 是六命令面里唯一不做实事的命令：只打印升级纪律与 remote 列表
（`ponygo` 的 `cmd_upgrade`）。README 方式 C 以"方便跟随升级"为卖点，期望落差大
（EXTERNAL-001 P1-5 只做了措辞收敛）。

曾计划的解法：在临时目录用 `write_skeleton` 生成当前 CLI 的骨架，逐文件与实例比对，输出
`一致 / 漂移 / 缺失` 三态清单（只报告不合并）。TASK-002 的双审实测否决了这个形态。

## Proposal

先定义**比对宇宙**，再实现漂移报告：

- `template-owned`：框架保证逐字节一致的文件（`.agents/notes/README.md`、`notes/AGENTS.md`、
  `archived/AGENTS.md`、`skills/README.md`、`skills/*/SKILL.md`、`verify-note.sh`、
  `gates/README.md`）——漂移 = 真问题；
- `instance-owned`：实例本来就该拥有的文件（根 `README.md`、`meta.yaml`、`constitution.md`、
  激活后的 `docs-tier/README.md`）——不报；
- `mixed`：模板 + 允许的实例化变换（如 constitution 槽位、docs-tier 激活）——用标记块
  （`<!-- instance:begin/end -->`）断言"块外逐字节一致"。

清单落盘为可读真源（如 `.meta/skeleton-owned`），供测试与 `upgrade` 共用，避免"模板所有 /
实例所有"散在测试代码里。

## Alternatives considered

- **直接实现三态清单**：否决（实测）。健康实例第一次运行就报 ≥3 条假漂移：`constitution.md`
  （实例填槽 vs 最小模板）、`meta.yaml`（`level` 是实例状态）、`README.md`（真实 vs 占位）；
  叠加 40+ 实例独有文件与"模板独有"文件（根 `AGENTS.md`/`CLAUDE.md`，本仓库根本没有）。
  一个"全是误报"的报告会被永久忽略——这正是 `gates/README.md` 自己写过的教训。
- **改名 `ponygo guide upgrade` 或收敛命令面**：六命令是拍板不变量（HANDOFF 决策表），
  不改；只把期望落差写清（README 已收敛措辞）。
- **交付 v+2 自动合并**：风险不可控，且与"保留 git 血缘"的纪律冲突。

## Acceptance criteria

- 比对宇宙落盘为可读真源，`upgrade` 与测试共用同一份；
- 在健康实例（含已填 constitution、已激活 docs-tier）上运行，输出**零假漂移**；
- `tests/run.sh` 覆盖：一致 / 真漂移 / 缺失 / 实例合法分叉四类；
- 报告型命令，exit 0，且不落盘任何文件（含临时目录清理）。

## Risks

- 新增 `.meta/skeleton-owned` 是又一份需要维护的清单；若与 `write_skeleton` 的文件集漂移，
  报告本身会失真。缓解：加一条测试断言"清单 ⊇ 实际生成的文件集"。
- `mixed` 标记块机制会改动骨架模板与 s14 契约，属框架规则变更，需走 `revisions/`。
