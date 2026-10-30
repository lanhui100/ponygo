#!/usr/bin/env bash
# ============================================================
# scratch-hygiene.spec.sh —— scratch-hygiene 门禁的负样本与契约测试
#
# 契约：
#   - 自包含，只读真实仓库，样本一律在 mktemp -d 中构建并自动清理。
#   - exit 0 = 门禁在合规样本放行、非法样本拒绝（自检通过）。
# ============================================================
set -u

SPEC=scratch-hygiene.spec

# --- 防递归：被 audit --run-specs / CI 以 PONYGO_IN_SPEC=1 调用 → SKIPPED ---
if [ "${PONYGO_IN_SPEC:-0}" = "1" ] && [ "${PONYGO_SPEC_SELFRUN:-0}" != "1" ]; then
  printf '[%s] SKIPPED（PONYGO_IN_SPEC=1，不计入 PASS）\n' "$SPEC"
  exit 0
fi

# --- 秒级上限：自包裹 timeout 30，避免挂死拖死体检 ---
if [ "${PONYGO_SPEC_SELFRUN:-0}" != "1" ] && command -v timeout >/dev/null 2>&1; then
  export PONYGO_SPEC_SELFRUN=1
  exec timeout 30 bash "$0" "$@"
fi

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
GATE="$ROOT/.meta/gates/scratch-hygiene.sh"

TMPDIR_SPEC=$(mktemp -d)
trap 'rm -rf "$TMPDIR_SPEC"' EXIT

run_gate() {
  (cd "$TMPDIR_SPEC" && bash "$GATE")
}

# 1. 合规基准测试
(
  cd "$TMPDIR_SPEC"
  git init -q
  echo ".scratch/" > .gitignore
  mkdir -p .scratch
  echo "temp" > .scratch/temp.txt
)
if ! run_gate >/dev/null 2>&1; then
  echo "spec: FAIL 合规样本未能正常放行" >&2
  exit 1
fi

# 2. 负样本 E1: .scratch 被强制跟踪入库
(
  cd "$TMPDIR_SPEC"
  git add -f .scratch/temp.txt
)
if run_gate >/dev/null 2>&1; then
  echo "spec: FAIL [E1] 跟踪 .scratch 样本未被门禁拦截" >&2
  exit 1
fi
(
  cd "$TMPDIR_SPEC"
  git rm -q -f .scratch/temp.txt
)

# 3. 负样本 E2: .gitignore 丢失 .scratch/ 声明
(
  cd "$TMPDIR_SPEC"
  echo "" > .gitignore
)
if run_gate >/dev/null 2>&1; then
  echo "spec: FAIL [E2] 缺少 .gitignore 规则未被门禁拦截" >&2
  exit 1
fi
(
  cd "$TMPDIR_SPEC"
  echo ".scratch/" > .gitignore
)

# 4. 负样本 E3: 构建/发布脚本引用 .scratch
(
  cd "$TMPDIR_SPEC"
  echo "cp .scratch/foo ." > install.sh
)
if run_gate >/dev/null 2>&1; then
  echo "spec: FAIL [E3] 发布安装脚本引用 .scratch 未被门禁拦截" >&2
  exit 1
fi

echo "scratch-hygiene.spec: PASS（所有自检与负样本测试通过）"
exit 0
