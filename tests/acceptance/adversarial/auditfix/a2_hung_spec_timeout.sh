#!/usr/bin/env bash
# L2-AT ②：恶意 spec 挂死（sleep 999）。`audit --run-specs` 必须在超时护栏内返回：
# 外部 `timeout` 兜底断言「不得 hang」，返回码不得为 124（外层硬杀），也不得 0（假绿）。
# 禁 sleep 轮询：本用例只测「被测对象自身的超时护栏」，不用 sleep 等状态。
# 冻结契约来源：.dev-team/contract-matrix-auditfix.md（L2-AT ②）;
#   Wave-14 契约 C8/C9（.dev-team/contract-wave14.md §3）——外层兜底窗口必须 = 内层预算 + 30s，
#   且与 CLI **同源推导**。
#   Wave-15 B008（2026-11-22）：夹具**不再复刻平台真值**（删掉自带的平台判定函数）。预算唯一真源 =
#   SUT 结论区打印的 `  spec 预算=<N>s（来源：PONYGO_SPEC_TIMEOUT|平台默认）`（ponygo run_gate_specs
#   的可观测量 C12），夹具反向解析 N 并据此设外层兜底。平台分档只在 ponygo 一处。
#   前置取数调用（preflight）只跑「无 spec」的 audit（毫秒级），其兜底 PREFLIGHT_GUARD 是
#   **环境兜底**而非预算真值——故意远宽于任何平台默认，慢机不得把取数误判成失败。
set -u
. "$(dirname "${BASH_SOURCE[0]}")/../../auditfix/lib.sh"

if ! command -v timeout >/dev/null 2>&1; then
  bad "AT2 需要 timeout 命令做外部兜底（当前环境缺失，无法断言「不得 hang」）"
  finish
fi

# 环境变量若被外部预置，只接受正整数秒（契约 C1）；非法值不是本用例的考察对象，
# 但静默忽略会让内外层推导脱钩 → 直接判失败，禁止假绿。
if [ -n "${PONYGO_SPEC_TIMEOUT:-}" ]; then
  case "$PONYGO_SPEC_TIMEOUT" in
    *[!0-9]*) bad "AT2 环境预置 PONYGO_SPEC_TIMEOUT 非法（须为正整数秒：实得 [$PONYGO_SPEC_TIMEOUT]）"; finish ;;
  esac
  if [ "$PONYGO_SPEC_TIMEOUT" -le 0 ]; then
    bad "AT2 环境预置 PONYGO_SPEC_TIMEOUT 非法（须为正整数秒：实得 [$PONYGO_SPEC_TIMEOUT]）"
    finish
  fi
fi

# 形状自检（B008 防复发）：本夹具不得再自带平台判定。源码里不得出现平台推导符号。
SELF=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")
PLAT_SYM="is_""windows"
assert_eq "AT2 形状：夹具源码零平台推导残留（$PLAT_SYM 计数）" 0 "$(grep -c -- "$PLAT_SYM" "$SELF" 2>/dev/null || true)"

PREFLIGHT_GUARD=${PONYGO_AT2_PREFLIGHT_GUARD:-300}

T=$(new_case)
if ! gov_repo "$T" 1; then
  finish
fi
# 前置取数：先移除全部 spec（run_gate_specs 在「无 spec」时也打印预算行），把预算真值从 SUT 读出来。
rm -f "$T"/.meta/gates/*.spec.*

run_timeout_in "$T" "$PREFLIGHT_GUARD" audit --run-specs
PREFLIGHT_RC=$R_RC
PREFLIGHT_OUT=$R_OUT
if [ "$PREFLIGHT_RC" -eq 124 ]; then
  bad "AT2 预算取数调用超时（外部 ${PREFLIGHT_GUARD}s 兜底触发）——取不到 spec 预算行，判定不可信"
fi
BUDGET_LINE=$(printf '%s\n' "$PREFLIGHT_OUT" | sed -n 's/^\(  spec 预算=[0-9][0-9]*s（来源：[^）]*）\)$/\1/p' | head -n1)
INNER_BUDGET=$(printf '%s\n' "$BUDGET_LINE" | sed -n 's/^  spec 预算=\([0-9][0-9]*\)s（来源：.*）$/\1/p')
BUDGET_SRC=$(printf '%s\n' "$BUDGET_LINE" | sed -n 's/^  spec 预算=[0-9][0-9]*s（来源：\(.*\)）$/\1/p')

if [ -z "$INNER_BUDGET" ]; then
  bad "AT2 未取到 spec 预算行（SUT 未打印「spec 预算=<N>s（来源：…）」——契约 C12 可观测量缺失，无法同源推导外层兜底）"
  finish
fi
ok "AT2 从 SUT 取到 spec 预算行：${BUDGET_LINE#  }"
case "$INNER_BUDGET" in
  *[!0-9]*|0*) bad "AT2 SUT 报告的 spec 预算非法：[${INNER_BUDGET}]（须为正整数秒）"; finish ;;
esac
if [ "${#INNER_BUDGET}" -gt 5 ] || { [ "${#INNER_BUDGET}" -eq 5 ] && [ "$INNER_BUDGET" -gt 86400 ]; }; then
  bad "AT2 SUT 报告的 spec 预算越界：[${INNER_BUDGET}]（契约值域 1..86400）"
  finish
fi
case "$BUDGET_SRC" in
  PONYGO_SPEC_TIMEOUT|平台默认) ok "AT2 预算来源标签合法（${BUDGET_SRC}）" ;;
  *) bad "AT2 预算来源标签非预期：[${BUDGET_SRC}]（契约 C12 只允许 PONYGO_SPEC_TIMEOUT|平台默认）" ;;
esac
# 同源校验：env 预置时 SUT 必须采用该值（否则内外层推导脱钩）
if [ -n "${PONYGO_SPEC_TIMEOUT:-}" ]; then
  assert_eq "AT2 env 预置预算与 SUT 报告同源（PONYGO_SPEC_TIMEOUT 优先）" "$PONYGO_SPEC_TIMEOUT" "$INNER_BUDGET"
  assert_eq "AT2 env 预置时来源标签为 PONYGO_SPEC_TIMEOUT" "PONYGO_SPEC_TIMEOUT" "$BUDGET_SRC"
else
  assert_eq "AT2 未设 env 时来源标签为平台默认（平台分档只在 SUT 一处）" "平台默认" "$BUDGET_SRC"
fi

OUTER_BUDGET=$((INNER_BUDGET + 30)) # 外层兜底 = SUT 预算 + 30（契约 C8；平台分档已由 SUT 决定）

cat >"$T/.meta/gates/zz-hang.spec.sh" <<'SPECEOF'
#!/usr/bin/env bash
# 验收夹具：挂死的恶意 spec（超时护栏必须拦住它）
set -u
sleep 999
printf '[zz-hang.spec] 永不到达\n'
exit 0
SPECEOF
chmod +x "$T/.meta/gates/zz-hang.spec.sh"

START=$(date +%s)
run_timeout_in "$T" "$OUTER_BUDGET" audit --run-specs
ELAPSED=$(($(date +%s) - START))

if [ "$R_RC" -eq 124 ]; then
  bad "AT2 超时护栏失效：靠外层 timeout ${OUTER_BUDGET}s 兜底才结束（内层预算=${INNER_BUDGET}s，elapsed=${ELAPSED}s）"
else
  ok "AT2 audit 在外部 ${OUTER_BUDGET}s 兜底内自行返回（内层预算=${INNER_BUDGET}s，elapsed=${ELAPSED}s，rc=$R_RC）"
fi

if [ "$ELAPSED" -lt "$OUTER_BUDGET" ]; then
  ok "AT2 返回耗时在护栏窗口内（${ELAPSED}s < ${OUTER_BUDGET}s）"
else
  bad "AT2 返回耗时超出护栏窗口（${ELAPSED}s ≥ ${OUTER_BUDGET}s）"
fi
assert_nonzero "AT2 挂死 spec 未被验证 → audit 不得变绿" "$R_RC"

finish
