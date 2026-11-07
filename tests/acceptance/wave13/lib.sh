#!/usr/bin/env bash
# ============================================================
# tests/acceptance/wave13/lib.sh
# Wave13（零新增旗标：归档封印 A6/A7 + 证据诚实化）验收套件的公共夹具与断言。
#
# 契约真源：.dev-team/contract-matrix-wave13.md（冻结；唯一断言来源）
#           + .dev-team/plan-wave13.md（架构意图，冲突时以契约为准）。
#
# 约定（与 tests/acceptance/auditfix、deferred 同风格）：
#   - 纯 bash + 零依赖：**不用** jq / python3 / 网络；JSON 断言一律对单行 stdout 做
#     逐字节子串/正则断言（契约已冻结字段名与顺序），解析失败即红，绝不「解析不了就跳过」；
#   - 每个用例在 mktemp -d 里造仓，用 bash "$ROOT/ponygo" 调用（不吃 exec bit / shebang）；
#   - 断言只认真实退出码 + 输出子串/文件副作用；失败打印 `FAIL <用例名>（期望 … 实得 …）`；
#   - 严禁 sleep 轮询、严禁「跑了没报错即 pass」、严禁吞异常；
#   - git 一律消毒：进程内导出 GIT_CONFIG_GLOBAL/SYSTEM 指向空文件（run.sh 的 sanitize_git 同源），
#     不读机器全局配置，跨机同结论。
# ============================================================
set -u

W13_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$W13_DIR/../../.." && pwd)

CLI() { bash "$ROOT/ponygo" "$@"; }

# 归档封印资产的契约路径（plan §1 P0-1；契约确认前不得改写）
A6_REL=".meta/gates/archive-verify.sh"
A7_REL=".meta/gates/archive-verify.spec.sh"
MANIFEST_REL=".agents/notes/archived/manifest.sha256"
ARCHIVED_REL=".agents/notes/archived"

SBASE=$(mktemp -d) || { echo "无法创建临时目录" >&2; exit 1; }
trap 'rm -rf "$SBASE"' EXIT
new_case() { mktemp -d "$SBASE/case.XXXXXX"; }

# git 配置消毒（不得读机器全局配置）：整个用例进程统一导出，子进程（含钩子）继承。
GITCONF="$SBASE/gitconf.empty"
: > "$GITCONF" || exit 1
export GIT_CONFIG_GLOBAL="$GITCONF" GIT_CONFIG_SYSTEM="$GITCONF"
git_at() { # <dir> <git args...>
  local dir="$1"; shift
  ( cd "$dir" && GIT_CONFIG_GLOBAL="$GITCONF" GIT_CONFIG_SYSTEM="$GITCONF" git "$@" )
}

# ---------- 断言 ----------
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf 'FAIL %s\n' "$1"; }

assert_eq() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1（期望 [$2] 实得 [$3]）"; fi; }
assert_contains() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1（未找到 [$3]）" ;; esac; }
assert_not_contains() { case "$2" in *"$3"*) bad "$1（不应出现 [$3]）" ;; *) ok "$1" ;; esac; }
assert_exists() { [ -e "$2" ] && ok "$1" || bad "$1（缺失 $2）"; }
assert_missing() { [ ! -e "$2" ] && ok "$1" || bad "$1（不应存在 $2）"; }
assert_exec() { [ -x "$2" ] && ok "$1" || bad "$1（无执行位 $2）"; }
assert_zero() { [ "${2:-1}" = "0" ] && ok "$1" || bad "$1（期望 exit 0，实得 ${2:-?}）"; }
assert_nonzero() { [ "${2:-0}" != "0" ] && ok "$1" || bad "$1（期望非零，实得 0）"; }
assert_matches() { if printf '%s\n' "$2" | grep -Eq -- "$3"; then ok "$1"; else bad "$1（无匹配 /$3/）"; fi; }
assert_not_matches() { if printf '%s\n' "$2" | grep -Eq -- "$3"; then bad "$1（不应匹配 /$3/）"; else ok "$1"; fi; }
assert_file_has() { if [ -f "$2" ] && grep -qF -- "$3" "$2"; then ok "$1"; else bad "$1（$2 缺 [$3]）"; fi; }
assert_file_lacks() { if [ ! -f "$2" ] || ! grep -qF -- "$3" "$2"; then ok "$1"; else bad "$1（$2 不应含 [$3]）"; fi; }
# 崩溃/异常不得被当成「正常的非零」放过
assert_no_crash() {
  assert_not_matches "$1" "$2" 'syntax error|command not found|unbound variable|integer expression expected|bad substitution|Traceback \(most recent call last\)'
}
md5_of() { if [ -f "$1" ]; then md5sum "$1" 2>/dev/null | awk '{print $1}'; else printf 'MISSING'; fi; }
sha_of() { if [ -f "$1" ]; then sha256sum "$1" 2>/dev/null | awk '{print $1}'; else printf 'MISSING'; fi; }

# ---------- 调用 ponygo ----------
R_OUT=""; R_RC=0; R_ERR=""
# run_in <dir> [VAR=val ...] <args...>：stdout+stderr 合并（契约默认判定面）
run_in() {
  local dir="$1"; shift
  local -a envs=()
  while [ $# -gt 0 ]; do case "$1" in *=*) envs+=("$1"); shift ;; *) break ;; esac; done
  R_OUT=$( cd "$dir" && env ${envs[@]+"${envs[@]}"} bash "$ROOT/ponygo" "$@" 2>&1 )
  R_RC=$?
}
# run_split <dir> [VAR=val ...] <args...>：R_OUT=stdout（纯净），R_ERR=stderr（WARN 面判定用）
run_split() {
  local dir="$1"; shift
  local -a envs=()
  while [ $# -gt 0 ]; do case "$1" in *=*) envs+=("$1"); shift ;; *) break ;; esac; done
  local errf; errf=$(mktemp "$SBASE/err.XXXXXX") || return 1
  R_OUT=$( cd "$dir" && env ${envs[@]+"${envs[@]}"} bash "$ROOT/ponygo" "$@" 2>"$errf" )
  R_RC=$?
  R_ERR=$(cat "$errf" 2>/dev/null)
  rm -f "$errf"
  return 0
}
# 直跑仓库内脚本（A6/A7/A1/A4 的执行语义），捕获合并输出与 rc
S_RC=0; S_OUT=""
run_script() { # <dir> <脚本相对路径> [args...]
  local dir="$1"; shift
  S_OUT=$( cd "$dir" && bash "$@" 2>&1 ); S_RC=$?
}
# 直跑并分离 stderr（A6 check 的「诊断走 stderr」类断言）
S_ERR=""
run_script_split() { # <dir> <脚本相对路径> [args...]
  local dir="$1"; shift
  local errf; errf=$(mktemp "$SBASE/serr.XXXXXX") || return 1
  S_OUT=$( cd "$dir" && bash "$@" 2>"$errf" ); S_RC=$?
  S_ERR=$(cat "$errf" 2>/dev/null); rm -f "$errf"
  return 0
}

# ---------- 夹具 ----------
# 合法 ADR（满足 1.1–1.10；Status 由参数给定）
write_adr() { # <dir> <notes 相对路径> [status]
  local dir="$1" rel="$2" st="${3:-implemented}"
  mkdir -p "$dir/.agents/notes/$(dirname "$rel")"
  cat > "$dir/.agents/notes/$rel" <<ADREOF
# Agent Note: wave13 fixture

Status: $st

## Problem

夹具问题陈述。

## Decision

夹具决策正文。

## Alternatives considered

- 不建夹具：判定器无法被验证。
ADREOF
}
# 合法骨架但**故意缺** `## Alternatives considered`（1.10 未满足）→ coverage 诚实性夹具
write_adr_missing_1_10() { # <dir> <notes 相对路径> [status]
  local dir="$1" rel="$2" st="${3:-implemented}"
  mkdir -p "$dir/.agents/notes/$(dirname "$rel")"
  cat > "$dir/.agents/notes/$rel" <<ADREOF
# Agent Note: wave13 fixture without alternatives

Status: $st

## Problem

夹具问题陈述。

## Decision

夹具决策正文。
ADREOF
}

# 建仓 + 一个初始提交（--no-verify：装配前不被已有钩子拦）+ 清空 git 全局配置
git_seed_repo() { # <dir>
  ( cd "$1" \
      && GIT_CONFIG_GLOBAL="$GITCONF" GIT_CONFIG_SYSTEM="$GITCONF" git init -q . >/dev/null 2>&1 \
      && printf '# seed\n' > README.md \
      && GIT_CONFIG_GLOBAL="$GITCONF" GIT_CONFIG_SYSTEM="$GITCONF" git add -A >/dev/null 2>&1 \
      && GIT_CONFIG_GLOBAL="$GITCONF" GIT_CONFIG_SYSTEM="$GITCONF" \
           git -c user.email=t@t -c user.name=t -c commit.gpgsign=false \
           commit -qm seed --no-verify >/dev/null 2>&1 )
  [ -d "$1/.git" ] || mkdir -p "$1/.git"
  return 0
}
git_commit() { # <dir> <message>  —— 满输出/rc → C_OUT / C_RC
  local dir="$1" msg="${2:-wave13}"
  C_OUT=$( cd "$dir" && GIT_CONFIG_GLOBAL="$GITCONF" GIT_CONFIG_SYSTEM="$GITCONF" \
    git -c user.email=t@t -c user.name=t -c commit.gpgsign=false commit -qm "$msg" 2>&1 )
  C_RC=$?
  return 0
}

# 治理仓夹具：git 仓 + 真 ponygo init 骨架 + level，可选是否放合法 ADR
gov_repo() { # <dir> [level] [adr:1|0]
  local dir="$1" lvl="${2:-2}" with_adr="${3:-0}" rc=0
  git_seed_repo "$dir"
  ( cd "$dir" && bash "$ROOT/ponygo" init >/dev/null 2>&1 ) || rc=$?
  [ "$rc" -eq 0 ] || { bad "夹具失败：ponygo init 在 $dir 退出 $rc"; return 1; }
  printf 'level: %s\n' "$lvl" > "$dir/.meta/meta.yaml"
  [ "$with_adr" = "1" ] && write_adr "$dir" "implemented/feature/2026-01-02-fixture-adr.md"
  return 0
}

# ---------- 归档封印夹具 ----------
# 造一个已归档 ADR（合法、Status: implemented），但不写 manifest（= 未封印态）
stage_archived_adr() { # <dir> <archived 相对路径> [status]
  write_adr "$1" "archived/$2" "${3:-implemented}"
}
# 篡改一个字节（确定性、不改变文件长度）：把首字节替换为与原值不同的字符。
# 用于「内容相同但长度不变」的最坏篡改（若只靠长度/wc 判定，必漏）。
tamper_one_byte() { # <file>
  local f="$1" first repl
  [ -f "$f" ] || { bad "夹具失败：待篡改文件不存在（$f）"; return 1; }
  first=$(head -c 1 "$f")
  case "$first" in
    Z) repl='Y' ;;
    *) repl='Z' ;;
  esac
  printf '%s' "$repl" | dd of="$f" bs=1 count=1 conv=notrunc status=none 2>/dev/null \
    || { bad "夹具失败：无法篡改 $f"; return 1; }
  [ "$(head -c 1 "$f")" = "$repl" ] || { bad "夹具失败：篡改未生效（$f）"; return 1; }
  return 0
}

finish() {
  printf '##CASE %s pass=%s fail=%s\n' "$(basename "$0")" "$PASS" "$FAIL"
  if [ "$FAIL" -eq 0 ]; then exit 0; else exit 1; fi
}
