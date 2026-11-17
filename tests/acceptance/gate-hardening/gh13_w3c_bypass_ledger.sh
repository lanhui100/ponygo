#!/usr/bin/env bash
# GH13：W3c 契约验收（U7：逃生口留痕路径/格式契约 + audit 观察面）
# 契约源：.dev-team/contract-w3c-u7.md §5（T-U7-*）
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

T=$(new_case)
make_gov_repo "$T" 1
GCD=$(cd "$T" && git rev-parse --git-common-dir 2>/dev/null)
case "$GCD" in /*) : ;; *) GCD="$T/$GCD" ;; esac
mkdir -p "$GCD/ponygo-gate"
LEDGER="$GCD/ponygo-gate/bypass.log"

# 对照组：无 ledger → 不打印该行
run_cli "$T" audit
CTL_RC=$R_RC
assert_not_contains "T-U7-3 无 ledger → 不打印逃生口留痕行" "$R_OUT" "逃生口留痕"

# 两条合法行
printf '{"ts":"2026-11-17T21:00:00+0800","gate":"drift-strict","why":"集群 API 不可达，紧急发布","commit":"abc1234"}\n' > "$LEDGER"
printf '{"ts":"2026-11-17T21:05:00+0800","gate":"git-flow-gate","why":"热修复直推 master"}\n' >> "$LEDGER"
run_cli "$T" audit
assert_eq "T-U7-1 有 ledger 时退出码与对照组一致" "$CTL_RC" "$R_RC"
assert_contains "T-U7-1b 人读含条数" "$R_OUT" "逃生口留痕：2 条"
assert_contains "T-U7-1c 人读含最近一条 gate 名" "$R_OUT" "git-flow-gate"

# 非法行（缺 why）
printf '{"ts":"2026-11-17T21:10:00+0800","gate":"drift-strict"}\n' >> "$LEDGER"
run_cli "$T" audit
assert_eq "T-U7-2 非法行不改变退出码" "$CTL_RC" "$R_RC"
assert_contains "T-U7-2b 人读点名格式不合法条数" "$R_OUT" "其中 1 条格式不合法"

# JSON 词表零改动
run_json "$T" audit --json
assert_not_contains "T-U7-5 audit --json 不含逃生口字样（词表零改动）" "$R_OUT" "逃生口"

# 文档口径
G="$ROOT/.meta/gates/README.md"
for k in bypass.log ts gate why 非门禁; do
  assert_contains "T-U7-4 gates/README 含「$k」" "$(cat "$G")" "$k"
done

finish
