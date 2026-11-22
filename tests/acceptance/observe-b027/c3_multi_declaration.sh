#!/usr/bin/env bash
# ============================================================
# B027③ 同仓多声明验收：`docs/observability.d/*.yaml|yml` 与根声明 `docs/observability.yaml`
# 并存时，每份附加声明必须**各自独立判定**，缺口以 `extra_declaration_inconsistent` 暴露。
#
# 缺陷原文（backlog B027③）：declaration_paths 单目录单声明 + kind 单值，同仓无法同时声明
# k8s-service 与 pipeline 形态。修法：主声明定 ob 级，附加声明只扩覆盖并逐份巡检。
# 冻结判据：①附加声明逐份出现在人读清单；②坏的那份进 extra_declaration_inconsistent；
#           ③主声明的 ob0/ob1/ob2 判定不受附加声明影响（各自独立）；④非 strict 只进 backlog。
# ============================================================
set -u
SPEC_NAME=observe-b027-c3
. "$(dirname "${BASH_SOURCE[0]}")/selfwrap.sh"

. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

STUB=$(new_stub) || { bad "夹具：stub skill 副本创建失败"; finish; }

T=$(new_case)
make_ob_repo "$T" svc-root || finish
write_mount_hook "$T" .githooks/pre-commit || finish
set_hooks_path "$T" .githooks || finish

# ---------- 3a 基线：无 docs/observability.d/ → 零缺口、无附加声明巡检行 ----------
audit_ob2 "$T" "$STUB"
assert_rc_is "3a 基线（无附加声明目录）：exit" 0 "$R_RC"
assert_contains "3a 基线：缺口为空" "$R_OUT" "缺口: 无"
assert_not_contains "3a 基线：不得凭空出现附加声明巡检行" "$R_OUT" "附加声明巡检"

# ---------- 3b 附加声明（pipeline 形态）与实测不一致 → extra_declaration_inconsistent ----------
write_decl "$T" bad-pipeline docs/observability.d/pipeline.yaml || finish
assert_file "3b 夹具：附加声明已落盘" "$T/docs/observability.d/pipeline.yaml"
audit_ob2 "$T" "$STUB"
assert_rc_is "3b 附加声明不一致：非 strict 只进 backlog → exit 0" 0 "$R_RC"
assert_contains "3b 附加声明不一致：缺口 id 为 extra_declaration_inconsistent" "$R_OUT" "extra_declaration_inconsistent"
assert_contains "3b 附加声明不一致：人读逐份列 rc（pipeline.yaml:2）" "$R_OUT" "pipeline.yaml:2"
assert_contains "3b 附加声明不一致：主声明仍判 ob2 PASS（判定独立）" "$R_OUT" "[PASS] ob2"
assert_contains "3b 附加声明不一致：当前级仍为 ob2" "$R_OUT" "当前级: ob2"
assert_not_contains "3b 附加声明不一致：不得报缺口为空" "$R_OUT" "缺口: 无"

# --strict：附加声明的缺口同样不得静默豁免
audit_ob2 "$T" "$STUB" --strict
assert_rc_is "3b --strict：存在附加声明缺口 → exit 1" 1 "$R_RC"
assert_contains "3b --strict：缺口 id 不丢失" "$R_OUT" "extra_declaration_inconsistent"

# ---------- 3c 多份附加声明各判各的（.yaml 与 .yml 两种扩展名都必须纳入） ----------
write_decl "$T" svc-frontend docs/observability.d/frontend.yaml || finish
write_decl "$T" svc-backup docs/observability.d/backup.yml || finish
audit_ob2 "$T" "$STUB"
assert_rc_is "3c 多份附加声明：exit 0（非 strict）" 0 "$R_RC"
assert_contains "3c 多份附加声明：.yml 也被纳入（backup.yml:0）" "$R_OUT" "backup.yml:0"
assert_contains "3c 多份附加声明：逐份判定顺序稳定（LC_ALL=C 排序）" "$R_OUT" "backup.yml:0 frontend.yaml:0 pipeline.yaml:2"
assert_contains "3c 多份附加声明：坏的那份仍进缺口" "$R_OUT" "extra_declaration_inconsistent"
assert_contains "3c 多份附加声明：主声明仍判 ob2 PASS" "$R_OUT" "[PASS] ob2"

# ---------- 3d 全部一致 → 缺口消失（不误报） ----------
write_decl "$T" svc-pipeline docs/observability.d/pipeline.yaml || finish
audit_ob2 "$T" "$STUB"
assert_rc_is "3d 附加声明全一致：exit" 0 "$R_RC"
assert_contains "3d 附加声明全一致：三份都判 0（独立判定，互不牵连）" "$R_OUT" "backup.yml:0 frontend.yaml:0 pipeline.yaml:0"
assert_not_contains "3d 附加声明全一致：不得误报 extra_declaration_inconsistent" "$R_OUT" "extra_declaration_inconsistent"
assert_contains "3d 附加声明全一致：缺口为空" "$R_OUT" "缺口: 无"

# ---------- 3e 作用域负样本：docs/observability.d/ 只取**同一层**声明（不得递归） ----------
mkdir -p "$T/docs/observability.d/nested"
write_decl "$T" bad-deep docs/observability.d/nested/deep.yaml || finish
assert_file "3e 夹具：二级声明已落盘（越界样本）" "$T/docs/observability.d/nested/deep.yaml"
audit_ob2 "$T" "$STUB"
assert_rc_is "3e 二级声明不参与巡检：exit 0" 0 "$R_RC"
assert_not_contains "3e 二级声明不得进人读清单" "$R_OUT" "deep.yaml"
assert_not_contains "3e 二级声明的坏 rc 不得进缺口" "$R_OUT" "extra_declaration_inconsistent"
assert_contains "3e 同层三份仍各自判 0" "$R_OUT" "backup.yml:0 frontend.yaml:0 pipeline.yaml:0"
assert_contains "3e 缺口为空" "$R_OUT" "缺口: 无"

finish
