#!/usr/bin/env bash
# ============================================================
# tests/acceptance/deferred/lib.sh
# F8（audit/status --json）/ F9（2.6 AI 常载命约投影）/ F10（observe probe）
# 验收套件的公共夹具与断言。约定与 tests/acceptance/auditfix 同风格：
#   - 纯 bash + 零依赖（F8/F10 按契约需要 python3：JSON 解析与本地探针服务）；
#   - 每个用例在 mktemp -d 里造仓，用 bash "$ROOT/ponygo" 调用；
#   - 断言只认真实退出码 + 输出子串/文件副作用；失败打印 `FAIL <用例名>`，脚本末 exit 1；
#   - 严禁 sleep 轮询：本地探针服务的就绪同步走 FIFO 阻塞读，不是轮询。
# ============================================================
set -u

DEF_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$DEF_DIR/../../.." && pwd)
STUB_SKILL_SRC="$DEF_DIR/stub-skill"
PROBE_SERVER="$DEF_DIR/probe_server.py"

CLI() { bash "$ROOT/ponygo" "$@"; }

SBASE=$(mktemp -d) || { echo "无法创建临时目录" >&2; exit 1; }
trap 'stop_probe_server 2>/dev/null || true; rm -rf "$SBASE"' EXIT
new_case() { mktemp -d "$SBASE/case.XXXXXX"; }

# git 配置消毒（不得读机器全局配置）
GITCONF=$(mktemp "$SBASE/gitconf.XXXXXX") || exit 1
: > "$GITCONF"
export GIT_CONFIG_GLOBAL="$GITCONF" GIT_CONFIG_SYSTEM="$GITCONF"

# ---------- 断言 ----------
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf 'FAIL %s\n' "$1"; }

assert_eq() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1（期望 [$2] 实得 [$3]）"; fi; }
assert_contains() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1（未找到 [$3]）" ;; esac; }
assert_not_contains() { case "$2" in *"$3"*) bad "$1（不应出现 [$3]）" ;; *) ok "$1" ;; esac; }
assert_exists() { [ -e "$2" ] && ok "$1" || bad "$1（缺失 $2）"; }
assert_missing() { [ ! -e "$2" ] && ok "$1" || bad "$1（不应存在 $2）"; }
assert_zero() { [ "${2:-1}" = "0" ] && ok "$1" || bad "$1（期望 exit 0，实得 ${2:-?}）"; }
assert_nonzero() { [ "${2:-0}" != "0" ] && ok "$1" || bad "$1（期望非零，实得 0）"; }
assert_rc_is() { assert_eq "$1（exit）" "$2" "${3:-?}"; }
assert_matches() { if printf '%s\n' "$2" | grep -Eq -- "$3"; then ok "$1"; else bad "$1（无匹配 /$3/）"; fi; }
assert_not_matches() { if printf '%s\n' "$2" | grep -Eq -- "$3"; then bad "$1（不应匹配 /$3/）"; else ok "$1"; fi; }
assert_no_crash() {
  assert_not_matches "$1" "$2" 'syntax error|command not found|unbound variable|integer expression expected|bad substitution|Traceback \(most recent call last\)'
}
md5_of() { if [ -f "$1" ]; then md5sum "$1" 2>/dev/null | awk '{print $1}'; else printf 'MISSING'; fi; }

# ---------- 调用 ponygo ----------
R_OUT=""; R_RC=0; R_ERR=""
# run_in <dir> [VAR=val ...] <args...>：stdout+stderr 合并
run_in() {
  local dir="$1"; shift
  local -a envs=()
  while [ $# -gt 0 ]; do case "$1" in *=*) envs+=("$1"); shift ;; *) break ;; esac; done
  R_OUT=$(cd "$dir" && env ${envs[@]+"${envs[@]}"} bash "$ROOT/ponygo" "$@" 2>&1)
  R_RC=$?
}
# run_split <dir> [VAR=val ...] <args...>：R_OUT=stdout（纯净），R_ERR=stderr
run_split() {
  local dir="$1"; shift
  local -a envs=()
  while [ $# -gt 0 ]; do case "$1" in *=*) envs+=("$1"); shift ;; *) break ;; esac; done
  local errf; errf=$(mktemp "$SBASE/err.XXXXXX")
  R_OUT=$(cd "$dir" && env ${envs[@]+"${envs[@]}"} bash "$ROOT/ponygo" "$@" 2>"$errf")
  R_RC=$?
  R_ERR=$(cat "$errf" 2>/dev/null)
  rm -f "$errf"
}

# ---------- 文件树快照 ----------
snap() {
  ( cd "$1" 2>/dev/null || exit 1
    find . -path ./.git -prune -o -type f -print 2>/dev/null | LC_ALL=C sort | while IFS= read -r f; do
      printf '%s|%s\n' "$f" "$(cksum < "$f" 2>/dev/null)"
    done )
}
snap_added() {
  LC_ALL=C comm -13 <(printf '%s\n' "$1" | LC_ALL=C sort) <(printf '%s\n' "$2" | LC_ALL=C sort) | wc -l | tr -d ' '
}

# ---------- 夹具 ----------
# 治理仓：git 仓 + 真 ponygo init 骨架 + 一条合法 ADR + 声明级（缺省 L2）
make_gov_repo() { # <dir> [level]
  local dir="$1" lvl="${2:-2}" rc=0
  ( cd "$dir" && git init -q . >/dev/null 2>&1 ) || { bad "夹具失败：git init（$dir）"; return 1; }
  ( cd "$dir" && bash "$ROOT/ponygo" init >/dev/null 2>&1 ) || rc=$?
  [ "$rc" -eq 0 ] || { bad "夹具失败：ponygo init 在 $dir 退出 $rc"; return 1; }
  mkdir -p "$dir/.agents/notes/implemented/architecture"
  cat > "$dir/.agents/notes/implemented/architecture/2026-01-01-fixture-adr.md" <<'ADREOF'
# 2026-01-01 夹具 ADR

Status: implemented

## Context

deferred 验收夹具用的合法决策记录（满足 1.1–1.9 机械判据）。

## Decision

采用最小夹具。

## Alternatives considered

- 不建夹具：判定器无法被验证。
ADREOF
  printf 'level: %s\n' "$lvl" > "$dir/.meta/meta.yaml"
  return 0
}
# 夹具自检：等价基线本身必须是通过态（后续变红才可归因到被测判据）
gov_repo() { # <dir> [level]
  make_gov_repo "$1" "${2:-2}" || return 1
  run_in "$1" status
  assert_zero "夹具自检：等价基线 ponygo status exit 0" "$R_RC"
  return 0
}

# 跑一段 python3 断言脚本（stdin 传 JSON 文本）；失败打印其输出
json_assert() { # <描述> <json 文本> <python 断言代码（变量 d 为已解析 dict）>
  local desc="$1" body="$2" code="$3" out rc=0
  out=$(JSON_TEXT="$body" python3 - "$code" <<'PY' 2>&1
import json, os, sys
code = sys.argv[1]
text = os.environ.get("JSON_TEXT", "")
try:
    d = json.loads(text)
except Exception as exc:
    print("JSON-PARSE-ERROR: %s" % exc)
    sys.exit(1)
ns = {"d": d, "fail": []}
exec(code, ns)
for m in ns.get("fail", []):
    print("ASSERT-FAIL: %s" % m)
sys.exit(1 if ns.get("fail") else 0)
PY
) || rc=$?
  if [ "$rc" -eq 0 ]; then ok "$desc"; else bad "$desc（$out）"; fi
}

# ---------- 本地 OTLP 探针接收器（零外网；FIFO 就绪同步，无 sleep 轮询）----------
PROBE_PID=""; PROBE_PORT=""; PROBE_CAP=""; PROBE_FIFO=""; PROBE_ERR=""
start_probe_server() { # <case-dir> [http_status]
  local dir="$1" st="${2:-200}"
  PROBE_CAP="$dir/.probe-capture.txt"; : > "$PROBE_CAP"
  PROBE_FIFO="$dir/.probe-port.fifo"; rm -f "$PROBE_FIFO"
  if ! mkfifo "$PROBE_FIFO" 2>/dev/null; then bad "夹具失败：无法创建 FIFO（$PROBE_FIFO）"; return 1; fi
  PROBE_ERR="$dir/.probe-server.err"; : > "$PROBE_ERR"
  STUB_HTTP_STATUS="$st" python3 "$PROBE_SERVER" "$PROBE_FIFO" "$PROBE_CAP" 2>"$PROBE_ERR" &
  PROBE_PID=$!
  # 阻塞读：服务端绑定端口后写入端口号（就绪即返回），不是轮询
  read -r PROBE_PORT < "$PROBE_FIFO" || PROBE_PORT=""
  if [ -z "$PROBE_PORT" ]; then
    bad "夹具失败：探针服务未报告端口（见 $PROBE_ERR）"
    return 1
  fi
  return 0
}
stop_probe_server() {
  if [ -n "${PROBE_PID:-}" ]; then
    kill "$PROBE_PID" 2>/dev/null || true
    wait "$PROBE_PID" 2>/dev/null || true
    PROBE_PID=""
  fi
  if [ -n "${PROBE_FIFO:-}" ]; then rm -f "$PROBE_FIFO"; PROBE_FIFO=""; fi
}
probe_requests() { # → 抓到的请求数
  if [ ! -f "${PROBE_CAP:-}" ]; then printf '0'; return 0; fi
  grep -c '^---REQ---$' "$PROBE_CAP" 2>/dev/null | tr -d ' '
}

finish() {
  stop_probe_server 2>/dev/null || true
  printf '##CASE %s pass=%s fail=%s\n' "$(basename "$0")" "$PASS" "$FAIL"
  if [ "$FAIL" -eq 0 ]; then exit 0; else exit 1; fi
}
