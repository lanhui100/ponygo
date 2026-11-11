#!/usr/bin/env bash
# ============================================================
# tests/acceptance/wave13/f6_gates_readme.sh
# 生成的 `.meta/gates/README.md` 必须与事实一致：删旧句（此目录为空 / 实例仓照旧从空开始）、
# 登记 A6/A7、宇宙表口径、pre-push 可选行（只说明、不生成 hook、不加旗标）。
#
# 契约真源：.dev-team/contract-matrix-wave13.md §7（RM-1 ~ RM-7，冻结）。
# 反假绿：不仅断言「删掉了旧句」，还断言「新句确实存在」+「生成物 == 仓库模板」+
#         反向断言不得凭空生成 .githooks/pre-push，且既有承诺片段未被文案改写顺手删掉。
# ============================================================
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

README_REL=".meta/gates/README.md"

# ---------- RM-1 / RM-2 / RM-3 / RM-4 / RM-5：init 生成物 ----------
T=$(new_case)
git_seed_repo "$T"
run_in "$T" init
assert_eq "RM 夹具：init exit 0" 0 "$R_RC"
G="$T/$README_REL"
assert_exists "RM 前置取证：init 生成 gates/README.md" "$G"

assert_file_lacks "RM-1 [NOGO] 不得含旧句「此目录为空」" "$G" "此目录为空"
assert_file_lacks "RM-1 [NOGO] 不得含旧句「实例仓照旧从空开始」" "$G" "实例仓照旧从空开始"
assert_file_lacks "RM-1 [NOGO] 不得含片段「照旧从空开始」" "$G" "照旧从空开始"

assert_file_has "RM-2 [GO] 新文案逐字：框架交付资产 A1/A2/A4/A6/A7/A8/A9 常驻；实例自有门禁从 L2 起按需添加" \
  "$G" "框架交付资产 A1/A2/A4/A6/A7/A8/A9 常驻；实例自有门禁从 L2 起按需添加"

assert_file_has "RM-3 [GO] 资产表含 A6 行" "$G" "A6"
assert_file_has "RM-3 [GO] 资产表含 A6 路径 .meta/gates/archive-verify.sh" "$G" ".meta/gates/archive-verify.sh"
assert_file_has "RM-3 [GO] 资产表含 A7 行" "$G" "A7"
assert_file_has "RM-3 [GO] 资产表含 A7 路径 .meta/gates/archive-verify.spec.sh" "$G" ".meta/gates/archive-verify.spec.sh"
assert_file_has "RM-3 [GO] 资产表含 A8 路径 .meta/gates/no-residue.sh" "$G" ".meta/gates/no-residue.sh"
assert_file_has "RM-3 [GO] 资产表含 A9 路径 .meta/gates/no-residue.spec.sh" "$G" ".meta/gates/no-residue.spec.sh"

assert_file_has "RM-4 [GO] pre-push 可选行含命令 bash .meta/gates/ci-verify.sh" "$G" "bash .meta/gates/ci-verify.sh"
assert_file_has "RM-4 [GO] 同段出现 pre-push" "$G" "pre-push"
if grep -qE 'pre-push.*(可选|按需)|(可选|按需).*pre-push' "$G"; then
  ok "RM-4 [GO] pre-push 措辞为「可选/按需」（不得写成强制）"
else
  bad "RM-4 [GO] pre-push 未标注「可选/按需」（易被误读为已装配的强制钩子）"
fi
assert_missing "RM-4 [NOGO] 不得生成 .githooks/pre-push（可选行只是说明）" "$T/.githooks/pre-push"

assert_file_has "RM-5 [GO] 出现「宇宙表只登记」口径句" "$G" "宇宙表只登记"
if grep -qE '宇宙表只登记[^\n]*A6[^\n]*A7|宇宙表只登记[^\n]*A6/A7' "$G"; then
  ok "RM-5 [GO] 宇宙表句同时列出 A6 与 A7"
else
  bad "RM-5 [GO] 宇宙表句未同时列出 A6 与 A7"
fi
assert_file_has "RM-5 [GO] A3 仍排除在宇宙表外（可编辑文件说明仍在）" "$G" "A3"
assert_file_has "RM-5 [GO] A5 仍排除在宇宙表外" "$G" "A5"

# 既有承诺片段不得被文案改写顺手删掉（不弱化）
assert_file_has "RM 回归：仍含 pre-commit 链入说明" "$G" "pre-commit"
assert_file_has "RM 回归：仍含 A1 路径" "$G" "adr-verify.sh"
assert_file_has "RM 回归：仍含 A4 路径" "$G" "ci-verify.sh"

# ---------- RM-6：双写一致（生成物 vs 仓库模板）----------
if [ -f "$ROOT/$README_REL" ]; then
  if diff <(tr -d '\r' < "$G") <(tr -d '\r' < "$ROOT/$README_REL") >/dev/null 2>&1; then
    ok "RM-6 [GO] 生成物与仓库模板 EOL 归一后逐字节一致（双写无漂移）"
  else
    bad "RM-6 [GO] 生成物与仓库模板不一致（双写漂移）"
  fi
else
  bad "RM-6 夹具：仓库模板缺失 $ROOT/$README_REL"
fi

# 仓库模板自身也不得残留旧句（RM-1 覆盖本仓同名文件）
assert_file_lacks "RM-1 [NOGO] 仓库模板不得含「此目录为空」" "$ROOT/$README_REL" "此目录为空"
assert_file_lacks "RM-1 [NOGO] 仓库模板不得含「实例仓照旧从空开始」" "$ROOT/$README_REL" "实例仓照旧从空开始"

# ---------- RM-7：升级/重跑不覆盖实例编辑 ----------
T=$(new_case)
git_seed_repo "$T"
run_in "$T" init
assert_eq "RM-7 夹具：init exit 0" 0 "$R_RC"
printf '\n实例自有门禁说明（编辑痕迹）\n' >> "$T/$README_REL"
MARK_BEFORE=$(md5_of "$T/$README_REL")
run_in "$T" init
assert_eq "RM-7 [C] 重复 init exit 0" 0 "$R_RC"
assert_eq "RM-7 [C] 实例编辑未被 init 覆盖" "$MARK_BEFORE" "$(md5_of "$T/$README_REL")"
assert_file_has "RM-7 [C] 追加行仍在" "$T/$README_REL" "实例自有门禁说明（编辑痕迹）"
run_in "$T" upgrade
assert_eq "RM-7 [C] upgrade exit 0" 0 "$R_RC"
assert_eq "RM-7 [C] 实例编辑未被 upgrade 覆盖" "$MARK_BEFORE" "$(md5_of "$T/$README_REL")"

# ---------- repair 路径同一文案口径 ----------
T=$(new_case)
git_seed_repo "$T"
run_in "$T" init
assert_eq "repair 夹具：init exit 0" 0 "$R_RC"
rm -f "$T/$README_REL"
run_in "$T" init --repair-skeleton
assert_eq "repair（README 缺口）exit 0" 0 "$R_RC"
assert_file_has "repair 补回的 README 同样含 A1/A2/A4/A6/A7/A8/A9" "$T/$README_REL" "A1/A2/A4/A6/A7/A8/A9"
assert_file_lacks "repair 补回的 README 同样不含「此目录为空」" "$T/$README_REL" "此目录为空"

finish
