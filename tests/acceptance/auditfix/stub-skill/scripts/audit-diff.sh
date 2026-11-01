#!/usr/bin/env bash
# tests/acceptance/auditfix/stub-skill/scripts/audit-diff.sh
# auditfix 验收套件专用假 skill：变更级收口门禁替身（离线、零 git、零网络）。
#   rc 由 env STUB_RC_AUDIT_DIFF 决定（缺省 0）。**不是纯常量桩**：--repo 目录不存在 → exit 4。
set -u

REPO=""
while [ $# -gt 0 ]; do
  case "$1" in
    --repo)
      [ $# -ge 2 ] || { printf 'STUB-AUDIT-DIFF rc=4 reason=missing-value\n' >&2; exit 4; }
      REPO="$2"; shift ;;
    --declaration|--base)
      [ $# -ge 2 ] || { printf 'STUB-AUDIT-DIFF rc=4 reason=missing-value\n' >&2; exit 4; }
      shift ;;
    --staged|--json|--strict|--show-line|--decl-approved) : ;;
    -h|--help) printf 'stub audit-diff: [--repo <dir>] [--base <rev>]\n'; exit 0 ;;
    -*) printf 'STUB-AUDIT-DIFF rc=4 reason=unknown-flag\n' >&2; exit 4 ;;
    *)  [ -n "$REPO" ] || REPO="$1" ;;
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
printf 'STUB-AUDIT-DIFF rc=%s repo=%s\n' "$RC" "$REPO"
printf 'stub: audit-diff 模拟结论 rc=%s（非真实判定，仅供 auditfix 验收套件）\n' "$RC" >&2
exit "$RC"
