#!/usr/bin/env bash
# P0 修复验收（Lead 冻结；实施者只读不可改）
# 用法：bash tests/acceptance/p0-fixes/verify-p0.sh
# 语义：全绿 exit 0；任一 FAIL exit 1。所有实例一律 mktemp -d，不污染仓库。
set -u

ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
CLI="$ROOT/ponygo"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad() {
  FAIL=$((FAIL+1))
  printf '  FAIL %s\n' "$1"
  # 诊断副本写 stderr：CI 上 s92 曾只看到段头 + PASS=15 FAIL=2，失败原文被吞（run 43043638972）。
  # 计数只在上面 +1 一次，stderr 行不参与判定，也不进 PASS/FAIL 汇总。
  printf '  FAIL %s\n' "$1" >&2
}
chk() { # <desc> <期望rc> <实际rc>
  if [ "$2" = "$3" ]; then ok "$1"; else bad "$1（期望 rc=$2 实得 rc=$3）"; fi
}
chk_contains() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1（输出缺 [$3]）" ;; esac; }
chk_missing()  { case "$2" in *"$3"*) bad "$1（不应出现 [$3]）" ;; *) ok "$1" ;; esac; }
# 输出可见性（CI 日志硬化）：不匹配时把**实际输出尾部**打到 stderr，
# 避免只看到「输出缺 […]」却不知道被测到底输出了什么（Windows 排障必需）。
show_tail() { # <标签> <文本>
  printf '    ↳ %s 实际输出尾部：%s\n' "$1" \
    "$(printf '%s' "${2:-}" | tail -n 3 | tr '\n' '|')" >&2
}


SB=$(mktemp -d); trap 'rm -rf "$SB"' EXIT
# 平台取证（CI 日志用）：Windows 失败的排障需要知道 OSTYPE/uname/$SB 形态；
# 只写 stderr，不参与 PASS/FAIL 计数，也不改任何断言语义。
case "${OSTYPE:-}" in
  msys* | cygwin* | MSYS* | CYGWIN*)
    printf 'WIN-DIAG：OSTYPE=%s uname=%s SB=%s PWD=%s\n' \
      "${OSTYPE:-}" "$(uname -s 2>/dev/null)" "$SB" "$PWD" >&2
    ;;
esac
# 沙箱逃逸 fail-closed：任何写盘动作前断言 cwd 在 $SB 下。
# 反例（曾发生）：d=$(mk) 在子 shell 里 cd，父进程 cwd 不变 → 相对路径写盘落到仓库根，
# 把 .meta/meta.yaml 覆盖成桩、往 .meta/gates 塞 my-gate.sh、往 adr-verify.sh 追加篡改行。
require_sandbox() {
  # Windows/MSYS 语义差异（CI run 43031069740 排查项）：`mktemp -d` 返回 /tmp/... 而 cd 之后
  # `$PWD` 可能是 C:/Users/... 形态，字符串前缀比对会误报「沙箱逃逸」。改为比对**物理路径**
  # （cd -P / pwd -P），判据仍是「cwd 必须落在沙箱下」，未放宽为任何形式的放行。
  local sb_real pwd_real
  sb_real=$(cd "$SB" 2>/dev/null && pwd -P) || sb_real="$SB"
  pwd_real=$(pwd -P 2>/dev/null) || pwd_real="$PWD"
  case "$pwd_real" in
    "$sb_real"/*) ;;
    *)
      printf 'FAIL 沙箱逃逸：cwd=%s（real=%s）不在沙箱 %s（real=%s）下（拒绝写盘）\n' \
        "$PWD" "$pwd_real" "$SB" "$sb_real" >&2
      exit 1
      ;;
  esac
}
mk() { # 新实例：mkdir + git init + init。在当前 shell 内 cd（调用方直接 `mk` 而非 `$(mk)`）
  local d; d=$(mktemp -d "$SB/i.XXXXXX")
  cd "$d" || exit 1
  require_sandbox
  git init -q . || exit 1
  bash "$CLI" init >/dev/null 2>&1
  printf '%s' "$d"
}
add_adr() { # 合规最小 ADR（1.5–1.8 + 1.10 全过）
  require_sandbox
  mkdir -p .agents/notes/implemented/process
  cat > .agents/notes/implemented/process/2026-01-01-x.md <<'EOF'
# Agent Note: x

Status: implemented

## Problem

p

## Decision

d

## Alternatives considered

- a — 落选原因
EOF
}
fill_const() { require_sandbox; sed -i 's/【TODO[^】]*】/filled/g' .meta/constitution/constitution.md; }
meta() { require_sandbox; printf 'level: %s\n%s\n' "$1" "${2:-docs-tier: off}" > .meta/meta.yaml; }
sync_out() { bash "$CLI" sync 2>&1 | tr -d '\r'; }

echo "== P0-1 ai-surface 默认态 =="
# A：填槽态 + 无 ai-surface 键 → 不得投影常载命约
mk; fill_const; meta 2; rm -f AGENTS.md CLAUDE.md
out=$(sync_out)
if [ -f AGENTS.md ] && grep -q 'BEGIN constitution' AGENTS.md; then
  bad "A 填槽+无键：不应投影命约（AGENTS.md 含 BEGIN constitution）"
else ok "A 填槽+无键：未投影命约"; fi
# B：填槽 + off + 残留投影 → 必须 WARN 残留
mk; fill_const; meta 2 $'ai-surface: off\ndocs-tier: off'
printf '<!-- BEGIN constitution -->\n残留\n<!-- END constitution -->\n' > AGENTS.md
out=$(sync_out)
case "$out" in *残留*|*WARN*|*警告*) ok "B off+残留：给出残留提示" ;; *) bad "B off+残留：未提示残留投影"; show_tail "B" "$out" ;; esac
# C：填槽 + on → 投影（回归）
mk; fill_const; meta 2 $'ai-surface: on\ndocs-tier: off'
out=$(sync_out)
if [ -f AGENTS.md ] && grep -q 'BEGIN constitution' AGENTS.md; then ok "C 填槽+on：正常投影"; else bad "C 填槽+on：未投影"; fi
# D：模板态 → 投影 bootstrap（回归）
mk
out=$(sync_out)
if [ -f AGENTS.md ] && grep -q 'BEGIN constitution' AGENTS.md; then ok "D 模板态：bootstrap 投影保留"; else bad "D 模板态：bootstrap 投影丢失"; fi

echo "== P0-2 L2 必须 ≥1 实例门 =="
mk; meta 2 $'ai-surface: off\ndocs-tier: off'; add_adr
out=$(bash "$CLI" audit --json 2>/dev/null); rc=$?
out=$(printf '%s' "$out" | tr -d '\r')   # 行尾归一化放在取 rc 之后，避免管道吞掉被测退出码
chk "E 零实例门：audit 拒绝（exit 1）" 1 "$rc"
chk_contains "E 零实例门：判据 2.3 报 FAIL" "$out" '"2.3"'

echo "== P0-3 spec 最小拒绝断言 =="
mk; meta 2 $'ai-surface: off\ndocs-tier: off'; add_adr
require_sandbox
printf '#!/usr/bin/env bash\nexit 0\n' > .meta/gates/my-gate.sh
require_sandbox
printf '#!/usr/bin/env bash\nexit 0\n' > .meta/gates/my-gate.spec.sh
chmod +x .meta/gates/my-gate.sh .meta/gates/my-gate.spec.sh
out=$(bash "$CLI" audit 2>&1); rc=$?
out=$(printf '%s' "$out" | tr -d '\r')
chk "F 空壳 spec：audit 拒绝（exit 1）" 1 "$rc"
case "$out" in *拒绝断言*|*negative*|*负样本*|*2.3*) ok "F 空壳 spec：报 2.3 缺拒绝断言" ;; *) bad "F 空壳 spec：未报 2.3"; show_tail "F" "$out" ;; esac
# 回归：含拒绝断言 + 自检通过的 spec → PASS
mk; meta 2 $'ai-surface: off\ndocs-tier: off'; add_adr
require_sandbox
printf '#!/usr/bin/env bash\nexit 0\n' > .meta/gates/my-gate.sh
require_sandbox
cat > .meta/gates/my-gate.spec.sh <<'EOF'
#!/usr/bin/env bash
# 负样本：违规输入必须被门拒绝
if bash .meta/gates/my-gate.sh --bad; then echo "门未拒绝"; exit 1; fi
exit 0
EOF
chmod +x .meta/gates/my-gate.sh .meta/gates/my-gate.spec.sh
bash "$CLI" audit >/dev/null 2>&1; chk "G 合规 spec：audit 通过（exit 0）" 0 "$?"

echo "== P0-4 框架门资产漂移纳入判定 =="
mk; meta 2 $'ai-surface: off\ndocs-tier: off'; add_adr
require_sandbox
printf '\n# tampered\n' >> .meta/gates/adr-verify.sh
out=$(bash "$CLI" status 2>&1); rc=$?
out=$(printf '%s' "$out" | tr -d '\r')
chk "H 门资产被改：status 拒绝（exit 1）" 1 "$rc"
case "$out" in *漂移*|*替换*|*drift*) ok "H 门资产被改：报文提及漂移" ;; *) bad "H 门资产被改：报文未提及漂移"; show_tail "H" "$out" ;; esac

echo "== P0-5 硬数字 =="
# CRLF 容错：Windows 检出（core.autocrlf）会把行尾改成 CRLF，`^s…$` 会因行尾 \r 全部不匹配
# 而把计数算成 0（CI run 43031069740 的 s92 红项之一）；先剥 \r 再计数，语义不变。
SCN=$(tr -d '\r' < "$ROOT/tests/run.sh" | grep -cE '^s[0-9]+_[a-z0-9_]+$')
chk_contains "I-1 README 场景数与 run.sh 枚举一致（$SCN）" "$(tr -d '\r' < "$ROOT/README.md" | sed -n '270,300p')" "$SCN 场景" 
chk_contains "I-2 depth-selector 骨架 9" "$(tr -d '\r' < "$ROOT/audit/depth-selector.md" | grep -o '骨架 9' | head -1)" '骨架 9'
chk_contains "I-3a depth-selector S total=12" "$(tr -d '\r' < "$ROOT/audit/depth-selector.md")" 'total=12'
chk_contains "I-3b depth-selector M total=16" "$(tr -d '\r' < "$ROOT/audit/depth-selector.md")" 'total=16'
chk_contains "I-4 maturity-ladder doc-sync 43 叶" "$(tr -d '\r' < "$ROOT/maturity-ladder.md" | grep -o '43 叶' | head -1)" '43 叶'

echo "== 回归：干净实例（不依赖本仓工作区状态） =="
mk; bash "$CLI" status >/dev/null 2>&1; chk "J 干净新实例 status exit 0" 0 "$?"

echo ""
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
