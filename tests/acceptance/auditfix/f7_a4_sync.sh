#!/usr/bin/env bash
# F7（A4 双写纪律 + W3 契约演进 v4）：
#   F7-1 heredoc ≡ 仓库 .meta/gates/ci-verify.sh（EOL 归一后逐字节一致，双方均为**固定三段**）
#   F7-2 新 init 生成物为固定三段 [1/3][2/3][3/3]；NOGO 旧两段编号与任何 hygiene 门 / 守卫式跳过
#   F7-3 生成态 A4 实跑 exit 0（无 hygiene 资产时三段自洽，不得靠「有资产才跑」的守卫式）
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
    with open(ponygo_path, encoding="utf-8") as fh:
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
    with open(repo_path, encoding="utf-8") as fh:
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
assert_contains "F7-2 GO：生成物含三段编号 [1/3]" "$GEN_TXT" "[1/3]"
assert_contains "F7-2 GO：生成物含三段编号 [2/3]" "$GEN_TXT" "[2/3]"
assert_contains "F7-2 GO：生成物含三段编号 [3/3]" "$GEN_TXT" "[3/3]"
assert_not_contains "F7-2 NOGO：A4 不得残留旧两段编号 [1/2]" "$GEN_TXT" "[1/2]"
assert_not_contains "F7-2 NOGO：A4 不得残留旧两段编号 [2/2]" "$GEN_TXT" "[2/2]"
assert_contains "F7-2 GO：第 3 段覆盖归档封印门（archive-verify.sh）" "$GEN_TXT" "archive-verify.sh"
assert_contains "F7-2 GO：第 3 段覆盖 A7 自检（archive-verify.spec.sh）" "$GEN_TXT" "archive-verify.spec.sh"
assert_not_contains "F7-2 NOGO：A4 不得再含 hygiene 门（已挪到 A5 的独立 step）" "$GEN_TXT" "scratch-hygiene"
assert_not_contains "F7-2 NOGO：A4 不得用守卫式跳过（「有资产才跑」= 把门禁做成可选）" \
  "$GEN_TXT" "本实例无 scratch-hygiene 资产"

# ---- F7-3：生成态 A4 必须能真跑通（无 hygiene 资产的两步自洽 → exit 0）----
CIR=$( cd "$T" && bash .meta/gates/ci-verify.sh 2>&1 )
CIRC=$?
assert_zero "F7-3 生成态仓内 bash .meta/gates/ci-verify.sh → exit 0（三段自洽）" "$CIRC"
assert_contains "F7-3 取证：生成态 A4 实跑经过 [1/3]" "$CIR" "[1/3]"
assert_contains "F7-3 取证：生成态 A4 实跑经过 [2/3]" "$CIR" "[2/3]"
assert_contains "F7-3 取证：生成态 A4 实跑经过 [3/3]" "$CIR" "[3/3]"
assert_not_contains "F7-3 NOGO：实跑不得残留旧两段编号 [1/2]" "$CIR" "[1/2]"
assert_not_contains "F7-3 NOGO：生成态 A4 实跑不得出现 hygiene 段" "$CIR" "scratch-hygiene"

# ---- F7-4：本仓 A5 承载「固定两步之外的实例专属门」----
A5="$ROOT/.github/workflows/ponygo-governance.yml"
assert_exists "F7-4 本仓 A5 存在（.github/workflows/ponygo-governance.yml）" "$A5"
A5_TXT=$(cat "$A5" 2>/dev/null || :)
assert_contains "F7-4 GO：A5 仍调用 A4（bash .meta/gates/ci-verify.sh）" "$A5_TXT" "bash .meta/gates/ci-verify.sh"
assert_contains "F7-4 GO：A5 有 scratch-hygiene.sh 的独立 step" "$A5_TXT" "bash .meta/gates/scratch-hygiene.sh"
assert_contains "F7-4 GO：A5 有 scratch-hygiene.spec.sh 的独立 step" "$A5_TXT" "scratch-hygiene.spec.sh"
assert_contains "F7-4 GO：A5 有 bash ponygo audit --run-specs 的真实执行面" "$A5_TXT" "bash ponygo audit --run-specs"

finish
