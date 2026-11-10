#!/usr/bin/env bash
# ============================================================
# ci-verify.sh —— forge 无关的全树门（门禁资产 A4）
#
# 为什么需要它：CI 平台是外壳，门禁逻辑本体必须在本仓内**真实可执行**。
# 于是把"远端层要跑的检查"抽成本脚本：
#   - GitHub 由 10 行适配器 `.github/workflows/ponygo-governance.yml` 调它；
#   - GitLab / Jenkins / Drone / Azure / Bitbucket 在自己的流水线里加一行同样调用即可；
#   - 本地也能直接 `bash .meta/gates/ci-verify.sh` 复现远端结论（不用开 PR 才知道）。
# 平台适配器是薄壳（A5 不进宇宙表），门禁本体在这里（A4 恒生成、进宇宙表）。
#
# 三段：
#   1) 全树 ADR 格式（判定真源 verify-note.sh 无参模式：1.1–1.10，含 1.9 文档有家与 1.10 备选节）
#   2) 暂存区门的负样本 spec（证明 A1 会拒绝非法样本——门禁自证，非产品检查）
#   3) 归档 SHA-256 封印（A6 check + A7 负样本自检）——缺 A6/A7 时 **fail-closed**（exit 1），
#      不静默跳过：全树兜底门缺件 = 封印无人看守，按「未验证不得计为 PASS」处理。
#
# 约定：本目录脚本一律 `chmod +x`（非可执行钩子会被 git 静默忽略，判据会假达标）。
# 只读：不写仓库任何文件。
# ============================================================
set -u

ROOT=$(cd "$(dirname "$0")/../.." && pwd) || {
  echo "ci-verify: 无法解析仓库根" >&2
  exit 1
}
cd "$ROOT" || exit 1

fail=0

echo "== [1/3] 全树 ADR 格式（verify-note.sh，1.1–1.10）=="
if ! bash .agents/skills/write-adr/verify-note.sh; then
  echo "ci-verify: FAIL 全树 ADR 格式门未通过 → 逐项修 FAIL 后重跑" >&2
  fail=1
fi

echo "== [2/3] 暂存区门负样本 spec（adr-verify.spec.sh）=="
# 分开捕获真实退出码与输出：SKIPPED + 0 同样是未验证，不得被 ! 改写后洗成通过。
spec_out=$(bash .meta/gates/adr-verify.spec.sh 2>&1); spec_rc=$?
printf '%s\n' "$spec_out"
if [ "$spec_rc" -ne 0 ] || ! printf '%s\n' "$spec_out" | grep -qF '[adr-verify.spec] 全部通过'; then
  echo "ci-verify: FAIL 门禁自检未通过（exit $spec_rc；缺 A2 精确完成标记即未验证）" >&2
  fail=1
fi

echo "== [3/3] 归档封印（archive-verify.sh check + archive-verify.spec.sh）=="
if [ ! -f .meta/gates/archive-verify.sh ]; then
  echo "ci-verify: FAIL 第 3 段缺资产 .meta/gates/archive-verify.sh（fail-closed：缺件不得静默跳过）→ 跑 'ponygo init --repair-skeleton' 补齐" >&2
  fail=1
elif ! bash .meta/gates/archive-verify.sh check; then
  echo "ci-verify: FAIL 归档封印未通过（归档件被改动或未封印）→ 恢复原字节，或按 append-only 跑架构封印追加（archive-verify.sh seal）" >&2
  fail=1
fi
if [ ! -f .meta/gates/archive-verify.spec.sh ]; then
  echo "ci-verify: FAIL 第 3 段缺资产 .meta/gates/archive-verify.spec.sh（fail-closed：缺件不得静默跳过）→ 跑 'ponygo init --repair-skeleton' 补齐" >&2
  fail=1
else
  archive_spec_out=$(bash .meta/gates/archive-verify.spec.sh 2>&1); archive_spec_rc=$?
  printf '%s\n' "$archive_spec_out"
  if [ "$archive_spec_rc" -ne 0 ] || ! printf '%s\n' "$archive_spec_out" | grep -qF '== archive-verify.spec：通过（5 类负样本 + 1 合法样本全部符合预期）=='; then
    echo "ci-verify: FAIL 归档封印门自检未通过（exit $archive_spec_rc；缺 A7 精确完成标记即未验证）" >&2
    fail=1
  fi
fi

if [ "$fail" -ne 0 ]; then
  echo "ci-verify: 未通过（见上方 FAIL）" >&2
  exit 1
fi
echo "ci-verify: 通过（三段：全树 ADR 格式 + 暂存区门自检 + 归档封印）"
exit 0
