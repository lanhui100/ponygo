#!/usr/bin/env bash
# F6：输出文案/语义四连（P2-7 / P2-9 / P2-8 / P2-12），按冻结契约矩阵 §7 逐格断言。
#   F6a  below_target 只在显式 --level 时出现（文本 + --json 两个面）；无 --level 时不得出现
#         「当前级低于 --level 断言的目标级」话术。
#   F6b  零缺口不打印空「缺口与最小改进动作」标题；有缺口时标题与条目仍须在（正反两面）。
#   F6c  沉睡钩子 + init --dry-run：必须打印「存在但不可执行 — 不动权限（需人 chmod +x）」，
#         不得承诺「创建 .githooks/pre-commit」；dry-run 零落盘（含权限与 core.hooksPath）。
#   F6d  悬空引用 URL 化：checklists/audit.md 与 maturity-ladder.md 的每次出现都必须落在
#         框架仓 URL token 内；「已认可替代物」诚实条款不得被删。
# 冻结契约来源：.dev-team/contract-matrix-auditfix.md §7（F6a-1/2、F6b-1、F6c-1/2/3、F6d-1/2/3/4）。
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# ================= F6a：below_target 的出现条件 =================
T=$(new_case)
SK=$(stage_skill "$T")
make_observe_case "$T" 3            # level 3 → 目标级 ob2；stub rc=2 → 当前级 ob0
run_in "$T" STUB_RC_CHECK_DECL=2 observe audit --skill-dir "$SK"
assert_contains "F6a 夹具：体检模式确实产出缺口列表（含 declaration_inconsistent）" "$R_OUT" "declaration_inconsistent"
assert_not_contains "F6a-1 NOGO：无 --level 的体检 gaps 不得含 below_target" "$R_OUT" "below_target"
assert_not_contains "F6a-2 NOGO：无 --level 时不得出现「当前级低于 --level 断言的目标级」话术" \
  "$R_OUT" "当前级低于 --level 断言的目标级"

run_in "$T" STUB_RC_CHECK_DECL=2 observe audit --skill-dir "$SK" --level ob2
assert_contains "F6a-1 GO：显式 --level ob2 时 gaps 必须含 below_target（文本面）" "$R_OUT" "below_target"

run_in "$T" STUB_RC_CHECK_DECL=2 observe audit --skill-dir "$SK" --json
JSON_NOLVL=$(printf '%s\n' "$R_OUT" | grep '^{.*"schema":"ponygo.observe/1"' | tail -n1)
assert_matches "F6a 夹具：--json 输出可解析（stdout 单行 JSON）" "$JSON_NOLVL" '"schema":"ponygo.observe/1"'
assert_not_contains "F6a-1 NOGO：无 --level 的 --json gaps 不得含 below_target" "$JSON_NOLVL" "below_target"

run_in "$T" STUB_RC_CHECK_DECL=2 observe audit --skill-dir "$SK" --level ob2 --json
JSON_LVL=$(printf '%s\n' "$R_OUT" | grep '^{.*"schema":"ponygo.observe/1"' | tail -n1)
assert_contains "F6a-1 GO：显式 --level ob2 的 --json gaps 含 below_target" "$JSON_LVL" "below_target"

# ================= F6b：零缺口不打印空缺口标题 =================
T=$(new_case)
if gov_repo "$T" 1; then
  run_in "$T" audit
  assert_zero "F6b 夹具：零缺口仓 audit exit 0" "$R_RC"
  assert_not_contains "F6b-1 NOGO：零缺口时不得出现「缺口与最小改进动作」标题" "$R_OUT" "缺口与最小改进动作"
fi

# 正向对照：有缺口时标题与条目必须仍在（防「一律不打印」的假修法）
T=$(new_case)
if gov_repo "$T" 1; then
  rm -f "$T/.agents/notes/implemented/architecture/2026-01-01-fixture-adr.md"
  run_in "$T" audit
  assert_contains "F6b-1 GO：有缺口时仍打印标题" "$R_OUT" "缺口与最小改进动作（按杠杆排序，优先「强制层」）："
  assert_matches "F6b-1 GO：标题下至少有一条「  - 」条目" "$R_OUT" '^  - '
fi

# ================= F6c：沉睡钩子 + init --dry-run =================
T=$(new_case)
if gov_repo "$T" 1; then
  ( cd "$T" && git config --unset core.hooksPath ) >/dev/null 2>&1 || :
  HP_BEFORE=$( cd "$T" && git config core.hooksPath 2>/dev/null || true )
  assert_eq "F6c 夹具：core.hooksPath 已清空（干跑将走「未设 hooksPath」分支）" "" "$HP_BEFORE"
  assert_exists "F6c 夹具：.githooks/pre-commit 存在" "$T/.githooks/pre-commit"
  chmod 644 "$T/.githooks/pre-commit"
  [ -x "$T/.githooks/pre-commit" ] && bad "F6c 夹具：pre-commit 仍可执行（chmod 0644 失败）" \
    || ok "F6c 夹具：pre-commit 已不可执行（沉睡钩子）"

  SNAP0=$(snap "$T")
  run_in "$T" init --dry-run
  RC_DRY=$R_RC
  assert_zero "F6c init --dry-run exit 0" "$RC_DRY"
  assert_contains "F6c-1 GO：dry-run 说明钩子「存在但不可执行」" "$R_OUT" "存在但不可执行"
  assert_contains "F6c-1 GO：dry-run 说明「不动权限」" "$R_OUT" "不动权限"
  assert_contains "F6c-1 GO：dry-run 给出人工补救 chmod +x（允许；禁止的是框架承诺自己 chmod）" "$R_OUT" "chmod +x"
  assert_not_contains "F6c-1 NOGO：dry-run 不得再承诺「创建 .githooks/pre-commit」（该文件已存在）" \
    "$R_OUT" "创建 .githooks/pre-commit（A3"
  assert_not_matches "F6c-1 NOGO：dry-run 不得承诺由框架执行 chmod +x" "$R_OUT" "将.*chmod \+x"
  assert_same_tree "F6c-2 dry-run 零落盘（文件树不变）" "$T" "$SNAP0"
  [ -x "$T/.githooks/pre-commit" ] && bad "F6c-2 dry-run 改变了文件权限（应仍不可执行）" \
    || ok "F6c-2 dry-run 不动权限（pre-commit 仍不可执行）"
  HP_AFTER=$( cd "$T" && git config core.hooksPath 2>/dev/null || true )
  assert_eq "F6c-2 dry-run 不动 core.hooksPath" "" "$HP_AFTER"

  # F6c-3：实跑同样不改权限，且与 dry-run 不矛盾（OPEN-3：同码）
  run_in "$T" init
  assert_eq "F6c-3 OPEN-3 init --dry-run 与实跑同码" "$RC_DRY" "$R_RC"
  assert_matches "F6c-3 GO：实跑同样声明沉睡钩子/不改权限" "$R_OUT" "沉睡钩子|不改权限"
  [ -x "$T/.githooks/pre-commit" ] && bad "F6c-3 实跑改变了钩子权限（框架不得替人 chmod）" \
    || ok "F6c-3 实跑未改钩子权限（沉睡钩子仍是人的决定）"
fi

# ================= F6d：悬空文档引用 URL 化 =================
T=$(new_case)
if gov_repo "$T" 1; then
  run_in "$T" audit
  AUDIT_OUT="$R_OUT"
  run_in "$T" status
  STATUS_OUT="$R_OUT"
  ALL_OUT=$(printf '%s\n%s\n' "$AUDIT_OUT" "$STATUS_OUT")

  # 机读判定（契约 §10 N19）：每个出现都必须落在框架仓 URL token 内
  BARE=$(printf '%s\n' "$ALL_OUT" \
    | grep -oE '[^[:space:]]*(checklists/audit\.md|maturity-ladder\.md)' \
    | grep -vE '^<?https://github\.com/' || true)
  if [ -z "$BARE" ]; then
    ok "F6d-1/2 GO：checklists/audit.md 与 maturity-ladder.md 的出现均落在框架仓 URL 内"
  else
    bad "F6d-1/2 NOGO：出现未 URL 化的实例侧路径 token：$(printf '%s' "$BARE" | head -n1)"
  fi
  assert_not_contains "F6d-2 NOGO：不得出现字面量「maturity-ladder.md（仓库根）」" "$ALL_OUT" "maturity-ladder.md（仓库根）"
  assert_contains "F6d-3 GO：诚实条款「已认可替代物」保留（修正不得删条款）" "$AUDIT_OUT" "已认可替代物"
fi

finish
