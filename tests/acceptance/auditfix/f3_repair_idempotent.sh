#!/usr/bin/env bash
# F3（P1-3 + Lead 二次裁定 CONTRACT-EVOLUTION v2）：骨架补缺**并入现有命令**——旗标形态
# `ponygo init --repair-skeleton`（依据命令面固定 ADR
# `.agents/notes/implemented/process/2026-08-30-six-command-surface.md`：新能力并入现有命令，
#  不得新增顶层命令；故 `ponygo repair` 子命令被否决）。
#   F3-1 只补缺失：缺 2 个骨架文件 → 恰补回 2 个（新增文件数 == 2，其余文件逐字节不变）
#   F3-2 绝不覆盖：已存在文件 sha256 前后全等（先改写 .agents/notes/AGENTS.md 再跑）
#   F3-4 --dry-run 零落盘 + 打印缺失清单；OPEN-3：dry-run 与实跑同码
#   F3-5 N=0 → 输出「骨架零缺口」，exit 0（幂等 rerun 亦零写）
#   F3-3 无 .meta 的仓：保持 init 既有语义（铺骨架、exit 0、不额外报错）
#   F3-6 upgrade 缺口行指向 `init --repair-skeleton`（不再指向死路 `ponygo init`）
#   CMD 命令面不变量：顶层命令词集合 == 基线 HEAD 实态
#       {init, audit, status, upgrade, sync, retire, observe}；不得出现 repair 命令词；
#       `ponygo repair` 必须被当作未知参数拒绝（非零退出 + 提示）。
# 冻结契约来源：.dev-team/contract-matrix-auditfix.md §4 + Lead 二次裁定（2026-11-01）。
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

T=$(new_case)
if gov_repo "$T" 1; then
  # ---- 先改写一个「已存在文件」，用于证明补缺绝不覆盖既有内容 ----
  printf '\n# 实例自定义行（补缺不得覆盖本行）\n' >> "$T/.agents/notes/AGENTS.md"
  BEFORE_MD5=$(md5_of "$T/.agents/notes/AGENTS.md")
  assert_contains "F3 夹具：AGENTS.md 已含实例自定义行（覆盖判据的前提）" \
    "$(cat "$T/.agents/notes/AGENTS.md" 2>/dev/null)" "实例自定义行"
  assert_matches "F3 夹具：AGENTS.md 内容基线可计算（md5 非 MISSING）" "$BEFORE_MD5" '^[0-9a-f]{32}$'

  KEEP_NOTES=$(drop_file "$T" ".agents/notes/README.md")
  KEEP_SKILLS=$(drop_file "$T" ".agents/skills/README.md")
  assert_missing "F3 夹具：.agents/notes/README.md 已被移除（缺口 1/2）" "$T/.agents/notes/README.md"
  assert_missing "F3 夹具：.agents/skills/README.md 已被移除（缺口 2/2）" "$T/.agents/skills/README.md"

  # ---- F3-6：先于修复取证：upgrade 的缺口行指向 `init --repair-skeleton` ----
  run_in "$T" upgrade
  GAP_LINE=$(printf '%s\n' "$R_OUT" | grep -F '缺口: .agents/notes/README.md' | head -n1)
  assert_contains "F3-6 GO：upgrade 缺口行指向 init --repair-skeleton" "$GAP_LINE" "--repair-skeleton"
  assert_not_contains "F3-6 NOGO：缺口行不得再指向死路「跑 'ponygo init' 补全」" \
    "$GAP_LINE" "跑 'ponygo init' 补全"

  # ---- F3-4：--dry-run 零落盘 + 打印清单 ----
  SNAP_DRY=$(snap "$T")
  run_in "$T" init --repair-skeleton --dry-run
  RC_DRY=$R_RC
  assert_zero "F3-4 init --repair-skeleton --dry-run（有缺口）→ exit 0" "$RC_DRY"
  assert_missing "F3-4 dry-run 不落盘（缺口 1/2 仍缺）" "$T/.agents/notes/README.md"
  assert_missing "F3-4 dry-run 不落盘（缺口 2/2 仍缺）" "$T/.agents/skills/README.md"
  assert_same_tree "F3-4 dry-run 文件树零变化" "$T" "$SNAP_DRY"
  assert_contains "F3-4 GO：dry-run 清单具名 .agents/notes/README.md" "$R_OUT" ".agents/notes/README.md"
  assert_contains "F3-4 GO：dry-run 清单具名 .agents/skills/README.md" "$R_OUT" ".agents/skills/README.md"
  assert_matches "F3-4 GO：dry-run 文案表明「仅计划/未落盘」" "$R_OUT" "dry-run|将补|计划"

  # ---- F3-1 / F3-2：实跑只补缺失、绝不覆盖 ----
  run_in "$T" init --repair-skeleton
  RC_REAL=$R_RC
  assert_zero "F3-1 init --repair-skeleton（有缺口）→ exit 0" "$RC_REAL"
  assert_eq "F3-4 OPEN-3 dry-run 与实跑同码" "$RC_DRY" "$RC_REAL"
  assert_exists "F3-1 补回 .agents/notes/README.md" "$T/.agents/notes/README.md"
  assert_exists "F3-1 补回 .agents/skills/README.md" "$T/.agents/skills/README.md"
  assert_contains "F3-1 GO：输出具名被补文件 .agents/notes/README.md" "$R_OUT" ".agents/notes/README.md"
  assert_contains "F3-1 GO：输出具名被补文件 .agents/skills/README.md" "$R_OUT" ".agents/skills/README.md"
  assert_eq "F3-2 已存在文件内容零改动（AGENTS.md 逐字节不变）" \
    "$BEFORE_MD5" "$(md5_of "$T/.agents/notes/AGENTS.md")"
  assert_contains "F3-2 未删除实例自定义行" "$(cat "$T/.agents/notes/AGENTS.md" 2>/dev/null)" \
    "实例自定义行（补缺不得覆盖本行）"

  # 只补缺失的强判据：新增文件恰 2 个、零删除、其余文件 cksum 全等
  SNAP_AFTER=$(snap "$T")
  ADDED=$(comm -13 <(printf '%s\n' "$SNAP_DRY") <(printf '%s\n' "$SNAP_AFTER") | wc -l | tr -d ' ')
  REMOVED=$(comm -23 <(printf '%s\n' "$SNAP_DRY") <(printf '%s\n' "$SNAP_AFTER") | wc -l | tr -d ' ')
  assert_eq "F3-1 只补缺失：新增文件恰为 2 个（实得 $ADDED）" 2 "$ADDED"
  assert_eq "F3-2 绝不覆盖：既有文件零变化/零删除（实得 $REMOVED）" 0 "$REMOVED"

  # ---- F3-5：N=0 → 「骨架零缺口」，且幂等零写 ----
  run_in "$T" init --repair-skeleton
  assert_zero "F3-5 无缺口时 init --repair-skeleton → exit 0" "$R_RC"
  assert_contains "F3-5 GO：N=0 时输出「骨架零缺口」" "$R_OUT" "骨架零缺口"
  assert_same_tree "F3-5 无缺口时零写（幂等）" "$T" "$SNAP_AFTER"

  # 收尾：备份文件回填（保持临时目录可回收）
  [ -n "$KEEP_NOTES" ] && cp "$KEEP_NOTES" "$T/.agents/notes/README.md"
  [ -n "$KEEP_SKILLS" ] && cp "$KEEP_SKILLS" "$T/.agents/skills/README.md"
fi

# ---- F3-3：无 .meta 的仓 → 保持 init 既有语义（不额外报错）----
T=$(new_case)
run_in "$T" init --repair-skeleton
assert_zero "F3-3 无 .meta 的仓 init --repair-skeleton → exit 0（init 既有语义）" "$R_RC"
assert_exists "F3-3 照常铺骨架（.meta/meta.yaml 生成）" "$T/.meta/meta.yaml"
assert_not_matches "F3-3 NOGO：不得把它当未知参数/报错" "$R_OUT" "未知参数|未知子命令|unsupported|invalid option"
run_in "$T" status
assert_zero "F3-3 铺完后 status exit 0（骨架可用）" "$R_RC"

# ================= CMD：命令面不变量（ADR 2026-08-30-six-command-surface）=================
# 基线 HEAD 实态 = {init, audit, status, upgrade, sync, retire, observe}；本轮不得新增/删除词。
T=$(new_case)
run_in "$T" --help
assert_zero "CMD --help exit 0" "$R_RC"
CMDS=$(printf '%s\n' "$R_OUT" | sed -n 's/^  ponygo \([a-z][a-z-]*\).*/\1/p' | LC_ALL=C sort -u)
EXPECTED=$(printf '%s\n' audit init observe retire status sync upgrade)
assert_eq "CMD 顶层命令词集合与基线实态一致（未新增/未删除）" "$EXPECTED" "$CMDS"
assert_not_contains "CMD NOGO：usage 不得出现 repair 命令词" "$CMDS" "repair"
assert_not_matches "CMD NOGO：usage 不得列出 ponygo repair 行" "$R_OUT" '^  ponygo repair'

run_in "$T" repair
assert_nonzero "CMD ponygo repair 必须被当作未知参数拒绝（非零退出）" "$R_RC"
assert_matches "CMD 拒绝时必须给出提示（未知参数/子命令）" "$R_OUT" '未知参数|未知子命令|未知命令'

finish
