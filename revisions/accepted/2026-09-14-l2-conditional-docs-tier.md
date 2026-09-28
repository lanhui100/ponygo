# Revision: 判据 2.5 改为条件判据（`docs-tier: on|off` 显式声明，Q1=A）

Status: accepted

## 回馈证据（TASK-002 双审矛盾 + TASK-003 consultant 三选一）

`maturity-ladder.md` §5 的 L2 判据 2.5「文档分层已激活」是无条件硬判据，而 §6 停止线承诺
"保留 L1 + 上最轻的 L2（仅 format 门禁，不上文档分层）"——照 §6 行事的单实例永远无法声明 L2
（`ponygo status` 必 FAIL）。两份独立审核（TASK-002）各自独立发现此矛盾。TASK-003 交由
consultant 三选一裁决（`reviews/review-TASK-003-consultant.md` Q1）：**选 A——2.5 改条件判据**；
否决 B（门禁语义污染 L1，违反 §1 每级单一核心产物划分）；否决 C（删真实中间态，丢掉
"单人 + format 门禁"实证形态）。

## 框架规则变更

1. **`meta.yaml` 新增合法键 `docs-tier`**（值仅小写 `on`/`off`，顶格无缩进；`ai-surface` 的
   Off 大小写先例不继承——新键从严）。它是**启用声明**而非目录推导事实：目录在 init 时即生成
   模板态，存在 ≠ 已激活，故不是可由目录推导的冗余副本。
2. **判据 2.5 状态机**（仅 `level >= 2` 生效；`level: 1` 声明 docs-tier: on 被忽略；`lv >= 3`
   同 L2 分支处理）：
   - **undeclared = SKIP + WARN 催声明**（不计入 PASS，也不判 FAIL）；
   - **off = 显式 opt-out**（结论行改写为「2.1–2.4 PASS；2.5 未启用」，禁写"全部 PASS"；
     建议录一条 decision 说明为何不上文档分层，对齐 retire 的退级须录 decision 纪律）；
   - **on + 家清单仍有 `【TODO】` 残留 = FAIL**（声明即承诺，TODO 残留 = 声明空心）；
   - **off + 已激活 = 矛盾 WARN**（声明与事实不符，催对齐）；
   - **undeclared + 已激活 = PASS**（实际做到优先于声明）。
   - 引号/空白/非法值（yes/true/大写/空）**不得兑现 on/off 语义**：白名单正则
     `^docs-tier:[[:space:]]*(on|off)$` 判非法键 WARN，状态机值读取只剥 `\r` 不剥引号/空白，
     任何变体落"未声明"支（保守方向，无绕过 FAIL 的路径）。
3. **状态轴与诚实条款**：§6「最轻 L2」定义写死为 `2.1–2.4 + docs-tier: off`；§5 判据 2.5
   行与注标注 condition 型 validation 的诚实条款（「机械」身份以显式声明 docs-tier: on 为前提）。

## 采纳理由

- 保住「单人 + format 门禁」真实中间态（删行消解矛盾 = 删证据）；
- solution 方向保守：畸形值一律落 SKIP+WARN，无 FALSE-PASS 注入逃逸（case 仅比对 on/off，内容不被解释）；
- 迁移面清晰：既有实例默认行为不变（未声明 = SKIP+WARN，不 PASS→FAIL）；
- 与 v2.0「文档治理前置到 L0/L1」无冲突：前置的是"有家"（0.5/1.9），条件化的是"分层激活"（2.5），两层不是同一物。

## Alternatives considered

- **B：把 2.5 降为 WARN / 引入 L1.5 改名**：否决。让 L1 承担"承诺可验"语义违反 §1 分层纯洁；
  文档分层失去机械看守，与 v2.0 直接冲突。
- **C：删 §6「最轻 L2」行，停在 L1**：否决。丢掉真实存在的中间态，等于用删建议消解矛盾。
- **通配"存在即声明"（目录存在=已启用）**：否决。目录 init 即生成模板态，`exemptions` 等文件
  已在目录下，通配会误触发（L2 评审遗漏边界条）。

## 影响面

- `ponygo`：`verify_ladder` 2.5 条件化（严格 on|off 匹配）、`warn_meta_violations` 白名单
  （level/ai-surface/docs-tier，docs-tier 值仅小写 on|off）、`write_skeleton` meta.yaml heredoc
  注释、结论行改写（off → "2.1–2.4 PASS；2.5 未启用"）、`usage()`；
- `.meta/meta.yaml` 铁律注释（合法键 = level + ai-surface + docs-tier）；
- `maturity-ladder.md` §1 总表 L2 行、§5 判据 2.5 行与注、§6 最轻 L2 定义、§附诚实条款；
- `README.md` §4.1 meta.yaml 键说明；
- 测试：`tests/run.sh` s12 四分支六用例（含 off+已激活、on+无 TODO、引号值回归）、
  s13 新键/缩进/非法值、s28 作用域、s29 口径；
- 版本：v2.6.0（README 示例同步）。