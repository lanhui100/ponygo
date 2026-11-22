#!/usr/bin/env bash
# ============================================================
# tests/acceptance/observe-b027/run-all.sh —— B027 四项独立验收入口
#
# 用法：bash tests/acceptance/observe-b027/run-all.sh
#   退出码：0 = 四项全过；1 = 任一 case RED（FAIL 行原样回显在 case 段内）；2 = 配置错误
#   预算：每例 `PONYGO_GATE_SPEC_TIMEOUT`（默认 90s，KILL 5）；套件外层 = 每例预算 × 例数 + 30s
#   环境：PONYGO_CLI 可指向只读基线副本（先红后绿取证）；PONYGO_SPEC_NO_GUARD=1 时不加包裹
#
# 边界（诚实登记）：
#   - **不接入 tests/run.sh**：94 场景字面量是 gh6/R1 与 verify-p0 的硬锚，扩场景属范围变更；
#   - 本套件只读仓库：夹具与 skill 替身副本全在 `mktemp -d` 沙箱，EXIT 清理；
#   - skill 用 ./stub-skill（**内容驱动**退出码），验的是 ponygo 的判定面而非 skill 的规则集语义；
#     真 skill 端到端取证另落 .dev-team/b027-acceptance-receipt.md。
# ============================================================
set -u
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

CASES=(
  c1_carriers.sh
  c2_subcomponent.sh
  c3_multi_declaration.sh
  c4_comment_mount.sh
)

# 套件外层预算：每例预算 × 例数 + 30s 结算余量（外层必须宽于内层，否则内层自包裹永远来不及生效）
GT_ALL=${PONYGO_GATE_SPEC_TIMEOUT:-90}
case "$GT_ALL" in
  *[!0-9]*|0*) printf '[observe-b027] FAIL 非法 PONYGO_GATE_SPEC_TIMEOUT=%s（须为 1..86400 的正整数秒）\n' "$GT_ALL" >&2; exit 2 ;;
esac
SPEC_NAME=observe-b027
SPEC_TIMEOUT_SECS=$(( GT_ALL * ${#CASES[@]} + 30 ))
. "$HERE/selfwrap.sh"

TOTAL_PASS=0
TOTAL_FAIL=0
FAILED_CASES=""
FAILED_N=0
RAN=0
TMPLOG=$(mktemp) || exit 1
trap 'rm -f "$TMPLOG"' EXIT

for case_file in "${CASES[@]}"; do
  RAN=$((RAN + 1))
  printf '\n===== %s =====\n' "$case_file"
  # 清掉外层自包裹的 SELFRUN 信号：每个 case 必须自己再包一层 timeout（每例独立预算）
  env -u PONYGO_SPEC_SELFRUN bash "$HERE/$case_file" 2>&1 | tee "$TMPLOG"
  rc=${PIPESTATUS[0]}
  case_line=$(grep '^##CASE ' "$TMPLOG" | tail -n1)
  p=$(printf '%s\n' "$case_line" | sed -n 's/.* pass=\([0-9][0-9]*\).*/\1/p')
  n=$(printf '%s\n' "$case_line" | sed -n 's/.* fail=\([0-9][0-9]*\).*/\1/p')
  TOTAL_PASS=$((TOTAL_PASS + ${p:-0}))
  TOTAL_FAIL=$((TOTAL_FAIL + ${n:-0}))
  printf '##EXIT %s rc=%s\n' "$case_file" "$rc"
  if [ "$rc" -ne 0 ]; then
    FAILED_CASES="$FAILED_CASES ${case_file}(rc=$rc)"
    FAILED_N=$((FAILED_N + 1))
    printf -- '--- %s: RED (rc=%s)\n' "$case_file" "$rc"
  else
    printf -- '--- %s: GREEN (rc=%s)\n' "$case_file" "$rc"
  fi
done

printf '\n##SUMMARY observe-b027 cases=%s pass=%s fail=%s failed=%s\n' \
  "$RAN" "$TOTAL_PASS" "$TOTAL_FAIL" "$FAILED_N"
if [ -n "$FAILED_CASES" ]; then
  printf 'RED:%s\n' "$FAILED_CASES"
  printf '结果：FAIL（任一 case RED → exit 1）\n'
  exit 1
fi
printf '结果：PASS（B027 四项验收全过）\n'
exit 0
