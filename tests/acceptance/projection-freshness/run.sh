#!/usr/bin/env bash
# ============================================================
# tests/acceptance/projection-freshness/run.sh
#
# 冻结契约：.scratch/2026-11-10-ponygo-upgrade/contract.md（F1：2.6 canonical 投影新鲜度）
#
# 被测语义：ai-surface: on 且 L2+ 时，根 AGENTS.md / CLAUDE.md 的哨兵块内容必须等于
#           constitution 的 canonical 投影（BEGIN…END 之间的整块，仅归一 \r）；
#           正文漂移 = 2.6 FAIL + exit 1，补救 `bash ponygo sync`。
#
# 方法（黑盒）：每个用例在独立 mktemp 目录铺真骨架（git init + bash ponygo init +
#   一条合法 ADR + level 2 + ai-surface: on，模板态另行投影 bootstrap），然后只通过
#   `bash <repo>/ponygo status|audit|sync` 观测：真实退出码 + stdout/stderr 子串 +
#   文件字节（块正文与 canonical 逐字节相等）。此处不 import 实现、不假设私有函数。
#
# 分级：L2 契约类（判定器行为 + 文件副作用），断言一律为「真断言」，无「跑通即过」。
# 清理：全部临时仓在 mktemp -d 下，EXIT/INT/TERM 统一回收；不改仓库内任何文件。
# ============================================================
set -u

PROJ_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=${PONYGO_ROOT:-$(cd "$PROJ_DIR/../../.." && pwd)}
[ -f "$ROOT/ponygo" ] || { printf '找不到被测 CLI：%s/ponygo\n' "$ROOT" >&2; exit 1; }

SYNC_BEGIN='<!-- BEGIN constitution -->'
SYNC_END='<!-- END constitution -->'

SBASE=$(mktemp -d) || { echo "无法创建临时目录" >&2; exit 1; }
cleanup() { rm -rf "$SBASE"; }
trap cleanup EXIT INT TERM

# git 配置消毒：不得读机器全局/系统配置（钩子、模板、user.* 都不得影响夹具）
GITCONF="$SBASE/gitconfig.empty"; : > "$GITCONF"
export GIT_CONFIG_GLOBAL="$GITCONF" GIT_CONFIG_SYSTEM="$GITCONF"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }

# ---------- 断言 ----------
assert_rc() { # <描述> <期望 rc> <实得 rc>
  if [ "$2" = "$3" ]; then ok "$1（exit $3）"; else bad "$1（期望 exit [$2]，实得 [$3]）"; fi
}
assert_contains() {
  case "$2" in *"$3"*) ok "$1" ;; *) bad "$1（未找到 [$3]）" ;; esac
}
assert_not_contains() {
  case "$2" in *"$3"*) bad "$1（不应出现 [$3]）" ;; *) ok "$1" ;; esac
}
assert_matches() {
  if printf '%s\n' "$2" | grep -Eq -- "$3"; then ok "$1"; else bad "$1（无匹配 /$3/）"; fi
}
assert_not_matches() {
  if printf '%s\n' "$2" | grep -Eq -- "$3"; then bad "$1（不应匹配 /$3/）"; else ok "$1"; fi
}
assert_exists()  { [ -f "$2" ] && ok "$1" || bad "$1（缺文件 $2）"; }
assert_regular() { [ -f "$2" ] && [ ! -L "$2" ] && ok "$1" || bad "$1（$2 不是普通文件或不存在）"; }

# 2.6 失败区间：从含 `2.6` 的行起，连同其缩进续行（到空行为止）。
# 供「补救文案」类断言使用：漂移/缺失可建议 sync，重复/倒序只能建议手工清理。
f26_region() {
  printf '%s\n' "$1" | awk '
    /2\.6/ { inreg=1; print; next }
    inreg==1 && /^[[:space:]]*$/ { inreg=0; next }
    inreg==1 { print }
  '
}

# ---------- 调用被测 CLI ----------
R_OUT=""; R_ERR=""; R_RC=0
run_in() { # <dir> <args...>：R_OUT=stdout（纯净）, R_ERR=stderr, R_RC=退出码
  local dir="$1"; shift
  local errf; errf=$(mktemp "$SBASE/err.XXXXXX") || return 1
  R_OUT=$(cd "$dir" && bash "$ROOT/ponygo" "$@" 2>"$errf")
  R_RC=$?
  R_ERR=$(cat "$errf" 2>/dev/null || :)
  rm -f "$errf"
}

# ---------- 夹具 ----------
# 极小真骨架：git 仓 + ponygo init（模板态）+ 一条合法 ADR + level 2 + ai-surface: on。
mk_skeleton() { # <dir> [level]
  local d="$1" lvl="${2:-2}"
  ( cd "$d" && git init -q . ) >/dev/null 2>&1 || { bad "夹具失败：git init（$d）"; return 1; }
  ( cd "$d" && bash "$ROOT/ponygo" init ) >/dev/null 2>&1 || { bad "夹具失败：ponygo init（$d）"; return 1; }
  mkdir -p "$d/.agents/notes/implemented/architecture"
  cat > "$d/.agents/notes/implemented/architecture/2026-01-01-fixture-adr.md" <<'ADREOF'
# 2026-01-01 夹具 ADR

Status: implemented

## Context

projection-freshness 验收夹具用的合法决策记录（满足 L1 机械判据）。

## Decision

采用最小夹具。

## Alternatives considered

- 不建夹具：判定器无法被验证。
ADREOF
  printf 'level: %s\nai-surface: on\n' "$lvl" > "$d/.meta/meta.yaml"
}

# 填宪法槽位（清掉 TODO: 以脱离模板态，投影体变成「常载命约」）
fill_slots() { # <dir>
  sed -i \
    -e 's/【TODO: 填项目名】/pf-fixture/' \
    -e 's/【TODO: 填一句话定位】/投影新鲜度验收夹具/' \
    -e 's/【TODO: 填技术栈】/bash/' \
    -e 's/【TODO: 填，如 L2】/2/' \
    "$1/.meta/constitution/constitution.md"
}

case_start() { CASE="$1"; printf '\n# %s\n' "$CASE"; }
mk_copy() { # <模板目录> → 独立用例仓路径
  local d; d=$(mktemp -d "$SBASE/case.XXXXXX") || return 1
  cp -a "$1/." "$d/" || { bad "夹具失败：复制模板"; return 1; }
  printf '%s' "$d"
}
CONST=".meta/constitution/constitution.md"

# 块正文（哨兵之间，不含哨兵行）；raw = 不归一 EOL（字节断言用）
block_body_raw() {
  awk -v b="$SYNC_BEGIN" -v e="$SYNC_END" '$0==b{f=1;next} $0==e{f=0} f' "$1"
}
canon_body() { # constitution 的 canonical 投影体（契约：sync-body 锚点之后）
  awk 'BEGIN{ok=0} /<!-- sync-body -->/{ok=1; next} ok' "$1"
}
assert_block_bytes() { # <描述> <投影文件> <constitution>
  local desc="$1" file="$2" const="$3" want got d
  want=$(canon_body "$const")
  got=$(block_body_raw "$file")
  if [ "$want" = "$got" ]; then
    ok "$desc"
  else
    d=$(diff -u <(printf '%s\n' "$want") <(printf '%s\n' "$got") 2>&1 | sed -n '3,8p' | tr '\n' ' ')
    bad "$desc（块正文 ≠ canonical 逐字节；diff：${d:-<空>}）"
  fi
}
count_line() { local n; n=$(grep -cxF "$2" "$1" 2>/dev/null); printf '%s' "${n:-0}"; }
count_cr() { local n; n=$(tr -cd '\r' < "$1" 2>/dev/null | wc -c | tr -d ' '); printf '%s' "${n:-0}"; }

# 模板 A：已填槽 + 已 sync（canonical 基线）
TPL_FILLED="$SBASE/tpl-filled"
mkdir -p "$TPL_FILLED"
mk_skeleton "$TPL_FILLED" 2 || exit 1
fill_slots "$TPL_FILLED"
run_in "$TPL_FILLED" sync
[ "$R_RC" -eq 0 ] || { printf '夹具失败：模板态 sync exit %s\n%s\n' "$R_RC" "$R_OUT$R_ERR" >&2; exit 1; }

# 模板 B：模板态（TODO 槽位未填）→ 投影体是 bootstrap
TPL_BOOT="$SBASE/tpl-boot"
mkdir -p "$TPL_BOOT"
mk_skeleton "$TPL_BOOT" 2 || exit 1

# ============================================================
# PF-01 新鲜 sync 后 PASS（同时是基线自检：基线非绿则其余用例不可归因）
# ============================================================
case_start "PF-01"
T=$(mk_copy "$TPL_FILLED")
assert_exists "PF-01 夹具：根 AGENTS.md 存在" "$T/AGENTS.md"
assert_regular "PF-01 夹具：CLAUDE.md 是普通文件（非 symlink）" "$T/CLAUDE.md"
assert_block_bytes "PF-01 AGENTS.md 块正文逐字节等于 canonical" "$T/AGENTS.md" "$T/$CONST"
assert_block_bytes "PF-01 CLAUDE.md 块正文逐字节等于 canonical" "$T/CLAUDE.md" "$T/$CONST"
run_in "$T" status
assert_rc "PF-01 已 sync 的 on/L2 仓 status" 0 "$R_RC"
assert_contains "PF-01 结论行为「级自洽验证：通过」" "$R_OUT" "级自洽验证：通过"
assert_not_matches "PF-01 NOGO：2.6 不得进 FAIL 列表" "$R_OUT$R_ERR" '^[[:space:]]*-[[:space:]]*2\.6'

# ============================================================
# PF-02 改 constitution（未重投影）→ AGENTS.md 正文漂移 = 2.6 FAIL(exit 1)
# ============================================================
case_start "PF-02"
T=$(mk_copy "$TPL_FILLED")
sed -i 's/^2\. 凡机械可查的承诺.*/2. 漂移测试：本条已在 constitution 中改写（未重投影）。/' "$T/$CONST"
assert_contains "PF-02 夹具：constitution 投影体已改写" "$(cat "$T/$CONST")" "漂移测试"
run_in "$T" status
REG=$(f26_region "$R_OUT$R_ERR")
assert_rc "PF-02 AGENTS.md 正文漂移 → exit 1" 1 "$R_RC"
assert_contains "PF-02 GO：判定点是 2.6" "$REG" "2.6"
assert_contains "PF-02 GO：失败文案点名 AGENTS.md" "$REG" "AGENTS.md"
assert_contains "PF-02 GO：漂移文案给补救 bash ponygo sync" "$REG" "ponygo sync"
assert_not_contains "PF-02 NOGO：不得写「级自洽验证：通过」" "$R_OUT" "级自洽验证：通过"

# ============================================================
# PF-03 仅改 CLAUDE.md（独立普通文件）→ CLAUDE 正文漂移 = 2.6 FAIL
# ============================================================
case_start "PF-03"
T=$(mk_copy "$TPL_FILLED")
assert_regular "PF-03 夹具：CLAUDE.md 为独立普通文件（非 symlink）" "$T/CLAUDE.md"
AG_BEFORE=$(cksum < "$T/AGENTS.md")
sed -i 's/^3\. 删除代码前先搜消费者.*/3. CLAUDE 专属篡改：本条只在 CLAUDE.md 改过。/' "$T/CLAUDE.md"
assert_contains "PF-03 夹具：CLAUDE.md 块内已篡改" "$(cat "$T/CLAUDE.md")" "CLAUDE 专属篡改"
run_in "$T" status
REG=$(f26_region "$R_OUT$R_ERR")
assert_rc "PF-03 CLAUDE.md 正文漂移 → exit 1" 1 "$R_RC"
assert_contains "PF-03 GO：判定点是 2.6" "$REG" "2.6"
assert_contains "PF-03 GO：失败文案点名 CLAUDE.md" "$REG" "CLAUDE.md"
assert_contains "PF-03 GO：漂移文案给补救 ponygo sync" "$REG" "ponygo sync"
assert_contains "PF-03 读命令不改写 AGENTS.md（字节不变）" "$(cksum < "$T/AGENTS.md")" "$AG_BEFORE"

# ============================================================
# PF-04 漂移后重跑 sync → 两文件恢复 canonical 且回到 PASS
# ============================================================
case_start "PF-04"
T=$(mk_copy "$TPL_FILLED")
sed -i 's/^2\. 凡机械可查的承诺.*/2. 漂移测试：本条已改写（等待 resync）。/' "$T/$CONST"
run_in "$T" status
assert_rc "PF-04 resync 前：stale 必须 exit 1（否则无「恢复」可验）" 1 "$R_RC"
run_in "$T" sync
assert_rc "PF-04 夹具：ponygo sync exit 0" 0 "$R_RC"
assert_block_bytes "PF-04 sync 后 AGENTS.md 块正文 = canonical" "$T/AGENTS.md" "$T/$CONST"
assert_block_bytes "PF-04 sync 后 CLAUDE.md 块正文 = canonical" "$T/CLAUDE.md" "$T/$CONST"
run_in "$T" status
assert_rc "PF-04 resync 后 status 回到 exit 0" 0 "$R_RC"
assert_contains "PF-04 结论行为「级自洽验证：通过」" "$R_OUT" "级自洽验证：通过"

# ============================================================
# PF-05 块外用户内容改动 / 追加 → 不得误报（2.6 只比哨兵块内）
# ============================================================
case_start "PF-05"
T=$(mk_copy "$TPL_FILLED")
printf '\n## 用户补充（哨兵块外）\n块外内容不参与 2.6 校验。\n' >> "$T/AGENTS.md"
{ printf '# CLAUDE 头部（块外，位于哨兵之前）\n\n'; cat "$T/CLAUDE.md"; } > "$T/CLAUDE.tmp" && mv "$T/CLAUDE.tmp" "$T/CLAUDE.md"
run_in "$T" status
assert_rc "PF-05 块外改动 → status 仍 exit 0" 0 "$R_RC"
assert_not_matches "PF-05 NOGO：块外改动不得触发 2.6 FAIL" "$R_OUT$R_ERR" '^[[:space:]]*-[[:space:]]*2\.6'
assert_contains "PF-05 块外内容仍在（读命令不改写用户字节）" "$(cat "$T/AGENTS.md")" "用户补充（哨兵块外）"
assert_block_bytes "PF-05 块正文仍等于 canonical" "$T/AGENTS.md" "$T/$CONST"

# ============================================================
# PF-06 缺 AGENTS.md → 结构 FAIL（缺失类可建议 sync）
# ============================================================
case_start "PF-06"
T=$(mk_copy "$TPL_FILLED")
rm -f "$T/AGENTS.md"
run_in "$T" status
REG=$(f26_region "$R_OUT$R_ERR")
assert_rc "PF-06 缺 AGENTS.md → exit 1" 1 "$R_RC"
assert_contains "PF-06 GO：判定点是 2.6" "$REG" "2.6"
assert_contains "PF-06 GO：失败文案点名 AGENTS.md" "$REG" "AGENTS.md"
assert_contains "PF-06 GO：缺失类可建议 bash ponygo sync" "$REG" "ponygo sync"

# ============================================================
# PF-07 缺 CLAUDE.md → 结构 FAIL（旧实现完全不读 CLAUDE.md）
# ============================================================
case_start "PF-07"
T=$(mk_copy "$TPL_FILLED")
rm -f "$T/CLAUDE.md"
run_in "$T" status
REG=$(f26_region "$R_OUT$R_ERR")
assert_rc "PF-07 缺 CLAUDE.md → exit 1" 1 "$R_RC"
assert_contains "PF-07 GO：判定点是 2.6" "$REG" "2.6"
assert_contains "PF-07 GO：失败文案点名 CLAUDE.md" "$REG" "CLAUDE.md"
assert_contains "PF-07 GO：缺失类可建议 bash ponygo sync" "$REG" "ponygo sync"

# ============================================================
# PF-08 / PF-09 缺 BEGIN / 缺 END → 结构 FAIL
# ============================================================
case_start "PF-08"
T=$(mk_copy "$TPL_FILLED")
sed -i '/^<!-- BEGIN constitution -->$/d' "$T/AGENTS.md"
assert_contains "PF-08 夹具：BEGIN 行已删" "$(count_line "$T/AGENTS.md" "$SYNC_BEGIN")" "0"
run_in "$T" status
REG=$(f26_region "$R_OUT$R_ERR")
assert_rc "PF-08 缺 BEGIN 哨兵 → exit 1" 1 "$R_RC"
assert_contains "PF-08 GO：判定点是 2.6" "$REG" "2.6"
assert_contains "PF-08 GO：失败文案点名 AGENTS.md" "$REG" "AGENTS.md"
assert_contains "PF-08 GO：无块可建议 bash ponygo sync" "$REG" "ponygo sync"

case_start "PF-09"
T=$(mk_copy "$TPL_FILLED")
sed -i '/^<!-- END constitution -->$/d' "$T/AGENTS.md"
assert_contains "PF-09 夹具：END 行已删" "$(count_line "$T/AGENTS.md" "$SYNC_END")" "0"
run_in "$T" status
REG=$(f26_region "$R_OUT$R_ERR")
assert_rc "PF-09 缺 END 哨兵 → exit 1" 1 "$R_RC"
assert_contains "PF-09 GO：判定点是 2.6" "$REG" "2.6"
assert_contains "PF-09 GO：失败文案点名 AGENTS.md" "$REG" "AGENTS.md"
assert_contains "PF-09 GO：无块可建议 bash ponygo sync" "$REG" "ponygo sync"

# ============================================================
# PF-10 重复哨兵块 → 结构 FAIL；契约：重复/倒序仅建议手工清理，不得声称 sync 可修
# ============================================================
case_start "PF-10"
T=$(mk_copy "$TPL_FILLED")
cat >> "$T/AGENTS.md" <<'EOF'

<!-- BEGIN constitution -->
重复块（第二对哨兵）
<!-- END constitution -->
EOF
assert_contains "PF-10 夹具：BEGIN 出现 2 次" "$(count_line "$T/AGENTS.md" "$SYNC_BEGIN")" "2"
run_in "$T" status
REG=$(f26_region "$R_OUT$R_ERR")
assert_rc "PF-10 重复哨兵块 → exit 1" 1 "$R_RC"
assert_contains "PF-10 GO：判定点是 2.6" "$REG" "2.6"
assert_contains "PF-10 GO：失败文案点名 AGENTS.md" "$REG" "AGENTS.md"
assert_not_contains "PF-10 NOGO：重复不得声称 sync 可修（契约：仅建议手工清理）" "$REG" "ponygo sync"
assert_matches "PF-10 GO：重复给出「手工清理」类修法（非 sync）" "$REG" '手工|手动|人工|清理|删除'

# ============================================================
# PF-11 哨兵倒序（END 在 BEGIN 之上）→ 结构 FAIL；同样不得声称 sync 可修
# ============================================================
case_start "PF-11"
T=$(mk_copy "$TPL_FILLED")
cat > "$T/AGENTS.md" <<'EOF'
# AGENTS.md（END 在 BEGIN 之上：顺序颠倒）

文档标准 → docs/AGENTS.md

<!-- END constitution -->
中间内容
<!-- BEGIN constitution -->
EOF
run_in "$T" status
REG=$(f26_region "$R_OUT$R_ERR")
assert_rc "PF-11 哨兵倒序 → exit 1" 1 "$R_RC"
assert_contains "PF-11 GO：判定点是 2.6" "$REG" "2.6"
assert_contains "PF-11 GO：失败文案点名 AGENTS.md" "$REG" "AGENTS.md"
assert_not_contains "PF-11 NOGO：倒序不得声称 sync 可修（契约：仅建议手工清理）" "$REG" "ponygo sync"
assert_matches "PF-11 GO：倒序给出「手工清理」类修法（非 sync）" "$REG" '手工|手动|人工|清理|删除'

# ============================================================
# PF-12 哨兵成对但块内为空 → 结构 FAIL
# ============================================================
case_start "PF-12"
T=$(mk_copy "$TPL_FILLED")
cat > "$T/AGENTS.md" <<'EOF'
# AGENTS.md（成对但块内为空）

文档标准 → docs/AGENTS.md

<!-- BEGIN constitution -->
<!-- END constitution -->
EOF
run_in "$T" status
REG=$(f26_region "$R_OUT$R_ERR")
assert_rc "PF-12 空投影块 → exit 1" 1 "$R_RC"
assert_contains "PF-12 GO：判定点是 2.6" "$REG" "2.6"
assert_matches "PF-12 GO：失败文案点名文件（AGENTS）" "$REG" 'AGENTS'

# ============================================================
# PF-13 ai-surface: off → 2.6 显式未启用（不计入 PASS，也不判 FAIL），退出码不变
# ============================================================
case_start "PF-13"
T=$(mk_copy "$TPL_FILLED")
printf 'level: 2\nai-surface: off\n' > "$T/.meta/meta.yaml"
sed -i 's/^2\. 凡机械可查的承诺.*/2. 已漂移但 off 应放行（语义不变）。/' "$T/$CONST"
run_in "$T" status
assert_rc "PF-13 ai-surface: off → exit 0（显式 opt-out，不判 FAIL）" 0 "$R_RC"
assert_contains "PF-13 GO：说明 2.6 未启用" "$R_OUT" "2.6 未启用"
assert_not_contains "PF-13 NOGO：结论行不得出现「全部 PASS」" "$R_OUT" "全部 PASS"
assert_not_matches "PF-13 NOGO：off 不得判 2.6 FAIL" "$R_OUT$R_ERR" '^[[:space:]]*-[[:space:]]*2\.6'

# ============================================================
# PF-14 ai-surface 未声明 → 2.6 SKIPPED（WARN 走 stderr），exit 0 不变
# ============================================================
case_start "PF-14"
T=$(mk_copy "$TPL_FILLED")
printf 'level: 2\n' > "$T/.meta/meta.yaml"
sed -i 's/^2\. 凡机械可查的承诺.*/2. 已漂移但未声明应 SKIP（语义不变）。/' "$T/$CONST"
run_in "$T" status
assert_rc "PF-14 未声明 ai-surface → exit 0" 0 "$R_RC"
assert_contains "PF-14 GO：stderr WARN 通道含「2.6 SKIPPED」" "$R_ERR" "2.6 SKIPPED"
assert_matches "PF-14 GO：结论面标注 SKIPPED/未验证/未声明" "$R_OUT" 'SKIPPED|未验证|未声明'
assert_not_matches "PF-14 NOGO：未声明不得判 2.6 FAIL" "$R_OUT$R_ERR" '^[[:space:]]*-[[:space:]]*2\.6'

# ============================================================
# PF-15 行内（非独占整行）marker 不参与结构识别 → 不得误判重复/漂移
# ============================================================
case_start "PF-15"
T=$(mk_copy "$TPL_FILLED")
printf '\n说明：形如 <!-- BEGIN constitution --> 与 <!-- END constitution --> 的行内标记不算哨兵。\n' >> "$T/AGENTS.md"
assert_contains "PF-15 夹具：BEGIN 独占整行仍恰 1 次" "$(count_line "$T/AGENTS.md" "$SYNC_BEGIN")" "1"
run_in "$T" status
assert_rc "PF-15 行内 marker → status exit 0" 0 "$R_RC"
assert_not_matches "PF-15 NOGO：行内 marker 不得触发 2.6 FAIL" "$R_OUT$R_ERR" '^[[:space:]]*-[[:space:]]*2\.6'

# ============================================================
# PF-16 CRLF：比较仅归一 \r → 不得误漂移
# ============================================================
case_start "PF-16"
T=$(mk_copy "$TPL_FILLED")
crlf_ify() { awk '{printf "%s\r\n", $0}' "$1" > "$1.crlf" && mv "$1.crlf" "$1"; }
crlf_ify "$T/AGENTS.md"
crlf_ify "$T/CLAUDE.md"
assert_matches "PF-16 夹具：AGENTS.md 确有 CR 字节" "$(count_cr "$T/AGENTS.md")" '^[1-9][0-9]*$'
run_in "$T" status
assert_rc "PF-16 CRLF 投影 → status exit 0（\r 归一后无漂移）" 0 "$R_RC"
assert_not_matches "PF-16 NOGO：CRLF 不得触发 2.6 FAIL" "$R_OUT$R_ERR" '^[[:space:]]*-[[:space:]]*2\.6'
assert_contains "PF-16 GO：结论行为「级自洽验证：通过」" "$R_OUT" "级自洽验证：通过"

# ============================================================
# PF-17 末尾空行（哨兵块之后）→ 不得误漂移
# ============================================================
case_start "PF-17"
T=$(mk_copy "$TPL_FILLED")
printf '\n\n' >> "$T/AGENTS.md"
printf '\n\n' >> "$T/CLAUDE.md"
run_in "$T" status
assert_rc "PF-17 块后末尾空行 → status exit 0" 0 "$R_RC"
assert_not_matches "PF-17 NOGO：末尾空行不得触发 2.6 FAIL" "$R_OUT$R_ERR" '^[[:space:]]*-[[:space:]]*2\.6'

# ============================================================
# PF-18 反斜杠内容：sync 写入必须保真（禁 awk -v 转义分叉），且重投影后仍 PASS
# ============================================================
case_start "PF-18"
T=$(mk_copy "$TPL_FILLED")
cat >> "$T/$CONST" <<'EOF'

5. 反斜杠内容保真：C:\path\to\file、\n、\t、\\、$HOME、"双引号"、'单引号'、100%。
EOF
assert_contains "PF-18 夹具：constitution 含反斜杠字面量" "$(cat "$T/$CONST")" 'C:\path\to\file'
run_in "$T" sync
assert_rc "PF-18 夹具：ponygo sync exit 0" 0 "$R_RC"
assert_block_bytes "PF-18 sync 后 AGENTS.md 块正文逐字节保真（含反斜杠）" "$T/AGENTS.md" "$T/$CONST"
assert_block_bytes "PF-18 sync 后 CLAUDE.md 块正文逐字节保真（含反斜杠）" "$T/CLAUDE.md" "$T/$CONST"
run_in "$T" status
assert_rc "PF-18 反斜杠正文 → status exit 0（无假漂移）" 0 "$R_RC"
assert_not_matches "PF-18 NOGO：反斜杠不得触发 2.6 FAIL" "$R_OUT$R_ERR" '^[[:space:]]*-[[:space:]]*2\.6'

# ============================================================
# PF-19 模板态（TODO 槽位未填）→ bootstrap 投影 PASS
# ============================================================
case_start "PF-19"
T=$(mk_copy "$TPL_BOOT")
assert_contains "PF-19 夹具：constitution 仍是模板态（含 TODO:）" "$(cat "$T/$CONST")" "TODO:"
assert_contains "PF-19 夹具：AGENTS.md 投影的是 bootstrap 引导" "$(cat "$T/AGENTS.md")" "初始引导（bootstrap）"
run_in "$T" status
assert_rc "PF-19 模板态 bootstrap 投影 → status exit 0" 0 "$R_RC"
assert_contains "PF-19 GO：结论行为「级自洽验证：通过」" "$R_OUT" "级自洽验证：通过"
assert_not_matches "PF-19 NOGO：bootstrap 不得判 2.6 FAIL" "$R_OUT$R_ERR" '^[[:space:]]*-[[:space:]]*2\.6'

# ============================================================
# PF-20 模板态下投影块被改（stale bootstrap）→ 2.6 FAIL
# ============================================================
case_start "PF-20"
T=$(mk_copy "$TPL_BOOT")
sed -i 's/先一次性完成治理引导/先一次性完成治理引导（旧版残留）/' "$T/AGENTS.md"
assert_contains "PF-20 夹具：AGENTS.md 块内已残留改动" "$(cat "$T/AGENTS.md")" "旧版残留"
run_in "$T" status
REG=$(f26_region "$R_OUT$R_ERR")
assert_rc "PF-20 stale bootstrap → exit 1" 1 "$R_RC"
assert_contains "PF-20 GO：判定点是 2.6" "$REG" "2.6"
assert_contains "PF-20 GO：失败文案点名 AGENTS.md" "$REG" "AGENTS.md"
assert_contains "PF-20 GO：给出补救 bash ponygo sync" "$REG" "ponygo sync"

# ============================================================
# PF-21 JSON 机读面：audit --json 仍单行，且漂移 id 为 2.6
# ============================================================
case_start "PF-21"
T=$(mk_copy "$TPL_FILLED")
sed -i 's/^2\. 凡机械可查的承诺.*/2. JSON 面漂移夹具：本条已改写（未重投影）。/' "$T/$CONST"
run_in "$T" audit --json
assert_rc "PF-21 漂移仓 audit --json → exit 1" 1 "$R_RC"
assert_contains "PF-21 GO：stdout 恰为单行 JSON" "$(printf '%s\n' "$R_OUT" | wc -l | tr -d ' ')" "1"
assert_not_contains "PF-21 NOGO：机读面不得混入人读文本" "$R_OUT" "级自洽验证"
assert_matches "PF-21 GO：fails 列表含 2.6（唯一 id，不新增 2.6b）" "$R_OUT" '"fails":\[[^]]*"2\.6"'
assert_matches "PF-21 GO：JSON exit 字段 == 真实退出码 1" "$R_OUT" '"exit":1'

# ============================================================
printf '\n##CASE %s pass=%s fail=%s\n' "$(basename "$0")" "$PASS" "$FAIL"
if [ "$FAIL" -eq 0 ]; then exit 0; else exit 1; fi
