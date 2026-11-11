#!/usr/bin/env bash
# Windows 编码硬化（CI 实跑 run 43031069740）：cp1252 控制台下 python3 打印中文会抛
# UnicodeEncodeError → rc=1 且无 stdout（gh2 3/1、gh3 9/1、gh6 83/8 均为其连锁反应）。
# 在调用任何 python3 之前强制 UTF-8；standalone 执行时由本文件/lib.sh 顶部覆盖生效。
export PYTHONUTF8=1 PYTHONIOENCODING=utf-8
# carrier-audit 冻结验收入口：任一真实断言失败即 exit 1。
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
TOTAL_PASS=0; TOTAL_FAIL=0; FAILED_CASES=""; RAN=0
TMPLOG=$(mktemp) || exit 1
trap 'rm -f "$TMPLOG"' EXIT

for f in "$HERE"/f[0-9]*.sh; do
  [ -f "$f" ] || continue
  RAN=$((RAN+1))
  printf '\n===== %s =====\n' "$(basename "$f")"
  bash "$f" 2>&1 | tee "$TMPLOG"
  rc=${PIPESTATUS[0]}
  line=$(grep '^##CASE ' "$TMPLOG" | tail -n1)
  p=$(printf '%s\n' "$line" | sed -n 's/.* pass=\([0-9][0-9]*\).*/\1/p')
  n=$(printf '%s\n' "$line" | sed -n 's/.* fail=\([0-9][0-9]*\).*/\1/p')
  TOTAL_PASS=$((TOTAL_PASS + ${p:-0})); TOTAL_FAIL=$((TOTAL_FAIL + ${n:-0}))
  if [ "$rc" -ne 0 ]; then
    FAILED_CASES="$FAILED_CASES $(basename "$f")(rc=$rc)"
    printf -- '--- %s: RED (rc=%s)\n' "$(basename "$f")" "$rc"
  else
    printf -- '--- %s: GREEN (rc=0)\n' "$(basename "$f")"
  fi
done

printf '\n===== carrier-audit 验收汇总 =====\n用例文件：%s 个\n断言：pass=%s fail=%s\n' \
  "$RAN" "$TOTAL_PASS" "$TOTAL_FAIL"
if [ -n "$FAILED_CASES" ]; then
  printf 'RED:%s\n结果：FAIL（冻结契约未满足）\n' "$FAILED_CASES"
  exit 1
fi
[ "$RAN" -gt 0 ] || { echo "结果：FAIL（未发现用例文件）"; exit 1; }
echo "结果：PASS（全部冻结断言通过）"
exit 0
