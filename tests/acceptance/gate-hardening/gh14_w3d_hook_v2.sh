#!/usr/bin/env bash
# GH14：W3d 契约验收（B020：A3 钩子 v2 fail-closed + v1 双接受灰度）
# 契约源：.dev-team/contract-w3d-b020.md §3（T-B020-1..5）
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

HOOK_REL=".githooks/pre-commit"
A1_REL=".meta/gates/adr-verify.sh"

V1_BLOCK='# >>> ponygo-gate: adr-verify v1 >>>
if [ -f "$(git rev-parse --show-toplevel)/.meta/gates/adr-verify.sh" ]; then
  bash "$(git rev-parse --show-toplevel)/.meta/gates/adr-verify.sh" || exit 1
fi
# <<< ponygo-gate: adr-verify v1 <<<'

# T-B020-1：新钩子 = v2 fail-closed
T=$(new_case)
make_gov_repo "$T" 1
HOOK="$T/$HOOK_REL"
assert_file "T-B020-1 前置：init 生成 pre-commit" "$HOOK"
assert_contains "T-B020-1 钩子含 v2 哨兵" "$(cat "$HOOK")" "# >>> ponygo-gate: adr-verify v2 >>>"
assert_contains "T-B020-1b 钩子含 v2 marker 行" "$(cat "$HOOK")" "# ponygo-gate: adr-verify v2"
assert_contains "T-B020-1c 钩子含 fail-closed 分支文案" "$(cat "$HOOK")" "fail-closed"
assert_contains "T-B020-1d 缺失时提示跑 ponygo init" "$(cat "$HOOK")" "ponygo init 补回"

# T-B020-2：删 A1 后提交被拒
rm -f "$T/$A1_REL"
mkdir -p "$T/.agents/notes/proposed/process"
printf '# 坏 ADR\n\nStatus: proposed\n' > "$T/.agents/notes/proposed/process/2026-01-02-bad.md"
(cd "$T" && git add -A >/dev/null 2>&1 && git -c user.name=gh14 -c user.email=gh14@example.invalid commit -q -m bad > /tmp/gh14_c.$$ 2>&1); CRC=$?
assert_nonzero "T-B020-2 删 A1 后 git commit 被拒" "$CRC"
assert_contains "T-B020-2b 拒绝文案含 fail-closed" "$(cat /tmp/gh14_c.$$)" "fail-closed"
assert_contains "T-B020-2c 拒绝文案给出修法（ponygo init）" "$(cat /tmp/gh14_c.$$)" "ponygo init"
rm -f /tmp/gh14_c.$$

# T-B020-3：v1 钩子 → 2.4 PASS + WARN
T2=$(new_case)
make_gov_repo "$T2" 2   # 2.4 属 L2 判据：夹具必须 lv=2，否则 status 不判 2.4
printf '#!/usr/bin/env bash\n' > "$T2/$HOOK_REL"
printf '%s\n' "$V1_BLOCK" >> "$T2/$HOOK_REL"
chmod +x "$T2/$HOOK_REL"
run_cli "$T2" status
assert_zero "T-B020-3 v1 钩子实例 status exit 0（灰度期不判死）" "$R_RC"
assert_contains "T-B020-3b v1 钩子只给 WARN 且建议升级" "$R_OUT" "WARN pre-commit 哨兵块为 v1"

# T-B020-4：init 把 v1 升级为 v2，既有用户行不动
T3=$(new_case)
make_gov_repo "$T3" 1
printf '#!/usr/bin/env bash\nUSER-KEEP-ME\n' > "$T3/$HOOK_REL"
printf '%s\n' "$V1_BLOCK" >> "$T3/$HOOK_REL"
chmod +x "$T3/$HOOK_REL"
run_cli "$T3" init
assert_zero "T-B020-4 对 v1 钩子重跑 init exit 0" "$R_RC"
assert_contains "T-B020-4b 块已升级 v2" "$(cat "$T3/$HOOK_REL")" "# >>> ponygo-gate: adr-verify v2 >>>"
assert_not_contains "T-B020-4c 旧 v1 哨兵已移除" "$(cat "$T3/$HOOK_REL")" "adr-verify v1 >>>"
assert_contains "T-B020-4d 钩子里的用户行保留" "$(cat "$T3/$HOOK_REL")" "USER-KEEP-ME"

# T-B020-5：注释掉调用行 → 2.4 FAIL（既有拒绝能力不回退）
T4=$(new_case)
make_gov_repo "$T4" 2   # 同上：2.4 只在 lv≥2 判
sed -i.bak 's|^  bash "\$(git rev-parse --show-toplevel)/.meta/gates/adr-verify.sh" || exit 1|  # DISABLED|' "$T4/$HOOK_REL" 2>/dev/null
python3 - "$T4/$HOOK_REL" <<'PY'
import sys
p=sys.argv[1]
s=open(p,encoding='utf-8').read()
s=s.replace('  bash "$(git rev-parse --show-toplevel)/.meta/gates/adr-verify.sh" || exit 1','  # DISABLED')
open(p,'w',encoding='utf-8').write(s)
PY
rm -f "$T4/$HOOK_REL.bak"
run_cli "$T4" status
assert_nonzero "T-B020-5 调用行被注释 → status 2.4 FAIL" "$R_RC"

finish
