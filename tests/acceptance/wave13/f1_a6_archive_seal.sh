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

# 平台能力探测：Windows Git Bash 默认无 symlink 权限；无能力时 symlink 专项只能 SKIP，
# 不能把「夹具造不出来」误报成门禁失败（Linux/macOS 仍完整跑）。
W13_SYMLINK_OK=0
_probe=$(mktemp -d "$SBASE/symlink-probe.XXXXXX")
mkdir -p "$_probe/target"
ln -s target "$_probe/link" 2>/dev/null || true
[ -L "$_probe/link" ] && W13_SYMLINK_OK=1
rm -rf "$_probe"

# ============ A6-SYM：符号链接绕过（L3 BLOCKING 回归，task-10）============
# 缺陷形态：archived/ 下放 `*.md` 符号链接 → 既不被收进集合 B（`-type f` 跳过 symlink），
# 也不报错 → check/seal 双双 exit 0，等于给「归档件」开了一条不受封印约束的旁路。
# 判定：存在归档案符号链接时 check 与 seal 均 exit 1 且文案含「符号链接」；移除后合法件仍 0。
if [ "$W13_SYMLINK_OK" -eq 1 ]; then
T=$(new_case); gov_repo "$T" 2 || finish
stage_archived_adr "$T" "testing/2026-01-02-sym-legit.md"
a6 "$T" seal
assert_eq "A6-SYM 夹具：合法件 seal exit 0" 0 "$S_RC"
a6 "$T" check
assert_eq "A6-SYM 对照：仅合法件时 check exit 0" 0 "$S_RC"
# 相对 symlink（指向归档内的合法件）+ 绝对 symlink（指向仓外文件）
ln -s "2026-01-02-sym-legit.md" "$T/$ARCHIVED_REL/testing/2026-01-02-sym-rel.md"
ln -s "/etc/hostname" "$T/$ARCHIVED_REL/testing/2026-01-02-sym-abs.md"
assert_exists "A6-SYM 取证：symlink 已放入归档目录" "$T/$ARCHIVED_REL/testing/2026-01-02-sym-rel.md"
MAN_SYM=$(sha_of "$T/$MANIFEST_REL")
a6 "$T" check
assert_eq "A6-SYM [GO] 归档目录含 symlink → check exit 1" 1 "$S_RC"
assert_contains "A6-SYM [GO] check 文案含「符号链接」" "$S_OUT" "符号链接"
assert_contains "A6-SYM [GO] check 点名该 symlink" "$S_OUT" "2026-01-02-sym-rel.md"
a6 "$T" seal
assert_eq "A6-SYM [GO] 归档目录含 symlink → seal exit 1" 1 "$S_RC"
assert_contains "A6-SYM [GO] seal 文案含「符号链接」" "$S_OUT" "符号链接"
assert_eq "A6-SYM [NOGO] seal 拒绝时 manifest 零写入" "$MAN_SYM" "$(sha_of "$T/$MANIFEST_REL")"
# 反向控制：移除 symlink 后回到 0（证明拒绝来自 symlink，不是「一律拒绝」）
rm -f "$T/$ARCHIVED_REL/testing/2026-01-02-sym-rel.md" "$T/$ARCHIVED_REL/testing/2026-01-02-sym-abs.md"
a6 "$T" check
assert_eq "A6-SYM [GO] 移除 symlink 后 check 回到 exit 0（反向控制）" 0 "$S_RC"
a6 "$T" seal
assert_eq "A6-SYM [GO] 移除 symlink 后 seal 回到 exit 0" 0 "$S_RC"

# ============ A6-SYM-DIR：目录 symlink 与归档根 symlink 绕过（L3 B2 回归，task-12）============
# 缺陷形态 1：`archived/process/linked-dir -> /tmp/ext` —— 目录 symlink 名字不含 `.md`，
#   旧实现只扫 `-type l -name '*.md'`，既漏判链接本身，`find -type f` 也不会下钻外部目录，
#   等于把未封印的 `.md` 藏进链接目标（check/seal 双双 rc=0）。
# 缺陷形态 2：`$ARCH`（.agents/notes/archived）本身被换成 symlink —— 整个判定面指向仓库外。
# 判定：两种形态下 check 与 seal 均 exit 1 且文案含「符号链接」，且拒绝时**零写入**
#       （manifest 不变、链接目标目录不被写）；移除链接后恢复 exit 0。
T=$(new_case); gov_repo "$T" 2 || finish
stage_archived_adr "$T" "testing/2026-01-02-dirlink-legit.md"
a6 "$T" seal
assert_eq "A6-SYM-DIR 夹具：合法封印 exit 0" 0 "$S_RC"
EXT="$SBASE/ext.dir"; rm -rf "$EXT"; mkdir -p "$EXT"
cat > "$EXT/2026-01-02-hidden.md" <<'HIDEOF'
# Agent Note: hidden in linked dir

Status: implemented

## Problem

外部目录里的未封印归档件（验证目录 symlink 不被枚举）。

## Decision

用于回归。

## Alternatives considered

- 不测：绕过无法被发现。
HIDEOF
ln -s "$EXT" "$T/$ARCHIVED_REL/process" || bad "A6-SYM-DIR 夹具失败：无法创建目录 symlink"
if [ -L "$T/$ARCHIVED_REL/process" ]; then
  ok "A6-SYM-DIR 取证：目录 symlink 已放入归档目录（archived/process -> $EXT）"
else
  bad "A6-SYM-DIR 夹具失败：目录 symlink 未创建"
fi
MAN_DIR=$(sha_of "$T/$MANIFEST_REL")
EXT_SNAP=$(find "$EXT" -type f | LC_ALL=C sort | md5sum | awk '{print $1}')
a6 "$T" check
assert_eq "A6-SYM-DIR [GO] 归档目录内目录 symlink → check exit 1" 1 "$S_RC"
assert_contains "A6-SYM-DIR [GO] check 文案含「符号链接」" "$S_OUT" "符号链接"
assert_contains "A6-SYM-DIR [GO] check 点名该目录 symlink" "$S_OUT" "process"
a6 "$T" seal
assert_eq "A6-SYM-DIR [GO] 归档目录内目录 symlink → seal exit 1" 1 "$S_RC"
assert_contains "A6-SYM-DIR [GO] seal 文案含「符号链接」" "$S_OUT" "符号链接"
assert_eq "A6-SYM-DIR [NOGO] seal 拒绝时 manifest 零写入" "$MAN_DIR" "$(sha_of "$T/$MANIFEST_REL")"
assert_eq "A6-SYM-DIR [NOGO] 拒绝时不得写进链接目标目录" \
  "$EXT_SNAP" "$(find "$EXT" -type f | LC_ALL=C sort | md5sum | awk '{print $1}')"
# 反向控制：移除目录 symlink 后回到 0
rm -f "$T/$ARCHIVED_REL/process"
a6 "$T" check
assert_eq "A6-SYM-DIR [GO] 移除目录 symlink 后 check 恢复 exit 0（反向控制）" 0 "$S_RC"
a6 "$T" seal
assert_eq "A6-SYM-DIR [GO] 移除目录 symlink 后 seal 恢复 exit 0" 0 "$S_RC"

# 形态 2：归档根 $ARCH 本身是 symlink
T=$(new_case); gov_repo "$T" 2 || finish
EXT2="$SBASE/ext.arch"; rm -rf "$EXT2"; mkdir -p "$EXT2/testing"
cp "$T/AGENTS.md" "$EXT2/AGENTS.md" 2>/dev/null || printf '# agents\n' > "$EXT2/AGENTS.md"
cat > "$EXT2/testing/2026-01-02-ok.md" <<'ARCHEOF'
# Agent Note: archived via linked root

Status: archived

## Problem

归档根被换成 symlink 时的绕过样本。

## Decision

用于回归。

## Alternatives considered

- 不测：判定面指向仓库外。
ARCHEOF
rm -rf "$T/$ARCHIVED_REL"
ln -s "$EXT2" "$T/$ARCHIVED_REL" || bad "A6-SYM-DIR 夹具失败：无法把 $ARCHIVED_REL 换成 symlink"
if [ -L "$T/$ARCHIVED_REL" ]; then
  ok "A6-SYM-DIR 取证：归档根已替换为 symlink（$ARCHIVED_REL -> $EXT2）"
else
  bad "A6-SYM-DIR 夹具失败：归档根 symlink 未创建"
fi
EXT2_SNAP=$(find "$EXT2" -type f | LC_ALL=C sort | md5sum | awk '{print $1}')
a6 "$T" check
assert_eq "A6-SYM-DIR [GO] 归档根是 symlink → check exit 1" 1 "$S_RC"
assert_contains "A6-SYM-DIR [GO] 归档根 symlink 文案含「符号链接」" "$S_OUT" "符号链接"
a6 "$T" seal
assert_eq "A6-SYM-DIR [GO] 归档根是 symlink → seal exit 1" 1 "$S_RC"
assert_contains "A6-SYM-DIR [GO] seal 文案含「符号链接」" "$S_OUT" "符号链接"
assert_missing "A6-SYM-DIR [NOGO] 拒绝时不得把 manifest 写进链接目标" "$EXT2/manifest.sha256"
assert_eq "A6-SYM-DIR [NOGO] 拒绝时链接目标目录零写入" \
  "$EXT2_SNAP" "$(find "$EXT2" -type f | LC_ALL=C sort | md5sum | awk '{print $1}')"
# 反向控制：恢复真实目录 + 合法归档件 → 0
rm -f "$T/$ARCHIVED_REL"
mkdir -p "$T/$ARCHIVED_REL"
printf '# agents\n' > "$T/$ARCHIVED_REL/AGENTS.md"
stage_archived_adr "$T" "testing/2026-01-02-after-restore.md"
a6 "$T" seal
assert_eq "A6-SYM-DIR [GO] 恢复真实归档目录后 seal exit 0（反向控制）" 0 "$S_RC"
a6 "$T" check
assert_eq "A6-SYM-DIR [GO] 恢复真实归档目录后 check exit 0" 0 "$S_RC"

else
  skip "A6-SYM/A6-SYM-DIR：平台不支持 symlink（Windows 默认无权限），symlink 专项未执行"
fi

# ============ A6-STA：Status: archived 来源代理判据（L3 ADVISORY 回归，task-10）============
# 缺陷形态：seal 只认 Status 首词 == implemented → 已按 1.7 迁到 archived/ 的冻结件
# （Status: archived）永远封印不了，等于「归档目录里的合法终态被锁死」。
# 判定：Status: archived → seal exit 0 且成功登记；proposed 仍 exit 1（判据不得放宽成「任意 Status」）。
T=$(new_case); gov_repo "$T" 2 || finish
stage_archived_adr "$T" "testing/2026-01-02-sta-archived.md" "archived"
a6 "$T" seal
assert_eq "A6-STA [GO] Status: archived → seal exit 0（不得锁死）" 0 "$S_RC"
assert_eq "A6-STA [GO] Status: archived 被正常登记（manifest 恰 1 行）" 1 \
  "$(grep -c . "$T/$MANIFEST_REL" 2>/dev/null || printf '0')"
a6 "$T" check
assert_eq "A6-STA [GO] 登记后 check exit 0" 0 "$S_RC"
# 反向对照：proposed 仍拒绝（放宽必须止于「已归档/已实现」，不得放行提案态）
T=$(new_case); gov_repo "$T" 2 || finish
stage_archived_adr "$T" "testing/2026-01-02-sta-proposed.md" "proposed"
a6 "$T" seal
assert_eq "A6-STA [NOGO] Status: proposed 仍 seal exit 1（判据未放宽成任意 Status）" 1 "$S_RC"
assert_missing "A6-STA [NOGO] proposed 不得被封印" "$T/$MANIFEST_REL"

# ============ A6-EOL：manifest CRLF 容错（L3 ADVISORY 回归，task-10）============
# 缺陷形态：Windows/Git Bash 检出把 manifest 换成 CRLF → 行尾 `\r` 混进路径/哈希比对，
# check 报「未封印/孤儿」、seal 拒绝，门禁在跨平台场景自伤。
# 判定：EOL 归一后 check 与 seal 均 exit 0，且逻辑条目不变（2 条）。
T=$(new_case); gov_repo "$T" 2 || finish
stage_archived_adr "$T" "testing/2026-01-02-eol-a.md"
stage_archived_adr "$T" "testing/2026-01-02-eol-b.md"
a6 "$T" seal
assert_eq "A6-EOL 夹具：seal exit 0" 0 "$S_RC"
assert_eq "A6-EOL 夹具：manifest 2 条" 2 "$(grep -c . "$T/$MANIFEST_REL" 2>/dev/null || printf '0')"
# 转 CRLF（逐行加 \r；不使用 sed 的 \r 展开——Windows Git Bash 的 sed 行为不一致）
while IFS= read -r _line || [ -n "$_line" ]; do printf '%s\r\n' "$_line"; done   < "$T/$MANIFEST_REL" > "$T/$MANIFEST_REL.crlf"
mv -f "$T/$MANIFEST_REL.crlf" "$T/$MANIFEST_REL"
_cr_seen=0
while IFS= read -r _cr_line; do
  case "$_cr_line" in *$'\r') _cr_seen=1; break ;; esac
done < "$T/$MANIFEST_REL"
if [ "$_cr_seen" -eq 1 ]; then
  ok "A6-EOL 取证：manifest 确已转为 CRLF"
else
  bad "A6-EOL 夹具失败：未能把 manifest 转成 CRLF"
fi
a6 "$T" check
assert_eq "A6-EOL [GO] CRLF manifest → check exit 0（EOL 归一）" 0 "$S_RC"
assert_not_contains "A6-EOL [NOGO] 不得把 CRLF 误报为未封印" "$S_OUT" "未封印"
a6 "$T" seal
assert_eq "A6-EOL [GO] CRLF manifest → seal exit 0" 0 "$S_RC"
assert_eq "A6-EOL [GO] seal 后逻辑条目仍 2 条（未被 \r 撕裂）" 2 \
  "$(grep -c . "$T/$MANIFEST_REL" 2>/dev/null || printf '0')"

# ============ A6-CONC：seal 并发回归（BLOCKING 缺陷，Lead 2026-11-07 立项 task-9）============
# 缺陷形态：两个 `archive-verify.sh seal` 并行 → 各自「读 manifest（无此条）→ 追加」，
# 无锁的 check-then-append 让同一归档件被写两次 → manifest 重复 → 随后 check exit 1（门禁自伤）。
# 契约依据：A6-7（纯文本追加式）/ A6-14（重复条目 → exit 1）/ A6-19（只追加**缺失**条目）/
#           A6-23（幂等）/ NFR `concurrency_lock`。
# 判定：1 件 implemented 归档、无 manifest；**并行 2×seal × 10 轮**；每轮 manifest 必须恰 1 行、
#       无重复条目、两个进程均 exit 0；收尾 check 必须 exit 0。
# 并发原语：FIFO 发令栅栏（父进程持读写端 + 子进程 `read -u 7` 阻塞，非 sleep 轮询）——
#           两 seal 在同一毫秒级窗口被放行，消除「顺序执行假绿」；`read -t 30` 兜底防挂死。
CONC_ROUNDS=10
GATE="$SBASE/conc.gate"; rm -f "$GATE"
if ! mkfifo "$GATE" 2>/dev/null; then
  bad "A6-CONC 夹具失败：无法创建发令 FIFO（$GATE）"
else
  T=$(new_case); gov_repo "$T" 2 || finish
  stage_archived_adr "$T" "testing/2026-01-02-conc.md"
  ARCH_FILE="$T/$ARCHIVED_REL/testing/2026-01-02-conc.md"
  WANT_H=$(sha_of "$ARCH_FILE")
  rm -f "$T/$MANIFEST_REL"
  exec 7<>"$GATE"                      # 父进程持有读写端：FIFO open 永不阻塞
  BAD_ROUNDS=0; BAD_RC=0; DET=""
  for r in $(seq 1 "$CONC_ROUNDS"); do
    rm -f "$T/$MANIFEST_REL" "$SBASE/rc1.$r" "$SBASE/rc2.$r"
    ( read -r -t 30 -u 7 _ || exit 9
      ( cd "$T" && bash "$A6_REL" seal >/dev/null 2>&1 ); printf '%s' "$?" > "$SBASE/rc1.$r" ) &
    P1=$!
    ( read -r -t 30 -u 7 _ || exit 9
      ( cd "$T" && bash "$A6_REL" seal >/dev/null 2>&1 ); printf '%s' "$?" > "$SBASE/rc2.$r" ) &
    P2=$!
    printf 'go\ngo\n' >&7            # 同一时刻放行两个 seal
    wait "$P1" 2>/dev/null; wait "$P2" 2>/dev/null
    R1=$(cat "$SBASE/rc1.$r" 2>/dev/null || printf 'MISSING')
    R2=$(cat "$SBASE/rc2.$r" 2>/dev/null || printf 'MISSING')
    case "${R1}${R2}" in 00) : ;; *) BAD_RC=$((BAD_RC + 1)) ;; esac
    NL=$(grep -c . "$T/$MANIFEST_REL" 2>/dev/null || printf '0'); NL=${NL:-0}
    if [ "$NL" != "1" ]; then
      BAD_ROUNDS=$((BAD_ROUNDS + 1))
      [ ${#DET} -lt 200 ] && DET="$DET [round $r: ${NL} 行, seal rc=$R1/$R2]"
    fi
  done
  exec 7<&-
  assert_eq "A6-CONC [GO] 10 轮并行 2×seal：每轮 manifest 恰 1 行（偏离轮数）" 0 "$BAD_ROUNDS"
  if [ "$BAD_ROUNDS" -eq 0 ]; then
    ok "A6-CONC 并发写坏明细：无（10/10 轮恰 1 行）"
  else
    bad "A6-CONC 并发写坏明细：$DET"
  fi
  assert_eq "A6-CONC [GO] 10 轮内两个并发 seal 全部 exit 0（异常轮数）" 0 "$BAD_RC"
  DUPN=$(grep -v '^[[:space:]]*$' "$T/$MANIFEST_REL" 2>/dev/null | awk '{print $2}' | sort | uniq -d | wc -l | tr -d ' ')
  assert_eq "A6-CONC [NOGO] manifest 不得出现重复路径条目" 0 "$DUPN"
  assert_eq "A6-CONC [GO] 收尾 manifest 恰 1 行" 1 \
    "$(grep -c . "$T/$MANIFEST_REL" 2>/dev/null || printf '0')"
  assert_eq "A6-CONC [GO] 唯一行 hex == 归档件真实 sha256" "$WANT_H" \
    "$(awk 'NR==1{print $1}' "$T/$MANIFEST_REL" 2>/dev/null)"
  a6 "$T" check
  assert_eq "A6-CONC [GO] 并发生成后 check exit 0（不得因重复行红）" 0 "$S_RC"
  # 顺序对照：串行两次 seal 后仍恰 1 行（证明「恰 1 行」不是靠非法实现恒成立）
  rm -f "$T/$MANIFEST_REL"
  a6 "$T" seal; a6 "$T" seal
  assert_eq "A6-CONC 对照：串行两次 seal 后 manifest 恰 1 行" 1 \
    "$(grep -c . "$T/$MANIFEST_REL" 2>/dev/null || printf '0')"
fi

# ============ A6-CONC-MUT：历史缺陷形态等价体（证明并发回归有辨别力）============
# 为什么不用真实现做「去锁手术」：现行写路径是「lock + 临时文件 + 原子 mv」双保险，
# 只拆锁也难复现重复行（末次 mv 胜出仍 1 行），据此判红会变成「测实现细节」。
# 这里改为自造 15 行「无锁 check-then-append」的历史缺陷等价体，与主用例共用同一发令栅栏：
# 若并发回归真能抓 BLOCKING，等价体必然在若干轮里产出重复行。
MUTDIR=$(new_case); gov_repo "$MUTDIR" 2 || finish
stage_archived_adr "$MUTDIR" "testing/2026-01-02-mut.md"
MUT="$MUTDIR/.meta/gates/archive-verify.mutant.sh"
cat > "$MUT" <<'MUTEOF'
#!/usr/bin/env bash
# 测试用变异体：复刻「无锁 check-then-append」的历史缺陷形态（不是产品代码）
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
ARCH="$ROOT/.agents/notes/archived"
MAN="$ARCH/manifest.sha256"
F_REL=".agents/notes/archived/testing/2026-01-02-mut.md"
F="$ROOT/$F_REL"
if [ ! -f "$MAN" ]; then
  h=$(sha256sum "$F" 2>/dev/null | awk '{print $1}')
  printf '%s  %s\n' "$h" "$F_REL" >> "$MAN"
fi
exit 0
MUTEOF
chmod +x "$MUT"
if ! mkfifo "$SBASE/conc.mut.gate" 2>/dev/null; then
  bad "A6-CONC-MUT 夹具失败：无法创建发令 FIFO"
else
  exec 6<>"$SBASE/conc.mut.gate"
  MUTBAD=0
  for r in 1 2 3 4 5; do
    rm -f "$MUTDIR/$MANIFEST_REL"
    ( read -r -t 30 -u 6 _ || exit 9
      ( cd "$MUTDIR" && bash "$MUT" >/dev/null 2>&1 ) ) &
    A=$!
    ( read -r -t 30 -u 6 _ || exit 9
      ( cd "$MUTDIR" && bash "$MUT" >/dev/null 2>&1 ) ) &
    B=$!
    printf 'go\ngo\n' >&6
    wait "$A" 2>/dev/null; wait "$B" 2>/dev/null
    NL=$(grep -c . "$MUTDIR/$MANIFEST_REL" 2>/dev/null || printf '0')
    [ "${NL:-0}" -gt 1 ] 2>/dev/null && MUTBAD=$((MUTBAD + 1))
  done
  exec 6<&-
  if [ "$MUTBAD" -gt 0 ]; then
    ok "A6-CONC-MUT [GO] 历史缺陷等价体被并发回归抓到（$MUTBAD/5 轮出现重复行）"
  else
    bad "A6-CONC-MUT [GO] 历史缺陷等价体未被抓到（0/5 轮重复）——并发回归缺乏辨别力"
  fi
fi

finish
