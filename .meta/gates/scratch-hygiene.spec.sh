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

# `PONYGO_IN_SPEC` 是旧环境信息，不是自我跳过开关；本 spec 恒完整执行。

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

# 4. SCRATCH_E3_INSTALL：安装脚本独立夹具（不残留到 SCRATCH_E3_RELEASE）
TMPDIR_INSTALL="$TMPDIR_SPEC/install-case"
mkdir -p "$TMPDIR_INSTALL"
INSTALL_CASE="$TMPDIR_INSTALL"
[ ! -e "$INSTALL_CASE/.github/workflows/release.yml" ] || {
  echo "spec: FAIL [E3] install-case 不应包含 release.yml" >&2
  exit 1
}
(
  cd "$INSTALL_CASE"
  git init -q
  printf '.scratch/\n' > .gitignore
  echo "cp .scratch/foo ." > install.sh
)
if (cd "$INSTALL_CASE" && bash "$GATE") >"$INSTALL_CASE/gate.out" 2>&1; then
  echo "spec: FAIL [E3] 发布安装脚本引用 .scratch 未被门禁拦截" >&2
  exit 1
fi
grep -q '\[E3\]' "$INSTALL_CASE/gate.out" && grep -qF 'install.sh' "$INSTALL_CASE/gate.out" || {
  echo "spec: FAIL [E3] install.sh 拒绝证据不完整" >&2
  exit 1
}
printf 'SCRATCH_E3_INSTALL isolated\n'

# 5. SCRATCH_E3_RELEASE：独立 release-case 只含 release 违例，恢复后须放行
TMPDIR_RELEASE="$TMPDIR_SPEC/release-case"
mkdir -p "$TMPDIR_RELEASE"
RELEASE_CASE="$TMPDIR_RELEASE"
[ ! -e "$RELEASE_CASE/install.sh" ] || {
  echo "spec: FAIL [E3] release-case 不应包含 install.sh" >&2
  exit 1
}
(
  cd "$RELEASE_CASE"
  git init -q
  printf '.scratch/\n' > .gitignore
  mkdir -p .github/workflows
  printf 'jobs:\n  release:\n    steps:\n      - run: cp .scratch/artifact ponygo\n' > .github/workflows/release.yml
)
if (cd "$RELEASE_CASE" && bash "$GATE") >"$RELEASE_CASE/gate.out" 2>&1; then
  echo "spec: FAIL [E3] release.yml 引用 .scratch 未被门禁拦截" >&2
  exit 1
fi
grep -q '\[E3\]' "$RELEASE_CASE/gate.out" \
  && grep -qF '.github/workflows/release.yml' "$RELEASE_CASE/gate.out" \
  && grep -qF '.scratch' "$RELEASE_CASE/gate.out" || {
    echo "spec: FAIL [E3] release.yml 拒绝证据不完整" >&2
    exit 1
  }
printf 'jobs:\n  release:\n    steps:\n      - run: sha256sum ponygo\n' \
  > "$RELEASE_CASE/.github/workflows/release.yml"
if ! (cd "$RELEASE_CASE" && bash "$GATE") >/dev/null 2>&1; then
  echo "spec: FAIL [E3] release.yml 恢复后未重新放行" >&2
  exit 1
fi
printf 'SCRATCH_E3_RELEASE isolated\n'

echo "scratch-hygiene.spec: PASS（所有自检与负样本测试通过）"
exit 0
