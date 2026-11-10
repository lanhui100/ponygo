#!/usr/bin/env bash
# ============================================================
# tests/acceptance/auditfix/lib.sh
# auditfix 验收套件（F1–F7 + L2-AT 对抗）的公共夹具与断言。
#
# 纪律（与仓库既有 tests/run.sh 同风格）：
#   - 纯 bash、零依赖；每个用例在 mktemp -d 里造仓，用 bash "$ROOT/ponygo" 调用；
#   - 断言只认「真实退出码 + 输出子串」，失败打印 `FAIL <用例名>`，脚本末 exit 1；
#   - 严禁 sleep 轮询等待（唯一 sleep 是被测对象自身——恶意 spec 夹具）；
#   - git 全局/系统配置一律消毒（空文件），钩子/命中判定不得读机器全局配置。
# ============================================================
set -u

AUDITFIX_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$AUDITFIX_DIR/../../.." && pwd)
STUB_SKILL_SRC="$AUDITFIX_DIR/stub-skill"

CLI() { bash "$ROOT/ponygo" "$@"; }

# 一个进程一份临时基目录（中断也清理）
SBASE=$(mktemp -d) || { echo "无法创建临时目录" >&2; exit 1; }
trap 'rm -rf "$SBASE"' EXIT
new_case() { mktemp -d "$SBASE/case.XXXXXX"; }

# git 配置消毒（不得读机器全局配置：命中数/hooksPath/钩子判定都会被污染）
GITCONF=$(mktemp "$SBASE/gitconf.XXXXXX") || exit 1
: > "$GITCONF"
export GIT_CONFIG_GLOBAL="$GITCONF" GIT_CONFIG_SYSTEM="$GITCONF"

# ---------- 断言（一律真断言：状态突变或关键输出） ----------
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
# 「工具崩溃」零容忍：shell 级错误字面量一律算失败（畸形输入不得炸栈）
assert_no_crash() { # <描述> <输出>
  assert_not_matches "$1" "$2" 'syntax error|command not found|unbound variable|integer expression expected|bad substitution|Segmentation fault|core dumped'
}
md5_of() { # <文件> → md5；缺失打印 MISSING（防「空==空」假绿）
  if [ -f "$1" ]; then md5sum "$1" 2>/dev/null | awk '{print $1}'; else printf 'MISSING'; fi
}
# 结论行（audit / status 内嵌级自洽验证的唯一结论面）：匹配 ^级自洽验证： 的单行
conclusion_of() { printf '%s\n' "$1" | grep '^级自洽验证：' | head -n1; }
# 命中行里的分子/分母（M 档打分）：命中 <n> / <t> 项
hits_n_of() { printf '%s\n' "$1" | sed -n 's/.*命中 \([0-9][0-9]*\) \/ [0-9][0-9]* 项.*/\1/p' | head -n1; }
hits_t_of() { printf '%s\n' "$1" | sed -n 's/.*命中 [0-9][0-9]* \/ \([0-9][0-9]*\) 项.*/\1/p' | head -n1; }

# ---------- 调用 ponygo（cwd 隔离 + 变量注入） ----------
R_OUT=""; R_RC=0
# run_in <dir> [VAR=val ...] <args...>
run_in() {
  local dir="$1"; shift
  local -a envs=()
  while [ $# -gt 0 ]; do
    case "$1" in *=*) envs+=("$1"); shift ;; *) break ;; esac
  done
  R_OUT=$(cd "$dir" && env ${envs[@]+"${envs[@]}"} bash "$ROOT/ponygo" "$@" 2>&1)
  R_RC=$?
}
# run_timeout_in <dir> <秒> [VAR=val ...] <args...>（外部硬兜底，防被测对象 hang）
run_timeout_in() {
  local dir="$1" secs="$2"; shift 2
  local -a envs=()
  while [ $# -gt 0 ]; do
    case "$1" in *=*) envs+=("$1"); shift ;; *) break ;; esac
  done
  R_OUT=$(cd "$dir" && env ${envs[@]+"${envs[@]}"} timeout "$secs" bash "$ROOT/ponygo" "$@" 2>&1)
  R_RC=$?
}

# ---------- 文件树快照（零写判据） ----------
snap() { # <dir>
  ( cd "$1" 2>/dev/null || exit 1
    find . -path ./.git -prune -o -type f -print 2>/dev/null | LC_ALL=C sort | while IFS= read -r f; do
      printf '%s|%s\n' "$f" "$(cksum < "$f" 2>/dev/null)"
    done )
}
assert_same_tree() { # <描述> <dir> <before>
  local after
  after=$(snap "$2")
  if [ "$after" = "$3" ]; then ok "$1"; else bad "$1（文件树已变化，零写被破坏）"; fi
}
# 快照差集（TEST-DEFECT 修复）：snap 用 LC_ALL=C 定序，comm 若按环境 locale
# （如 en_US.UTF-8）比对会报 "input is not in sorted order" 并给出错误计数——
# 故两端一律先 LC_ALL=C sort 再喂 LC_ALL=C comm（只改测试侧，不动断言语义）。
snap_added() { # <before-snapshot> <after-snapshot> → 只出现在 after 的行数
  LC_ALL=C comm -13 <(printf '%s\n' "$1" | LC_ALL=C sort) \
                     <(printf '%s\n' "$2" | LC_ALL=C sort) | wc -l | tr -d ' '
}
snap_removed() { # <before-snapshot> <after-snapshot> → 只出现在 before 的行数
  LC_ALL=C comm -23 <(printf '%s\n' "$1" | LC_ALL=C sort) \
                     <(printf '%s\n' "$2" | LC_ALL=C sort) | wc -l | tr -d ' '
}

# ---------- 夹具 ----------
# 造一个「机械判据可通过」的治理仓：git 仓 + 真 ponygo init 骨架 + 一条合法 ADR + 声明级。
# 用真 init 铺骨架（不用手写副本）→ 被测对象看到的是真实交付形态。
make_gov_repo() { # <dir> [level]
  local dir="$1" lvl="${2:-1}" rc=0
  ( cd "$dir" && git init -q . >/dev/null 2>&1 ) || { bad "夹具失败：git init（$dir）"; return 1; }
  ( cd "$dir" && bash "$ROOT/ponygo" init >/dev/null 2>&1 ) || rc=$?
  if [ "$rc" -ne 0 ]; then bad "夹具失败：ponygo init 在 $dir 退出 $rc"; return 1; fi
  mkdir -p "$dir/.agents/notes/implemented/architecture"
  cat > "$dir/.agents/notes/implemented/architecture/2026-01-01-fixture-adr.md" <<'ADREOF'
# 2026-01-01 夹具 ADR

Status: implemented

## Context

验收夹具用的合法决策记录（满足 1.1–1.9 机械判据，不参与被测判定）。

## Decision

采用最小夹具，不引入额外治理机制。

## Alternatives considered

- 不建夹具：判定器无法被验证。
ADREOF
  printf 'level: %s\n' "$lvl" > "$dir/.meta/meta.yaml"
  return 0
}

# 夹具自检：先证明「等价基线」本身是通过态，后续变红才可归因到被测判据。
gov_repo() { # <dir> [level] → 打印是否成功（0/1）
  make_gov_repo "$1" "${2:-1}" || return 1
  run_in "$1" status
  assert_zero "夹具自检：等价基线 ponygo status exit 0" "$R_RC"
  # 覆盖诚实化后人读结论不再写「机械判据全部 PASS」；保持原自检强度，钉死通过态与 1.10 边界。
  assert_contains "夹具自检：等价基线级自洽通过" "$R_OUT" "级自洽验证：通过（L0-L"
  assert_contains "夹具自检：等价基线保留 1.10 未由本命令验证边界" "$R_OUT" "1.10 未由本命令验证"
  return 0
}

# 把某骨架文件移出仓（stash 保留，供后续恢复）；打印 stash 路径
drop_file() { # <dir> <相对路径> → 打印 stash
  local dir="$1" rel="$2" keep
  keep=$(mktemp "$SBASE/keep.XXXXXX")
  cp "$dir/$rel" "$keep" || { bad "夹具失败：无法备份 $rel"; printf ''; return 1; }
  rm -f "$dir/$rel"
  printf '%s' "$keep"
}

# 把假 skill 复制进 case（逐 case 一份，避免互污；不改 fixture 本体）→ 打印 skill 目录
stage_skill() { # <case-dir>
  local dst="$1/skill"
  rm -rf "$dst"
  cp -R "$STUB_SKILL_SRC" "$dst" || return 1
  printf '%s' "$dst"
}

# 手写四维归属声明（正文无占位；ob0 静态判据满足）
write_decl_clean() { # <dir>
  mkdir -p "$1/docs" "$1/src"
  cat > "$1/docs/observability.yaml" <<'DECLEOF'
# 归属声明（验收夹具手写；注释含占位符字面不参与占位判定）
service: svc-a
kind: cli
dimensions:
  metrics:
    applicable: true
    anchor: src/metrics.txt
  tracing:
    applicable: true
    anchor: src/tracing.txt
  logs:
    applicable: true
    anchor: src/logs.txt
  issues:
    applicable: true
    anchor: src/issues.txt
reviewed_at: "2026-01-01"
DECLEOF
  : > "$1/src/metrics.txt"; : > "$1/src/tracing.txt"
  : > "$1/src/logs.txt";   : > "$1/src/issues.txt"
}

# observe 夹具：声明（ob0 可达）+ 声明级（决定 observe 目标级）+ git 仓
make_observe_case() { # <dir> [level]
  local dir="$1" lvl="${2:-3}"
  mkdir -p "$dir/.meta"
  write_decl_clean "$dir"
  printf 'level: %s\n' "$lvl" > "$dir/.meta/meta.yaml"
  ( cd "$dir" && git init -q . >/dev/null 2>&1 ) || :
  return 0
}

# ---------- 收尾 ----------
finish() {
  printf '##CASE %s pass=%s fail=%s\n' "$(basename "$0")" "$PASS" "$FAIL"
  if [ "$FAIL" -eq 0 ]; then exit 0; else exit 1; fi
}
