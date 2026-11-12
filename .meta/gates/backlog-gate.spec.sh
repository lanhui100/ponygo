#!/usr/bin/env bash
# ============================================================
# backlog-gate.spec.sh —— backlog-gate 门禁的负样本与契约测试
#
# 契约（与 .meta/gates/README.md「负样本 spec 的两种形态」一致）：
#   - 自包含：从自身路径解析仓库根，不依赖调用者 cwd；
#   - 只读仓库：样本一律建在 mktemp -d 夹具目录，退出时清理；
#   - 秒级：有 timeout 时施加 30s 上限；
#   - exit 0 = 门禁在非法样本上拒绝、在合法样本上放行（自检通过）。
#
# 断言面：
#   P1 合法账本 → 放行
#   P2 编号下限：空账本首次 record → B001（ID_FLOOR=1，不是上游仓遗留的 B056）
#   P3 真实操作闭环：record → start（租约 + owner + touched_paths）→ resolve（归档 + 清锁）→ 放行
#   P4 实例级在场：本仓 tasks.jsonl / .next-id / scripts/backlog.mjs 必须存在（防「删账本 → 门静默跳过」）
#   P5 接线实证（静态）：CI governance job 与 pre-commit 都真调本门，且钩子含 fail-closed 分支
#   N1 记录缺 metadata.fingerprint → 拒绝（lint）
#   N2 活跃池残留 done → 拒绝（lint）
#   N3 孤儿租约 → 拒绝（doctor 对账）
#   N4 记录 ID 越过高水位 → 拒绝（lint）
#   N5 无账本 → 跳过并放行（迁移期语义）
#   N6 无 node → fail-closed 拒绝
#   N7 锁存在但记录非 in_progress（手改降级 / start 中断）→ 拒绝（租约-状态互斥）
#   N8 record 缺 --fingerprint → 拒绝（exec）
#   H  pre-commit 接线：门在场 → commit 放行；门缺失 → fail-closed 拒绝
#   H2 门在场 + 账本非法 → commit 被拒且证据含门输出（证明钩子真执行门，而非只判文件存在）
# ============================================================
set -u

SPEC=backlog-gate.spec

# 自包裹上限：PONYGO_GATE_SPEC_TIMEOUT（由 ponygo 派生下传，未设默认 30s）；KILL 兜底恒 5s。
# spec 内**不做平台判定**（平台真值只留在 ponygo 一处），只读 env + 校验格式。
GT=${PONYGO_GATE_SPEC_TIMEOUT:-30}
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

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
GATE="$ROOT/.meta/gates/backlog-gate.sh"
CLI="$ROOT/scripts/backlog.mjs"

TMPDIR_SPEC=$(mktemp -d)
trap 'rm -rf "$TMPDIR_SPEC"' EXIT

fail() { echo "spec: FAIL $*" >&2; exit 1; }

# 每个样本是独立夹具仓：只放被测 CLI 副本与账本，门禁按 PONYGO_WORKSPACE_ROOT 寻址。
mkcase() {
  d="$TMPDIR_SPEC/$1"
  mkdir -p "$d/scripts" "$d/backlog"
  cp "$CLI" "$d/scripts/backlog.mjs"
  printf '%s\n' "$d"
}

run_gate() {
  ( cd "$1" && PONYGO_WORKSPACE_ROOT="$1" PONY_BACKLOG_ROOT="$1" bash "$GATE" )
}

valid_record() {
  printf '%s\n' '{"id":"B001","category":"Task","priority":"P1","status":"todo","title":"t","created_at":"2026-01-01T00:00:00.000Z","metadata":{"fingerprint":"f"}}'
}

expect_pass() {
  if ! run_gate "$1" >"$1/gate.out" 2>&1; then
    cat "$1/gate.out" >&2
    fail "$2 未被放行"
  fi
}

expect_fail() {
  case_dir="$1"; label="$2"; needle="$3"
  if run_gate "$case_dir" >"$case_dir/gate.out" 2>&1; then
    cat "$case_dir/gate.out" >&2
    fail "$label 未被拒绝"
  fi
  grep -qF "$needle" "$case_dir/gate.out" || {
    cat "$case_dir/gate.out" >&2
    fail "$label 拒绝证据不完整（未出现：$needle）"
  }
}

# P1 合法账本：todo 记录 + 高水位越过最大编号 → 放行
c=$(mkcase pass-legal)
valid_record > "$c/backlog/tasks.jsonl"
printf '5\n' > "$c/backlog/.next-id"
expect_pass "$c" "P1 合法账本"

# P2 编号下限：空账本首次 record → B001（本仓 ID_FLOOR=1；上游仓把下限钳在 56，
# 若误搬该常量，首次登记会凭空跳到 B056——这是复用基线脚本最贵的回归点）
c=$(mkcase pass-id-floor)
: > "$c/backlog/tasks.jsonl"
if ! ( cd "$c" && PONY_BACKLOG_ROOT="$c" node "$CLI" record --category Task --title "首次登记" --fingerprint "spec::id-floor" >"$c/record.out" 2>&1 ); then
  cat "$c/record.out" >&2
  fail "P2 空账本 record 失败"
fi
grep -qF '已登记 B001' "$c/record.out" || {
  cat "$c/record.out" >&2
  fail "P2 首次 record 未分配 B001（期望见「已登记 B001」，实得见上）"
}

# P3 真实操作闭环：record → start（租约 + owner + touched_paths）→ resolve（归档 + 清锁）→ 门放行
c=$(mkcase pass-lifecycle)
: > "$c/backlog/tasks.jsonl"
bl() { ( cd "$1" && PONY_BACKLOG_ROOT="$1" node "$CLI" "${@:2}" ); }
if ! bl "$c" record --category Task --title "闭环样本" --fingerprint "spec::lifecycle" >"$c/p3.out" 2>&1; then
  cat "$c/p3.out" >&2; fail "P3 record 失败"
fi
if ! bl "$c" start B001 --owner spec-verifier --paths "scripts/backlog.mjs" >>"$c/p3.out" 2>&1; then
  cat "$c/p3.out" >&2; fail "P3 start 失败（应获取租约并置 in_progress）"
fi
[ -f "$c/backlog/.locks/B001.lock" ] || fail "P3 start 未生成租约锁 .locks/B001.lock"
if ! bl "$c" resolve B001 --evidence "spec e2e：record→start→resolve" >>"$c/p3.out" 2>&1; then
  cat "$c/p3.out" >&2; fail "P3 resolve 失败（应归档并释放租约）"
fi
[ -f "$c/backlog/.locks/B001.lock" ] && fail "P3 resolve 未释放租约锁（残留 .locks/B001.lock）"
archive_file="$c/backlog/archive/tasks-$(date -u +%Y).jsonl"
[ -f "$archive_file" ] || fail "P3 resolve 未写入归档 tasks-$(date -u +%Y).jsonl"
grep -qF '"id":"B001"' "$archive_file" || fail "P3 归档文件不含 B001"
[ -s "$c/backlog/tasks.jsonl" ] && fail "P3 活跃池未清空已闭环记录"
expect_pass "$c" "P3 真实操作闭环（归档后账本仍合法）"

# P4 实例级在场断言（本仓已启用账本，防「删账本 → 门静默跳过 → 整链变绿」）
# spec 常驻跑在本仓根上：这里断的不是夹具，而是"本仓确实有账本"这个事实。
[ -f "$ROOT/backlog/tasks.jsonl" ] || fail "P4 本仓 backlog/tasks.jsonl 缺失（门会静默跳过 = 账本门失效）"
[ -f "$ROOT/backlog/.next-id" ] || fail "P4 本仓 backlog/.next-id 缺失（高水位丢失，ID 单调性无载体）"
[ -f "$ROOT/scripts/backlog.mjs" ] || fail "P4 判定真源 scripts/backlog.mjs 缺失"

# P5 接线实证（静态）：CI governance job 真跑本门；pre-commit 在哨兵块之外调用本门
grep -qF 'bash .meta/gates/backlog-gate.sh' "$ROOT/.github/workflows/ci.yml" \
  || fail "P5 CI 未挂 backlog 门（governance job 缺 .meta/gates/backlog-gate.sh 调用）"
grep -qF 'backlog-gate.sh' "$ROOT/.githooks/pre-commit" \
  || fail "P5 pre-commit 未调用 backlog 门（本地层失守）"
grep -qF 'fail-closed' "$ROOT/.githooks/pre-commit" \
  || fail "P5 pre-commit 缺 fail-closed 分支（门缺失时应拒绝提交）"

# N1 缺 metadata.fingerprint → lint 拒绝
c=$(mkcase neg-fingerprint)
printf '%s\n' '{"id":"B001","category":"Task","priority":"P1","status":"todo","title":"t","created_at":"2026-01-01T00:00:00.000Z","metadata":{}}' > "$c/backlog/tasks.jsonl"
printf '5\n' > "$c/backlog/.next-id"
expect_fail "$c" "N1 缺 fingerprint" "metadata.fingerprint 必填"

# N2 活跃池残留 done → 拒绝
c=$(mkcase neg-active-done)
printf '%s\n' '{"id":"B001","category":"Task","priority":"P1","status":"done","title":"t","created_at":"2026-01-01T00:00:00.000Z","evidence":"x","closed_at":"2026-01-02T00:00:00.000Z","metadata":{"fingerprint":"f"}}' > "$c/backlog/tasks.jsonl"
printf '5\n' > "$c/backlog/.next-id"
expect_fail "$c" "N2 活跃池 done 残留" "活跃池不得残留 done"

# N3 孤儿租约（活跃池无此记录）→ doctor 对账拒绝
c=$(mkcase neg-orphan-lease)
: > "$c/backlog/tasks.jsonl"
printf '5\n' > "$c/backlog/.next-id"
mkdir -p "$c/backlog/.locks"
printf '%s' '{"task_id":"B009","owner":"me","session_id":"me","pid":1,"acquired_at":"2026-01-01T00:00:00.000Z","heartbeat_at":"2026-01-01T00:00:00.000Z","ttl_ms":7200000}' > "$c/backlog/.locks/B009.lock"
expect_fail "$c" "N3 孤儿租约" "残留租约"

# N4 记录 ID 越过高水位 → lint 拒绝
c=$(mkcase neg-highwater)
printf '%s\n' '{"id":"B010","category":"Task","priority":"P1","status":"todo","title":"t","created_at":"2026-01-01T00:00:00.000Z","metadata":{"fingerprint":"f"}}' > "$c/backlog/tasks.jsonl"
printf '10\n' > "$c/backlog/.next-id"
expect_fail "$c" "N4 高水位越界" "越过高水位"

# N5 无账本 → 明确跳过并放行（迁移期语义）
c="$TMPDIR_SPEC/no-ledger"
mkdir -p "$c"
expect_pass "$c" "N5 无账本（迁移期跳过）"
grep -qF '跳过' "$c/gate.out" || fail "N5 跳过提示缺失"

# N6 无 node → fail-closed 拒绝
c=$(mkcase no-node)
valid_record > "$c/backlog/tasks.jsonl"
printf '5\n' > "$c/backlog/.next-id"
if env -i PATH=/nonexistent PONYGO_WORKSPACE_ROOT="$c" PONY_BACKLOG_ROOT="$c" "$(command -v bash)" "$GATE" >"$c/gate.out" 2>&1; then
  cat "$c/gate.out" >&2
  fail "N6 无 node 未被拒绝（fail-open）"
fi
grep -qF 'fail-closed' "$c/gate.out" || fail "N6 拒绝文案缺失 fail-closed"

# N7 锁存在但记录非 in_progress → 租约-状态互斥拒绝
c=$(mkcase neg-lease-status-mismatch)
valid_record > "$c/backlog/tasks.jsonl"
printf '5\n' > "$c/backlog/.next-id"
mkdir -p "$c/backlog/.locks"
printf '%s' '{"task_id":"B001","owner":"me","session_id":"me","pid":1,"acquired_at":"2026-01-01T00:00:00.000Z","heartbeat_at":"2026-01-01T00:00:00.000Z","ttl_ms":7200000}' > "$c/backlog/.locks/B001.lock"
expect_fail "$c" "N7 锁存而记录非 in_progress" "存在租约锁但记录状态"

# N8 record 缺 --fingerprint → exit 1（缺省会退化为"所有任务共用一个指纹"并被静默合并成一条）
c=$(mkcase neg-record-fingerprint)
: > "$c/backlog/tasks.jsonl"
if bl "$c" record --category Task --title "无指纹" >"$c/n8.out" 2>&1; then
  cat "$c/n8.out" >&2
  fail "N8 record 缺 --fingerprint 未被拒绝（静默合并风险）"
fi
grep -qF 'fingerprint' "$c/n8.out" || { cat "$c/n8.out" >&2; fail "N8 拒绝文案未提 fingerprint"; }

# H pre-commit 接线：门在场必须放行，门缺失必须 fail-closed 拒绝
command -v git >/dev/null 2>&1 || fail "H 需要 git 才能验证 pre-commit 接线"
h="$TMPDIR_SPEC/hook-wiring"
mkdir -p "$h"
(
  cd "$h"
  git init -q
  git config user.email spec@example.com
  git config user.name spec
  git config core.hooksPath .githooks
  mkdir -p .githooks .meta/gates backlog scripts
  cp "$ROOT/.githooks/pre-commit" .githooks/pre-commit
  chmod +x .githooks/pre-commit
  cp "$CLI" scripts/backlog.mjs
  cp "$GATE" .meta/gates/backlog-gate.sh
  printf '5\n' > backlog/.next-id
  valid_record > backlog/tasks.jsonl
  echo hello > a.txt
  git add a.txt
)
if ! ( cd "$h" && git commit -qm control ) >"$h/hook.out" 2>&1; then
  cat "$h/hook.out" >&2
  fail "H 门在场时合法提交被误拒"
fi
# H2 门在场 + 账本非法 → commit 必须被拒，且拒绝证据来自门本身：
# 这一步杀掉「钩子里只判断文件存在、没有真正调用门」的接线 mutant（把调用行换成 true/|| true 仍会全绿）。
( cd "$h" && printf '%s\n' '{"id":"B001","category":"Task","priority":"P1","status":"todo","title":"t","created_at":"2026-01-01T00:00:00.000Z","metadata":{}}' > backlog/tasks.jsonl && echo bad > c.txt && git add c.txt )
if ( cd "$h" && git commit -qm bad-ledger ) >"$h/hook2a.out" 2>&1; then
  cat "$h/hook2a.out" >&2
  fail "H2 账本非法时提交未被拒绝（钩子可能未真正执行门）"
fi
grep -qF 'backlog-gate: FAIL' "$h/hook2a.out" || {
  cat "$h/hook2a.out" >&2
  fail "H2 拒绝证据不含 backlog-gate: FAIL（门未被执行）"
}
( cd "$h" && rm -f .meta/gates/backlog-gate.sh && echo world > b.txt && git add b.txt )
if ( cd "$h" && git commit -qm blocked ) >"$h/hook2.out" 2>&1; then
  cat "$h/hook2.out" >&2
  fail "H 门缺失时提交未被 fail-closed 拒绝"
fi
grep -qF 'fail-closed' "$h/hook2.out" || fail "H 拒绝文案缺失 fail-closed"

echo "backlog-gate.spec: PASS（P1 合法账本放行 + P2 编号下限 B001 + P3 真实操作闭环 + P4 实例级在场 + P5 接线 + N1–N8 全部按预期拒绝/跳过 + H/H2 pre-commit 接线与真执行）"
exit 0
