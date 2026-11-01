#!/usr/bin/env bash
# F2（P0-2 + Lead 裁定 OPEN-1/OPEN-4）：SKIPPED / 无 spec 必须有判定后果（fail-closed）。
#   F2-1 全真通过 → exit 0，结论行含「2.3 执行判据」，结论行不得含 SKIPPED/未验证
#   F2-2 0 spec + --run-specs → exit 3；GO「2.3 执行判据」+「未验证」+「exit 3/证据不足」；NOGO「机械判据全部 PASS」
#   F2-3 全 SKIPPED → exit 3；NOGO 再加「spec 全部自检通过」（禁把 SKIPPED 当 PASS）
#   F2-5 任一/多个 spec 失败 → exit 1，聚合报出**每个**失败 spec
#   F2-6 OPEN-1：--run-specs --dry-run → exit 0（不执行不判定），GO「SKIPPED」，NOGO「全部通过」/探针文件
#   F2-7 不带 --run-specs：退出码仍为 0/1，且无任何 spec 执行段/执行痕迹
#   F2-8 OPEN-4：一 FAIL 一 SKIPPED → exit 1（FAIL 优先于未验证）；判定器 FAIL + 未验证 → exit 1
# 冻结契约来源：.dev-team/contract-matrix-auditfix.md §3 + Lead 裁定 OPEN-1/OPEN-4。
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# ---- F2-2 / F2-7：0 spec ----
T=$(new_case)
if gov_repo "$T" 1; then
  rm -f "$T"/.meta/gates/*.spec.*
  assert_missing "F2-2 夹具：仓内确无 gates/*.spec.*" "$T/.meta/gates/adr-verify.spec.sh"

  run_in "$T" audit --run-specs
  assert_rc_is "F2-2 0 spec + --run-specs → exit 3（证据不足）" 3 "$R_RC"
  assert_contains "F2-2 GO：输出含「2.3 执行判据」" "$R_OUT" "2.3 执行判据"
  assert_contains "F2-2 GO：输出含「未验证」" "$R_OUT" "未验证"
  assert_matches "F2-2 GO：输出含「exit 3」或「证据不足」" "$R_OUT" "exit 3|exit=3|证据不足"
  assert_not_contains "F2-2 NOGO：禁止出现「机械判据全部 PASS」" "$R_OUT" "机械判据全部 PASS"

  # ---- F2-7 不带 --run-specs：执行判据是 opt-in ----
  run_in "$T" audit
  case "$R_RC" in
    0|1) ok "F2-7 不带 --run-specs → 退出码仍为 0/1（实得 $R_RC，不因缺 spec 变 3）" ;;
    *)   bad "F2-7 不带 --run-specs 退出码应为 0/1，实得 $R_RC" ;;
  esac
  assert_not_contains "F2-7 NOGO：不带 --run-specs 不得出现「===== 2.3 执行判据」段" "$R_OUT" "===== 2.3 执行判据"
  assert_not_contains "F2-7 NOGO：不带 --run-specs 不得出现 spec 执行行" "$R_OUT" "2.3 spec 自检"
fi

# ---- F2-3：全 SKIPPED ----
T=$(new_case)
if gov_repo "$T" 1; then
  rm -f "$T"/.meta/gates/*.spec.*
  cat > "$T/.meta/gates/zz-skip.spec.sh" <<'SPECEOF'
#!/usr/bin/env bash
# 验收夹具：spec 自报 SKIPPED 且 exit 0（= 门没跑，不得计入 PASS）
set -u
printf '[zz-skip.spec] SKIPPED（夹具：本次未真正跑门）\n'
exit 0
SPECEOF
  chmod +x "$T/.meta/gates/zz-skip.spec.sh"

  run_in "$T" audit --run-specs
  assert_rc_is "F2-3 全 SKIPPED + --run-specs → exit 3（证据不足）" 3 "$R_RC"
  assert_contains "F2-3 GO：输出含「2.3 执行判据」" "$R_OUT" "2.3 执行判据"
  assert_contains "F2-3 GO：输出含「未验证」" "$R_OUT" "未验证"
  assert_not_contains "F2-3 NOGO：禁止出现「机械判据全部 PASS」" "$R_OUT" "机械判据全部 PASS"
  assert_not_contains "F2-3 NOGO：禁止把 SKIPPED 当 PASS（「spec 全部自检通过」）" "$R_OUT" "spec 全部自检通过"
fi

# ---- F2-9（契约演进 #5）：**部分** spec 自报 SKIPPED 同样是「证据不足」----
# 判定：任一 spec 自报 SKIPPED（未真正验证）→ exit 3；FAIL 仍优先（1 > 3，见 F2-8）。
# 只有全部 spec 真跑通过才允许结论行出现「已真跑并通过」；有 skipped 时须给
# 「N 真跑通过 / M 未验证（SKIPPED）」计数，且禁写「机械判据全部 PASS」。
T=$(new_case)
if gov_repo "$T" 1; then
  rm -f "$T"/.meta/gates/*.spec.sh
  cat > "$T/.meta/gates/a-pass.spec.sh" <<'SPECEOF'
#!/usr/bin/env bash
# 验收夹具：真跑通过（exit 0，不自报 SKIPPED）
set -u
printf '[a-pass.spec] [ok] 门拒绝了非法样本，放行了合法样本
'
exit 0
SPECEOF
  cat > "$T/.meta/gates/b-skip.spec.sh" <<'SPECEOF'
#!/usr/bin/env bash
# 验收夹具：自报 SKIPPED 且 exit 0（= 未真正验证，不得计入 PASS）
set -u
printf '[b-skip.spec] SKIPPED（夹具：本次未真正跑门）
'
exit 0
SPECEOF
  chmod +x "$T/.meta/gates/a-pass.spec.sh" "$T/.meta/gates/b-skip.spec.sh"

  run_in "$T" audit --run-specs
  assert_rc_is "F2-9 部分 SKIPPED（1 真过 + 1 SKIPPED）→ exit 3（证据不足）" 3 "$R_RC"
  assert_contains "F2-9 GO：输出披露 SKIPPED（未验证）事实" "$R_OUT" "SKIPPED"
  assert_contains "F2-9 GO：输出用「未验证」措辞" "$R_OUT" "未验证"
  assert_matches "F2-9 GO：输出给出真跑通过计数面" "$R_OUT" '真跑通过'
  assert_not_contains "F2-9 NOGO：存在 SKIPPED 时不得写「机械判据全部 PASS」" \
    "$R_OUT" "机械判据全部 PASS"
  assert_not_contains "F2-9 NOGO：存在 SKIPPED 时不得写「已真跑并通过」" "$R_OUT" "已真跑并通过"
fi

# ---- F2-9 反向控制：两个 spec 都真过 → exit 0 且结论行「已真跑并通过」----
T=$(new_case)
if gov_repo "$T" 1; then
  rm -f "$T"/.meta/gates/*.spec.sh
  printf '#!/usr/bin/env bash\nprintf "[a-pass.spec] [ok] ok\\n"\nexit 0\n' > "$T/.meta/gates/a-pass.spec.sh"
  printf '#!/usr/bin/env bash\nprintf "[c-pass.spec] [ok] ok\\n"\nexit 0\n' > "$T/.meta/gates/c-pass.spec.sh"
  chmod +x "$T/.meta/gates/a-pass.spec.sh" "$T/.meta/gates/c-pass.spec.sh"

  run_in "$T" audit --run-specs
  assert_rc_is "F2-9 反向控制：全部真跑通过 → exit 0" 0 "$R_RC"
  assert_contains "F2-9 反向控制 GO：结论行「已真跑并通过」" "$R_OUT" "已真跑并通过"
  assert_not_contains "F2-9 反向控制 NOGO：不得出现「未验证」" "$R_OUT" "未验证"
fi

# ---- F2-6 OPEN-1：dry-run 不执行、不判定 → exit 0 ----
T=$(new_case)
if gov_repo "$T" 1; then
  cat > "$T/.meta/gates/zz-witness.spec.sh" <<'SPECEOF'
#!/usr/bin/env bash
# 验收夹具：探针 spec——被执行就留下 WITNESS.txt
set -u
printf 'witness\n' > .meta/gates/WITNESS.txt
printf '[zz-witness.spec] [ok] 探针 spec 被执行\n'
exit 0
SPECEOF
  chmod +x "$T/.meta/gates/zz-witness.spec.sh"
  rm -f "$T/.meta/gates/WITNESS.txt"
  assert_exists "F2-6 夹具：真 A2 spec 在场（dry-run 会**不**执行它）" "$T/.meta/gates/adr-verify.spec.sh"

  run_in "$T" audit --run-specs --dry-run
  assert_rc_is "F2-6 OPEN-1 --run-specs --dry-run → exit 0（不执行不判定）" 0 "$R_RC"
  assert_contains "F2-6 GO：dry-run 输出必须含 SKIPPED（如实披露未执行）" "$R_OUT" "SKIPPED"
  assert_not_contains "F2-6 NOGO：dry-run 不得宣称「全部通过」" "$R_OUT" "全部通过"
  assert_not_contains "F2-6 NOGO：dry-run 不得宣称「spec 全部自检通过」" "$R_OUT" "spec 全部自检通过"
  assert_missing "F2-6 NOGO：dry-run 不得执行 spec（无 WITNESS 探针）" "$T/.meta/gates/WITNESS.txt"
fi

# ---- F2-1：全部真通过 → exit 0，结论行声明执行判据已跑 ----
T=$(new_case)
if gov_repo "$T" 1; then
  run_in "$T" audit --run-specs
  assert_rc_is "F2-1 全部 spec 真通过 → exit 0" 0 "$R_RC"
  assert_contains "F2-1 GO：输出含「2.3 spec 自检：」" "$R_OUT" "2.3 spec 自检："
  assert_not_contains "F2-1 NOGO：全部真通过时不得出现「自报 SKIPPED」" "$R_OUT" "自报 SKIPPED"
  CONC=$(conclusion_of "$R_OUT")
  assert_contains "F2-1 GO：结论行含「2.3 执行判据」" "$CONC" "2.3 执行判据"
  assert_not_contains "F2-1 NOGO：结论行不得含 SKIPPED" "$CONC" "SKIPPED"
  assert_not_contains "F2-1 NOGO：结论行不得含「未验证」" "$CONC" "未验证"
fi

# ---- F2-5：多个 spec 失败必须聚合报出 ----
T=$(new_case)
if gov_repo "$T" 1; then
  rm -f "$T"/.meta/gates/*.spec.*
  printf '#!/usr/bin/env bash\nprintf "[bad.spec] 拒绝失败\\n" >&2\nexit 1\n' > "$T/.meta/gates/bad.spec.sh"
  printf '#!/usr/bin/env bash\nprintf "[bad2.spec] 工具错误\\n" >&2\nexit 5\n' > "$T/.meta/gates/bad2.spec.sh"
  chmod +x "$T/.meta/gates/bad.spec.sh" "$T/.meta/gates/bad2.spec.sh"

  run_in "$T" audit --run-specs
  assert_rc_is "F2-5 多个 spec 失败 → exit 1" 1 "$R_RC"
  assert_contains "F2-5 GO：输出含「[FAIL] 2.3 spec 自检失败：」" "$R_OUT" "[FAIL] 2.3 spec 自检失败："
  assert_contains "F2-5 GO：聚合列出 bad.spec.sh" "$R_OUT" "bad.spec.sh"
  assert_contains "F2-5 GO：聚合列出 bad2.spec.sh（exit>1 也算失败）" "$R_OUT" "bad2.spec.sh"
fi

# ---- F2-8 OPEN-4：FAIL 优先于未验证 ----
T=$(new_case)
if gov_repo "$T" 1; then
  rm -f "$T"/.meta/gates/*.spec.*
  printf '#!/usr/bin/env bash\nprintf "[zz-fail.spec] [fail]\\n"\nexit 1\n' > "$T/.meta/gates/zz-fail.spec.sh"
  printf '#!/usr/bin/env bash\nprintf "[zz-skip.spec] SKIPPED（夹具）\\n"\nexit 0\n' > "$T/.meta/gates/zz-skip.spec.sh"
  chmod +x "$T/.meta/gates/zz-fail.spec.sh" "$T/.meta/gates/zz-skip.spec.sh"

  run_in "$T" audit --run-specs
  assert_rc_is "F2-8 OPEN-4 任一 spec 失败 + 另有 SKIPPED → exit 1（FAIL 优先）" 1 "$R_RC"
fi

# ---- F2-8 OPEN-4（判定器 FAIL 面）：判定器 FAIL + spec 未验证 → exit 1 ----
T=$(new_case)
if gov_repo "$T" 2; then
  ( cd "$T" && git config --unset core.hooksPath ) >/dev/null 2>&1 || :
  run_in "$T" audit --run-specs
  assert_rc_is "F2-8 OPEN-4 判定器 FAIL（2.4 未接线）+ spec 未验证 → exit 1" 1 "$R_RC"
  assert_contains "F2-8 取证：FAIL 项为 2.4 未接 ADR 门" "$R_OUT" "2.4"
fi

# ---- F2-10（Wave 6「有效内容为空」口径）：空白 / 注释-only spec 不得被当作真跑通过 ----
# 1 字节空白（printf '\n'）与注释-only 文件的**有效内容为空**（剥空白行与 # 注释行后无字符）
# → 判 FAIL（exit 1），不得打「[ok] 2.3 spec 自检」，也不得出现「全部自检通过」。
for kind in blank comment; do
  T=$(new_case)
  gov_repo "$T" 1 || continue
  rm -f "$T"/.meta/gates/*.spec.sh
  if [ "$kind" = "blank" ]; then
    printf '\n' > "$T/.meta/gates/blank.spec.sh"
  else
    printf '# 只有注释，没有可执行内容\n' > "$T/.meta/gates/comment.spec.sh"
  fi
  chmod +x "$T"/.meta/gates/*.spec.sh
  if [ "$kind" = "blank" ]; then
    assert_eq "F2-10($kind) 夹具：空白 spec 恰 1 字节" 1 \
      "$(wc -c < "$T/.meta/gates/blank.spec.sh" | tr -d ' ')"
  fi

  run_in "$T" audit --run-specs
  assert_rc_is "F2-10($kind) 有效内容为空的 spec → exit 1（判 FAIL）" 1 "$R_RC"
  assert_matches "F2-10($kind) 输出点明「空 spec」类文案" "$R_OUT" '空 spec|空spec|无有效内容|有效内容为空'
  assert_not_contains "F2-10($kind) NOGO：不得出现「全部自检通过」" "$R_OUT" "全部自检通过"
  assert_not_contains "F2-10($kind) NOGO：不得打「[ok]   2.3 spec 自检」" "$R_OUT" "[ok]   2.3 spec 自检："
done

finish
