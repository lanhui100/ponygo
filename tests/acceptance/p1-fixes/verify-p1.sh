#!/usr/bin/env bash
# P1 修复验收（Lead 冻结；实施者只读不可改）
# 用法：bash tests/acceptance/p1-fixes/verify-p1.sh  → 全绿 exit 0
set -u
ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
CLI="$ROOT/ponygo"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
has() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1（缺 [$3]）" ;; esac; }
hasnt(){ case "$2" in *"$3"*) bad "$1（不应出现 [$3]）" ;; *) ok "$1" ;; esac; }
rc_chk(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1（期望 rc=$2 实得 $3）"; fi; }

SB=$(mktemp -d); trap 'rm -rf "$SB"' EXIT
MK_DIR=""
mk() { MK_DIR=$(mktemp -d "$SB/i.XXXXXX") || exit 1; cd "$MK_DIR" || exit 1; git init -q .; bash "$CLI" init >/dev/null 2>&1; }
add_adr() { mkdir -p .agents/notes/implemented/process
  cat > .agents/notes/implemented/process/2026-01-01-x.md <<'EOF'
# Agent Note: x

Status: implemented

## Problem

p

## Decision

d

## Alternatives considered

- a — 落选
EOF
}
add_gate() { # 合规实例门（spec 含拒绝断言）
  printf '#!/usr/bin/env bash\nexit 0\n' > .meta/gates/my-gate.sh
  cat > .meta/gates/my-gate.spec.sh <<'EOF'
#!/usr/bin/env bash
if bash .meta/gates/my-gate.sh --bad; then echo "门未拒绝"; exit 1; fi
exit 0
EOF
  chmod +x .meta/gates/my-gate*.sh
}
meta() { printf 'level: %s\n%s\n' "$1" "${2:-docs-tier: off}" > .meta/meta.yaml; }

echo "== P1-1 JSON 机读面（declared/verified/miss/exempt） =="
mk; meta 2 $'ai-surface: off\ndocs-tier: off'; add_adr; add_gate
j=$(bash "$CLI" status --json 2>/dev/null)
has "status --json 有 level_declared" "$j" '"level_declared"'
has "status --json 有 level_verified" "$j" '"level_verified"'
ja=$(bash "$CLI" audit --json 2>/dev/null)
has "audit --json 有 miss_ids" "$ja" '"miss_ids"'
has "audit --json 有 exempt_gates" "$ja" '"exempt_gates"'
has "exempt_gates 含 ci-verify 豁免" "$ja" 'ci-verify.sh'

echo "== P1-2 措辞：已接线 → 已挂载（未验证门会拒绝） =="
out=$(bash "$CLI" status 2>&1)
hasnt "status 不再写「已接线」" "$out" "已接线"
case "$out" in *"已挂载"*) ok "status 用「已挂载」" ;; *) bad "status 未用「已挂载」" ;; esac

echo "== P1-3 其它 forge：空 CI 文件不算载体 =="
mk; meta 1 $'ai-surface: off\ndocs-tier: off'; add_adr; : > .gitlab-ci.yml
j=$(bash "$CLI" status --json 2>/dev/null)
case "$j" in
  *'"unverified":["1.10"]'*|*'1.10'*) ok "空 gitlab CI 下 1.10 仍属未验证" ;;
  *) bad "空 gitlab CI 下 1.10 被当成已验证" ;;
esac

echo "== P1-4 自适应深度不被 init 自身产物触发 =="
mk; j=$(bash "$CLI" audit --json 2>/dev/null)
has "干净实例 audit tier = S" "$j" '"tier":"S"'

echo "== P1-5 HANDOFF 归家 + 失效口径 =="
[ -f "$ROOT/docs/dev-team/HANDOFF.md" ] && ok "HANDOFF 已迁入 docs/dev-team/" || bad "HANDOFF 未迁入 docs/dev-team/"
[ -f "$ROOT/docs/HANDOFF.md" ] && bad "旧 docs/HANDOFF.md 仍在" || ok "旧 docs/HANDOFF.md 已移除"
H="$ROOT/docs/dev-team/HANDOFF.md"; [ -f "$H" ] || H="$ROOT/docs/HANDOFF.md"
hasnt "HANDOFF 不再写 level 0-6" "$(cat "$H" 2>/dev/null)" "0-6"
hasnt "HANDOFF 不再写 .meta/decisions" "$(cat "$H" 2>/dev/null)" ".meta/decisions"

echo "== P1-6 家清单 / 索引补登 =="
has "docs-tier 家清单含 audit/" "$(cat "$ROOT/.meta/docs-tier/README.md")" 'audit/'
has "docs-tier 家清单含 maturity-ladder" "$(cat "$ROOT/.meta/docs-tier/README.md")" 'maturity-ladder'
has "README 索引含 install.sh" "$(sed -n '270,300p' "$ROOT/README.md")" 'install.sh'
has "README 索引含 .githooks" "$(sed -n '270,300p' "$ROOT/README.md")" '.githooks'

echo "== P1-7 off/retire 残留投影告警 =="
mk; sed -i 's/【TODO[^】]*】/filled/g' .meta/constitution/constitution.md
meta 2 $'ai-surface: on\ndocs-tier: off'; add_adr; add_gate; bash "$CLI" sync >/dev/null 2>&1
bash "$CLI" retire --level off >/dev/null 2>&1
out=$(bash "$CLI" status 2>&1)
case "$out" in *残留*|*手工删除*) ok "retire off 后 status 提示残留投影" ;; *) bad "retire off 后 status 未提示残留投影" ;; esac

echo "== P1-8 level 口径统一（当前档位） =="
has "meta.yaml 模板注释写「当前档位」" "$(sed -n '1,12p' "$ROOT/.meta/meta.yaml")" '当前档位'

echo ""
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
