#!/usr/bin/env bash
# gate-hardening 独立验收公共层：真实资产、真实退出码、临时夹具、自动清理。
set -u

GH_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$GH_DIR/../../.." && pwd)
CLI_BIN=${PONYGO_CLI:-$ROOT/ponygo}

# P0-2/P0-3 夹具（2026-11-11）：L2 判据 2.3 现要求 ≥1 实例门 + 含拒绝断言的 spec，单点收口在此。
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/p0_instance_gate.sh"
SBASE=$(mktemp -d) || { echo "gate-hardening: mktemp 失败" >&2; exit 1; }
trap 'rm -rf "$SBASE"' EXIT
new_case() { mktemp -d "$SBASE/case.XXXXXX"; }

GITCONF=$(mktemp "$SBASE/gitconf.XXXXXX") || exit 1
: > "$GITCONF"
export GIT_CONFIG_GLOBAL="$GITCONF" GIT_CONFIG_SYSTEM="$GITCONF"

PASS=0
FAIL=0
ok() { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf 'FAIL %s\n' "$1" >&2; }
assert_eq() {
  if [ "$2" = "$3" ]; then ok "$1"; else bad "$1（期望 [$2]，实得 [$3]）"; fi
}
assert_rc_is() { assert_eq "$1（exit）" "$2" "${3:-?}"; }
assert_zero() { assert_rc_is "$1" 0 "${2:-?}"; }
assert_nonzero() {
  if [ "${2:-0}" != "0" ]; then ok "$1（exit=${2}）"; else bad "$1（期望非零，实得 0）"; fi
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
assert_exists() { [ -e "$2" ] && ok "$1" || bad "$1（缺失 $2）"; }
assert_missing() { [ ! -e "$2" ] && ok "$1" || bad "$1（不应存在 $2）"; }
assert_file() { [ -f "$2" ] && ok "$1" || bad "$1（不是文件 $2）"; }

R_OUT=""
R_ERR=""
R_RC=0
run_cli() { # <dir> [VAR=value ...] <args...>，合并人读输出
  local dir="$1"
  shift
  local -a envs=()
  while [ $# -gt 0 ]; do
    case "$1" in *=*) envs+=("$1"); shift ;; *) break ;; esac
  done
  R_OUT=$(cd "$dir" && env ${envs[@]+"${envs[@]}"} bash "$CLI_BIN" "$@" 2>&1)
  R_RC=$?
  R_ERR=""
}
run_json() { # <dir> [VAR=value ...] audit ... --json，stdout/stderr 分流
  local dir="$1"
  shift
  local -a envs=()
  while [ $# -gt 0 ]; do
    case "$1" in *=*) envs+=("$1"); shift ;; *) break ;; esac
  done
  local ef
  ef=$(mktemp "$SBASE/stderr.XXXXXX") || { R_RC=1; R_OUT=""; R_ERR="mktemp stderr 失败"; return 1; }
  R_OUT=$(cd "$dir" && env ${envs[@]+"${envs[@]}"} bash "$CLI_BIN" "$@" 2>"$ef")
  R_RC=$?
  R_ERR=$(cat "$ef" 2>/dev/null)
}
json_assert() { # <描述> <json> <python: d=对象, fail=[]>
  local desc="$1" json="$2" code="$3"
  if printf '%s' "$json" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception as exc:
    print("JSON parse error: %s" % exc)
    sys.exit(1)
fail = []
exec(sys.argv[1])
if fail:
    print("; ".join(str(x) for x in fail))
    sys.exit(1)
' "$code"; then ok "$desc"; else bad "$desc"; fi
}
json_get() {
  printf '%s' "$1" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(eval(sys.argv[1]))' "$2" 2>/dev/null
}
hits_of() {
  printf '%s\n' "$1" | sed -n 's/.*命中 \([0-9][0-9]*\) \/ [0-9][0-9]* 项.*/\1/p' | head -n1
}

make_gov_repo() { # <dir> [level]：真实 ponygo init + 合法 ADR
  local dir="$1" lvl="${2:-1}"
  mkdir -p "$dir"
  (cd "$dir" && git init -q . >/dev/null 2>&1) || { bad "夹具 git init 失败：$dir"; return 1; }
  run_cli "$dir" init
  assert_rc_is "夹具：ponygo init" 0 "$R_RC"
  [ "$R_RC" -eq 0 ] || return 1
  printf 'level: %s\n' "$lvl" > "$dir/.meta/meta.yaml"
  # P0-2：level ≥2 的实例必须有 ≥1 个实例门（框架门资产不计），否则 2.3 恒 FAIL
  [ "${lvl:-1}" -ge 2 ] && add_instance_gate "$dir"
  mkdir -p "$dir/.agents/notes/implemented/architecture"
  cat > "$dir/.agents/notes/implemented/architecture/2026-01-01-fixture.md" <<'ADREOF'
# 2026-01-01 gate-hardening 合法夹具

Status: implemented

## Context

独立验收需要一条真实决策记录。

## Decision

采用真实 init 骨架与临时仓，不伪造判定输出。

## Alternatives considered

- 手写空骨架：无法提供可信正向对照。
ADREOF
}
write_gate_pair() { # <dir> <stem> <ext>
  local dir="$1" stem="$2" ext="$3"
  cat > "$dir/.meta/gates/$stem.$ext" <<'GATEEOF'
#!/usr/bin/env bash
# 验收夹具：有实质内容的门，不依赖其执行来判定配对。
exit 0
GATEEOF
  cat > "$dir/.meta/gates/$stem.spec.$ext" <<'SPECEOF'
#!/usr/bin/env bash
# 验收夹具：合法负样本 spec 配对。
# P0-3（2026-11-11）：spec 必须含拒绝断言（exit/return [1-9]），否则 2.3 判 FAIL——
# 只 exit 0 的 spec 恒绿，证明不了门会拒绝非法样本。
printf 'fixture negative sample rejected\n'
if false; then
  exit 1
fi
exit 0
SPECEOF
}

finish() {
  printf '##CASE %s pass=%s fail=%s\n' "$(basename "$0")" "$PASS" "$FAIL"
  if [ "$FAIL" -eq 0 ]; then exit 0; else exit 1; fi
}
