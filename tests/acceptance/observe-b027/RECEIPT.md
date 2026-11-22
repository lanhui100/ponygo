# B027 验收收据（入仓版 · 可复跑）

> 为什么这份在 `tests/` 里：`.scratch/` 与 `.dev-team/` 都在 `.gitignore` 里，清理即蒸发。
> 物理凭证必须留在**入仓的地方**——本文件与 `.agents/notes/implemented/` 的决策记录一起构成取证链。
> 完整过程版（含真 skill 冒烟、逐条断言明细）见 git 历史的 `.dev-team/b027-acceptance-receipt.md`（不入仓）。

## 0. 一条命令

```bash
bash tests/acceptance/observe-b027/run-all.sh
# → exit 0
# ##SUMMARY observe-b027 cases=4 pass=113 fail=0 failed=0
# 结果：PASS（B027 四项验收全过）
```

## 1. 四项判据（B027①–④）+ 归因对照

| # | 判据 | 用例 | 断言数 |
|---|---|---|---|
| ① | `.husky/` / `core.hooksPath` 载体上 ob2 **可得分** | `c1_carriers.sh` | 35 |
| ② | 一级子组件声明被 audit **逐份**巡检（`subcomponent_*`） | `c2_subcomponent.sh` | 30 |
| ③ | `docs/observability.d/*.yaml` 与根声明并存、**各自独立**判定（`extra_declaration_*`） | `c3_multi_declaration.sh` | 27 |
| ④ | 纯注释 `# bash scripts/audit-diff.sh` 伪装 mount **必须判负** | `c4_comment_mount.sh` | 21 |
| ⑤ | 归因对照：单文件载体写**真调用** → 仍 ob2 PASS（防修复把真挂载误杀） | `c4` 4a 段 | （含在 21 内） |

## 2. 红相（对 B027 修复前的 CLI，`7379930^`）

```bash
git show 7379930^:ponygo > /tmp/ponygo.prefix
PONYGO_CLI=/tmp/ponygo.prefix bash tests/acceptance/observe-b027/run-all.sh
# → exit 1；##SUMMARY observe-b027 cases=4 pass=75 fail=38 failed=4
#    c1 26/9 · c2 18/12 · c3 17/10 · c4 14/7
```

两次独立取得（并发窗口 + 串行干净窗口）计数逐字一致：本套件零计时依赖断言，抖动不改变结论。

## 3. 本次唯一产品改动（B027④ 半修复 → `-HIn`）

- 缺陷：`observe_mount_hit()` 单文件分支 `grep -In` 打印 `1:# …`（**无 `file:` 前缀**），
  注释排除正则 `:[0-9]+:` 永不匹配 → 单文件载体（`.githooks/pre-commit`、`.git/hooks/pre-commit`、
  `.pre-commit-config.yaml`、`lefthook.yml`）的纯注释伪装判**绿**（ob2 PASS，exit 0）。
- 铁证（当前 `c42cb5c`）：四条单文件载体 rc=0 / 当前级=ob2 / 缺口=无；`.husky`、`.github/workflows`
  两条目录载体 rc=1 + `mount_missing`（目录分支带前缀，判负正确）。
- 修复：`grep -In` → `grep -HIn`（一行）。收口：c4 `pass=17 fail=4` → `pass=21 fail=0`，
  c1 的四个正样本仍 PASS（未误杀真挂载）。

## 4. 真 skill 端到端冒烟（补 stub 之外的边界）

用 `$HOME/.agents/skills/observability-onboarding` 逐项复验：`.githooks`/`.husky` 真挂载 → exit 0 当前级 ob2；
单文件纯注释 → exit 1 + `mount_missing`；子组件声明（applicable=true 无证据）→ `subcomponent_*` 缺口 +
`front_end:` rc；`docs/observability.d/pipeline.yaml` → `附加声明巡检` 清单含 `pipeline.yaml:`。11 断言全过。

## 5. 边界

- skill 用 `./stub-skill`（**内容驱动**退出码）：验的是 ponygo 的判定面，不是 skill 的规则集语义；
  skill 语义由第 4 节真 skill 冒烟覆盖。
- 载体判定仍是**文本判据**（不解析 AST、不验证钩子真会执行）；真执行证据是 `audit-diff` 自身 rc。
- 不接入 `tests/run.sh`（94 场景字面量是 gh6/R1 与 `verify-p0` 的硬锚）。

## 6. CI 看守（防「修完没人看守」）

`observe_mount_hit` 在 `tests/run.sh` 与 `gh6` 内**零覆盖**，本套件是它唯一的判别器；不挂 CI 就等于
修完即失效。故两处机械看守：

1. `.github/workflows/ci.yml` 的 `governance` job 调用本套件：
   `- run: bash tests/acceptance/observe-b027/run-all.sh`（短套件，约 25s，不依赖真 skill）；
2. `gh6` 的 `GH6/E1` 断言：`ci.yml` 中该调用**恰 1 处**且落在 `governance` job 的 step 内。
   负样本（副本树删掉该行）→ `GH6/E1 …（实得：命中=0 governance内=False）` **FAIL**，已验证。
   → 未来把这一行悄悄摘掉，`GH6/E1` 立刻红，不会出现「看守被删而全绿」。
