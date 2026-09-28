#!/usr/bin/env bash
# ponygo 一键安装脚本：零依赖，单文件安装与全局配置引导
set -euo pipefail

# 版本钉住（P0-3）：PONYGO_VERSION 指定 git ref（tag/分支/commit），默认 main。
# 生产环境建议钉 tag + 配 PONYGO_SHA256 校验和，避免"curl|bash 拉的是未知内容"。
VERSION="${PONYGO_VERSION:-main}"
REPO_RAW_URL="${PONYGO_SOURCE_URL:-https://raw.githubusercontent.com/lanhui100/ponygo/$VERSION/ponygo}"
BIN_DIR="${PONYGO_INSTALL_DIR:-${1:-$HOME/.local/bin}}"

info() { printf "\033[32m[ponygo:install]\033[0m %s\n" "$*"; }
warn() { printf "\033[33m[ponygo:install:warn]\033[0m %s\n" "$*"; }
die()  { printf "\033[31m[ponygo:install:error]\033[0m %s\n" "$*" >&2; exit 1; }

mkdir -p "$BIN_DIR" || die "无法创建安装目录: $BIN_DIR"
TARGET="$BIN_DIR/ponygo"

# 1. 获取 ponygo 执行脚本：优先本地已有文件（同目录/当前目录），否则 curl / wget 下载
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "")"
if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/ponygo" ]; then
  info "检测到本地源码，从 $SCRIPT_DIR/ponygo 复制..."
  cp -f "$SCRIPT_DIR/ponygo" "$TARGET"
elif [ -f "./ponygo" ]; then
  info "检测到当前目录源码，从 ./ponygo 复制..."
  cp -f "./ponygo" "$TARGET"
else
  info "从远端拉取最新 ponygo 脚本 ($REPO_RAW_URL)..."
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$REPO_RAW_URL" -o "$TARGET" || die "curl 下载失败: $REPO_RAW_URL"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$TARGET" "$REPO_RAW_URL" || die "wget 下载失败: $REPO_RAW_URL"
  else
    die "未找到 curl 或 wget，请先安装网络下载工具。"
  fi
fi

# 1.5 完整性校验（P0-3）：设置了 PONYGO_SHA256 就必须校验通过；
# 找不到校验工具时 fail-closed（拒绝未校验安装），不降级为跳过。
# 显式空串（PONYGO_SHA256=""）= 用户声明"要校验但给空值"→ 拒绝安装（fail-closed，非跳过）；
# 未设置（unset）= 未要求校验 → 允许（兼容分支，配合 README 未发布提示）。
if [ -n "${PONYGO_SHA256+x}" ]; then
  if [ -z "${PONYGO_SHA256}" ]; then
    rm -f "$TARGET"
    die "PONYGO_SHA256 已设置但为空——完整性校验要求非空校验和；拒绝未校验安装（fail-closed）"
  fi
  actual=""
  if command -v sha256sum >/dev/null 2>&1; then
    actual=$(sha256sum "$TARGET" | awk '{print $1}')
  elif command -v shasum >/dev/null 2>&1; then
    actual=$(shasum -a 256 "$TARGET" | awk '{print $1}')
  else
    die "已设置 PONYGO_SHA256 但找不到 sha256sum/shasum，无法校验——拒绝未校验安装。"
  fi
  if [ "$actual" != "$PONYGO_SHA256" ]; then
    rm -f "$TARGET"
    die "SHA-256 校验失败：期望 $PONYGO_SHA256，实得 $actual。已删除可疑文件。"
  fi
  info "SHA-256 校验通过。"
else
  warn "未设置 PONYGO_SHA256——安装未经完整性校验（生产环境建议钉版本 + 校验和，见 README §3.1）"
fi

chmod +x "$TARGET" || die "无法赋予执行权限: $TARGET"
info "已成功安装到: $TARGET"

# 2. 检查 PATH 并提示
case ":$PATH:" in
  *":$BIN_DIR:"*)
    info "PATH 检查通过：$BIN_DIR 已在系统环境中。"
    ;;
  *)
    warn "$BIN_DIR 尚未包含在当前 PATH 中！"
    info "请将以下内容追加到你的 Shell 配置文件（如 ~/.bashrc 或 ~/.zshrc）："
    printf "\n    export PATH=\"%s:\$PATH\"\n\n" "$BIN_DIR"
    info "并在当前终端执行一次：export PATH=\"$BIN_DIR:\$PATH\""
    ;;
esac

# 3. 校验运行
if [ -x "$TARGET" ]; then
  info "运行自检 (ponygo --help):"
  "$TARGET" --help | head -n 3
  info "ponygo 一键安装完成！"
fi
