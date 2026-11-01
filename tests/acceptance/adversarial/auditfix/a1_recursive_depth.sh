#!/usr/bin/env bash
# L2-AT ①：递归护栏的两个入口（Lead 裁定第 7 条）。
#   A. 旧入口 env PONYGO_IN_SPEC=1（语义保留 ⊆ SKIPPED）：整轮视为「未验证」→ exit 3，
#      输出含 SKIPPED，且不得报「机械判据全部 PASS」。
#   B. 新入口 PONYGO_AUDIT_SPEC_DEPTH=1（第一层必须真跑，深度≥1 不得变绿）：
#      - 不得执行仓库内 spec（canary 副作用文件取证，非纯文本断言）；
#      - 必须有递归/护栏类输出；不得变绿；不得报「机械判据全部 PASS」。
#   C. 深度=2 同样不得变绿（深度单调：叠得越深越不能当验证）。
# 冻结契约来源：.dev-team/contract-matrix-auditfix.md（L2-AT ①）+ Lead 裁定第 6/7 条。
set -u
. "$(dirname "${BASH_SOURCE[0]}")/../../auditfix/lib.sh"

T=$(new_case)
if gov_repo "$T" 1; then
  MARKER="$T.canary-executed"
  rm -f "$MARKER"
  cat > "$T/.meta/gates/zz-canary.spec.sh" <<'SPECEOF'
#!/usr/bin/env bash
# 验收夹具：canary spec——被执行就留下副作用文件（用于证明「到底跑没跑」）
set -u
if [ -n "${CANARY_MARKER:-}" ]; then printf 'executed\n' >> "$CANARY_MARKER"; fi
printf '[zz-canary.spec] [ok] canary spec 被执行\n'
exit 0
SPECEOF
  chmod +x "$T/.meta/gates/zz-canary.spec.sh"

  # ---- 阳性对照：第一层（无任何护栏变量）必须真跑 ----
  run_in "$T" CANARY_MARKER="$MARKER" audit --run-specs
  assert_exists "AT1 对照：第一层无护栏变量时 canary spec 真被执行（副作用文件存在）" "$MARKER"
  assert_zero "AT1 对照：第一层全部真通过 → exit 0" "$R_RC"
  rm -f "$MARKER"

  # ---- A. 旧入口 PONYGO_IN_SPEC=1：⊆ SKIPPED（未验证）----
  run_in "$T" PONYGO_IN_SPEC=1 CANARY_MARKER="$MARKER" audit --run-specs
  assert_rc_is "AT1-A PONYGO_IN_SPEC=1 → exit 3（整轮 ⊆ SKIPPED/未验证）" 3 "$R_RC"
  assert_contains "AT1-A 输出含 SKIPPED" "$R_OUT" "SKIPPED"
  assert_not_contains "AT1-A 不得报「机械判据全部 PASS」" "$R_OUT" "机械判据全部 PASS"
  rm -f "$MARKER"

  # ---- B. 新入口 PONYGO_AUDIT_SPEC_DEPTH=1 ----
  run_in "$T" PONYGO_AUDIT_SPEC_DEPTH=1 CANARY_MARKER="$MARKER" audit --run-specs
  assert_missing "AT1-B 深度注入 → 不得执行仓库内 spec（无副作用文件）" "$MARKER"
  assert_matches "AT1-B 深度注入 → 必须有递归/护栏输出" "$R_OUT" "护栏|递归|嵌套|PONYGO_AUDIT_SPEC_DEPTH"
  assert_nonzero "AT1-B 深度注入 → 不得变绿（exit 非零）" "$R_RC"
  assert_not_contains "AT1-B 深度注入 → 不得报「机械判据全部 PASS」" "$R_OUT" "机械判据全部 PASS"

  # ---- C. 深度=2 ----
  rm -f "$MARKER"
  run_in "$T" PONYGO_AUDIT_SPEC_DEPTH=2 CANARY_MARKER="$MARKER" audit --run-specs
  assert_missing "AT1-C 深度=2 → 不得执行仓库内 spec" "$MARKER"
  assert_nonzero "AT1-C 深度=2 → 不得变绿（exit 非零）" "$R_RC"
fi

finish
