#!/usr/bin/env bash
# GH9：W2a 契约验收（U3 删除决策记录入册 / U5 结论行诚实化）
# 契约源：.dev-team/contract-w2a-u3-u5.md §3（T-U3-* / T-U5-*）
# 纪律：黑盒断言（CLI/门 的公开行为 + 生成仓状态），纯 bash + lib.sh；折叠进 s90，不新增 run.sh 场景。
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

git_base() { # <dir>：把夹具落成基线提交（lib 已把 user.* 指向空配置，故逐命令给身份）
  git -C "$1" -c user.name=gh9 -c user.email=gh9@example.invalid add -A >/dev/null 2>&1
  git -C "$1" -c user.name=gh9 -c user.email=gh9@example.invalid commit -q -m base >/dev/null 2>&1
}

write_simpl_note() { # <dir> [--no-reintroduce]
  local d="$1" mode="${2:-}"
  mkdir -p "$d/.agents/notes/implemented/simplification"
  {
    printf '# Agent Note: 移除夹具决策（简化）\n\nStatus: implemented\n\n## Decision\n\n删掉夹具决策，能力由简化 note 接管。\n\n## Alternatives considered\n\n- 保留并标注过时：否决，过时决策会挤掉当前事实。\n\n## Removed surface\n\n- `.agents/notes/implemented/architecture/2026-01-01-fixture.md`\n\n- 检索收据：rg --fixed-strings 2026-01-01-fixture .agents/notes\n'
    if [ "$mode" != "--no-reintroduce" ]; then
      printf '\n## Reintroduction conditions\n\n若该决策重新成为当前事实（例如治理根改回单文档），把它按 implemented 重新入册。\n'
    fi
  } > "$d/.agents/notes/implemented/simplification/2026-01-05-remove-fixture.md"
}

# ============================================================
# U3：删除决策记录必须同提交入册
# ============================================================
T=$(new_case)
make_gov_repo "$T" 1
git_base "$T"
git -C "$T" rm -q .agents/notes/implemented/architecture/2026-01-01-fixture.md >/dev/null 2>&1
run_cli "$T" ""
(cd "$T" && bash .meta/gates/adr-verify.sh > "$T/.o1" 2>&1); echo $? > "$T/.rc1"
assert_nonzero "T-U3-1 删除 ADR 而无简化 note → A1 非零拒绝" "$(cat "$T/.rc1")"
assert_contains "T-U3-1b 文案要求同提交入册 simplification" "$(cat "$T/.o1")" "simplification"
assert_contains "T-U3-1c 文案声明「移除本身是一次决策」" "$(cat "$T/.o1")" "移除本身是一次决策"

write_simpl_note "$T"
git -C "$T" add -A >/dev/null 2>&1
(cd "$T" && bash .meta/gates/adr-verify.sh > "$T/.o2" 2>&1); echo $? > "$T/.rc2"
assert_zero "T-U3-2 删除 ADR + 合法简化 note → A1 放行" "$(cat "$T/.rc2")"

# 简化 note 缺 ## Reintroduction conditions → 由判定真源 1.11 拒绝
T2=$(new_case)
make_gov_repo "$T2" 1
git_base "$T2"
git -C "$T2" rm -q .agents/notes/implemented/architecture/2026-01-01-fixture.md >/dev/null 2>&1
write_simpl_note "$T2" --no-reintroduce
git -C "$T2" add -A >/dev/null 2>&1
(cd "$T2" && bash .meta/gates/adr-verify.sh > "$T2/.o3" 2>&1); echo $? > "$T2/.rc3"
assert_nonzero "T-U3-3 简化 note 缺复活条件 → A1 非零（真源 1.11）" "$(cat "$T2/.rc3")"

(cd "$ROOT" && bash .meta/gates/adr-verify.spec.sh >/dev/null 2>&1); echo $? > /tmp/gh9_a2.$$
assert_zero "T-U3-4 A2 负样本自检 exit 0（新增删除用例后仍自洽）" "$(cat /tmp/gh9_a2.$$)"
rm -f /tmp/gh9_a2.$$

# ---------- 审核 BLOCKING/ADVISORY 的机器看守（W2a 对抗审核 2026-11-17）----------
# T-U3-5：生命周期迁移（proposed → implemented）被 git 表示成 D+A 时不得误判为「删除」
T6=$(new_case)
make_gov_repo "$T6" 1
mkdir -p "$T6/.agents/notes/proposed/architecture"
printf '# 迁移中的提案\n\nStatus: proposed\n\n## Problem\n\np\n\n## Proposal\n\npp\n\n## Alternatives considered\n\n- a\n\n## Acceptance criteria\n\nac\n\n## Risks\n\nr\n' > "$T6/.agents/notes/proposed/architecture/2026-02-01-migrate-me.md"
git_base "$T6"
git -C "$T6" rm -q .agents/notes/proposed/architecture/2026-02-01-migrate-me.md >/dev/null 2>&1
mkdir -p "$T6/.agents/notes/implemented/architecture"
printf '# 迁移后的决策\n\nStatus: implemented\n\n## Decision\n\nd\n\n## Alternatives considered\n\n- a\n' > "$T6/.agents/notes/implemented/architecture/2026-02-01-migrate-me.md"
git -C "$T6" add -A >/dev/null 2>&1
(cd "$T6" && bash .meta/gates/adr-verify.sh > "$T6/.o6" 2>&1); echo $? > "$T6/.rc6"
assert_zero "T-U3-5 生命周期迁移（同 basename 的 D+A）不得被判成删除决策记录" "$(cat "$T6/.rc6")"

# T-U3-6：只删 *.zh.md 译文（母语版仍在）→ 与 1.7/1.10/1.11 的 zh 豁免同口径，不要求入册
T7=$(new_case)
make_gov_repo "$T7" 1
printf '# 译文\n\nStatus: implemented\n\n## Decision\n\nd\n\n## Alternatives considered\n\n- a\n' > "$T7/.agents/notes/implemented/architecture/2026-01-01-fixture.zh.md"
git_base "$T7"
git -C "$T7" rm -q .agents/notes/implemented/architecture/2026-01-01-fixture.zh.md >/dev/null 2>&1
(cd "$T7" && bash .meta/gates/adr-verify.sh > "$T7/.o7" 2>&1); echo $? > "$T7/.rc7"
assert_zero "T-U3-6 只删 *.zh.md 译文 → A1 放行（zh 随母语版同批补齐，不独立判）" "$(cat "$T7/.rc7")"

# T-U3-7：简化 note 必须是真 note——README.md 不能充当入册载体
T8=$(new_case)
make_gov_repo "$T8" 1
git_base "$T8"
git -C "$T8" rm -q .agents/notes/implemented/architecture/2026-01-01-fixture.md >/dev/null 2>&1
mkdir -p "$T8/.agents/notes/implemented/simplification"
printf '# simplification 目录说明\n\n本目录放简化记录。\n' > "$T8/.agents/notes/implemented/simplification/README.md"
git -C "$T8" add -A >/dev/null 2>&1
(cd "$T8" && bash .meta/gates/adr-verify.sh > "$T8/.o8" 2>&1); echo $? > "$T8/.rc8"
assert_nonzero "T-U3-7 仅塞 simplification/README.md → A1 仍非零（README 不是决策记录）" "$(cat "$T8/.rc8")"

# T-U3-8：简化 note 未提及被删路径 → 放行但打可复核 WARN（不做语义硬判）
T9=$(new_case)
make_gov_repo "$T9" 1
git_base "$T9"
git -C "$T9" rm -q .agents/notes/implemented/architecture/2026-01-01-fixture.md >/dev/null 2>&1
write_simpl_note "$T9"
git -C "$T9" add -A >/dev/null 2>&1
(cd "$T9" && bash .meta/gates/adr-verify.sh > "$T9/.o9" 2>&1); echo $? > "$T9/.rc9"
assert_zero "T-U3-8 简化 note 存在 → A1 放行（语义关联靠 review）" "$(cat "$T9/.rc9")"
assert_contains "T-U3-8b 未提及被删路径时打可复核 WARN" "$(cat "$T9/.o9")" "建议复核"

# ============================================================
# U5：结论行诚实化（通过 → 已判定部分通过）
# ============================================================
T3=$(new_case)
make_gov_repo "$T3" 1
run_cli "$T3" status
CONC=$(printf '%s\n' "$R_OUT" | grep '^级自洽验证：')
assert_contains "T-U5-1 lv=1 结论行判词为「已判定部分通过」" "$CONC" "级自洽验证：已判定部分通过（"
assert_not_contains "T-U5-1b 不再出现无保留的「级自洽验证：通过（」" "$R_OUT" "级自洽验证：通过（"

T4=$(new_case)
make_gov_repo "$T4" 1
mkdir -p "$T4/.agents/notes/implemented/feature"
printf '# bad\n\nStatus: implemented\n\n## Decision\n\nd\n\n## Alternatives considered\n\n- a\n' > "$T4/.agents/notes/implemented/feature/badname.md"
run_cli "$T4" status
assert_nonzero "T-U5-2 判据 FAIL 仓 status 非零" "$R_RC"
assert_contains "T-U5-2b 失败判词不变" "$R_OUT" "级自洽验证：未通过（声明"

T5=$(new_case)
mkdir -p "$T5"
(cd "$T5" && git init -q .)
run_cli "$T5" init
run_cli "$T5" status
CONC5=$(printf '%s\n' "$R_OUT" | grep '^级自洽验证：')
assert_eq "T-U5-3 lv=0 结论行逐字节不变（不存在「部分」）" "级自洽验证：通过（纯 L0 长驻：合法终态）" "$CONC5"

run_json "$T3" status --json
assert_zero "T-U5-4 status --json exit 0" "$R_RC"
assert_eq "T-U5-4b --json 仍为单行" "1" "$(printf '%s\n' "$R_OUT" | grep -c '')"
json_assert "T-U5-4c --json 的 exit 字段与退出码一致（词表不动）" "$R_OUT" '
fail = []
if d.get("exit") != 0: fail.append("exit=%r" % d.get("exit"))
'

finish
