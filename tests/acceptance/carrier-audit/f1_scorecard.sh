#!/usr/bin/env bash
# CA-05~09：空 notes、四态结构、Status 内容与 gate_24_probe 同源计分。
# 冻结真源：.dev-team/contract-matrix-carrier-audit.md §2（Gate-1 最终口径）。
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

command -v python3 >/dev/null 2>&1 || { bad "CA-05~09 需要 python3 解析真实 JSON"; finish; }

audit_m() { # <dir>：人读/JSON 双面同跑，结果存 M_*
  local d="$1" hh
  run_in "$d" audit --level M
  M_HRC=$R_RC; M_HOUT=$R_OUT
  hh=$(hits_of "$M_HOUT")
  assert_matches "M 夹具：人读命中数可解析" "$hh" '^[0-9]+$'
  run_json "$d" audit --level M --json
  M_JRC=$R_RC; M_JOUT=$R_OUT; M_ERR=$R_ERR
  assert_eq "M 人读/JSON 退出码一致" "$M_HRC" "$M_JRC"
  assert_json_shape "M JSON" "$M_JRC" "$M_JOUT"
  M_HIT=$(json_get "$M_JOUT" "d['hits']")
  M_TOTAL=$(json_get "$M_JOUT" "d['total']")
  assert_eq "M 人读 hits 与 JSON hits 同源" "$hh" "$M_HIT"
  assert_eq "M 总项数恒为 14" 14 "$M_TOTAL"
  assert_eq "M 人读 total 与 JSON total 同源" 14 "$(total_of "$M_HOUT")"
}

# CA-05/07 正对照：有真实 ADR 时，决策数项与 Status 项均正常计分。
T=$(new_case); make_gov_repo "$T" 1 || finish
audit_m "$T"
FULL_HIT=$M_HIT
assert_rc_is "CA-07 正对照：合法 ADR audit M" 0 "$M_HRC"
json_assert "CA-07 正对照：不得误报 no_decisions" "$M_JOUT" "
if 'no_decisions' in d.get('gaps', []): fail.append(d.get('gaps'))
"
assert_not_contains "CA-07 正对照：人读不得误报无决策" "$M_HOUT" "notes/ 无任何决策"

# CA-05：仅删除真实决策，保留 notes/四态/README/AGENTS；M 档应恰少「决策数+Status+Alternatives」3 分。
clear_decisions "$T"
assert_eq "CA-05 夹具：真实决策数降为 0" 0 "$(decision_count "$T")"
for d in proposed implemented rejected archived; do
  assert_exists "CA-05 夹具：空 notes 仍保留四态/$d" "$T/.agents/notes/$d"
done
audit_m "$T"
EMPTY4_HIT=$M_HIT
assert_rc_is "CA-05 空 notes 保持既有 1.2 无决策 FAIL" 1 "$M_HRC"
assert_contains "CA-05 夹具：退出 1 归因于既有 1.2，而非新增漂移/JSON 分支" "$M_HOUT" "1.2 无决策记录"
assert_eq "CA-05 空 notes 不得白送决策数/Status 分（M 正对照连同 Alternatives 恰多 3）" 3 "$((FULL_HIT-EMPTY4_HIT))"
json_assert "CA-05 GO：JSON gaps 含 no_decisions" "$M_JOUT" "
if 'no_decisions' not in d.get('gaps', []): fail.append(d.get('gaps'))
"
assert_contains "CA-05 GO：人读保留无决策 gap" "$M_HOUT" "notes/ 无任何决策"

# CA-06：空 notes 的四态结构分独立；4/4 恰比 3/4 多 1，3/4、2/4、1/4 同分。
for n in 3 2 1; do
  C=$(new_case); make_gov_repo "$C" 1 || finish
  clear_decisions "$C"
  [ "$n" -le 3 ] || rm -rf "$C/.agents/notes/rejected"
  if [ "$n" -lt 4 ]; then rm -rf "$C/.agents/notes/rejected"; fi
  if [ "$n" -lt 3 ]; then rm -rf "$C/.agents/notes/archived"; fi
  if [ "$n" -lt 2 ]; then rm -rf "$C/.agents/notes/implemented"; fi
  left=$(find "$C/.agents/notes" -mindepth 1 -maxdepth 1 -type d \
    \( -name proposed -o -name implemented -o -name rejected -o -name archived \) | wc -l | tr -d ' ')
  assert_eq "CA-06 夹具：四态目录恰 $n/4" "$n" "$left"
  audit_m "$C"
  assert_rc_is "CA-06 $n/4 保持级自洽既有失败语义" 1 "$M_HRC"
  eval "EMPTY${n}_HIT=\$M_HIT"
  json_assert "CA-06 $n/4 仍有真实 no_decisions gap" "$M_JOUT" "
if 'no_decisions' not in d.get('gaps', []): fail.append(d.get('gaps'))
"
  assert_contains "CA-06 $n/4 人读无决策 gap 不丢失" "$M_HOUT" "notes/ 无任何决策"
done
assert_eq "CA-06 GO：空 notes 4/4 才获得四态结构分" 1 "$((EMPTY4_HIT-EMPTY3_HIT))"
assert_eq "CA-06 NOGO：3/4 不得比 2/4 多拿结构分" "$EMPTY2_HIT" "$EMPTY3_HIT"
assert_eq "CA-06 NOGO：2/4 不得比 1/4 多拿结构分" "$EMPTY1_HIT" "$EMPTY2_HIT"

# CA-07：0 字节 md 被计为真实决策，但缺 Status 必须让 Status 项恰少 1 分。
C=$(new_case); make_gov_repo "$C" 1 || finish
audit_m "$C"
GOOD_STATUS_HIT=$M_HIT
: > "$C/.agents/notes/implemented/architecture/2026-01-02-zero-byte.md"
assert_eq "CA-07 夹具：0 字节决策文件长度为 0" 0 "$(wc -c < "$C/.agents/notes/implemented/architecture/2026-01-02-zero-byte.md")"
assert_eq "CA-07 夹具：真实决策数增至 2" 2 "$(decision_count "$C")"
audit_m "$C"
assert_rc_is "CA-07 负样本：缺 Status 维持级自洽 FAIL" 1 "$M_HRC"
assert_eq "CA-07 GO：缺 Status 不得分（合法对照恰多 1）" 1 "$((GOOD_STATUS_HIT-M_HIT))"
assert_not_contains "CA-07 负样本不得误报 no_decisions" "$M_HOUT" "notes/ 无任何决策"
json_assert "CA-07 负样本 JSON 不得误报 no_decisions" "$M_JOUT" "
if 'no_decisions' in d.get('gaps', []): fail.append(d.get('gaps'))
"

# CA-08/09：同一 probe 驱动 2.4、gates.local、人读接线、评分与 gap。
H=$(new_case); make_gov_repo "$H" 2 || finish
audit_m "$H"
WIRED_HIT=$M_HIT
assert_rc_is "CA-08 正对照：真实接线仓 audit M" 0 "$M_HRC"
assert_contains "CA-09 正对照：人读治理门已接线" "$M_HOUT" "治理门接线：已接线"
json_assert "CA-08 正对照：gates.local=wired 且无 no_local_hook" "$M_JOUT" "
if d.get('gates', {}).get('local') != 'wired': fail.append(d.get('gates'))
if 'no_local_hook' in d.get('gaps', []): fail.append(d.get('gaps'))
"

git_at "$H" config core.hooksPath .empty-hooks
mkdir -p "$H/.empty-hooks"
assert_exists "CA-08 夹具：hooksPath 指向的目录确实存在" "$H/.empty-hooks"
assert_file "CA-08 夹具：旧 .githooks/pre-commit 仍存在（禁 fallback 冒充）" "$H/.githooks/pre-commit"
assert_eq "CA-08 夹具：hooksPath 已切到空目录" ".empty-hooks" "$(git_at "$H" config core.hooksPath)"
audit_m "$H"
assert_rc_is "CA-09 负样本：同一 probe 让 2.4 FAIL" 1 "$M_HRC"
assert_eq "CA-08 GO：空 hooksPath 目录不得加分（恰少 1）" 1 "$((WIRED_HIT-M_HIT))"
assert_contains "CA-09 GO：人读报告未接线" "$M_HOUT" "治理门接线：未接线"
assert_contains "CA-09 GO：人读沿用 probe 的钩子缺失因由" "$M_HOUT" "钩子缺失：.empty-hooks/pre-commit"
assert_contains "CA-09 GO：2.4 输出同一失败因由" "$M_HOUT" "2.4 本地层未接 ADR 门：钩子缺失：.empty-hooks/pre-commit"
json_assert "CA-08 GO：gates.local=not_wired 且 gaps 含 no_local_hook" "$M_JOUT" "
if d.get('gates', {}).get('local') != 'not_wired': fail.append(d.get('gates'))
if 'no_local_hook' not in d.get('gaps', []): fail.append(d.get('gaps'))
"
assert_contains "CA-08 GO：人读列本地 ADR 门缺口" "$M_HOUT" "本地 ADR 门未接线"

finish
