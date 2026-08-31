# Agent Note: 自身狗粮补齐——决策回溯入册、CI 挂载、安装完整性校验

Status: implemented

## Problem

外部审核 EXTERNAL-001 的 P0 组：ponygo 的全部可信性来自"实证"，但自身治理停在
`level: 0` 字面合法态——`.meta/decisions/` 与 `revisions/` 均为空（决策散在
docs/dev-team/ 与 git log）；回归门禁 tests/run.sh 无任何钩子/CI 挂载，宣称的
pass=117 无法独立复跑；README 首推的 curl|bash 安装无版本钉住、无完整性校验。

## Decision

1. **决策回溯入册**：把已拍板的核心决策补录为 6 条 implemented ADR（单文件零依赖 CLI、
   .meta/ 布局与两键铁律、六命令面、阶梯止步 L2、四问两档审计、纯 bash 测试），
   外加 P1/P2 修复与本条共 8 条；框架规则演进补录 `revisions/accepted/` 2 条
   （v1.1 机械验级、classes.local 扩展口）。meta.yaml 升 `level: 1`，
   由 status 对 L1 判据机械看守（决策存在、双轴合法、Status 一致）。
2. **CI 挂载**：`.github/workflows/ci.yml` 双 job（ubuntu = GNU 用户态，
   windows = Git Bash——正是 README §6.2 承诺的两个平台）跑 `bash tests/run.sh`，
   加 `all-checks-passed` 聚合门（`if: always()`，防 skipped 计为通过，
   分支保护只依赖聚合检查——dsh 实证形态的最小化复刻）。
3. **安装完整性**：install.sh 支持 `PONYGO_VERSION`（git ref 钉住下载地址）与
   `PONYGO_SHA256`（下载/复制后强制校验，无校验工具时 fail-closed 拒绝安装，
   校验失败删除可疑文件）；README 安装节同步推荐用法；s20 补正反校验和场景。

## Alternatives considered

- **只入册今后的决策、不回溯**：否决——"多记成本一段文字，漏记成本永久丢失"；
  回溯的是已拍板且仍在生效的决策，正是 decisions/ 的用途。
- **level 直接升 2**：否决——L2 判据要求 gates/ 实质门禁 + 负样本 spec + 本地钩子，
  CI 挂载不等于本地钩子已挂（hooksPath 是开发机状态）；声称 L2 即散文。
- **install.sh 默认强制校验和**：否决——无公布的校验和清单前强制校验会堵死安装；
  采取"设了就必须过"的 fail-closed 语义，默认路径保持可用。
- **CI 只跑 ubuntu**：否决——平台承诺含 Windows Git Bash，不测即未承诺（P2）。

## Consequences

- ponygo 自身四问记分卡更新：问① 3→6 分（载体 + 内容 + 门禁校验齐备，
  触发枚举化已在 decisions/README 成文）；问② 3→5 分（CI 挂载，本地钩子仍靠自觉）；
  问④ 不变（archived 仍无实际归档，属"语料未腐烂"的合法空态）。
- 结构性漏洞仍在但收窄：L0→L1 后，status 会持续看守决策语料的形状合法。
