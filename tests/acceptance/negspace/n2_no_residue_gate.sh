#!/usr/bin/env bash
# N2（负空间·A8 零残留门）：.meta/gates/no-residue.sh 的判定面必须「命中必拒、干净必放、
#   无可判定项跳过、参数非法 fail-closed」，且检索语义是**固定字符串**而非正则。
#   被测契约（Lead 裁决，exec-core C4）：
#     默认清单 .meta/gates/no-residue.manifest；每行 `<字面串><TAB><范围>`；
#     空行 / `#` 注释忽略；非空且无 TAB 的行 = 格式非法 → exit 1；
#     清单不存在或为空（含只有注释）→ 打印「跳过」且 exit 0（无可判定项，不假装通过）；
#     任一登记命中残留 → 逐条列出「字面串 ← 命中文件」并 exit 1；
#     未知参数 / 多余参数 → exit 1；
#     检索用 rg --fixed-strings（字面匹配，不做正则解释），无 rg 时退化 grep -F。
#   全部夹具在 mktemp 临时仓里造（把门脚本复制进夹具的 .meta/gates/），**不写仓库**。
# 冻结契约来源：团队 task-3（修复 A · exec-core C4/C5）、task-5（修复 C · T3-N2）。
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

assert_exists "N2 夹具：被测门 A8 资产在场" "$NO_RESIDUE_SH"

# 夹具：临时仓 + 把真实门脚本复制到 <仓>/.meta/gates/（门的 ROOT 由脚本自身位置解析 → 指向夹具）
mk_gate_case() { # <case-dir>
  mkdir -p "$1/.meta/gates" || return 1
  cp "$NO_RESIDUE_SH" "$1/.meta/gates/no-residue.sh" || return 1
  printf '%s\n' "$1"
}
GATE_REL=".meta/gates/no-residue.sh"

# ================= 1) 命中残留 → exit 1 且逐条列出 =================
T=$(new_case); mk_gate_case "$T" >/dev/null
mkdir -p "$T/src"
printf 'func Live() {}\n// 这里仍有 fixture_dropped_symbol 的残留引用\n' > "$T/src/live.txt"
printf 'fixture_dropped_symbol\tsrc\n' > "$T/.meta/gates/no-residue.manifest"
run_script_in "$T" "$GATE_REL"
assert_rc_is "N2-1 清单登记的符号仍在树里 → exit 1" 1 "$R_RC"
assert_contains "N2-1 GO：列出被命中的字面串" "$R_OUT" "fixture_dropped_symbol"
assert_contains "N2-1 GO：列出命中文件" "$R_OUT" "src/live.txt"
assert_contains "N2-1 GO：给出 FAIL 结论" "$R_OUT" "FAIL"
assert_no_crash "N2-1 不得炸栈" "$R_OUT"

# ================= 2) 零残留 → exit 0 =================
T=$(new_case); mk_gate_case "$T" >/dev/null
mkdir -p "$T/src"
printf 'func Live() {}\n' > "$T/src/live.txt"
printf 'fixture_dropped_symbol\tsrc\n' > "$T/.meta/gates/no-residue.manifest"
run_script_in "$T" "$GATE_REL"
assert_rc_is "N2-2 零残留 → exit 0" 0 "$R_RC"
assert_contains "N2-2 GO：给出通过结论" "$R_OUT" "通过"
assert_not_contains "N2-2 NOGO：干净树不得报残留" "$R_OUT" "残留命中"

# 清单自身不得被自己命中（清单里就写着该字面串）——上面这条已隐含；再加默认清单路径（无参）一次：
: > "$T/src/only.txt"
run_script_in "$T" "$GATE_REL"
assert_rc_is "N2-2b 无参 = 默认清单 .meta/gates/no-residue.manifest → exit 0" 0 "$R_RC"

# ================= 3) 空清单 / 缺清单 → exit 0 且明示跳过 =================
T=$(new_case); mk_gate_case "$T" >/dev/null
mkdir -p "$T/src"; printf 'func Live() {}\n' > "$T/src/live.txt"
printf '# 只有注释，没有任何登记\n\n' > "$T/.meta/gates/no-residue.manifest"
run_script_in "$T" "$GATE_REL"
assert_rc_is "N2-3 空清单（只有注释）→ exit 0（无可判定项）" 0 "$R_RC"
assert_contains "N2-3 GO：明示「跳过」而非假装通过" "$R_OUT" "跳过"

T=$(new_case); mk_gate_case "$T" >/dev/null
mkdir -p "$T/src"; printf 'func Live() {}\n' > "$T/src/live.txt"
assert_missing "N2-3b 夹具：确无默认清单" "$T/.meta/gates/no-residue.manifest"
run_script_in "$T" "$GATE_REL"
assert_rc_is "N2-3b 缺清单 → exit 0（无可判定项）" 0 "$R_RC"
assert_contains "N2-3b GO：明示「跳过」" "$R_OUT" "跳过"

# ================= 4) 参数非法 fail-closed =================
T=$(new_case); mk_gate_case "$T" >/dev/null
mkdir -p "$T/src"; printf 'func Live() {}\n' > "$T/src/live.txt"
printf 'fixture_dropped_symbol\tsrc\n' > "$T/.meta/gates/no-residue.manifest"

run_script_in "$T" "$GATE_REL" --bogus-flag
assert_rc_is "N2-4 未知参数 → exit 1" 1 "$R_RC"
assert_matches "N2-4 GO：报未知参数" "$R_OUT" '未知参数|unknown|用法'
assert_no_crash "N2-4 未知参数不得炸栈" "$R_OUT"

run_script_in "$T" "$GATE_REL" ".meta/gates/no-residue.manifest" "extra.manifest"
assert_rc_is "N2-4b 多余参数（只接受一个清单路径）→ exit 1" 1 "$R_RC"
assert_matches "N2-4b GO：报多余参数" "$R_OUT" '多余参数|只接受一个|用法'

# --help 是已知参数：exit 0 且打印用法（不是静默执行）
run_script_in "$T" "$GATE_REL" --help
assert_rc_is "N2-4c --help → exit 0" 0 "$R_RC"
assert_contains "N2-4c GO：--help 打印用法" "$R_OUT" "用法"

# ================= 5) 清单格式非法 → exit 1（宁拒不猜） =================
T=$(new_case); mk_gate_case "$T" >/dev/null
mkdir -p "$T/src"; printf 'func Live() {}\n' > "$T/src/live.txt"
printf 'no_tab_here_is_illegal\n' > "$T/.meta/gates/no-residue.manifest"
run_script_in "$T" "$GATE_REL"
assert_rc_is "N2-5 非空且无 TAB 的登记行 → exit 1（格式非法）" 1 "$R_RC"
assert_matches "N2-5 GO：报格式非法与行号" "$R_OUT" '格式非法'
assert_contains "N2-5 GO：指出第 1 行" "$R_OUT" "第 1 行"

T=$(new_case); mk_gate_case "$T" >/dev/null
mkdir -p "$T/src"; printf 'func Live() {}\n' > "$T/src/live.txt"
printf '\tsrc\n' > "$T/.meta/gates/no-residue.manifest"
run_script_in "$T" "$GATE_REL"
assert_rc_is "N2-5b 空字面串（会命中一切）→ exit 1" 1 "$R_RC"
assert_matches "N2-5b GO：报字面串为空" "$R_OUT" '字面串为空'

# ================= 6) 字面匹配而非正则解释 =================
# 登记 axb：正则语义下 a.b 会命中 axb —— 固定字符串语义下**不得**命中。
T=$(new_case); mk_gate_case "$T" >/dev/null
mkdir -p "$T/src"
printf '这个是 axb，不含被删名字\n' > "$T/src/other.txt"
printf 'a.b\tsrc\n' > "$T/.meta/gates/no-residue.manifest"
run_script_in "$T" "$GATE_REL"
assert_rc_is "N2-6 登记 a.b 不得命中 axb（固定字符串，非正则）→ exit 0" 0 "$R_RC"
assert_not_contains "N2-6 NOGO：不得把正则语义带入" "$R_OUT" "残留命中"

# 反向：树里真有字面 a.b 时，同一登记必须命中（证明不是“恒不命中”的假绿）
T=$(new_case); mk_gate_case "$T" >/dev/null
mkdir -p "$T/src"
printf '这里真有字面 a.b 残留\n' > "$T/src/real.txt"
printf 'a.b\tsrc\n' > "$T/.meta/gates/no-residue.manifest"
run_script_in "$T" "$GATE_REL"
assert_rc_is "N2-6b 真有字面 a.b → exit 1（字面语义两条腿都成立）" 1 "$R_RC"
assert_contains "N2-6b GO：列出该文件" "$R_OUT" "src/real.txt"

# 特殊字符按字面（括号/方括号不做字符组解释）
T=$(new_case); mk_gate_case "$T" >/dev/null
mkdir -p "$T/src"
printf '无关内容 x\n' > "$T/src/plain.txt"
printf 'f(x)\tsrc\n' > "$T/.meta/gates/no-residue.manifest"
run_script_in "$T" "$GATE_REL"
assert_rc_is "N2-6c 特殊字符 f(x) 按字面检索（不命中无关文件）→ exit 0" 0 "$R_RC"

T=$(new_case); mk_gate_case "$T" >/dev/null
mkdir -p "$T/src"
printf '调用处 f(x) 仍在\n' > "$T/src/call.txt"
printf 'f(x)\tsrc\n' > "$T/.meta/gates/no-residue.manifest"
run_script_in "$T" "$GATE_REL"
assert_rc_is "N2-6d 真有字面 f(x) → exit 1" 1 "$R_RC"
assert_contains "N2-6d GO：列出该文件" "$R_OUT" "src/call.txt"

# ================= 7) 范围生效：scope 之外的命中不计 =================
T=$(new_case); mk_gate_case "$T" >/dev/null
mkdir -p "$T/src" "$T/docs"
printf 'clean\n' > "$T/src/clean.txt"
printf 'fixture_dropped_symbol 只在 docs 里\n' > "$T/docs/note.md"
printf 'fixture_dropped_symbol\tsrc\n' > "$T/.meta/gates/no-residue.manifest"
run_script_in "$T" "$GATE_REL"
assert_rc_is "N2-7 命中在 scope 之外 → 不计（exit 0）" 0 "$R_RC"

# ================= 8) 退化路径（无 rg 时 grep -F）语义一致 =================
T=$(new_case); mk_gate_case "$T" >/dev/null
mkdir -p "$T/src"
printf '残留 fixture_dropped_symbol\n' > "$T/src/live.txt"
printf 'fixture_dropped_symbol\tsrc\n' > "$T/.meta/gates/no-residue.manifest"
R_OUT=$(cd "$T" && NO_RESIDUE_FORCE_GREP=1 bash "$GATE_REL" 2>&1); R_RC=$?
assert_rc_is "N2-8 退化路径（NO_RESIDUE_FORCE_GREP=1）仍判残留 → exit 1" 1 "$R_RC"
assert_contains "N2-8 GO：退化路径照样列出命中文件" "$R_OUT" "src/live.txt"

T=$(new_case); mk_gate_case "$T" >/dev/null
mkdir -p "$T/src"; printf 'clean\n' > "$T/src/clean.txt"
printf 'fixture_dropped_symbol\tsrc\n' > "$T/.meta/gates/no-residue.manifest"
R_OUT=$(cd "$T" && NO_RESIDUE_FORCE_GREP=1 bash "$GATE_REL" 2>&1); R_RC=$?
assert_rc_is "N2-8b 退化路径下干净树 → exit 0（两条检索路径语义一致）" 0 "$R_RC"

finish
