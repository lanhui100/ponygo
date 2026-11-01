#!/usr/bin/env bash
# L2-AT ③：畸形 .meta/meta.yaml 穿透（level: abc / 引号变体）。
# 判据：不得崩溃（无 shell 级错误字面量）、不得静默放行（不得报通过/机械判据 PASS）。
#   1) level: abc          → status/audit 均非零，且点名 0.4/非法
#   2) level: "abc"（引号变体）→ 同上
#   3) level: "2"（引号数字）→ 不崩溃；若判通过，必须显式声明 L2（不得悄悄按别级放行）
# 冻结契约来源：.dev-team/contract-matrix-auditfix.md（L2-AT ③）；verify_ladder 0.4 判据。
set -u
. "$(dirname "${BASH_SOURCE[0]}")/../../auditfix/lib.sh"

T=$(new_case)
if gov_repo "$T" 1; then
  # ---- 1) level: abc ----
  printf 'level: abc\n' > "$T/.meta/meta.yaml"
  run_in "$T" status
  assert_no_crash "AT3a status 在 level:abc 下不得崩溃" "$R_OUT"
  assert_nonzero "AT3a status（level:abc）→ exit 非零" "$R_RC"
  assert_contains "AT3a status 点名判据 0.4 / 非法" "$R_OUT" "0.4"
  assert_not_contains "AT3a status 不得静默放行（无「机械判据全部 PASS」）" "$R_OUT" "机械判据全部 PASS"

  run_in "$T" audit
  assert_no_crash "AT3a audit 在 level:abc 下不得崩溃" "$R_OUT"
  assert_nonzero "AT3a audit（level:abc）→ exit 非零" "$R_RC"
  assert_not_contains "AT3a audit 不得静默放行（无「机械判据全部 PASS」）" "$R_OUT" "机械判据全部 PASS"

  # ---- 2) 引号变体 level: "abc" ----
  printf 'level: "abc"\n' > "$T/.meta/meta.yaml"
  run_in "$T" status
  assert_no_crash "AT3b status 在 level:\"abc\" 下不得崩溃" "$R_OUT"
  assert_nonzero "AT3b status（level:\"abc\"）→ exit 非零" "$R_RC"
  assert_not_contains "AT3b status 不得静默放行" "$R_OUT" "机械判据全部 PASS"

  run_in "$T" audit
  assert_no_crash "AT3b audit 在 level:\"abc\" 下不得崩溃" "$R_OUT"
  assert_nonzero "AT3b audit（level:\"abc\"）→ exit 非零" "$R_RC"
  assert_not_contains "AT3b audit 不得静默放行" "$R_OUT" "机械判据全部 PASS"

  # ---- 3) 引号数字 level: "2" ----
  printf 'level: "2"\n' > "$T/.meta/meta.yaml"
  run_in "$T" status
  assert_no_crash "AT3c status 在 level:\"2\" 下不得崩溃" "$R_OUT"
  if [ "$R_RC" -eq 0 ]; then
    assert_contains "AT3c 若判通过，必须显式声明 L2（不得悄悄按别级放行）" "$R_OUT" "L2"
  else
    ok "AT3c level:\"2\" 未判通过（exit=$R_RC，亦非静默放行）"
  fi
fi

finish
