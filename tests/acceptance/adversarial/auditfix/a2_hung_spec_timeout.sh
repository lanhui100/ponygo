#!/usr/bin/env bash
# L2-AT ②：恶意 spec 挂死（sleep 999）。`audit --run-specs` 必须在超时护栏内返回：
# 外部 `timeout 60` 兜底断言「不得 hang」，返回码不得为 124（外层硬杀），也不得 0（假绿）。
# 禁 sleep 轮询：本用例只测「被测对象自身的超时护栏」，不用 sleep 等状态。
# 冻结契约来源：.dev-team/contract-matrix-auditfix.md（L2-AT ②）；run_gate_specs 头注「超时：30 秒上限」。
set -u
. "$(dirname "${BASH_SOURCE[0]}")/../../auditfix/lib.sh"

if ! command -v timeout >/dev/null 2>&1; then
  bad "AT2 需要 timeout 命令做外部兜底（当前环境缺失，无法断言「不得 hang」）"
  finish
fi

T=$(new_case)
if gov_repo "$T" 1; then
  rm -f "$T"/.meta/gates/*.spec.*
  cat > "$T/.meta/gates/zz-hang.spec.sh" <<'SPECEOF'
#!/usr/bin/env bash
# 验收夹具：挂死的恶意 spec（超时护栏必须拦住它）
set -u
sleep 999
printf '[zz-hang.spec] 永不到达\n'
exit 0
SPECEOF
  chmod +x "$T/.meta/gates/zz-hang.spec.sh"

  START=$(date +%s)
  run_timeout_in "$T" 60 audit --run-specs
  ELAPSED=$(( $(date +%s) - START ))

  if [ "$R_RC" -eq 124 ]; then
    bad "AT2 超时护栏失效：靠外层 timeout 60 兜底才结束（elapsed=${ELAPSED}s）"
  else
    ok "AT2 audit 在外部 60s 兜底内自行返回（elapsed=${ELAPSED}s，rc=$R_RC）"
  fi

  if [ "$ELAPSED" -lt 60 ]; then
    ok "AT2 返回耗时在护栏窗口内（${ELAPSED}s < 60s）"
  else
    bad "AT2 返回耗时超出护栏窗口（${ELAPSED}s）"
  fi
  assert_nonzero "AT2 挂死 spec 未被验证 → audit 不得变绿" "$R_RC"
fi

finish
