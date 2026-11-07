#!/usr/bin/env bash
# ============================================================
# tests/acceptance/wave13/f3_wiring.sh
# A6/A7 的**接线**验收：init/repair 落盘与执行位、双写一致、A1 调 A6 check、
# A4 三段门 [1/3][2/3][3/3]、只读命令不执行门禁脚本。
#
# 契约真源：.dev-team/contract-matrix-wave13.md §3.1（W-1 ~ W-11）+ §4（RO-1/RO-2）
#           + Lead 裁决 2026-11-07（W-8 upgrade 只报缺口；A4 缺件 fail-closed）。
# 反假绿：既断言「生成/可执行/双写一致」，也断言「真的会拦」（负样本非零）；
#         两者缺一即为假接线。
# ============================================================
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# ============ W-1：A1 调用 A6 check（归档未封印 → 拒绝；顺序 ADR 段在前）============
T=$(new_case); gov_repo "$T" 2 || finish
write_adr "$T" "implemented/feature/2026-01-02-staged.md"
stage_archived_adr "$T" "testing/2026-01-02-unsealed.md"
git_at "$T" add -A >/dev/null 2>&1
run_script "$T" .meta/gates/adr-verify.sh
assert_eq "W-1 [GO] 归档未封印 → A1 exit 1" 1 "$S_RC"
assert_contains "W-1 [GO] 输出含「归档封印」段" "$S_OUT" "归档封印"
assert_contains "W-1 [GO] 输出含「未封印」" "$S_OUT" "未封印"
assert_contains "W-1 [GO] ADR 格式门信息仍出现（未被归档段挤掉）" "$S_OUT" "adr-verify"
NR_ADR=$(printf '%s\n' "$S_OUT" | grep -n 'adr-verify' | head -n1 | cut -d: -f1)
NR_ARCH=$(printf '%s\n' "$S_OUT" | grep -n '归档封印' | head -n1 | cut -d: -f1)
if [ -n "$NR_ADR" ] && [ -n "$NR_ARCH" ] && [ "$NR_ADR" -lt "$NR_ARCH" ]; then
  ok "W-1 [GO] 顺序正确：ADR 段在前（$NR_ADR）→ 归档段在后（$NR_ARCH）"
else
  bad "W-1 [GO] 顺序错误：ADR 段($NR_ADR) 应先于 归档段($NR_ARCH)"
fi
# 正向对照：seal 之后同一暂存态 → A1 放行（证明拒绝来自封印，不是「一律拒绝」）
run_script "$T" "$A6_REL" seal
assert_eq "W-1 夹具：seal exit 0" 0 "$S_RC"
run_script "$T" .meta/gates/adr-verify.sh
assert_eq "W-1 [GO] seal 之后 A1 exit 0（正向控制）" 0 "$S_RC"
# 链路末段：pre-commit 真跑 → 未封印时提交被拒
T=$(new_case); gov_repo "$T" 2 || finish
write_adr "$T" "implemented/feature/2026-01-02-commit.md"
stage_archived_adr "$T" "testing/2026-01-02-commit-unsealed.md"
git_at "$T" add -A >/dev/null 2>&1
git_commit "$T" "must be rejected"
assert_nonzero "W-1 [GO] 未封印 → git commit 被 pre-commit 拒绝" "$C_RC"
run_script "$T" "$A6_REL" seal
git_at "$T" add -A >/dev/null 2>&1
git_commit "$T" "legal after seal"
assert_eq "W-1 [GO] seal 后同一提交成功（正向控制）" 0 "$C_RC"

# ============ W-2：A1 不回归（合法归档态行为同 Wave12）============
T=$(new_case); gov_repo "$T" 2 || finish
write_adr "$T" "implemented/feature/2026-01-02-w2.md"
stage_archived_adr "$T" "testing/2026-01-02-w2-old.md"
run_script "$T" "$A6_REL" seal
git_at "$T" add -A >/dev/null 2>&1
run_script "$T" .meta/gates/adr-verify.sh
assert_eq "W-2 [C] 合法归档 + 合法 ADR → A1 exit 0" 0 "$S_RC"
assert_contains "W-2 [C] 原有「通过：N 条 ADR 经 … 校验」行仍在" "$S_OUT" "条 ADR"
assert_contains "W-2 [C] 原有「通过」结论词仍在" "$S_OUT" "通过"

# ============ W-3：A1 缺 A6 时优雅回退 ============
T=$(new_case); gov_repo "$T" 2 || finish
write_adr "$T" "implemented/feature/2026-01-02-w3.md"
rm -f "$T/$A6_REL"
assert_missing "W-3 夹具：A6 已删除" "$T/$A6_REL"
git_at "$T" add -A >/dev/null 2>&1
run_script "$T" .meta/gates/adr-verify.sh
assert_eq "W-3 [GO] 缺 A6 → A1 exit 0（静默跳过归档检查）" 0 "$S_RC"
assert_not_contains "W-3 [NOGO] 缺 A6 时不得出现「归档封印」段" "$S_OUT" "归档封印"
assert_no_crash "W-3 [NOGO] 缺 A6 时不得崩溃" "$S_OUT"

# ============ W-4 / W-5 / W-6：A4 三段门 ============
T=$(new_case); gov_repo "$T" 2 || finish
write_adr "$T" "implemented/feature/2026-01-02-ci-ok.md"
run_script_split "$T" .meta/gates/ci-verify.sh
assert_eq "W-4 [GO] A4 健康仓 exit 0" 0 "$S_RC"
assert_eq "W-4 [GO] 段头 == [1/3] 恰 1 次" 1 "$(printf '%s\n' "$S_OUT" | grep -c '^== \[1/3\] ')"
assert_eq "W-4 [GO] 段头 == [2/3] 恰 1 次" 1 "$(printf '%s\n' "$S_OUT" | grep -c '^== \[2/3\] ')"
assert_eq "W-4 [GO] 段头 == [3/3] 恰 1 次" 1 "$(printf '%s\n' "$S_OUT" | grep -c '^== \[3/3\] ')"
assert_eq "W-4 [GO] 三段总数 = 3" 3 "$(printf '%s\n' "$S_OUT" | grep -cE '^== \[[123]/3\] ')"
assert_not_contains "W-4 [NOGO] 不得残留旧两段编号 [1/2]" "$S_OUT" "[1/2]"
assert_not_contains "W-4 [NOGO] 不得残留旧两段编号 [2/2]" "$S_OUT" "[2/2]"
assert_not_contains "W-6 [NOGO] 运行输出不得残留「两道」旧措辞" "$S_OUT" "两道"
assert_contains "W-5 [GO] 第 3 段覆盖 A6（archive-verify）" "$S_OUT" "archive-verify.sh"

# W-5：归档被篡改 → A4 非零，且 FAIL 归属第 3 段
T=$(new_case); gov_repo "$T" 2 || finish
write_adr "$T" "implemented/feature/2026-01-02-ci-bad.md"
stage_archived_adr "$T" "testing/2026-01-02-ci-tamper.md"
run_script "$T" "$A6_REL" seal
assert_eq "W-5 夹具：封印 exit 0" 0 "$S_RC"
run_script "$T" .meta/gates/ci-verify.sh
assert_eq "W-5 夹具：封印态 A4 exit 0" 0 "$S_RC"
tamper_one_byte "$T/.agents/notes/archived/testing/2026-01-02-ci-tamper.md"
run_script_split "$T" .meta/gates/ci-verify.sh
assert_eq "W-5 [GO] 归档篡改 → A4 exit 1" 1 "$S_RC"
assert_contains "W-5 [GO] stderr 含 ci-verify: FAIL" "$S_ERR" "ci-verify: FAIL"
NR3=$(printf '%s\n' "$S_OUT" | grep -n '^== \[3/3\] ' | head -n1 | cut -d: -f1)
NRF=$(printf '%s\n' "$S_OUT" "$S_ERR" | grep -n 'ci-verify: FAIL' | head -n1 | cut -d: -f1)
if [ -n "$NR3" ] && [ -n "$NRF" ] && [ "$NRF" -gt "$NR3" ]; then
  ok "W-5 [GO] FAIL 归属第 3 段之后（段3@$NR3 < FAIL@$NRF）"
else
  bad "W-5 [GO] FAIL 未归属第 3 段（段3@${NR3:-?} / FAIL@${NRF:-?}）"
fi

# W-6b（revision+1）：A6 或 A7 缺席 → 第 3 段 fail-closed（exit 1），段头仍恒为 [3/3]
for miss in "$A6_REL" "$A7_REL"; do
  T=$(new_case); gov_repo "$T" 2 || finish
  write_adr "$T" "implemented/feature/2026-01-02-no-asset.md"
  rm -f "$T/$miss"
  assert_missing "W-6b 夹具：已删除 $miss" "$T/$miss"
  run_script "$T" .meta/gates/ci-verify.sh
  assert_eq "W-6b [GO] 缺 $miss → A4 exit 1（fail-closed，不静默跳过）" 1 "$S_RC"
  assert_eq "W-6b [GO] 缺 $miss → 段头仍为 [3/3]（不降级 [1/2]）" 1 \
    "$(printf '%s\n' "$S_OUT" | grep -c '^== \[3/3\] ')"
  assert_not_contains "W-6b [NOGO] 缺 $miss 时不得降级为两段编号" "$S_OUT" "[1/2]"
done

# ============ W-7：init 落盘 A6/A7（非空 + 执行位）+ upgrade 报零缺口（十五文件口径）============
T=$(new_case)
git_seed_repo "$T"
run_in "$T" init
assert_eq "W-7 init（git 仓）exit 0" 0 "$R_RC"
for a in "$A6_REL" "$A7_REL"; do
  assert_exists "W-7 [GO] init 生成 $a" "$T/$a"
  if [ -s "$T/$a" ]; then ok "W-7 [GO] $a 非空"; else bad "W-7 [GO] $a 为空文件"; fi
  assert_exec "W-7 [GO] $a 有执行位（非可执行 = git 静默忽略门禁）" "$T/$a"
done
run_in "$T" upgrade
assert_eq "W-7 upgrade（齐备仓）exit 0" 0 "$R_RC"
assert_matches "W-7 [GO] upgrade 报零缺口/零漂移" "$R_OUT" '零缺口|零漂移'
assert_matches "W-7 [GO] 宇宙口径为十五文件（13 → 15）" "$R_OUT" '十五|15 文件|15个文件' 
# W-11 init 幂等：再 init 零写
PORC_BEFORE=$(git_at "$T" status --porcelain 2>/dev/null)
run_in "$T" init
assert_eq "W-11 [C] 重复 init exit 0" 0 "$R_RC"
PORC_AFTER=$(git_at "$T" status --porcelain 2>/dev/null)
assert_eq "W-11 [NOGO] 重复 init 零写（git status 前后一致）" "$PORC_BEFORE" "$PORC_AFTER"

# ============ W-8：缺口口径同步 15（upgrade 只报、repair 才写）============
T=$(new_case); gov_repo "$T" 2 || finish
rm -f "$T/$A6_REL" "$T/$A7_REL"
run_in "$T" upgrade
assert_eq "W-8 upgrade（A6/A7 缺口）exit 0" 0 "$R_RC"
assert_contains "W-8 [GO] 缺口行含 A6 路径" "$R_OUT" ".meta/gates/archive-verify.sh"
assert_contains "W-8 [GO] 缺口行含 A7 路径" "$R_OUT" ".meta/gates/archive-verify.spec.sh"
assert_missing "W-8 [NOGO] upgrade 只报缺口、不写盘（A6 仍缺）" "$T/$A6_REL"
PORC_UPG=$(git_at "$T" status --porcelain 2>/dev/null | md5sum | awk '{print $1}')
run_in "$T" upgrade
assert_eq "W-8 [NOGO] upgrade 前后仓库零写入（git status 快照不变）" "$PORC_UPG" \
  "$(git_at "$T" status --porcelain 2>/dev/null | md5sum | awk '{print $1}')"
run_in "$T" init --repair-skeleton
assert_eq "W-8 夹具：repair exit 0" 0 "$R_RC"
assert_exec "W-8 [GO] repair 补齐后 A6 可执行" "$T/$A6_REL"
assert_exec "W-8 [GO] repair 补齐后 A7 可执行" "$T/$A7_REL"
run_in "$T" upgrade
assert_matches "W-8 [GO] 补齐后 upgrade 报零缺口/零漂移" "$R_OUT" '零缺口|零漂移' 

# ============ W-9：--repair-skeleton 同口径（按 15 文件补）============
T=$(new_case)
git_seed_repo "$T"
run_in "$T" init
assert_eq "W-9 夹具：init exit 0" 0 "$R_RC"
rm -f "$T/$A6_REL" "$T/$A7_REL" "$T/.agents/notes/README.md"
run_in "$T" init --repair-skeleton
assert_eq "W-9 [GO] repair（缺口态）exit 0" 0 "$R_RC"
assert_exec "W-9 [GO] repair 补回 A6（可执行）" "$T/$A6_REL"
assert_exec "W-9 [GO] repair 补回 A7（可执行）" "$T/$A7_REL"
assert_exists "W-9 [GO] repair 同口径补回骨架文件" "$T/.agents/notes/README.md"

# ============ W-10：双写逐字节一致（仓库模板 vs 生成物）============
for a in "$A6_REL" "$A7_REL"; do
  if [ -f "$ROOT/$a" ] && [ -f "$T/$a" ]; then
    if diff <(tr -d '\r' < "$T/$a") <(tr -d '\r' < "$ROOT/$a") >/dev/null 2>&1; then
      ok "W-10 [GO] 生成 $a 与仓库模板 EOL 归一后逐字节一致（双写无漂移）"
    else
      bad "W-10 [GO] 生成 $a 与仓库模板不一致（双写漂移）"
    fi
  else
    bad "W-10 [GO] 双写比对缺件（模板或生成物缺失：$a）"
  fi
done

# ============ RO-1：只读命令不执行门禁脚本 ============
T=$(new_case); gov_repo "$T" 2 || finish
write_adr "$T" "implemented/feature/2026-01-02-ro.md"
printf '#!/usr/bin/env bash\ntouch "$(cd "$(dirname "$0")" && pwd)/CI_RAN"\nexit 0\n' \
  > "$T/.meta/gates/ci-verify.sh"
printf '#!/usr/bin/env bash\ntouch "$(cd "$(dirname "$0")" && pwd)/ARCHIVE_RAN"\nexit 0\n' \
  > "$T/$A6_REL"
run_in "$T" status
assert_eq "RO-1 status exit 0（只读）" 0 "$R_RC"
assert_missing "RO-1 [NOGO] status 不得执行 ci-verify" "$T/.meta/gates/CI_RAN"
assert_missing "RO-1 [NOGO] status 不得执行 archive-verify" "$T/.meta/gates/ARCHIVE_RAN"
run_in "$T" audit
assert_missing "RO-1 [NOGO] audit 默认不得执行 ci-verify" "$T/.meta/gates/CI_RAN"
assert_missing "RO-1 [NOGO] audit 默认不得执行 archive-verify" "$T/.meta/gates/ARCHIVE_RAN"

# ============ RO-2：audit --run-specs 仍显式执行 spec（含 A7）============
T=$(new_case); gov_repo "$T" 2 || finish
write_adr "$T" "implemented/feature/2026-01-02-ro2.md"
run_in "$T" audit --run-specs
assert_eq "RO-2 [GO] audit --run-specs exit 0（A2/A7 均自检通过）" 0 "$R_RC"
assert_contains "RO-2 [GO] 2.3 spec 自检行出现" "$R_OUT" "2.3 spec 自检"
assert_contains "RO-2 [GO] A7 被真实执行（点名 archive-verify.spec.sh）" "$R_OUT" "archive-verify.spec.sh"
assert_not_contains "RO-2 [NOGO] A7 不得在 --run-specs 下被 SKIPPED" \
  "$R_OUT" "skipped] 2.3 spec 自检：.meta/gates/archive-verify.spec.sh"

# ============ W-DEL：删除归档件绕过（L3 BLOCKING 回归，task-10）============
# 缺陷形态：A1 以「无暂存 ADR 变更（exit 0）」提前返回，而 `git rm` 归档件属于 D（删除）态、
# 被 `--diff-filter=ACMR` 过滤掉 → 删掉已封印的归档件可以静默提交，封印形同虚设。
# 判定：封印后 `git rm` 归档件 → A1 exit 1 且提交被拒；恢复后放行（正向控制）。
T=$(new_case); gov_repo "$T" 2 || finish
stage_archived_adr "$T" "testing/2026-01-02-del.md"
write_adr "$T" "implemented/feature/2026-01-02-delbase.md"
run_script "$T" "$A6_REL" seal
assert_eq "W-DEL 夹具：归档封印 exit 0" 0 "$S_RC"
git_at "$T" add -A >/dev/null 2>&1
git_commit "$T" "base with sealed archive"
assert_eq "W-DEL 夹具：基线提交成功（封印件已入库）" 0 "$C_RC"
# 删除已封印的归档件（只删归档，不动 ADR）
git_at "$T" rm -q .agents/notes/archived/testing/2026-01-02-del.md >/dev/null 2>&1
assert_missing "W-DEL 取证：归档件已从工作区删除" "$T/.agents/notes/archived/testing/2026-01-02-del.md"
run_script "$T" .meta/gates/adr-verify.sh
assert_eq "W-DEL [GO] 删除已封印归档件 → A1 exit 1" 1 "$S_RC"
if printf '%s\n' "$S_OUT" | grep -qE '归档封印|孤儿|未封印'; then
  ok "W-DEL [GO] A1 诊断指向归档封印面（孤儿/未封印）"
else
  bad "W-DEL [GO] A1 拒绝但诊断未指向归档封印面（实得：$(printf '%s' "$S_OUT" | head -n2 | tr '\n' ' ')）"
fi
git_commit "$T" "must be rejected: delete sealed archive"
assert_nonzero "W-DEL [GO] 删除已封印归档件的提交被 pre-commit 拒绝" "$C_RC"
# 正向控制：恢复归档件 → A1 放行、提交成功
git_at "$T" reset -q >/dev/null 2>&1
git_at "$T" checkout -- .agents/notes/archived/testing/2026-01-02-del.md >/dev/null 2>&1
assert_exists "W-DEL 取证：归档件已恢复" "$T/.agents/notes/archived/testing/2026-01-02-del.md"
run_script "$T" .meta/gates/adr-verify.sh
assert_eq "W-DEL [GO] 恢复归档件后 A1 exit 0（反向控制）" 0 "$S_RC"
# 恢复后要有**真实变更**才提交（空提交 rc=1 反映的「无变更」而非门禁拒绝）
write_adr "$T" "implemented/feature/2026-01-02-delbase2.md"
git_at "$T" add -A >/dev/null 2>&1
assert_nonzero "W-DEL 取证：恢复后确有暂存变更可提交（防空提交假红）" \
  "$( [ -n "$(git_at "$T" diff --cached --name-only 2>/dev/null)" ] && printf '1' || printf '0' )"
git_commit "$T" "restored archive + new adr"
assert_eq "W-DEL [GO] 恢复后提交成功（证明拒绝来自删除动作）" 0 "$C_RC"

# ============ W-DRY：init --dry-run 计划行数（L3 ADVISORY 回归，task-10）============
# 缺陷形态：dry-run 只列 A1/A2/A4（3 行），A6/A7 不在计划里 → 用户看不到新增门禁将被生成，
# 「计划与实际」不一致（真跑 init 其实会生成 5 个门禁资产）。
# 判定：fresh 目录 `ponygo init --dry-run` 的「将生成 .meta/gates/」行恰 5 行（A1/A2/A4/A6/A7）。
T=$(new_case)
run_in "$T" init --dry-run
assert_eq "W-DRY init --dry-run（fresh 目录）exit 0" 0 "$R_RC"
NRY=$(printf '%s\n' "$R_OUT" | grep -c '将生成 \.meta/gates/')
assert_eq "W-DRY [GO] 「将生成 .meta/gates/」计划行恰 5 行（A1/A2/A4/A6/A7）" 5 "$NRY"
for a in adr-verify.sh adr-verify.spec.sh ci-verify.sh archive-verify.sh archive-verify.spec.sh; do
  assert_contains "W-DRY [GO] 计划含 .meta/gates/$a" "$R_OUT" ".meta/gates/$a"
done
assert_missing "W-DRY [NOGO] --dry-run 零落盘（不得创建 .meta/）" "$T/.meta"

finish
