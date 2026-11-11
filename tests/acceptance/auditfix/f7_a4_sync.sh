#!/usr/bin/env bash
# F7（A4 双写纪律 + W3 契约演进 v4）：
#   F7-1 heredoc ≡ 仓库 .meta/gates/ci-verify.sh（EOL 归一后逐字节一致，双方均为**固定四段**）
#   F7-2 新 init 生成物为固定四段 [1/4][2/4][3/4][4/4]；NOGO 旧三段/两段编号与任何 hygiene 门 / 守卫式跳过
#   F7-3 生成态 A4 实跑 exit 0（四段自洽，不得靠「有资产才跑」的守卫式）
#
# 契约演进（Wave13 contract-matrix-wave13.md W-4/W-5，Lead 裁定 2026-11-07）：
#   A4 由「全树 ADR + A2 spec」两段扩为**三段**——第 3 段 = A6（archive-verify check）+ A7
#   （archive-verify.spec.sh）。本文件原 F7-2/F7-3 冻结的 [1/2][2/2] 断言按新契约**更新为**
#   [1/3][2/3][3/3]，并**加强**为「旧编号禁现」；其余断言（hygiene 不在 A4、A5 承载实例门）
#   一条未删、未弱化。
#   F7-4 本仓 A5（.github/workflows/ponygo-governance.yml）承载 hygiene 两步与
#        `bash ponygo audit --run-specs` 的真实执行面，且仍调用 A4
# 冻结契约来源：.dev-team/contract-matrix-auditfix.md（F7）；plan-freeze §2 双写纪律；
#   Lead 裁定 contract_evolution_v4（W3：hygiene 门移出 A4 → 本仓 A5 独立 step）。
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

REPO_CI="$ROOT/.meta/gates/ci-verify.sh"
assert_exists "F7 仓库模板 .meta/gates/ci-verify.sh 存在" "$REPO_CI"

if ! command -v python3 >/dev/null 2>&1; then
  bad "F7 需要 python3 做 heredoc 抽取与逐字节比对（当前环境缺 python3）"
else
  R_OUT=$(ROOT="$ROOT" python3 - <<'PY' 2>&1
import os, sys, difflib

root = os.environ["ROOT"]
ponygo_path = os.path.join(root, "ponygo")
repo_path = os.path.join(root, ".meta", "gates", "ci-verify.sh")
marker = 'gate_asset_put "$META_DIR/gates/ci-verify.sh"'

try:
    with open(ponygo_path, encoding="utf-8", newline="") as fh:
        lines = fh.read().splitlines(keepends=True)
except OSError as exc:
    print(f"FAIL 无法读取 {ponygo_path}: {exc}")
    sys.exit(2)

start = None
for i, line in enumerate(lines):
    if marker in line:
        if "PONYGO_EOF" not in line:
            print("FAIL 找到 ci-verify 的 gate_asset_put，但其后不是 <<'PONYGO_EOF' heredoc（抽取契约变更？）")
            sys.exit(2)
        start = i + 1
        break
if start is None:
    print("FAIL ponygo 内找不到 ci-verify.sh 的 gate_asset_put heredoc（A4 资产丢失？）")
    sys.exit(2)

body = []
closed = False
for line in lines[start:]:
    if line.strip() == "PONYGO_EOF":
        closed = True
        break
    body.append(line)
if not closed:
    print("FAIL ci-verify heredoc 未闭合（缺 PONYGO_EOF 终止行）")
    sys.exit(2)

embedded = "".join(body).replace("\r\n", "\n")
try:
    with open(repo_path, encoding="utf-8", newline="") as fh:
        repo = fh.read().replace("\r\n", "\n")
except OSError as exc:
    print(f"FAIL 无法读取 {repo_path}: {exc}")
    sys.exit(2)

if embedded == repo:
    print("F7 ci-verify heredoc 与仓库模板 EOL 归一后逐字节一致")
    sys.exit(0)

print("FAIL ci-verify heredoc 与仓库模板不一致（A4 双写漂移）")
diff = list(difflib.unified_diff(embedded.splitlines(True), repo.splitlines(True),
                                 "ponygo:heredoc", ".meta/gates/ci-verify.sh"))
for line in diff[:40]:
    sys.stdout.write(line if line.endswith("\n") else line + "\n")
sys.exit(1)
PY
)
  R_RC=$?
  printf '%s\n' "$R_OUT" | sed 's/^/    /'
  assert_zero "F7-1 ci-verify heredoc 与仓库模板逐字节一致（EOL 归一后）" "$R_RC"
  assert_contains "F7-1 比对必须有明确的「逐字节一致」收据" "$R_OUT" "逐字节一致"
fi

# ---- F7-2：新 init 仓生成的 A4 是**固定两步**（W3 契约演进：hygiene 门移出 A4）----
T=$(new_case)
run_in "$T" init
assert_zero "F7-2 夹具：ponygo init（新仓）exit 0" "$R_RC"
GEN="$T/.meta/gates/ci-verify.sh"
assert_exists "F7-2 生成物 .meta/gates/ci-verify.sh 存在" "$GEN"
GEN_TXT=$(cat "$GEN" 2>/dev/null || :)
assert_contains "F7-2 GO：生成物含四段编号 [1/4]" "$GEN_TXT" "[1/4]"
assert_contains "F7-2 GO：生成物含四段编号 [2/4]" "$GEN_TXT" "[2/4]"
assert_contains "F7-2 GO：生成物含四段编号 [3/4]" "$GEN_TXT" "[3/4]"
assert_contains "F7-2 GO：生成物含四段编号 [4/4]" "$GEN_TXT" "[4/4]"
assert_not_contains "F7-2 NOGO：A4 不得残留旧两段编号 [1/2]" "$GEN_TXT" "[1/2]"
assert_not_contains "F7-2 NOGO：A4 不得残留旧两段编号 [2/2]" "$GEN_TXT" "[2/2]"
assert_contains "F7-2 GO：第 3 段覆盖归档封印门（archive-verify.sh）" "$GEN_TXT" "archive-verify.sh"
assert_contains "F7-2 GO：第 3 段覆盖 A7 自检（archive-verify.spec.sh）" "$GEN_TXT" "archive-verify.spec.sh"
assert_contains "F7-2 GO：第 4 段覆盖引用残留门 A8（no-residue.sh）" "$GEN_TXT" "no-residue.sh"
assert_contains "F7-2 GO：第 4 段覆盖 A9 自检（no-residue.spec.sh）" "$GEN_TXT" "no-residue.spec.sh"
assert_not_contains "F7-2 NOGO：A4 不得再含 hygiene 门（已挪到 A5 的独立 step）" "$GEN_TXT" "scratch-hygiene"
assert_not_contains "F7-2 NOGO：A4 不得用守卫式跳过（「有资产才跑」= 把门禁做成可选）" \
  "$GEN_TXT" "本实例无 scratch-hygiene 资产"

# ---- F7-3：生成态 A4 必须能真跑通（无 hygiene 资产的两步自洽 → exit 0）----
CIR=$( cd "$T" && bash .meta/gates/ci-verify.sh 2>&1 )
CIRC=$?
assert_zero "F7-3 生成态仓内 bash .meta/gates/ci-verify.sh → exit 0（四段自洽）" "$CIRC"
assert_contains "F7-3 取证：生成态 A4 实跑经过 [1/4]" "$CIR" "[1/4]"
assert_contains "F7-3 取证：生成态 A4 实跑经过 [2/4]" "$CIR" "[2/4]"
assert_contains "F7-3 取证：生成态 A4 实跑经过 [3/4]" "$CIR" "[3/4]"
assert_contains "F7-3 取证：生成态 A4 实跑经过 [4/4]" "$CIR" "[4/4]"
assert_contains "F7-3 取证：生成态 A4 第 4 段跑过引用残留面" "$CIR" "引用残留"
assert_not_contains "F7-3 NOGO：实跑不得残留旧两段编号 [1/2]" "$CIR" "[1/2]"
assert_not_contains "F7-3 NOGO：生成态 A4 实跑不得出现 hygiene 段" "$CIR" "scratch-hygiene"

# ---- F7-4：本仓把治理执行面并入主 ci.yml，使聚合门可消费 governance 结果 ----
# A5 文件不再是本仓必需：跨 workflow 的 job 无法被 `needs` 消费；生成模板仍保留（下方 fresh init 验证）。
CI="$ROOT/.github/workflows/ci.yml"
assert_exists "F7-4 本仓主 CI 存在" "$CI"
CI_TXT=$(cat "$CI" 2>/dev/null || :)
assert_contains "F7-4 GO：主 CI 含 governance job" "$CI_TXT" "governance:"
assert_contains "F7-4 GO：governance 调 A4" "$CI_TXT" "bash .meta/gates/ci-verify.sh"
assert_contains "F7-4 GO：governance 含 scratch-hygiene.sh" "$CI_TXT" "bash .meta/gates/scratch-hygiene.sh"
assert_contains "F7-4 GO：governance 含 scratch-hygiene.spec.sh" "$CI_TXT" "scratch-hygiene.spec.sh"
assert_contains "F7-4 GO：governance 含 bash ponygo audit --run-specs" "$CI_TXT" "bash ponygo audit --run-specs"
# F7-4b（Wave-14 契约 D1/D6/D7 迁移，.dev-team/contract-wave14.md §4）：
# job 集合与 needs 四项拓扑必须**结构化解析**，不得用一行注释或模糊子串命中冒充接线。
# 为什么必须随本轮同批改：`selftest-windows` → `windows-core`（+ 新增 `windows-full`）是改名迁移，
# 旧字面 `needs: [selftest-linux, selftest-windows, governance]` 已不再是契约形状；该断言在 full/nightly
# 层（s89 属 NONCORE，core 层不覆盖），漏改只能靠 nightly 抓到。
CI_TOPO=$(ROOT="$ROOT" python3 - <<'PYTOP' 2>&1
import os
import re

try:
    import yaml
except ImportError:
    print("FAIL F7-4 需要 PyYAML 做 ci.yml 结构化解析（缺失即失败，不跳过拓扑断言）")
    raise SystemExit(0)

with open(os.path.join(os.environ["ROOT"], ".github/workflows/ci.yml"), encoding="utf-8") as fh:
    doc = yaml.safe_load(fh.read())
if not isinstance(doc, dict):
    print("FAIL F7-4 ci.yml 根节点必须是映射")
    raise SystemExit(0)
if True in doc:  # YAML 1.1 把裸 on 解析成布尔 True
    doc["on"] = doc.pop(True)
jobs = doc.get("jobs") or {}
lines = []
expected = {"selftest-linux", "windows-core", "windows-full", "governance", "all-checks-passed"}
if set(jobs) == expected:
    lines.append("OK F7-4 job 集合恰为五 job 拓扑（selftest-linux/windows-core/windows-full/governance/all-checks-passed）")
else:
    lines.append("FAIL F7-4 job 集合恰为五 job 拓扑（缺 %s 多 %s）"
                 % (sorted(expected - set(jobs)), sorted(set(jobs) - expected)))
if "selftest-windows" in jobs:
    lines.append("FAIL F7-4 selftest-windows 已改名迁移为 windows-core（覆盖由 core+full 承接，非删覆盖）")
else:
    lines.append("OK F7-4 selftest-windows 已改名迁移为 windows-core（覆盖由 core+full 承接，非删覆盖）")
agg = jobs.get("all-checks-passed") if isinstance(jobs.get("all-checks-passed"), dict) else {}
needs = agg.get("needs") if isinstance(agg.get("needs"), list) else []
want = ["governance", "selftest-linux", "windows-core", "windows-full"]
if sorted(str(n) for n in needs) == want:
    lines.append("OK F7-4 聚合门 needs 恰含四项 linux/core/full/governance")
else:
    lines.append("FAIL F7-4 聚合门 needs 恰含四项（实得 %s）" % sorted(str(n) for n in needs))
text = "\n".join(str(s.get("run", "")) for s in (agg.get("steps") or []) if isinstance(s, dict))
missing = [j for j in want if ("needs.%s.result" % j) not in text]
if missing:
    lines.append("FAIL F7-4 聚合步读取四项 needs.<job>.result（缺 %s）" % ",".join(missing))
else:
    lines.append("OK F7-4 聚合步读取四项 needs.<job>.result")
triple = re.search(
    r'result="\s*\$\{\{\s*needs\.selftest-linux\.result\s*\}\}\s+'
    r'\$\{\{\s*needs\.windows-core\.result\s*\}\}\s+'
    r'\$\{\{\s*needs\.governance\.result\s*\}\}\s*"', text)
if triple and '"success success success"' in text:
    lines.append("OK F7-4 required 三元组须恰三 success（required 项 skipped 一律判失败）")
else:
    lines.append("FAIL F7-4 required 三元组须恰三 success（linux/core/governance 精确比较）")
if "needs.windows-full.result" in text and "skipped" in text:
    lines.append("OK F7-4 windows-full 结果允许 success 或 skipped（failure/cancelled 必须失败）")
else:
    lines.append("FAIL F7-4 windows-full 结果允许 success 或 skipped（failure/cancelled 必须失败）")
print("\n".join(lines))
PYTOP
)
CI_TOPO_RC=$?
assert_rc_is "F7-4b 拓扑断言器正常结束" 0 "$CI_TOPO_RC"
while IFS= read -r line; do
  case "$line" in
    'OK '*) ok "${line#OK }" ;;
    'FAIL '*) bad "${line#FAIL }" ;;
    '') : ;;
    *) bad "F7-4b 拓扑断言器异常输出：$line" ;;
  esac
done <<< "$CI_TOPO"

# 生成模板仍交付 A5：新实例预置 .github/workflows 后 init 应生成薄适配器并调用 A4。
T=$(new_case)
mkdir -p "$T/.github/workflows"
run_in "$T" init
A5_GEN="$T/.github/workflows/ponygo-governance.yml"
assert_exists "F7-4 生成模板：fresh init 仍产出 A5" "$A5_GEN"
if [ -f "$A5_GEN" ]; then
  A5_GEN_TXT=$(cat "$A5_GEN")
  assert_contains "F7-4 生成模板：A5 调用 A4" "$A5_GEN_TXT" "bash .meta/gates/ci-verify.sh"
fi

finish
