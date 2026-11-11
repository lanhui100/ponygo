#!/usr/bin/env bash
# CA-10~16：exit 3 机读结论、drift unknown=-1、真实 L1_JUDGED 覆盖。
# 冻结真源：.dev-team/contract-matrix-carrier-audit.md §3/§3.1（Gate-1 最终口径）。
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

command -v python3 >/dev/null 2>&1 || { bad "CA-10~16 需要 python3 解析真实 JSON"; finish; }

# ---------- CA-10：四种证据不足路径均 exit 3 / verdict=unverified ----------
for mode in zero all-skipped partial-skipped recursion; do
  T=$(new_case); make_gov_repo "$T" 1 || finish
  case "$mode" in
    zero)
      remove_specs "$T"
      assert_eq "CA-10(zero) 夹具：spec 数为 0" 0 "$(find "$T/.meta/gates" -maxdepth 1 -type f -name '*.spec.*' | wc -l | tr -d ' ')"
      ;;
    all-skipped|partial-skipped)
      remove_specs "$T"
      cat > "$T/.meta/gates/z-skip.spec.sh" <<'SPECEOF'
#!/usr/bin/env bash
printf 'SKIPPED（carrier-audit 夹具：未真正执行）\n'
exit 0
SPECEOF
      if [ "$mode" = "partial-skipped" ]; then
        printf '#!/usr/bin/env bash\nprintf "[ok] 真跑通过\\n"\nexit 0\n' > "$T/.meta/gates/a-pass.spec.sh"
        chmod +x "$T/.meta/gates/a-pass.spec.sh"
      fi
      chmod +x "$T/.meta/gates/z-skip.spec.sh"
      ;;
    recursion)
      assert_file "CA-10(recursion) 夹具：真实 spec 在场" "$T/.meta/gates/adr-verify.spec.sh"
      ;;
  esac
  if [ "$mode" = "recursion" ]; then
    run_json "$T" PONYGO_IN_SPEC=1 audit --run-specs --json
  else
    run_json "$T" audit --run-specs --json
  fi
  assert_rc_is "CA-10($mode) 证据不足" 3 "$R_RC"
  assert_json_shape "CA-10($mode)" "$R_RC" "$R_OUT"
  json_assert "CA-10($mode) GO：ladder.verdict=unverified，禁止 pass/fail" "$R_OUT" "
if d.get('ladder', {}).get('verdict') != 'unverified': fail.append(d.get('ladder'))
"
  assert_contains "CA-10($mode) GO：人读披露 2.3 执行判据" "$R_ERR" "2.3 执行判据"
  assert_contains "CA-10($mode) GO：人读披露未验证" "$R_ERR" "未验证"
  assert_matches "CA-10($mode) GO：人读给出 exit 3/证据不足" "$R_ERR" 'exit 3|exit=3|证据不足'
  assert_not_contains "CA-10($mode) NOGO：不得宣称机械判据全部 PASS" "$R_ERR" "机械判据全部 PASS"
done

# CA-10 关键反例：无 meta + 0 spec，verify_ladder 从未执行，VL_VERDICT 初值为空。
# 这条专门穿过 json_verdict_fallback，防止通用「非零即 fail」把 exit 3 错写成 fail。
T=$(new_case)
assert_missing "CA-10(no-meta-zero) 夹具：确无 meta" "$T/.meta/meta.yaml"
assert_missing "CA-10(no-meta-zero) 夹具：确无 gates/spec" "$T/.meta/gates"
run_json "$T" audit --run-specs --json
assert_rc_is "CA-10(no-meta-zero) 证据不足" 3 "$R_RC"
assert_json_shape "CA-10(no-meta-zero)" "$R_RC" "$R_OUT"
json_assert "CA-10(no-meta-zero) GO：fallback 不得把 exit 3 写成 fail" "$R_OUT" "
if d.get('ladder', {}).get('verdict') != 'unverified': fail.append(d.get('ladder'))
c = d.get('coverage', {})
if c.get('verified') != [] or c.get('unverified') != ['1.1-1.10'] or c.get('reason') != 'l1-not-run': fail.append(c)
"
assert_contains "CA-10(no-meta-zero) GO：人读披露 2.3 未验证" "$R_ERR" "2.3 执行判据"
assert_contains "CA-10(no-meta-zero) GO：人读声明确无 meta 未跑 ladder" "$R_ERR" "级自洽验证：跳过（无 .meta/meta.yaml"
assert_not_contains "CA-10(no-meta-zero) NOGO：不得宣称机械判据全部 PASS" "$R_ERR" "机械判据全部 PASS"

# 正向对照：所有真实 spec 通过才允许 exit 0 / verdict=pass。
T=$(new_case); make_gov_repo "$T" 1 || finish
run_json "$T" audit --run-specs --json
assert_rc_is "CA-10 正对照：全部 spec 真跑通过" 0 "$R_RC"
assert_json_shape "CA-10 正对照" "$R_RC" "$R_OUT"
json_assert "CA-10 正对照：verdict=pass" "$R_OUT" "
if d.get('ladder', {}).get('verdict') != 'pass': fail.append(d.get('ladder'))
"
assert_contains "CA-10 正对照：人读已真跑并通过" "$R_ERR" "已真跑并通过"
# P1-2（2026-11-11）期望更新：人读输出新增常驻提示句「未验证门会拒绝（验证入口：…）」——
# 它声明「挂载 ≠ 已验证」，不是本命令的判定结果。剔除该句后再判「无未验证措辞」（原强度不变：
# 任何其它未验证措辞仍红）。
R_ERR_NOT_HINT=$(printf '%s\n' "$R_ERR" | sed 's/未验证门会拒绝（验证入口：[^）]*）//g')
assert_not_contains "CA-10 正对照：不得出现未验证" "$R_ERR_NOT_HINT" "未验证"

# ---------- CA-11：真实 ladder FAIL 优先于证据不足 ----------
T=$(new_case); make_gov_repo "$T" 2 || finish
git_at "$T" config --unset core.hooksPath >/dev/null 2>&1 || true
# P0-2（2026-11-11）：make_gov_repo(2) 会加装一对合规实例门；本用例要测「ladder FAIL 优先于证据不足」，
# 故先移除该实例门本体，再 remove_specs——否则「实例门存在但 spec 被删」会走 gate_spec_missing 硬失败早退，
# 根本到不了 ladder（2.4 就不会出现）。移除后：0 实例门 = 2.3 FAIL + 2.4 FAIL，都在 ladder 内，正是本用例要的。
rm -f "$T/.meta/gates/instance-gate.sh" "$T/.meta/gates/instance-gate.spec.sh"
remove_specs "$T"
run_json "$T" audit --run-specs --json
assert_rc_is "CA-11 GO：ladder FAIL 优先" 1 "$R_RC"
assert_json_shape "CA-11" "$R_RC" "$R_OUT"
json_assert "CA-11 GO：verdict=fail 且 fails 含 2.4" "$R_OUT" "
lad = d.get('ladder', {})
if lad.get('verdict') != 'fail': fail.append(lad)
if '2.4' not in lad.get('fails', []): fail.append(lad)
"
assert_contains "CA-11 GO：人读列出 2.4 硬失败" "$R_ERR" "2.4 本地层未接 ADR 门"
assert_not_contains "CA-11 NOGO：硬失败不得被洗成通过" "$R_ERR" "级自洽验证：通过"

# ---------- CA-12/13：drift unknown=-1；已判定 0/1 正向对照 ----------
T=$(new_case); make_gov_repo "$T" 1 || finish
assert_missing "CA-12 夹具：TMPDIR 目标不存在" "$T/tmp-does-not-exist"
run_json "$T" TMPDIR="$T/tmp-does-not-exist" audit --json
UNKNOWN_RC=$R_RC
assert_rc_is "CA-12 drift unknown 不改变既有退出码" 0 "$UNKNOWN_RC"
assert_json_shape "CA-12 unknown" "$R_RC" "$R_OUT"
json_assert "CA-12 GO：unknown 唯一形态 count=-1/files=[]/无 status" "$R_OUT" "
dr = d.get('drift', {})
if dr.get('count') != -1: fail.append(dr)
if dr.get('files') != []: fail.append(dr)
if 'status' in dr: fail.append(dr)
"
assert_contains "CA-12 GO：人读明确漂移未判定" "$R_ERR" "漂移未判定"
assert_not_contains "CA-12 NOGO：unknown 不得冒充零漂移" "$R_ERR" "漂移 0 处"

# CA-12 反例：比较器 cmp 本身失败时不得把未比较列成真实漂移。
T=$(new_case); make_gov_repo "$T" 1 || finish
BADBIN=$(new_case)
cat > "$BADBIN/cmp" <<'CMPEOF'
#!/usr/bin/env bash
exit 2
CMPEOF
chmod +x "$BADBIN/cmp"
PATH="$BADBIN:$PATH" cmp -s /dev/null /dev/null
assert_rc_is "CA-12(cmp-exit2) 夹具：PATH 注入 cmp 确实以 2 失败" 2 "$?"
run_json "$T" PATH="$BADBIN:$PATH" audit --json
assert_rc_is "CA-12(cmp-exit2) 比较失败不改变既有退出码" 0 "$R_RC"
assert_json_shape "CA-12(cmp-exit2)" "$R_RC" "$R_OUT"
json_assert "CA-12(cmp-exit2) GO：比较器失败必须为 count=-1/files=[]，不得列漂移" "$R_OUT" "
dr = d.get('drift', {})
if dr.get('count') != -1: fail.append(dr)
if dr.get('files') != []: fail.append(dr)
if 'status' in dr: fail.append(dr)
"
assert_contains "CA-12(cmp-exit2) GO：人读明确漂移未判定" "$R_ERR" "漂移未判定"
assert_not_contains "CA-12(cmp-exit2) NOGO：不得把 cmp exit 2 当真实漂移" "$R_ERR" "漂移 15 处"
assert_not_contains "CA-12(cmp-exit2) NOGO：不得冒充真实零漂移" "$R_ERR" "漂移 0 处"

run_json "$T" audit --json
assert_rc_is "CA-13 正对照：真实比较完成不改退出码" "$UNKNOWN_RC" "$R_RC"
assert_json_shape "CA-13 judged-zero" "$R_RC" "$R_OUT"
json_assert "CA-13 GO：真实零漂移 count=0/files=[]" "$R_OUT" "
dr = d.get('drift', {})
if dr.get('count') != 0 or dr.get('files') != []: fail.append(dr)
"
assert_contains "CA-13 GO：人读真实零漂移" "$R_ERR" "漂移 0 处"
assert_not_contains "CA-13 正对照：不得误报未判定" "$R_ERR" "漂移未判定"

printf '# carrier-audit：制造一处真实漂移\n' >> "$T/.agents/notes/README.md"
run_json "$T" audit --json
assert_rc_is "CA-13 正对照：一处漂移仍不改变退出码" "$UNKNOWN_RC" "$R_RC"
assert_json_shape "CA-13 judged-one" "$R_RC" "$R_OUT"
json_assert "CA-13 GO：count=1 且 files 恰为实际路径" "$R_OUT" "
dr = d.get('drift', {})
if dr.get('count') != 1: fail.append(dr)
if dr.get('files') != ['.agents/notes/README.md']: fail.append(dr)
"
assert_contains "CA-13 GO：人读漂移 1 处" "$R_ERR" "漂移 1 处"
assert_contains "CA-13 GO：人读列出实际漂移文件" "$R_ERR" ".agents/notes/README.md"

# ---------- CA-14：无 meta，L1 未跑 ----------
T=$(new_case)
run_json "$T" audit --json
assert_rc_is "CA-14 无 meta 保持既有退出码" 0 "$R_RC"
assert_json_shape "CA-14 no-meta" "$R_RC" "$R_OUT"
json_assert "CA-14 GO：未跑 L1 的 coverage 完整诚实形态" "$R_OUT" "
c = d.get('coverage', {})
if c.get('verified') != []: fail.append(c)
if c.get('unverified') != ['1.1-1.10']: fail.append(c)
if c.get('reason') != 'l1-not-run': fail.append(c)
if d.get('ladder', {}).get('verdict') != 'unverified': fail.append(d.get('ladder'))
"
assert_contains "CA-14 GO：人读声明无 meta 跳过级自洽" "$R_ERR" "级自洽验证：跳过（无 .meta/meta.yaml"
assert_not_contains "CA-14 NOGO：不得宣称机械判据全部 PASS" "$R_ERR" "机械判据全部 PASS"

# ---------- CA-15：level 0 与无 meta 同形，不另造原因 ----------
T=$(new_case); make_gov_repo "$T" 0 || finish
run_json "$T" audit --json
assert_rc_is "CA-15 level 0 保持既有退出码" 0 "$R_RC"
assert_json_shape "CA-15 level0" "$R_RC" "$R_OUT"
json_assert "CA-15 GO：level0 的 L1 同样未跑" "$R_OUT" "
c = d.get('coverage', {})
if c.get('verified') != []: fail.append(c)
if c.get('unverified') != ['1.1-1.10']: fail.append(c)
if c.get('reason') != 'l1-not-run': fail.append(c)
"
assert_contains "CA-15 GO：人读仍为纯 L0 合法终态" "$R_ERR" "纯 L0 长驻：合法终态"

# ---------- CA-16 正对照：L1 真跑且 PASS；1.9b 未判仍不得进 verified ----------
T=$(new_case); make_gov_repo "$T" 1 || finish
run_json "$T" audit --json
assert_rc_is "CA-16 正对照：L1 真跑 PASS" 0 "$R_RC"
assert_json_shape "CA-16 L1-pass" "$R_RC" "$R_OUT"
json_assert "CA-16 GO：仅实际范围 verified，1.10 仍只读未验" "$R_OUT" "
c = d.get('coverage', {})
if c.get('verified') != ['1.1-1.8']: fail.append(c)
if c.get('unverified') != ['1.10']: fail.append(c)
if c.get('skipped') != ['1.9b']: fail.append(c)
if c.get('reason') != 'readonly-no-repo-exec': fail.append(c)
if d.get('ladder', {}).get('verdict') != 'pass': fail.append(d.get('ladder'))
"
assert_contains "CA-16 正对照：人读级自洽通过" "$R_ERR" "级自洽验证：通过"

# CA-16：L1 真跑但 FAIL 也算已判，coverage 不得退回 l1-not-run。
T=$(new_case); make_gov_repo "$T" 1 || finish
: > "$T/.agents/notes/implemented/architecture/2026-01-02-zero-byte.md"
run_json "$T" audit --json
assert_rc_is "CA-16 对照：L1 真跑且 FAIL" 1 "$R_RC"
assert_json_shape "CA-16 L1-fail" "$R_RC" "$R_OUT"
json_assert "CA-16 GO：FAIL 也算真跑，verified 仍为实际范围" "$R_OUT" "
c = d.get('coverage', {})
if c.get('verified') != ['1.1-1.8']: fail.append(c)
if c.get('unverified') != ['1.10']: fail.append(c)
if c.get('reason') != 'readonly-no-repo-exec': fail.append(c)
if d.get('ladder', {}).get('verdict') != 'fail': fail.append(d.get('ladder'))
"
assert_contains "CA-16 对照：人读级自洽未通过" "$R_ERR" "级自洽验证：未通过"

# CA-16：ai-surface:on 时 1.9b 真判，verified 可扩至 1.1-1.9。
T=$(new_case); make_gov_repo "$T" 1 || finish
printf 'ai-surface: on\n' >> "$T/.meta/meta.yaml"
run_json "$T" audit --json
assert_rc_is "CA-16 正对照：ai-surface:on 的 L1 真跑" 0 "$R_RC"
assert_json_shape "CA-16 L1-on" "$R_RC" "$R_OUT"
json_assert "CA-16 GO：1.9b 真判才进入 verified" "$R_OUT" "
c = d.get('coverage', {})
if c.get('verified') != ['1.1-1.9']: fail.append(c)
if c.get('unverified') != ['1.10']: fail.append(c)
if 'skipped' in c: fail.append(c)
if c.get('reason') != 'readonly-no-repo-exec': fail.append(c)
"

finish
