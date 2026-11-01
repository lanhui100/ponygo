#!/usr/bin/env bash
# ============================================================
# tests/acceptance/auditfix/run-all.sh
# auditfix 验收总入口（F1–F7 + L2-AT 对抗）：纯 bash、零依赖。
# 用法：bash tests/acceptance/auditfix/run-all.sh
# 语义：任一用例文件失败 → 总 exit 1；全部通过 → exit 0。
# 每个用例是独立进程（隔离 mktemp 仓）；本脚本只做编排与汇总。
# ============================================================
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
ADV="$HERE/../adversarial/auditfix"

TOTAL_PASS=0; TOTAL_FAIL=0; FAILED_CASES=""; RAN=0
TMPLOG=$(mktemp) || exit 1
trap 'rm -f "$TMPLOG"' EXIT

run_case() { # <脚本绝对路径>
  local f="$1" rc case_line p n
  RAN=$((RAN+1))
  printf '\n===== %s =====\n' "$(basename "$f")"
  bash "$f" 2>&1 | tee "$TMPLOG"
  rc=${PIPESTATUS[0]}
  case_line=$(grep '^##CASE ' "$TMPLOG" | tail -n1)
  p=$(printf '%s\n' "$case_line" | sed -n 's/.* pass=\([0-9][0-9]*\).*/\1/p')
  n=$(printf '%s\n' "$case_line" | sed -n 's/.* fail=\([0-9][0-9]*\).*/\1/p')
  TOTAL_PASS=$((TOTAL_PASS + ${p:-0}))
  TOTAL_FAIL=$((TOTAL_FAIL + ${n:-0}))
  if [ "$rc" -ne 0 ]; then
    FAILED_CASES="$FAILED_CASES $(basename "$f")(rc=$rc)"
    printf -- '--- %s: RED (rc=%s)\n' "$(basename "$f")" "$rc"
  else
    printf -- '--- %s: GREEN (rc=0)\n' "$(basename "$f")"
  fi
}

for f in "$HERE"/f[0-9]*.sh; do
  [ -f "$f" ] || continue
  run_case "$f"
done

if [ -d "$ADV" ]; then
  for f in "$ADV"/a[0-9]*.sh; do
    [ -f "$f" ] || continue
    run_case "$f"
  done
fi

echo ""
echo "===== auditfix 验收汇总 ====="
printf '用例文件：%s 个\n' "$RAN"
printf '断言：pass=%s fail=%s\n' "$TOTAL_PASS" "$TOTAL_FAIL"
if [ -n "$FAILED_CASES" ]; then
  printf 'RED:%s\n' "$FAILED_CASES"
  echo "结果：FAIL（存在红用例；红相=被测契约尚未实现，转绿前不得放行）"
  exit 1
fi
echo "结果：PASS（全部用例绿）"
exit 0
