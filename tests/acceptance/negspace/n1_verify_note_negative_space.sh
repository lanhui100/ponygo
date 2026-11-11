#!/usr/bin/env bash
# N1（负空间·判据 1.11）：write-adr 的机械验证器必须锁住「简化笔记的复活条件」这一形状——
#   被测契约（Lead 裁决，exec-core C3）：
#     implemented/simplification/*.md（排除 *.zh.md、archived）必须含**围栏外**
#     `## Reintroduction conditions`；
#     若同时含 `## Removed surface`，则必须含至少一行含 rg / grep / git grep 的**检索收据行**；
#     违例消息带 `1.11` 前缀，退出码非零。
#   本文件把「反例必拒 + 正例必放 + 判据不外溢」成对钉死（全部在 mktemp 夹具里造，不写仓库）：
#     A 缺 `## Reintroduction conditions`      → 拒（含 1.11）
#     B 补上该段                               → 放行（路径模式 + 整树模式）
#     C 含 `## Removed surface` 但无检索收据行  → 拒（含 1.11）
#     D 带 `rg -n "x" .` / `grep -rn` 收据行    → 放行
#     E 非 simplification class 的同形状笔记    → 放行（判据不得外溢到所有 implemented）
#     F 围栏内写 `## Reintroduction conditions` → 拒（围栏内标题不算在场，与 1.8/1.10 同口径）
#     G *.zh.md 双语配对                        → 放行（与 1.10 同豁免口径）
#     H archived/ 冻结件                        → 放行（归档保持原貌）
# 冻结契约来源：团队 task-3（修复 A · exec-core C3）、task-5（修复 C · T3-N1）。
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

assert_exists "N1 夹具：被测资产 verify-note.sh 在场" "$VERIFY_NOTE"

REL_SIMP="implemented/simplification/2026-01-01-fixture-simplification.md"

# ---------- 夹具：一份满足 1.5–1.10 的 implemented 笔记 ----------
# stdin 传入「1.11 相关段落」，其余骨架固定 → 唯一变量是负空间形状。
# 注意：固定骨架**刻意不含任何检索工具名**，避免污染 1.11 的检索收据判定。
mk_note() { # <case-dir> <notes 下相对路径>；正文从 stdin 读（只落盘，不打印，避免污染断言行）
  local dir="$1" rel="$2" path
  path="$dir/.agents/notes/$rel"
  mkdir -p "$(dirname "$path")" || return 1
  {
    cat <<'HEAD'
# 2026-01-01 夹具：无真消费者符号移除

Status: implemented

## Context

夹具正文：某符号被判定「唯一消费者是自身」，按负空间工艺连根拔除并登记复活条件。

## Decision

移除该符号及其测试残留，同一变更内更新目录条目与文档索引。

## Alternatives considered

- 保留空壳：无生产消费者，留着只会随演进漂移。
HEAD
    cat
  } > "$path"
}

# ================= A：缺 ## Reintroduction conditions → 拒 =================
T=$(new_case)
mk_note "$T" "$REL_SIMP" </dev/null
assert_exists "N1-A 夹具：笔记已落盘（无 1.11 段落）" "$T/.agents/notes/$REL_SIMP"
run_script_in "$T" "$VERIFY_NOTE" ".agents/notes/$REL_SIMP"
assert_nonzero "N1-A 缺 ## Reintroduction conditions → 验证器必须拒" "$R_RC"
assert_contains "N1-A GO：拒因带判据号 1.11" "$R_OUT" "1.11"
assert_contains "N1-A GO：拒因指出笔记文件" "$R_OUT" "fixture-simplification.md"
assert_no_crash "N1-A 反例不得炸栈" "$R_OUT"

# ================= B：补上该段 → 放行（路径模式 + 整树模式）=================
T=$(new_case)
mk_note "$T" "$REL_SIMP" <<'EOF'
## Reintroduction conditions

- 出现第二个真实调用方、且其语义与该符号原始职责一致时，重新引入并补回测试。
EOF
run_script_in "$T" "$VERIFY_NOTE" ".agents/notes/$REL_SIMP"
assert_zero "N1-B 正例：补上 ## Reintroduction conditions → exit 0" "$R_RC"
assert_not_contains "N1-B NOGO：正例不得再报 1.11" "$R_OUT" "1.11"
assert_contains "N1-B GO：正例给出通过结论（1.1–1.10 口径仍自洽）" "$R_OUT" "全部通过"

# 整树模式（真实用法：无参 = 校验 .agents/notes/ 全树）：补 docs/AGENTS.md 满足 1.9a 后必须放行
mkdir -p "$T/docs" && printf '# 文档标准\n' > "$T/docs/AGENTS.md"
run_script_in "$T" "$VERIFY_NOTE"
assert_zero "N1-B 整树模式：全树校验亦放行" "$R_RC"
assert_not_contains "N1-B 整树模式：不得报 1.11" "$R_OUT" "1.11"
assert_no_crash "N1-B 整树模式不得炸栈" "$R_OUT"

# ================= C：含 ## Removed surface 但无检索收据行 → 拒 =================
T=$(new_case)
mk_note "$T" "$REL_SIMP" <<'EOF'
## Reintroduction conditions

- 出现第二个真实调用方时重新引入。

## Removed surface

- 移除夹具符号（本条夹具刻意不写任何检索命令：验证“零残留须有收据”）。
EOF
run_script_in "$T" "$VERIFY_NOTE" ".agents/notes/$REL_SIMP"
assert_nonzero "N1-C 有 ## Removed surface 而无检索收据 → 必须拒" "$R_RC"
assert_contains "N1-C GO：拒因带判据号 1.11" "$R_OUT" "1.11"
assert_no_crash "N1-C 反例不得炸栈" "$R_OUT"

# ================= D：带检索收据行 → 放行（rg / grep 等价） =================
T=$(new_case)
mk_note "$T" "$REL_SIMP" <<'EOF'
## Reintroduction conditions

- 出现第二个真实调用方时重新引入。

## Removed surface

- 移除夹具符号。

检索收据（零残留证据）：`rg -n "fixture_symbol" .` → 无命中（exit 1）。
EOF
run_script_in "$T" "$VERIFY_NOTE" ".agents/notes/$REL_SIMP"
assert_zero "N1-D 正例：带 rg -n \"x\" . 检索收据 → exit 0" "$R_RC"
assert_not_contains "N1-D NOGO：正例不得报 1.11" "$R_OUT" "1.11"

T=$(new_case)
mk_note "$T" "$REL_SIMP" <<'EOF'
## Reintroduction conditions

- 出现第二个真实调用方时重新引入。

## Removed surface

- 移除夹具符号。

检索收据（零残留证据）：grep -rn "fixture_symbol" . → 无命中（exit 1）。
EOF
run_script_in "$T" "$VERIFY_NOTE" ".agents/notes/$REL_SIMP"
assert_zero "N1-D2 正例：检索收据用 grep 亦放行（契约词表 rg/grep/git grep）" "$R_RC"

# ================= E：判据不得外溢到非 simplification class =================
T=$(new_case)
mk_note "$T" "implemented/architecture/2026-01-01-fixture-architecture.md" </dev/null
run_script_in "$T" "$VERIFY_NOTE" ".agents/notes/implemented/architecture/2026-01-01-fixture-architecture.md"
assert_zero "N1-E 边界：implemented/architecture 缺该段仍放行（1.11 只锁 simplification）" "$R_RC"
assert_not_contains "N1-E NOGO：非 simplification 不得报 1.11" "$R_OUT" "1.11"

# ================= F：围栏内的标题不算在场（fail-closed） =================
T=$(new_case)
mk_note "$T" "$REL_SIMP" <<'EOF'
```
## Reintroduction conditions

- 这是围栏内的示例文本，不是真段。
```
EOF
run_script_in "$T" "$VERIFY_NOTE" ".agents/notes/$REL_SIMP"
assert_nonzero "N1-F 围栏内 ## Reintroduction conditions → 不得算在场（拒）" "$R_RC"
assert_contains "N1-F GO：拒因带判据号 1.11" "$R_OUT" "1.11"

# ================= G：*.zh.md 双语配对豁免 =================
T=$(new_case)
mk_note "$T" "implemented/simplification/2026-01-01-fixture-simplification.zh.md" </dev/null
run_script_in "$T" "$VERIFY_NOTE" ".agents/notes/implemented/simplification/2026-01-01-fixture-simplification.zh.md"
assert_zero "N1-G 边界：*.zh.md 双语配对豁免 1.11" "$R_RC"
assert_not_contains "N1-G NOGO：豁免面不得报 1.11" "$R_OUT" "1.11"

# ================= H：archived/ 冻结件豁免 =================
T=$(new_case)
mk_note "$T" "archived/simplification/2026-01-01-fixture-archived.md" </dev/null
run_script_in "$T" "$VERIFY_NOTE" ".agents/notes/archived/simplification/2026-01-01-fixture-archived.md"
assert_zero "N1-H 边界：archived/ 冻结件豁免 1.11（归档保持原貌）" "$R_RC"
assert_not_contains "N1-H NOGO：archived 不得报 1.11" "$R_OUT" "1.11"

finish
