# decisions/ —— 决策记录（ADR / Agent Note）

这是治理根的**记忆**：任何"为什么这样 / 为什么不那样"的决定，都落到这里，
而不是散落在人脑、聊天记录或 PR（拉取请求）线程里。

## 路径规范

```
decisions/{lifecycle}/{class}/yyyy-mm-dd-topic-title.md
```

两个轴都编码进**路径**（文件夹即标签，内容里不必重复声明，二者永不漂移）：

- **lifecycle（状态轴，顶层）** 随状态迁移：
  - `proposed/` —— 提案，未实现或部分实现
  - `implemented/` —— 已落地，记录当前态（事实随代码更新）
  - `rejected/` —— 已否决，判定保留在路径 + Status 行
  - `archived/` —— 冻结历史快照（只有 implemented 能进入；见 methodology.md §2.3）
- **class（类别轴，嵌套）** 来自封闭集合：
  - `feature`（新能力）/ `bug-fix`（修缺陷）/ `simplification`（减复杂度）/
    `architecture`（交付源码的结构）/ `process`（代码周围的工具与流程）/ `testing`（测试策略）
  - class 目录由**写入时创建**，不预建空目录——空目录既不承载事实、又制造"有决策"的假象。
  - **lifecycle 四态目录由 `ponygo init` 预建**（`proposed/ implemented/ rejected/ archived/`）：
    状态轴的空态是合法的——它代表治理根已播种；而 class 是类别轴，空目录不承载事实，故不预建。

## 文件格式契约

头部固定前两行：

```markdown
# Agent Note: <title>

Status: <status>
```

- `Status:` 三选一，必须与所在文件夹一致：`proposed` / `implemented` / `rejected — <一行理由>`。
- 正文从 `## Problem` 开始（先写动机，脱离方案也成立）。
- `implemented/` 用现在时 `## Decision`；禁止提案时代标题（`## Proposal` / `## Plan` /
  `## Migration plan` / `## Acceptance criteria`）。
- 每条必含 `## Alternatives considered`（候选方案与落选原因）——记录无备选的决策是在邀请重开争执。

## 触发规则（谁在什么时候必须写）

非平凡变更 = 命中任一：行为变更 / 架构 / 跨文件或跨包契约 / 流程与工具链 /
测试策略 / 磁盘-线-配置格式 / 维护者可能再访的决定。
命中即同一次变更内新增或更新记录。纯机械或局部编辑豁免。

## 与下一级的关系

有决策记录是 L1 的判据之一；是否"承诺可验"（L2）取决于 `gates/` 是否有非零退出门禁。
