#!/usr/bin/env bash
# tests/acceptance/auditfix/stub-skill/scripts/check-declaration.sh
# auditfix 验收套件专用假 skill：声明 vs 现实判定替身（离线、零网络、零集群）。
#   rc 由 env STUB_RC_CHECK_DECL 决定（缺省 0）。**不是纯常量桩**：--project 目录不存在 → exit 4
#   （与真 skill 的「工具使用错误」语义一致，不得被上层当成「声明不合格(2)」）。
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
if [ ! -d "$PROJ" ]; then
  printf 'STUB-CHECK-DECL rc=4 reason=project-missing\n'
  printf 'stub: 项目目录不存在：[%s]\n' "$PROJ" >&2
  exit 4
fi

RC="${STUB_RC_CHECK_DECL:-0}"
printf 'STUB-CHECK-DECL rc=%s proj=%s\n' "$RC" "$PROJ"
printf 'stub: check-declaration 模拟结论 rc=%s（非真实判定，仅供 auditfix 验收套件）\n' "$RC" >&2
exit "$RC"
