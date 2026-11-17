#!/usr/bin/env bash
# GH10：W2b 契约验收（U10 检索面同口径 / U9 框架仓空转的处置）
# 契约源：.dev-team/contract-w2b-u10-u9.md §3（T-U10-* / T-U9-*）
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

MANIFEST_REL=".meta/gates/no-residue.manifest"
GATE_REL=".meta/gates/no-residue.sh"

mk_residue_fixture() { # <dir>：.gitignore 忽略 dist/，dist 内残留被删字面串
  local d="$1"
  mkdir -p "$d/dist" "$d/.meta/gates"
  (cd "$d" && git init -q .)  # rg 只在 git 仓内应用 .gitignore（判据要证明的正是这条）
  printf 'dist/\n' > "$d/.gitignore"
  printf 'var legacySymbol = 1;\n' > "$d/dist/bundle.js"
  printf 'legacySymbol\t.\n' > "$d/$MANIFEST_REL"
  cp "$ROOT/$GATE_REL" "$d/$GATE_REL"
}

T=$(new_case)
mk_residue_fixture "$T"
OUT=$(mktemp -d)/o1; (cd "$T" && bash .meta/gates/no-residue.sh > "$OUT" 2>&1); echo $? > "$T/.rc1"
assert_nonzero "T-U10-1 被 .gitignore 忽略的残留，rg 路径必须判非零" "$(cat "$T/.rc1")"
assert_contains "T-U10-1b 命中点名被忽略目录内的文件" "$(cat "$OUT")" "dist/bundle.js"

OUT2=$(mktemp -d)/o2; (cd "$T" && NO_RESIDUE_FORCE_GREP=1 bash .meta/gates/no-residue.sh > "$OUT2" 2>&1); echo $? > "$T/.rc2"
assert_nonzero "T-U10-2 grep 退化路径同样判非零（两路径同口径）" "$(cat "$T/.rc2")"

rm -f "$T/dist/bundle.js"
(cd "$T" && bash .meta/gates/no-residue.sh >/dev/null 2>&1); echo $? > "$T/.rc3"
(cd "$T" && NO_RESIDUE_FORCE_GREP=1 bash .meta/gates/no-residue.sh >/dev/null 2>&1); echo $? > "$T/.rc4"
assert_zero "T-U10-3 正控制：去掉残留后 rg 路径 exit 0" "$(cat "$T/.rc3")"
assert_zero "T-U10-3b 正控制：去掉残留后 grep 路径 exit 0" "$(cat "$T/.rc4")"

(cd "$ROOT" && bash .meta/gates/no-residue.spec.sh >/dev/null 2>&1); echo $? > /tmp/gh10_a9.$$
assert_zero "T-U10-4 A9 负样本自检 exit 0（新增忽略目录用例后仍自洽）" "$(cat /tmp/gh10_a9.$$)"
rm -f /tmp/gh10_a9.$$

# U9：框架仓无清单 → 恒跳过是设计事实（不改成红、也不造空清单）
(cd "$ROOT" && bash "$GATE_REL" > "$T/.o5" 2>&1); echo $? > "$T/.rc5"
assert_zero "T-U9-1 本仓 no-residue 仍 exit 0（跳过不是失败）" "$(cat "$T/.rc5")"
assert_contains "T-U9-1b 输出明示跳过原因" "$(cat "$T/.o5")" "跳过（清单不存在"
assert_missing "T-U9-1c 不引入空清单仪式（框架仓仍无 manifest）" "$ROOT/$MANIFEST_REL"
assert_contains "T-U9-2 gates/README 写明空清单不构成验证" "$(cat "$ROOT/.meta/gates/README.md")" "空清单不构成验证"

finish
