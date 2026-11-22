#!/usr/bin/env bash
# ============================================================
# B027① 载体形态验收：`.githooks/` 与 `.husky/`（含 husky v9 的 core.hooksPath=.husky/_ 形态）
# 各一例 —— 门禁真挂在载体上时 ob2 **可得分**；载体上没有真调用时 ob2 必须掉到 mount_missing。
#
# 缺陷原文（backlog B027①）：ponygo 的 mount_carriers 是静态清单，不含 .husky/；
# 消费仓 L1/L2 门禁全在 .husky/ 下 → 「本地门禁已接 audit-diff」也拿不到 ob2 分。
# 冻结判据：①可得分（exit 0 + `[PASS] ob2` + `缺口: 无`）；②得分归因（移除真调用 → mount_missing）。
# ============================================================
set -u
SPEC_NAME=observe-b027-c1
. "$(dirname "${BASH_SOURCE[0]}")/selfwrap.sh"

. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

STUB=$(new_stub) || { bad "夹具：stub skill 副本创建失败"; finish; }

# 夹具自检（证明 stub 不是「所有入参都返回 0」的纯常量桩）：项目目录不存在 → exit 4
SC_OUT=$(bash "$STUB/scripts/check-declaration.sh" --project "$SBASE/根本没有这个目录" 2>&1)
SC_RC=$?
assert_rc_is "夹具自检：stub check-declaration 入参校验（目录不存在）→ exit 4" 4 "$SC_RC"
assert_contains "夹具自检：stub 打印可识别标记" "$SC_OUT" "STUB-CHECK-DECL rc=4"
AD_OUT=$(bash "$STUB/scripts/audit-diff.sh" --repo "$SBASE/根本没有这个目录" 2>&1)
AD_RC=$?
assert_rc_is "夹具自检：stub audit-diff 入参校验（目录不存在）→ exit 4" 4 "$AD_RC"
assert_contains "夹具自检：stub audit-diff 打印可识别标记" "$AD_OUT" "STUB-AUDIT-DIFF rc=4"

# ---------- 1a：.githooks/（静态 mount_carriers 之一）----------
T=$(new_case)
make_ob_repo "$T" svc-githooks || finish
write_mount_hook "$T" .githooks/pre-commit || finish
set_hooks_path "$T" .githooks || finish
assert_eq "1a 夹具：core.hooksPath=.githooks" ".githooks" "$(cd "$T" && git config core.hooksPath)"

audit_ob2 "$T" "$STUB"
assert_rc_is "1a .githooks 载体：ob2 断言 exit" 0 "$R_RC"
assert_contains "1a .githooks 载体：ob2 判 PASS" "$R_OUT" "[PASS] ob2"
assert_contains "1a .githooks 载体：当前级 ob2" "$R_OUT" "当前级: ob2"
assert_contains "1a .githooks 载体：缺口为空" "$R_OUT" "缺口: 无"

# 归因对照：同一仓、同一 hooksPath，把真调用换成无 audit-diff 的钩子 → 必须 mount_missing
write_stub_hook "$T" .githooks/pre-commit
audit_ob2 "$T" "$STUB"
assert_rc_is "1a 归因对照：钩子无 audit-diff → exit 1" 1 "$R_RC"
assert_contains "1a 归因对照：缺口点名 mount_missing" "$R_OUT" "mount_missing"
assert_contains "1a 归因对照：ob2 判 FAIL" "$R_OUT" "[FAIL] ob2"
assert_not_contains "1a 归因对照：不得仍报 ob2 PASS" "$R_OUT" "[PASS] ob2"

# ---------- 1b：.husky/（core.hooksPath=.husky；缺陷原文的核心形态）----------
H=$(new_case)
make_ob_repo "$H" svc-husky || finish
write_mount_hook "$H" .husky/pre-commit || finish
set_hooks_path "$H" .husky || finish
assert_eq "1b 夹具：core.hooksPath=.husky" ".husky" "$(cd "$H" && git config core.hooksPath)"

audit_ob2 "$H" "$STUB"
assert_rc_is "1b .husky 载体：ob2 断言 exit" 0 "$R_RC"
assert_contains "1b .husky 载体：ob2 判 PASS（B027①：husky 载体可得分）" "$R_OUT" "[PASS] ob2"
assert_contains "1b .husky 载体：当前级 ob2" "$R_OUT" "当前级: ob2"
assert_contains "1b .husky 载体：缺口为空" "$R_OUT" "缺口: 无"

write_stub_hook "$H" .husky/pre-commit
audit_ob2 "$H" "$STUB"
assert_rc_is "1b 归因对照：husky 钩子无 audit-diff → exit 1" 1 "$R_RC"
assert_contains "1b 归因对照：缺口点名 mount_missing" "$R_OUT" "mount_missing"
assert_not_contains "1b 归因对照：不得仍报 ob2 PASS" "$R_OUT" "[PASS] ob2"

# ---------- 1c：husky v9 形态（core.hooksPath=.husky/_，钩子本体在 .husky/）----------
# husky v9 把 core.hooksPath 写成 .husky/_；git 实际执行 .husky/_/<hook> 的 shim，
# shim 再转调 .husky/<hook> 本体。载体判定必须在 hp 与 .husky/ 两侧都成立。
V=$(new_case)
make_ob_repo "$V" svc-husky-v9 || finish
mkdir -p "$V/.husky/_"
printf '#!/usr/bin/env bash\n. "$(dirname "$0")/h"\n' > "$V/.husky/_/pre-push"
chmod +x "$V/.husky/_/pre-push" 2>/dev/null || :
write_mount_hook "$V" .husky/pre-push || finish
set_hooks_path "$V" .husky/_ || finish
assert_eq "1c 夹具：core.hooksPath=.husky/_" ".husky/_" "$(cd "$V" && git config core.hooksPath)"
assert_file "1c 夹具：husky v9 shim 在场" "$V/.husky/_/pre-push"
assert_file "1c 夹具：用户钩子本体在场" "$V/.husky/pre-push"

audit_ob2 "$V" "$STUB"
assert_rc_is "1c husky v9：ob2 断言 exit" 0 "$R_RC"
assert_contains "1c husky v9：ob2 判 PASS（hp=.husky/_ 形态可得分）" "$R_OUT" "[PASS] ob2"
assert_contains "1c husky v9：缺口为空" "$R_OUT" "缺口: 无"

write_stub_hook "$V" .husky/pre-push
audit_ob2 "$V" "$STUB"
assert_rc_is "1c 归因对照：用户钩子本体无 audit-diff → exit 1" 1 "$R_RC"
assert_contains "1c 归因对照：缺口点名 mount_missing" "$R_OUT" "mount_missing"
assert_not_contains "1c 归因对照：不得仍报 ob2 PASS" "$R_OUT" "[PASS] ob2"

# ---------- 1d：hp 本身就是钩子目录（core.hooksPath 指向自建目录）----------
# 覆盖「core.hooksPath 指向的目录是唯一权威」这条判据：不依赖 .husky/.githooks 命名。
P=$(new_case)
make_ob_repo "$P" svc-custom || finish
write_mount_hook "$P" .hooks-custom/pre-commit || finish
set_hooks_path "$P" .hooks-custom || finish
audit_ob2 "$P" "$STUB"
assert_rc_is "1d core.hooksPath 自建目录：ob2 断言 exit" 0 "$R_RC"
assert_contains "1d core.hooksPath 自建目录：ob2 判 PASS" "$R_OUT" "[PASS] ob2"

# 归因对照（负样本）：同一自建目录换成无 audit-diff 的钩子 → 必须 mount_missing
write_stub_hook "$P" .hooks-custom/pre-commit
audit_ob2 "$P" "$STUB"
assert_rc_is "1d 归因对照：载体无 audit-diff → exit 1" 1 "$R_RC"
assert_contains "1d 归因对照：缺口点名 mount_missing" "$R_OUT" "mount_missing"
assert_not_contains "1d 归因对照：不得仍报 ob2 PASS" "$R_OUT" "[PASS] ob2"

finish
