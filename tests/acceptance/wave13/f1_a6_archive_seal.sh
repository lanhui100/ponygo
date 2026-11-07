#!/usr/bin/env bash
# ============================================================
# tests/acceptance/wave13/f1_a6_archive_seal.sh
# A6 —— `.meta/gates/archive-verify.sh`（归档 SHA-256 封印门）契约验收。
#
# 契约真源：.dev-team/contract-matrix-wave13.md §2（A6-1 ~ A6-24，冻结）
#           夹具 §1（FXW-ARCH-*）；关键词词表 §2.5。
# 零依赖：纯 bash + GNU 用户态；manifest 为纯文本。
# 反假绿：每类负样本都配正向对照（合法态 exit 0），并逐条断言关键词 + 被点名路径，
#         防止「一律 exit 1」或「恒 exit 0」被误判为合格。
# ============================================================
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

a6() { run_script "$1" "$A6_REL" "${@:2}"; }
# FXW-ARCH-OK：两个 Status: implemented 归档件 + 成功 seal
mk_arch_ok() { # <dir>
  stage_archived_adr "$1" "testing/2026-01-02-old-a.md"
  stage_archived_adr "$1" "testing/2026-01-02-old-b.md"
  a6 "$1" seal
}

# ============ 命令面（A6-1 / A6-3 / A6-4）============
T=$(new_case); gov_repo "$T" 2 || finish
assert_exists "前置取证：init 生成 A6" "$T/$A6_REL"
assert_exec "前置取证：A6 有执行位" "$T/$A6_REL"
mk_arch_ok "$T"
assert_eq "夹具：合法封印态 seal exit 0" 0 "$S_RC"

OUT_CHECK=$( cd "$T" && bash "$A6_REL" check 2>&1 ); RC_CHECK=$?
OUT_NOARG=$( cd "$T" && bash "$A6_REL" 2>&1 ); RC_NOARG=$?
assert_eq "A6-1 [GO] 无参调用 exit == check exit" "$RC_CHECK" "$RC_NOARG"
case "${RC_CHECK:-x}${RC_NOARG:-y}" in
  00|01|10|11) ok "A6-1 [GO] 两次调用的退出码均 ∈ {0,1}（非 127/崩溃壳）" ;;
  *) bad "A6-1 [GO] 退出码越界（check=$RC_CHECK / 无参=$RC_NOARG，期望 0/1）" ;;
esac
if [ "$OUT_CHECK" = "$OUT_NOARG" ] && [ -n "$OUT_CHECK" ]; then
  ok "A6-1 [GO] 无参调用与 check 输出逐字节一致（零旗标默认语义）"
else
  bad "A6-1 [GO] 无参调用与 check 输出不一致：$(diff <(printf '%s\n' "$OUT_CHECK") <(printf '%s\n' "$OUT_NOARG") | head -n3 | tr '\n' ' ')"
fi

MAN0=$(sha_of "$T/$MANIFEST_REL")
a6 "$T" bogus
assert_eq "A6-3 [GO] 未知子命令 bogus → exit 1" 1 "$S_RC"
assert_contains "A6-3 [GO] usage 含 check" "$S_OUT" "check"
assert_contains "A6-3 [GO] usage 含 seal" "$S_OUT" "seal"
a6 "$T" seal-me
assert_eq "A6-3 [GO] 未知子命令 seal-me → exit 1" 1 "$S_RC"
assert_eq "A6-3 [NOGO] 未知输入不得写 manifest" "$MAN0" "$(sha_of "$T/$MANIFEST_REL")"

a6 "$T" --seal
assert_eq "A6-4 [NOGO] --seal 不得被接受（exit 1）" 1 "$S_RC"
a6 "$T" --check
assert_eq "A6-4 [NOGO] --check 不得被接受（exit 1）" 1 "$S_RC"
a6 "$T" -c
assert_eq "A6-4 [NOGO] -c 不得被接受（exit 1）" 1 "$S_RC"
assert_eq "A6-4 [NOGO] 旗标形态输入不得写 manifest" "$MAN0" "$(sha_of "$T/$MANIFEST_REL")"

# A6-5 只读性
SNAP_BEFORE=$(md5_of "$T/$MANIFEST_REL")
PORC_BEFORE=$(git_at "$T" status --porcelain 2>/dev/null | md5sum | awk '{print $1}')
a6 "$T" check
assert_eq "A6-5 [GO] 合法封印 check exit 0" 0 "$S_RC"
assert_eq "A6-5 [GO] check 不修改 manifest" "$SNAP_BEFORE" "$(md5_of "$T/$MANIFEST_REL")"
assert_eq "A6-5 [NOGO] check 零写入（git status --porcelain 快照前后一致）" \
  "$PORC_BEFORE" "$(git_at "$T" status --porcelain 2>/dev/null | md5sum | awk '{print $1}')"

# ============ manifest 格式（A6-6 / A6-8 / A6-9）============
BADFMT=""
if [ -f "$T/$MANIFEST_REL" ]; then
while IFS= read -r line; do
  [ -n "$line" ] || continue
  printf '%s\n' "$line" | grep -Eq '^[0-9a-f]{64}  [^ ]+$' || BADFMT="$BADFMT [$line]"
done < "$T/$MANIFEST_REL"
else
  BADFMT="[manifest 缺失]"
fi
assert_eq "A6-6 [GO] 每行匹配 ^[0-9a-f]{64}  <repo-rel-path>$" "" "$BADFMT"
assert_eq "A6-6 [GO] manifest 条目数 == 归档 .md 数" 2 \
  "$(grep -c . "$T/$MANIFEST_REL" 2>/dev/null || printf '0')"

# 大写十六进制 → exit 1
TU=$(new_case); gov_repo "$TU" 2 || finish
stage_archived_adr "$TU" "testing/2026-01-02-upper.md"
mkdir -p "$TU/$ARCHIVED_REL"
printf '%s  %s\n' "$(sha_of "$TU/.agents/notes/archived/testing/2026-01-02-upper.md" | tr 'a-f' 'A-F')" \
  ".agents/notes/archived/testing/2026-01-02-upper.md" > "$TU/$MANIFEST_REL"
a6 "$TU" check
assert_eq "A6-6 [NOGO] 大写十六进制 manifest → exit 1" 1 "$S_RC"

# 越界路径（../..）→ exit 1 + 关键词 manifest
TP=$(new_case); gov_repo "$TP" 2 || finish
stage_archived_adr "$TP" "testing/2026-01-02-escape.md"
printf '%s  %s\n' "$(sha_of "$TP/.agents/notes/archived/testing/2026-01-02-escape.md")" \
  "../../etc/passwd" > "$TP/$MANIFEST_REL"
a6 "$TP" check
assert_eq "A6-6 [NOGO] 越界路径条目 → exit 1" 1 "$S_RC"
assert_contains "A6-6 [GO] 越界条目诊断含「manifest」" "$S_OUT" "manifest"

# A6-8 空行忽略
a6 "$T" check
assert_eq "A6-8 夹具：追加空行前 exit 0" 0 "$S_RC"
printf '\n\n' >> "$T/$MANIFEST_REL"
a6 "$T" check
assert_eq "A6-8 [GO] manifest 空行被忽略 → exit 0" 0 "$S_RC"

# A6-9 注释行 → 1 + manifest + 非法
printf '# comment\n' >> "$T/$MANIFEST_REL"
a6 "$T" check
assert_eq "A6-9 [NOGO] manifest 注释行 → exit 1" 1 "$S_RC"
assert_contains "A6-9 [GO] 诊断含「manifest」" "$S_OUT" "manifest"
assert_contains "A6-9 [GO] 诊断含「非法」" "$S_OUT" "非法"

# ============ check 判据（A6-10 ~ A6-18）============
# A6-10 合法封印 → 0
T=$(new_case); gov_repo "$T" 2 || finish
mk_arch_ok "$T"
a6 "$T" check
assert_eq "A6-10 [GO] 合法封印 → check exit 0" 0 "$S_RC"
assert_contains "A6-10 [GO] 输出含「归档封印」" "$S_OUT" "归档封印"
assert_matches "A6-10 [GO] 输出含通过/一致类结论词" "$S_OUT" '通过|一致'
assert_not_contains "A6-10 [NOGO] 合法态不得报「未封印」" "$S_OUT" "未封印"
assert_not_contains "A6-10 [NOGO] 合法态不得报「哈希不符」" "$S_OUT" "哈希不符"

# A6-11 篡改一字节 → 1
T=$(new_case); gov_repo "$T" 2 || finish
mk_arch_ok "$T"
TF="$T/.agents/notes/archived/testing/2026-01-02-old-a.md"
SZ=$(wc -c < "$TF")
tamper_one_byte "$TF"
assert_eq "A6-11 夹具：篡改后长度不变（只改一字节）" "$SZ" "$(wc -c < "$TF")"
a6 "$T" check
assert_eq "A6-11 [GO] 篡改一字节 → exit 1" 1 "$S_RC"
assert_contains "A6-11 [GO] 诊断含「哈希不符」" "$S_OUT" "哈希不符"
assert_contains "A6-11 [GO] 诊断点名被篡改路径" "$S_OUT" "2026-01-02-old-a.md"

# A6-12 未封印（manifest 缺条目）→ 1，且 check 不自动补写
T=$(new_case); gov_repo "$T" 2 || finish
mk_arch_ok "$T"
MANB=$(md5_of "$T/$MANIFEST_REL")
stage_archived_adr "$T" "testing/2026-01-02-unsealed.md"
a6 "$T" check
assert_eq "A6-12 [GO] 归档件未封印 → exit 1" 1 "$S_RC"
assert_contains "A6-12 [GO] 诊断含「未封印」" "$S_OUT" "未封印"
assert_contains "A6-12 [GO] 诊断点名未封印路径" "$S_OUT" "2026-01-02-unsealed.md"
assert_eq "A6-12 [NOGO] check 不得自动补写 manifest" "$MANB" "$(md5_of "$T/$MANIFEST_REL")"

# A6-13 孤儿条目（manifest 有、磁盘无）→ 1
T=$(new_case); gov_repo "$T" 2 || finish
mk_arch_ok "$T"
rm -f "$T/.agents/notes/archived/testing/2026-01-02-old-b.md"
a6 "$T" check
assert_eq "A6-13 [GO] 孤儿条目 → exit 1" 1 "$S_RC"
assert_contains "A6-13 [GO] 诊断含「孤儿」" "$S_OUT" "孤儿"
assert_contains "A6-13 [GO] 诊断点名孤儿路径" "$S_OUT" "2026-01-02-old-b.md"

# A6-14 重复条目 → 1
T=$(new_case); gov_repo "$T" 2 || finish
mk_arch_ok "$T"
DUP_LINE=$(grep -F '2026-01-02-old-a.md' "$T/$MANIFEST_REL" 2>/dev/null | head -n1)
printf '%s\n' "$DUP_LINE" >> "$T/$MANIFEST_REL"
a6 "$T" check
assert_eq "A6-14 [GO] 重复条目 → exit 1" 1 "$S_RC"
assert_contains "A6-14 [GO] 诊断含「重复」" "$S_OUT" "重复"
assert_contains "A6-14 [GO] 诊断点名重复路径" "$S_OUT" "2026-01-02-old-a.md"

# A6-15 无归档 → 0
T=$(new_case); gov_repo "$T" 2 || finish
rm -rf "$T/$ARCHIVED_REL"
a6 "$T" check
assert_eq "A6-15 [GO] 无归档目录 → exit 0" 0 "$S_RC"
assert_matches "A6-15 [GO] 输出含「无归档」或「0 条」" "$S_OUT" '无归档|0 条'
assert_no_crash "A6-15 [NOGO] 无归档时不得崩溃/报语法错" "$S_OUT"

# A6-16 空归档目录 → 0，且不创建 manifest
T=$(new_case); gov_repo "$T" 2 || finish
rm -rf "$T/$ARCHIVED_REL"; mkdir -p "$T/$ARCHIVED_REL"
a6 "$T" check
assert_eq "A6-16 [GO] 空归档目录 → exit 0" 0 "$S_RC"
assert_missing "A6-16 [NOGO] check 不得创建 manifest.sha256" "$T/$MANIFEST_REL"

# A6-17 README/AGENTS 排除（含任意深度）
T=$(new_case); gov_repo "$T" 2 || finish
mk_arch_ok "$T"
printf '# archived readme\n' > "$T/$ARCHIVED_REL/README.md"
printf '# archived agents\n' > "$T/$ARCHIVED_REL/AGENTS.md"
mkdir -p "$T/$ARCHIVED_REL/testing/deep"
printf '# deep readme\n' > "$T/$ARCHIVED_REL/testing/deep/README.md"
a6 "$T" check
assert_eq "A6-17 [GO] archived 下 README/AGENTS（含子目录）不参与判定 → exit 0" 0 "$S_RC"
assert_not_contains "A6-17 [NOGO] README.md 不得被报为未封印" "$S_OUT" "README.md"

# A6-18 check 不执行仓库脚本
T=$(new_case); gov_repo "$T" 2 || finish
mk_arch_ok "$T"
printf '#!/usr/bin/env bash\ntouch "$(cd "$(dirname "$0")" && pwd)/CI_RAN"\nexit 0\n' \
  > "$T/.meta/gates/ci-verify.sh"
a6 "$T" check
assert_missing "A6-18 [NOGO] check 不得执行 ci-verify（CI_RAN 不得出现）" "$T/.meta/gates/CI_RAN"

# ============ seal 判据（A6-2 / A6-19 ~ A6-24）============
# A6-2 / A6-19 正常追加
T=$(new_case); gov_repo "$T" 2 || finish
stage_archived_adr "$T" "testing/2026-01-02-seal-a.md"
N0=$(grep -c . "$T/$MANIFEST_REL" 2>/dev/null || printf '0'); N0=${N0:-0}
a6 "$T" seal
assert_eq "A6-19 [GO] seal 缺失 1 条 → exit 0" 0 "$S_RC"
assert_contains "A6 [GO] seal 分支同样打印「归档封印」" "$S_OUT" "归档封印"
N1=$(grep -c . "$T/$MANIFEST_REL" 2>/dev/null || printf '0'); N1=${N1:-0}
assert_eq "A6-19 [GO] manifest 行数恰 +1（$N0 → $N1）" "$((N0 + 1))" "$N1"
NEW=$(grep -F '2026-01-02-seal-a.md' "$T/$MANIFEST_REL" 2>/dev/null | head -n1)
assert_eq "A6-2/A6-19 [GO] 新行 hex == 该文件 sha256sum" \
  "$(sha_of "$T/.agents/notes/archived/testing/2026-01-02-seal-a.md")" \
  "$(printf '%s' "$NEW" | awk '{print $1}')"

# A6-7 append-only：旧内容是新内容的前缀
T=$(new_case); gov_repo "$T" 2 || finish
stage_archived_adr "$T" "testing/2026-01-02-prefix-a.md"
a6 "$T" seal
if [ -f "$T/$MANIFEST_REL" ]; then cp "$T/$MANIFEST_REL" "$SBASE/man.before"; else : > "$SBASE/man.before"; fi
assert_exists "A6-7 前置取证：首条 seal 后 manifest 已存在" "$T/$MANIFEST_REL"
LINES_B=$(grep -c . "$T/$MANIFEST_REL" 2>/dev/null || printf '0'); LINES_B=${LINES_B:-0}
stage_archived_adr "$T" "testing/2026-01-02-prefix-b.md"
a6 "$T" seal
assert_eq "A6-7 夹具：追加第二条 seal exit 0" 0 "$S_RC"
if [ -f "$T/$MANIFEST_REL" ] && head -n "$LINES_B" "$T/$MANIFEST_REL" 2>/dev/null | cmp -s - "$SBASE/man.before"; then
  ok "A6-7 [GO] seal 前内容 == seal 后前缀（逐字节，不重写既有行）"
else
  bad "A6-7 [GO] seal 重写了既有行（append-only 被破坏）"
fi

# A6-20 既有条目被改 → seal 拒绝 + 零写入
T=$(new_case); gov_repo "$T" 2 || finish
stage_archived_adr "$T" "testing/2026-01-02-append-only.md"
a6 "$T" seal
assert_eq "A6-20 夹具：首次 seal exit 0" 0 "$S_RC"
MANS=$(sha_of "$T/$MANIFEST_REL")
tamper_one_byte "$T/.agents/notes/archived/testing/2026-01-02-append-only.md"
a6 "$T" seal
assert_eq "A6-20 [GO] 既有条目被改 → seal exit 1" 1 "$S_RC"
assert_contains "A6-20 [GO] 诊断含「哈希不符」" "$S_OUT" "哈希不符"
assert_contains "A6-20 [GO] 诊断含「append-only」（逐字）" "$S_OUT" "append-only"
assert_eq "A6-20 [NOGO] 拒绝时不得写 manifest（不得把篡改洗白）" "$MANS" "$(sha_of "$T/$MANIFEST_REL")"

# A6-21 来源代理判据
T=$(new_case); gov_repo "$T" 2 || finish
stage_archived_adr "$T" "testing/2026-01-02-proposed.md" "proposed"
a6 "$T" seal
assert_eq "A6-21 [GO] Status: proposed → seal exit 1" 1 "$S_RC"
assert_contains "A6-21 [GO] 诊断含「Status」" "$S_OUT" "Status"
assert_contains "A6-21 [GO] 诊断含「implemented」" "$S_OUT" "implemented"
assert_contains "A6-21 [GO] 诊断点名该路径" "$S_OUT" "2026-01-02-proposed.md"
assert_missing "A6-21 [NOGO] 不得把 proposed 静默封印" "$T/$MANIFEST_REL"

# A6-22 孤儿不可由 seal 修复
T=$(new_case); gov_repo "$T" 2 || finish
mk_arch_ok "$T"
rm -f "$T/.agents/notes/archived/testing/2026-01-02-old-a.md"
a6 "$T" seal
assert_eq "A6-22 [GO] 孤儿态 seal → exit 1" 1 "$S_RC"
assert_contains "A6-22 [GO] 报孤儿条目" "$S_OUT" "孤儿"

# A6-23 幂等
T=$(new_case); gov_repo "$T" 2 || finish
mk_arch_ok "$T"
MANI=$(sha_of "$T/$MANIFEST_REL")
assert_exists "A6-23 前置取证：manifest 已存在（否则「不变」是空断言）" "$T/$MANIFEST_REL"
a6 "$T" seal
assert_eq "A6-23 [GO] 全一致态再 seal → exit 0" 0 "$S_RC"
assert_eq "A6-23 [GO] manifest 逐字节不变（幂等）" "$MANI" "$(sha_of "$T/$MANIFEST_REL")"
assert_matches "A6-23 [GO] 报「追加 0 条」类措辞" "$S_OUT" '追加 0 条|0 条'

# A6-24 原子性：无中间文件残留
T=$(new_case); gov_repo "$T" 2 || finish
stage_archived_adr "$T" "testing/2026-01-02-atomic.md"
a6 "$T" seal
assert_eq "A6-24 夹具：seal exit 0" 0 "$S_RC"
LEFT=$(find "$T/$ARCHIVED_REL" \( -name '*.tmp' -o -name '*.new' \) 2>/dev/null | head -n3 | tr '\n' ' ')
assert_eq "A6-24 [NOGO] 不得遗留 .tmp/.new 中间文件" "" "$LEFT"

finish
