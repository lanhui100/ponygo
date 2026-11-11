#!/usr/bin/env bash
# carrier-audit 独立黑盒验收公共层：真实 CLI、临时仓、真断言、自动清理。
# PONYGO_CLI 可指向只读基线副本；默认测试当前工作树的 ponygo。
set -u

CARRIER_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$CARRIER_DIR/../../.." && pwd)
CLI_BIN=${PONYGO_CLI:-$ROOT/ponygo}

# P0-2/P0-3 夹具（2026-11-11）：L2 判据 2.3 现要求 ≥1 实例门 + 含拒绝断言的 spec，单点收口在此。
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/p0_instance_gate.sh"

# P0-2/P0-3 夹具（2026-11-11）：L2 判据 2.3 现要求 ≥1 实例门 + 含拒绝断言的 spec，单点收口在此。
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/p0_instance_gate.sh"

SBASE=$(mktemp -d) || { echo "无法创建 carrier-audit 临时目录" >&2; exit 1; }
trap 'rm -rf "$SBASE"' EXIT
new_case() { mktemp -d "$SBASE/case.XXXXXX"; }

GITCONF=$(mktemp "$SBASE/gitconf.XXXXXX") || exit 1
: > "$GITCONF"
export GIT_CONFIG_GLOBAL="$GITCONF" GIT_CONFIG_SYSTEM="$GITCONF"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf 'FAIL %s\n' "$1"; }
assert_eq() { # <描述> <期望> <实得>
  if [ "$2" = "$3" ]; then ok "$1"; else bad "$1（期望 [$2] 实得 [$3]）"; fi
}
assert_rc_is() { assert_eq "$1（exit）" "$2" "${3:-?}"; }
assert_contains() { # <描述> <整体> <子串>
  case "$2" in *"$3"*) ok "$1" ;; *) bad "$1（未找到 [$3]）" ;; esac
}
assert_not_contains() { # <描述> <整体> <子串>
  case "$2" in *"$3"*) bad "$1（不应出现 [$3]）" ;; *) ok "$1" ;; esac
}
assert_matches() { # <描述> <整体> <ERE>
  if printf '%s\n' "$2" | grep -Eq -- "$3"; then ok "$1"; else bad "$1（无匹配 /$3/）"; fi
}
assert_not_matches() { # <描述> <整体> <ERE>
  if printf '%s\n' "$2" | grep -Eq -- "$3"; then bad "$1（不应匹配 /$3/）"; else ok "$1"; fi
}
assert_exists() { [ -e "$2" ] && ok "$1" || bad "$1（缺失 $2）"; }
assert_missing() { [ ! -e "$2" ] && ok "$1" || bad "$1（不应存在 $2）"; }
assert_file() { [ -f "$2" ] && ok "$1" || bad "$1（不是文件 $2）"; }
assert_no_crash() {
  assert_not_matches "$1" "$2" 'syntax error|command not found|unbound variable|integer expression expected|bad substitution|Segmentation fault|core dumped'
}

R_OUT=""; R_ERR=""; R_RC=0
run_in() { # <dir> [VAR=val ...] <args...>；合并人读 stdout/stderr
  local dir="$1"; shift
  local -a envs=()
  while [ $# -gt 0 ]; do
    case "$1" in *=*) envs+=("$1"); shift ;; *) break ;; esac
  done
  R_OUT=$(cd "$dir" && env ${envs[@]+"${envs[@]}"} bash "$CLI_BIN" "$@" 2>&1)
  R_RC=$?; R_ERR=""
}
run_json() { # <dir> [VAR=val ...] audit ... --json；stdout 与人读 stderr 分流
  local dir="$1"; shift
  local -a envs=()
  while [ $# -gt 0 ]; do
    case "$1" in *=*) envs+=("$1"); shift ;; *) break ;; esac
  done
  local ef
  ef=$(mktemp "$SBASE/stderr.XXXXXX") || { R_RC=1; R_OUT=""; R_ERR="无法创建 stderr 文件"; return 1; }
  R_OUT=$(cd "$dir" && env ${envs[@]+"${envs[@]}"} bash "$CLI_BIN" "$@" 2>"$ef")
  R_RC=$?
  R_ERR=$(cat "$ef" 2>/dev/null)
}

json_assert() { # <描述> <json> <python 语句；d=已解析对象，fail=[]>
  local desc="$1" json="$2" code="$3"
  if printf '%s' "$json" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception as e:
    print("JSON parse error: %s" % e)
    sys.exit(1)
fail = []
exec(sys.argv[1])
if fail:
    print("; ".join(str(x) for x in fail))
    sys.exit(1)
' "$code"; then ok "$desc"; else bad "$desc"; fi
}
json_get() { # <json> <python 表达式；d=已解析对象>
  printf '%s' "$1" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(eval(sys.argv[1]))' "$2" 2>/dev/null
}
assert_json_shape() { # <描述> <rc> <json>：单行、schema、真实 exit、稳定 drift 键型
  local desc="$1" rc="$2" json="$3"
  assert_eq "$desc：stdout 恰一行" 1 "$(printf '%s\n' "$json" | grep -c '')"
  json_assert "$desc：audit/1 + exit 同源 + drift 键型不变" "$json" "
if d.get('schema') != 'ponygo.audit/1': fail.append('schema=%r' % d.get('schema'))
if d.get('exit') != $rc: fail.append('exit=%r rc=$rc' % d.get('exit'))
dr = d.get('drift')
if not isinstance(dr, dict): fail.append('drift 非对象')
elif set(dr) != {'count','files'}: fail.append('drift keys=%r' % sorted(dr))
elif not isinstance(dr.get('count'), int) or isinstance(dr.get('count'), bool): fail.append('drift.count 非整数')
elif not isinstance(dr.get('files'), list): fail.append('drift.files 非数组')
"
}
hits_of() { printf '%s\n' "$1" | sed -n 's/.*命中 \([0-9][0-9]*\) \/ [0-9][0-9]* 项.*/\1/p' | head -n1; }
total_of() { printf '%s\n' "$1" | sed -n 's/.*命中 [0-9][0-9]* \/ \([0-9][0-9]*\) 项.*/\1/p' | head -n1; }
decision_count() {
  find "$1/.agents/notes" -type f -name '*.md' ! -name 'README.md' ! -name 'AGENTS.md' ! -name '*.zh.md' 2>/dev/null | wc -l | tr -d ' '
}

git_at() { local dir="$1"; shift; (cd "$dir" && git "$@"); }
write_adr() { # <case> <相对 notes 路径>
  local f="$1/.agents/notes/$2"
  mkdir -p "$(dirname "$f")"
  cat > "$f" <<'ADREOF'
# 2026-01-01 合法夹具决策

Status: implemented

## Context

独立黑盒验收需要一条真实决策。

## Decision

采用临时仓与真实 CLI，不伪造判定结果。

## Alternatives considered

- 无决策夹具：无法提供正向对照。
ADREOF
}
clear_decisions() {
  find "$1/.agents/notes" -type f -name '*.md' ! -name 'README.md' ! -name 'AGENTS.md' ! -name '*.zh.md' -delete
}
make_gov_repo() { # <case> [level]；真 init + 一条合法 ADR
  local dir="$1" lvl="${2:-1}"
  mkdir -p "$dir"
  git_at "$dir" init -q . >/dev/null 2>&1 || { bad "夹具 git init 失败：$dir"; return 1; }
  run_in "$dir" init
  assert_rc_is "夹具：ponygo init" 0 "$R_RC"
  [ "$R_RC" -eq 0 ] || return 1
  printf 'level: %s\n' "$lvl" > "$dir/.meta/meta.yaml"
  [ "${lvl:-1}" -ge 2 ] && add_instance_gate "$dir"   # P0-2：L2 需 ≥1 个实例门（框架门资产不计）
  write_adr "$dir" implemented/architecture/2026-01-01-fixture.md
  assert_file "夹具：真实 ADR 已落盘" "$dir/.agents/notes/implemented/architecture/2026-01-01-fixture.md"
  assert_eq "夹具：真实决策数为 1" 1 "$(decision_count "$dir")"
}
remove_specs() { find "$1/.meta/gates" -maxdepth 1 -type f -name '*.spec.*' -delete; }

finish() {
  printf '##CASE %s pass=%s fail=%s\n' "$(basename "$0")" "$PASS" "$FAIL"
  if [ "$FAIL" -eq 0 ]; then exit 0; else exit 1; fi
}
