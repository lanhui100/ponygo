#!/usr/bin/env bash
# tests/acceptance/observe-b027/stub-skill/scripts/audit-diff.sh
# 「变更级收口门禁」判定的替身（离线、零 git 遍历、零网络）。
#
# B027① 的判定面是 ponygo 的**挂载载体发现**（静态 mount_carriers ∪ core.hooksPath ∪ .husky/），
# 而 ob2 的得分前提是 audit-diff 本身 rc=0。用本桩把「收口门禁结论」钉死在 0，
# 从而让 ob2 的通过/拒绝**只**由载体命中与注释过滤决定——不混入真 skill 的规则集语义。
# rc 由 env STUB_RC_AUDIT_DIFF 覆盖（缺省 0）；--repo 目录不存在 → exit 4（真 skill 同义）。
set -u

usage() {
  printf '%s\n' 'stub audit-diff: audit-diff.sh [--repo <dir>] [--base <rev>] [--declaration <path>] [--json] [--strict]'
  printf '%s\n' '退出码: 0 无违规 / 1 仅 WARN / 2 违规 / 3 证据不可得 / 4 工具使用错误'
}

REPO=""
while [ $# -gt 0 ]; do
  case "$1" in
    --repo)
      [ $# -ge 2 ] || { printf 'STUB-AUDIT-DIFF rc=4 reason=missing-value\n'
                        printf 'stub: --repo 需要一个取值\n' >&2; exit 4; }
      REPO="$2"; shift ;;
    --base|--declaration)
      [ $# -ge 2 ] || { printf 'STUB-AUDIT-DIFF rc=4 reason=missing-value\n'
                        printf 'stub: %s 需要一个取值\n' "$1" >&2; exit 4; }
      shift ;;
    --staged|--json|--strict|--show-line|--decl-approved) : ;;
    -h|--help) usage; exit 0 ;;
    -*) printf 'STUB-AUDIT-DIFF rc=4 reason=unknown-flag\n'
        printf 'stub: 未知参数 %s\n' "$1" >&2; exit 4 ;;
    *) [ -n "$REPO" ] || REPO="$1" ;;
  esac
  shift
done

[ -n "$REPO" ] || REPO="$PWD"
if [ ! -d "$REPO" ]; then
  printf 'STUB-AUDIT-DIFF rc=4 reason=repo-missing\n'
  printf 'stub: --repo 目录不存在：[%s]\n' "$REPO" >&2
  exit 4
fi

RC="${STUB_RC_AUDIT_DIFF:-0}"
case "$RC" in
  ''|*[!0-9]*) printf 'stub: STUB_RC_AUDIT_DIFF 须为非负整数（实得 [%s]）\n' "$RC" >&2; exit 4 ;;
esac
printf 'STUB-AUDIT-DIFF rc=%s repo=%s\n' "$RC" "$REPO"
printf 'stub: audit-diff 模拟结论 rc=%s（非真实判定，仅供 ponygo observe 判定面测试）\n' "$RC" >&2
exit "$RC"
