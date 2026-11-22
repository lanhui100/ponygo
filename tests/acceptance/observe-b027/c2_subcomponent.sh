#!/usr/bin/env bash
# ============================================================
# B027② 子组件声明验收：一级子目录（front_end/ web/ client/ ui/ app/ frontend/）下的声明
# 必须被 `ponygo observe audit` **逐份**巡检，缺口以 `subcomponent_*` id 暴露。
#
# 缺陷原文（backlog B027②）：observe status 推荐「进入 front_end/ 执行 ponygo observe init」，
# 而 observe_audit 只判根声明，从不遍历一级子目录 → 用户照提示建了子组件声明却拿不到任何门禁反馈。
# 冻结判据：①混合 rc（根声明 0 / 子声明 2）同时出现 → 证明逐份；②缺口 id 为 subcomponent_*；
#           ③子声明一致时缺口消失（不误报）；④非 strict 只进 backlog（exit 0），--strict 才动退出码。
# ============================================================
set -u
SPEC_NAME=observe-b027-c2
. "$(dirname "${BASH_SOURCE[0]}")/selfwrap.sh"

. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

STUB=$(new_stub) || { bad "夹具：stub skill 副本创建失败"; finish; }

T=$(new_case)
make_ob_repo "$T" svc-root || finish
write_mount_hook "$T" .githooks/pre-commit || finish
set_hooks_path "$T" .githooks || finish

# ---------- 2a 基线：无子组件声明 → 零缺口、无子组件巡检行 ----------
audit_ob2 "$T" "$STUB"
assert_rc_is "2a 基线（无子组件声明）：exit" 0 "$R_RC"
assert_contains "2a 基线：缺口为空" "$R_OUT" "缺口: 无"
assert_not_contains "2a 基线：不得凭空出现子组件巡检行" "$R_OUT" "子组件声明巡检"

# ---------- 2b 子组件声明与实测不一致 → subcomponent_inconsistent ----------
write_decl "$T" bad-frontend front_end/docs/observability.yaml || finish
assert_file "2b 夹具：子组件声明已落盘" "$T/front_end/docs/observability.yaml"
audit_ob2 "$T" "$STUB"
assert_rc_is "2b 子组件不一致：非 strict 只进 backlog → exit 0" 0 "$R_RC"
assert_contains "2b 子组件不一致：缺口 id 为 subcomponent_inconsistent" "$R_OUT" "subcomponent_inconsistent"
assert_contains "2b 子组件不一致：人读逐份列 rc（front_end:2）" "$R_OUT" "front_end:2"
assert_contains "2b 子组件不一致：根声明仍判 ob2 PASS（判定独立）" "$R_OUT" "[PASS] ob2"
assert_not_contains "2b 子组件不一致：不得报缺口为空" "$R_OUT" "缺口: 无"

# --strict：任一缺口即非零退出（缺口不是静默豁免）
audit_ob2 "$T" "$STUB" --strict
assert_rc_is "2b --strict：存在子组件缺口 → exit 1" 1 "$R_RC"
assert_contains "2b --strict：缺口 id 不丢失" "$R_OUT" "subcomponent_inconsistent"

# ---------- 2c 子组件声明一致 → 不误报 ----------
write_decl "$T" svc-frontend front_end/docs/observability.yaml || finish
audit_ob2 "$T" "$STUB"
assert_rc_is "2c 子组件一致：exit" 0 "$R_RC"
assert_contains "2c 子组件一致：人读列 rc=0" "$R_OUT" "front_end:0"
assert_not_contains "2c 子组件一致：不得误报 subcomponent_inconsistent" "$R_OUT" "subcomponent_inconsistent"
assert_not_contains "2c 子组件一致：不得误报证据不足" "$R_OUT" "subcomponent_evidence_insufficient"
assert_contains "2c 子组件一致：缺口为空" "$R_OUT" "缺口: 无"

# ---------- 2d 逐份：两个一级子目录，一份 0 一份 2 → 两份都必须出现在 rc 清单 ----------
write_decl "$T" bad-web web/docs/observability.yaml || finish
audit_ob2 "$T" "$STUB"
assert_rc_is "2d 逐份巡检：exit 0（非 strict）" 0 "$R_RC"
assert_contains "2d 逐份巡检：front_end 判 0（逐份，不被 web 的 2 覆盖）" "$R_OUT" "front_end:0"
assert_contains "2d 逐份巡检：web 判 2" "$R_OUT" "web:2"
assert_contains "2d 逐份巡检：缺口 id 为 subcomponent_inconsistent" "$R_OUT" "subcomponent_inconsistent"

# ---------- 2e 证据不可得分支独立：子声明 rc=3 → subcomponent_evidence_insufficient ----------
write_decl "$T" unk-web web/docs/observability.yaml || finish
audit_ob2 "$T" "$STUB"
assert_rc_is "2e 证据不可得：非 strict exit 0" 0 "$R_RC"
assert_contains "2e 证据不可得：rc 清单含 web:3" "$R_OUT" "web:3"
assert_contains "2e 证据不可得：缺口 id 为 subcomponent_evidence_insufficient" "$R_OUT" "subcomponent_evidence_insufficient"
assert_not_contains "2e 证据不可得：不得误报 inconsistent" "$R_OUT" "subcomponent_inconsistent"

# ---------- 2f 作用域负样本：只巡检**一级**子组件，不得越界扫二级 ----------
# 判据是「一级子目录的 docs/observability.*」，故 front_end/web/docs/... 这类二级声明不参与，
# 也不得凭空产生缺口（否则「逐份」会退化成「无限递归」——作用域失控同样是缺陷）。
rm -rf "$T/web"
write_decl "$T" svc-frontend front_end/docs/observability.yaml || finish
write_decl "$T" bad-nested front_end/web/docs/observability.yaml || finish
assert_file "2f 夹具：二级声明已落盘（越界样本）" "$T/front_end/web/docs/observability.yaml"
audit_ob2 "$T" "$STUB"
assert_rc_is "2f 二级声明不参与巡检：exit 0" 0 "$R_RC"
assert_contains "2f 一级声明照常判 0" "$R_OUT" "front_end:0"
assert_not_contains "2f 二级声明不得被计成子组件条目" "$R_OUT" "front_end/web"
assert_not_contains "2f 二级声明的坏 rc 不得进缺口" "$R_OUT" "subcomponent_inconsistent"
assert_contains "2f 缺口为空" "$R_OUT" "缺口: 无"

finish
