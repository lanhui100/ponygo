#!/usr/bin/env bash
# L2-AT ②：恶意 spec 挂死（sleep 999）。`audit --run-specs` 必须在超时护栏内返回：
# 外部 `timeout` 兜底断言「不得 hang」，返回码不得为 124（外层硬杀），也不得 0（假绿）。
# 禁 sleep 轮询：本用例只测「被测对象自身的超时护栏」，不用 sleep 等状态。
# 冻结契约来源：.dev-team/contract-matrix-auditfix.md（L2-AT ②）；
#   Wave-14 契约 C8/C9（.dev-team/contract-wave14.md §3）——外层兜底气窗口必须 = 内层预算 + 30s，
#   且与 CLI **同源推导**（PONYGO_SPEC_TIMEOUT 优先；未设则平台分档：Windows 180 / 其他 90）。
#   为什么不能写死常量：CLI 的软超时一旦按平台分档（Windows 180），写死的外层窗口就会窄于内层预算，
#   把「护栏正常工作」误判成「护栏失效」；宽于内层又会让「护栏失效」被外层兜底掩盖成绿。
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

# 与 ponygo run_gate_specs 同一判定口径：OSTYPE msys*/cygwin* 或 uname -s 含 MINGW/MSYS/CYGWIN（契约 C4）。
is_windows() {
  case "${OSTYPE:-}" in msys* | cygwin* | MSYS* | CYGWIN*) return 0 ;; esac
  case "$(uname -s 2>/dev/null)" in MINGW* | MSYS* | CYGWIN* | mingw* | msys* | cygwin*) return 0 ;; esac
  return 1
}
if [ -n "${PONYGO_SPEC_TIMEOUT:-}" ]; then
  INNER_BUDGET=$PONYGO_SPEC_TIMEOUT
elif is_windows; then
  INNER_BUDGET=180
else
  INNER_BUDGET=90
fi
OUTER_BUDGET=$((INNER_BUDGET + 30)) # 外层兜底 = 内层预算 + 30（契约 C8：Linux 90+30、Windows 180+30）

T=$(new_case)
if gov_repo "$T" 1; then
  rm -f "$T"/.meta/gates/*.spec.*
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
fi

finish
