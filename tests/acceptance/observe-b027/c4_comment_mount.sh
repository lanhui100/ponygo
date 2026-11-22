#!/usr/bin/env bash
# ============================================================
# B027④ 注释伪装挂载验收：载体里只把 `audit-diff` 写在**注释**里（形如
# `# bash scripts/audit-diff.sh`）必须判负 —— 不得作为 mount 命中、不得给 ob2 分。
#
# 缺陷原文（backlog B027④）：ob2 的 mount 判据曾是纯文本 `grep -F 'audit-diff'`，
# 注释写一行即可满足（假绿）。修法：判据改为「存在**非注释行**引用」。
# 冻结判据：①三种载体形态（shell 钩子 / husky 钩子 / yaml workflow）的纯注释伪装均判负
#           （缺口 mount_missing 且 ob2 不得 PASS）；②同一文件去掉注释符即恢复得分（归因对照）。
# ============================================================
set -u
SPEC_NAME=observe-b027-c4
. "$(dirname "${BASH_SOURCE[0]}")/selfwrap.sh"

. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

STUB=$(new_stub) || { bad "夹具：stub skill 副本创建失败"; finish; }

# ---------- 4a .githooks/pre-commit：audit-diff 只出现在注释行 ----------
T=$(new_case)
make_ob_repo "$T" svc-comment || finish
write_comment_hook "$T" .githooks/pre-commit '#' || finish
set_hooks_path "$T" .githooks || finish
grep_hits=$(grep -c 'audit-diff' "$T/.githooks/pre-commit")
assert_eq "4a 夹具：注释伪装行确实含 audit-diff 字面（否则用例空转）" 1 "$grep_hits"
audit_ob2 "$T" "$STUB"
assert_rc_is "4a 纯注释伪装：未达 ob2 → exit 1" 1 "$R_RC"
assert_contains "4a 纯注释伪装：缺口点名 mount_missing" "$R_OUT" "mount_missing"
assert_contains "4a 纯注释伪装：ob2 判 FAIL" "$R_OUT" "[FAIL] ob2"
assert_not_contains "4a 纯注释伪装：不得给 ob2 分" "$R_OUT" "[PASS] ob2"

# 归因对照（单文件真调用）：同一文件、同一路径，只把注释符去掉 → 必须恢复得分。
# 它同时守住修复本身：把「单文件载体」误判成一概无命中（假红）会在这里立刻翻红。
write_mount_hook "$T" .githooks/pre-commit || finish
audit_ob2 "$T" "$STUB"
assert_rc_is "4a 归因对照（单文件真调用）：去掉注释符后 exit 0" 0 "$R_RC"
assert_contains "4a 归因对照（单文件真调用）：ob2 判 PASS，不得误杀真挂载" "$R_OUT" "[PASS] ob2"
assert_contains "4a 归因对照（单文件真调用）：缺口为空" "$R_OUT" "缺口: 无"

# ---------- 4b husky 载体：.husky/pre-commit 纯注释伪装（必须与 ① 的 husky 载体叠加判负） ----------
H=$(new_case)
make_ob_repo "$H" svc-comment-husky || finish
write_comment_hook "$H" .husky/pre-commit '#' || finish
set_hooks_path "$H" .husky || finish
audit_ob2 "$H" "$STUB"
assert_rc_is "4b husky 纯注释伪装：exit 1" 1 "$R_RC"
assert_contains "4b husky 纯注释伪装：缺口点名 mount_missing" "$R_OUT" "mount_missing"
assert_not_contains "4b husky 纯注释伪装：不得给 ob2 分" "$R_OUT" "[PASS] ob2"

# ---------- 4c yaml 载体：.github/workflows/ci.yml 里 audit-diff 只写在 yaml 注释 ----------
W=$(new_case)
make_ob_repo "$W" svc-comment-yaml || finish
mkdir -p "$W/.github/workflows"
cat > "$W/.github/workflows/ci.yml" <<'YMLEOF'
name: ci
on: [push]
jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      # - run: bash scripts/audit-diff.sh --repo . --base origin/main
      - run: echo no-op
YMLEOF
assert_eq "4c 夹具：workflow 内 audit-diff 仅 1 处且为注释" 1 "$(grep -c 'audit-diff' "$W/.github/workflows/ci.yml")"
audit_ob2 "$W" "$STUB"
assert_rc_is "4c yaml 纯注释伪装：exit 1" 1 "$R_RC"
assert_contains "4c yaml 纯注释伪装：缺口点名 mount_missing" "$R_OUT" "mount_missing"
assert_not_contains "4c yaml 纯注释伪装：不得给 ob2 分" "$R_OUT" "[PASS] ob2"

# 归因对照：同一 workflow 去掉注释符（yaml 里变成真步骤）→ 恢复得分
sed -i 's|^      # - run: bash scripts/audit-diff.sh|      - run: bash scripts/audit-diff.sh|' \
  "$W/.github/workflows/ci.yml"
assert_eq "4c 归因对照夹具：注释符已去除" 0 "$(grep -c '^      # .*audit-diff' "$W/.github/workflows/ci.yml")"
audit_ob2 "$W" "$STUB"
assert_rc_is "4c 归因对照：yaml 真调用 → exit 0" 0 "$R_RC"
assert_contains "4c 归因对照：ob2 判 PASS" "$R_OUT" "[PASS] ob2"

# ---------- 4d 混合：注释伪装不遮蔽同仓别的真载体（判据是「存在非注释行」，不是「无注释行」） ----------
M=$(new_case)
make_ob_repo "$M" svc-comment-mixed || finish
write_comment_hook "$M" .githooks/pre-commit '#' || finish
write_mount_hook "$M" .githooks/pre-push || finish
set_hooks_path "$M" .githooks || finish
audit_ob2 "$M" "$STUB"
assert_rc_is "4d 注释 + 真调用并存：exit 0" 0 "$R_RC"
assert_contains "4d 注释 + 真调用并存：ob2 判 PASS" "$R_OUT" "[PASS] ob2"
assert_not_contains "4d 注释 + 真调用并存：不得误报 mount_missing" "$R_OUT" "mount_missing"

finish
