#!/usr/bin/env bash
# ============================================================
# adr-verify.spec.sh —— 暂存区 ADR 格式门的负样本执行判据（门禁资产 A2）
#
# 契约（.meta/gates/README.md「负样本 spec 的两种形态」）：
#   - 自包含：从自身路径解析仓库根，不依赖调用者 cwd；
#   - 只读仓库：样本一律建在 `mktemp -d` 临时目录，退出时清理；不改仓库任何文件；
#   - 秒级：自包裹 `timeout 30`（有 timeout 时）；
#   - 防递归：环境里已有 `PONYGO_IN_SPEC=1` → 打印 SKIPPED 并 exit 0（不计入 PASS）；
#   - exit 0 = 自检通过（"门确实会拒绝非法样本，且会放行合法样本"）。
#
# 本 spec 证明的是 A1 的**拒绝语义**，不是"格式判据本身对不对"——后者是
# `.agents/skills/write-adr/verify-note.sh` 的自检范围（诚实条款：执行判据只证明
# 门会响，证明不了抽样无偏；抽样设计靠 review）。
# ============================================================
set -u

SPEC=adr-verify.spec

# --- 防递归：被 audit --run-specs / CI 以 PONYGO_IN_SPEC=1 调用 → SKIPPED ---
if [ "${PONYGO_IN_SPEC:-0}" = "1" ] && [ "${PONYGO_SPEC_SELFRUN:-0}" != "1" ]; then
  printf '[%s] SKIPPED（PONYGO_IN_SPEC=1，不计入 PASS）\n' "$SPEC"
  exit 0
fi

# --- 秒级上限：自包裹 timeout 30，避免挂死拖死体检 ---
if [ "${PONYGO_SPEC_SELFRUN:-0}" != "1" ] && command -v timeout >/dev/null 2>&1; then
  export PONYGO_SPEC_SELFRUN=1
  exec timeout 30 bash "$0" "$@"
fi

ROOT=$(cd "$(dirname "$0")/../.." && pwd) || {
  printf '[%s] FAIL：无法解析仓库根\n' "$SPEC" >&2
  exit 1
}
GATE="$ROOT/.meta/gates/adr-verify.sh"
VERIFY="$ROOT/.agents/skills/write-adr/verify-note.sh"
for f in "$GATE" "$VERIFY"; do
  [ -f "$f" ] || {
    printf '[%s] FAIL：缺被测资产 %s\n' "$SPEC" "$f" >&2
    exit 1
  }
done

TMP=$(mktemp -d) || {
  printf '[%s] FAIL：mktemp -d 失败\n' "$SPEC" >&2
  exit 1
}
trap 'rm -rf "$TMP"' EXIT

FAIL=0
fail() {
  printf 'FAIL  %s\n' "$*" >&2
  FAIL=1
}

# 造一个"已安装接线"的最小 git 仓：A1 + 判定真源 + 四态 notes 目录
new_repo() { # $1 = 目录名（在 $TMP 下）
  local d="$TMP/$1"
  mkdir -p "$d/.meta/gates" "$d/.agents/skills/write-adr" \
    "$d/.agents/notes/proposed/process" "$d/.agents/notes/implemented/process" \
    "$d/.agents/notes/rejected" "$d/.agents/notes/archived"
  cp "$GATE" "$d/.meta/gates/adr-verify.sh"
  cp "$VERIFY" "$d/.agents/skills/write-adr/verify-note.sh"
  git -C "$d" -c init.defaultBranch=main init -q
  git -C "$d" config user.email spec@example.invalid
  git -C "$d" config user.name spec
  printf '%s\n' "$d"
}

# 写一个 ADR 样本（$1=仓 $2=相对路径 $3=正文）
write_adr() {
  mkdir -p "$1/$(dirname "$2")"
  printf '%s\n' "$3" >"$1/$2"
}

# 跑门：cwd 必须在被检仓内（A1 自行 cd 到 toplevel）
run_gate() { # $1=仓，余下=透传参数
  local d="$1"
  shift
  ( cd "$d" && bash .meta/gates/adr-verify.sh "$@" ) 2>&1
}

expect_accept() { # $1=用例名 $2=仓 [extra args]
  local name="$1" d="$2" out rc
  shift 2
  out=$(run_gate "$d" "$@") && rc=0 || rc=$?
  if [ "$rc" -ne 0 ]; then
    fail "$name：门应放行，实得 exit $rc"
    printf '%s\n' "$out" | tail -n 3 | sed 's/^/      /' >&2
    return
  fi
  printf 'PASS  %s（exit 0）\n' "$name"
}

expect_reject() { # $1=用例名 $2=仓 [extra args]
  local name="$1" d="$2" out rc
  shift 2
  out=$(run_gate "$d" "$@") && rc=0 || rc=$?
  if [ "$rc" -eq 0 ]; then
    fail "$name：门应拒绝，实得 exit 0"
    printf '%s\n' "$out" | tail -n 3 | sed 's/^/      /' >&2
    return
  fi
  printf 'PASS  %s（exit %d）\n' "$name" "$rc"
}

LEGAL_BODY='# Agent Note: 合法样本

Status: implemented

## Problem

样本：为证明门会放行而构造的合规 ADR。

## Decision

样本决定。

## Alternatives considered

- 样本备选（落选原因：只是样本）。

## Consequences

- 样本后果。'

# ---------- 1. 合法 ADR → 放行 ----------
R=$(new_repo legal)
write_adr "$R" .agents/notes/implemented/process/2026-10-29-legal-sample.md "$LEGAL_BODY"
git -C "$R" add -A >/dev/null 2>&1
expect_accept "合法 ADR 放行" "$R"
# 带参模式：同一份合法 ADR 显式指定路径
expect_accept "合法 ADR 带参放行" "$R" .agents/notes/implemented/process/2026-10-29-legal-sample.md

# ---------- 2. 时态错位：proposed 下写现在时 ## Decision（判据 1.8）→ 拒绝 ----------
R=$(new_repo tense-drift)
write_adr "$R" .agents/notes/proposed/process/2026-10-29-tense-drift.md '# Agent Note: 时态错位

Status: proposed

## Problem

样本：未批准的提案伪装成已落地的决定。

## Decision

不该出现在 proposed 的现在时标题。

## Alternatives considered

- 样本。'
git -C "$R" add -A >/dev/null 2>&1
expect_reject "时态错位（proposed + ## Decision）拒绝" "$R"

# ---------- 3. implemented 带提案时代标题（判据 1.8）→ 拒绝 ----------
R=$(new_repo proposal-era)
write_adr "$R" .agents/notes/implemented/process/2026-10-29-proposal-era.md '# Agent Note: 提案时代标题

Status: implemented

## Problem

样本：迁移到 implemented 却没把 ## Proposal 改写为现在时。

## Proposal

## Alternatives considered

- 样本。'
git -C "$R" add -A >/dev/null 2>&1
expect_reject "implemented 含 ## Proposal 拒绝" "$R"

# ---------- 4. Status 与所在目录不一致（判据 1.7）→ 拒绝 ----------
R=$(new_repo status-drift)
write_adr "$R" .agents/notes/implemented/process/2026-10-29-status-drift.md '# Agent Note: Status 漂移

Status: proposed

## Problem

样本：Status 行与目录不一致。

## Decision

样本。

## Alternatives considered

- 样本。'
git -C "$R" add -A >/dev/null 2>&1
expect_reject "Status 与目录不一致拒绝" "$R"

# ---------- 5. R6 TOCTOU：staged 后又在工作区改动 → 拒绝且文案可执行 ----------
R=$(new_repo toctou)
write_adr "$R" .agents/notes/implemented/process/2026-10-29-toctou.md "$LEGAL_BODY"
git -C "$R" add -A >/dev/null 2>&1
printf '\n<!-- 暂存后又在工作区改了这一行，制造 TOCTOU -->\n' \
  >>"$R/.agents/notes/implemented/process/2026-10-29-toctou.md"
OUT=$(run_gate "$R") && RC=0 || RC=$?
if [ "$RC" -eq 0 ]; then
  fail "TOCTOU（staged 后工作区再改）应拒绝，实得 exit 0"
elif ! printf '%s' "$OUT" | grep -q 'ADR 有未暂存改动，请先 git add'; then
  fail "TOCTOU 拒绝文案缺「ADR 有未暂存改动，请先 git add」→ 补救不可执行"
  printf '%s\n' "$OUT" | tail -n 3 | sed 's/^/      /' >&2
else
  printf 'PASS  TOCTOU 拒绝且文案可执行（exit %d）\n' "$RC"
fi

# ---------- 6. 缺 ## Alternatives considered —— 覆盖探针 ----------
# 诚实条款：`## Alternatives considered` 是 notes/README 的强制契约，但判定真源
# verify-note.sh 的 1.1–1.9 里**没有**这一项（它只锁路径/文件名/Status/骨架标题）。
# 本 case 因此做成探针：真源将来覆盖该节则断言拒绝；未覆盖则 WARN 保留缺口，
# **不**由本 spec 私设第二真值（同一判据两份实现必然漂移，P9）。
R=$(new_repo missing-alternatives)
write_adr "$R" .agents/notes/implemented/process/2026-10-29-missing-alt.md '# Agent Note: 缺备选节

Status: implemented

## Problem

样本：缺 ## Alternatives considered。

## Decision

样本。'
git -C "$R" add -A >/dev/null 2>&1
OUT=$(run_gate "$R") && RC=0 || RC=$?
if [ "$RC" -ne 0 ]; then
  printf 'PASS  缺 ## Alternatives considered 被真源拒绝（exit %d）\n' "$RC"
else
  printf 'WARN  缺 ## Alternatives considered 未被拒绝：判定真源 1.1–1.9 不含该节 → 本 case 不计入 PASS（缺口见 ADR Consequences）\n'
fi

# ---------- 7. 空场景一律放行：无暂存 ADR 变更 ----------
R=$(new_repo no-change)
write_adr "$R" .agents/notes/implemented/process/2026-10-29-legal-sample.md "$LEGAL_BODY"
git -C "$R" add -A >/dev/null 2>&1
git -C "$R" commit -q -m init >/dev/null 2>&1
expect_accept "无暂存 ADR 变更放行" "$R"

# ---------- 8. 空场景一律放行：无 .agents/notes ----------
R="$TMP/no-notes"
mkdir -p "$R/.meta/gates"
cp "$GATE" "$R/.meta/gates/adr-verify.sh"
git -C "$R" -c init.defaultBranch=main init -q
expect_accept "无 .agents/notes 放行" "$R"

if [ "$FAIL" -ne 0 ]; then
  printf '[%s] 未通过：门禁的拒绝/放行语义与预期不符（见上方 FAIL）\n' "$SPEC" >&2
  exit 1
fi
printf '[%s] 全部通过：拒绝语义 + 放行语义 + TOCTOU 文案均已证明（exit 0）\n' "$SPEC"
exit 0
