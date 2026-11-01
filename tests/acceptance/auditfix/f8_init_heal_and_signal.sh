#!/usr/bin/env bash
# F8（Wave-5 回归缺口，Lead 授权 · 最后一批 2 个用例）：
#   F8-1 **信号清理回归**（L3-P：既有断言无一覆盖 repair 的临时目录清理）：
#        隔离 TMPDIR 后在 `init --repair-skeleton` 运行中分别投递 SIGTERM / SIGINT，
#        断言退出码 143 / 130、TMPDIR 零残留、目标骨架文件无半截（0 字节/截断）。
#        拖住进程用「慢 mkdir」shim（write_skeleton 的第一个外部命令）——**无 sleep 轮询**：
#        由外部 `timeout --preserve-status -s <sig> 1` 在固定时刻投递信号，shim 只负责让进程
#        停在中途；shim 被调用即证明「已越过 mktemp -d、进入写入路径」（否则断言直接红，不静默放行）。
#   F8-2 **0 字节 / 截断 pre-commit 自愈回归**（L3 收口复审唯一 BLOCKING）：
#        0 字节 + 0755 → init 后字节数 >0、bash -n rc=0、status 的 2.4 由 FAIL 转 PASS；
#        114B 纯残块 → init 后不得变 0 字节、BEGIN/END 各 1、bash -n rc=0。
# 冻结契约来源：Lead 授权（W5 回归缺口补测）；不改变任何既有判据。
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

BEGIN_LINE='# >>> ponygo-gate: adr-verify v1 >>>'
END_LINE='# <<< ponygo-gate: adr-verify v1 <<<'

count_line() { printf '%s\n' "$2" | grep -c -x -F -- "$1"; }

# ---------- 慢 mkdir shim：让被测进程稳定停在中途（不 sleep 轮询） ----------
write_slow_mkdir_shim() { # <shim 目录> <mark 文件>
  mkdir -p "$1"
  cat > "$1/mkdir" <<'SHIMEOF'
#!/usr/bin/env bash
# 验收夹具：write_skeleton 的第一个外部命令是 mkdir -p；首次被调用时占住一段时间，
# 使外部 timeout 能在「已创建临时目录、尚未写骨架文件」的窗口内稳定投递信号。
if [ -n "${SHIM_MARK:-}" ] && [ ! -e "$SHIM_MARK" ]; then
  : > "$SHIM_MARK"
  sleep 30
fi
exec /bin/mkdir "$@"
SHIMEOF
  chmod +x "$1/mkdir"
}

# 目标骨架文件「无半截」判据：要么仍缺失，要么字节数 >0 且与模板逐字节相同
assert_not_truncated() { # <描述> <目标文件> <模板文件 md5>
  local desc="$1" f="$2" refmd5="$3"
  if [ ! -e "$f" ]; then
    ok "$desc（信号中断后该文件仍缺失 = 无半截，合法二态之一）"
    return 0
  fi
  if [ ! -s "$f" ]; then
    bad "$desc（出现 0 字节半截文件：$f）"
    return 0
  fi
  assert_eq "$desc（存在即须与模板逐字节相同）" "$refmd5" "$(md5_of "$f")"
}

signal_case() { # <信号名 TERM|INT> <期望退出码>
  local sig="$1" want="$2" T REF TMPD SHIM MARK RC refmd5_notes refmd5_skills
  T=$(new_case)
  REF=$(new_case)
  run_in "$REF" init
  assert_zero "F8-1($sig) 夹具：参考仓 init exit 0" "$R_RC"
  refmd5_notes=$(md5_of "$REF/.agents/notes/README.md")
  refmd5_skills=$(md5_of "$REF/.agents/skills/README.md")

  gov_repo "$T" 1 || return 0
  rm -f "$T/.agents/notes/README.md" "$T/.agents/skills/README.md"
  assert_missing "F8-1($sig) 夹具：造出 2 个骨架缺口" "$T/.agents/notes/README.md"

  TMPD="$T/.tmpd"; mkdir -p "$TMPD"
  SHIM="$T/.shim"; MARK="$T/.shim-mark"
  write_slow_mkdir_shim "$SHIM" "$MARK"

  RC=0
  ( cd "$T" && TMPDIR="$TMPD" SHIM_MARK="$MARK" PATH="$SHIM:$PATH" \
      timeout --preserve-status -s "$sig" 1 bash "$ROOT/ponygo" init --repair-skeleton \
      > "$T/.signal-out" 2>&1 ) || RC=$?
  assert_rc_is "F8-1($sig) 信号中断 → 退出码 $want" "$want" "$RC"
  assert_exists "F8-1($sig) 已进入写入路径（慢 mkdir 被调用，信号不是打在启动阶段）" "$MARK"
  assert_eq "F8-1($sig) TMPDIR 零残留目录（信号路径必须清理临时目录）" "" \
    "$(find "$TMPD" -mindepth 1 -print -quit 2>/dev/null)"
  assert_eq "F8-1($sig) 仓内无 0 字节骨架文件" "" \
    "$(find "$T/.agents" "$T/.meta" -type f -size 0 -print -quit 2>/dev/null)"
  assert_not_truncated "F8-1($sig) .agents/notes/README.md 无半截" "$T/.agents/notes/README.md" "$refmd5_notes"
  assert_not_truncated "F8-1($sig) .agents/skills/README.md 无半截" "$T/.agents/skills/README.md" "$refmd5_skills"
}

# ================= F8-1：SIGTERM / SIGINT 清理回归 =================
signal_case TERM 143
signal_case INT 130

# ================= F8-2a：0 字节 pre-commit → init 自愈 =================
T=$(new_case)
if gov_repo "$T" 2; then
  HOOK="$T/.githooks/pre-commit"
  assert_exists "F8-2a 夹具：pre-commit 初始存在（init 已装配）" "$HOOK"
  : > "$HOOK"
  chmod 755 "$HOOK"
  assert_eq "F8-2a 夹具：已置 0 字节" 0 "$(wc -c < "$HOOK" | tr -d ' ')"

  run_in "$T" status
  assert_rc_is "F8-2a 0 字节钩子 → status exit 1" 1 "$R_RC"
  assert_contains "F8-2a 取证：2.4 判据报未接 ADR 门" "$R_OUT" "2.4"

  run_in "$T" init
  assert_zero "F8-2a init（0 字节钩子）→ exit 0" "$R_RC"
  SIZE=$(wc -c < "$HOOK" 2>/dev/null | tr -d ' ')
  if [ "${SIZE:-0}" -gt 0 ]; then
    ok "F8-2a 自愈：钩子字节数 > 0（实得 $SIZE）"
  else
    bad "F8-2a 自愈失败：钩子仍是 0 字节"
  fi
  ( cd "$T" && bash -n .githooks/pre-commit ) 2>/dev/null
  assert_zero "F8-2a bash -n 钩子语法检查 → rc 0" "$?"

  run_in "$T" status
  assert_zero "F8-2a 自愈后 status exit 0（2.4 由 FAIL 转 PASS）" "$R_RC"
  assert_not_contains "F8-2a 2.4 不再报未接 ADR 门" "$R_OUT" "2.4 本地层未接 ADR 门"
fi

# ================= F8-2b：114B 纯残块 → init 自愈（不得留残块/语法坏） =================
T=$(new_case)
REF=$(new_case)
( cd "$REF" && git init -q . >/dev/null 2>&1 )   # 参考仓必须是 git 仓：非 git 目录 init 不装配钩子
run_in "$REF" init
assert_zero "F8-2b 夹具：参考仓 init exit 0" "$R_RC"
assert_exists "F8-2b 夹具：参考仓 pre-commit 存在" "$REF/.githooks/pre-commit"
if gov_repo "$T" 2; then
  HOOK="$T/.githooks/pre-commit"
  head -c 114 "$REF/.githooks/pre-commit" > "$HOOK"
  chmod 755 "$HOOK"
  assert_eq "F8-2b 夹具：残块恰 114 字节" 114 "$(wc -c < "$HOOK" | tr -d ' ')"

  run_in "$T" init
  SIZE=$(wc -c < "$HOOK" 2>/dev/null | tr -d ' ')
  if [ "${SIZE:-0}" -gt 0 ]; then
    ok "F8-2b 自愈：钩子不得变 0 字节（实得 $SIZE）"
  else
    bad "F8-2b 自愈失败：钩子变成 0 字节"
  fi
  HOOK_TXT=$(cat "$HOOK" 2>/dev/null || :)
  assert_eq "F8-2b 自愈：BEGIN 哨兵恰 1 个" 1 "$(count_line "$BEGIN_LINE" "$HOOK_TXT")"
  assert_eq "F8-2b 自愈：END 哨兵恰 1 个" 1 "$(count_line "$END_LINE" "$HOOK_TXT")"
  ( cd "$T" && bash -n .githooks/pre-commit ) 2>/dev/null
  assert_zero "F8-2b 自愈后钩子 bash -n → rc 0（残块不得留下语法坏文件）" "$?"
fi

finish
