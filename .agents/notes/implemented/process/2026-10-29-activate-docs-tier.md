# Agent Note: 模板仓自身启用文档分层（docs-tier: on）

Status: implemented

## Problem

`ponygo` 本仓升 L2 后，`meta.yaml` 未声明 `docs-tier` → 判据 2.5 处于 **SKIPPED + WARN** 状态，
`status` 每次打印「未声明 docs-tier …… 2.5 SKIPPED 不计入 PASS」。两个选项：

1. 声明 `docs-tier: off`（显式 opt-out）+ 一条 decision；
2. 真启用文档分层：`docs-tier: on` + 把 `.meta/docs-tier/README.md` 从模板态推进为
   「已激活文档家清单」，使 2.5 从 SKIPPED 变为实际 PASS。

用户裁决选 2。由此产生一个结构性张力：**本仓既是框架模板源，又要成为一个已激活实例**——
`s14` 双写断言与 `ponygo upgrade` 漂移比对都假定「仓库文件 = 模板态」。

## Decision

1. `meta.yaml` 增 `docs-tier: on`；`.meta/docs-tier/README.md` 改为激活版
   （标题 `## 已激活文档家清单`、九个 tier 全部填真实家、零 `【TodoPlaceholder】` 残留）。
2. **模板态仍由 `write_skeleton` 的 heredoc 提供**：`ponygo init` 生成的副本保持模板态
   （含待填占位），因此"新实例拿到的是模板、不是本仓激活版"。
3. `ponygo upgrade` 的 `dt_skip` 分支已能豁免该文件比对（既有实现，本次不改）；
   但 `s14` 的逐字节断言需按同一口径跳过，并**改为断言"生成物仍是模板态"**——
   这比原来的"生成物 == 仓库文件"更强：它防的是"激活版被当成模板污染新实例"。
4. 事故复盘 tier 不设独立 `docs/postmortem/` 目录：单维护者场景下"事故即一次决策"，
   复盘写在 `.agents/notes/implemented/bug-fix/`；另开一条轨道会与决策记录互相漂移。
   用户文档、how-to、生成参考等家按实际落地写在清单里（`README.md` / `checklists/` / `ponygo --help`）。

## Alternatives considered

- **保持 `docs-tier: off` + 一条 decision**：最省事，且符合 ladder §6「单人 + 轻 L2」画像。
  否决理由：本仓已具备 9 个 tier 的真实家（决策双轨、checklists、methodology、--help），
  再声明"不启用文档分层"与事实不符，等于用一条 decision 记下一个假的停止线。
- **保持未声明（继续 2.5 SKIPPED）**：否决——这会让 `status` 永久打印催声明 WARN，
  而本轮的目标之一正是"每条 WARN 都要有终止条件"，留着它就自相矛盾。
- **模板仓用副本激活、模板文件保持模板态（两处文件）**：否决。两份"文档分层契约"必然漂移，
  且读者无法判断哪份是权威；宁愿用"生成物断言仍是模板态"来防污染。
- **把 `s14` 直接删掉 docs-tier 那一组断言**：否决——那是放松而非改口径；
  正确做法是把断言从"等于仓库文件"改为"仍是模板态 + 本仓已激活"。

## Consequences

- `status`：2.5 由 SKIPPED 变为 **PASS**，`级自洽` 结论行不再有 SKIPPED 尾巴（L0-L2 全 PASS）。
- `upgrade --check`：继续对本文件豁免（`dt_skip`），零漂移。
- **代价（明确接受）**：本仓的 `.meta/docs-tier/README.md` 不再是模板。任何"手抄本仓文件去初始化新仓"的
  做法都会拿到激活版；正确入口只有 `ponygo init`。该告警已写入文件头。
- `s14` 契约演进：docs-tier 组由"生成物 == 仓库模板"改为"生成物仍为模板态 ∧ 本仓已激活"，
  断言强度不降反升；改动需在测试侧留痕（本轮 `tests/run.sh` 同步）。
- 后续若要设词数预算（doc-sync 门，L2 选装），把数值写进 README 的「词数预算」节，不留占位。
