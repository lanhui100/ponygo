#!/usr/bin/env bash
# GH12：W3b 契约验收（U4：spec 运行时契约 ##SPEC，灰度）
# 契约源：.dev-team/contract-w3b-u4.md §5（T-U4-*）
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SPECS=".meta/gates/adr-verify.spec.sh .meta/gates/archive-verify.spec.sh .meta/gates/no-residue.spec.sh .meta/gates/scratch-hygiene.spec.sh .meta/gates/backlog-gate.spec.sh"
for s in $SPECS; do
  assert_contains "T-U4-1 $s 含 ##SPEC 运行时计数行" "$(cat "$ROOT/$s")" "##SPEC asserts="
done

# 本仓：5 个 spec 都有计数 → 无 legacy 告警，整体仍绿
(cd "$ROOT" && bash ponygo audit --run-specs > /tmp/gh12_self.$$ 2>&1); echo $? > /tmp/gh12_rc.$$
assert_zero "T-U4-2 本仓 audit --run-specs exit 0" "$(cat /tmp/gh12_rc.$$)"
assert_contains "T-U4-2b 仍打「全部自检通过」" "$(cat /tmp/gh12_self.$$)" "全部自检通过"
assert_not_contains "T-U4-2c 5 个 spec 都有计数行 → 无 legacy 告警" "$(cat /tmp/gh12_self.$$)" "legacy spec"
rm -f /tmp/gh12_self.$$ /tmp/gh12_rc.$$

# 夹具 A：rejects=0 → 硬 FAIL（用对照组隔离 ladder 自身退出码）
TA=$(new_case)
make_gov_repo "$TA" 2
cat > "$TA/.meta/gates/fake-zero.sh" <<'G'
#!/usr/bin/env bash
case "${1:-}" in "") exit 0 ;; *) exit 1 ;; esac
G
cat > "$TA/.meta/gates/fake-zero.spec.sh" <<'S'
#!/usr/bin/env bash
if false; then exit 1; fi
printf 'ran fake spec\n'
printf '##SPEC asserts=1 rejects=0\n'
exit 0
S
chmod +x "$TA/.meta/gates/fake-zero.sh" "$TA/.meta/gates/fake-zero.spec.sh"
TA0=$(new_case); make_gov_repo "$TA0" 2
(cd "$TA0" && bash ponygo audit --run-specs > /tmp/gh12_ctl.$$ 2>&1); echo $? > /tmp/gh12_ctlrc.$$
(cd "$TA" && bash ponygo audit --run-specs > /tmp/gh12_a.$$ 2>&1); echo $? > /tmp/gh12_arc.$$
assert_nonzero "T-U4-3 自报 rejects=0 的 spec → audit --run-specs 非零" "$(cat /tmp/gh12_arc.$$)"
assert_not_contains "T-U4-3a 对照组（无该 spec）不出现 rejects=0 判词" "$(cat /tmp/gh12_ctl.$$)" "rejects=0"
assert_contains "T-U4-3b 文案点名 rejects=0 且点名该 spec" "$(cat /tmp/gh12_a.$$)" "fake-zero.spec.sh 自报 rejects=0"
assert_contains "T-U4-3c 判为 [bad]（不是 legacy WARN）" "$(cat /tmp/gh12_a.$$)" "[bad]"
rm -f /tmp/gh12_a.$$ /tmp/gh12_arc.$$ /tmp/gh12_ctl.$$ /tmp/gh12_ctlrc.$$

# 夹具 B：legacy spec（无 ##SPEC）→ 本轮 WARN、退出码与对照组一致
TB=$(new_case)
make_gov_repo "$TB" 2
cat > "$TB/.meta/gates/fake-legacy.sh" <<'G'
#!/usr/bin/env bash
case "${1:-}" in "") exit 0 ;; *) exit 1 ;; esac
G
cat > "$TB/.meta/gates/fake-legacy.spec.sh" <<'S'
#!/usr/bin/env bash
if bash "$(dirname "$0")/fake-legacy.sh" --bad >/dev/null 2>&1; then
  printf 'FAIL: fake-legacy 未拒绝非法样本\n' >&2
  exit 1
fi
printf 'legacy spec ran\n'
exit 0
S
chmod +x "$TB/.meta/gates/fake-legacy.sh" "$TB/.meta/gates/fake-legacy.spec.sh"
TB0=$(new_case); make_gov_repo "$TB0" 2
(cd "$TB0" && bash ponygo audit --run-specs >/dev/null 2>&1); RB0=$?
(cd "$TB" && bash ponygo audit --run-specs > /tmp/gh12_b.$$ 2>&1); RB1=$?
assert_eq "T-U4-4 legacy spec 不改变退出码（与对照组一致）" "$RB0" "$RB1"
assert_contains "T-U4-4b 逐 spec 打出 legacy 告警并点名该 spec" "$(cat /tmp/gh12_b.$$)" "fake-legacy.spec.sh 未提供 ##SPEC"
assert_contains "T-U4-4c 告警写明 v3 起转硬" "$(cat /tmp/gh12_b.$$)" "v3"
assert_not_contains "T-U4-4d legacy spec 不得被判 [bad]" "$(cat /tmp/gh12_b.$$)" "fake-legacy.spec.sh 自报"
rm -f /tmp/gh12_b.$$

assert_contains "T-U4-5 gates/README 写明 ##SPEC 契约" "$(cat "$ROOT/.meta/gates/README.md")" "##SPEC"
assert_contains "T-U4-5b maturity-ladder 写明灰度到 v3" "$(cat "$ROOT/maturity-ladder.md")" "v3"

finish
