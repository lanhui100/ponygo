#!/usr/bin/env bash
# tests/fixtures/skill-stub/scripts/audit-diff.sh
# 假 skill 的「变更级收口门禁」替身（离线、零 git、零网络）。
#   rc 由 env STUB_RC_AUDIT_DIFF 决定（缺省 0）；stdout 打印可识别标记 STUB-AUDIT-DIFF rc=<N>。
#   真 skill 退出码：0 无违规 / 1 仅 WARN（含「零收口点」）/ 2 违规 / 3 证据不可得 / 4 工具错误。
#   **不是纯常量桩**：--repo 目录不存在 → exit 4（真 skill 亦如此）。
set -u

REPO=""
while [ $# -gt 0 ]; do
  case "$1" in
    --repo)
      [ $# -ge 2 ] || { printf 'STUB-AUDIT-DIFF rc=4 reason=missing-value\n'; \
                        printf 'stub: --repo 需要一个取值\n' >&2; exit 4; }
      REPO="$2"; shift ;;
    --declaration|--base)
      [ $# -ge 2 ] || { printf 'STUB-AUDIT-DIFF rc=4 reason=missing-value\n'; \
                        printf 'stub: %s 需要一个取值\n' "$1" >&2; exit 4; }
      shift ;;
    --staged|--json|--strict|--show-line|--decl-approved) : ;;
    -h|--help) printf 'stub audit-diff: audit-diff.sh [--repo <dir>] [--base <rev>] [--staged] [--json] [--strict]\n'; exit 0 ;;
    -*) printf 'STUB-AUDIT-DIFF rc=4 reason=unknown-flag\n'; \
        printf 'stub: 未知参数 %s\n' "$1" >&2; exit 4 ;;
    *)  [ -n "$REPO" ] || REPO="$1" ;;
  esac
  shift
done

# 入参校验：目标仓库目录必须真实存在
[ -n "$REPO" ] || REPO="$PWD"
if [ ! -d "$REPO" ]; then
  printf 'STUB-AUDIT-DIFF rc=4 reason=repo-missing\n'
  printf 'stub: --repo 目录不存在：[%s]\n' "$REPO" >&2
  exit 4
fi

RC="${STUB_RC_AUDIT_DIFF:-0}"
# 慢仓模拟：真实 audit-diff 在 job_copilot 大仓实测 11.6s（636 变更文件 / 1495617 行新增），
# 远超旧版 3s 局部预算。此处只睡不做判定，用于锁定「超时预算必须覆盖真实耗时」这条契约。
SLEEP="${STUB_SLEEP_AUDIT_DIFF:-0}"
case "$SLEEP" in
  ''|*[!0-9]*) printf 'stub: STUB_SLEEP_AUDIT_DIFF 须为非负整数（实得 [%s]）\n' "$SLEEP" >&2; exit 4 ;;
esac
if [ "$SLEEP" -gt 0 ]; then sleep "$SLEEP"; fi
printf 'STUB-AUDIT-DIFF rc=%s repo=%s\n' "$RC" "$REPO"
printf 'stub: audit-diff 模拟结论 rc=%s（非真实判定，仅供 ponygo observe 测试）\n' "$RC" >&2
exit "$RC"
