#!/usr/bin/env bash
# ============================================================
# tests/acceptance/observe-b027/lib.sh —— B027 独立验收公共层
#
# 口径（与 tests/acceptance/gate-hardening/lib.sh 同源）：
#   - 真实 CLI（默认工作树 `ponygo`，可用 PONYGO_CLI 指向只读基线副本做先红后绿）；
#   - 每例 `mktemp -d` 沙箱 + EXIT 清理；**绝不写仓库**（夹具、stub skill 副本全在沙箱内）；
#   - 真实退出码 + 真断言（无断言不收；不为了让套件绿而放宽）；
#   - git 全局/系统配置隔离到空文件，夹具的 core.hooksPath 只落在自己仓里。
#
# skill 替身：见 ./stub-skill（内容驱动退出码）。B027 验的是 ponygo 的**判定面**
# （载体发现 / 子组件逐份巡检 / 附加声明逐份判定 / 注释过滤），不是 skill 的规则集语义；
# 真 skill 的端到端取证另落 .dev-team/b027-acceptance-receipt.md。
# ============================================================
export PYTHONUTF8=1 PYTHONIOENCODING=utf-8
set -u

OB_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$OB_DIR/../../.." && pwd)
CLI_BIN=${PONYGO_CLI:-$ROOT/ponygo}
STUB_SRC=$OB_DIR/stub-skill

[ -f "$CLI_BIN" ] || { printf 'observe-b027: 被测 CLI 不存在：%s\n' "$CLI_BIN" >&2; exit 1; }
[ -d "$STUB_SRC/scripts" ] || { printf 'observe-b027: 缺 skill 替身：%s\n' "$STUB_SRC" >&2; exit 1; }

SBASE=$(mktemp -d) || { printf 'observe-b027: mktemp 失败\n' >&2; exit 1; }
trap 'rm -rf "$SBASE"' EXIT
new_case() { mktemp -d "$SBASE/case.XXXXXX"; }

# 每个 case 各自一份 stub skill 副本（放沙箱，SUT 绝不碰仓库内夹具）
new_stub() {
  local d
  d=$(mktemp -d "$SBASE/skill.XXXXXX") || return 1
  cp -R "$STUB_SRC/." "$d/" || return 1
  printf '%s\n' "$d"
}

# git 全局/系统配置隔离：夹具的 core.hooksPath 只写各自仓（local），环境不泄漏
GITCONF=$(mktemp "$SBASE/gitconf.XXXXXX") || exit 1
: > "$GITCONF"
export GIT_CONFIG_GLOBAL="$GITCONF" GIT_CONFIG_SYSTEM="$GITCONF"
export GIT_AUTHOR_NAME=observe-b027 GIT_AUTHOR_EMAIL=observe-b027@example.invalid
export GIT_COMMITTER_NAME=observe-b027 GIT_COMMITTER_EMAIL=observe-b027@example.invalid

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
assert_exists() { [ -e "$2" ] && ok "$1" || bad "$1（缺失 $2）"; }
assert_file() { [ -f "$2" ] && ok "$1" || bad "$1（不是文件 $2）"; }

R_OUT=""
R_RC=0
run_cli() { # <dir> [VAR=value ...] <args...>；合并人读 stdout/stderr
  local dir="$1"
  shift
  local -a envs=()
  while [ $# -gt 0 ]; do
    case "$1" in *=*) envs+=("$1"); shift ;; *) break ;; esac
  done
  R_OUT=$(cd "$dir" && env ${envs[@]+"${envs[@]}"} bash "$CLI_BIN" "$@" 2>&1)
  R_RC=$?
}

# ---------- 夹具 ----------
make_repo() { # <dir>：git 仓（不提交，落 hooksPath 用）
  mkdir -p "$1" || { bad "夹具：建目录失败 $1"; return 1; }
  ( cd "$1" && git init -q . >/dev/null 2>&1 )
  [ -d "$1/.git" ] || { bad "夹具：git init 失败（$1）"; return 1; }
  return 0
}

set_hooks_path() { # <dir> <path>  —— 仓内 local 配置；等价消费仓的 `git config core.hooksPath <dir>`
  ( cd "$1" && git config core.hooksPath "$2" ) >/dev/null 2>&1 || {
    bad "夹具：设置 core.hooksPath=$2 失败"; return 1; }
  return 0
}

write_decl() { # <dir> <service> [相对路径，缺省 docs/observability.yaml]
  local dir="$1" svc="$2" rel="${3:-docs/observability.yaml}"
  mkdir -p "$dir/$(dirname "$rel")" || { bad "夹具：建声明目录失败"; return 1; }
  cat > "$dir/$rel" <<DECLEOF
service: ${svc}
kind: cli
reviewed_at: "2026-01-01"
dimensions:
  metrics:
    applicable: false
    reason: 指标归属集群侧采集，本仓无进程内 exporter（结构性不适用）
  tracing:
    applicable: false
    reason: 出口统一由网关接 traceparent，本仓不另建管道（结构性不适用）
  logs:
    applicable: false
    reason: 日志走集群采集，本仓不落盘（结构性不适用）
  issues:
    applicable: false
    reason: 本形态无前端，无 issue 归宿（结构性不适用）
DECLEOF
  return 0
}

write_mount_hook() { # <dir> <相对路径>：正样本（**非注释**行真调用 audit-diff）
  local dir="$1" rel="$2"
  mkdir -p "$dir/$(dirname "$rel")" || { bad "夹具：建钩子目录失败"; return 1; }
  {
    printf '#!/usr/bin/env bash\n'
    printf '# 变更级收口门禁：pre-commit / pre-push 挂载\n'
    printf 'bash scripts/audit-diff.sh --repo . --base HEAD\n'
  } > "$dir/$rel"
  chmod +x "$dir/$rel" 2>/dev/null || :
  return 0
}

write_comment_hook() { # <dir> <相对路径> <注释前缀>：负样本（audit-diff 只出现在注释里）
  local dir="$1" rel="$2" prefix="${3:-#}"
  mkdir -p "$dir/$(dirname "$rel")" || { bad "夹具：建钩子目录失败"; return 1; }
  {
    printf '%s 本钩子只做占位，未真正挂变更级门禁\n' "$prefix"
    printf '%s bash scripts/audit-diff.sh --repo . --base HEAD\n' "$prefix"
    printf 'exit 0\n'
  } > "$dir/$rel"
  chmod +x "$dir/$rel" 2>/dev/null || :
  return 0
}

write_stub_hook() { # <dir> <相对路径>：无 audit-diff 字样的钩子（负对照，证明得分来自载体命中）
  local dir="$1" rel="$2"
  mkdir -p "$dir/$(dirname "$rel")" || { bad "夹具：建钩子目录失败"; return 1; }
  printf '#!/usr/bin/env bash\necho pre-commit: 无变更级门禁\nexit 0\n' > "$dir/$rel"
  chmod +x "$dir/$rel" 2>/dev/null || :
  return 0
}

# 基线夹具：合法根声明（service 非 bad-/unk- 前缀 → stub 判 0）+ git 仓
make_ob_repo() { # <dir> [service]
  make_repo "$1" || return 1
  write_decl "$1" "${2:-svc-root}" || return 1
  return 0
}

# ---------- 被测调用 ----------
audit_ob2() { # <dir> <stub> [VAR=value ...] [额外旗标 ...]：断言 ob2 目标级的体检（--level ob2）
  local dir="$1" stub="$2"
  shift 2
  local -a envs=()
  local -a flags=()
  while [ $# -gt 0 ]; do
    case "$1" in *=*) envs+=("$1") ;; *) flags+=("$1") ;; esac
    shift
  done
  run_cli "$dir" ${envs[@]+"${envs[@]}"} observe audit --level ob2 --skill-dir "$stub" ${flags[@]+"${flags[@]}"}
}

finish() {
  printf '##CASE %s pass=%s fail=%s\n' "$(basename "$0")" "$PASS" "$FAIL"
  if [ "$FAIL" -eq 0 ]; then exit 0; else exit 1; fi
}
