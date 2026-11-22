#!/usr/bin/env bash
# ============================================================
# tests/acceptance/observe-b027/selfwrap.sh —— 自包裹标准形态（照 `.meta/gates/adr-verify.spec.sh`）
#
# 契约（`.meta/gates/README.md`「负样本 spec 的两种形态」）：
#   - 上限 = `PONYGO_GATE_SPEC_TIMEOUT`（由 ponygo 派生下传，未设默认 90s），KILL 兜底 `-k 5`；
#   - 非法 / 越界（1..86400 之外）→ stderr FAIL + exit 2（绝不静默回退默认值，否则是假护栏）；
#   - 无 timeout 或 ponygo 报告守卫不可用（`PONYGO_SPEC_NO_GUARD=1`）时不加包裹（端到端如实降级）；
#   - 套件/用例内**零平台判定**（平台真值只留在 ponygo 一处）。
#
# 用法（必须放在被测脚本最前、source 其它文件之前）：
#   SPEC_NAME=<名字> [SPEC_TIMEOUT_SECS=<总预算>] . <本目录>/selfwrap.sh
#   `SPEC_TIMEOUT_SECS` 只给 run-all.sh 这类「一次跑多例」的入口用（总预算），单例不设 = 用 GT。
# ============================================================
GT=${PONYGO_GATE_SPEC_TIMEOUT:-90}
case "$GT" in
  *[!0-9]*|0*)
    printf '[%s] FAIL 非法 PONYGO_GATE_SPEC_TIMEOUT=%s（须为 1..86400 的正整数秒）\n' "${SPEC_NAME:-observe-b027}" "$GT" >&2
    exit 2 ;;
esac
if [ "${#GT}" -gt 5 ] || { [ "${#GT}" -eq 5 ] && [ "$GT" -gt 86400 ]; }; then
  printf '[%s] FAIL 非法 PONYGO_GATE_SPEC_TIMEOUT=%s（须为 1..86400 的正整数秒）\n' "${SPEC_NAME:-observe-b027}" "$GT" >&2
  exit 2
fi
SW_BUDGET=${SPEC_TIMEOUT_SECS:-$GT}
case "$SW_BUDGET" in
  *[!0-9]*|0*)
    printf '[%s] FAIL 非法 SPEC_TIMEOUT_SECS=%s（须为正整数秒）\n' "${SPEC_NAME:-observe-b027}" "$SW_BUDGET" >&2
    exit 2 ;;
esac
unset SPEC_TIMEOUT_SECS
if [ "${PONYGO_SPEC_SELFRUN:-0}" != "1" ] && [ "${PONYGO_SPEC_NO_GUARD:-0}" != "1" ] && command -v timeout >/dev/null 2>&1; then
  export PONYGO_SPEC_SELFRUN=1
  exec timeout -k 5 "$SW_BUDGET" bash "$0" "$@"
fi
