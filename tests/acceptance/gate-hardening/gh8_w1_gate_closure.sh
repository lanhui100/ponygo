#!/usr/bin/env bash
# GH8：W1 契约验收（U1 实例 CI 补判据面 / U2 A6 缺失 fail-closed）
# 契约源：.dev-team/contract-w1-u1-u2.md §4（T-U1-* / T-U2-*）
# 纪律：黑盒断言（CLI 公开行为 + 生成物文本 + 退出码），纯 bash + lib.sh；折叠进 s90，不新增 run.sh 场景。
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

A5_REL=".github/workflows/ponygo-governance.yml"
A1_REL=".meta/gates/adr-verify.sh"
A2_REL=".meta/gates/adr-verify.spec.sh"
A6_REL=".meta/gates/archive-verify.sh"
GATES_DOC="$ROOT/.meta/gates/README.md"
LADDER="$ROOT/maturity-ladder.md"

# ============================================================
# U1：A5 模板加判据面步骤（只影响新生成物，不回改已存在 workflow）
# ============================================================
T=$(new_case)
mkdir -p "$T/.github/workflows"
make_gov_repo "$T" 1
assert_file "T-U1-1 前置：init 生成 A5（.github 在场 → github 适配器）" "$T/$A5_REL"
A5_TEXT=$(cat "$T/$A5_REL" 2>/dev/null)
assert_contains "T-U1-1 A5 含判据面步骤名" "$A5_TEXT" "ponygo 判据面（status）"
assert_contains "T-U1-1b 判据面步骤真调 CLI status" "$A5_TEXT" 'bash "$CLI" status'
assert_contains "T-U1-2 A5 仍是薄壳：仍跑 A4" "$A5_TEXT" "bash .meta/gates/ci-verify.sh"
assert_contains "T-U1-2b A5 保留超时门" "$A5_TEXT" "timeout-minutes: 10"
assert_contains "T-U1-3 支持 PONYGO_BIN 定位 CLI" "$A5_TEXT" "PONYGO_BIN"
assert_contains "T-U1-3b 无 CLI 时如实 WARN（不静默放行）" "$A5_TEXT" "::warning::"
assert_contains "T-U1-3c WARN 文案声明「这不是通过」" "$A5_TEXT" "这不是通过"

# A4 看不到判据面（U1 的存在理由）：篡改一个门资产 → ci-verify 仍 0 而 status 红
T2=$(new_case)
make_gov_repo "$T2" 1
printf '\n# tampered by gh8\n' >> "$T2/.meta/gates/ci-verify.sh"
(cd "$T2" && bash .meta/gates/ci-verify.sh >/dev/null 2>&1); echo $? > "$T2/.civ_rc"
CIV_RC=$(cat "$T2/.civ_rc")
run_cli "$T2" status
assert_zero "T-U1-4 篡改门资产后 A4（ci-verify）仍 exit 0（A4 不含资产字节比对）" "$CIV_RC"
assert_nonzero "T-U1-4b 同一棵树 status 判 2.1 红（判据面只能由 CLI 看见）" "$R_RC"

# 文档口径：不再声称「CI 侧实际有看守」
assert_not_contains "T-U1-5 maturity-ladder 不再声称「故 CI 侧实际有看守」" "$(cat "$LADDER")" "故 CI 侧实际有看守"
assert_contains "T-U1-5b maturity-ladder 写明未携带 CLI 时的诚实口径" "$(cat "$LADDER")" "未携带"

# ============================================================
# U2：A6 缺失 → A1 fail-closed
# ============================================================
T3=$(new_case)
make_gov_repo "$T3" 1
(cd "$T3" && bash .meta/gates/adr-verify.sh >/dev/null 2>&1); echo $? > "$T3/.rc0"
assert_zero "T-U2-1 正控制：A6 在场且无暂存 ADR → adr-verify exit 0" "$(cat "$T3/.rc0")"

rm -f "$T3/$A6_REL"
run_cli "$T3" "" >/dev/null 2>&1 || true
(cd "$T3" && bash .meta/gates/adr-verify.sh > "$T3/.out" 2>&1); echo $? > "$T3/.rc1"
A1_RC=$(cat "$T3/.rc1")
A1_OUT=$(cat "$T3/.out" 2>/dev/null)
assert_nonzero "T-U2-2 删 A6 后无暂存 ADR 也必须非零（不得因无暂存 ADR 跳过）" "$A1_RC"
assert_contains "T-U2-3 拒绝文案点名 A6" "$A1_OUT" "A6"
assert_contains "T-U2-3b 拒绝文案声明 fail-closed" "$A1_OUT" "fail-closed"

# 删 A6 + 暂存一条改动 ADR → 仍必须非零
T4=$(new_case)
make_gov_repo "$T4" 1
printf '\n<!-- staged edit by gh8 -->\n' >> "$T4/.agents/notes/implemented/architecture/2026-01-01-fixture.md"
(cd "$T4" && git add .agents/notes/implemented/architecture/2026-01-01-fixture.md >/dev/null 2>&1)
rm -f "$T4/$A6_REL"
(cd "$T4" && bash .meta/gates/adr-verify.sh >/dev/null 2>&1); echo $? > "$T4/.rc2"
assert_nonzero "T-U2-4 删 A6 + 暂存改动 ADR → 非零（封印不可判定即拒绝）" "$(cat "$T4/.rc2")"

# A2 负样本自检必须覆盖新分支
(cd "$ROOT" && bash "$A2_REL" >/dev/null 2>&1); echo $? > /tmp/gh8_a2.$$
assert_zero "T-U2-5 A2 负样本自检 exit 0（新增 A6 缺失用例后仍自洽）" "$(cat /tmp/gh8_a2.$$)"
rm -f /tmp/gh8_a2.$$
assert_contains "T-U2-5b A2 spec 文本已含 A6 缺失负样本用例" "$(cat "$ROOT/$A2_REL")" "A6 缺失"

# 文档：A1 行/A6 时序不再写「优雅回退」
assert_not_contains "T-U2-6 gates/README 不再写「门缺失时优雅回退」" "$(cat "$GATES_DOC")" "门缺失时优雅回退"
assert_contains "T-U2-6b gates/README 的 A1 行写明 A6 缺失 fail-closed" "$(cat "$GATES_DOC")" "A6 缺失"

finish
