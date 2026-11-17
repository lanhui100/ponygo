# 仓库卫生的体检与体系设计（指引，非门禁）

> **定位**：本页是**指引页**，不是判据、不是门禁、不参与四问计分。它回答三件事：
> ①植入时怎么**体检**一个仓的卫生状况；②怎么为该仓**设计**它自己的卫生体系（哪些机械化、哪些靠 review）；
> ③哪些东西本页**不管**（§4 必须随报告复述）。
>
> **为什么不做成框架门**：门是实例的决定（P9 负空间）；框架内置的卫生门会被计为"每个实例都白得"的假绿
> （依据：`ponygo audit` 的"框架门不计实例门"）。框架只给**程序 + 判据形态 + 骨架**，白名单与取舍归实例。
>
> **编号约定**：本表编号（`HY-n`）**不映射** `maturity-ladder.md` §5 的判据号——两套编号同形不同义的话
> `audit/checklist.md` 已经吃过一次亏（见其「口径声明」）。涉及既有判据的项，本页只**引用**判据号，不复述定义。

## 0. 用法（植入时两步，各做一次）

1. **体检**：按 §1 逐项跑锚定命令，产出一份"本仓卫生现状"的事实清单（只记录，不评判）。
2. **设计**：按 §2 的菜单为每一项选定处置——机械门 / 实例门+负样本 spec / 靠 review / 明确不做，
   并把结果落成 §3 的**一条决策记录**（不落记录 = 体检没发生）。

## 1. 体检面（扁平清单：布尔命题 + 锚定命令 + 判定性）

判定性三档：**机械** = 有非零退出命令可判；**部分** = 命令只覆盖形状/子集；**review** = 语义判断。
"何时必须"只写**引用**（命约 7 / 判据 2.3 / 2.5），档位定义仍在 `maturity-ladder.md`。

| ID | 布尔命题（判什么） | 锚定命令（按本仓栈替换路径集） | 判定性 | 何时必须 |
|---|---|---|---|---|
| HY-1 | 临时产物有唯一落点，且该约定被写下来 | `ls -d .scratch 2>/dev/null`；约定锚点须在 `docs/AGENTS.md` 或仓内等效家 | 部分 | L1+（命约 7） |
| HY-2 | 临时产物未被 Git 跟踪 | `git ls-files .scratch \| wc -l` 应 = 0 | 机械 | L1+ |
| HY-3 | 临时目录已在 `.gitignore` 声明 | `grep -qE '^\\.?/?\\.scratch/?' .gitignore` | 机械 | L1+ |
| HY-4 | 构建产物未入库 | `git ls-files 'lib/**' 'dist/**' 'out/**' 'target/**' '*.pyc' \| wc -l` 应 = 0 | 机械 | L1+ |
| HY-5 | 发布/安装链不引用临时区 | `grep -rn '\\.scratch' .github/workflows install.sh scripts 2>/dev/null \| wc -l` 应 = 0 | 机械 | L2+ |
| HY-6 | 若本仓有清理脚本 → 它有删除边界（§2.3 四条不变量） | 见 §2.3（人工核对脚本源码后落成 review 结论或实例门） | 部分 | L2+（有清理器才判） |
| HY-7 | 搜索面隔离冻结史 | `grep -qF '/.agents/notes/archived/' .rgignore` | 机械 | L2+ |
| HY-8 | 游离过程文档（根目录/源码旁平铺的临时 md、日志、截图） | `git ls-files '*.md' \| awk -F/ 'NF==1'` 后人工分类哪些是契约、哪些是过程产物 | review | L2+ |
| HY-9 | 生成物有再生路径（`gen-*` / `*-generated` 可重建） | `git ls-files '*generated*'` + 对应 `gen-* --check` 是否存在 | 部分 | L2+ |
| HY-10 | 死代码/语料腐烂初筛（只作候选，不作结论） | `find .agents/notes/implemented -name '*.md' -mtime +180`；`git log --diff-filter=D --name-only --since='90 days ago' -- 'src/**'` | 部分 | L3 候选 |
| HY-11 | 依赖卫生：lockfile 与声明一致 | 按栈：`pnpm install --frozen-lockfile` / `cargo metadata --locked` / `go mod verify` | 机械 | L2+ |
| HY-12 | 大**二进制/非源码**文件未入库（单文件源码、内嵌模板等经确认的"有意的字面量大文件"除外，须在记录里点名） | `git ls-files -z \| xargs -0 du -k 2>/dev/null \| awk '$1>512'`（阈值按仓定，命中项逐个分类） | 部分 | L2+ |

> 只体检**本仓确实有**的项：没有清理脚本就没有 HY-6，没有生成物就没有 HY-9——**"不适用"要写进记录**，
> 不得静默跳过（P6：不适用 ≠ 通过）。

## 2. 设计菜单（按当前 `level` 映射；**不新增等级轴**）

| 当前 level | 卫生面的最低要求 | 依据 |
|---|---|---|
| L0–L1 | 机械项（HY-2/3/4）为真；不做门 | 判据 1.x 的骨架期，门不在档位内 |
| L2 | 选定的机械项落成**实例门** + 同名负样本 spec（§2.1/§2.2 骨架）；review 项写进报告的"靠 review"段 | 判据 2.3（门 + 负样本）、`ponygo audit` 的实例门计数 |
| L3 | 若"临时产物/清理"流程已第 3 次重复 → 沉淀为 `.agents/skills/` 技能 | `maturity-ladder.md` L3 的资产化条件 |

### 2.1 实例门骨架（只给形状，白名单由实例填）

```bash
#!/usr/bin/env bash
# scratch-hygiene.sh —— 临时产物卫生门（实例门，非框架资产）
# 判据：① .scratch 未被跟踪 ② .gitignore 已声明 ③ 发布/安装链不引用 ④ 清理动作不越仓根
set -u
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || { echo '拒绝：非 git 仓，无法判定边界' >&2; exit 1; }
tracked=$(git -C "$ROOT" ls-files .scratch 2>/dev/null | wc -l | tr -d ' ')
[ "$tracked" -eq 0 ] || { echo "拒绝：.scratch/ 有 $tracked 个被跟踪文件" >&2; exit 1; }
grep -qE '^\.?/?\.scratch/?' "$ROOT/.gitignore" 2>/dev/null || { echo '拒绝：.gitignore 未声明 .scratch/' >&2; exit 1; }
refs=$(grep -rln $'\.scratch' "$ROOT/.github/workflows" "$ROOT/install.sh" "$ROOT/scripts" 2>/dev/null | wc -l | tr -d ' ')
[ "$refs" -eq 0 ] || { echo "拒绝：发布/安装链引用了 .scratch（$refs 处）" >&2; exit 1; }
exit 0
```

### 2.2 同名负样本 spec 骨架（每条"必须拒"都要有）

```bash
#!/usr/bin/env bash
# scratch-hygiene.spec.sh —— 负样本判据（判据 2.3 要求：至少一条真实拒绝断言）
# 断言计数供 ponygo 的 ##SPEC 运行时契约使用（U4）
PASS_N=0; FAIL_N=0; REJECTS=0
ok() { PASS_N=$((PASS_N+1)); printf '  [ok]   %s\n' "$*"; }
bad() { FAIL_N=$((FAIL_N+1)); printf '  [FAIL] %s\n' "$*" >&2; }
mk() { d=$(mktemp -d); mkdir -p "$d/.meta/gates" "$d/.git" 2>/dev/null; printf '%s' "$d"; }
# ① 被跟踪的 .scratch 文件 → 必须拒
d=$(mk); (cd "$d" && git init -q . && mkdir -p .scratch && printf 'x\n' > .scratch/a.log && git add -A)
REJECTS=$((REJECTS+1)); (cd "$d" && bash .meta/gates/scratch-hygiene.sh >/dev/null 2>&1) && bad '被跟踪 .scratch 未拒' || ok '被跟踪 .scratch 必拒'
# ② 缺 .gitignore 声明 → 必须拒
d=$(mk); (cd "$d" && git init -q . && printf 'node_modules/\n' > .gitignore)
REJECTS=$((REJECTS+1)); (cd "$d" && bash .meta/gates/scratch-hygiene.sh >/dev/null 2>&1) && bad '缺声明未拒' || ok '缺 .gitignore 声明必拒'
printf '##SPEC asserts=%s rejects=%s\n' "$((PASS_N+FAIL_N))" "$REJECTS"
[ "$FAIL_N" -eq 0 ]
```

### 2.3 清理器的删除安全不变量（若要写清理脚本，四条缺一不可）

1. **仓根锚定**：`ROOT=$(git rev-parse --show-toplevel)`；不可得 → 拒绝执行删除（不猜）。
2. **父目录 realpath 校验**：`realpath dirname(target)` 必须落在 `$ROOT/` 内——**只校验最终路径会被符号链接骗**（祖先链接会把删除带出仓外）。
3. **链接不跟随**：目标若本身是符号链接，只 `rm` 链接本身，`rm -rf` 只用于已验证在白名单内的目录。
4. **白名单 + fail-closed**：只清显式登记过的路径（如 `.scratch/**`）；白名单外一律拒绝并点名，不"猜着删"。

> 这四条是从 deepseek-harness 的 `scripts/clean.ts`（`assertDescendant` + 父目录 `realpath`）借来的**唯一部分**；
> 它的清理器本体绑 TS workspace 产物（`lib/`、`dist-exe/`、`.typecheck`），不进 ponygo。

### 2.4 review 项怎么写进报告

每项一行：`<ID> <现状事实> — 证据: <命令> → <输出摘要>；判定：<合规/欠账/不适用>；动作：<最小改进或"靠 review 接受">`。
**"不适用"必须给理由**（例：HY-6 无清理脚本），不得省略。

## 3. 一次性产出：卫生基线记录（review 层面的交付物）

- 路径：`.agents/notes/{proposed,implemented}/process/yyyy-mm-dd-hygiene-baseline.md`（lifecycle 按实际状态）；
- 必含四节：①**体检事实**（§1 的项 → 事实 + 证据命令）②**已选机械门**（每条：判据 + 命令 + 负样本路径）
  ③**明确不做项**（含理由，P9）④**复审条件**（何时重跑体检：如"新增清理脚本/新增构建产物目录/每半年"）；
- **本项不设门**：文件名与内容语义判不了"这份体检是否认真"——由 `governance-review` 在
  **L2 升级与 `upgrade adopt` 之前**核对"记录存在 + 四节齐"，内容真实性归 review（P6）。

## 4. 本页不覆盖（报告必须原文复述）

- **文档分层语义**（tier 放置、slop 清单、词数预算）——归 `docs/AGENTS.md` 与 docs-tier 门/ review；
- **构建系统正确性与产物一致性**（增量构建、产物漂移门）——归各栈自身的构建验证；
- **依赖漏洞/供应链/许可证**——本页只查 lockfile 一致性，不做扫描；
- **"这个目录是不是临时产物 / 这个脚本该不该存在"**——语义判断，靠 review；
- **清理策略**（清什么、何时清）——本页只给删除安全不变量，策略是实例自己的决定。

## 5. 与既有资产的关系

- `governance-review` 的「卫生面」从三条粗筛升级为"引用本页走 §0 两步"；
- `audit/checklist.md` 的卫生相关条目（如 4.3 搜索隔离）**不改判据**，只加一行指针；
- 本页**不改**四问编号与 `ponygo.audit/1` 字段（加"第五问"是破坏性变更，需要独立 ADR）。
