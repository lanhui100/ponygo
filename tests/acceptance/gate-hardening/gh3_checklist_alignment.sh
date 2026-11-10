#!/usr/bin/env bash
# GH3：文档静态契约 + CLI 真接线行为对照。
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

OUT=$(python3 "$GH_DIR/gh3_checklist_alignment.py" "$ROOT" 2>&1)
RC=$?
printf '%s\n' "$OUT"
assert_zero "GH3 checklist 2.3/2.4 静态口径" "$RC"

T=$(new_case)
if make_gov_repo "$T" 2; then
  run_cli "$T" audit --level M
  assert_rc_is "GH3 正对照：真实接线 audit M" 0 "$R_RC"
  mkdir -p "$T/.empty-hooks"
  (cd "$T" && git config core.hooksPath .empty-hooks)
  run_cli "$T" audit --level M
  assert_rc_is "GH3 反例：空 hooksPath 不得被当作接线" 1 "$R_RC"
  assert_contains "GH3 CLI 2.4 报真实未接线" "$R_OUT" "2.4 本地层未接 ADR 门"
  assert_contains "GH3 CLI 2.4 指向缺失 pre-commit" "$R_OUT" ".empty-hooks/pre-commit"
fi

# 2.3 行为真源：删光实例负样本 spec 必须在 L2 硬 FAIL。
T=$(new_case)
if make_gov_repo "$T" 2; then
  find "$T/.meta/gates" -maxdepth 1 -type f -name '*.spec.*' -delete
  run_cli "$T" audit --level M
  assert_rc_is "GH3 反例：L2 无负样本 spec 必须失败" 1 "$R_RC"
  assert_contains "GH3 CLI 2.3 报缺负样本 spec" "$R_OUT" "2.3"
  assert_matches "GH3 CLI 2.3 稳定指向负样本 spec 判据" "$R_OUT" '2\.3[^\n]*spec'
fi
finish
