#!/usr/bin/env bash
# tests/fixtures/skill-stub/scripts/check-declaration.sh
# 假 skill 的「声明 vs 现实」判定替身（离线、零网络、零集群）。
#   rc 由 env STUB_RC_CHECK_DECL 决定（缺省 0）；stdout 打印可识别标记 STUB-CHECK-DECL rc=<N>。
#   **不是纯常量桩**：至少做一条真入参校验——项目目录不存在 → exit 4（工具使用错误，
#   与真 skill 的 4 语义一致：不得被上层当成「声明不合格(2)」或「证据不足(3)」）。
set -u

PROJ=""
while [ $# -gt 0 ]; do
  case "$1" in
    --project)
      [ $# -ge 2 ] || { printf 'STUB-CHECK-DECL rc=4 reason=missing-value\n'; \
                        printf 'stub: --project 需要一个取值\n' >&2; exit 4; }
      PROJ="$2"; shift ;;
    --declaration|--facts)
      [ $# -ge 2 ] || { printf 'STUB-CHECK-DECL rc=4 reason=missing-value\n'; \
                        printf 'stub: %s 需要一个取值\n' "$1" >&2; exit 4; }
      shift ;;
    --json|--quiet) : ;;
    -h|--help) printf 'stub check-declaration: check-declaration.sh [<project>] [--project <dir>] [--json]\n'; exit 0 ;;
    -*) printf 'STUB-CHECK-DECL rc=4 reason=unknown-flag\n'; \
        printf 'stub: 未知参数 %s\n' "$1" >&2; exit 4 ;;
    *)  PROJ="$1" ;;
  esac
  shift
done

# 入参校验：项目目录必须真实存在（相对路径按当前工作目录解析，与真 skill 一致）
[ -n "$PROJ" ] || PROJ="$PWD"
if [ ! -d "$PROJ" ]; then
  printf 'STUB-CHECK-DECL rc=4 reason=project-missing\n'
  printf 'stub: 项目目录不存在：[%s]\n' "$PROJ" >&2
  exit 4
fi

# 可选：故意拖长执行时间，供 SIGTERM 中断/临时文件清理用例（F3）驱动；
# 缺省 0 = 立即返回（其余用例零等待，禁盲等）。
if [ -n "${STUB_SLEEP:-}" ]; then sleep "${STUB_SLEEP}"; fi

RC="${STUB_RC_CHECK_DECL:-0}"
printf 'STUB-CHECK-DECL rc=%s proj=%s\n' "$RC" "$PROJ"
printf 'stub: check-declaration 模拟结论 rc=%s（非真实判定，仅供 ponygo observe 测试）\n' "$RC" >&2
exit "$RC"
