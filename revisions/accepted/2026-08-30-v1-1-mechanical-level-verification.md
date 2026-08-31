# Revision: v1.1 —— status 机械验级 + meta.yaml 违例告警（accepted）

Status: accepted

## 框架规则变更

1. `ponygo status` 从"只报骨架完整度"升级为**一键验级**：按 maturity-ladder §5 对
   min(声明级, 2) 及以下全部判据逐项机械验证，不符逐项列 FAIL + 最小修正动作，exit 1。
   判据实现时对真源做了显式裁决并回写：0.4 加行尾锚、1.5 机械化为"恰好两级"、
   1.6 日期合法性依赖 GNU date 否则降级"靠 review"、1.7 archived/ 允许
   Status ∈ {implemented, archived}、2.2 以 bash -n 为代理判据并如实标注、
   2.4 声明 L2 即视为已承诺钩子（WARN-only 构成假门禁，改 FAIL）。
2. `meta.yaml` 合法键白名单（level + ai-surface）的违例告警**双挂** status 与 audit
   （同一函数，消灭归属歧义）；WARN 不改退出码。
3. 决策文件计数排除集 `{README.md, *.zh.md}` 三处共用同一函数，写死。

## 采纳理由（回馈证据）

v0 的 audit M 档只覆盖 L1/L2 判据一小部分，"级自洽"靠人手工跑 maturity-ladder §5
的命令——凡机械可查的承诺没配命令，违反框架自己的 P2。v1.1 把判据收进 CLI，
并让"判据真源"（maturity-ladder §5）与实现同变更回写，防止双源漂移。

## 影响面

- 实例升级路径：存量实例的 level 声明若与实际不符，status 从"绿"变 exit 1——
  这是判据生效的预期行为，不是回归。
- 测试：`tests/run.sh` 场景 11/12/13 覆盖各级判据正反对照例。
