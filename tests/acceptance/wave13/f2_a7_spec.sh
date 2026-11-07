#!/usr/bin/env bash
# ============================================================
# tests/acceptance/wave13/f2_a7_spec.sh
# A7 —— `.meta/gates/archive-verify.spec.sh`（A6 负样本自检）契约验收。
#
# 契约真源：.dev-team/contract-matrix-wave13.md §3（A7-0 ~ A7-12，冻结）
#           + §10-4（PONYGO_IN_SPEC 语义）+ Lead 裁决 2026-11-07。
# 反假绿核心：
#   ① [ok] 行**计数**（5 负样本 + 1 合法 = 6），禁 [fail]/SKIPPED；
#   ② 把 A6 换成恒 exit 0 的桩 → A7 必须变红（A7-7：证明自检不是摆设）；
#   ③ A7 必须以自身目录寻址 A6（A7-0 探针），且 PONYGO_IN_SPEC=1 不得自我跳过（A7-9）。
# 注：类名标签词表未冻结 → 只断言行数/大小写/结论词，不锚定中文类名（契约 §10-4）。
# ============================================================
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# ---------- A7-1：合法样本 → 0，6 条 [ok]，末行「通过」，无 [fail]/SKIPPED ----------
T=$(new_case); gov_repo "$T" 2 || finish
stage_archived_adr "$T" "testing/2026-01-02-a7-ok.md"
run_script "$T" "$A6_REL" seal
assert_eq "A7-1 夹具：合法封印 exit 0" 0 "$S_RC"
NOK0=$(find "$T/$ARCHIVED_REL" -name '*.md' ! -name 'README.md' ! -name 'AGENTS.md' | wc -l | tr -d ' ')
assert_eq "A7-1 取证：归档实体数 = 1（样本可判定）" 1 "$NOK0"

run_script "$T" "$A7_REL"
assert_eq "A7-1 [GO] 健康仓 A7 自检 exit 0" 0 "$S_RC"
assert_no_crash "A7-1 [NOGO] A7 不得崩溃/语法错" "$S_OUT"
assert_not_contains "A7-1 [NOGO] 不得出现 [fail] 行" "$S_OUT" "[fail]"
assert_not_contains "A7-1 [NOGO] 不得出现 SKIPPED（禁自我跳过）" "$S_OUT" "SKIPPED"
NOK=$(printf '%s\n' "$S_OUT" | grep -cF '[ok]')
assert_eq "A7-1 [GO] 逐项 [ok] 行数 = 6（5 负样本 + 1 合法样本）" 6 "$NOK"
assert_contains "A7-1 [GO] 末行含「通过」" "$(printf '%s\n' "$S_OUT" | tail -n1)" "通过"

# ---------- A7-7：A6 被弱化为恒 0 → A7 必须红（自检效力）----------
T=$(new_case); gov_repo "$T" 2 || finish
printf '#!/usr/bin/env bash\nexit 0\n' > "$T/$A6_REL"
chmod +x "$T/$A6_REL"
run_script_split "$T" "$A7_REL"
assert_eq "A7-7 [GO] A6 恒 0 桩 → A7 exit 1（不得空断言）" 1 "$S_RC"
assert_contains "A7-7 [GO] 输出出现 [fail] 行" "$S_OUT" "[fail]"
FAILLINE=$(printf '%s\n' "$S_OUT" | grep -F '[fail]' | head -n1)
if [ "${#FAILLINE}" -gt 6 ]; then
  ok "A7-7 [GO] [fail] 行带失败样本名（不被截断成空标记）"
else
  bad "A7-7 [GO] [fail] 行缺失败样本名（实得 [$FAILLINE]）"
fi
assert_matches "A7-7 [GO] stderr 含「失败」或「FAIL」" "$S_ERR" '失败|FAIL'

# ---------- A7-0：以自身所在目录寻址 A6（不依赖 cwd）----------
T=$(new_case)
GDIR="$T/some/deep/gates"; mkdir -p "$GDIR"
MARK="$T/A6_PROBE_RAN"
printf '#!/usr/bin/env bash\ntouch %q\nexit 0\n' "$MARK" > "$GDIR/archive-verify.sh"
chmod +x "$GDIR/archive-verify.sh"
if [ -f "$ROOT/$A7_REL" ]; then
  cp "$ROOT/$A7_REL" "$GDIR/archive-verify.spec.sh"
  chmod +x "$GDIR/archive-verify.spec.sh"
  UNREL="$T/unrelated"; mkdir -p "$UNREL"
  OUT_A70=$( cd "$UNREL" && bash "$GDIR/archive-verify.spec.sh" 2>&1 )
  if [ -f "$MARK" ]; then
    ok "A7-0 [GO] A7 以自身目录寻址 A6（cwd 无关目录下探针被执行）"
  else
    bad "A7-0 [GO] A7 未按自身目录寻址 A6（探针未执行，cwd=$UNREL）"
  fi
else
  bad "A7-0 [GO] 仓库模板缺失 $A7_REL（A7 未随框架交付 → 无法验证自身目录寻址）"
fi

# ---------- A7-8：夹具隔离（不改被检仓库、不留样本）----------
T=$(new_case); gov_repo "$T" 2 || finish
stage_archived_adr "$T" "testing/2026-01-02-a7-iso.md"
run_script "$T" "$A6_REL" seal
assert_eq "A7-8 夹具：封印 exit 0" 0 "$S_RC"
SNAP_ARCH=$(find "$T/$ARCHIVED_REL" -type f | LC_ALL=C sort | md5sum | awk '{print $1}')
run_script "$T" "$A7_REL"
assert_eq "A7-8 夹具：A7 exit 0" 0 "$S_RC"
SNAP_ARCH2=$(find "$T/$ARCHIVED_REL" -type f | LC_ALL=C sort | md5sum | awk '{print $1}')
assert_eq "A7-8 [NOGO] A7 不得在真仓 archived/ 留下样本" "$SNAP_ARCH" "$SNAP_ARCH2"
PORC0=$(git_at "$T" status --porcelain 2>/dev/null | md5sum | awk '{print $1}')
run_script "$T" "$A7_REL"
PORC1=$(git_at "$T" status --porcelain 2>/dev/null | md5sum | awk '{print $1}')
assert_eq "A7-8 [NOGO] A7 零写（git status --porcelain 快照前后一致）" "$PORC0" "$PORC1"

# ---------- A7-9：PONYGO_IN_SPEC=1 不得自我跳过 ----------
T=$(new_case); gov_repo "$T" 2 || finish
stage_archived_adr "$T" "testing/2026-01-02-a7-noskip.md"
run_script "$T" "$A6_REL" seal
S_RC=0; S_OUT=""
S_OUT=$( cd "$T" && PONYGO_IN_SPEC=1 bash "$A7_REL" 2>&1 ); S_RC=$?
assert_eq "A7-9 [GO] PONYGO_IN_SPEC=1 下 A7 仍 exit 0" 0 "$S_RC"
assert_not_contains "A7-9 [NOGO] 不得自我跳过（无 SKIPPED）" "$S_OUT" "SKIPPED"
NOK2=$(printf '%s\n' "$S_OUT" | grep -cF '[ok]')
assert_eq "A7-9 [GO] 全套样本仍完整执行（[ok] = 6）" 6 "$NOK2"

# ---------- A7-10：PONYGO_IN_SPEC 不改变 A6 语义 ----------
T=$(new_case); gov_repo "$T" 2 || finish
stage_archived_adr "$T" "testing/2026-01-02-a7-a6same.md"
run_script "$T" "$A6_REL" seal
assert_eq "A7-10 夹具：seal exit 0" 0 "$S_RC"
OUT_PLAIN=$( cd "$T" && bash "$A6_REL" check 2>&1 ); RC_PLAIN=$?
OUT_VAR=$( cd "$T" && PONYGO_IN_SPEC=1 bash "$A6_REL" check 2>&1 ); RC_VAR=$?
assert_eq "A7-10 [GO] 合法态：带/不带 PONYGO_IN_SPEC 退出码一致" "$RC_PLAIN" "$RC_VAR"
case "${RC_PLAIN:-x}" in
  0) ok "A7-10 [GO] 合法态 check exit 0（比对基线有效，非 127 壳）" ;;
  *) bad "A7-10 [GO] 合法态 check 应 exit 0（实得 ${RC_PLAIN:-?}）——比对基线无效" ;;
esac
if [ "$OUT_PLAIN" = "$OUT_VAR" ]; then
  ok "A7-10 [GO] 合法态：带/不带变量输出逐字节一致"
else
  bad "A7-10 [GO] 合法态：PONYGO_IN_SPEC 改变了 A6 输出"
fi
tamper_one_byte "$T/.agents/notes/archived/testing/2026-01-02-a7-a6same.md"
OUT_PLAIN=$( cd "$T" && bash "$A6_REL" check 2>&1 ); RC_PLAIN=$?
OUT_VAR=$( cd "$T" && PONYGO_IN_SPEC=1 bash "$A6_REL" check 2>&1 ); RC_VAR=$?
assert_eq "A7-10 [GO] 篡改态：带/不带变量退出码一致" "$RC_PLAIN" "$RC_VAR"
if [ "$OUT_PLAIN" = "$OUT_VAR" ]; then
  ok "A7-10 [GO] 篡改态：带/不带变量输出逐字节一致（A6 对变量无感）"
else
  bad "A7-10 [GO] 篡改态：PONYGO_IN_SPEC 改变了 A6 判定"
fi

# ---------- A7-11：无自我递归 + 耗时受控（< 60s）----------
T=$(new_case); gov_repo "$T" 2 || finish
stage_archived_adr "$T" "testing/2026-01-02-a7-time.md"
run_script "$T" "$A6_REL" seal
assert_eq "A7-11 夹具：seal exit 0" 0 "$S_RC"
if [ -f "$ROOT/$A7_REL" ]; then
  if grep -q 'archive-verify.spec.sh' "$ROOT/$A7_REL"; then
    bad "A7-11 [NOGO] A7 源码出现对自身 spec 的调用（潜在自我递归）"
  else
    ok "A7-11 [GO] A7 源码不调用自身 spec（无自我递归）"
  fi
fi
assert_exec "A7-11 前置：A7 存在且可执行（否则耗时为 0s 属空断言）" "$T/$A7_REL"
T0=$(date +%s)
run_script "$T" "$A7_REL"
T1=$(date +%s)
ELAPSED=$((T1 - T0))
assert_eq "A7-11 [GO] A7 exit 0" 0 "$S_RC"
if [ "$ELAPSED" -lt 60 ]; then
  ok "A7-11 [GO] 单次运行耗时 ${ELAPSED}s < 60s（NFR 预算内）"
else
  bad "A7-11 [NOGO] 单次运行耗时 ${ELAPSED}s ≥ 60s（超预算）"
fi

# ---------- A7-12：退出码值域 {0,1} ----------
for rc in "$RC_PLAIN" "$RC_VAR"; do
  case "$rc" in
    0|1) ok "A7-12 [GO] A6/A7 退出码 ∈ {0,1}（实得 $rc）" ;;
    *) bad "A7-12 [NOGO] 退出码越界（期望 0/1，实得 $rc）" ;;
  esac
done

finish
