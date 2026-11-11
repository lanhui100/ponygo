#!/usr/bin/env bash
# Windows 编码硬化（CI 实跑 run 43031069740）：cp1252 控制台下 python3 打印中文会抛
# UnicodeEncodeError → rc=1 且无 stdout（gh2 3/1、gh3 9/1、gh6 83/8 均为其连锁反应）。
# 在调用任何 python3 之前强制 UTF-8；standalone 执行时由本文件/lib.sh 顶部覆盖生效。
export PYTHONUTF8=1 PYTHONIOENCODING=utf-8
# ============================================================
# tests/acceptance/negspace/lib.sh
# 负空间（negative space）验收套件（N1–N3）的公共夹具与断言。
#
# 纪律（与 tests/acceptance/auditfix 同风格）：
#   - 纯 bash、零依赖；每个用例在 mktemp -d 里造夹具，只读调用仓库真实资产
#     （.agents/skills/write-adr/verify-note.sh、.meta/gates/no-residue.sh、.meta/gates/ci-verify.sh）；
#   - 断言只认「真实退出码 + 输出子串」，失败打印 `FAIL <用例名>`，脚本末 exit 1；
#   - 严禁 sleep 轮询等待；严禁写仓库（临时目录即夹具，trap 清理）；
#   - git 全局/系统配置一律消毒（空文件），夹具判定不得读机器全局配置。
#
# 被测契约来源（Lead 裁决）：
#   N1 = write-adr 判据 1.11（负空间形状：简化笔记的复活条件 + 检索收据）
#   N2 = A8 门 .meta/gates/no-residue.sh（零残留清单门）
#   N3 = ci-verify 未知参数 fail-closed
# ============================================================
set -u

NEG_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$NEG_DIR/../../.." && pwd)
VERIFY_NOTE="$ROOT/.agents/skills/write-adr/verify-note.sh"
NO_RESIDUE_SH="$ROOT/.meta/gates/no-residue.sh"
NO_RESIDUE_MANIFEST="$ROOT/.meta/gates/no-residue.manifest"
CI_VERIFY_SH="$ROOT/.meta/gates/ci-verify.sh"

# 一个进程一份临时基目录（中断也清理）
SBASE=$(mktemp -d) || { echo "无法创建临时目录" >&2; exit 1; }
trap 'rm -rf "$SBASE"' EXIT
new_case() { mktemp -d "$SBASE/case.XXXXXX"; }

# git 配置消毒（不得读机器全局配置：命中数/hooksPath/钩子判定都会被污染）
GITCONF=$(mktemp "$SBASE/gitconf.XXXXXX") || exit 1
: > "$GITCONF"
export GIT_CONFIG_GLOBAL="$GITCONF" GIT_CONFIG_SYSTEM="$GITCONF"

# ---------- 断言（一律真断言：真实退出码或关键输出） ----------
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf 'FAIL %s\n' "$1"; }

assert_eq() { # <描述> <期望> <实得>
  if [ "$2" = "$3" ]; then ok "$1"; else bad "$1（期望 [$2] 实得 [$3]）"; fi
}
assert_contains() { # <描述> <整体> <子串>
  case "$2" in *"$3"*) ok "$1" ;; *) bad "$1（未找到 [$3]；实际输出见日志）" ;; esac
}
assert_not_contains() { # <描述> <整体> <子串>
  case "$2" in *"$3"*) bad "$1（不应出现 [$3]）" ;; *) ok "$1" ;; esac
}
assert_exists() { [ -e "$2" ] && ok "$1" || bad "$1（缺失 $2）"; }
assert_missing() { [ ! -e "$2" ] && ok "$1" || bad "$1（不应存在 $2）"; }
assert_zero() { # <描述> <rc>
  [ "${2:-1}" = "0" ] && ok "$1" || bad "$1（期望 exit 0，实得 ${2:-?}）"
}
assert_nonzero() { # <描述> <rc>
  [ "${2:-0}" != "0" ] && ok "$1" || bad "$1（期望非零，实得 0）"
}
assert_rc_is() { # <描述> <期望 rc> <实得 rc>
  assert_eq "$1（exit）" "$2" "${3:-?}"
}
assert_matches() { # <描述> <整体> <ERE>
  if printf '%s\n' "$2" | grep -Eq -- "$3"; then ok "$1"; else bad "$1（无匹配 /$3/）"; fi
}
assert_not_matches() { # <描述> <整体> <ERE>
  if printf '%s\n' "$2" | grep -Eq -- "$3"; then bad "$1（不应匹配 /$3/）"; else ok "$1"; fi
}
# 「工具崩溃」零容忍：shell 级错误字面量一律算失败（畸形参数不得炸栈）
assert_no_crash() { # <描述> <输出>
  assert_not_matches "$1" "$2" 'syntax error|command not found|unbound variable|integer expression expected|bad substitution|Segmentation fault|core dumped'
}

# ---------- 调用被测资产（cwd 隔离） ----------
R_OUT=""; R_RC=0
# run_script_in <dir> <脚本绝对路径> [args...]
run_script_in() {
  local dir="$1" script="$2"; shift 2
  R_OUT=$(cd "$dir" && bash "$script" "$@" 2>&1)
  R_RC=$?
}
# run_timeout_in <dir> <秒> <脚本绝对路径> [args...]（外部硬兜底，防被测对象 hang）
run_timeout_in() {
  local dir="$1" secs="$2" script="$3"; shift 3
  R_OUT=$(cd "$dir" && timeout "$secs" bash "$script" "$@" 2>&1)
  R_RC=$?
}

# ---------- 收尾 ----------
finish() {
  printf '##CASE %s pass=%s fail=%s\n' "$(basename "$0")" "$PASS" "$FAIL"
  if [ "$FAIL" -eq 0 ]; then exit 0; else exit 1; fi
}
