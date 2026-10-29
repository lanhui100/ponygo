# Revision: 模板仓自身启用文档分层（docs-tier 激活）与 s14 口径演化（accepted）

> 类型：框架自身演进（吃自己的狗粮）。日期：2026-10-29。实例决策见
> `.agents/notes/implemented/process/2026-10-29-activate-docs-tier.md`。

## Problem

`ponygo` 本仓升 L2 后，`docs-tier` 未声明 → 判据 2.5 恒为 **SKIPPED + WARN**（"催声明"）。
三条路：声明 `off`（opt-out）、保持未声明（永久 WARN）、真启用（`on` + 激活清单）。

真启用后暴露一个框架级张力：**本仓既是模板源又是实例**。两处代码此前都假定"仓库文件 = 模板态"：

- `s14` 用「生成物 == 仓库文件」逐字节断言 10 个骨架文件；
- `cmd_upgrade` 的 `dt_skip` 已能对已激活实例豁免漂移，但它的注释把这件事写成
  「s14 契约锁模板态，激活即破 s14，诚实声明不支持」——把"可支持"说成了"不支持"。

## Decision

1. 模板仓启用文档分层：`docs-tier: on` + `.meta/docs-tier/README.md` 激活
   （九 tier 填真实家、零 `【TODO】` 残留）。2.5 由 SKIPPED 转为 PASS。
2. `s14` 的 docs-tier 那组断言按激活状态分支：本仓已激活 → 跳过"生成物 == 仓库文件"，
   **改为断言"生成物仍是模板态"**（`$T` 里那份必须不含 `## 已激活文档家清单` 且含模板态标记）。
   断言强度上升：它防的是「激活版被当成模板发出去」，而不是简单放宽。
3. `cmd_upgrade` 的 `dt_skip` 语义保持不变，仅订正注释与用户可见提示的措辞：
   不再说"不支持/激活即破 s14"，改说"本文件不参与漂移比对；模板基准仍由 heredoc 提供；
   模板仓自身也可以是已激活实例"。
4. 未打 tag、未 bump 版本号：框架版本由 git tag 派生，bump 时机交维护者。

## Alternatives considered

- **声明 `docs-tier: off` + decision**：与事实不符（本仓已有 9 个 tier 的真实家），
  等于用一条 decision 记下假的停止线。否决。
- **保持未声明**：`status` 永久催声明，违反本轮"每条 WARN 必须有终止条件"的目标。否决。
- **模板仓保留两份 docs-tier README（模板 + 激活副本）**：两份契约必漂移，权威不明。否决。
- **直接删掉 s14 的 docs-tier 断言**：放松而非改口径。否决。
- **升级为"框架版本 3.0 并打 tag"**：影响面超出本次（需 release 流程、校验和链），交维护者另议。

## Consequences

- `status`：L0-L2 全部 PASS，无 SKIPPED 尾巴；`upgrade --check`：零漂移（`dt_skip` 生效）。
- `s14`：docs-tier 组断言从"等于模板"变为"生成物仍为模板态 ∧ 本仓已激活"，并补正向控制
  （手工把生成物改成激活标题 → 断言必须变红）。
- 代价：本仓 `.meta/docs-tier/README.md` 不再是可直接抄用的模板；初始化新仓只有 `ponygo init`
  一条正路（文件头已写明该告警）。
- 后续扩展点：词数预算（doc-sync 门，L2 选装）落数值即可，模板与激活版都留有该节。

## 验收

- `bash tests/run.sh` → pass=894 fail=0（含 s12 2.5 四分支、s14 docs-tier 新口径、s75–s77 1.10）
- `bash ponygo status` → 0，`L0-L2 机械判据全部 PASS`（2.5 实际 PASS）
- `bash ponygo upgrade --check` → 0，零漂移
- `bash .meta/gates/adr-verify.spec.sh` / `ci-verify.sh` / `verify-note.sh` → 0
- `ponygo` 内 `P0-1(a)|激活即破 s14|诚实声明不支持` 计数 = 0（文案已与事实一致）
