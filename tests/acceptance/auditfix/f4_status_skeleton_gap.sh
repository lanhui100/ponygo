#!/usr/bin/env bash
# F4（P1-4）：status 增「骨架文件」口径（与 upgrade 同一 UPGRADE_UNIVERSE），消除
# 「status 绿 / upgrade 缺口」的结论分裂。
#   F4-1 有缺失 → `骨架文件缺口：N` + `ponygo repair` 指引 + exit 1；NOGO `^骨架完整。$`
#   F4-2 N 与 upgrade 缺口行数逐一相等（同仓交叉判定，防口径分裂复发）
#   F4-3 无缺失 → `骨架文件与模板一致` + 维持现有退出语义（exit 0）
#   F4-4 骨架文件齐但级自洽 FAIL → 仍 exit 1（新口径不得把 FAIL 洗成 0）
# 冻结契约来源：.dev-team/contract-matrix-auditfix.md §5（F4-1…F4-4）。
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

T=$(new_case)
if gov_repo "$T" 1; then
  # ---- 基线：完整骨架 → status 0 且无缺口字样 ----
  run_in "$T" status
  assert_zero "F4 基线：骨架完整 → status exit 0" "$R_RC"
  assert_not_contains "F4 基线：无「骨架文件缺口」字样" "$R_OUT" "骨架文件缺口"

  # ---- F4-1/F4-2：造缺口（删一个 UPGRADE_UNIVERSE 内的骨架文件）----
  KEEP=$(drop_file "$T" ".agents/notes/README.md")
  assert_missing "F4 夹具：骨架文件已缺失" "$T/.agents/notes/README.md"

  run_in "$T" status
  assert_rc_is "F4-1 缺骨架文件 → status exit 1" 1 "$R_RC"
  assert_contains "F4-1 GO：打印「骨架文件缺口：N」" "$R_OUT" "骨架文件缺口："
  assert_matches "F4-1 GO：缺口数为十进制无前导零" "$R_OUT" '骨架文件缺口：[1-9][0-9]*'
  assert_contains "F4-1 GO：给出 ponygo repair 指引" "$R_OUT" "ponygo repair"
  assert_contains "F4-1 GO：缺口行点名具体文件 .agents/notes/README.md" "$R_OUT" ".agents/notes/README.md"
  assert_not_contains "F4-1 NOGO：不得再打印「骨架完整。」（与 upgrade 结论相反）" "$R_OUT" "骨架完整。"

  N_STATUS=$(printf '%s\n' "$R_OUT" | sed -n 's/.*骨架文件缺口：\([0-9][0-9]*\).*/\1/p' | head -n1)
  run_in "$T" upgrade
  N_UPGRADE=$(printf '%s\n' "$R_OUT" | grep -c '^缺口: ')
  assert_eq "F4-2 N 与 upgrade 缺口行数相等（status=$N_STATUS / upgrade=$N_UPGRADE）" \
    "${N_UPGRADE:-x}" "${N_STATUS:-y}"

  # ---- F4-3：补全后恢复绿灯 ----
  [ -n "$KEEP" ] && cp "$KEEP" "$T/.agents/notes/README.md"
  assert_exists "F4 夹具：骨架文件已补全" "$T/.agents/notes/README.md"

  run_in "$T" status
  assert_zero "F4-3 补全后 → status exit 0" "$R_RC"
  assert_not_contains "F4-3 补全后不再出现「骨架文件缺口」" "$R_OUT" "骨架文件缺口"
  assert_contains "F4-3 GO：无缺失时声明「骨架文件与模板一致」" "$R_OUT" "骨架文件与模板一致"

  # ---- F4-4：骨架文件齐但级自洽 FAIL → 仍 exit 1 ----
  rm -f "$T/docs/AGENTS.md"
  run_in "$T" status
  assert_rc_is "F4-4 骨架文件齐 + 级自洽 FAIL（缺 docs/AGENTS.md）→ status exit 1" 1 "$R_RC"
  assert_contains "F4-4 GO：结论面为「级自洽验证：未通过」" "$R_OUT" "级自洽验证：未通过"
  assert_not_contains "F4-4 NOGO：新口径不得把 FAIL 洗成「骨架文件缺口」" "$R_OUT" "骨架文件缺口"
fi

finish
