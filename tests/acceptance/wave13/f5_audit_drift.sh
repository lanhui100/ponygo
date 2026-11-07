#!/usr/bin/env bash
# ============================================================
# tests/acceptance/wave13/f5_audit_drift.sh
# audit 的骨架漂移**只读**报告：段标题逐字、计数正确、机器面 drift.count/files、
# 与 status 同口径、退出码不变。
#
# 契约真源：.dev-team/contract-matrix-wave13.md §6（DR-1 ~ DR-J5，冻结）
#           + plan-wave13.md §1 P1-3。
# 反假绿：① 零漂移态必须报「0 处」（否则「≥1」可能恒真）；② 改**一字节**（长度不变）；
#         ③ 漂移前后退出码逐一比对；④ 与 status.skeleton.drift 长度对齐（同口径）。
# ============================================================
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SKEL_REL=".agents/notes/README.md"   # UPGRADE_UNIVERSE 成员，且不属 ADR 判定面

# ---------- DR-1 / DR-2 / DR-6：零漂移态 ----------
T=$(new_case)
git_seed_repo "$T"
run_in "$T" init
assert_eq "DR 夹具：init exit 0" 0 "$R_RC"
write_adr "$T" "implemented/feature/2026-01-02-drift-clean.md"
run_in "$T" audit
RC_CLEAN=$R_RC
OUT_CLEAN=$R_OUT
assert_eq "DR-1 干净仓 audit exit 0" 0 "$RC_CLEAN"
assert_eq "DR-1 [GO] 段标题逐字恰 1 行" 1 \
  "$(printf '%s\n' "$OUT_CLEAN" | grep -c '^===== 骨架漂移（观察项，不改退出码） =====$')"
assert_contains "DR-2 [GO] 零漂移态报「漂移 0 处」" "$OUT_CLEAN" "漂移 0 处"
assert_not_contains "DR-2 [NOGO] 零漂移态不得列出文件" "$OUT_CLEAN" "漂移 1 处"
assert_not_contains "DR-6 [NOGO] 新资产 A6/A7 不得被算成漂移" "$OUT_CLEAN" "漂移 1 处："
run_split "$T" audit --json
assert_eq "DR-J 夹具：干净仓 audit --json exit 0" 0 "$R_RC"
assert_eq "DR-J5 [C] audit --json stdout 恰 1 行" 1 "$(printf '%s\n' "$R_OUT" | grep -c '')"
assert_contains "DR-J1 [GO] 字段形如 \"drift\":{\"count\":" "$R_OUT" '"drift":{"count":'
assert_contains "DR-J2 [GO] 零漂移逐字 \"drift\":{\"count\":0,\"files\":[]}" "$R_OUT" '"drift":{"count":0,"files":[]}'
assert_contains "DR-J4 [GO] schema 名不变" "$R_OUT" '"schema":"ponygo.audit/1"'

# ---------- DR-3 / DR-5 / DR-J3：改一字节 → 漂移 ≥1，退出码不变 ----------
T=$(new_case)
git_seed_repo "$T"
run_in "$T" init
write_adr "$T" "implemented/feature/2026-01-02-drift-tamper.md"
run_in "$T" audit
RC_BEFORE=$R_RC
SZ0=$(wc -c < "$T/$SKEL_REL")
tamper_one_byte "$T/$SKEL_REL"
assert_eq "DR-3 夹具：篡改后长度不变（只改一字节）" "$SZ0" "$(wc -c < "$T/$SKEL_REL")"
run_in "$T" audit
RC_AFTER=$R_RC
OUT_AFTER=$R_OUT
assert_eq "DR-5 [GO] 漂移不改变退出码（前 $RC_BEFORE / 后 $RC_AFTER）" "$RC_BEFORE" "$RC_AFTER"
assert_eq "DR-1 [GO] 漂移态段标题仍逐字恰 1 行" 1 \
  "$(printf '%s\n' "$OUT_AFTER" | grep -c '^===== 骨架漂移（观察项，不改退出码） =====$')"
N=$(printf '%s\n' "$OUT_AFTER" | sed -n 's/.*漂移 \([0-9][0-9]*\) 处：.*/\1/p' | head -n1)
assert_matches "DR-3 [GO] 报「漂移 N 处：」且 N 为整数（实得 [${N:-}]）" "${N:-}" '^[0-9]+$'
if [ -n "${N:-}" ] && [ "$N" -ge 1 ] 2>/dev/null; then
  ok "DR-3 [GO] 漂移计数 ≥1（实得 $N）"
else
  bad "DR-3 [GO] 漂移计数应 ≥1（实得 [${N:-未取到}]）"
fi
assert_contains "DR-3 [GO] 列出被改文件路径" "$OUT_AFTER" "${SKEL_REL##*/}"

run_split "$T" audit --json
assert_eq "DR-J3 夹具：漂移态 audit --json 退出码 == 人类输出" "$RC_AFTER" "$R_RC"
JN=$(printf '%s' "$R_OUT" | sed -n 's/.*"drift":{"count":\([0-9][0-9]*\),"files":\[\([^]]*\)\].*/\1/p')
JFILES=$(printf '%s' "$R_OUT" | sed -n 's/.*"drift":{"count":[0-9][0-9]*,"files":\[\([^]]*\)\].*/\1/p')
assert_matches "DR-J1 [GO] drift.count 为整数（实得 [${JN:-}]）" "${JN:-}" '^[0-9]+$'
if [ -n "${JN:-}" ] && [ "$JN" -ge 1 ] 2>/dev/null; then
  ok "DR-J3 [GO] drift.count ≥1（实得 $JN）"
else
  bad "DR-J3 [GO] drift.count 应 ≥1（实得 [${JN:-未取到}]）"
fi
assert_contains "DR-J1 [GO] drift.files 含被改文件" "$JFILES" "${SKEL_REL##*/}"
# count == files 数组长度
NJSON=$(printf '%s' "$JFILES" | tr ',' '\n' | grep -c '"')
assert_eq "DR-J3 [GO] drift.count == drift.files 长度" "${JN:-x}" "$NJSON"
# 与人类段计数一致
assert_eq "DR-J3 [GO] JSON count == 人类段 N（$N）" "${N:-x}" "${JN:-y}"

# ---------- DR-4：与 status 的 skeleton.drift 同口径 ----------
run_split "$T" status --json
SKELE=$(printf '%s' "$R_OUT" | sed -n 's/.*"skeleton":{"missing_dirs":\[[^]]*\],"missing_files":\[[^]]*\],"drift":\[\([^]]*\)\].*/\1/p')
NDR=$(printf '%s' "$SKELE" | tr ',' '\n' | grep -c '"')
assert_eq "DR-4 [GO] audit drift.count == status.skeleton.drift 长度" "${JN:-x}" "$NDR"

# ---------- DR-5b：审计失败态也照常报漂移（观察项不被吞）----------
T=$(new_case)
git_seed_repo "$T"
run_in "$T" init
printf 'level: 2\n' > "$T/.meta/meta.yaml"
write_adr "$T" "implemented/feature/badname.md"
tamper_one_byte "$T/$SKEL_REL"
run_in "$T" audit
assert_nonzero "DR-5b 违例仓 audit 非零（判据面照旧）" "$R_RC"
assert_contains "DR-5b [GO] 失败态仍打印骨架漂移段" "$R_OUT" "骨架漂移（观察项，不改退出码）"

finish
