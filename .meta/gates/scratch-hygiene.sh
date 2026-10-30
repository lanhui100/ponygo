#!/usr/bin/env bash
# ============================================================
# scratch-hygiene.sh —— 临时文件与工作区卫生门禁
#
# 退出码：0 放行 / 非零 阻断
#
# 检查项：
#   E1: 阻断 git ls-files 中出现 .scratch/ 路径（临时产物入库越界）
#   E2: 阻断 .gitignore 缺少 .scratch/ 声明（忽略策略未版本化）
#   E3: 阻断构建/发布脚本中显式引用 .scratch 路径（污染构建/部署链路）
# ============================================================
set -euo pipefail

ROOT="${PONYGO_WORKSPACE_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$ROOT"

fail=0

# E1: git ls-files 严禁包含 .scratch/ 路径
tracked_scratch=$(git ls-files .scratch 2>/dev/null || true)
if [ -n "$tracked_scratch" ]; then
  echo "scratch-hygiene: FAIL [E1] 检测到 .scratch/ 临时产物被 Git 跟踪：" >&2
  echo "$tracked_scratch" | sed 's/^/  /' >&2
  fail=1
fi

# E2: .gitignore 必须显式声明 .scratch/
if ! grep -qE '^\.scratch/?$' .gitignore 2>/dev/null; then
  echo "scratch-hygiene: FAIL [E2] 根目录 .gitignore 缺少 '.scratch/' 显式忽略规则" >&2
  fail=1
fi

# E3: 构建与发布文件不得显式引用 .scratch
build_artifacts=(".github/workflows/release.yml" "install.sh")
for f in "${build_artifacts[@]}"; do
  if [ -f "$f" ] && grep -q '\.scratch' "$f"; then
    echo "scratch-hygiene: FAIL [E3] 发布/安装构建链文件 ($f) 引用了临时目录 .scratch" >&2
    fail=1
  fi
done

if [ "$fail" -ne 0 ]; then
  echo "scratch-hygiene: 未通过检查（见上方 FAIL）" >&2
  exit 1
fi

echo "scratch-hygiene: PASS（工作区临时产物卫生合规）"
exit 0
