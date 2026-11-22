#!/usr/bin/env bash
# tests/acceptance/observe-b027/stub-skill/scripts/check-declaration.sh
# 「声明 vs 现实」判定的替身（离线、零集群、零网络）。
#
# 为什么是**内容驱动**而不是纯常量桩：
#   B027②/③ 要验的是 ponygo 是否**逐份**巡检子组件声明与 docs/observability.d/*.yaml——
#   「根声明 0 / 子声明 2」这类混合场景必须能在一次运行内同时出现，env 单值桩做不到，
#   且纯常量桩会让「所有声明同判」冒充「逐份判定」。故判定由声明内容里的 service 名驱动：
#     bad-*  → exit 2（声明与实测不一致；真 skill 的 FAIL 语义）
#     unk-*  → exit 3（证据不可得；真 skill 的 UNKNOWN 语义）
#     无 service 键 → exit 4（形状不合规 = 工具使用错误，真 skill 同义）
#     其余 → exit 0（一致）
# 入参校验与真 skill 对齐：--project 目录不存在 / --declaration 文件不存在 → exit 4。
# 真 skill 的判定真源不在本仓（~/.agents/skills/observability-onboarding），本桩只替身它的**退出码词表**。
set -u

usage() {
  printf '%s\n' 'stub check-declaration: check-declaration.sh [--project <dir>] [--declaration <path>] [--json] [--quiet]'
  printf '%s\n' '退出码: 0 一致 / 2 不一致 / 3 证据不可得 / 4 工具使用错误（形状不合规、路径不存在）'
}

PROJ=""
DECL=""
while [ $# -gt 0 ]; do
  case "$1" in
    --project)
      [ $# -ge 2 ] || { printf 'STUB-CHECK-DECL rc=4 reason=missing-value\n'; \
                        printf 'stub: --project 需要一个取值\n' >&2; exit 4; }
      PROJ="$2"; shift ;;
    --declaration)
      [ $# -ge 2 ] || { printf 'STUB-CHECK-DECL rc=4 reason=missing-value\n'; \
                        printf 'stub: --declaration 需要一个取值\n' >&2; exit 4; }
      DECL="$2"; shift ;;
    --facts)
      [ $# -ge 2 ] || { printf 'STUB-CHECK-DECL rc=4 reason=missing-value\n'; \
                        printf 'stub: --facts 需要一个取值\n' >&2; exit 4; }
      shift ;;
    --json|--quiet) : ;;
    -h|--help) usage; exit 0 ;;
    -*) printf 'STUB-CHECK-DECL rc=4 reason=unknown-flag\n'
        printf 'stub: 未知参数 %s\n' "$1" >&2; exit 4 ;;
    *) [ -n "$PROJ" ] || PROJ="$1" ;;
  esac
  shift
done

[ -n "$PROJ" ] || PROJ="$PWD"
if [ ! -d "$PROJ" ]; then
  printf 'STUB-CHECK-DECL rc=4 reason=project-missing\n'
  printf 'stub: 项目目录不存在：[%s]\n' "$PROJ" >&2
  exit 4
fi

if [ -z "$DECL" ]; then
  if [ -f "$PROJ/docs/observability.yaml" ]; then
    DECL="$PROJ/docs/observability.yaml"
  elif [ -f "$PROJ/docs/observability.yml" ]; then
    DECL="$PROJ/docs/observability.yml"
  fi
fi
if [ -z "$DECL" ] || [ ! -f "$DECL" ]; then
  printf 'STUB-CHECK-DECL rc=4 reason=declaration-missing\n'
  printf 'stub: 声明文件不存在：%s\n' "${DECL:-（未找到 docs/observability.yaml|yml）}" >&2
  exit 4
fi

svc=$(sed -n '/^service:/{s/^service:[[:space:]]*//;s/[[:space:]]*$//;p;q;}' "$DECL" 2>/dev/null)
case "${svc:-}" in
  '') rc=4 ;;
  bad-*) rc=2 ;;
  unk-*) rc=3 ;;
  *) rc=0 ;;
esac

printf 'STUB-CHECK-DECL rc=%s decl=%s service=%s\n' "$rc" "$DECL" "${svc:-<none>}"
printf 'stub: check-declaration 模拟结论 rc=%s（内容驱动，非真实判定；仅供 ponygo observe 判定面测试）\n' "$rc" >&2
exit "$rc"
