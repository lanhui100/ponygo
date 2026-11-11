#!/usr/bin/env bash
# F8（ponygo audit/status --json）：机读审计面。
#   契约（Lead 裁决）：
#     * `audit --json`：stdout **单行** JSON，可被 `python3 -m json.tool` 解析；
#       字段词表固定 schema/command/tier/hits/total/level/level_declared/level_verified/
#       ladder{verdict,fails[]}/gates{local,remote}/miss_ids[]/exempt_gates[]/coverage/drift/
#       skills{baseline_missing,library{missing,installed},instance_owned,candidates}/gaps[]/
#       warnings[]/exit，schema=ponygo.audit/1；`exit` 必须等于进程真实退出码；
#       stdout 不得混入任何非 JSON 文本。
#     * `status --json`：ponygo.status/1 + level/level_declared/level_verified/skeleton{missing_dirs,
#       missing_files,drift}/gates/ladder/miss_ids[]/exempt_gates[]/coverage/warnings[]/exit。
#       P1 修复批（2026-11-11，p1-fixes 契约）新增 level_declared/level_verified/miss_ids/
#       exempt_gates/warnings 五个词表字段（未验证 ≠ 通过；豁免门名单派生自 UPGRADE_UNIVERSE）。
#
# 契约演进（Wave13 contract-matrix-wave13.md COV-J1~J6 / DR-J1~J5，Lead 裁定 2026-11-07）：
#   Wave13 新增两个固定词表字段——status/audit 均增 `coverage`，audit 另增 `drift`。
#   本文件原「顶层字段词表固定（多/少皆 FAIL）」断言按新契约**更新**词表并保留其强度
#   （仍是集合相等，多/少皆红）；另补 coverage/drift 的**形状**断言。
#   注意：契约只冻结字段**存在性与值**，不冻结键序——故断言用 set 比较，不锚定顺序。
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
want = {"schema","command","tier","hits","total","level","level_declared","level_verified","ladder","gates","coverage","drift","skills","gaps","miss_ids","exempt_gates","warnings","exit"}
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
# 期望迁移（T7 收口，2026-11-09）：本段夹具（gov_repo lv=1）**未声明 ai-surface** →
# 1.9b 未判定（SKIPPED ≠ PASS），机器面据实收窄 verified 并显式列 skipped:["1.9b"]。
# 逐字取自实测：`bash ponygo audit --json` →
#   "coverage":{"verified":["1.1-1.8"],"unverified":["1.10"],"skipped":["1.9b"],"reason":"readonly-no-repo-exec"}
# 保持原强度：值按字面精确相等、键集仍为集合相等（多/少皆红），只是把「未判」这一态补进契约。
json_assert "F8-1 GO：coverage 固定词表（verified/unverified/skipped/reason）" "$R_OUT" '
c = d.get("coverage")
if not isinstance(c, dict): fail.append("coverage 不是对象")
else:
    if c.get("verified") != ["1.1-1.8"]: fail.append("coverage.verified=%r" % (c.get("verified"),))
    if c.get("unverified") != ["1.10"]: fail.append("coverage.unverified=%r" % (c.get("unverified"),))
    if c.get("skipped") != ["1.9b"]: fail.append("coverage.skipped=%r" % (c.get("skipped"),))
    if c.get("reason") != "readonly-no-repo-exec": fail.append("coverage.reason=%r" % (c.get("reason"),))
if set(d.get("coverage", {}).keys()) != {"verified","unverified","skipped","reason"}:
    fail.append("coverage keys=%s" % sorted(d.get("coverage", {}).keys()))
'
json_assert "F8-1 GO：drift{count,files[]} 形状固定" "$R_OUT" '
dr = d.get("drift")
if not isinstance(dr, dict): fail.append("drift 不是对象")
else:
    if set(dr.keys()) != {"count","files"}: fail.append("drift keys=%s" % sorted(dr.keys()))
    if not isinstance(dr.get("count"), int): fail.append("drift.count 不是整数: %r" % (dr.get("count"),))
    if not isinstance(dr.get("files"), list): fail.append("drift.files 不是数组")
    if len(dr.get("files") or []) != dr.get("count"): fail.append("drift.count 与 files 长度不一致")
'
# skills 块（spec-ponygo-v2.6 §5.5「技能三层归属」；与 status 同源 compute_skills_state + json_skills）。
# 逐字取自实测（gov_repo lv=1 夹具）：
#   "skills":{"baseline_missing":[],"library":{"missing":[],"installed":[]},
#             "instance_owned":[],"candidates":[]}
# 技能面判不了时机器面据实收窄为 {"judged":false,"reason":"not-run"}——两种形态都必须自洽。
json_assert "F8-1 GO：skills 块词表固定（baseline_missing/library{missing,installed}/instance_owned/candidates）" "$R_OUT" '
sk = d.get("skills")
if not isinstance(sk, dict): fail.append("skills 不是对象: %r" % (sk,))
elif "judged" in sk:
    if sk.get("judged") is not False: fail.append("skills.judged 只允许 false: %r" % (sk,))
    if not isinstance(sk.get("reason"), str) or not sk.get("reason"): fail.append("skills.reason 非法: %r" % (sk,))
else:
    if set(sk.keys()) != {"baseline_missing","library","instance_owned","candidates"}:
        fail.append("skills keys=%s" % sorted(sk.keys()))
    for k in ("baseline_missing","instance_owned","candidates"):
        if not isinstance(sk.get(k), list): fail.append("skills.%s 不是数组" % k)
    lib = sk.get("library")
    if not isinstance(lib, dict): fail.append("skills.library 不是对象: %r" % (lib,))
    elif set(lib.keys()) != {"missing","installed"}: fail.append("skills.library keys=%s" % sorted(lib.keys()))
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
json_assert "F8-2 GO：status 字段（level/skeleton{...}/gates/ladder/coverage/exit）齐备" "$R_OUT" '
for k in ("level","skeleton","gates","ladder","coverage","exit"):
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

# ================= F8-4 同一二进制：不带旗标不得改变人类输出（CE-7 / L3DEF-12）=================
# 基线自证：不再拿 `git show HEAD:ponygo` 当对照（那对当前二进制是恒等式），改为**同一二进制**
# 的「带/不带 --json」对比；夹具用 level 2 + 已 sync（覆盖 2.6 判据分支）。
T=$(new_case)
gov_repo "$T" 2
run_in "$T" sync
assert_zero "F8-4 夹具：ponygo sync exit 0（2.6 走 PASS 分支）" "$R_RC"

ERRF=$(mktemp "$SBASE/err.XXXXXX")
A_OUT=$( cd "$T" && bash "$ROOT/ponygo" audit 2>/dev/null ); A_RC=$?
B_OUT=$( cd "$T" && bash "$ROOT/ponygo" audit 2>/dev/null ); B_RC=$?
assert_eq "F8-4 无旗标两次调用退出码一致" "$A_RC" "$B_RC"
if [ "$A_OUT" = "$B_OUT" ]; then
  ok "F8-4 GO：无旗标两次调用 stdout 逐字节一致（人类输出无抖动）"
else
  bad "F8-4 无旗标两次调用 stdout 不同（人类输出不稳定）"
fi

J_OUT=$( cd "$T" && bash "$ROOT/ponygo" audit --json 2>"$ERRF" ); J_RC=$?
J_ERR=$(cat "$ERRF" 2>/dev/null)
assert_eq "F8-4 --json 与无旗标退出码一致（$A_RC / $J_RC）" "$A_RC" "$J_RC"
assert_eq "F8-4 GO：--json 时 stdout 只有一行" 1 "$(printf '%s\n' "$J_OUT" | grep -c '')"
assert_matches "F8-4 GO：--json 的 stdout 是 JSON" "$J_OUT" '^\{'
assert_not_contains "F8-4 NOGO：--json 的 stdout 不得含人类文案" "$J_OUT" "===== ponygo 审计结果"
assert_contains "F8-4 GO：--json 时人类文案改走 stderr" "$J_ERR" "===== ponygo 审计结果"

assert_contains "F8-4 GO：无旗标时人类文案在 stdout" "$A_OUT" "===== ponygo 审计结果"
assert_contains "F8-4 GO：人类输出仍含命中行" "$A_OUT" "命中"
assert_contains "F8-4 GO：人类输出仍含级自洽结论行" "$A_OUT" "级自洽验证"
printf '%s' "$J_OUT" | python3 -m json.tool >/dev/null 2>&1
assert_zero "F8-4 GO：--json stdout 仍可被 json.tool 解析" "$?"

# ================= F8-5 status --json 的 skeleton 数组口径（L3 终审新增）=================
# 契约：skeleton.missing_dirs / missing_files / drift 必须是**数组**且元素为仓库相对路径；
#       missing_files 不得含 .meta/meta.yaml；missing_files 长度 == 人类输出「骨架文件缺口：N」。
T=$(new_case)
gov_repo "$T" 2
rm -f "$T/.agents/notes/README.md" "$T/.agents/skills/README.md"
rm -rf "$T/.meta/docs-tier"
assert_missing "F8-5 夹具：已删 2 个骨架文件 + 1 个骨架目录" "$T/.meta/docs-tier"

HUMAN_OUT=$( cd "$T" && bash "$ROOT/ponygo" status 2>&1 )
N_HUMAN=$(printf '%s\n' "$HUMAN_OUT" | sed -n 's/.*骨架文件缺口：\([0-9][0-9]*\).*/\1/p' | head -n1)
assert_matches "F8-5 夹具：人类输出给出「骨架文件缺口：N」（实得 [$N_HUMAN]）" "$N_HUMAN" '^[0-9]+$'

R_OUT=$( cd "$T" && bash "$ROOT/ponygo" status --json 2>/dev/null )
json_assert "F8-5 GO：skeleton 三个字段均为数组" "$R_OUT" '
sk = d.get("skeleton") or {}
for k in ("missing_dirs","missing_files","drift"):
    if not isinstance(sk.get(k), list): fail.append("%s 不是数组: %r" % (k, sk.get(k)))
'
DIRS=$(json_list "$R_OUT" "skeleton.missing_dirs")
FILES=$(json_list "$R_OUT" "skeleton.missing_files")
DRIFT=$(json_list "$R_OUT" "skeleton.drift")
assert_contains "F8-5 GO：missing_dirs 含被删目录 .meta/docs-tier" "$DIRS" ".meta/docs-tier"
assert_contains "F8-5 GO：missing_files 含被删文件 .agents/notes/README.md" "$FILES" ".agents/notes/README.md"
assert_not_contains "F8-5 NOGO：missing_files 不得含 .meta/meta.yaml（值文件不是骨架文件）" "$FILES" ".meta/meta.yaml"
assert_eq "F8-5 GO：missing_files 长度 == 人类输出「骨架文件缺口：N」" "$N_HUMAN" "$(printf '%s\n' "$FILES" | grep -c .)"
assert_eq "F8-5 GO：missing_dirs 长度 == 1（只删了 .meta/docs-tier）" 1 "$(printf '%s\n' "$DIRS" | grep -c .)"
assert_eq "F8-5 取证：本夹具 drift 为空数组" "" "$DRIFT"

# 元素必须是仓库相对路径且确实不存在
BAD_ABS=""
while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  case "$rel" in /*|~*) BAD_ABS="$BAD_ABS $rel"; continue ;; esac
  [ -e "$T/$rel" ] && BAD_ABS="$BAD_ABS ${rel}(存在)"
done <<EOF
$DIRS
$FILES
EOF
if [ -z "$BAD_ABS" ]; then
  ok "F8-5 GO：missing_dirs/missing_files 元素均为仓库相对路径且确实不存在"
else
  bad "F8-5 skeleton 数组元素不合规：$BAD_ABS"
fi

finish
