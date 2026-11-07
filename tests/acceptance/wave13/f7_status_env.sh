#!/usr/bin/env bash
# ============================================================
# tests/acceptance/wave13/f7_status_env_line.sh
# status 的「环境依赖」行：五行固定形状（git / GNU date / find -printf / sed -i / observe skill），
# 紧随「治理级」行、缺项 ✗、零旗标、不改退出码、只读。
#
# 契约真源：.dev-team/contract-matrix-wave13.md §8（ENV-1 ~ ENV-7，冻结）
#           + §8.1（探针定义面向 Executor 冻结；本测试**不绑定探针命令**）。
# 反假绿：① 形状正则（五项名/顺序/分隔符 ` / `）；② 缺项必须变 ✗（证探测而非常量）；
#         ③ 位置断言（「治理级」下一行）；④ 退出码前后一致；⑤ 只读（不执行门禁脚本）。
# ENV-5（✗ 分支）为契约「可选 R 相」：本文件用**不扰动治理判定**的 observe skill 缺项实现，
# 并在文末附 git 缺项的 R 相机理证据（不锚定探针实现）。
# ============================================================
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ENV_RE='^环境：git (✓|✗) / GNU date (✓|✗) / find -printf (✓|✗) / sed -i (✓|✗) / observe skill (✓|✗)$'
env_line_of() { printf '%s\n' "$1" | grep '^环境：' | head -n1; }

# ---------- ENV-1 / ENV-2 / ENV-3 / ENV-4：默认环境 ----------
T=$(new_case)
git_seed_repo "$T"
run_in "$T" init
printf 'level: 1\n' > "$T/.meta/meta.yaml"
write_adr "$T" "implemented/feature/2026-01-02-env.md"
run_in "$T" status
RC_BASE=$R_RC
assert_eq "ENV 夹具：status exit 0" 0 "$RC_BASE"
assert_eq "ENV-1 [GO] 「环境：」行恰 1 行" 1 "$(printf '%s\n' "$R_OUT" | grep -c '^环境：')"
EL=$(env_line_of "$R_OUT")
assert_matches "ENV-3 [GO] 五项名/顺序/分隔符逐字" "$EL" "$ENV_RE"
assert_contains "ENV-4 [GO] 本机全绿：git ✓" "$EL" "git ✓"
assert_contains "ENV-4 [GO] 本机全绿：GNU date ✓" "$EL" "GNU date ✓"
assert_contains "ENV-4 [GO] 本机全绿：find -printf ✓" "$EL" "find -printf ✓"
assert_contains "ENV-4 [GO] 本机全绿：sed -i ✓" "$EL" "sed -i ✓"
assert_contains "ENV-4 [GO] 本机全绿：observe skill ✓" "$EL" "observe skill ✓"
NR_GOV=$(printf '%s\n' "$R_OUT" | grep -n '^治理级' | head -n1 | cut -d: -f1)
NR_ENV=$(printf '%s\n' "$R_OUT" | grep -n '^环境：' | head -n1 | cut -d: -f1)
if [ -n "$NR_GOV" ] && [ -n "$NR_ENV" ] && [ "$NR_ENV" -eq "$((NR_GOV + 1))" ]; then
  ok "ENV-2 [GO] 环境行紧随「治理级」行（治理级@$NR_GOV / 环境@$NR_ENV）"
else
  bad "ENV-2 [GO] 环境行位置错误（治理级@${NR_GOV:-?} / 环境@${NR_ENV:-?}，期望相邻下一行）"
fi

# ---------- ENV-6：不改变退出码（同一仓、同一判据面）----------
# 观察 skill 藏起来（HOME 覆盖）不会扰动治理判定 → 退出码必须与 ENV-1 相同
T2=$(new_case)
git_seed_repo "$T2"
run_in "$T2" init
printf 'level: 1\n' > "$T2/.meta/meta.yaml"
write_adr "$T2" "implemented/feature/2026-01-02-env2.md"
FAKEHOME="$T2/fake-home"; mkdir -p "$FAKEHOME"
run_in "$T2" HOME="$FAKEHOME" status
assert_eq "ENV-6 [GO] 环境缺项时退出码不变（与 ENV-1 同为 $RC_BASE）" "$RC_BASE" "$R_RC"

# ---------- ENV-5（可选 R 相）：✗ 分支可测（探测而非常量）----------
EL2=$(env_line_of "$R_OUT")
assert_matches "ENV-5 [GO] 缺项态行形状不变（仍五项）" "$EL2" "$ENV_RE"
assert_contains "ENV-5 [GO] 藏起 observe skill → observe skill ✗" "$EL2" "observe skill ✗"
assert_contains "ENV-5 [GO] 其余四项仍按真实环境判定（git ✓）" "$EL2" "git ✓"
assert_eq "ENV-5 [NOGO] 缺项时整行不得消失" 1 "$(printf '%s\n' "$R_OUT" | grep -c '^环境：')"
assert_no_crash "ENV-5 [NOGO] 缺项时不得崩溃" "$R_OUT"
# 反向控制：默认 HOME 下同一仓回到 ✓（排除残留/顺序导致的假 ✗）
run_in "$T2" status
assert_contains "ENV-5 [GO] 默认 HOME 下 observe skill 回到 ✓（反向控制）" "$(env_line_of "$R_OUT")" "observe skill ✓"

# ---------- ENV-7：只读（不执行门禁脚本、零写入）----------
T3=$(new_case)
git_seed_repo "$T3"
run_in "$T3" init
printf 'level: 1\n' > "$T3/.meta/meta.yaml"
write_adr "$T3" "implemented/feature/2026-01-02-env7.md"
printf '#!/usr/bin/env bash\ntouch "$(cd "$(dirname "$0")" && pwd)/CI_RAN"\nexit 0\n' \
  > "$T3/.meta/gates/ci-verify.sh"
printf '#!/usr/bin/env bash\ntouch "$(cd "$(dirname "$0")" && pwd)/ARCHIVE_RAN"\nexit 0\n' \
  > "$T3/$A6_REL"
PORC0=$(git_at "$T3" status --porcelain 2>/dev/null | md5sum | awk '{print $1}')
run_in "$T3" status
assert_missing "ENV-7 [NOGO] 探测不得执行 ci-verify（CI_RAN 不得出现）" "$T3/.meta/gates/CI_RAN"
assert_missing "ENV-7 [NOGO] 探测不得执行 archive-verify（ARCHIVE_RAN 不得出现）" "$T3/.meta/gates/ARCHIVE_RAN"
PORC1=$(git_at "$T3" status --porcelain 2>/dev/null | md5sum | awk '{print $1}')
assert_eq "ENV-7 [NOGO] 探测零写（git status 快照不变）" "$PORC0" "$PORC1"

# ---------- ENV-4b：违例态仍完整打印环境行（不因失败省略）----------
T4=$(new_case)
git_seed_repo "$T4"
run_in "$T4" init
printf 'level: 1\n' > "$T4/.meta/meta.yaml"
write_adr "$T4" "implemented/feature/badname.md"
run_in "$T4" status
assert_nonzero "ENV-4b 违例仓 status 非零（判据面不受环境行影响）" "$R_RC"
assert_matches "ENV-4b [GO] 违例态仍打印完整环境行" "$(env_line_of "$R_OUT")" "$ENV_RE"

finish
