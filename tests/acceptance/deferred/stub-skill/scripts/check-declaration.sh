#!/usr/bin/env bash
# tests/acceptance/deferred/stub-skill/scripts/check-declaration.sh
# deferred 验收套件专用假 skill：声明 vs 现实判定替身（离线、零网络、零集群）。
set -u
PROJ=""
while [ $# -gt 0 ]; do
  case "$1" in
    --project|--declaration|--facts)
      [ $# -ge 2 ] || { printf 'STUB-CHECK-DECL rc=4 reason=missing-value\n' >&2; exit 4; }
      [ "$1" = "--project" ] && PROJ="$2"
      shift ;;
    --json|--quiet) : ;;
    -h|--help) printf 'stub check-declaration: [<project>] [--project <dir>]\n'; exit 0 ;;
    -*) printf 'STUB-CHECK-DECL rc=4 reason=unknown-flag\n' >&2; exit 4 ;;
    *)  PROJ="$1" ;;
  esac
  shift
done
[ -n "$PROJ" ] || PROJ="$PWD"
[ -d "$PROJ" ] || { printf 'STUB-CHECK-DECL rc=4 reason=project-missing\n' >&2; exit 4; }
RC="${STUB_RC_CHECK_DECL:-0}"
printf 'STUB-CHECK-DECL rc=%s proj=%s\n' "$RC" "$PROJ"
exit "$RC"
