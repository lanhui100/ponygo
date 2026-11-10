# Agent Note: 门禁负样本与聚合证据加固

Status: implemented

## Problem

门禁审核发现五类证据断点：A2 与 scratch spec 在旧环境变量下会 SKIPPED 却以 0 退出，A4 只看退出码形成假绿；主 CI 聚合未包含独立治理 workflow；audit 细目编号与现行 CLI 不一致；存在任一 spec 不能证明每个实例门均有负样本；scratch E3 未覆盖发布 workflow 的负样本。

## Decision

1. 负样本执行统一由 audit 深度变量防递归，spec 不再因旧 `PONYGO_IN_SPEC` 自我跳过；A4 对未验证结果 fail-closed。
2. 将治理执行面并入主 CI 聚合，添加 workflow 形状的破坏性验收。
3. 回改 audit 文档，使 2.3/2.4 与 CLI 真源一致。
4. 以同名片约定建立门与负样本映射，覆盖 shell 与 PowerShell 形态；编排器显式区分，缺失配对在 audit 中失败。
5. scratch spec 增加发布 workflow 引用 `.scratch/` 的拒绝用例，并在 pony-agent 的隔离工作树验证真实效果。

## Alternatives considered

- 保留旧自我跳过、只改文案：否决，CI 仍会把未执行当成通过。
- 继续保留两个独立 workflow、仅文档要求人工配置 required：否决，仓库无法证明分支保护状态，聚合形状仍无机械保证。
- 新增手写 spec-map 清单：暂不采用，同名推导减少第二份漂移源；编排器与跨栈形态必须显式处理。
- 为凑三层在 pre-push 重跑完整 CI：否决，违反本地窄、CI 全的时间经济原则。

## Consequences

- A2、scratch spec 与 A4 不再把旧环境变量或任意 exit 0 当作已验证：A2/A7 必须同时满足真实退出码与精确完成标记；合法样本仍放行。
- 主 `ci.yml` 的 `governance` job 与双平台自测一起进入 `all-checks-passed`，`needs` 三元组必须全部 success；独立 A5 仍作为新实例的生成模板。
- audit 的 M 档固定为 15 项：新增逐实例门/同名同后缀 spec 配对项。配对缺口以 `gate_spec_missing` 进入人读与 JSON，并硬 FAIL；空 spec 不算配对。
- 2.3/2.4 的语义与 `verify_ladder` 一致：2.3 是负样本与配对，2.4 是本地 ADR 门真接线；checklist、depth selector、README 与本 ADR 同步。
- scratch E3 分别用独立 install/release 夹具验证，发布 workflow 的 `.scratch/` 引用被非零拒绝，恢复后回绿。
- pony-agent 隔离工作树实测（HEAD 上叠加其当前未提交的 ADR/verify-note 修复）：A2/A4/scratch/ps1 配对的拒绝与放行语义均有原生退出码；其 HEAD 原有 6 条 1.8 债务被 A4 真实拦下，未借验证清理。
- 工作区原有其他未提交修改保持不动；本次不提交 git，验收以命令物理收据为准。
