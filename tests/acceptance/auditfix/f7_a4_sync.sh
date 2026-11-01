#!/usr/bin/env bash
# F7（A4 双写纪律）：ponygo 内的 ci-verify heredoc 与仓库模板 .meta/gates/ci-verify.sh
# 必须在 EOL 归一后**逐字节一致**。当前为红（模板已加 scratch-hygiene 三段，heredoc 未同步）。
# 冻结契约来源：.dev-team/contract-matrix-auditfix.md（F7）；plan-freeze §2「双写纪律」。
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

# ---- F7-2：新 init 仓生成的 A4 必须含仓库已加的 scratch-hygiene 三步 ----
T=$(new_case)
run_in "$T" init
assert_zero "F7-2 夹具：ponygo init（新仓）exit 0" "$R_RC"
GEN="$T/.meta/gates/ci-verify.sh"
assert_exists "F7-2 生成物 .meta/gates/ci-verify.sh 存在" "$GEN"
GEN_TXT=$(cat "$GEN" 2>/dev/null || :)
assert_contains "F7-2 GO：生成物含三步编号 [1/3]" "$GEN_TXT" "[1/3]"
assert_contains "F7-2 GO：生成物含三步编号 [2/3]" "$GEN_TXT" "[2/3]"
assert_contains "F7-2 GO：生成物含三步编号 [3/3]" "$GEN_TXT" "[3/3]"
assert_contains "F7-2 GO：生成物调用 scratch-hygiene.sh" "$GEN_TXT" "scratch-hygiene.sh"
assert_contains "F7-2 GO：生成物调用 scratch-hygiene.spec.sh" "$GEN_TXT" "scratch-hygiene.spec.sh"
assert_not_contains "F7-2 NOGO：生成物不得仍是两步编号 [1/2]" "$GEN_TXT" "[1/2]"

finish
