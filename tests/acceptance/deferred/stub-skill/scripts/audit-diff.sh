#!/usr/bin/env bash
# tests/acceptance/deferred/stub-skill/scripts/audit-diff.sh
# deferred 验收套件专用假 skill：变更级收口门禁替身（离线、零 git、零网络）。
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
[ -d "$REPO" ] || { printf 'STUB-AUDIT-DIFF rc=4 reason=repo-missing\n' >&2; exit 4; }
RC="${STUB_RC_AUDIT_DIFF:-0}"
printf 'STUB-AUDIT-DIFF rc=%s repo=%s\n' "$RC" "$REPO"
exit "$RC"
