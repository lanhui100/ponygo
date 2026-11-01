#!/usr/bin/env bash
# F8（ponygo audit/status --json）：机读审计面。
#   契约（Lead 裁决）：
#     * `audit --json`：stdout **单行** JSON，可被 `python3 -m json.tool` 解析；
#       字段词表固定 schema/command/tier/hits/total/level/ladder{verdict,fails[]}/gates{local,remote}/gaps[]/exit，
#       schema=ponygo.audit/1；`exit` 必须等于进程真实退出码；stdout 不得混入任何非 JSON 文本。
#     * `status --json`：ponygo.status/1 + level/skeleton{missing_dirs,missing_files,drift}/gates/ladder/exit。
#     * 反向：--json 对 init|sync|retire|upgrade|observe init|observe upgrade 必须 die（非零 + 「仅适用于」）。
#     * 等价性：同一仓 `audit` 与 `audit --json` 退出码相同；不带 --json 的人类输出与 HEAD 版逐字节相同。
# 冻结契约来源：Lead 裁决（task-5 · F8）。
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

if ! command -v python3 >/dev/null 2>&1; then
  bad "F8 需要 python3（JSON 解析与 json.tool 校验）——当前环境缺失"
  finish
fi

# ================= F8-1 audit --json 契约 =================
T=$(new_case)
gov_repo "$T" 1
JSON_ERR="$T/.json-stderr"

run_in "$T" audit
RC_HUMAN=$R_RC
OUT_HUMAN=$R_OUT
assert_zero "F8-1 夹具：人类输出 audit exit 0" "$RC_HUMAN"

R_OUT=$( cd "$T" && bash "$ROOT/ponygo" audit --json 2>"$JSON_ERR" )
RC_JSON=$?
JSON_ERR_TXT=$(cat "$JSON_ERR" 2>/dev/null)
assert_eq "F8-1 audit --json 与人类输出退出码相同（human=$RC_HUMAN / json=$RC_JSON）" "$RC_HUMAN" "$RC_JSON"

# stdout 单行 + 无任何非 JSON 文本
LINE_N=$(printf '%s\n' "$R_OUT" | grep -c '' )
assert_eq "F8-1 GO：stdout 恰为单行" 1 "$LINE_N"
assert_matches "F8-1 GO：stdout 以 { 开头" "$R_OUT" '^\{'
assert_matches "F8-1 GO：stdout 以 } 结尾" "$R_OUT" '\}$'
printf '%s' "$R_OUT" | python3 -m json.tool >/dev/null 2>&1
assert_zero "F8-1 GO：stdout 可被 python3 -m json.tool 解析" "$?"

json_assert "F8-1 GO：schema=ponygo.audit/1" "$R_OUT" '
if d.get("schema") != "ponygo.audit/1": fail.append("schema=%r" % d.get("schema"))
if d.get("command") != "audit": fail.append("command=%r" % d.get("command"))
'
json_assert "F8-1 GO：顶层字段词表固定（多/少皆 FAIL）" "$R_OUT" '
want = {"schema","command","tier","hits","total","level","ladder","gates","gaps","exit"}
got = set(d.keys())
if got != want: fail.append("缺 %s / 多 %s" % (sorted(want-got), sorted(got-want)))
'
json_assert "F8-1 GO：ladder{verdict,fails[]} 词表固定" "$R_OUT" '
lad = d.get("ladder")
if not isinstance(lad, dict): fail.append("ladder 不是对象")
else:
    if set(lad.keys()) != {"verdict","fails"}: fail.append("ladder keys=%s" % sorted(lad.keys()))
    if not isinstance(lad.get("fails"), list): fail.append("ladder.fails 不是数组")
'
json_assert "F8-1 GO：gates{local,remote} 词表固定" "$R_OUT" '
g = d.get("gates")
if not isinstance(g, dict): fail.append("gates 不是对象")
elif set(g.keys()) != {"local","remote"}: fail.append("gates keys=%s" % sorted(g.keys()))
if not isinstance(d.get("gaps"), list): fail.append("gaps 不是数组")
if not isinstance(d.get("tier"), str) or not d.get("tier"): fail.append("tier 非法: %r" % d.get("tier"))
for k in ("hits","total","level","exit"):
    if not isinstance(d.get(k), int): fail.append("%s 不是整数: %r" % (k, d.get(k)))
'
json_assert "F8-1 GO：exit 字段 == 进程真实退出码（$RC_JSON）" "$R_OUT" "
if d.get('exit') != $RC_JSON: fail.append('exit=%r 实际 rc=%s' % (d.get('exit'), $RC_JSON))
"
assert_not_matches "F8-1 NOGO：stdout 不得混入人类文本" "$R_OUT" '=====|ponygo: |级自洽验证'

# ================= F8-2 status --json 契约 =================
T=$(new_case)
gov_repo "$T" 1
R_OUT=$( cd "$T" && bash "$ROOT/ponygo" status --json 2>/dev/null )
RC_ST=$?
assert_eq "F8-2 status --json 单行" 1 "$(printf '%s\n' "$R_OUT" | grep -c '')"
printf '%s' "$R_OUT" | python3 -m json.tool >/dev/null 2>&1
assert_zero "F8-2 GO：status --json 可被 json.tool 解析" "$?"
json_assert "F8-2 GO：schema=ponygo.status/1" "$R_OUT" '
if d.get("schema") != "ponygo.status/1": fail.append("schema=%r" % d.get("schema"))
'
json_assert "F8-2 GO：status 字段（level/skeleton{missing_dirs,missing_files,drift}/gates/ladder/exit）齐备" "$R_OUT" '
for k in ("level","skeleton","gates","ladder","exit"):
    if k not in d: fail.append("缺字段 %s" % k)
sk = d.get("skeleton") or {}
if not isinstance(sk, dict): fail.append("skeleton 不是对象")
elif set(sk.keys()) != {"missing_dirs","missing_files","drift"}:
    fail.append("skeleton keys=%s" % sorted(sk.keys()))
'
json_assert "F8-2 GO：status.exit == 进程真实退出码（$RC_ST）" "$R_OUT" "
if d.get('exit') != $RC_ST: fail.append('exit=%r 实际 rc=%s' % (d.get('exit'), $RC_ST))
"

# ================= F8-3 反向：--json 只属于 audit/status =================
T=$(new_case)
gov_repo "$T" 1
SK="$T/skill"; rm -rf "$SK"; cp -R "$STUB_SKILL_SRC" "$SK"
for cmdline in "init" "sync" "retire --level off" "upgrade" "observe init --kind cli --skill-dir $SK" "observe upgrade --skill-dir $SK"; do
  # shellcheck disable=SC2086
  run_in "$T" $cmdline --json
  assert_nonzero "F8-3 --json 对「$cmdline」必须 die（非零）" "$R_RC"
  assert_matches "F8-3 --json 对「$cmdline」给出「仅适用于」类文案" "$R_OUT" '仅适用于|仅适用'
done

# ================= F8-4 人类输出不受影响（与 HEAD 版逐字节相同） =================
T=$(new_case)
gov_repo "$T" 1
HEADP="$SBASE/ponygo-head"
if git -C "$ROOT" show HEAD:ponygo > "$HEADP" 2>/dev/null && [ -s "$HEADP" ]; then
  OUT_HEAD=$( cd "$T" && bash "$HEADP" audit 2>&1 ); RC_HEAD=$?
  OUT_CUR=$( cd "$T" && bash "$ROOT/ponygo" audit 2>&1 ); RC_CUR=$?
  assert_eq "F8-4 人类输出退出码与 HEAD 版相同（HEAD=$RC_HEAD / 当前=$RC_CUR）" "$RC_HEAD" "$RC_CUR"
  if [ "$OUT_HEAD" = "$OUT_CUR" ]; then
    ok "F8-4 GO：不带 --json 的人类输出与 HEAD 版逐字节相同"
  else
    bad "F8-4 人类输出与 HEAD 版不同（$(printf '%s\n' "$OUT_HEAD" > "$SBASE/h.txt"; printf '%s\n' "$OUT_CUR" > "$SBASE/c.txt"; diff "$SBASE/h.txt" "$SBASE/c.txt" | head -5 | tr '\n' ';')）"
  fi
else
  bad "F8-4 无法取得 HEAD 版 ponygo（git show HEAD:ponygo 失败）——无法做逐字节对照"
fi
assert_contains "F8-4 GO：人类输出仍含审计结果头" "$OUT_HUMAN" "===== ponygo 审计结果"
assert_contains "F8-4 GO：人类输出仍含命中行" "$OUT_HUMAN" "命中"
assert_contains "F8-4 GO：人类输出仍含级自洽结论行" "$OUT_HUMAN" "级自洽验证"

finish
