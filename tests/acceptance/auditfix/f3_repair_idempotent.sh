#!/usr/bin/env bash
# F3（P1-3 + Lead 裁定 OPEN-2/OPEN-3）：新增 `ponygo repair`——按模板幂等补骨架缺口，
# 且**不覆盖既有内容**。
#   1) 缺 .agents/notes/README.md + .agents/skills/README.md → repair 补回；先前被改写的
#      既有文件（.agents/notes/AGENTS.md）内容逐字节不变。
#   2) --dry-run 不改盘（缺文件仍缺、文件树零变化），且 OPEN-3：与实跑同码。
#   3) 再跑一次 repair（幂等）→ exit 0 且文件树零变化。
#   4) 无缺口仓 repair exit 0。
#   5) OPEN-2：无 .meta 的仓 repair → exit 1，且不得静默铺骨架。
#   6) `ponygo upgrade` 的缺口行必须指向 repair，而非死路 `ponygo init`。
# 冻结契约来源：.dev-team/contract-matrix-auditfix.md（F3）+ Lead 裁定 OPEN-2/OPEN-3。
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

T=$(new_case)
if gov_repo "$T" 1; then
  # ---- 先改写一个「已存在文件」，用于证明 repair 不覆盖既有内容 ----
  printf '\n# 实例自定义行（repair 不得覆盖本行）\n' >> "$T/.agents/notes/AGENTS.md"
  BEFORE_MD5=$(md5_of "$T/.agents/notes/AGENTS.md")
  assert_contains "F3 夹具：AGENTS.md 已含实例自定义行（覆盖判据的前提）" \
    "$(cat "$T/.agents/notes/AGENTS.md" 2>/dev/null)" "实例自定义行"
  assert_matches "F3 夹具：AGENTS.md 内容基线可计算（md5 非 MISSING）" "$BEFORE_MD5" '^[0-9a-f]{32}$'

  KEEP_NOTES=$(drop_file "$T" ".agents/notes/README.md")
  KEEP_SKILLS=$(drop_file "$T" ".agents/skills/README.md")
  assert_missing "F3 夹具：.agents/notes/README.md 已被移除（造缺口）" "$T/.agents/notes/README.md"
  assert_missing "F3 夹具：.agents/skills/README.md 已被移除（造缺口）" "$T/.agents/skills/README.md"

  # ---- 6) 先于修复取证：upgrade 的缺口行指向 repair ----
  run_in "$T" upgrade
  GAP_LINE=$(printf '%s\n' "$R_OUT" | grep -F '缺口: .agents/notes/README.md' | head -n1)
  assert_contains "F3 upgrade 缺口行指向 ponygo repair" "$GAP_LINE" "repair"
  assert_not_contains "F3 upgrade 缺口行不再让人去跑 ponygo init（死路）" "$GAP_LINE" "ponygo init"

  # ---- 2) --dry-run：零落盘（OPEN-3：与实跑同码）----
  SNAP_DRY=$(snap "$T")
  run_in "$T" repair --dry-run
  RC_DRY=$R_RC
  assert_zero "F3 repair --dry-run（有缺口）→ exit 0" "$RC_DRY"
  assert_missing "F3 repair --dry-run 不落盘（缺口仍缺）" "$T/.agents/notes/README.md"
  assert_same_tree "F3 repair --dry-run 文件树零变化" "$T" "$SNAP_DRY"

  # ---- 1) repair 补缺且不覆盖 ----
  run_in "$T" repair
  RC_REAL=$R_RC
  assert_zero "F3 repair（有缺口）→ exit 0" "$RC_REAL"
  assert_eq "F3 OPEN-3 repair --dry-run 与实跑同码" "$RC_DRY" "$RC_REAL"
  assert_exists "F3 repair 补回 .agents/notes/README.md" "$T/.agents/notes/README.md"
  assert_exists "F3 repair 补回 .agents/skills/README.md" "$T/.agents/skills/README.md"
  assert_contains "F3-1 GO：repair 输出具名被补文件 .agents/notes/README.md" "$R_OUT" ".agents/notes/README.md"
  assert_contains "F3-1 GO：repair 输出具名被补文件 .agents/skills/README.md" "$R_OUT" ".agents/skills/README.md"
  assert_eq "F3 repair 未覆盖既有文件内容（AGENTS.md 逐字节不变）" \
    "$BEFORE_MD5" "$(md5_of "$T/.agents/notes/AGENTS.md")"
  assert_contains "F3 repair 未删除实例自定义行" "$(cat "$T/.agents/notes/AGENTS.md" 2>/dev/null)" \
    "实例自定义行（repair 不得覆盖本行）"

  # ---- 3) 幂等 ----
  SNAP1=$(snap "$T")
  run_in "$T" repair
  assert_zero "F3 repair（已无缺口，幂等）→ exit 0" "$R_RC"
  assert_same_tree "F3 幂等 rerun 文件树零变化" "$T" "$SNAP1"

  # ---- 4) 无缺口仓 exit 0（含 dry-run 同码）----
  run_in "$T" repair --dry-run
  RC_NODRY=$R_RC
  run_in "$T" repair
  assert_zero "F3 repair（无缺口）→ exit 0" "$R_RC"
  assert_contains "F3-5 GO：无缺口时打印「零缺口」" "$R_OUT" "零缺口"
  assert_eq "F3 OPEN-3 无缺口时 dry-run 与实跑同码" "$RC_NODRY" "$R_RC"

  # 收尾：备份文件回填（保持临时目录可回收）
  [ -n "$KEEP_NOTES" ] && cp "$KEEP_NOTES" "$T/.agents/notes/README.md"
  [ -n "$KEEP_SKILLS" ] && cp "$KEEP_SKILLS" "$T/.agents/skills/README.md"
fi

# ---- 5) OPEN-2：无 .meta → repair exit 1（不得静默铺骨架）----
T=$(new_case)
run_in "$T" repair
assert_rc_is "F3 OPEN-2 无 .meta 的仓 repair → exit 1" 1 "$R_RC"
assert_contains "F3-3 GO：无 .meta 时输出指引 ponygo init" "$R_OUT" "ponygo init"
assert_missing "F3 OPEN-2 repair 不得静默铺骨架（.meta 仍不存在）" "$T/.meta"
assert_missing "F3 OPEN-2 repair 不得静默铺骨架（.agents 仍不存在）" "$T/.agents"

finish
