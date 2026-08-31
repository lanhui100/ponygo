# revisions/ —— 框架自身演进记录

> ponygo 框架"吃自己的狗粮"：用 ADR 记自己的演进。
>
> 回馈 = 一篇 proposed ADR（附"该约定在原实例为何失效"的证据）；框架修订 = proposed → accepted + bump 版本。
>
> 注意：框架非软件实例，无"implemented=落地代码"语义，lifecycle 简化为 proposed → accepted。

## 与 .meta/decisions/ 的双轨边界（何时用哪个）

ponygo 仓库同时有两套记录，分工如下，勿混用：

| 载体 | 记什么 | 例子 |
|---|---|---|
| `revisions/` | **框架规则的演进**——ponygo 这套元框架自身的约定/判据/命令面如何变（"框架应该怎么治理别人"） | 新增一条 L1 判据；audit 增加一档；命令面调整 |
| `.meta/decisions/` | **本仓库作为软件项目的工程决策**——ponygo 这个软件本身怎么实现（"这个项目自己怎么被治理"） | CLI 用单文件 bash；测试用 mktemp 场景化；某 bug 的修复方案 |

实例项目只有 `.meta/decisions/`（revisions/ 不进实例骨架）；框架维护者两套都用。
实例对框架的回馈 = 一篇 `revisions/proposed/` ADR（附"该约定在原实例为何失效"的证据）。

- proposed/  —— 提案（实例回馈、待定夺的框架改动）
- accepted/  —— 已采纳，随下一版本号发布
