#!/usr/bin/env bash
# GH2 外壳：环境缺失是失败，不跳过结构验收。
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

if ! python3 -c 'import yaml' >/dev/null 2>&1; then
  bad "GH2 需要 python3 + PyYAML 做真实 YAML 结构断言"
else
  OUT=$(python3 "$GH_DIR/gh2_ci_aggregate.py" "$ROOT" 2>&1)
  RC=$?
  printf '%s\n' "$OUT"
  assert_zero "GH2 主 CI 与三类变异对抗" "$RC"
fi

# 本仓删除独立 A5 后，CLI 必须把主 CI 的 governance job 识别为等价执行面，不得误报适配器缺失。
run_cli "$ROOT" audit --level M
assert_zero "GH2 本仓 dogfood audit" "$R_RC"
assert_not_contains "GH2 不得把已聚合的 governance 误报为适配器缺失" "$R_OUT" "适配器缺失"
assert_contains "GH2 应识别 governance 执行面" "$R_OUT" "治理执行面已接线"
finish
