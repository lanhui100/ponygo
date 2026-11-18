#!/usr/bin/env bash
# ============================================================
# A7 —— 归档封印门（A6）的负样本执行判据（门禁资产 A7）
#
# 契约（.meta/gates/README.md「负样本 spec 的两种形态」）：
#   - 自包含：以**自身所在目录**为基准寻址 A6（同目录 archive-verify.sh），
#     不依赖调用者 cwd，也不从 PATH 找同名脚本；
#   - 只读仓库：样本一律建在 `mktemp -d` 临时目录，退出时清理；不改被检仓库任何文件；
#   - 秒级：自包裹上限 = `PONYGO_GATE_SPEC_TIMEOUT`（由 ponygo 派生下传，未设默认 90s），
#     KILL 兜底 `-k 5`；无 timeout 或 ponygo 报告守卫不可用（`PONYGO_SPEC_NO_GUARD=1`）时不加包裹；不调用自身（无递归）；
#   - exit 0 = 自检通过（门确实会拒绝五类非法样本，且会放行合法样本）；只允许 0/1。
#
# 五类负样本（每类都必须被 A6 拒绝，且配有正向对照，防「一律拒绝」的门混过）：
#   N1 篡改     归档件封印后被改一字节（长度不变的最坏情形）→ check 必须 1
#   N2 缺条目   归档件存在但 manifest 无该条目（未封印）→ check 必须 1
#   N3 孤儿     manifest 条目指向不存在的归档件 → check 必须 1
#   N4 重复     manifest 同一路径登记两行 → check 必须 1
#   N5 非追加   既有条目被改动后再 seal → seal 必须 1，且 manifest 零写入
#   合法样本    两件合规归档件 → seal 0 且 check 0
#
# 诚实条款：本 spec 只证明"门会响"，证明不了抽样无偏——抽样设计靠 review。
# 注：`PONYGO_IN_SPEC` 只是信息变量，**不作为自我跳过开关**（本 spec 恒完整执行）；
#     门 A6 对该变量无感（判定与输出不随其变化）。
# ============================================================
set -u

SPEC=archive-verify.spec
GATE_DIR=$(cd "$(dirname "$0")" && pwd) || {
  printf '[%s] FAIL：无法解析自身目录\n' "$SPEC" >&2
  exit 1
}
GATE="$GATE_DIR/archive-verify.sh"

# 自包裹上限：PONYGO_GATE_SPEC_TIMEOUT（由 ponygo 派生下传，未设默认 90s）；KILL 兜底恒 5s。
# spec 内**不做平台判定**（平台真值只留在 ponygo 一处），只读 env + 校验格式。
GT=${PONYGO_GATE_SPEC_TIMEOUT:-90}
case "$GT" in
  *[!0-9]*|0*)
    printf '[%s] FAIL 非法 PONYGO_GATE_SPEC_TIMEOUT=%s（须为 1..86400 的正整数秒）\n' "$SPEC" "$GT" >&2
    exit 2 ;;
esac
# 值域上界（1..86400）：超长整数会让 GNU timeout 接受并视为「不设上限」，而预算行照打 = 假护栏。
if [ "${#GT}" -gt 5 ] || { [ "${#GT}" -eq 5 ] && [ "$GT" -gt 86400 ]; }; then
  printf '[%s] FAIL 非法 PONYGO_GATE_SPEC_TIMEOUT=%s（须为 1..86400 的正整数秒）\n' "$SPEC" "$GT" >&2
  exit 2
fi
if [ "${PONYGO_SPEC_SELFRUN:-0}" != "1" ] && [ "${PONYGO_SPEC_NO_GUARD:-0}" != "1" ] && command -v timeout >/dev/null 2>&1; then
  export PONYGO_SPEC_SELFRUN=1
  exec timeout -k 5 "$GT" bash "$0" "$@"
fi

[ -f "$GATE" ] || {
  printf '[%s] FAIL：缺被测门禁 %s（A6 未随框架交付或路径被改）\n' "$SPEC" "$GATE" >&2
  exit 1
}

TMP=$(mktemp -d 2>/dev/null) || {
  printf '[%s] FAIL：mktemp -d 失败\n' "$SPEC" >&2
  exit 1
}
trap 'rm -rf "$TMP" 2>/dev/null || true' EXIT INT TERM

FAIL=0
# U4（W3b）运行时计数：asserts = PASS_N + FAIL_N；REJECTS = **期望被拒**的断言条数（逐断言累加）。
PASS_N=0
FAIL_N=0
REJECTS=0
# 通过行（A7 的 [ok] 行数被上游计数：5 负样本 + 1 合法样本 = 6）
ok_case() { PASS_N=$((PASS_N+1)); printf '[ok]   %s\n' "$*"; }
fail_case() {
  FAIL=1
  FAIL_N=$((FAIL_N+1))
  printf '[fail] %s\n' "$*"
  printf '[%s] 失败：%s\n' "$SPEC" "$*" >&2
}
# 期望被拒的断言：先记一条 rejects，再按 rc 判通过/失败（计数点贴着断言，禁止手写常数）
reject_case() { # <rc> <描述>：rc≠0 即门确实拒绝了
  REJECTS=$((REJECTS+1))
  if [ "$1" -ne 0 ]; then ok_case "$2"; else fail_case "$2（门未拒绝，exit 0）"; fi
}

# 造一个独立样本仓：只放被测门禁 + 归档目录（不需要 git，A6 以自身路径解析仓库根）
new_repo() { # <name> → 目录路径
  local d="$TMP/$1"
  mkdir -p "$d/.meta/gates" "$d/.agents/notes/archived/testing" || return 1
  cp "$GATE" "$d/.meta/gates/archive-verify.sh" || return 1
  printf '%s\n' "$d"
}

mk_adr() { # <dir> <文件名> [status]
  cat >"$1/.agents/notes/archived/testing/$2" <<ADREOF
# Agent Note: archive-verify spec fixture

Status: ${3:-implemented}

## Problem

spec 夹具：用于证明封印门会拒绝非法样本。

## Decision

夹具正文（内容无关，仅用于 sha256 封印）。
ADREOF
}

run_gate() { # <dir> [check|seal] → 0/1（输出丢弃，只看退出码）
  local d="$1"
  shift
  ( cd "$d" && bash "$d/.meta/gates/archive-verify.sh" "$@" ) >"$TMP/gate.log" 2>&1
}

sha_of() { sha256sum "$1" 2>/dev/null | awk '{print $1}'; }

# 篡改一字节（长度不变、确定性）：把首字节换成不同的字符
bend_byte() { # <file>
  local f="$1" first repl
  first=$(head -c 1 "$f" 2>/dev/null)
  case "$first" in
    Z) repl='Y' ;;
    *) repl='Z' ;;
  esac
  printf '%s' "$repl" | dd of="$f" bs=1 count=1 conv=notrunc status=none 2>/dev/null || return 1
  [ "$(head -c 1 "$f" 2>/dev/null)" = "$repl" ] || return 1
  return 0
}

# ---------------- N1 篡改 ----------------
d=$(new_repo n1) || { fail_case "N1 篡改：夹具创建失败"; d=""; }
if [ -n "$d" ]; then
  mk_adr "$d" "a.md"
  if ! run_gate "$d" seal; then
    fail_case "N1 篡改：夹具 seal 未成功（正向对照失败）"
  else
    bend_byte "$d/.agents/notes/archived/testing/a.md" || fail_case "N1 篡改：夹具篡改失败"
    if run_gate "$d" check; then
      fail_case "N1 篡改：归档件被改一字节后 check 仍放行（门未拒绝哈希不符）"
    else
      reject_case 1 "N1 篡改：封印后被改一字节 → check 拒绝（exit 1）"
    fi
  fi
fi

# ---------------- N2 缺条目（未封印） ----------------
d=$(new_repo n2) || { fail_case "N2 缺条目：夹具创建失败"; d=""; }
if [ -n "$d" ]; then
  mk_adr "$d" "a.md"
  if run_gate "$d" check; then
    fail_case "N2 缺条目：归档件未封印时 check 仍放行（门未报未封印）"
  else
    reject_case 1 "N2 缺条目：归档件未封印 → check 拒绝（exit 1）"
  fi
fi

# ---------------- N3 孤儿（manifest 有、磁盘无） ----------------
d=$(new_repo n3) || { fail_case "N3 孤儿：夹具创建失败"; d=""; }
if [ -n "$d" ]; then
  mk_adr "$d" "a.md"
  if ! run_gate "$d" seal; then
    fail_case "N3 孤儿：夹具 seal 未成功（正向对照失败）"
  else
    rm -f "$d/.agents/notes/archived/testing/a.md"
    if run_gate "$d" check; then
      fail_case "N3 孤儿：manifest 条目指向不存在文件时 check 仍放行（门未报孤儿）"
    else
      reject_case 1 "N3 孤儿：manifest 条目指向不存在的归档件 → check 拒绝（exit 1）"
    fi
  fi
fi

# ---------------- N4 重复条目 ----------------
d=$(new_repo n4) || { fail_case "N4 重复：夹具创建失败"; d=""; }
if [ -n "$d" ]; then
  mk_adr "$d" "a.md"
  if ! run_gate "$d" seal; then
    fail_case "N4 重复：夹具 seal 未成功（正向对照失败）"
  else
    cp "$d/.agents/notes/archived/manifest.sha256" "$TMP/man4" 2>/dev/null || true
    cat "$TMP/man4" "$TMP/man4" >"$d/.agents/notes/archived/manifest.sha256" 2>/dev/null || true
    if run_gate "$d" check; then
      fail_case "N4 重复：manifest 同一路径登记两行时 check 仍放行（门未报重复）"
    else
      reject_case 1 "N4 重复：manifest 重复条目 → check 拒绝（exit 1）"
    fi
  fi
fi

# ---------------- N5 非追加（既有条目被改动后 seal） ----------------
d=$(new_repo n5) || { fail_case "N5 非追加：夹具创建失败"; d=""; }
if [ -n "$d" ]; then
  mk_adr "$d" "a.md"
  if ! run_gate "$d" seal; then
    fail_case "N5 非追加：夹具 seal 未成功（正向对照失败）"
  else
    before=$(sha_of "$d/.agents/notes/archived/manifest.sha256")
    bend_byte "$d/.agents/notes/archived/testing/a.md" || fail_case "N5 非追加：夹具篡改失败"
    if run_gate "$d" seal; then
      fail_case "N5 非追加：既有条目被改动后 seal 仍放行（append-only 被破坏）"
    else
      after=$(sha_of "$d/.agents/notes/archived/manifest.sha256")
      if [ "$before" = "$after" ]; then
        reject_case 1 "N5 非追加：既有条目被改动 → seal 拒绝且 manifest 零写入"
      else
        fail_case "N5 非追加：seal 拒绝但仍改写了 manifest（篡改被洗白）"
      fi
    fi
  fi
fi

# ---------------- 合法样本（正向对照：门不得一律拒绝） ----------------
d=$(new_repo legal) || { fail_case "合法样本：夹具创建失败"; d=""; }
if [ -n "$d" ]; then
  mk_adr "$d" "a.md"
  mk_adr "$d" "b.md"
  if ! run_gate "$d" seal; then
    fail_case "合法样本：合规归档件 seal 被拒（门过度拒绝）"
  elif ! run_gate "$d" check; then
    fail_case "合法样本：封印后 check 被拒（门过度拒绝）"
  else
    ok_case "合法样本：合规归档件 seal 通过且 check 通过"
  fi
fi

rm -rf "$TMP" 2>/dev/null || true
trap - EXIT INT TERM

if [ "$FAIL" -eq 0 ]; then
  # U4（W3b）运行时契约：成功路径打印机读计数（asserts=PASS+FAIL；rejects=期望被拒断言数）。
  # 位置放在人类「通过」横幅**之前**：末行「通过」是 A7-1 的既有断言（wave13 f2），
  # 计数行只需存在于输出中（CLI 取最后一条 ##SPEC），不必抢末行。
  printf '##SPEC asserts=%s rejects=%s\n' "$((PASS_N + FAIL_N))" "$REJECTS"
  printf '== %s：通过（5 类负样本 + 1 合法样本全部符合预期）==\n' "$SPEC"
  exit 0
fi
printf '== %s：未通过（见上方 [fail] 行）==\n' "$SPEC"
exit 1
