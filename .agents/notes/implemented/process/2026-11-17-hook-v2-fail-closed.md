# Agent Note: A3 哨兵块 v2——删掉 A1 本身也 fail-closed（v1 双接受灰度）

Status: implemented

## Problem

U2 把 A1 的 A6 缺失改成 fail-closed，但**钩子自己**还有同族缺口：A3 的哨兵块是

```bash
if [ -f "$(git rev-parse --show-toplevel)/.meta/gates/adr-verify.sh" ]; then
  bash "$(git rev-parse --show-toplevel)/.meta/gates/adr-verify.sh" || exit 1
fi
```

`rm .meta/gates/adr-verify.sh` 之后 if 条件为假 → pre-commit 静默放行（对抗审核实测坏 ADR `commit_rc=0`）。
A4 远端能抓，但"删一个文件即可让本地判定消失"与 U2 是同一条病灶。

## Decision

1. **哨兵块 v2**：`then … || exit 1` 之外补 `else` 分支——打印
   `[pre-commit] 拒绝：缺失 .meta/gates/adr-verify.sh（A1 不可判定 = fail-closed）→ 跑 ponygo init 补回` 并 `exit 1`。
   marker 与哨兵同文（`adr-verify v2`）。
2. **双接受灰度**：2.4 的 ④ 判据同时持有 v1、v2 两份 canonical——
   - 块 == v2 → PASS（零噪音）；
   - 块 == v1（冻结的历史值）→ **PASS + WARN**「pre-commit 哨兵块为 v1（无『A1 缺失』fail-closed），
     建议重跑 `ponygo init` 升级到 v2」；
   - 其余（注释掉调用行 / `|| true` / `echo` / 半截块 / 位置不合规）→ FAIL，拒绝能力不回退。
3. **`init` 负责迁移**：钩子不存在 → 写 v2 全文；已含合规 v1 块 → **原子替换**为 v2 块（其余字节顺序与内容
   零改动、位置仍在 `#!` 之后与首个顶层 `exit`/`exec` 之前）；已是 v2 → 幂等不动。
   `--repair-skeleton` 不动钩子（既有语义）；`hooksPath` 一律不动；不可执行钩子仍不改权限。

## Alternatives considered

- **直接改 v1 块字节（不升版本号）**：否决——块字节是 2.4 的判据原子，改字节等于让所有实例的 2.4
  立刻 FAIL；没有版本号就无法区分"旧"与"错"，灰度无从谈起。
- **只改新钩子、不迁移旧钩子**：否决——那样 v1 缺口会长期留在现有实例上，WARN 变成永久背景噪音。
- **v1 直接判 FAIL（不做灰度）**：否决——一次发布让全部实例的 2.4 变红，正是这轮审计反复抓到的
  "出厂即红 → 绕过"病灶；灰度把迁移成本显式化（WARN 点名版本与修法）。
- **在钩子里再嵌一层"若 A1 缺失则跑 A4"兜底**：否决——本地钩子不应联网/跑全树；CI 层已有 A4。
- **把 A1 的路径写死成绝对路径避免 `git rev-parse`**：否决——工作树/子目录调用会错；现状的相对解析是对的，
  缺的是"解析不到就拒绝"，不是改解析方式。

## Consequences

- 删 A1 从"静默摊平"变成"提交被拒 + 一句可执行修法"；v1 实例在灰度期只多一行 WARN，不会整体变红。
- `init` 变成有迁移职责的命令（v1→v2 原子替换）：跑一次即可消除 WARN；替换失败走既有失败清单与退出码。
- v1 canonical 作为**冻结历史值**长期留在 CLI 里（双接受的代价）——它只用于判定与 WARN，不再写入。
- 残余风险（诚实登记）：仍可用 `git commit --no-verify` 绕过本地层（A4 兜底）；删钩子文件本身也绕过本地层
  ——这类"删掉执行载体"的行为由 A4 + review 兜底，本地层无法自证自身存在。
