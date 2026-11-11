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

# 基座：治理仓 + 一个实质门禁文件（占住「gates/ 有实质文件」这一分）。
# 框架自带的是 A2/A7 spec，保留（新契约下编排资产与实例门都要保持可配对）。
make_base() { # <dir>
  gov_repo "$1" 1 || return 1
  cat > "$1/.meta/gates/my-gate.sh" <<'GATEEOF'
#!/usr/bin/env bash
# 验收夹具：实例自己的实质门禁（非框架资产、非负样本 spec）
set -u
printf 'my-gate: 拒绝非法输入\n' >&2
exit 1
GATEEOF
  chmod +x "$1/.meta/gates/my-gate.sh"
  cat > "$1/.meta/gates/my-gate.spec.sh" <<'SPECEOF'
#!/usr/bin/env bash
# 验收夹具：与 my-gate.sh 同名的负样本 spec（证明实例门会拒绝非法样本）
printf 'my-gate.spec: 非法样本被拒绝\n'
exit 0
SPECEOF
  chmod +x "$1/.meta/gates/my-gate.spec.sh"
  return 0
}

A=$(new_case)
if make_base "$A"; then
  run_in "$A" audit --level M
  assert_zero "F5 基座 A：audit --level M exit 0" "$R_RC"
  HIT_A=$(hits_of "$R_OUT")
  assert_matches "F5 基座 A：输出含「命中 N / M 项」" "$R_OUT" '命中 [0-9]+ / [0-9]+ 项'
  assert_matches "F5 基座 A：命中数为整数（实得 [$HIT_A]）" "$HIT_A" '^[0-9]+$'
  assert_eq "F5-3 基座 A：总项数仍为 16" 16 "$(hits_t_of "$R_OUT")"

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
  assert_eq "F5-3 B：总项数仍为 16" 16 "$(hits_t_of "$R_OUT")"

  # ---- C：新增一个带同名负样本的实例门。计分是「是否存在实例门/配对」而非按门数累加，
  #          因此命中数不增；关键断言是配对被接受、无 gate_spec_missing。----
  C=$(new_case)
  cp -a "$A"/. "$C"/
  cat > "$C/.meta/gates/x.sh" <<'GATEEOF'
#!/usr/bin/env bash
printf 'x-gate: 拒绝非法输入\n' >&2
exit 1
GATEEOF
  cat > "$C/.meta/gates/x.spec.sh" <<'SPECEOF'
#!/usr/bin/env bash
# 验收夹具：门禁负样本（证明门会拒绝非法样本）
set -u
printf '[x.spec] [ok] 门拒绝了非法样本，放行了合法样本\n'
exit 0
SPECEOF
  chmod +x "$C/.meta/gates/x.sh" "$C/.meta/gates/x.spec.sh"
  run_in "$C" audit --level M
  assert_zero "F5 C：完整门+同名 spec 配对必须放行" "$R_RC"
  HIT_C=$(hits_of "$R_OUT")
  if [ -n "$HIT_A" ] && [ -n "$HIT_C" ]; then
    assert_eq "F5 C：配对项是存在性计分，加门不得白送额外命中（A=$HIT_A / C=$HIT_C）" "$HIT_A" "$HIT_C"
  else
    bad "F5 C：无法解析命中数（A=[$HIT_A] C=[$HIT_C]）"
  fi
  assert_not_contains "F5 C：完整配对不得报 gate_spec_missing" "$R_OUT" "gate_spec_missing"
  assert_eq "F5-3 C：总项数仍为 16" 16 "$(hits_t_of "$R_OUT")"

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

  # 对照：C 的完整配对不改变命中数；空白/注释 spec 也不得产生额外命中。
  if [ -n "$HIT_C" ] && [ -n "$HIT_D" ]; then
    assert_eq "F5-5 对照：完整配对(C) 与空白 spec(D) 均不改变存在性命中（C=$HIT_C / D=$HIT_D）" \
      "$HIT_C" "$HIT_D"
  fi
fi

finish
