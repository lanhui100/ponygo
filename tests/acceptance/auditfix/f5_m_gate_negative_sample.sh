#!/usr/bin/env bash
# F5（P1-6）：M 档「负样本 spec」判据只认 gates 下的门禁负样本（*.spec.*），
# 不得把普通单测（*.spec.ts / *_test.go / test_*.py …）算成「门会拒绝非法样本」。
#   对照法（同一基线的三个等价仓，唯一变量是新增文件）：
#     基座 A = 有实质门禁文件、**无** gates/*.spec.*，也无任何单测
#     B = A + 仓根 foo.spec.ts（普通单测）→ 命中数增量必须为 0
#     C = A + .meta/gates/x.spec.sh（真门禁负样本）→ 命中数增量必须为 +1
# 冻结契约来源：.dev-team/contract-matrix-auditfix.md（F5）、会话审计 P1-6。
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

hits_of() { hits_n_of "$1"; }

# 基座：治理仓 + 一个实质门禁文件（占住「gates/ 有实质文件」这一分），并清掉框架自带的 *.spec.*
make_base() { # <dir>
  gov_repo "$1" 1 || return 1
  rm -f "$1"/.meta/gates/*.spec.*
  cat > "$1/.meta/gates/my-gate.sh" <<'GATEEOF'
#!/usr/bin/env bash
# 验收夹具：实例自己的实质门禁（非框架资产、非负样本 spec）
set -u
printf 'my-gate: 拒绝非法输入\n' >&2
exit 1
GATEEOF
  chmod +x "$1/.meta/gates/my-gate.sh"
  return 0
}

A=$(new_case)
if make_base "$A"; then
  run_in "$A" audit --level M
  assert_zero "F5 基座 A：audit --level M exit 0" "$R_RC"
  HIT_A=$(hits_of "$R_OUT")
  assert_matches "F5 基座 A：输出含「命中 N / M 项」" "$R_OUT" '命中 [0-9]+ / [0-9]+ 项'
  assert_matches "F5 基座 A：命中数为整数（实得 [$HIT_A]）" "$HIT_A" '^[0-9]+$'
  assert_eq "F5-3 基座 A：总项数仍为 14" 14 "$(hits_t_of "$R_OUT")"

  # ---- B：加一个普通单测 foo.spec.ts（不在 gates/ 下）----
  B=$(new_case)
  cp -a "$A"/. "$B"/
  : > "$B/foo.spec.ts"
  run_in "$B" audit --level M
  HIT_B=$(hits_of "$R_OUT")
  if [ -n "$HIT_A" ] && [ -n "$HIT_B" ]; then
    assert_eq "F5 B：仓根 foo.spec.ts 不得让 M 档命中 +1（A=$HIT_A / B=$HIT_B）" "$HIT_A" "$HIT_B"
  else
    bad "F5 B：无法解析命中数（A=[$HIT_A] B=[$HIT_B]）"
  fi
  assert_eq "F5-3 B：总项数仍为 14" 14 "$(hits_t_of "$R_OUT")"

  # ---- C：加一个真门禁负样本 gates/x.spec.sh ----
  C=$(new_case)
  cp -a "$A"/. "$C"/
  cat > "$C/.meta/gates/x.spec.sh" <<'SPECEOF'
#!/usr/bin/env bash
# 验收夹具：门禁负样本（证明门会拒绝非法样本）
set -u
printf '[x.spec] [ok] 门拒绝了非法样本，放行了合法样本\n'
exit 0
SPECEOF
  chmod +x "$C/.meta/gates/x.spec.sh"
  run_in "$C" audit --level M
  HIT_C=$(hits_of "$R_OUT")
  if [ -n "$HIT_A" ] && [ -n "$HIT_C" ]; then
    assert_eq "F5 C：gates/x.spec.sh 必须让 M 档命中 +1（A=$HIT_A / C=$HIT_C）" \
      "$((HIT_A + 1))" "$HIT_C"
  else
    bad "F5 C：无法解析命中数（A=[$HIT_A] C=[$HIT_C]）"
  fi
  assert_eq "F5-3 C：总项数仍为 14" 14 "$(hits_t_of "$R_OUT")"

  # ---- F5-5（Wave 6「有效内容为空」口径）：空白 / 注释-only spec 不得计分 ----
  # D：1 字节空白 spec（printf '\n'）——有效内容为空，不是门禁负样本
  D=$(new_case)
  cp -a "$A"/. "$D"/
  printf '\n' > "$D/.meta/gates/blank.spec.sh"
  chmod +x "$D/.meta/gates/blank.spec.sh"
  assert_eq "F5-5 夹具：blank.spec.sh 恰 1 字节" 1 "$(wc -c < "$D/.meta/gates/blank.spec.sh" | tr -d ' ')"
  run_in "$D" audit --level M
  HIT_D=$(hits_of "$R_OUT")
  if [ -n "$HIT_A" ] && [ -n "$HIT_D" ]; then
    assert_eq "F5-5 D：1 字节空白 spec 不得让 M 档命中 +1（A=$HIT_A / D=$HIT_D）" "$HIT_A" "$HIT_D"
  else
    bad "F5-5 D：无法解析命中数（A=[$HIT_A] D=[$HIT_D]）"
  fi

  # E：注释-only spec——同样「无有效内容」，不得计分
  E=$(new_case)
  cp -a "$A"/. "$E"/
  printf '# 只有注释行，没有可执行内容\n' > "$E/.meta/gates/comment.spec.sh"
  chmod +x "$E/.meta/gates/comment.spec.sh"
  run_in "$E" audit --level M
  HIT_E=$(hits_of "$R_OUT")
  if [ -n "$HIT_A" ] && [ -n "$HIT_E" ]; then
    assert_eq "F5-5 E：注释-only spec 不得让 M 档命中 +1（A=$HIT_A / E=$HIT_E）" "$HIT_A" "$HIT_E"
  else
    bad "F5-5 E：无法解析命中数（A=[$HIT_A] E=[$HIT_E]）"
  fi

  # 对照：真有内容的 spec（C）必须是唯一 +1 的那一个
  if [ -n "$HIT_C" ] && [ -n "$HIT_D" ]; then
    assert_eq "F5-5 对照：真有内容 spec(C) 与空白 spec(D) 命中差恰为 1（C=$HIT_C / D=$HIT_D）" \
      "$((HIT_D + 1))" "$HIT_C"
  fi
fi

finish
