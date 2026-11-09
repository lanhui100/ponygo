#!/usr/bin/env bash
# ============================================================
# tests/acceptance/wave13/f4_coverage_honesty.sh
# status / audit 的「判据覆盖诚实化」：1.10 未由本命令验证时必须如实声明，
# 结论行三态逐字、--json coverage 固定词表、不得把未验证洗成 PASS。
#
# 契约真源：.dev-team/contract-matrix-wave13.md §5（COV-1 ~ COV-J6，冻结）
#           + Lead 重裁 2026-11-07（level-range 随 lv：lv=1 → L0-L1，lv≥2 → L0-L2）。
# 零依赖：coverage token 用**逐字节子串**断言（契约已冻结词表与顺序）。
# 反假绿：缺 1.10 样本与含 1.10 样本**都**必须带「1.10 未由本命令验证」——
#         证明诚实化不是按样本结果编故事。
# ============================================================
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# coverage 机器面两态（契约收口/T4 落地后迁移 2026-11-09；**逐字取自实测**：只有
# `.meta/meta.yaml` 的 `level: 2`（不含 ai-surface）的实例跑 `bash ponygo status --json` →
# `"coverage":{"verified":["1.1-1.8"],"unverified":["1.10"],"skipped":["1.9b"],"reason":"readonly-no-repo-exec"}`）：
#   COV_TOKEN    = 1.9b **未判定**（未声明 / off / 值非法）态：verified 收窄为 ["1.1-1.8"]
#                  并显式列 skipped:["1.9b"]（SKIPPED ≠ PASS：机器面不得宣称没跑的子项已验证）
#   COV_TOKEN_19 = 1.9b **已判**（ai-surface: on）态：verified 保持 ["1.1-1.9"]，且**不带** skipped 键
# 本文件绝大多数夹具（gov_repo lv≥1）未声明 ai-surface → 用 COV_TOKEN；on 态由 COV-J1b 单独看守，
# 证明这是「两态可区分」，不是「一律降级」。
# 第三态（T7 收口后已并入 COV_TOKEN）：lv=0「纯 L0 长驻」——L1 判据不在判定域，
# 但机器面同样**不得宣称已验**：T7 后实测输出与 COV_TOKEN 逐字相同（verified ["1.1-1.8"]
# + skipped:["1.9b"]、无 on 态特权）。COV-J6 因此复用 COV_TOKEN，不再单列常量。
COV_TOKEN='"coverage":{"verified":["1.1-1.8"],"unverified":["1.10"],"skipped":["1.9b"],"reason":"readonly-no-repo-exec"}'
COV_TOKEN_19='"coverage":{"verified":["1.1-1.9"],"unverified":["1.10"],"reason":"readonly-no-repo-exec"}'
FORBIDDEN='机械判据全部 PASS'
# 2026-11-09 期望迁移（契约真源：.dev-team/wave-1-contract.md §C3；Lead 裁决：只迁期望值，
# assert_eq 全串精确相等不变、断言一条不删）。本文件 lv=1 夹具（gov_repo）**未声明 ai-surface**，
# 而 §C3 把判据 1.9 的「根 AGENTS.md 索引链」子项（1.9b）改为 fail-closed **仅当声明 ai-surface**：
# 未声明 → 该子项 SKIPPED，结论行据实把「判据 1.1–1.9 PASS」改写为
# 「判据 1.1–1.8 PASS；1.9b SKIPPED——…，不计入 PASS」（不得静默 PASS；同一契约由
# tests/run.sh 场景 s79 的 C3⑦/C3⑨/C3⑩ 看守）。已声明 ai-surface: on 的态（COV-1 的本仓副本）
# 仍为「1.1–1.9 PASS」——见 FROZEN_L2_BASE，不得顺手改掉正向影子。
FROZEN_L1='级自洽验证：通过（L0-L1 判据 1.1–1.8 PASS；1.9b SKIPPED——根 AGENTS.md 索引链未判定（未声明 ai-surface），不计入 PASS；1.10 未由本命令验证——由 A1/A4 门把关）'
FROZEN_L2_BASE='级自洽验证：通过（L0-L2 判据 1.1–1.9 PASS；1.10 未由本命令验证——由 A1/A4 门把关'
conc_of() { printf '%s\n' "$1" | grep '^级自洽验证：' ; }

# ---------- COV-1b：lv=1 态 1 结论行**逐字**（无 2.x 条件子句，可做全串精确断言）----------
T=$(new_case); gov_repo "$T" 1 || finish
write_adr "$T" "implemented/feature/2026-01-02-cov-l1.md"
run_in "$T" status
assert_eq "COV-1b status（lv=1，载体齐全）exit 0" 0 "$R_RC"
L=$(conc_of "$R_OUT")
assert_eq "COV-1b [GO] status 结论行逐字（L0-L1）" "$FROZEN_L1" "$L"
assert_eq "COV-1b [GO] 结论行恰 1 行" 1 "$(conc_of "$R_OUT" | grep -c '')"
run_in "$T" audit
assert_eq "COV-1b audit（lv=1）exit 0" 0 "$R_RC"
assert_eq "COV-1b [GO] audit 结论行与 status 逐字一致（同源）" "$FROZEN_L1" "$(conc_of "$R_OUT")"
assert_not_contains "COV-1b [NOGO] 不得出现「$FORBIDDEN」" "$R_OUT" "$FORBIDDEN"

# ---------- COV-1：lv=2 态 1 结论行（FXW-BASE = 本仓副本，L0-L2）----------
# 注：本仓 lv=2 且未声明 ai-surface → 既有条件子句「；2.6 SKIPPED——未声明 ai-surface，不计入 PASS」
# 会追加在冻结主体之后（该子句由既有回归断言 tests/run.sh 冻结，不得删除）。
# 因此这里断言：**冻结主体逐字为前缀**，且只允许既有条件子句后缀（若存在）。
T="$SBASE/copy.base"; mkdir -p "$T"
cp -a "$ROOT/." "$T/" 2>/dev/null || true
assert_exists "COV-1 前置取证：仓库副本含 .meta/meta.yaml" "$T/.meta/meta.yaml"
run_in "$T" status
assert_eq "COV-1 status（本仓副本 lv=2）exit 0" 0 "$R_RC"
L2=$(conc_of "$R_OUT")
assert_contains "COV-1 [GO] 结论行含冻结主体（L0-L2 判据 1.1–1.9 PASS；1.10 未由本命令验证——由 A1/A4 门把关）" \
  "$L2" "$FROZEN_L2_BASE"
case "$L2" in
  "$FROZEN_L2_BASE）"|"$FROZEN_L2_BASE；"*"）") ok "COV-1 [GO] 结论行 = 冻结主体 + 仅既有条件子句" ;;
  *) bad "COV-1 [GO] 结论行形状不合契约（实得 [$L2]）" ;;
esac
assert_not_contains "COV-1 [NOGO] 不得出现「$FORBIDDEN」" "$R_OUT" "$FORBIDDEN"
run_in "$T" audit
assert_eq "COV-1 audit（本仓副本）exit 0" 0 "$R_RC"
assert_contains "COV-1 [GO] audit 同态同主体" "$R_OUT" "$FROZEN_L2_BASE"
assert_not_contains "COV-1 [NOGO] audit 同样禁现「$FORBIDDEN」" "$R_OUT" "$FORBIDDEN"

# ---------- COV-2：无门禁载体态（结论行 + 独立行 + stderr WARN）----------
# 夹具口径（Lead 裁决 2026-11-07 收口）：**保留** A1/A4/A6 资产（它们在 UPGRADE_UNIVERSE 内，
# 删掉会产生骨架缺口 → exit 1，把 coverage 语义掩盖成「骨架不完整」）；只移除**载体**
# （本地层 .githooks/pre-commit、远端层 .github/workflows/**，并清掉 core.hooksPath）——
# 骨架仍完整，故契约 COV-2 的 exit 0 可达。载体语义 = 接线点（hook/CI），不是资产文件存在性。
T=$(new_case); gov_repo "$T" 1 || finish
write_adr "$T" "implemented/feature/2026-01-02-cov-nogate.md"
assert_exists "COV-2 前置取证：A1 资产仍在（骨架完整，不得删）" "$T/.meta/gates/adr-verify.sh"
assert_exists "COV-2 前置取证：A4 资产仍在（骨架完整，不得删）" "$T/.meta/gates/ci-verify.sh"
rm -f "$T/.githooks/pre-commit"
rm -rf "$T/.github"
git_at "$T" config --unset core.hooksPath >/dev/null 2>&1 || true
assert_missing "COV-2 前置取证：本地层载体已移除（.githooks/pre-commit）" "$T/.githooks/pre-commit"
assert_missing "COV-2 前置取证：远端层载体已移除（.github/）" "$T/.github"
assert_eq "COV-2 前置取证：core.hooksPath 未指向 hook" "" "$(git_at "$T" config core.hooksPath 2>/dev/null || true)"
run_in "$T" status
assert_eq "COV-2 [GO] status（骨架完整、无本地/远端载体）exit 0" 0 "$R_RC"
assert_contains "COV-2 前置取证：骨架确为完整态（不是靠缺口制造低级别）" "$R_OUT" "骨架完整"
run_split "$T" status
# 期望迁移（同上，§C3）：本夹具未声明 ai-surface → 1.9b SKIPPED 子句并入结论行；
# 「无门禁载体」尾句不变（coverage 诚实化语义未被改写）。
assert_eq "COV-2 [GO] 态 2 结论行逐字" \
  '级自洽验证：通过（L0-L1 判据 1.1–1.8 PASS；1.9b SKIPPED——根 AGENTS.md 索引链未判定（未声明 ai-surface），不计入 PASS；1.10 未由本命令验证——无门禁载体）' "$(conc_of "$R_OUT")"
assert_eq "COV-2 [GO] 独立行「1.10 无门禁载体（见接线）」恰 1 次" 1 \
  "$(printf '%s\n' "$R_OUT" | grep -c '^1\.10 无门禁载体（见接线）$')"
assert_matches "COV-2 [GO] stderr 出现 WARN" "$R_ERR" 'WARN|警告'
# 反向对照：载体存在时不得出现「无门禁载体」误报
T=$(new_case); gov_repo "$T" 1 || finish
write_adr "$T" "implemented/feature/2026-01-02-cov-withgate.md"
run_in "$T" status
assert_not_contains "COV-2 [NOGO] 有载体时不得写「无门禁载体」" "$R_OUT" "1.10 无门禁载体（见接线）"
assert_not_contains "COV-2 [NOGO] 有载体时结论行不得含「无门禁载体」" "$(conc_of "$R_OUT")" "无门禁载体"

# ---------- COV-3：态 3（1.1–1.9 有 FAIL）不回归 ----------
T=$(new_case); gov_repo "$T" 2 || finish
write_adr "$T" "implemented/feature/badname.md"     # 1.6 违例
run_in "$T" status
assert_nonzero "COV-3 [C] 违例仓 status 非零" "$R_RC"
assert_contains "COV-3 [C] 既有失败行逐字出现" "$R_OUT" "级自洽验证：未通过（声明"
assert_contains "COV-3 [C] FAIL 列表非空（FAIL 关键词）" "$R_OUT" "FAIL"
assert_not_contains "COV-3 [NOGO] 失败不得被新文案洗成「通过」" "$(conc_of "$R_OUT")" "级自洽验证：通过（"

# ---------- COV-4：lv=0 原样（逐字节），禁 1.1–1.9 / 1.10 措辞 ----------
# 夹具口径（可达成性取证）：契约 FXW-COV-L0 写「空仓 + .meta/meta.yaml」→ 骨架缺口会 exit 1，
# 与 COV-4 的「exit 0」不自洽；这里用 init 完整骨架 + level: 0（骨架无缺口 → exit 0），
# 仍满足「纯 L0 长驻」判定面。已上报 Lead/Protocol。
T=$(new_case)
git_seed_repo "$T"
run_in "$T" init
printf 'level: 0\n' > "$T/.meta/meta.yaml"
assert_eq "COV-4 夹具：init exit 0" 0 "$R_RC"
run_in "$T" status
assert_eq "COV-4 status（lv=0）exit 0" 0 "$R_RC"
assert_eq "COV-4 [GO] lv=0 结论行逐字节不变" '级自洽验证：通过（纯 L0 长驻：合法终态）' "$(conc_of "$R_OUT")"
assert_not_contains "COV-4 [NOGO] lv=0 不得出现 1.1–1.9 措辞" "$(conc_of "$R_OUT")" "1.1–1.9"
assert_not_contains "COV-4 [NOGO] lv=0 不得出现 1.10 措辞" "$(conc_of "$R_OUT")" "1.10"

# ---------- COV-5：缺 1.10 的 ADR —— 不得洗成 PASS ----------
T=$(new_case); gov_repo "$T" 2 || finish
write_adr_missing_1_10 "$T" "implemented/feature/2026-01-02-no-alt.md"
if grep -qE '^## Alternatives considered' "$T/.agents/notes/implemented/feature/2026-01-02-no-alt.md"; then
  bad "COV-5 前置取证：夹具不应含 ## Alternatives considered"
else
  ok "COV-5 前置取证：夹具确缺 1.10 备选节（其余骨架合法）"
fi
run_in "$T" status
assert_eq "COV-5 status（缺 1.10）exit 0（只读命令不判 1.10）" 0 "$R_RC"
assert_not_contains "COV-5 [NOGO] 不得出现「$FORBIDDEN」" "$R_OUT" "$FORBIDDEN"
assert_contains "COV-5 [GO] 结论行声明 1.10 未验证" "$(conc_of "$R_OUT")" "1.10 未由本命令验证"
run_in "$T" audit
assert_not_contains "COV-5 [NOGO] audit 不得出现「$FORBIDDEN」" "$R_OUT" "$FORBIDDEN"
assert_contains "COV-5 [GO] audit 结论行声明 1.10 未验证" "$(conc_of "$R_OUT")" "1.10 未由本命令验证"
# 反向控制：含 1.10 的合法 ADR 同样标注未验证（诚实化不随样本结果变化）
T=$(new_case); gov_repo "$T" 2 || finish
write_adr "$T" "implemented/feature/2026-01-02-with-alt.md"
run_in "$T" status
assert_contains "COV-5 [GO] 合法样本同样标注 1.10 未验证（非样本驱动）" \
  "$(conc_of "$R_OUT")" "1.10 未由本命令验证"

# ---------- COV-6：status 与 audit 同源（同仓同态）----------
T=$(new_case); gov_repo "$T" 1 || finish
write_adr_missing_1_10 "$T" "implemented/feature/2026-01-02-same.md"
run_in "$T" status
ST_CONC=$(conc_of "$R_OUT")
ST_RC=$R_RC
run_in "$T" audit
AU_CONC=$(conc_of "$R_OUT")
assert_eq "COV-6 [GO] status/audit 结论行同态（逐字节一致）" "$ST_CONC" "$AU_CONC"

# ---------- COV-7：退出码不因 coverage 改变 ----------
assert_eq "COV-7 [GO] status 退出码 0（与 Wave12 同场景相同，无第 4 种退出码）" 0 "$ST_RC"
run_in "$T" audit
case "$R_RC" in
  0|1|3) ok "COV-7 [GO] audit 退出码 ∈ {0,1,3}（实得 $R_RC）" ;;
  *) bad "COV-7 [NOGO] audit 退出码越界（实得 $R_RC）" ;;
esac

# ---------- COV-J1 / COV-J3 / COV-J4 / COV-J5：status --json ----------
T=$(new_case); gov_repo "$T" 2 || finish
write_adr "$T" "implemented/feature/2026-01-02-json.md"
run_split "$T" status --json
assert_eq "COV-J 夹具：status --json exit 0" 0 "$R_RC"
assert_eq "COV-J5 [C] status --json stdout 恰 1 行" 1 "$(printf '%s\n' "$R_OUT" | grep -c '')"
assert_matches "COV-J5 [C] status --json 是单行 JSON" "$R_OUT" '^\{.*\}$'
assert_contains "COV-J1 [GO] status coverage token 逐字节（1 次）" "$R_OUT" "$COV_TOKEN"
assert_eq "COV-J1 [GO] coverage token 出现次数 = 1" 1 \
  "$(printf '%s' "$R_OUT" | grep -oF "$COV_TOKEN" | wc -l | tr -d ' ')"
assert_contains "COV-J3 [GO] schema=ponygo.status/1（不得升 /2）" "$R_OUT" '"schema":"ponygo.status/1"'
assert_not_contains "COV-J3 [NOGO] 不得出现 ponygo.status/2" "$R_OUT" '"ponygo.status/2"'
for k in level skeleton gates ladder exit; do
  assert_contains "COV-J4 [C] status --json 既有键不丢：$k" "$R_OUT" "\"$k\":"
done
assert_not_contains "COV-J1 [NOGO] verified 数组不得超过 1.1-1.9（未验证不得计为已验证）" \
  "$R_OUT" '"verified":["1.1-1.9","1.10"]'

# ---------- COV-J1b：ai-surface: on 态 coverage **不降级**（两态可区分，不是「一律降级」）----------
# 口径 B（Lead 裁决 2026-11-09）：只有 1.9b 未判定时才收窄 verified 并显式列 skipped；
# 1.9b 已判（ai-surface: on）→ verified 保持 ["1.1-1.9"]，且**无** skipped 键（不留空键）。
T=$(new_case); gov_repo "$T" 2 || finish
write_adr "$T" "implemented/feature/2026-01-02-json-on.md"
printf 'ai-surface: on\n' >> "$T/.meta/meta.yaml"
assert_file_has "COV-J1b 前置取证：已声明 ai-surface: on（否则测到的不是 on 态）" "$T/.meta/meta.yaml" "ai-surface: on"
run_split "$T" status --json
assert_eq "COV-J1b 夹具：on 态 status --json exit 0（1.9b 已判且 PASS）" 0 "$R_RC"
assert_contains "COV-J1b [GO] on 态 coverage 保持 verified:[\"1.1-1.9\"]（逐字节）" "$R_OUT" "$COV_TOKEN_19"
assert_eq "COV-J1b [GO] on 态 coverage token 出现次数 = 1" 1 \
  "$(printf '%s' "$R_OUT" | grep -oF "$COV_TOKEN_19" | wc -l | tr -d ' ')"
assert_not_contains "COV-J1b [NOGO] on 态不得带 skipped 键（不留空键 / 不一律降级）" "$R_OUT" '"skipped"'
assert_not_contains "COV-J1b [NOGO] on 态 verified 不得收窄为 1.1-1.8" "$R_OUT" '"verified":["1.1-1.8"]'

# ---------- COV-J2 / COV-J3 / COV-J4：audit --json ----------
T=$(new_case); gov_repo "$T" 2 || finish
write_adr "$T" "implemented/feature/2026-01-02-json2.md"
run_split "$T" audit --json
assert_contains "COV-J2 [GO] audit coverage token 逐字节" "$R_OUT" "$COV_TOKEN"
assert_contains "COV-J3 [GO] schema=ponygo.audit/1" "$R_OUT" '"schema":"ponygo.audit/1"'
assert_not_contains "COV-J3 [NOGO] 不得出现 ponygo.audit/2" "$R_OUT" '"ponygo.audit/2"'
for k in tier hits total level ladder gates gaps exit; do
  assert_contains "COV-J4 [C] audit --json 既有键不丢：$k" "$R_OUT" "\"$k\":"
done
assert_contains "COV-J4 [GO] audit --json exit 字段 == 真实退出码" "$R_OUT" "\"exit\":$R_RC"

# ---------- COV-J6：lv=0 的 JSON 也带 coverage ----------
# 迁移说明（2026-11-09，T7 收口）：lv=0 走「纯 L0 长驻」分支，1.9b 不在判定域——机器面
# **不得**把没跑的子项报成已验证。T7 后实测输出与 COV_TOKEN 逐字相同
# （verified:["1.1-1.8"] + skipped:["1.9b"]），故本断言复用 COV_TOKEN（与 COV-J1/J2 同一口径），
# 已是「未判 → 收窄 + skipped」的保守态；不再存在「lv=0 报 verified:["1.1-1.9"]」的观察项。
T=$(new_case)
git_seed_repo "$T"
run_in "$T" init
printf 'level: 0\n' > "$T/.meta/meta.yaml"
run_split "$T" status --json
assert_eq "COV-J6 夹具：lv=0 status --json exit 0" 0 "$R_RC"
assert_contains "COV-J6 [GO] lv=0 JSON 同样带 coverage 固定 token" "$R_OUT" "$COV_TOKEN"

finish
