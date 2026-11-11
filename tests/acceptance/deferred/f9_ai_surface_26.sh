#!/usr/bin/env bash
# F9（L2 条件判据 2.6「AI 常载命约已投影」）：四态 + 兼容性。
#   ① meta.yaml 未声明 ai-surface → 输出含 2.6 与 SKIPPED/未声明 WARN，退出码不受影响（level 2 仓仍 0）
#   ② ai-surface: on 且根 AGENTS.md 缺 <!-- BEGIN constitution -->/<!-- END constitution --> 成对块
#      → 2.6 FAIL + exit 1 + 输出含 'ponygo sync' 补救
#   ③ ai-surface: on 且已 ponygo sync 投影 → 2.6 PASS（exit 0）
#   ④ ai-surface: off → 结论行不得出现「全部 PASS」，须显式说明 2.6 未启用
#   ⑤ 兼容性：未声明 ai-surface 的既有 L2 实例不得因该判据变红
# 冻结契约来源：Lead 裁决（task-5 · F9）；判据真源 maturity-ladder L2 2.6。
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# ================= ① 未声明 ai-surface =================
T=$(new_case)
gov_repo "$T" 2
# 通道口径（CE-7 / L3DEF-13）：分别捕获 stdout 与 stderr——2.6 SKIPPED 的说明行允许出现在
# stdout 结论行（与 2.5 同先例），WARN 在 stderr；两者都要断言，退出码不变。
run_split "$T" audit
assert_zero "F9-① 未声明 ai-surface → level 2 仓仍 exit 0（判据不影响退出码）" "$R_RC"
assert_contains "F9-① GO：stderr 的 WARN 通道含「2.6 SKIPPED」" "$R_ERR" "2.6 SKIPPED"
CONC1=$(conclusion_of "$R_OUT")
assert_contains "F9-① GO：stdout 结论行点明 2.6" "$CONC1" "2.6"
assert_matches "F9-① GO：结论面标注 SKIPPED/未验证" "$R_OUT" 'SKIPPED|未验证|未声明'
assert_not_matches "F9-① NOGO：未声明不得判 2.6 FAIL" "$R_OUT$R_ERR" '^[[:space:]]*-[[:space:]]*2\.6'

# ================= ② ai-surface: on + 缺哨兵块 =================
T=$(new_case)
gov_repo "$T" 2
printf 'level: 2\nai-surface: on\n' > "$T/.meta/meta.yaml"
printf '# AGENTS.md（人为去掉 constitution 哨兵块；保留 1.9 索引行避免 1.9 先红）\n\n文档标准 → docs/AGENTS.md\n' > "$T/AGENTS.md"
assert_not_contains "F9-② 夹具：AGENTS.md 确无 BEGIN 哨兵" "$(cat "$T/AGENTS.md")" "BEGIN constitution"

run_in "$T" audit
assert_rc_is "F9-② ai-surface: on 且未投影 → exit 1" 1 "$R_RC"
assert_contains "F9-② GO：判定点是 2.6" "$R_OUT" "2.6"
assert_contains "F9-② GO：给出补救命令 ponygo sync" "$R_OUT" "ponygo sync"

# ================= ③ ai-surface: on + 已投影 =================
T=$(new_case)
gov_repo "$T" 2
printf 'level: 2\nai-surface: on\n' > "$T/.meta/meta.yaml"
printf '# AGENTS.md（先去掉哨兵块，再用 sync 重新投影）\n\n文档标准 → docs/AGENTS.md\n' > "$T/AGENTS.md"
run_in "$T" sync
assert_zero "F9-③ 夹具：ponygo sync exit 0" "$R_RC"
AG_TXT=$(cat "$T/AGENTS.md" 2>/dev/null || :)
assert_contains "F9-③ 夹具：sync 后出现 BEGIN 哨兵" "$AG_TXT" "<!-- BEGIN constitution -->"
assert_contains "F9-③ 夹具：sync 后出现 END 哨兵" "$AG_TXT" "<!-- END constitution -->"

run_in "$T" audit
assert_zero "F9-③ ai-surface: on 且已投影 → exit 0（2.6 PASS）" "$R_RC"
assert_contains "F9-③ GO：结论行为「级自洽验证：通过」" "$R_OUT" "级自洽验证：通过"
# 2.6 PASS 是「无 FAIL 项」；成功态不要求回显判据编号（与 2.1–2.5 同口径）
assert_not_matches "F9-③ NOGO：不得把 2.6 判成 FAIL/未投影" "$R_OUT" '^[[:space:]]*-[[:space:]]*2\.6'
assert_not_contains "F9-③ NOGO：不得出现正文漂移文案" "$R_OUT" "投影正文漂移"

# ================= ④ ai-surface: off =================
T=$(new_case)
gov_repo "$T" 2
printf 'level: 2\nai-surface: off\n' > "$T/.meta/meta.yaml"
run_in "$T" audit
assert_zero "F9-④ ai-surface: off → exit 0（显式 opt-out 不判 FAIL）" "$R_RC"
assert_not_contains "F9-④ NOGO：结论行不得出现「全部 PASS」" "$R_OUT" "全部 PASS"
assert_contains "F9-④ GO：显式说明 2.6 未启用" "$R_OUT" "未启用"
assert_contains "F9-④ GO：输出仍点明 2.6" "$R_OUT" "2.6"

# ================= ⑤ 兼容性：未声明的既有 L2 实例不被打断 =================
T=$(new_case)
gov_repo "$T" 2
run_in "$T" status
assert_zero "F9-⑤ 兼容性：未声明 ai-surface 的 L2 仓 status 仍 exit 0" "$R_RC"
assert_not_matches "F9-⑤ NOGO：status 不得把 2.6 判成 FAIL" "$R_OUT" '^[[:space:]]*-[[:space:]]*2\.6'
run_in "$T" audit
assert_zero "F9-⑤ 兼容性：未声明 ai-surface 的 L2 仓 audit 仍 exit 0" "$R_RC"
assert_not_contains "F9-⑤ 兼容性：既有结论行仍保留（未被 2.6 改写为失败）" "$R_OUT" "级自洽验证：未通过"

# ================= ⑥ 2.6 成对性 / 非空性（L3 终审新增）=================
# 成对不是「两个哨兵行都在」就够：END 在 BEGIN 之上、或块内为空，都不是有效投影 → FAIL + exit 1。
T=$(new_case)
gov_repo "$T" 2
printf 'level: 2\nai-surface: on\n' > "$T/.meta/meta.yaml"
cat > "$T/AGENTS.md" <<'AGEOF'
# AGENTS.md（END 在 BEGIN 之上：顺序颠倒）

文档标准 → docs/AGENTS.md

<!-- END constitution -->
中间内容
<!-- BEGIN constitution -->
AGEOF
run_in "$T" audit
assert_rc_is "F9-⑥a 哨兵顺序颠倒（END 在 BEGIN 之上）→ exit 1" 1 "$R_RC"
assert_contains "F9-⑥a GO：判定点是 2.6" "$R_OUT" "2.6"

T=$(new_case)
gov_repo "$T" 2
printf 'level: 2\nai-surface: on\n' > "$T/.meta/meta.yaml"
cat > "$T/AGENTS.md" <<'AGEOF'
# AGENTS.md（成对但块内为空：等于没投影）

文档标准 → docs/AGENTS.md

<!-- BEGIN constitution -->
<!-- END constitution -->
AGEOF
run_in "$T" audit
assert_rc_is "F9-⑥b 哨兵成对但块内为空 → exit 1" 1 "$R_RC"
assert_contains "F9-⑥b GO：判定点是 2.6" "$R_OUT" "2.6"

# ================= ⑦ 2.6 重复 BEGIN（Wave-10 回归缺口补齐）=================
# 契约：两个 <!-- BEGIN constitution --> 配一个 END 不是有效投影（块结构不唯一）→ 2.6 FAIL + exit 1；
# 反向对照：正常一对 BEGIN/END → PASS（exit 0）。
T=$(new_case)
gov_repo "$T" 2
printf 'level: 2\nai-surface: on\n' > "$T/.meta/meta.yaml"
cat > "$T/AGENTS.md" <<'AGEOF'
# AGENTS.md（两个 BEGIN 配一个 END：块结构不唯一）

文档标准 → docs/AGENTS.md

<!-- BEGIN constitution -->
第一块内容
<!-- BEGIN constitution -->
第二块内容
<!-- END constitution -->
AGEOF
run_in "$T" audit
assert_rc_is "F9-⑦a 重复 BEGIN（两个 BEGIN + 一个 END）→ exit 1" 1 "$R_RC"
assert_contains "F9-⑦a GO：判定点是 2.6" "$R_OUT" "2.6"
assert_not_contains "F9-⑦a NOGO：重复块不得声称 sync 可修" "$R_OUT" "ponygo sync"
assert_contains "F9-⑦a GO：提示手工清理标记区" "$R_OUT" "手工清理"

T=$(new_case)
gov_repo "$T" 2
printf 'level: 2\nai-surface: on\n' > "$T/.meta/meta.yaml"
cat > "$T/AGENTS.md" <<'AGEOF'
# AGENTS.md（正常一对哨兵）

文档标准 → docs/AGENTS.md

<!-- BEGIN constitution -->
真实命约内容（唯一块）
<!-- END constitution -->
AGEOF
run_in "$T" sync
assert_zero "F9-⑦b 夹具：sync 生成 canonical 正文" "$R_RC"
run_in "$T" audit
assert_zero "F9-⑦b 反向对照：正常一对 BEGIN/END → exit 0（2.6 PASS）" "$R_RC"
assert_contains "F9-⑦b GO：结论行为「级自洽验证：通过」" "$R_OUT" "级自洽验证：通过"
assert_not_matches "F9-⑦b NOGO：不得把 2.6 判成 FAIL" "$R_OUT" '^[[:space:]]*-[[:space:]]*2\.6'

# ================= ⑦c 2.6 重复 END（Wave-11 回归缺口）=================
# 契约对称性：一个 BEGIN 配**两个** END 同样不是有效投影（块结构不唯一）→ 2.6 FAIL + exit 1；
# 反向对照沿用 F9-⑦b（正常一对 BEGIN/END → PASS）。
T=$(new_case)
gov_repo "$T" 2
printf 'level: 2\nai-surface: on\n' > "$T/.meta/meta.yaml"
cat > "$T/AGENTS.md" <<'AGEOF'
# AGENTS.md（一个 BEGIN 配两个 END：块结构不唯一）

文档标准 → docs/AGENTS.md

<!-- BEGIN constitution -->
真实命约内容
<!-- END constitution -->
<!-- END constitution -->
AGEOF
run_in "$T" audit
assert_rc_is "F9-⑦c 重复 END（一个 BEGIN + 两个 END）→ exit 1" 1 "$R_RC"
assert_contains "F9-⑦c GO：判定点是 2.6" "$R_OUT" "2.6"
assert_not_contains "F9-⑦c NOGO：重复块不得声称 sync 可修" "$R_OUT" "ponygo sync"
assert_contains "F9-⑦c GO：提示手工清理标记区" "$R_OUT" "手工清理"

finish
