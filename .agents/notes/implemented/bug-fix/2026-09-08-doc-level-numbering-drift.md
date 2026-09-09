# Agent Note: 文档档位口径漂移（L0-L6 → L0-L5）修复与防复发断言

Status: implemented

## Problem

当前态文档对成熟度档位的口径与唯一真源 `maturity-ladder.md` 不一致：真源与 §5 判据 0.4 都是
L0–L5（枚举 `0-5`），但以下 **7 处**仍写 L0-L6 / `0-6`：

| 位置 | 内容 |
|---|---|
| `README.md` | status 命令说明（L0-L6）、目录树 meta.yaml 注释（整数 0-6）、合规免责（爬满 L6）、文件索引（L0–L6） |
| `.meta/meta.yaml` | 注释块「取值 = 0-6 的整数」+ 旧阶梯名（L3 文档分层/L4 流程资产/L5 负空间/L6 领域定制） |
| `.meta/constitution/constitution.md` | 槽位提示「整数 0-6」 |
| `ponygo` | `retire` 非法目标消息「用 0-6 或 off」——而 `case` 分支只接受 `[0-5]`，是**真实 bug** |

对以"文件夹即标签、不冗余声明、口径不一致以真源为准"立身的框架，这是自打嘴巴；且 s18 已把
checklist 计数口径钉成测试，档位口径却无任何看守。

## Decision

1. 修正上述 6 处，全部对齐真源 L0–L5 / 枚举 `0-5`。
2. **删副本而非保副本**：`.meta/meta.yaml` 不再复述六级阶梯，只留一句指针指向
   `maturity-ladder.md`——同一事实的第二份副本就是漂移源（`docs/AGENTS.md` slop 第一条：
   同一条规则出现在多个家时，留一个家、其余链过去）。
3. **防复发落到测试，不新建门禁**：`tests/run.sh` 场景 29 断言 4 个当前态文件（README /
   maturity-ladder / meta.yaml / constitution）不得出现 `L6` 与 `0-6`，并断言 `retire`
   的用户可见消息与 `case` 分支口径一致。CI 双平台已跑该套件。
4. **历史记录豁免**：`.agents/notes/`、`revisions/`、`docs/HANDOFF.md`、`docs/dev-team/`
   记的是当时的真值，一律**不改**——把历史改对是篡改证据，不是修漂移。`ponygo:34` 的
   「原 L4-L6 顺延为 L3-L5」是正当的历史映射说明，同样保留。

## Alternatives considered

- **新建 `.meta/gates/docs-parity.sh` + `.githooks/pre-commit` 挂载**：否决。它把"同一事实多副本"
  制度化（与 slop 第一条冲突），且该门禁断言的是本仓库专属文件、实例拿不到、无法复用；
  测试断言已在 CI 双平台执行，再加一层本地钩子是重复付延迟（P7）与多余维护税（P9）。
- **全仓扫描 `L6`**：否决。历史文档里的旧口径是证据不是缺陷，全仓扫描必然误报，
  用户会学会忽略告警（false-positive 疲劳本身是 L2 的退场条件）。
- **改真源回 L0-L6**：否决。判据 0.4 的枚举、`retire` 的 `case` 分支、
  `revisions/accepted/2026-09-02-doc-governance-frontloaded-to-l0-l1.md` 的重排决定都以
  L0-L5 为准，回退会造成更大的漂移。

## Consequences

- 档位口径的唯一真源 = `maturity-ladder.md`；其余家只准"指向"，不准复述区间。
- 新增当前态文档若复述旧口径，`tests/run.sh` 场景 29 会在 CI 拦下（本地跑 `bash tests/run.sh` 同样）。
- `meta.yaml` 注释由 10 行缩到 3 行，少一份与真源漂移的副本。
