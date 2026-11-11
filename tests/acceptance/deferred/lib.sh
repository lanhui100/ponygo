#!/usr/bin/env bash
# Windows 编码硬化（CI 实跑 run 43031069740）：cp1252 控制台下 python3 打印中文会抛
# UnicodeEncodeError → rc=1 且无 stdout（gh2 3/1、gh3 9/1、gh6 83/8 均为其连锁反应）。
# 在调用任何 python3 之前强制 UTF-8；standalone 执行时由本文件/lib.sh 顶部覆盖生效。
export PYTHONUTF8=1 PYTHONIOENCODING=utf-8
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

# P0-2/P0-3 夹具（2026-11-11）：L2 判据 2.3 现要求 ≥1 实例门 + 含拒绝断言的 spec，单点收口在此。
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/p0_instance_gate.sh"

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
# 结论行（status/audit 内嵌级自洽验证的唯一结论面）
conclusion_of() { printf '%s\n' "$1" | grep '^级自洽验证：' | head -n1; }
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
  # P0-2：level ≥2 的实例必须有 ≥1 个实例门（框架门资产不计），否则 2.3 恒 FAIL
  [ "${lvl:-2}" -ge 2 ] && add_instance_gate "$dir"
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

# 写一份带 service 的最小归属声明（probe 可从中取 service.name）
write_decl_with_service() { # <dir> [service]
  local dir="$1" svc="${2:-svc-a}"
  mkdir -p "$dir/docs"
  cat > "$dir/docs/observability.yaml" <<DECLEOF
service: ${svc}
kind: cli
dimensions:
  metrics:
    applicable: false
    reason: 指标由 k8s 侧采集
  tracing:
    applicable: false
    reason: 由网关统一接入
  logs:
    applicable: false
    reason: 走集群采集
  issues:
    applicable: false
    reason: 无前端
DECLEOF
}

# 取 JSON 里的数组/标量（dotted path；数组逐行输出）
json_list() { # <json 文本> <dotted.path>
  JSON_TEXT="$1" python3 - "$2" <<'PY'
import json, os, sys
try:
    cur = json.loads(os.environ.get("JSON_TEXT", ""))
except Exception:
    sys.exit(1)
for part in sys.argv[1].split("."):
    if isinstance(cur, dict) and part in cur:
        cur = cur[part]
    else:
        cur = None
        break
if isinstance(cur, list):
    for item in cur:
        print(item)
elif cur is not None:
    print(cur)
PY
}

# 进程 argv 快照（读 /proc/*/cmdline，避免 ps args 截断）；可带过滤正则
# 注意（TEST-DEFECT 修复）：正则**经文件**传给 grep（-f），不能用 `grep -E "$pat"`——
# 否则 grep 自身的 /proc/<pid>/cmdline 里就含该字面量，扫描进程表时会把自己扫出来，
# 让「token 不得出现在任何进程 argv」变成恒假（本仓实测：探针真未泄漏，断言却红）。
proc_argv_snapshot() { # [过滤正则]
  local pat="${1:-.}" pf
  pf=$(mktemp 2>/dev/null) || pf=""
  if [ -n "$pf" ]; then
    printf '%s\n' "$pat" > "$pf"
    { for pc in /proc/[0-9]*/cmdline; do { tr '\0' ' ' < "$pc"; } 2>/dev/null || true; printf '\n'; done; } \
      | grep -E -f "$pf" || true
    rm -f "$pf"
  else
    { for pc in /proc/[0-9]*/cmdline; do { tr '\0' ' ' < "$pc"; } 2>/dev/null || true; printf '\n'; done; } \
      | grep -E -- "$pat" || true
  fi
}

# ---------- 本地 OTLP 探针接收器（零外网；FIFO 就绪同步，无 sleep 轮询）----------
PROBE_PID=""; PROBE_PORT=""; PROBE_CAP=""; PROBE_FIFO=""; PROBE_ERR=""; PROBE_NOTIFY=""
start_probe_server() { # <case-dir> [http_status] [delay_seconds]
  local dir="$1" st="${2:-200}" delay="${3:-0}"
  PROBE_CAP="$dir/.probe-capture.txt"; : > "$PROBE_CAP"
  PROBE_FIFO="$dir/.probe-port.fifo"; rm -f "$PROBE_FIFO"
  if ! mkfifo "$PROBE_FIFO" 2>/dev/null; then bad "夹具失败：无法创建 FIFO（$PROBE_FIFO）"; return 1; fi
  PROBE_NOTIFY="$dir/.probe-notify.fifo"; rm -f "$PROBE_NOTIFY"
  if ! mkfifo "$PROBE_NOTIFY" 2>/dev/null; then bad "夹具失败：无法创建 notify FIFO"; return 1; fi
  PROBE_ERR="$dir/.probe-server.err"; : > "$PROBE_ERR"
  STUB_HTTP_STATUS="$st" STUB_DELAY_SECONDS="$delay" \
    python3 "$PROBE_SERVER" "$PROBE_FIFO" "$PROBE_CAP" "$PROBE_NOTIFY" 2>"$PROBE_ERR" &
  PROBE_PID=$!
  # 阻塞读：服务端绑定端口后写入端口号（就绪即返回），不是轮询
  read -r PROBE_PORT < "$PROBE_FIFO" || PROBE_PORT=""
  if [ -z "$PROBE_PORT" ]; then
    bad "夹具失败：探针服务未报告端口（见 $PROBE_ERR）"
    return 1
  fi
  exec 9<>"$PROBE_NOTIFY"  # 读写方式打开：FIFO 的 read-only open 会阻塞到有写者，故用 <>
  return 0
}
# 阻塞等待「接收器已收到一个请求」（read -t 超时兜底，不是 sleep 轮询）
probe_wait_request() { read -r -t 30 -u 9 _ 2>/dev/null; }
stop_probe_server() {
  { exec 9<&-; } 2>/dev/null || true
  if [ -n "${PROBE_PID:-}" ]; then
    kill "$PROBE_PID" 2>/dev/null || true
    wait "$PROBE_PID" 2>/dev/null || true
    PROBE_PID=""
  fi
  [ -n "${PROBE_FIFO:-}" ] && rm -f "$PROBE_FIFO"
  [ -n "${PROBE_NOTIFY:-}" ] && rm -f "$PROBE_NOTIFY"
  PROBE_FIFO=""; PROBE_NOTIFY=""
}
# curl argv 观测桩（TEST-DEFECT 修复）：/proc 时间窗取样不可靠（curl 可能在取样前已退出），
# 改用 PATH 前置的 curl 包装桩——它把**自己的 argv** 追加到日志，再 exec 真 curl。
# 这样「token 不得进 argv」是**确定性**断言，不依赖进程存活窗口。
install_curl_shim() { # <bindir> <logfile>
  local bindir="$1" logf="$2" real=""
  real=$(command -v curl 2>/dev/null || true)
  [ -n "$real" ] || { bad "夹具失败：环境无 curl（无法安装观测桩）"; return 1; }
  mkdir -p "$bindir" || return 1
  : > "$logf"
  {
    printf '#!/usr/bin/env bash\n'
    printf '# 观测桩：记录 argv 后原样转发给真 curl（argv 是断言对象，这里不脱敏）\n'
    printf 'printf "%%s\\n" "$*" >> %q\n' "$logf"
    printf 'exec %q "$@"\n' "$real"
  } > "$bindir/curl"
  chmod +x "$bindir/curl" || return 1
  return 0
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
