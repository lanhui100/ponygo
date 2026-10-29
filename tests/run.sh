#!/usr/bin/env bash
# ============================================================
# ponygo 自测（纯 bash、零依赖；mktemp 场景化，不污染仓库）
# 用法：bash tests/run.sh   （任何失败 → 结尾 exit 1）
# 场景一律在临时目录跑（cwd 隔离），以 bash "$ROOT/ponygo" 调用，
# 规避 clone 后 exec bit / shebang 问题（spec rev3 P0-2）。
# ============================================================
set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
CLI() { bash "$ROOT/ponygo" "$@"; }

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }

assert_eq() { # <描述> <期望> <实得>
  if [ "$2" = "$3" ]; then ok "$1"; else bad "$1（期望 [$2] 实得 [$3]）"; fi
}
assert_contains() { # <描述> <整体> <子串>
  case "$2" in *"$3"*) ok "$1" ;; *) bad "$1（未找到 [$3]）" ;; esac
}
assert_not_contains() { # <描述> <整体> <子串>
  case "$2" in *"$3"*) bad "$1（不应出现 [$3]）" ;; *) ok "$1" ;; esac
}

# 所有场景共用一个临时基目录，中断也清理（reviewer-b P3-6）
SBASE=$(mktemp -d)
trap 'rm -rf "$SBASE"' EXIT
new_case() { mktemp -d "$SBASE/case.XXXXXX"; }

# 在指定目录跑 ponygo；R_OUT 合并 stdout+stderr，R_RC 为退出码
R_OUT=""; R_RC=0
run_cli() {
  local dir="$1"; shift
  R_OUT=$(cd "$dir" && CLI "$@" 2>&1)
  R_RC=$?
}
# 同 run_cli，但注入环境变量（形如 VAR=val 的前导参数，遇到首个非 VAR=val 停止；
# 用 "$@" 逐个传给 env，值含空格也安全。场景9/12 的 git 配置消毒用）。
# 注：env 起不了 shell 函数，这里直接 bash "$ROOT/ponygo"
run_cli_env() {
  local dir="$1"; shift
  local -a envs=()
  while [ $# -gt 0 ]; do
    case "$1" in *=*) envs+=("$1"); shift ;; *) break ;; esac
  done
  R_OUT=$(cd "$dir" && env "${envs[@]}" bash "$ROOT/ponygo" "$@" 2>&1)
  R_RC=$?
}

# git 配置消毒（rev3 P0-2：命中数/钩子判定不得读机器全局配置）
sanitize_git() {
  local G; G=$(mktemp "$SBASE/gitconf.XXXXXX"); : > "$G"
  printf 'GIT_CONFIG_GLOBAL=%s GIT_CONFIG_SYSTEM=%s' "$G" "$G"
}

# ---- 断言补件（s46+ 用；一律是真断言：禁「跑了没报错即 pass」）----
assert_nonzero() { # <描述> <实得 rc>
  case "${2:-0}" in
    0) bad "$1（期望非零，实得 0）" ;;
    *) ok "$1" ;;
  esac
}
assert_exists()    { [ -e "$2" ] && ok "$1" || bad "$1（缺失 $2）"; }
assert_missing()   { [ ! -e "$2" ] && ok "$1" || bad "$1（不应存在 $2）"; }
assert_exec()      { [ -x "$2" ] && ok "$1" || bad "$1（无执行位 $2）"; }
assert_file_has() { # <描述> <文件> <固定串>
  if [ -f "$2" ] && grep -qF -- "$3" "$2"; then ok "$1"; else bad "$1（$2 缺 [$3]）"; fi
}
md5_of() { # <文件> → md5；文件缺失打印 MISSING（防「空==空」假绿）
  if [ -f "$1" ]; then md5sum "$1" 2>/dev/null | awk '{print $1}'; else printf 'MISSING'; fi
}
# 双写一致性断言（照 s14 写法 + 失败时打印 diff 便于定位）
assert_same_as_template() { # <描述> <生成文件> <模板文件>
  local d
  if [ ! -f "$3" ]; then bad "$1（仓库模板缺失：$3）"; return 0; fi
  if [ ! -f "$2" ]; then bad "$1（未生成：$2）"; return 0; fi
  if d=$(diff <(tr -d '\r' < "$2") <(tr -d '\r' < "$3") 2>&1); then
    ok "$1"
  else
    bad "$1（eol 归一后不一致）"
    printf '%s\n' "$d" | sed -n '1,8p' >&2
  fi
}

# ---- ADR 门禁装配夹具（契约真源：.dev-team/plan-freeze.md §2/§6.5/§6.6）----
# 说明：s12/s24/s28 的正例夹具按 §6.6 加强后的 2.4 判据补装配（哨兵块 + 非注释调用行
# + 执行位 + A1 资产），属**判据加强**，断言一条不删、不弱化。
GATE_MARKER='# >>> ponygo-gate: adr-verify v1 >>>'
GATE_MARKER_END='# <<< ponygo-gate: adr-verify v1 <<<'

# 前置哨兵块（F1 口径，plan-freeze §7 F1 / 与 ponygo 生成器一致）：
# 插在 `#!` 首行之后（无 shebang 则文件最前），既有字节的顺序与内容**零改动**；
# 已含哨兵尾行则视为已接线、不重复插（幂等）。随后补执行位。
# 为什么不再末尾追加：既有钩子以 `exit 0`/`exec` 结尾时末尾块永不执行 = 假接线（B1 BLOCKING），
# 新 2.4 判据要求块可执行，故夹具必须与真生成器同构，否则测的是「永不运行的块」。
prepend_gate_block() { # <hook-file>
  local f="$1" block tmp
  [ -d "$(dirname "$f")" ] || mkdir -p "$(dirname "$f")"
  [ -f "$f" ] || printf '#!/usr/bin/env bash\n' > "$f"
  grep -qxF "$GATE_MARKER_END" "$f" 2>/dev/null && { chmod +x "$f"; return 0; }
  block="$SBASE/gate.block"
  {
    printf '%s\n' "$GATE_MARKER"
    printf 'if [ -f "$(git rev-parse --show-toplevel)/.meta/gates/adr-verify.sh" ]; then\n'
    printf '  bash "$(git rev-parse --show-toplevel)/.meta/gates/adr-verify.sh" || exit 1\n'
    printf 'fi\n'
    printf '%s\n' "$GATE_MARKER_END"
  } > "$block"
  tmp="$f.ponygo-tmp"
  if head -n1 "$f" 2>/dev/null | grep -q '^#!'; then
    { head -n1 "$f"; cat "$block"; tail -n +2 "$f"; } > "$tmp"
  else
    { cat "$block"; cat "$f"; } > "$tmp"
  fi
  mv -f "$tmp" "$f"
  chmod +x "$f"
}

# A1 资产存在性垫片（2.4 ⑤）：init 已生成则不覆盖（夹具不得吃掉被测产物）
ensure_gate_asset() { # <case-dir>
  local f="$1/.meta/gates/adr-verify.sh"
  mkdir -p "$(dirname "$f")"
  [ -s "$f" ] || printf '#!/usr/bin/env bash\n# fixture stub（init 未生成 A1 时的存在性垫片，不参与判定）\nexit 0\n' > "$f"
  chmod +x "$f"
}

# 正例夹具装配：手工钩子升级为「已接线」形态（F1 口径：块前置 shebang 之后）
wire_gate_fixture() { # <case-dir> [hook 相对路径]
  local T="$1" rel="${2:-.githooks/pre-commit}"
  ensure_gate_asset "$T"
  prepend_gate_block "$T/$rel"
}

# ---- git 夹具（一律消毒：不读机器全局配置，跨机同结论）----
git_local() { # <dir> <git args...>
  local dir="$1"; shift
  local G; G=$(sanitize_git)
  # shellcheck disable=SC2086
  ( cd "$dir" && env $G git "$@" )
}
hookspath_of() { git_local "$1" config core.hooksPath 2>/dev/null || true; }
# 建仓 + 一个初始提交（--no-verify：装配前的提交不被新钩子拦）
git_seed_repo() { # <dir>
  ( cd "$1" && git init -q . >/dev/null 2>&1 \
      && printf '# seed\n' > README.md \
      && git add -A >/dev/null 2>&1 \
      && git -c user.email=t@t -c user.name=t -c commit.gpgsign=false \
           commit -qm seed --no-verify >/dev/null 2>&1 ) || :
  [ -d "$1/.git" ] || mkdir -p "$1/.git"
}
# 直跑仓库内脚本（A1/A2 等资产的执行语义），捕获合并输出与 rc
S_RC=0; S_OUT=""
run_script() { # <dir> <脚本相对路径> [args...]
  local dir="$1"; shift
  S_OUT=$( cd "$dir" && bash "$@" 2>&1 ); S_RC=$?
}

# ---- 场景素材 ----
write_constitution_filled() { # 填掉 constitution 全部 TODO 槽位
  sed -i -e 's/【TODO: 填项目名】/ponygo-test/' \
         -e 's/【TODO: 填一句话定位】/a test project/' \
         -e 's/【TODO: 填技术栈】/bash/' \
         -e 's/【TODO: 填，如 L2】/L2/' \
         "$1/.meta/constitution/constitution.md"
}
write_valid_decision() { # $1=case目录 $2=相对 decisions/ 的子路径（含文件名）
  local dir
  dir="$1/.agents/notes/$(dirname "$2")"
  mkdir -p "$dir"
  cat > "$dir/$(basename "$2")" <<'EOF'
# Agent Note: test decision

Status: implemented

## Problem
why

## Decision
what

## Alternatives considered
other
EOF
}
write_proposal_decision() { # $1=case目录 $2=相对 decisions/ 的子路径（含文件名）
  local dir
  dir="$1/.agents/notes/$(dirname "$2")"
  mkdir -p "$dir"
  cat > "$dir/$(basename "$2")" <<'EOF'
# Agent Note: test proposal

Status: proposed

## Problem
why

## Proposal
what

## Alternatives considered
other

## Acceptance criteria
how verified

## Risks
what could go wrong
EOF
}
# 1.10 反例夹具（2026-10-29 起 `## Alternatives considered` 是硬判据）：
# 合法骨架但**故意缺**备选节——只供「1.10 应拒绝」类用例使用。
# 严禁拿它当"应通过 verify-note"的样本（否则新判据落地后合法变红）；要合规请用
# write_valid_decision / write_proposal_decision（两者已含该节）。
write_no_alt_decision() { # $1=case目录 $2=相对 notes 的子路径（含文件名）
  local dir
  dir="$1/.agents/notes/$(dirname "$2")"
  mkdir -p "$dir"
  cat > "$dir/$(basename "$2")" <<'EOF'
# Agent Note: test decision without alternatives

Status: implemented

## Problem
why

## Decision
what
EOF
}

# ============================================================
s01_help() {
  echo "--- 场景1：help 六命令 + 未知子命令"
  local c
  run_cli "$ROOT" --help
  assert_eq "help exit 0" 0 "$R_RC"
  for c in init audit status upgrade sync retire; do
    assert_contains "help 含 $c" "$R_OUT" "$c"
  done
  run_cli "$(new_case)" frobnicate
  assert_eq "未知子命令 die exit 1" 1 "$R_RC"
  assert_contains "未知子命令报错" "$R_OUT" "未知参数或子命令"
}

s02_init() {
  echo "--- 场景2：init 骨架 + 不投影 + 重复 init"
  local T d; T=$(new_case)
  run_cli "$T" init
  assert_eq "init exit 0" 0 "$R_RC"
  for d in proposed implemented rejected archived; do
    [ -d "$T/.agents/notes/$d" ] && ok "notes/$d 存在" || bad "notes/$d 缺失"
  done
  for d in constitution gates docs-tier; do
    [ -d "$T/.meta/$d" ] && ok ".meta/$d 存在" || bad ".meta/$d 缺失"
  done
  [ -d "$T/.agents/skills" ] && ok ".agents/skills 存在" || bad ".agents/skills 缺失"
  grep -qF '/.agents/notes/archived/' "$T/.rgignore" && ok ".rgignore 归档隔离" || bad ".rgignore 缺归档隔离"
  [ -f "$T/.gitignore" ] && ok ".gitignore 生成" || bad ".gitignore 缺失"
  [ -f "$T/.meta/meta.yaml" ] && ok "meta.yaml 存在" || bad "meta.yaml 缺失"
  grep -q '^level: 0' "$T/.meta/meta.yaml" && ok "level: 0" || bad "level 字段异常"
  [ -f "$T/.agents/notes/README.md" ] && ok "decisions/README.md 生成" || bad "decisions/README.md 缺失"
  [ -f "$T/.agents/skills/write-adr/SKILL.md" ] && ok "预置 write-adr 技能" || bad "write-adr 技能缺失"
  grep -q '何时用' "$T/.agents/skills/write-adr/SKILL.md" && ok "write-adr 含触发式 description" || bad "write-adr 缺触发式 description"
  [ -f "$T/.agents/skills/write-adr/verify-note.sh" ] && ok "verify-note.sh 随骨架生成" || bad "verify-note.sh 缺失"
  [ -f "$T/.agents/skills/governance-review/SKILL.md" ] && ok "governance-review 预置" || bad "governance-review 缺失"
  grep -q 'disable-model-invocation: true' "$T/.agents/skills/governance-review/SKILL.md" && ok "governance-review 禁自主路由" || bad "governance-review 未禁自主路由"
  [ -f "$T/docs/AGENTS.md" ] && ok "文档标准家 docs/AGENTS.md 生成（agent 自动加载）" || bad "docs/AGENTS.md 缺失"
  [ -f "$T/README.md" ] && ok "根 README 人读契约生成" || bad "根 README 缺失"
  [ -f "$T/.agents/notes/AGENTS.md" ] && ok "notes/AGENTS.md 生成（写前检索义务自动加载）" || bad "notes/AGENTS.md 缺失"
  [ -f "$T/.agents/notes/archived/AGENTS.md" ] && ok "archived/AGENTS.md 生成（冻结规则自动加载）" || bad "archived/AGENTS.md 缺失"
  [ -f "$T/.agents/skills/change-review/SKILL.md" ] && ok "change-review 预置（读侧入口）" || bad "change-review 缺失"
  grep -q '何时用' "$T/.agents/skills/change-review/SKILL.md" && ok "change-review 含触发式 description" || bad "change-review 缺触发式 description"
  grep -q '读触发规则' "$T/.agents/notes/README.md" && ok "notes/README 含读触发枚举" || bad "notes/README 缺读触发枚举"
  [ -f "$T/AGENTS.md" ] && [ -f "$T/CLAUDE.md" ] && ok "模板态投影初始引导（bootstrap）" || bad "模板态未投影初始引导"
  grep -q '初始引导' "$T/AGENTS.md" && ok "投影含 bootstrap 标记" || bad "投影缺 bootstrap 标记"
  run_cli "$T" init
  assert_eq "重复 init exit 0（不覆盖）" 0 "$R_RC"
  assert_contains "重复 init 提示已存在" "$R_OUT" "已存在"
  grep -q '^level: 0' "$T/.meta/meta.yaml" && ok "重复 init 未改 level" || bad "重复 init 改了 level"
}

s03_status() {
  echo "--- 场景3：status 完整（exit 0）"
  local T; T=$(new_case)
  run_cli "$T" init
  run_cli "$T" status
  assert_eq "新 init 后 status exit 0" 0 "$R_RC"
  assert_contains "骨架完整" "$R_OUT" "骨架完整"
  assert_contains "级自洽验证通过" "$R_OUT" "级自洽验证：通过"
}

s04_bootstrap_projection() {
  echo "--- 场景4：TODO 模板 → bootstrap 引导投影；填槽后自动替换为常载命约"
  local T; T=$(new_case)
  run_cli "$T" init
  [ -f "$T/AGENTS.md" ] && [ -f "$T/CLAUDE.md" ] && ok "模板态生成 bootstrap 投影" || bad "模板态未生成 bootstrap 投影"
  assert_contains "含初始引导标记" "$(cat "$T/AGENTS.md")" "初始引导"
  assert_contains "引导含填槽步骤" "$(cat "$T/AGENTS.md")" "填宪法槽位"
  assert_contains "引导指向 write-adr 技能" "$(cat "$T/AGENTS.md")" "write-adr"
  write_constitution_filled "$T"
  run_cli "$T" sync
  assert_eq "填槽后 sync exit 0" 0 "$R_RC"
  assert_not_contains "引导已被替换" "$(cat "$T/AGENTS.md")" "初始引导"
  assert_contains "替换为常载命约" "$(cat "$T/AGENTS.md")" "常载命约"
}

s05_sync_idempotent() {
  echo "--- 场景5：填槽后 sync 投影 + 幂等"
  local T h1 h2; T=$(new_case)
  run_cli "$T" init
  write_constitution_filled "$T"
  run_cli "$T" sync
  assert_eq "sync exit 0" 0 "$R_RC"
  [ -f "$T/AGENTS.md" ] && [ -f "$T/CLAUDE.md" ] && ok "投影生成" || bad "投影未生成"
  grep -q 'BEGIN constitution' "$T/AGENTS.md" && ok "标记区存在" || bad "缺标记区"
  h1=$(md5sum "$T/AGENTS.md" | awk '{print $1}')
  run_cli "$T" sync
  h2=$(md5sum "$T/AGENTS.md" | awk '{print $1}')
  assert_eq "sync 幂等（二次投影内容不变）" "$h1" "$h2"
}

s06_ai_surface_off() {
  echo "--- 场景6：ai-surface off 跳投影（含 Off 大小写，F8）"
  # 注意次序：init 会投影（模板态投 bootstrap），故先清掉投影文件再置 off 验 sync 拦截
  local T T2; T=$(new_case); T2=$(new_case)
  run_cli "$T" init; write_constitution_filled "$T"
  rm -f "$T/AGENTS.md" "$T/CLAUDE.md"
  printf 'ai-surface: off\n' >> "$T/.meta/meta.yaml"
  run_cli "$T" sync
  assert_eq "ai-surface: off → sync exit 0" 0 "$R_RC"
  [ ! -f "$T/AGENTS.md" ] && [ ! -f "$T/CLAUDE.md" ] && ok "off 不投影" || bad "off 仍投影"
  assert_contains "提示 off 跳投影" "$R_OUT" "ai-surface: off"
  run_cli "$T2" init; write_constitution_filled "$T2"
  rm -f "$T2/AGENTS.md" "$T2/CLAUDE.md"
  printf 'ai-surface: Off\n' >> "$T2/.meta/meta.yaml"
  run_cli "$T2" sync
  assert_eq "ai-surface: Off → sync exit 0" 0 "$R_RC"
  [ ! -f "$T2/AGENTS.md" ] && [ ! -f "$T2/CLAUDE.md" ] && ok "Off（大小写不敏感）不投影" || bad "Off 仍投影（F8 未修）"
}

s07_retire() {
  echo "--- 场景7：retire off / N / 非法值 / 无 meta（用法不死）"
  local E T; E=$(new_case); T=$(new_case)
  run_cli "$E" retire
  assert_eq "无 meta 无参 → 用法 exit 0" 0 "$R_RC"
  assert_contains "打印用法" "$R_OUT" "用法"
  run_cli "$E" retire --level off
  assert_eq "无 meta 带 --level → die exit 1" 1 "$R_RC"
  run_cli "$T" init
  printf 'level: 3\n' > "$T/.meta/meta.yaml"
  run_cli "$T" retire --level 1
  assert_eq "retire --level 1 exit 0" 0 "$R_RC"
  grep -q '^level: 1' "$T/.meta/meta.yaml" && ok "level 降到 1" || bad "level 未降级"
  run_cli "$T" retire --level off
  assert_eq "retire --level off exit 0" 0 "$R_RC"
  grep -q '^level: 0' "$T/.meta/meta.yaml" && ok "off 归 level 0" || bad "off 未归 0"
  grep -q '^ai-surface: off' "$T/.meta/meta.yaml" && ok "off 置 ai-surface" || bad "off 未置 ai-surface"
  run_cli "$T" retire --level 9
  assert_eq "非法值 die exit 1" 1 "$R_RC"
  assert_contains "非法值报错" "$R_OUT" "目标非法"
}

s08_level_normalize() {
  echo "--- 场景8：level L 前缀归一 + level: 12 拒绝"
  local T; T=$(new_case)
  run_cli "$T" init
  printf 'level: L0\n' > "$T/.meta/meta.yaml"
  run_cli "$T" status
  assert_eq "level: L0 归一后 status exit 0" 0 "$R_RC"
  assert_contains "显示 L0" "$R_OUT" "纯 L0 长驻"
  printf 'level: 12\n' > "$T/.meta/meta.yaml"
  run_cli "$T" status
  assert_eq "level: 12 → exit 1" 1 "$R_RC"
  assert_contains "报 0.4" "$R_OUT" "0.4"
}

s09_audit_counts() {
  echo "--- 场景9：audit 确定性命中（非 git temp + GIT_CONFIG 消毒，spec rev3 P0-2）"
  local G T; G=$(mktemp "$SBASE/gitconf.XXXXXX"); : > "$G"
  T=$(new_case)
  run_cli "$T" init
  run_cli "$T" init
  G=$(sanitize_git)
  # shellcheck disable=SC2046
  run_cli_env "$T" $G audit --level S
  assert_eq "S 档 exit 0" 0 "$R_RC"
  assert_contains "S 档命中 5 / 10（含预置 write-adr）" "$R_OUT" "命中 5 / 10"
  # shellcheck disable=SC2046
  run_cli_env "$T" $G audit --level M
  assert_contains "M 档命中 5 / 14（含预置 write-adr）" "$R_OUT" "命中 5 / 14"
}

s10_audit_level_arg() {
  echo "--- 场景10：audit --level 缺值 / 非法值"
  local T; T=$(new_case)
  run_cli "$T" init
  run_cli "$T" audit --level
  assert_eq "--level 缺值 die exit 1" 1 "$R_RC"
  assert_contains "--level 缺值报错" "$R_OUT" "--level 需要取值"
  run_cli "$T" audit --level X
  assert_eq "--level 非法 die exit 1" 1 "$R_RC"
  assert_contains "非法档报错" "$R_OUT" "仅支持 S|M"
}

s11_l1_criteria() {
  echo "--- 场景11：L1 判据（合法/缺 class 轴/坏文件名/Status 不符/archived/非法日期/depth-4/空格文件名/CRLF）"
  local T
  T=$(new_case); run_cli "$T" init
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/2026-01-02-add-widget.md"
  run_cli "$T" status
  assert_eq "合法决策 → exit 0" 0 "$R_RC"
  assert_contains "L0-L1 通过" "$R_OUT" "L0-L1"

  T=$(new_case); run_cli "$T" init
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/2026-01-02-bare.md"
  run_cli "$T" status
  assert_eq "缺 class 轴 → exit 1" 1 "$R_RC"
  assert_contains "报 1.5" "$R_OUT" "1.5"

  T=$(new_case); run_cli "$T" init
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/badname.md"
  run_cli "$T" status
  assert_eq "坏文件名 → exit 1" 1 "$R_RC"
  assert_contains "报 1.6" "$R_OUT" "1.6"

  T=$(new_case); run_cli "$T" init
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/2026-01-02-x.md"
  sed -i 's/^Status: implemented/Status: proposed/' "$T/.agents/notes/implemented/feature/2026-01-02-x.md"
  run_cli "$T" status
  assert_eq "Status 不符 → exit 1" 1 "$R_RC"
  assert_contains "报 1.7" "$R_OUT" "1.7"

  T=$(new_case); run_cli "$T" init
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "archived/testing/2026-01-02-old.md"
  run_cli "$T" status
  assert_eq "archived 下 Status: implemented 豁免 → exit 0" 0 "$R_RC"

  T=$(new_case); run_cli "$T" init
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "archived/testing/2026-01-02-old.md"
  sed -i 's/^Status: implemented/Status: rejected/' "$T/.agents/notes/archived/testing/2026-01-02-old.md"
  run_cli "$T" status
  assert_eq "archived 下 Status: rejected → exit 1" 1 "$R_RC"
  assert_contains "报 1.7（archived 违例）" "$R_OUT" "1.7"

  T=$(new_case); run_cli "$T" init
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/2026-02-30-topic.md"
  run_cli "$T" status
  assert_eq "非法日期 2026-02-30 → exit 1" 1 "$R_RC"
  assert_contains "日期不合法被判" "$R_OUT" "日期不合法"

  T=$(new_case); run_cli "$T" init
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/2026-01-02-x.md"
  mkdir -p "$T/.agents/notes/implemented/feature/extra"
  cp "$T/.agents/notes/implemented/feature/2026-01-02-x.md" "$T/.agents/notes/implemented/feature/extra/2026-01-02-deep.md"
  run_cli "$T" status
  assert_eq "depth-4 违例 → exit 1" 1 "$R_RC"
  assert_contains "报 1.5（depth-4）" "$R_OUT" "1.5"

  T=$(new_case); run_cli "$T" init
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/2026-01-02-my topic.md"
  run_cli "$T" status
  assert_eq "含空格文件名（合法）→ exit 0" 0 "$R_RC"

  T=$(new_case); run_cli "$T" init
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/2026-01-02-crlf.md"
  sed -i 's/$/\r/' "$T/.agents/notes/implemented/feature/2026-01-02-crlf.md"
  run_cli "$T" status
  assert_eq "CRLF 决策文件不假 FAIL（1.7）→ exit 0" 0 "$R_RC"

  # 1.8 正文骨架与 lifecycle 匹配（ponyllm 实证漂移回归）
  T=$(new_case); run_cli "$T" init
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/2026-01-02-x.md"
  write_proposal_decision "$T" "proposed/architecture/2026-01-02-y.md"
  run_cli "$T" status
  assert_eq "1.8 合法（Decision+Proposal 各归其位）→ exit 0" 0 "$R_RC"

  T=$(new_case); run_cli "$T" init
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "proposed/architecture/2026-01-02-y.md"
  run_cli "$T" status
  assert_eq "1.8 proposed 误用 ## Decision → exit 1" 1 "$R_RC"
  assert_contains "报 1.8" "$R_OUT" "1.8"

  T=$(new_case); run_cli "$T" init
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_proposal_decision "$T" "implemented/feature/2026-01-02-x.md"
  run_cli "$T" status
  assert_eq "1.8 implemented 含提案时代标题 → exit 1" 1 "$R_RC"
  assert_contains "报 1.8" "$R_OUT" "1.8"

  # 1.9 文档有家（v2.0）：删掉 docs/AGENTS.md → FAIL；根 AGENTS.md 断链 → FAIL
  T=$(new_case); run_cli "$T" init
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/2026-01-02-x.md"
  rm -f "$T/docs/AGENTS.md"
  run_cli "$T" status
  assert_eq "缺 docs/AGENTS.md → exit 1" 1 "$R_RC"
  assert_contains "报 1.9" "$R_OUT" "1.9"

  T=$(new_case); run_cli "$T" init
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/2026-01-02-x.md"
  sed -i 's/docs\/AGENTS\.md//g' "$T/AGENTS.md"
  run_cli "$T" status
  assert_eq "根 AGENTS.md 断链（无 docs/AGENTS.md 引用）→ exit 1" 1 "$R_RC"
  assert_contains "报 1.9" "$R_OUT" "1.9"

  # 1.9c 包文档缺失：packages/ 下子目录无 AGENTS.md/README.md → FAIL；豁免清单可免
  T=$(new_case); run_cli "$T" init
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/2026-01-02-x.md"
  mkdir -p "$T/packages/mod-a" "$T/packages/mod-b"
  run_cli "$T" status
  assert_eq "包文档缺失 → exit 1" 1 "$R_RC"
  assert_contains "报 1.9" "$R_OUT" "1.9"

  T=$(new_case); run_cli "$T" init
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/2026-01-02-x.md"
  mkdir -p "$T/packages/mod-a" "$T/packages/mod-b"
  printf '# mod-a\n' > "$T/packages/mod-a/README.md"
  printf '# mod-b\n' > "$T/packages/mod-b/AGENTS.md"
  run_cli "$T" status
  assert_eq "包文档齐全 → exit 0" 0 "$R_RC"
}

s12_l2_criteria() {
  echo "--- 场景12：L2 判据（齐 → 过；缺钩子 → FAIL；2.5 条件判据四分支）"
  local T
  T=$(new_case); run_cli "$T" init
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/2026-01-02-gate.md"
  printf 'level: 2\n' > "$T/.meta/meta.yaml"
  ( cd "$T" && git init -q && git config core.hooksPath .githooks \
      && mkdir -p .githooks && printf '#!/usr/bin/env bash\necho hook\n' > .githooks/pre-commit ) >/dev/null 2>&1
  # 契约演进（freeze §3/§6.6）：2.4 判据加强后，正例夹具须含哨兵块 + 非注释调用行
  # + 执行位 + <root>/.meta/gates/adr-verify.sh；断言一条未删、未弱化。
  wire_gate_fixture "$T"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$T/.meta/gates/format.sh"
  printf 'purpose: negative sample spec\n' > "$T/.meta/gates/format.spec.md"
  # 分支：未声明 docs-tier + 已激活 → PASS（实际做到优先于声明）
  printf '## 已激活文档家清单\n' >> "$T/.meta/docs-tier/README.md"
  run_cli "$T" status
  assert_eq "未声明+文档分层已激活（PASS）→ exit 0" 0 "$R_RC"
  assert_contains "L0-L2 通过" "$R_OUT" "L0-L2"
  assert_contains "2.2 标注代理判据" "$R_OUT" "代理判据"
  assert_not_contains "已激活不触发 2.5 告警" "$R_OUT" "WARN docs-tier"

  T=$(new_case); run_cli "$T" init
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/2026-01-02-gate.md"
  printf 'level: 2\n' > "$T/.meta/meta.yaml"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$T/.meta/gates/format.sh"
  printf 'x\n' > "$T/.meta/gates/format.spec.md"
  # 消毒：非 git 目录下全局 core.hooksPath 与本项目无关，不得假 PASS（reviewer-b P1-1）
  # shellcheck disable=SC2046
  run_cli_env "$T" $(sanitize_git) status
  assert_eq "缺钩子（非 git 目录 + 消毒）→ exit 1" 1 "$R_RC"
  assert_contains "报 2.4" "$R_OUT" "2.4"

  # 分支：未声明 docs-tier + 模板态（未激活）→ SKIP + WARN 催声明，exit 0（2.5 不计入 PASS）
  T=$(new_case); run_cli "$T" init
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/2026-01-02-gate.md"
  printf 'level: 2\n' > "$T/.meta/meta.yaml"
  ( cd "$T" && git init -q && git config core.hooksPath .githooks \
      && mkdir -p .githooks && printf '#!/usr/bin/env bash\necho hook\n' > .githooks/pre-commit ) >/dev/null 2>&1
  # 契约演进（freeze §3/§6.6）：2.4 判据加强后，正例夹具须含哨兵块 + 非注释调用行
  # + 执行位 + <root>/.meta/gates/adr-verify.sh；断言一条未删、未弱化。
  wire_gate_fixture "$T"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$T/.meta/gates/format.sh"
  printf 'x\n' > "$T/.meta/gates/format.spec.md"
  run_cli "$T" status
  assert_eq "未声明+模板态（SKIP）→ exit 0" 0 "$R_RC"
  assert_contains "催声明 WARN" "$R_OUT" "未声明 docs-tier"
  assert_contains "结论行标 SKIPPED" "$R_OUT" "2.5 SKIPPED"

  # 分支：docs-tier: off + 模板态 → 显式 opt-out，结论行禁写"全部 PASS"，改写为"2.1–2.4 PASS；2.5 未启用"
  T=$(new_case); run_cli "$T" init
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/2026-01-02-gate.md"
  printf 'level: 2\n' > "$T/.meta/meta.yaml"
  printf 'docs-tier: off\n' >> "$T/.meta/meta.yaml"
  ( cd "$T" && git init -q && git config core.hooksPath .githooks \
      && mkdir -p .githooks && printf '#!/usr/bin/env bash\necho hook\n' > .githooks/pre-commit ) >/dev/null 2>&1
  # 契约演进（freeze §3/§6.6）：2.4 判据加强后，正例夹具须含哨兵块 + 非注释调用行
  # + 执行位 + <root>/.meta/gates/adr-verify.sh；断言一条未删、未弱化。
  wire_gate_fixture "$T"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$T/.meta/gates/format.sh"
  printf 'x\n' > "$T/.meta/gates/format.spec.md"
  run_cli "$T" status
  assert_eq "docs-tier: off → exit 0" 0 "$R_RC"
  assert_contains "off 改写结论行" "$R_OUT" "2.1–2.4 PASS；2.5 未启用"
  assert_not_contains "off 禁写全部 PASS" "$R_OUT" "全部 PASS"

  # 分支：docs-tier: on + 模板态（未激活）→ FAIL（声明即承诺，未激活即违约）
  T=$(new_case); run_cli "$T" init
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/2026-01-02-gate.md"
  printf 'level: 2\n' > "$T/.meta/meta.yaml"
  printf 'docs-tier: on\n' >> "$T/.meta/meta.yaml"
  ( cd "$T" && git init -q && git config core.hooksPath .githooks \
      && mkdir -p .githooks && printf '#!/usr/bin/env bash\necho hook\n' > .githooks/pre-commit ) >/dev/null 2>&1
  # 契约演进（freeze §3/§6.6）：2.4 判据加强后，正例夹具须含哨兵块 + 非注释调用行
  # + 执行位 + <root>/.meta/gates/adr-verify.sh；断言一条未删、未弱化。
  wire_gate_fixture "$T"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$T/.meta/gates/format.sh"
  printf 'x\n' > "$T/.meta/gates/format.spec.md"
  # 模板态 docs-tier/README.md 未激活（无已激活锚点）
  run_cli "$T" status
  assert_eq "docs-tier: on + 模板态 → exit 1" 1 "$R_RC"
  assert_contains "报 2.5" "$R_OUT" "2.5"
  assert_contains "报模板态未激活" "$R_OUT" "未激活"

  # 分支：docs-tier: on + 已激活但 TODO 残留 → FAIL（声明空心）
  printf '## 已激活文档家清单\n' >> "$T/.meta/docs-tier/README.md"
  run_cli "$T" status
  assert_eq "docs-tier: on + TODO 残留 → exit 1" 1 "$R_RC"
  assert_contains "报 2.5（TODO 残留）" "$R_OUT" "2.5"
  assert_contains "报 TODO 残留" "$R_OUT" "TODO"

  # 分支：docs-tier: off + 已激活 → 矛盾 WARN + off 结论行（exit 0）
  # P3-3 单变量：全新目录 + 重写 docs-tier/README（无 TODO 残留），只留"off 声明 vs 已激活事实"一个变量
  T=$(new_case); run_cli "$T" init
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/2026-01-02-gate.md"
  printf 'level: 2\ndocs-tier: off\n' > "$T/.meta/meta.yaml"
  ( cd "$T" && git init -q && git config core.hooksPath .githooks \
      && mkdir -p .githooks && printf '#!/usr/bin/env bash\necho hook\n' > .githooks/pre-commit ) >/dev/null 2>&1
  # 契约演进（freeze §3/§6.6）：2.4 判据加强后，正例夹具须含哨兵块 + 非注释调用行
  # + 执行位 + <root>/.meta/gates/adr-verify.sh；断言一条未删、未弱化。
  wire_gate_fixture "$T"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$T/.meta/gates/format.sh"
  printf 'x\n' > "$T/.meta/gates/format.spec.md"
  printf '## 已激活文档家清单\n\n| tier | 家 |\n|---|---|\n| 决策记录 | .agents/notes/ |\n' > "$T/.meta/docs-tier/README.md"
  run_cli "$T" status
  assert_eq "off + 已激活（矛盾 WARN）→ exit 0" 0 "$R_RC"
  assert_contains "off 矛盾 WARN" "$R_OUT" "矛盾"
  assert_contains "off 结论行" "$R_OUT" "2.1–2.4 PASS；2.5 未启用"
  assert_contains "off 提示录 decision" "$R_OUT" "建议录一条 decision"

  # 分支：docs-tier: on + 已激活 + 无 TODO → PASS（声明且做到）
  T=$(new_case); run_cli "$T" init
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/2026-01-02-gate.md"
  printf 'level: 2\n' > "$T/.meta/meta.yaml"
  printf 'docs-tier: on\n' >> "$T/.meta/meta.yaml"
  ( cd "$T" && git init -q && git config core.hooksPath .githooks \
      && mkdir -p .githooks && printf '#!/usr/bin/env bash\necho hook\n' > .githooks/pre-commit ) >/dev/null 2>&1
  # 契约演进（freeze §3/§6.6）：2.4 判据加强后，正例夹具须含哨兵块 + 非注释调用行
  # + 执行位 + <root>/.meta/gates/adr-verify.sh；断言一条未删、未弱化。
  wire_gate_fixture "$T"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$T/.meta/gates/format.sh"
  printf 'x\n' > "$T/.meta/gates/format.spec.md"
  # 清零模板态 TODO：重写为已激活清单（无 TODO 残留）
  printf '## 已激活文档家清单\n\n| tier | 家 |\n|---|---|\n| 决策记录 | .agents/notes/ |\n' > "$T/.meta/docs-tier/README.md"
  run_cli "$T" status
  assert_eq "docs-tier: on + 已激活 + 无 TODO → exit 0" 0 "$R_RC"
  assert_contains "on 全过结论行" "$R_OUT" "L0-L2"

  # 分支（P1-1 回归）：引号值（docs-tier: "off"）不得激活状态机——走非法键 WARN + 未声明 SKIP，不兑现 off
  T=$(new_case); run_cli "$T" init
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/2026-01-02-gate.md"
  printf 'level: 2\n' > "$T/.meta/meta.yaml"
  printf 'docs-tier: "off"\n' >> "$T/.meta/meta.yaml"
  ( cd "$T" && git init -q && git config core.hooksPath .githooks \
      && mkdir -p .githooks && printf '#!/usr/bin/env bash\necho hook\n' > .githooks/pre-commit ) >/dev/null 2>&1
  # 契约演进（freeze §3/§6.6）：2.4 判据加强后，正例夹具须含哨兵块 + 非注释调用行
  # + 执行位 + <root>/.meta/gates/adr-verify.sh；断言一条未删、未弱化。
  wire_gate_fixture "$T"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$T/.meta/gates/format.sh"
  printf 'x\n' > "$T/.meta/gates/format.spec.md"
  run_cli "$T" status
  assert_eq "引号值不兑现 off → exit 0（未声明 SKIP）" 0 "$R_RC"
  assert_contains "引号值报非法键 WARN" "$R_OUT" "非法键"
  assert_not_contains "引号值不进入 off 分支（不写 off 结论）" "$R_OUT" "2.5 未启用"
}

s13_meta_violations() {
  echo "--- 场景13：meta.yaml 违例键告警（双挂 WARN，exit 0）+ CRLF 不假 WARN"
  local T
  T=$(new_case); run_cli "$T" init
  printf 'foo: bar\n' >> "$T/.meta/meta.yaml"
  run_cli "$T" status
  assert_eq "status 违例键仍 exit 0" 0 "$R_RC"
  assert_contains "status WARN" "$R_OUT" "WARN"
  assert_contains "status WARN 指出键" "$R_OUT" "foo: bar"
  run_cli "$T" audit --level S
  assert_eq "audit 违例键仍 exit 0" 0 "$R_RC"
  assert_contains "audit WARN（双挂）" "$R_OUT" "WARN"

  T=$(new_case); run_cli "$T" init
  printf '  level: 2\n' >> "$T/.meta/meta.yaml"
  run_cli "$T" status
  assert_contains "缩进 level: 行告警" "$R_OUT" "WARN"

  # 注意：非 git 场景会触发卫生 WARN（s22），本例在 git 仓库内隔离出 meta 键 WARN 单变量
  T=$(new_case); run_cli "$T" init
  ( cd "$T" && git init -q ) >/dev/null 2>&1
  printf '# comment\r\n\r\nlevel: 0\r\n' > "$T/.meta/meta.yaml"
  run_cli "$T" status
  assert_not_contains "CRLF meta.yaml 不假 WARN" "$R_OUT" "WARN"
  assert_eq "CRLF meta.yaml status exit 0" 0 "$R_RC"

  # docs-tier: on|off 是合法键（L 包原子补丁）：顶格声明不告警，缩进才告警
  T=$(new_case); run_cli "$T" init
  printf 'level: 0\ndocs-tier: off\n' > "$T/.meta/meta.yaml"
  run_cli "$T" status
  assert_eq "docs-tier: off 为合法键 → exit 0" 0 "$R_RC"
  assert_not_contains "docs-tier: off 不告警" "$R_OUT" "非法键"
  T=$(new_case); run_cli "$T" init
  printf 'level: 0\n  docs-tier: on\n' > "$T/.meta/meta.yaml"
  run_cli "$T" status
  assert_contains "缩进 docs-tier 行告警" "$R_OUT" "WARN"
  # docs-tier 非法值（yes/大写 ON）走违例键 WARN（新键从严，不继承 ai-surface 的 Off 大小写先例）
  T=$(new_case); run_cli "$T" init
  printf 'level: 0\ndocs-tier: ON\n' > "$T/.meta/meta.yaml"
  run_cli "$T" status
  assert_contains "docs-tier 非法值告警" "$R_OUT" "非法键"
}

# wave-7：模板仓自身可切到「已激活」态（docs-tier 激活）。`ponygo init` 的生成物**恒为模板态**，
# 故「生成物 == 仓库文件」只在仓库处于模板态时成立；已激活时按 `ponygo upgrade --check` 的
# `dt_skip` 同口径豁免该比对，改用更强的「生成物仍为模板态」断言（激活版不得被当模板发出去）。
# 锚定 h2 标题匹配，不用裸子串：模板态正文（激活指引那几行）里本就写着「已激活文档家清单」。
docs_tier_generated_is_template() { # <生成物路径>：模板态 ⇔ 无激活锚点标题 且 含模板态标记
  local f="$1"
  [ -f "$f" ] || return 1
  grep -qE '^##[[:space:]]+已激活文档家清单' "$f" && return 1
  grep -qF '模板态' "$f" || grep -qF '【TODO' "$f" || return 1
  return 0
}

s14_decisions_readme() {
  echo "--- 场景14：生成 decisions/ skills/ README 与模板 eol 归一逐字节一致（F3 + skills 契约）"
  local T MUT; T=$(new_case)
  run_cli "$T" init
  if diff <(tr -d '\r' < "$T/.agents/notes/README.md") \
          <(tr -d '\r' < "$ROOT/.agents/notes/README.md") >/dev/null 2>&1; then
    ok "生成 decisions/README 与模板 eol 归一后一致"
  else
    bad "生成 decisions/README 与模板不一致"
  fi
  if diff <(tr -d '\r' < "$T/.agents/skills/README.md") \
          <(tr -d '\r' < "$ROOT/.agents/skills/README.md") >/dev/null 2>&1; then
    ok "生成 skills/README 与模板 eol 归一后一致（含五要素契约）"
  else
    bad "生成 skills/README 与模板不一致"
  fi
  grep -q '五要素' "$T/.agents/skills/README.md" && ok "skills 契约含五要素" || bad "skills 契约缺五要素"
  # docs-tier/README.md：按本仓激活状态分支（wave-7）
  #  - 本仓模板态 → 原「逐字节一致」比对（不变）
  #  - 本仓已激活 → 生成物仍是模板态（比逐字节更强：直接证明激活版没被当成模板发出去）
  if grep -qE '^##[[:space:]]+已激活文档家清单' "$ROOT/.meta/docs-tier/README.md" 2>/dev/null; then
    ok "本仓 docs-tier 已激活 → 跳过「生成物 == 仓库文件」比对（upgrade --check 的 dt_skip 同口径豁免）"
    # 显式断言（只比对标题行集合，避免正文激活指引里的同名字样造成假红）
    assert_not_contains "生成 docs-tier/README 无「## 已激活文档家清单」标题（激活版未泄漏为模板）" \
      "$(grep -E '^#+ ' "$T/.meta/docs-tier/README.md" 2>/dev/null | tr '\n' '|')" "已激活文档家清单"
    assert_contains "生成 docs-tier/README 含模板态标记（【TODO】或「模板态」）" \
      "$(cat "$T/.meta/docs-tier/README.md" 2>/dev/null)" "模板态"
    # 正向控制：把生成物改成激活态 → 同一判定必须变红（证明它能抓「模板被污染」）
    MUT="$SBASE/docs-tier.activated.md"
    cp "$T/.meta/docs-tier/README.md" "$MUT" 2>/dev/null
    sed -i 's/^# .*/## 已激活文档家清单/' "$MUT"
    if docs_tier_generated_is_template "$MUT"; then
      bad "正向控制失效：生成物被改成激活态却仍判为模板态（断言抓不住污染）"
    else
      ok "正向控制：生成物改成激活态 → 判定变红（确能抓「模板被污染」）"
    fi
  else
    if diff <(tr -d '\r' < "$T/.meta/docs-tier/README.md") \
            <(tr -d '\r' < "$ROOT/.meta/docs-tier/README.md") >/dev/null 2>&1; then
      ok "生成 docs-tier/README 与模板 eol 归一后一致（含 tier 模板）"
    else
      bad "生成 docs-tier/README 与模板不一致"
    fi
  fi
  if diff <(tr -d '\r' < "$T/.agents/skills/write-adr/SKILL.md") \
          <(tr -d '\r' < "$ROOT/.agents/skills/write-adr/SKILL.md") >/dev/null 2>&1; then
    ok "生成 write-adr/SKILL.md 与模板 eol 归一后一致"
  else
    bad "生成 write-adr/SKILL.md 与模板不一致"
  fi
  if diff <(tr -d '\r' < "$T/.agents/skills/write-adr/verify-note.sh") \
          <(tr -d '\r' < "$ROOT/.agents/skills/write-adr/verify-note.sh") >/dev/null 2>&1; then
    ok "生成 write-adr/verify-note.sh 与模板 eol 归一后一致"
  else
    bad "生成 write-adr/verify-note.sh 与模板不一致"
  fi
  if diff <(tr -d '\r' < "$T/.agents/skills/governance-review/SKILL.md") \
          <(tr -d '\r' < "$ROOT/.agents/skills/governance-review/SKILL.md") >/dev/null 2>&1; then
    ok "生成 governance-review/SKILL.md 与模板 eol 归一后一致"
  else
    bad "生成 governance-review/SKILL.md 与模板不一致"
  fi
  if diff <(tr -d '\r' < "$T/.meta/gates/README.md") \
          <(tr -d '\r' < "$ROOT/.meta/gates/README.md") >/dev/null 2>&1; then
    ok "生成 gates/README 与模板 eol 归一后一致（含 P7 时间经济三层）"
  else
    bad "生成 gates/README 与模板不一致"
  fi
  grep -q 'pre-commit' "$T/.meta/gates/README.md" && ok "gates 模板含 P7 分层" || bad "gates 模板缺 P7 分层"
  if diff <(tr -d '\r' < "$T/.agents/skills/change-review/SKILL.md") \
          <(tr -d '\r' < "$ROOT/.agents/skills/change-review/SKILL.md") >/dev/null 2>&1; then
    ok "生成 change-review/SKILL.md 与模板 eol 归一后一致"
  else
    bad "生成 change-review/SKILL.md 与模板不一致"
  fi
  if diff <(tr -d '\r' < "$T/.agents/notes/AGENTS.md") \
          <(tr -d '\r' < "$ROOT/.agents/notes/AGENTS.md") >/dev/null 2>&1; then
    ok "生成 notes/AGENTS.md 与模板 eol 归一后一致"
  else
    bad "生成 notes/AGENTS.md 与模板不一致"
  fi
  if diff <(tr -d '\r' < "$T/.agents/notes/archived/AGENTS.md") \
          <(tr -d '\r' < "$ROOT/.agents/notes/archived/AGENTS.md") >/dev/null 2>&1; then
    ok "生成 archived/AGENTS.md 与模板 eol 归一后一致"
  else
    bad "生成 archived/AGENTS.md 与模板不一致"
  fi
}

s15_upgrade() {
  echo "--- 场景15：upgrade exit 0（默认契约：报告 exit 0；空项目温和跳过）"
  # 空项目（无 .meta、无代码迹象）→ upgrade 温和跳过 exit 0（含升级纪律输出行）
  run_cli "$(new_case)" upgrade
  assert_eq "空项目 upgrade exit 0" 0 "$R_RC"
  assert_contains "含升级纪律" "$R_OUT" "升级纪律"
  # 健康实例（init 后未动宇宙文件）→ exit 0 且含漂移报告头（双断言同属 s15）
  local T; T=$(new_case)
  run_cli "$T" init
  run_cli "$T" upgrade
  assert_eq "健康实例 upgrade exit 0" 0 "$R_RC"
  assert_contains "含漂移报告头" "$R_OUT" "漂移报告"
  assert_contains "零漂移" "$R_OUT" "零漂移"
}

s16_status_no_meta() {
  echo "--- 场景16：status 无 .meta（exit 1 不崩）"
  run_cli "$(new_case)" status
  assert_eq "无 .meta status exit 1" 1 "$R_RC"
  assert_not_contains "不崩（无 unbound 报错）" "$R_OUT" "unbound variable"
}

s17_dry_run() {
  echo "--- 场景17：--dry-run 零落盘（init / retire）"
  local T; T=$(new_case)
  run_cli "$T" init --dry-run
  assert_eq "init --dry-run exit 0" 0 "$R_RC"
  [ ! -e "$T/.meta" ] && ok "init --dry-run 零落盘" || bad "init --dry-run 落盘了"
  T=$(new_case)
  run_cli "$T" init
  printf 'level: 2\n' > "$T/.meta/meta.yaml"
  run_cli "$T" retire --level 1 --dry-run
  assert_eq "retire --dry-run exit 0" 0 "$R_RC"
  grep -q '^level: 2' "$T/.meta/meta.yaml" && ok "retire --dry-run 未改 level" || bad "retire --dry-run 改了 level"
}

s18_repo_consistency() {
  echo "--- 场景18：F1 口径 grep（checklist.md 骨架8/机制18/精微8）+ .gitattributes"
  if grep -Eq '骨架[[:space:]]*8|8[[:space:]]*项' "$ROOT/audit/checklist.md" 2>/dev/null; then
    ok "checklist.md 含骨架层数 8"
  else
    bad "checklist.md 缺骨架层数 8 口径"
  fi
  if grep -Eq '机制[[:space:]]*18|18[[:space:]]*项' "$ROOT/audit/checklist.md" 2>/dev/null; then
    ok "checklist.md 含机制层数 18"
  else
    bad "checklist.md 缺机制层数 18 口径"
  fi
  if grep -Eq '精微[[:space:]]*8|精微层.{0,10}8[[:space:]]*项' "$ROOT/audit/checklist.md" 2>/dev/null; then
    ok "checklist.md 含精微层数 8"
  else
    bad "checklist.md 缺精微层数 8 口径"
  fi
  if [ -f "$ROOT/.gitattributes" ] && grep -q 'eol=lf' "$ROOT/.gitattributes"; then
    ok ".gitattributes 含 eol=lf"
  else
    bad ".gitattributes 缺失或无 eol=lf"
  fi
}

s19_boundary_regress() {
  echo "--- 场景19：双审补盲（封闭集执法、缺 Status 行、sync 三分支）"
  local T
  # 1.3 lifecycle 顶层杂项目录
  T=$(new_case); run_cli "$T" init
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/2026-01-02-a.md"
  mkdir -p "$T/.agents/notes/random-stuff"
  run_cli "$T" status
  assert_eq "1.3 杂项目录 → exit 1" 1 "$R_RC"
  assert_contains "报 1.3" "$R_OUT" "1.3"
  # 1.4 class 越界
  T=$(new_case); run_cli "$T" init
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/not-a-class/2026-01-02-b.md"
  run_cli "$T" status
  assert_eq "1.4 class 越界 → exit 1" 1 "$R_RC"
  assert_contains "报 1.4" "$R_OUT" "1.4"
  # 1.7 缺 Status: 行
  T=$(new_case); run_cli "$T" init
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/2026-01-02-c.md"
  sed -i '/^Status:/d' "$T/.agents/notes/implemented/feature/2026-01-02-c.md"
  run_cli "$T" status
  assert_eq "缺 Status 行 → exit 1" 1 "$R_RC"
  assert_contains "报 1.7" "$R_OUT" "1.7"
  # sync：既有 AGENTS.md 带标记区 → 只替换块内、块外保留
  T=$(new_case); run_cli "$T" init; write_constitution_filled "$T"
  printf 'my notes head\n<!-- BEGIN constitution -->\nold body\n<!-- END constitution -->\nmy notes tail\n' > "$T/AGENTS.md"
  run_cli "$T" sync
  assert_eq "标记区替换 exit 0" 0 "$R_RC"
  grep -q 'my notes head' "$T/AGENTS.md" && ok "块外头保留" || bad "块外头丢失"
  grep -q 'my notes tail' "$T/AGENTS.md" && ok "块外尾保留" || bad "块外尾丢失"
  grep -q 'old body' "$T/AGENTS.md" && bad "旧投影体未替换" || ok "旧投影体已替换"
  [ -f "$T/AGENTS.md.tmp" ] && bad "残留 .tmp" || ok "无 .tmp 残留"
  # sync：既有 AGENTS.md 无标记区 → 追加、原文保留
  T=$(new_case); run_cli "$T" init; write_constitution_filled "$T"
  printf 'handwritten rules\n' > "$T/AGENTS.md"
  run_cli "$T" sync
  assert_eq "无标记区追加 exit 0" 0 "$R_RC"
  grep -q 'handwritten rules' "$T/AGENTS.md" && ok "原文保留" || bad "原文丢失"
  grep -q 'BEGIN constitution' "$T/AGENTS.md" && ok "块已追加" || bad "块未追加"
}

s20_installer() {
  echo "--- 场景20：install.sh 一键安装与环境探测"
  local T target_bin out rc=0
  T=$(new_case)
  target_bin="$T/bin"

  # 1. 本地源码安装测试
  out=$(bash "$ROOT/install.sh" "$target_bin" 2>&1) || rc=$?
  assert_eq "install.sh 本地安装 exit 0" 0 "$rc"
  [ -x "$target_bin/ponygo" ] && ok "生成可执行文件 target/ponygo" || bad "未生成 target/ponygo"
  echo "$out" | grep -q "已成功安装到" && ok "输出成功信息" || bad "未输出成功信息"

  # 2. 自检能否运行
  local help_out
  help_out=$("$target_bin/ponygo" --help 2>&1)
  echo "$help_out" | grep -q "ponygo" && ok "已安装 ponygo 可正常执行 --help" || bad "安装后无法执行"

  # 3. 完整性校验（P0-3）：SHA256 正确通过 / 错误拒绝并删文件
  if command -v sha256sum >/dev/null 2>&1; then
    local good
    good=$(sha256sum "$target_bin/ponygo" | awk '{print $1}')
    if PONYGO_SHA256="$good" bash "$ROOT/install.sh" "$target_bin" >/dev/null 2>&1; then
      ok "SHA256 正确 → 安装成功"
    else
      bad "SHA256 正确却被拒"
    fi
    if PONYGO_SHA256="deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef" \
         bash "$ROOT/install.sh" "$target_bin" >/dev/null 2>&1; then
      bad "SHA256 错误未被拒"
    else
      ok "SHA256 错误 → 拒绝安装"
    fi
    [ ! -f "$target_bin/ponygo" ] && ok "校验失败后可疑文件已删除" || bad "校验失败后文件残留"
  else
    ok "无 sha256sum，跳过校验和场景（CI 双平台均有）"
  fi
}

# ============================================================
s01_help
s02_init
s03_status
s04_bootstrap_projection
s05_sync_idempotent
s06_ai_surface_off
s07_retire
s08_level_normalize
s09_audit_counts
s10_audit_level_arg
s11_l1_criteria
s12_l2_criteria
s13_meta_violations
s14_decisions_readme
s15_upgrade
s16_status_no_meta
s17_dry_run
s18_repo_consistency
s19_boundary_regress
s21_external001_regress() {
  echo "--- 场景21：EXTERNAL-001 回归（空 level 0.4 / classes.local / sync 锚点 / audit 内嵌验级 / 深度信号4）"
  local T G
  # P1-4：空 level 不假 L0 PASS
  T=$(new_case); run_cli "$T" init
  printf 'level: \n' > "$T/.meta/meta.yaml"
  run_cli "$T" status
  assert_eq "空 level → exit 1" 1 "$R_RC"
  assert_contains "报 0.4" "$R_OUT" "0.4"
  # P2-1：classes.local 扩展 class
  T=$(new_case); run_cli "$T" init
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/domain-x/2026-01-02-ext.md"
  run_cli "$T" status
  assert_eq "未登记的扩展 class → exit 1" 1 "$R_RC"
  assert_contains "报 1.4" "$R_OUT" "1.4"
  printf '# 领域扩展\ndomain-x\n' > "$T/.agents/notes/classes.local"
  run_cli "$T" status
  assert_eq "classes.local 登记后 → exit 0" 0 "$R_RC"
  # P1-3：sync 锚点（英文标题 + <!-- sync-body -->）
  T=$(new_case); run_cli "$T" init
  cat > "$T/.meta/constitution/constitution.md" <<'EOF'
# Constitution

<!-- sync-body -->

## Standing Orders
1. Decisions must be recorded.
EOF
  run_cli "$T" sync
  assert_eq "sync 锚点（英文标题）exit 0" 0 "$R_RC"
  grep -q 'Standing Orders' "$T/AGENTS.md" && ok "英文投影体生成" || bad "英文投影体未生成"
  G=$(sanitize_git)
  # P1-1：audit 内嵌验级（声明 L1 无决策 → exit 1）
  T=$(new_case); run_cli "$T" init
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  # shellcheck disable=SC2046
  run_cli_env "$T" $G audit --level S
  assert_eq "audit 内嵌验级（L1 无决策）→ exit 1" 1 "$R_RC"
  assert_contains "audit 输出级自洽 FAIL" "$R_OUT" "级自洽验证：未通过"
  # P1-2：深度信号4 仅 .meta 不升 M 档
  T=$(new_case); run_cli "$T" init
  # shellcheck disable=SC2046
  run_cli_env "$T" $G audit
  assert_contains "仅 .meta 仍 S 档" "$R_OUT" "审计深度：S 档"
}

s22_hygiene_warn() {
  echo "--- 场景22：治理卫生 WARN（非 git / 游离计划 / 缺 .gitignore；exit 不变）"
  local T
  # 非 git 仓库 WARN + bootstrap 第 0 步与自证线
  T=$(new_case); run_cli "$T" init
  run_cli "$T" status
  assert_eq "非 git status 仍 exit 0" 0 "$R_RC"
  assert_contains "WARN 非 git 仓库" "$R_OUT" "不在 git 仓库"
  grep -q 'git init' "$T/AGENTS.md" && ok "bootstrap 含第 0 步 git init" || bad "bootstrap 缺 git init"
  grep -q '无 FAIL 且无 WARN' "$T/AGENTS.md" && ok "bootstrap 自证线含无 WARN" || bad "bootstrap 自证线未升级"
  # 游离计划文档 WARN（git 仓库内，与上一条 WARN 隔离）
  T=$(new_case); run_cli "$T" init
  ( cd "$T" && git init -q ) >/dev/null 2>&1
  printf '# plan\n' > "$T/IMPLEMENTATION_PLAN.md"
  run_cli "$T" status
  assert_eq "游离计划 status 仍 exit 0" 0 "$R_RC"
  assert_contains "WARN 游离计划文档" "$R_OUT" "游离计划文档"
  # git 仓库无 .gitignore WARN（init 已生成，删掉再测）
  T=$(new_case); run_cli "$T" init
  ( cd "$T" && git init -q ) >/dev/null 2>&1
  rm -f "$T/.gitignore"
  run_cli "$T" status
  assert_contains "WARN 缺 .gitignore" "$R_OUT" "无 .gitignore"
  # 干净场景无卫生 WARN
  T=$(new_case); run_cli "$T" init
  ( cd "$T" && git init -q ) >/dev/null 2>&1
  run_cli "$T" status
  assert_not_contains "干净场景无卫生 WARN" "$R_OUT" "WARN"
}

s23_verify_note() {
  echo "--- 场景23：write-adr/verify-note.sh 机械校验器正反例"
  local T; T=$(new_case)
  run_cli "$T" init
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/2026-01-02-x.md"
  write_proposal_decision "$T" "proposed/architecture/2026-01-02-y.md"
  ( cd "$T" && bash .agents/skills/write-adr/verify-note.sh >/dev/null 2>&1 )
  assert_eq "合规树 exit 0" 0 "$?"
  write_valid_decision "$T" "implemented/feature/badname.md"
  ( cd "$T" && bash .agents/skills/write-adr/verify-note.sh >/dev/null 2>&1 )
  assert_eq "坏文件名 exit 1" 1 "$?"
  write_proposal_decision "$T" "implemented/feature/2026-01-03-z.md"
  ( cd "$T" && bash .agents/skills/write-adr/verify-note.sh >/dev/null 2>&1 )
  assert_eq "implemented 含提案标题 exit 1" 1 "$?"
  ( cd "$T" && bash .agents/skills/write-adr/verify-note.sh .agents/notes/implemented/feature/2026-01-03-z.md >/dev/null 2>&1 )
  assert_eq "指定单文件也能抓违例 exit 1" 1 "$?"
}

s24_gate_layers() {
  echo "--- 场景24：门禁分层报告（P7 时间经济性：pre-commit/pre-push/CI）"
  local T G; G=$(sanitize_git)
  # 零门禁：audit 应报三层全无 + 缺层引导
  T=$(new_case); run_cli "$T" init
  # shellcheck disable=SC2046
  run_cli_env "$T" $G audit --level S
  assert_contains "audit 含门禁分层参考" "$R_OUT" "门禁分层参考"
  assert_contains "本地层 pre-commit 无" "$R_OUT" "本地层 pre-commit（秒级）：无"
  assert_contains "中继层 pre-push 无" "$R_OUT" "中继层 pre-push（10秒级）：无"
  assert_contains "远端层 CI 无" "$R_OUT" "远端层 CI（分钟级）：无"
  assert_contains "缺本地层引导" "$R_OUT" "缺本地层"
  # 三层齐备：audit 应报三层全有、无缺层引导
  T=$(new_case); run_cli "$T" init
  ( cd "$T" && mkdir -p .githooks .github/workflows \
      && printf '#!/usr/bin/env bash\necho fmt\n' > .githooks/pre-commit \
      && printf '#!/usr/bin/env bash\necho typecheck\n' > .githooks/pre-push \
      && printf 'name: ci\n' > .github/workflows/ci.yml \
      && git init -q && git config core.hooksPath .githooks ) >/dev/null 2>&1
  # 契约演进（freeze §6.6）：本地层 pre-commit 夹具补哨兵块 + 非注释调用行 + 执行位；
  # 「本地层 pre-commit（秒级）：有」的断言保持不变（新判据下仍须为「有」）。
  wire_gate_fixture "$T"
  chmod +x "$T/.githooks/pre-push"
  # shellcheck disable=SC2046
  run_cli_env "$T" $G audit --level S
  assert_contains "本地层 pre-commit 有" "$R_OUT" "本地层 pre-commit（秒级）：有"
  assert_contains "中继层 pre-push 有" "$R_OUT" "中继层 pre-push（10秒级）：有"
  assert_contains "远端层 CI 有" "$R_OUT" "远端层 CI（分钟级）：有"
  assert_not_contains "三层齐备无缺层引导" "$R_OUT" "缺本地层"
}

s25_doc_home_audit() {
  echo "--- 场景25：v2.0 文档有家——audit 对既有项目（旧项目接入）检测文档家缺失（0.5/1.9/2.5 双保证）"
  local T G; G=$(sanitize_git)
  # 旧项目接入：init 后声明 L1 但删掉 docs/AGENTS.md → audit exit 1 并报 0.5/1.9
  T=$(new_case); run_cli "$T" init
  ( cd "$T" && git init -q ) >/dev/null 2>&1
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/process/2026-01-02-adopt-governance.md"
  rm -f "$T/docs/AGENTS.md"
  # shellcheck disable=SC2046
  run_cli_env "$T" $G audit --level S
  assert_eq "audit 检测缺 docs/AGENTS.md → exit 1" 1 "$R_RC"
  assert_contains "audit 报 0.5" "$R_OUT" "0.5"
  assert_contains "audit 报 1.9" "$R_OUT" "1.9"

  # 文档家齐全（init 生成）→ audit exit 0
  T=$(new_case); run_cli "$T" init
  ( cd "$T" && git init -q ) >/dev/null 2>&1
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/process/2026-01-02-adopt-governance.md"
  # shellcheck disable=SC2046
  run_cli_env "$T" $G audit --level S
  assert_eq "文档家齐全 audit exit 0" 0 "$R_RC"
}

s26_warn_tier() {
  echo "--- 场景26：v2.1 提醒档——gates 模板 WARN 片段 + 卫生 WARN（新鲜度/未来日期，exit 不变）"
  local T G; G=$(sanitize_git)
  # gates/README 模板含 doc-freshness WARN 片段（排除 notes 计数）
  T=$(new_case); run_cli "$T" init
  grep -q 'doc-freshness WARN' "$T/.meta/gates/README.md" && ok "gates 模板含 WARN 片段" || bad "gates 模板缺 WARN 片段"
  grep -qF "grep -v '^\.agents/notes/'" "$T/.meta/gates/README.md" && ok "WARN 片段排除 notes 计数" || bad "WARN 片段未排除 notes"
  # 新鲜度 WARN：有提交历史，近 5 提交改代码而非-notes 文档零动 → WARN 但 exit 0
  # （init 提交自带 .md，需 6 提交把它挤出近 5 窗口，模拟已建项目）
  ( cd "$T" && git init -q && git add -A >/dev/null 2>&1 \
    && git -c user.email=t@t -c user.name=t commit -qm init \
    && for i in 1 2 3 4 5; do printf 'x\n' > "mod$i.py" && git add "mod$i.py" \
      && git -c user.email=t@t -c user.name=t commit -qm "feat: mod $i" >/dev/null 2>&1; done ) >/dev/null 2>&1
  # shellcheck disable=SC2046
  run_cli_env "$T" $G status
  assert_eq "新鲜度 WARN 不改 exit 0" 0 "$R_RC"
  assert_contains "WARN 新鲜度启发式" "$R_OUT" "无（非-notes）文档更新"
  # 未来日期 WARN：决策文件名日期晚于今天 → WARN 但 exit 0
  T=$(new_case); run_cli "$T" init
  ( cd "$T" && git init -q && git add -A >/dev/null 2>&1 \
    && git -c user.email=t@t -c user.name=t commit -qm init ) >/dev/null 2>&1
  write_valid_decision "$T" "implemented/feature/2099-01-01-future.md"
  # shellcheck disable=SC2046
  run_cli_env "$T" $G status
  assert_eq "未来日期 WARN 不改 exit（level 0 只验 L0）" 0 "$R_RC"
  assert_contains "WARN 未来日期" "$R_OUT" "晚于今天"
}

s27_run_specs() {
  echo "--- 场景27：判据 2.3 执行侧 opt-in（--run-specs）+ 只读默认 + 护栏（递归/dry-run）"
  local T
  # ① 只读不变量：默认 status/audit 不执行仓库脚本（spec 会落一个 WITNESS 见证文件）
  T=$(new_case); run_cli "$T" init
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/2026-01-02-gate.md"
  printf '#!/usr/bin/env bash\ntouch "$(cd "$(dirname "$0")" && pwd)/WITNESS.txt"\nexit 0\n' \
    > "$T/.meta/gates/x.spec.sh"
  run_cli "$T" status
  assert_eq "status 默认 exit 0" 0 "$R_RC"
  [ -f "$T/.meta/gates/WITNESS.txt" ] && bad "status 执行了仓库脚本（违反只读不变量）" || ok "status 未执行仓库脚本"
  run_cli "$T" audit
  [ -f "$T/.meta/gates/WITNESS.txt" ] && bad "audit 默认执行了仓库脚本（违反只读不变量）" || ok "audit 默认未执行仓库脚本"

  # ①b level:2 分支同样不得执行门禁脚本（2.2 只做 bash -n，不得执行）
  T=$(new_case); run_cli "$T" init
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/2026-01-02-gate.md"
  printf '#!/usr/bin/env bash\ntouch "$(cd "$(dirname "$0")" && pwd)/GATE_WITNESS.txt"\nexit 0\n' \
    > "$T/.meta/gates/readme.sh"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$T/.meta/gates/readme.spec.sh"
  printf 'level: 2\n' > "$T/.meta/meta.yaml"
  run_cli "$T" status
  [ -f "$T/.meta/gates/GATE_WITNESS.txt" ] && bad "level:2 status 执行了门禁脚本（2.2 应只做 bash -n）" || ok "level:2 status 未执行门禁脚本"

  # ①c usage 必须披露开关（否则用户不知道它存在）
  T=$(new_case); run_cli "$T" --help
  assert_contains "usage 披露 --run-specs" "$R_OUT" "--run-specs"

  # ② --run-specs 执行并断言 exit 0
  T=$(new_case); run_cli "$T" init
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/2026-01-02-gate.md"
  printf '#!/usr/bin/env bash\ntouch "$(cd "$(dirname "$0")" && pwd)/WITNESS.txt"\nexit 0\n' \
    > "$T/.meta/gates/x.spec.sh"
  run_cli "$T" audit --run-specs
  assert_eq "--run-specs 全过 → exit 0" 0 "$R_RC"
  assert_contains "报执行判据" "$R_OUT" "2.3 执行判据"
  [ -f "$T/.meta/gates/WITNESS.txt" ] && ok "--run-specs 确实执行了 spec" || bad "--run-specs 未执行 spec"

  # ②b 护栏变量必须真导出给子进程（删掉导出前缀则此断言红——护栏不得静默失效）
  T=$(new_case); run_cli "$T" init
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/2026-01-02-gate.md"
  printf '#!/usr/bin/env bash\n[ "${PONYGO_IN_SPEC:-0}" = "1" ] || { echo "missing guard env" >&2; exit 3; }\nexit 0\n' \
    > "$T/.meta/gates/env.spec.sh"
  run_cli "$T" audit --run-specs
  assert_eq "护栏变量已导出给 spec → exit 0" 0 "$R_RC"

  # ③ 有 spec 自检失败 → exit 1；多个失败必须全部报出（聚合，不只最后一个）；exit>1 也算失败
  printf '#!/usr/bin/env bash\necho "bad sample accepted" >&2\nexit 1\n' > "$T/.meta/gates/y.spec.sh"
  printf '#!/usr/bin/env bash\necho "second failure" >&2\nexit 5\n' > "$T/.meta/gates/z2.spec.sh"
  run_cli "$T" audit --run-specs
  assert_eq "spec 自检失败 → exit 1" 1 "$R_RC"
  assert_contains "报第一个失败 spec" "$R_OUT" "y.spec.sh"
  assert_contains "报第二个失败 spec（聚合）" "$R_OUT" "z2.spec.sh"
  assert_contains "exit>1 也算失败" "$R_OUT" "exit 5"
  assert_contains "回显输出尾部" "$R_OUT" "bad sample accepted"

  # ④ --dry-run 一律不执行脚本，且 SKIPPED 不得冒充 PASS
  rm -f "$T/.meta/gates/WITNESS.txt" "$T/.meta/gates/y.spec.sh" "$T/.meta/gates/z2.spec.sh"
  run_cli "$T" audit --run-specs --dry-run
  assert_eq "--dry-run exit 0" 0 "$R_RC"
  assert_contains "--dry-run 报 SKIPPED" "$R_OUT" "SKIPPED"
  [ -f "$T/.meta/gates/WITNESS.txt" ] && bad "--dry-run 仍执行了 spec" || ok "--dry-run 未执行 spec"

  # ⑤ 递归护栏：PONYGO_IN_SPEC=1 时 SKIPPED，且结论行必须限定"未验证"
  T=$(new_case); run_cli "$T" init
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/2026-01-02-gate.md"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$T/.meta/gates/z.spec.sh"
  run_cli_env "$T" PONYGO_IN_SPEC=1 audit --run-specs
  assert_contains "递归护栏报 SKIPPED" "$R_OUT" "SKIPPED"
  assert_not_contains "SKIPPED 不得并入全部通过" "$R_OUT" "spec 全部自检通过"
  assert_contains "结论行限定未验证" "$R_OUT" "2.3 执行判据 SKIPPED——本次未验证"

  # ⑥ 无 *.spec.sh → SKIPPED（不计入 PASS），非 FAIL
  T=$(new_case); run_cli "$T" init
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/2026-01-02-gate.md"
  printf 'x\n' > "$T/.meta/gates/format.spec.md"
  run_cli "$T" audit --run-specs
  assert_eq "无 .sh spec → exit 0（SKIPPED 非 FAIL）" 0 "$R_RC"
  assert_contains "报 SKIPPED 不计入 PASS" "$R_OUT" "SKIPPED 不计入 PASS"
  assert_contains "SKIPPED 时结论行显式提示未验证" "$R_OUT" "本次未验证门是否仍会拒绝非法样本"
  assert_contains "SKIPPED 时结论行限定范围" "$R_OUT" "2.3 执行判据 SKIPPED——本次未验证"

  # ⑦ --run-specs 只属于 audit：其余命令显式拒绝，不静默忽略
  run_cli "$T" status --run-specs
  assert_eq "status --run-specs → exit 1（显式拒绝）" 1 "$R_RC"
  assert_contains "报仅适用于 audit" "$R_OUT" "仅适用于"
}

s28_l2_reachability() {
  echo "--- 场景28：L1→L2 可达性（骨架 + 手工挂载步骤可复跑；证明判据可被满足，非声称框架自身为 L2）"
  local T; T=$(new_case); run_cli "$T" init
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/2026-01-02-gate.md"
  # L2 四件套：门禁脚本 + 负样本 spec + 本地钩子挂载 + 文档分层激活
  printf '#!/usr/bin/env bash\n[ -f README.md ] || exit 1\nexit 0\n' > "$T/.meta/gates/readme.sh"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$T/.meta/gates/readme.spec.sh"
  ( cd "$T" && git init -q && git config core.hooksPath .githooks && mkdir -p .githooks \
      && printf '#!/usr/bin/env bash\nexit 0\n' > .githooks/pre-commit ) >/dev/null 2>&1
  # 契约演进（freeze §6.6）：L2 四件套的「本地钩子挂载」须含哨兵块 + 非注释调用行 + 执行位
  # + A1 资产；反例（撤掉 hooksPath → 2.4 FAIL）保持原样，未弱化。
  wire_gate_fixture "$T"
  printf 'level: 2\n' > "$T/.meta/meta.yaml"
  printf '## 已激活文档家清单\n' >> "$T/.meta/docs-tier/README.md"
  run_cli "$T" status
  assert_eq "L2 四件套齐 → exit 0" 0 "$R_RC"
  assert_contains "报 L0-L2" "$R_OUT" "L0-L2"
  # 反例：撤掉钩子挂载 → 2.4 FAIL（证明 2.4 是真判据，不是形状摆设）
  ( cd "$T" && git config --unset core.hooksPath ) >/dev/null 2>&1
  # shellcheck disable=SC2046
  run_cli_env "$T" $(sanitize_git) status
  assert_eq "撤掉 hooksPath → exit 1" 1 "$R_RC"
  assert_contains "报 2.4" "$R_OUT" "2.4"

  # 作用域：L1 声明 docs-tier: on → 忽略（2.x 不在 L1 判据内，静默不告警，不校验 2.5）
  T=$(new_case); run_cli "$T" init
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  printf 'docs-tier: on\n' >> "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/2026-01-02-gate.md"
  run_cli "$T" status
  assert_eq "L1 + docs-tier: on → exit 0（忽略 2.x）" 0 "$R_RC"
  assert_not_contains "L1 不验 2.5（静默）" "$R_OUT" "2.5"
}

s29_doc_level_parity() {
  echo "--- 场景29：口径防复发——当前态文档不得复述旧档位区间（L6 / 0-6）"
  local f drift=0
  for f in README.md maturity-ladder.md .meta/meta.yaml .meta/constitution/constitution.md .meta/gates/README.md; do
    if grep -qE '(^|[^0-9A-Za-z])L6([^0-9]|$)' "$ROOT/$f" 2>/dev/null \
       || grep -qE '0[[:space:]]*[-–—][[:space:]]*6' "$ROOT/$f" 2>/dev/null; then
      bad "口径漂移：$f 仍含 L6 / 0-6"; drift=1
    fi
  done
  [ "$drift" = "0" ] && ok "当前态文档口径与真源一致（L0-L5）"
  # CLI 用户可见串与 case 分支一致（0-5）
  grep -q '用 0-5 或 off' "$ROOT/ponygo" && ok "retire 错误消息口径为 0-5" || bad "retire 错误消息仍是旧口径"
  # meta.yaml 不再复述阶梯（副本即漂移源）：只留指针
  grep -q 'maturity-ladder.md' "$ROOT/.meta/meta.yaml" && ok "meta.yaml 指向阶梯真源" || bad "meta.yaml 未指向阶梯真源"
  # CLI 的 LEVELS 显示名表只含 L0–L5（不得悄悄多出一档）
  if grep '^LEVELS=' "$ROOT/ponygo" | grep -q 'L6'; then bad "CLI LEVELS 含 L6"; else ok "CLI LEVELS 仅 L0-L5"; fi
  # 版本号一致性（spec §8 s29 扩展）：README 示例 tag == git 最新 tag 语义
  # （发布流程：实现 bump README 示例 → 从绿 main 切 tag → 以 tag 落点复核，bump 后/tag 前红是预期，spec §9）
  local ltag rtag
  ltag=$(git -C "$ROOT" tag --list 'v*' --sort=-version:refname | head -1)
  rtag=$(grep -oE 'releases/download/v[0-9]+\.[0-9]+\.[0-9]+/' "$ROOT/README.md" | head -1 | sed 's#releases/download/##' | tr -d '/')
  if [ -n "$ltag" ] && [ -n "$rtag" ]; then
    if [ "$ltag" = "$rtag" ]; then
      ok "README 示例 tag（$rtag）与 git 最新 tag 一致"
    else
      bad "README 示例 tag（$rtag）≠ git 最新 tag（$ltag）——发布流程中间态（bump 后/tag 前为预期，以 tag 落点复核）"
    fi
  else
    ok "仓库无 tag 或 README 未钉 release tag——版本一致性断言跳过（首次发布前无基线）"
  fi
}

s31_upgrade_drift() {
  echo "--- 场景31：upgrade 漂移报告（宇宙=s14 十文件；--check 漂移非零；donot 三场景）"
  local T
  # ① 健康实例（已填 constitution + 模板态 docs-tier）upgrade exit 0 且无"drift:"行
  T=$(new_case); run_cli "$T" init
  write_constitution_filled "$T"
  run_cli "$T" upgrade
  assert_eq "健康实例 upgrade exit 0" 0 "$R_RC"
  assert_not_contains "健康实例零漂移" "$R_OUT" "drift:"
  assert_contains "含漂移报告头" "$R_OUT" "漂移报告"
  assert_contains "报告内自证清理" "$R_OUT" "tmpdir 已清理"
  # ② 篡改一处宇宙内文件（notes/README.md 追加一行）→ 默认 exit 0 含 drift: 行；--check exit 非零
  printf '\n# 篡改标记\n' >> "$T/.agents/notes/README.md"
  run_cli "$T" upgrade
  assert_eq "篡改后默认 upgrade exit 0（漂移=观察）" 0 "$R_RC"
  assert_contains "报 drift 行" "$R_OUT" "drift:"
  assert_contains "drift 行带前缀" "$R_OUT" "drift: .agents/notes/README.md"
  run_cli "$T" upgrade --check
  assert_eq "--check 漂移 → exit 非零" 1 "$R_RC"
  # ③ 无 .meta/（有代码迹象的非空项目）→ die 指引 init
  T=$(new_case); printf '# proj\n' > "$T/README.md"
  run_cli "$T" upgrade
  assert_eq "有代码但无 .meta → die" 1 "$R_RC"
  assert_contains "指引 init" "$R_OUT" "ponygo init"
  # ④ 非 git → WARN（exit 0）
  T=$(new_case); run_cli "$T" init
  # init 在 mktemp 目录内，天然非 git——WARN 但 exit 0
  run_cli "$T" upgrade
  assert_eq "非 git 场景 upgrade exit 0" 0 "$R_RC"
  assert_contains "非 git WARN" "$R_OUT" "WARN 不在 git 仓库"
  # ⑤ 缺 meta.yaml/缺 level 行 → 按 L0 处理（不崩）
  T=$(new_case); run_cli "$T" init
  rm -f "$T/.meta/meta.yaml"
  run_cli "$T" upgrade
  assert_eq "缺 meta.yaml upgrade exit 0（按 L0）" 0 "$R_RC"
  assert_contains "L0 处理" "$R_OUT" "L0"
  T=$(new_case); run_cli "$T" init
  printf 'docs-tier: off\n' > "$T/.meta/meta.yaml"  # 有 meta.yaml 但无 level 行
  run_cli "$T" upgrade
  assert_eq "缺 level 行 upgrade exit 0（按 L0）" 0 "$R_RC"
  # ⑥ usage/parser 联动：--check 非 upgrade 拒绝；--check 与 --dry-run 互斥
  T=$(new_case); run_cli "$T" init
  run_cli "$T" status --check
  assert_eq "status --check → exit 1（显式拒绝）" 1 "$R_RC"
  assert_contains "报仅适用于 upgrade" "$R_OUT" "仅适用于 'ponygo upgrade'"
  run_cli "$T" upgrade --check --dry-run
  assert_eq "upgrade --check --dry-run → exit 1（互斥）" 1 "$R_RC"
  assert_contains "报互斥" "$R_OUT" "互斥"
  # ⑦ 已激活 docs-tier 实例（P2-1）：docs-tier/README.md 不参与比对（s14 锁模板态）——
  #    upgrade exit 0 且不报该文件 drift；--check 仍 exit 0（不假红）
  T=$(new_case); run_cli "$T" init
  printf '## 已激活文档家清单\n\n| tier | 家 |\n|---|---|\n| 决策记录 | .agents/notes/ |\n' > "$T/.meta/docs-tier/README.md"
  run_cli "$T" upgrade
  assert_eq "已激活实例 upgrade exit 0" 0 "$R_RC"
  assert_not_contains "不报 docs-tier drift" "$R_OUT" "drift: .meta/docs-tier/README.md"
  assert_contains "声明不支持比对" "$R_OUT" "不参与漂移比对"
  run_cli "$T" upgrade --check
  assert_eq "已激活实例 --check exit 0（不假红）" 0 "$R_RC"
}

s20_installer
s21_external001_regress
s22_hygiene_warn
s23_verify_note
s24_gate_layers
s25_doc_home_audit
s26_warn_tier
s27_run_specs
s30_release_chain() {
  echo "--- 场景30：发布校验和链（fail-closed / 同钉 tag / workflow 形状 / 裸哈希口径 / CRLF）"
  local T vreadme
  # ① fail-closed 双入口：README 主命令块守卫（静态）+ install.sh 显式空 SHA 拒绝（动态，不 mock curl）
  grep -q 'set -o pipefail' "$ROOT/README.md" && ok "README fail-closed 含 pipefail" || bad "README 缺 pipefail 守卫"
  grep -q '\[ -n "\$SHA" \]' "$ROOT/README.md" && ok "README fail-closed 含空 SHA 守卫" || bad "README 缺空 SHA 守卫"
  T=$(new_case); mkdir -p "$T/bin"
  if PONYGO_SHA256="" bash "$ROOT/install.sh" "$T/bin" >/dev/null 2>&1; then
    bad "install.sh 显式空 SHA 未拒绝（fail-closed 缺失）"
  else
    [ ! -f "$T/bin/ponygo" ] && ok "install.sh 空 SHA → 拒绝安装且无残留" || bad "install.sh 空 SHA 拒绝后仍残留 ponygo"
  fi
  # ② 同钉 tag：README 方式 A 的 bootstrap 行（install.sh URL）与 PONYGO_VERSION 同钉同一 tag；
  #    install.sh 未设版本时仍取 main（兼容分支，architect P1-2：真改的是 README 行）
  vreadme=$(grep -oE 'releases/download/v[0-9]+\.[0-9]+\.[0-9]+/' "$ROOT/README.md" | head -1 | sed 's#releases/download/##' | tr -d '/')
  [ -n "$vreadme" ] || { bad "README 未钉 release tag"; vreadme="v0.0.0"; }
  grep -qF "$vreadme/install.sh" "$ROOT/README.md" && ok "README bootstrap 行同钉 $vreadme" || bad "README bootstrap 行未钉 $vreadme"
  grep -qF "PONYGO_VERSION=$vreadme" "$ROOT/README.md" && ok "README PONYGO_VERSION 同钉 $vreadme" || bad "README PONYGO_VERSION 未钉 $vreadme"
  grep -q 'VERSION="${PONYGO_VERSION:-main}"' "$ROOT/install.sh" && ok "install.sh 未设版本回退 main" || bad "install.sh 缺 main 回退分支"
  # ③ workflow 静态六断言（spec §8 s30③ + security P1-1）：精确管线 / Linux runner / 顶层 permissions:{} /
  #    action 钉 commit SHA / tag 触发 / hex 附件断言（s30⑤）
  if [ -f "$ROOT/.github/workflows/release.yml" ]; then
    grep -qF 'sha256sum ponygo | awk' "$ROOT/.github/workflows/release.yml" && ok "workflow 裸哈希管线" || bad "workflow 缺裸哈希管线"
    grep -q 'runs-on: ubuntu-latest' "$ROOT/.github/workflows/release.yml" && ok "workflow 钉 Linux" || bad "workflow 未钉 Linux"
    grep -qE '^permissions: \{\}$' "$ROOT/.github/workflows/release.yml" && ok "workflow 顶层 permissions:{}" || bad "workflow 顶层 permissions 非 {}"
    grep -qE 'uses: actions/checkout@[0-9a-f]{40} # v[0-9]+' "$ROOT/.github/workflows/release.yml" && ok "checkout 钉 commit SHA" || bad "checkout 未钉 commit SHA"
    grep -qE 'uses: softprops/action-gh-release@[0-9a-f]{40} # v[0-9]+' "$ROOT/.github/workflows/release.yml" && ok "gh-release 钉 commit SHA" || bad "gh-release 未钉 commit SHA"
    grep -qE "tags: \['v\[0-9\]\+\.\[0-9\]\+\.\[0-9\]\+'\]" "$ROOT/.github/workflows/release.yml" && ok "workflow 仅语义化版本 tag 触发" || bad "workflow 触发条件非语义化版本 tag"
    grep -q "回验 raw.githubusercontent" "$ROOT/.github/workflows/release.yml" && ok "workflow 含 raw 回验" || bad "workflow 缺 raw 回验"
    grep -qE '\^\[0-9a-f\]\{64\}\$' "$ROOT/.github/workflows/release.yml" && ok "workflow 附件 64 hex 断言" || bad "workflow 缺附件 hex 断言"
    # ④ CRLF 断言（workflow 自身无 CRLF + 承诺的发布前 CRLF 检查静态存在）
    grep -q $'\r' "$ROOT/.github/workflows/release.yml" && bad "release.yml 自身含 CRLF" || ok "release.yml 无 CRLF"
    grep -qF "grep -q \$'\\r' ponygo" "$ROOT/.github/workflows/release.yml" && ok "workflow 含 CRLF 断言" || bad "workflow 缺 CRLF 断言"
  else
    bad "release.yml 缺失"
  fi
  # ⑤ README 维护者口径：裸哈希 awk 剥列 + 64 hex 附件语义（发布后以真实附件值为准）
  grep -qF '{print $1}' "$ROOT/README.md" && ok "README 维护者口径 awk 剥列" || bad "README 缺 awk 剥列口径"
  grep -qF 'sha256sum ponygo | awk' "$ROOT/README.md" && ok "README 裸哈希管线" || bad "README 缺裸哈希管线"
}
s32_task004_static() {
  echo "--- 场景32：TASK-004 静态存在性（G/I/S/D 四段，全称锚定；失败报 file:line）"
  g() { # $1=描述 $2=文件 $3=靶串（固定串）
    if grep -Hn -F -- "$3" "$ROOT/$2" >/dev/null 2>&1; then
      ok "$1（$2）"
    else
      bad "$1（$2 缺 [$3]）"
    fi
  }
  grep -q '^| 2\.A ' "$ROOT/audit/checklist.md" && ok "2.A 资源隔离存在" || bad "缺 2.A（audit/checklist.md）"
  grep -q '^| 2\.B ' "$ROOT/audit/checklist.md" && ok "2.B 状态同步存在" || bad "缺 2.B（audit/checklist.md）"
  grep -q '^| 2\.C ' "$ROOT/audit/checklist.md" && ok "2.C 处置静默存在" || bad "缺 2.C（audit/checklist.md）"
  g "判据链到家" "audit/checklist.md" 'methodology §4.7'
  g "用法小结已同步 18" "audit/checklist.md" '追加「机制层」（18 项）'
  g "checklist 纪律数已同步五条" "audit/checklist.md" '五条纪律'
  g "gates 链入行声明非门禁" ".meta/gates/README.md" '本行非门禁'
  g "gates 掩盖清单附注" ".meta/gates/README.md" '加超时'
  g "分节键存在" "docs/methodology.md" '分节键'
  g "旧格式有效原句存在" "docs/methodology.md" '旧整文件哈希记录仍有效'
  g "重名 ~2 规则存在" "docs/methodology.md" '~2'
  g "同级重名规则存在" "docs/methodology.md" '同级重名'
  g "F7 防逃逸句存在" "docs/methodology.md" '不得归 F7'
  g "纪律 4 存在" ".agents/skills/README.md" '工具定义卫生'
  g "纪律 5 存在" ".agents/skills/README.md" '简化勘探证据链'
  g "追溯句存在" ".agents/skills/README.md" '本提交之后新增/改写'
  g "计数不选优存在" "docs/methodology.md" '计数不选优'
  g "每事实一次存在" "docs/methodology.md" '每事实只说一次'
  g "证据链四件套存在" "docs/methodology.md" '证据链四件套'
  g "救命话：追溯句全句" ".agents/skills/README.md" '本节仅约束本提交之后新增/改写'
  g "救命话：旧格式有效" "docs/methodology.md" '旧整文件哈希记录仍有效'
  g "scorecard 精确句存在" "audit/scorecard.md" '2.A–2.C 任一有 review 记录'
  g "scorecard 9-10 分句存在" "audit/scorecard.md" '分类表可指到'
  g "depth-selector 已同步 18" "audit/depth-selector.md" '机制 18'
  g "README 已同步 18" "README.md" '机制 18'
}

# ============================================================
# observe 维度验收测试（s33~s36）—— Test Agent 冻结，实现方只读
#
# 依据：.dev-team/plan-observe-v2.md §5（退出码表）/§7（13 条测试契约）
#       + .dev-team/plan-observe-v3-addendum.md A1~A10（效力优先于 v2 冲突处）。
# 铁律：零 python3 / 零 jq / 零网络 / 零集群；每条断言必须是 rc / 输出子串 / 文件内容 之一，
#       禁止「跑了没报错即 pass」；用例一律在 mktemp case 目录内跑，fixture 逐 case 复制。
#
# 冻结的 --json 契约（v3 A6 + 本测试钉死的落地口径）：
#   * stdout 只有**一行紧凑 JSON**（无缩进/无换行），键序：
#     schema,command,declared_kind,current,target,skill{present,contract_version,compatible},
#     judges[4],gaps[]
#   * judges 固定 4 个 id，固定顺序：
#     declaration_present / no_placeholder / declaration_consistent / enforcement_mounted
#   * gaps 按 A6 词表顺序输出：declaration_missing,placeholder_present,declaration_inconsistent,
#     evidence_insufficient,enforcement_points_missing,diff_warn,enforcement_violation,
#     mount_missing,tool_error,below_target
#   * below_target 当且仅当 current∈{ob0,ob1,ob2} 且 rank(current) < rank(target)
#   * status 子命令：current 恒 unknown；declaration_consistent / enforcement_mounted 恒 skip
#   * target 由 .meta/meta.yaml 的 level 经 target_level_<N> 求得（缺 .meta/缺行 ⇒ level=0 ⇒ ob0）
#   * --json 时 skill 的原始输出与「人读证据」一律走 stderr（stdout 不得混入 STUB-* 标记）
# ============================================================
OBS_STUB="$ROOT/tests/fixtures/skill-stub"

# 把假 skill 复制进 case 目录（逐 case 一份副本，避免顺序/并发互污；不改 fixture 本体），
# 并按需改写 references/contract.json 的 contract_version（A8 唯一版本源）。→ 打印 skill 目录
stage_skill() { # <case-dir> [contract_version]
  local dst ver
  dst="$1/skill"; ver="${2:-1.0.3}"
  rm -rf "$dst"
  cp -R "$OBS_STUB" "$dst" || return 1
  printf '{"contract_version": "%s", "frozen_at": "2026-10-25"}\n' "$ver" \
    > "$dst/references/contract.json"
  printf '%s' "$dst"
}

# 文件树快照（排序后的「相对路径|内容校验和」）：零写断言的唯一依据。
# 不用 git status——case 在 mktemp 下非 git 仓，那是空断言（v2 C2 裁定）；cksum 两平台都在。
snap() { # <dir>
  ( cd "$1" 2>/dev/null || exit 1
    find . -type f -print 2>/dev/null | LC_ALL=C sort | while IFS= read -r f; do
      printf '%s|%s\n' "$f" "$(cksum < "$f" 2>/dev/null)"
    done )
}
assert_same_tree() { # <描述> <dir> <before-snapshot>
  local after
  after=$(snap "$2")
  if [ "$after" = "$3" ]; then
    ok "$1"
  else
    bad "$1（文件树被改写：有新增/删除/内容变化）"
    printf '  [snap] before %s 行 / after %s 行\n' \
      "$(printf '%s\n' "$3" | grep -c . )" "$(printf '%s\n' "$after" | grep -c . )" >&2
  fi
}

# 只捕 stdout 的 runner（--json 逐字断言用；stderr 丢弃 = 模拟 CI 管道消费者）
STD_OUT=""; STD_RC=0
run_cli_stdout() { # <dir> <args...>
  local dir; dir="$1"; shift
  STD_OUT=$(cd "$dir" && bash "$ROOT/ponygo" "$@" 2>/dev/null); STD_RC=$?
}
run_cli_stdout_env() { # <dir> VAR=val... <args...>
  local dir; dir="$1"; shift
  local -a envs=()
  while [ $# -gt 0 ]; do case "$1" in *=*) envs+=("$1"); shift ;; *) break ;; esac; done
  STD_OUT=$(cd "$dir" && env "${envs[@]}" bash "$ROOT/ponygo" "$@" 2>/dev/null); STD_RC=$?
}

# 本地建仓（无网络）。git 不可用时退化为建 .git 目录——够 fixture 判「非 git 仓」形状。
init_git() { # <dir>
  ( cd "$1" && git init -q . >/dev/null 2>&1 ) || :
  [ -d "$1/.git" ] || mkdir -p "$1/.git"
}

# 手写「正文无占位、注释含占位字面」的四维声明（A5：占位检查只扫非注释行）
write_decl_clean() { # <dir>
  mkdir -p "$1/docs" "$1/src"
  cat > "$1/docs/observability.yaml" <<'DECLEOF'
# 归属声明（测试手写）。注意：本注释行故意含占位符字面 __REPLACE_ME__，
# 按 A5 它不属于「占位残留」——占位检查只扫非注释行。
service: svc-a
kind: cli
dimensions:
  metrics:
    applicable: true
    anchor: src/metrics.txt
  tracing:
    applicable: true
    anchor: src/tracing.txt
  logs:
    applicable: true
    anchor: src/logs.txt
  issues:
    applicable: true
    anchor: src/issues.txt
reviewed_at: "2026-10-25"
DECLEOF
  : > "$1/src/metrics.txt"; : > "$1/src/tracing.txt"
  : > "$1/src/logs.txt";   : > "$1/src/issues.txt"
}

# 造一个「ob1 前提已具备」的 case：声明（正文无占位）+ .meta level（决定 target）+ git 仓
make_audit_case() { # <dir> [level]
  local lvl; lvl="${2:-3}"
  mkdir -p "$1/.meta"
  write_decl_clean "$1"
  printf 'level: %s\n' "$lvl" > "$1/.meta/meta.yaml"
  init_git "$1"
}

# ob2 的挂载载体形状证据（mount_carriers 之一：.githooks/pre-commit 正文含 audit-diff）
add_mount_carrier() { # <dir>
  mkdir -p "$1/.githooks"
  printf '#!/bin/sh\n# 变更级收口门禁（形状证据）\nbash scripts/audit-diff.sh --repo . --base HEAD\n' \
    > "$1/.githooks/pre-commit"
}

# 声明文件定位（yaml 优先）→ 打印绝对路径；无则 rc=1
decl_file() { # <dir>
  local f
  for f in docs/observability.yaml docs/observability.yml; do
    [ -f "$1/$f" ] && { printf '%s' "$1/$f"; return 0; }
  done
  return 1
}

# 完整映射数据块（--mapping 正向控制用；键名与嵌入块逐字一致）
write_mapping_full() { # <file>
  cat > "$1" <<'MAPEOF'
mapping_version: 1
ob_levels: ob0 ob1 ob2
ob_level0_name: 归属声明
ob_level1_name: 声明与现实一致
ob_level2_name: 收口与变更门禁
ob_advisory_name: ob3 成本与 SLO（目标画像，不参与判定）
target_level_0: ob0
target_level_1: ob0
target_level_2: ob1
target_level_3: ob2
target_level_4: ob2
target_level_5: ob2
kind_enum: desktop k8s-service cli batch library
contract_version_min: 1.0.3
declaration_paths: docs/observability.yaml docs/observability.yml
placeholder_token: __REPLACE_ME__
mount_carriers: .git/hooks/pre-commit .githooks/pre-commit .githooks/pre-push .pre-commit-config.yaml lefthook.yml .github/workflows .gitlab-ci.yml
skill_dir_rel: .agents/skills/observability-onboarding
external_timeout_seconds: 120
local_timeout_seconds: 3
MAPEOF
}

s33_observe_stub() {
  echo "--- 场景33：observe 命令面 + fixture 自查 + 零写 + A1 劫持 + A2 旗标位置 + A7/A10"
  local T SK SNAP0 SNAP1 OUT RC BIN
  BIN="$OBS_STUB/scripts"

  # ① fixture 自查（证明 stub 不是「纯常量桩」：真看入参、真吃 env）
  OUT=$(bash "$BIN/check-declaration.sh" "$SBASE/no-such-dir-xyz" 2>&1); RC=$?
  assert_eq "observe[fixture] check-declaration 入参校验：目录不存在 → exit 4" 4 "$RC"
  assert_contains "observe[fixture] check-declaration 标记 rc=4" "$OUT" "STUB-CHECK-DECL rc=4"
  OUT=$(STUB_RC_CHECK_DECL=2 bash "$BIN/check-declaration.sh" "$SBASE" 2>&1); RC=$?
  assert_eq "observe[fixture] check-declaration 吃 STUB_RC_CHECK_DECL=2" 2 "$RC"
  assert_contains "observe[fixture] check-declaration 标记 rc=2" "$OUT" "STUB-CHECK-DECL rc=2"
  OUT=$(bash "$BIN/audit-diff.sh" --repo "$SBASE/no-such-dir-xyz" 2>&1); RC=$?
  assert_eq "observe[fixture] audit-diff 入参校验：--repo 不存在 → exit 4" 4 "$RC"
  assert_contains "observe[fixture] audit-diff 标记 rc=4" "$OUT" "STUB-AUDIT-DIFF rc=4"
  OUT=$(STUB_RC_AUDIT_DIFF=3 bash "$BIN/audit-diff.sh" --repo "$SBASE" 2>&1); RC=$?
  assert_eq "observe[fixture] audit-diff 吃 STUB_RC_AUDIT_DIFF=3" 3 "$RC"

  # ② 帮助面（A7 明确断言；A10 已知局限必须进用户可见面）
  T=$(new_case); run_cli "$T" observe --help
  assert_eq "observe --help exit 0" 0 "$R_RC"
  assert_contains "observe --help 含 observe 用法段" "$R_OUT" "observe audit"
  assert_contains "observe --help 含 status 段" "$R_OUT" "observe status"
  assert_contains "observe[K4] 帮助含四维全 false 局限" "$R_OUT" "四维全 false"
  assert_contains "observe[K4] 帮助含 K4 记录指针" "$R_OUT" "K4"
  assert_contains "observe[K7] 帮助含挂载为形状判据局限" "$R_OUT" "形状判据"
  assert_contains "observe[K7] 帮助含 K7 标记" "$R_OUT" "K7"
  run_cli "$T" observe -h
  assert_eq "observe -h exit 0" 0 "$R_RC"
  run_cli "$T" --help
  assert_eq "ponygo --help exit 0（含 observe 段不得破坏）" 0 "$R_RC"
  assert_contains "ponygo --help 含 observe 段" "$R_OUT" "ponygo observe"

  # ③ 无子命令 / 未知子命令（A7 写死，不留「断言实际行为」）
  T=$(new_case); run_cli "$T" observe
  assert_eq "observe 无子命令 → exit 1" 1 "$R_RC"
  assert_contains "observe 无子命令报「未知 observe 子命令」" "$R_OUT" "未知 observe 子命令"
  T=$(new_case); run_cli "$T" observe foo
  assert_eq "observe foo（未知子命令）→ exit 1" 1 "$R_RC"
  assert_contains "observe foo 报「未知 observe 子命令」" "$R_OUT" "未知 observe 子命令"

  # ④ A1：observe <sub> 之后的第二个子命令词不得劫持 CMD（曾实测真的执行 init 并写盘）
  T=$(new_case); SNAP0=$(snap "$T")
  run_cli "$T" observe status init
  assert_eq "observe[A1] observe status init → exit 1（不得执行 init）" 1 "$R_RC"
  assert_same_tree "observe[A1] observe status init 零写（文件树快照不变）" "$T" "$SNAP0"
  assert_eq "observe[A1] 未生成 .meta/meta.yaml" "no" "$([ -f "$T/.meta/meta.yaml" ] && echo yes || echo no)"
  assert_eq "observe[A1] 未生成 docs/observability.yaml" "no" \
    "$([ -f "$T/docs/observability.yaml" ] && echo yes || echo no)"
  assert_eq "observe[A1] 未生成 AGENTS.md" "no" "$([ -f "$T/AGENTS.md" ] && echo yes || echo no)"

  # ⑤ status 只读（干净目录）+ 零写（双快照）
  T=$(new_case); SNAP0=$(snap "$T")
  run_cli "$T" observe status
  assert_eq "observe status 干净目录 exit 0（静态报告不判定）" 0 "$R_RC"
  assert_not_contains "observe status 不得是空桩" "$R_OUT" "NOT IMPLEMENTED"
  SNAP1=$(snap "$T")
  assert_same_tree "observe status 零写（文件树快照不变）" "$T" "$SNAP0"
  assert_eq "observe status 快照自洽（前后行数相同）" \
    "$(printf '%s\n' "$SNAP0" | grep -c .)" "$(printf '%s\n' "$SNAP1" | grep -c .)"

  # ⑥ A2：--skill-dir 出现在子命令之前也必须走到 audit（不得 die「未知 observe 子命令」）
  T=$(new_case); SK=$(stage_skill "$T")
  run_cli "$T" observe --skill-dir "$SK" audit
  assert_not_contains "observe[A2] --skill-dir 前置不得被当子命令" "$R_OUT" "未知 observe 子命令"
  assert_eq "observe[A2] observe --skill-dir <d> audit（无声明）→ exit 1" 1 "$R_RC"
  run_cli "$T" observe audit --skill-dir "$SK"
  assert_not_contains "observe[A2] --skill-dir 后置同样不得被当子命令" "$R_OUT" "未知 observe 子命令"
  assert_eq "observe[A2] observe audit --skill-dir <d>（无声明）→ exit 1" 1 "$R_RC"

  # ⑦ §7.12 单文件自洽：把 ponygo 复制到临时目录后仍能跑（数据块随文件走）
  T=$(new_case); mkdir -p "$T/bin"; cp "$ROOT/ponygo" "$T/bin/ponygo"
  OUT=$(cd "$T" && bash bin/ponygo observe status 2>&1); RC=$?
  assert_eq "observe 单文件自洽：副本 observe status exit 0" 0 "$RC"

  # ⑧ 既有守卫不得被 observe 旗标污染（--json / --skill-dir / --mapping 只属 observe）
  T=$(new_case); run_cli "$T" status --json
  assert_eq "status --json → exit 1（旗标仅属 observe）" 1 "$R_RC"
  assert_contains "status --json 报仅适用于 observe" "$R_OUT" "仅适用于 'ponygo observe status|audit'"
  run_cli "$T" status --skill-dir /tmp
  assert_eq "status --skill-dir → exit 1" 1 "$R_RC"
  assert_contains "status --skill-dir 报仅适用于 observe" "$R_OUT" "仅适用于 'ponygo observe'"
  run_cli "$T" audit --level S --mapping "$T/x"
  assert_eq "audit --mapping → exit 1" 1 "$R_RC"
}

s34_observe_init() {
  echo "--- 场景34：observe init（dry-run/落盘/四维/占位/参数校验/版本门/A5 注释占位）"
  local T SK SKL DECL TXT SNAP0 CMT

  # ① --dry-run 零写
  T=$(new_case); SK=$(stage_skill "$T"); SNAP0=$(snap "$T")
  run_cli "$T" observe init --dry-run --kind cli --skill-dir "$SK"
  assert_eq "observe init --dry-run --kind cli → exit 0" 0 "$R_RC"
  assert_same_tree "observe init --dry-run 零写（文件树快照不变）" "$T" "$SNAP0"
  assert_contains "observe init --dry-run 打印目标声明路径" "$R_OUT" "docs/observability.yaml"

  #    --dry-run 与 --force 并存 → 以 dry-run 为准（§2：只打印，不落盘）
  T=$(new_case); SK=$(stage_skill "$T"); SNAP0=$(snap "$T")
  run_cli "$T" observe init --dry-run --force --kind cli --skill-dir "$SK"
  assert_eq "observe init --dry-run --force 并存 → exit 0（dry-run 优先）" 0 "$R_RC"
  assert_same_tree "observe init --dry-run --force 零写（快照不变）" "$T" "$SNAP0"

  # ② 真落盘：四维齐备 + 占位符（模板态）
  run_cli "$T" observe init --kind cli --skill-dir "$SK"
  assert_eq "observe init --kind cli exit 0" 0 "$R_RC"
  DECL=$(decl_file "$T") || DECL=""
  assert_eq "observe init 落盘 docs/observability.yaml" "yes" \
    "$([ -n "$DECL" ] && echo yes || echo no)"
  TXT=$(cat "$DECL" 2>/dev/null || :)
  assert_contains "observe init 声明含 dimensions 容器" "$TXT" "dimensions:"
  assert_contains "observe init 声明含 metrics 维" "$TXT" "metrics:"
  assert_contains "observe init 声明含 tracing 维" "$TXT" "tracing:"
  assert_contains "observe init 声明含 logs 维" "$TXT" "logs:"
  assert_contains "observe init 声明含 issues 维" "$TXT" "issues:"
  assert_contains "observe init 声明含 placeholder 占位（模板态）" "$TXT" "__REPLACE_ME__"
  assert_contains "observe init 声明含 kind: cli" "$TXT" "kind: cli"
  assert_contains "observe init 声明含 reviewed_at" "$TXT" "reviewed_at:"
  CMT=$(grep -E '^[[:space:]]*#' "$DECL" 2>/dev/null | grep -c '__REPLACE_ME__' || :)
  assert_eq "observe[A5] init 生成的注释行不含 __REPLACE_ME__ 字面" 0 "${CMT:-0}"

  # ③ status 在模板态报 ob0（占位残留）
  run_cli "$T" observe status --skill-dir "$SK"
  assert_eq "observe status（模板态）exit 0" 0 "$R_RC"
  assert_contains "observe status（模板态）报 ob0" "$R_OUT" "ob0"

  # ④ A5：正文无占位、注释含占位字面 ⇒ 判「无占位」；stub rc=2 ⇒ ob0 达 / ob1 未达
  # K11：退出码口径 = 「当前级 ≥ 目标级」。本 case 需 level: 3（→ target=ob2）才让 current=ob0 判「未达目标」
  T=$(new_case); SK=$(stage_skill "$T"); make_audit_case "$T" 3
  run_cli_env "$T" STUB_RC_CHECK_DECL=2 observe audit --skill-dir "$SK"
  assert_eq "observe[A5] 注释含占位/正文无占位 → ob1 未达 exit 1（占位不误判）" 1 "$R_RC"
  run_cli_stdout_env "$T" STUB_RC_CHECK_DECL=2 observe audit --skill-dir "$SK" --json
  assert_contains "observe[A5] 该声明 current=ob0（ob0 已达）" "$STD_OUT" '"current":"ob0"'
  assert_contains "observe[A5] no_placeholder 判 pass" "$STD_OUT" \
    '{"id":"no_placeholder","status":"pass"}'

  # ⑤ 参数校验（§5：init 各类输入错误 → 2）
  T=$(new_case); SK=$(stage_skill "$T")
  run_cli "$T" observe init --skill-dir "$SK"
  assert_eq "observe init 缺 --kind → exit 2" 2 "$R_RC"
  run_cli "$T" observe init --kind bogus --skill-dir "$SK"
  assert_eq "observe init --kind bogus → exit 2" 2 "$R_RC"
  run_cli "$T" observe init --kind cli --service 'a: b' --skill-dir "$SK"
  assert_eq "observe init --service 'a: b'（YAML 注入形状）→ exit 2" 2 "$R_RC"
  run_cli "$T" observe init --kind cli --service 'svc-a' --skill-dir "$SK"
  assert_eq "observe init 合法 service 名 exit 0" 0 "$R_RC"
  run_cli "$T" observe init --kind cli --service 'svc-a' --skill-dir "$SK"
  assert_eq "observe init 声明已存在且无 --force → exit 2" 2 "$R_RC"
  run_cli "$T" observe init --kind cli --service 'svc-a' --skill-dir "$SK" --force
  assert_eq "observe init --force 覆盖 → exit 0" 0 "$R_RC"

  # ⑥ 全参 init 一条命令达 ob0（--dims 内 applicable:true + anchor，外 false + reason）
  T=$(new_case); SK=$(stage_skill "$T"); mkdir -p "$T/src"
  : > "$T/src/tracing.txt"; : > "$T/src/issues.txt"
  run_cli "$T" observe init --kind cli --skill-dir "$SK" \
    --dims tracing,issues --anchor-tracing src/tracing.txt --anchor-issues src/issues.txt \
    --reason-metrics "指标由 k8s 侧采集" --reason-logs "日志走集群采集"
  assert_eq "observe init 全参 exit 0" 0 "$R_RC"
  DECL=$(decl_file "$T") || DECL=""
  TXT=$(cat "$DECL" 2>/dev/null || :)
  assert_not_contains "observe init 全参声明无占位残留" "$TXT" "__REPLACE_ME__"
  assert_contains "observe init 全参：dims 外 applicable: false" "$TXT" "applicable: false"
  assert_contains "observe init 全参：dims 内 anchor 写入" "$TXT" "src/tracing.txt"
  assert_contains "observe init 全参：dims 外 reason 写入" "$TXT" "指标由 k8s 侧采集"
  # K11 同步：case 由 init 造声明、无 .meta 时 target=ob0（current=ob0 ⇒ 反而 exit 0）；
  # 显式写 level: 3 ⇒ target=ob2 ⇒ current=ob0 < target ⇒ exit 1。缺口列表只作 backlog，不决定退出码。
  mkdir -p "$T/.meta"; printf 'level: 3\n' > "$T/.meta/meta.yaml"
  run_cli_env "$T" STUB_RC_CHECK_DECL=2 observe audit --skill-dir "$SK"
  assert_eq "observe audit（全参 + stub rc=2）→ ob1 未达 exit 1" 1 "$R_RC"

  # ⑦ A8 版本门：<skill>/references/contract.json 是唯一版本源；低版本 init → 2
  T=$(new_case); SKL=$(stage_skill "$T" 0.9.9)
  run_cli "$T" observe init --kind cli --skill-dir "$SKL"
  assert_eq "observe[A8] contract 0.9.9（低于 1.0.3）init → exit 2" 2 "$R_RC"
  assert_contains "observe[A8] 低版本提示 min 版本 1.0.3" "$R_OUT" "1.0.3"
  T=$(new_case); SK=$(stage_skill "$T")
  run_cli_env "$T" PONYGO_SKILL_DIR="$SK" observe init --kind cli
  assert_eq "observe[A8] PONYGO_SKILL_DIR 注入 init exit 0" 0 "$R_RC"
  T=$(new_case)
  run_cli "$T" observe init --kind cli --skill-dir "$T/根本没有这个 skill"
  assert_eq "observe[A8] skill 目录缺失 init → exit 2" 2 "$R_RC"
  assert_contains "observe[A8] skill 缺失提示含 skill 字样" "$R_OUT" "skill"

  # ⑧ audit 零写（init 才是唯一写命令）
  T=$(new_case); SK=$(stage_skill "$T"); make_audit_case "$T" 3; add_mount_carrier "$T"
  SNAP0=$(snap "$T")
  run_cli_env "$T" STUB_RC_CHECK_DECL=0 STUB_RC_AUDIT_DIFF=0 observe audit --skill-dir "$SK"
  assert_same_tree "observe audit 零写（文件树快照不变）" "$T" "$SNAP0"
}

s35_observe_audit() {
  echo "--- 场景35：observe audit（ob0/ob1/ob2 判据 + rc 白名单 + A3 audit-diff rc 映射 + 路由隔离）"
  local T SK SNAP0

  # ① 无声明 → ob0 未达 exit 1，且不得串到顶层 cmd_audit
  T=$(new_case); SK=$(stage_skill "$T"); init_git "$T"
  run_cli "$T" observe audit --skill-dir "$SK"
  assert_eq "observe audit 无声明 → exit 1" 1 "$R_RC"
  assert_contains "observe audit 无声明指向声明路径" "$R_OUT" "docs/observability.yaml"
  assert_not_contains "observe audit 路由隔离：不触发顶层 cmd_audit" "$R_OUT" \
    "===== ponygo 审计结果"
  assert_not_contains "observe audit 不得是空桩" "$R_OUT" "NOT IMPLEMENTED"

  # ② ob0 判据 ③：check-declaration rc 白名单 {0,2,3}
  T=$(new_case); SK=$(stage_skill "$T"); make_audit_case "$T" 3
  run_cli_env "$T" STUB_RC_CHECK_DECL=2 observe audit --skill-dir "$SK"
  assert_eq "observe audit（skill rc=2）→ ob1 未达 exit 1" 1 "$R_RC"
  run_cli_env "$T" STUB_RC_CHECK_DECL=0 STUB_RC_AUDIT_DIFF=1 observe audit --skill-dir "$SK"
  assert_eq "observe audit（skill rc=0、audit-diff rc=1）→ ob2 未达 exit 1" 1 "$R_RC"
  assert_contains "observe audit ob2 未达报 enforcement 缺口" "$R_OUT" "enforcement"
  run_cli_env "$T" STUB_RC_CHECK_DECL=3 observe audit --skill-dir "$SK"
  assert_eq "observe audit（skill rc=3 证据不足）→ exit 3" 3 "$R_RC"
  run_cli_env "$T" STUB_RC_CHECK_DECL=4 observe audit --skill-dir "$SK"
  assert_eq "observe audit（skill rc=4 声明层不可判定）→ exit 2" 2 "$R_RC"
  assert_contains "observe[A4] rc=4 给出两条排查路径（声明层不可判定）" "$R_OUT" "声明层不可判定"
  run_cli_env "$T" STUB_RC_CHECK_DECL=127 observe audit --skill-dir "$SK"
  assert_eq "observe audit（skill rc=127 非白名单）→ exit 2（C1 反例，绝不当达标）" 2 "$R_RC"

  # ③ A3：audit-diff 的 rc 映射（0 达标候选 / 1 未达 / 2 违例 / 3|4 判定中止 rc=2）
  T=$(new_case); SK=$(stage_skill "$T"); make_audit_case "$T" 3; add_mount_carrier "$T"
  run_cli_env "$T" STUB_RC_CHECK_DECL=0 STUB_RC_AUDIT_DIFF=0 observe audit --skill-dir "$SK"
  assert_eq "observe[A3] audit-diff rc=0 + 挂载载体存在 → 全达 exit 0" 0 "$R_RC"
  assert_contains "observe ob3 advisory 含 gen_ai 成本归因" "$R_OUT" "gen_ai"
  assert_contains "observe ob3 advisory 含 SLI 告警" "$R_OUT" "SLI"
  assert_contains "observe ob3 段存在（不参与退出码）" "$R_OUT" "ob3"
  run_cli_env "$T" STUB_RC_CHECK_DECL=0 STUB_RC_AUDIT_DIFF=2 observe audit --skill-dir "$SK"
  assert_eq "observe[A3] audit-diff rc=2（违规）→ ob2 未达 exit 1" 1 "$R_RC"
  assert_contains "observe[A3] audit-diff rc=2 报 enforcement_violation" "$R_OUT" "enforcement_violation"
  run_cli_env "$T" STUB_RC_CHECK_DECL=0 STUB_RC_AUDIT_DIFF=3 observe audit --skill-dir "$SK"
  assert_eq "observe[A3] audit-diff rc=3（证据不可得）→ 判定中止 exit 3" 3 "$R_RC"
  assert_contains "observe[A3] audit-diff rc=3（证据不可得）报 evidence_insufficient" "$R_OUT" "evidence_insufficient"
  run_cli_env "$T" STUB_RC_CHECK_DECL=0 STUB_RC_AUDIT_DIFF=4 observe audit --skill-dir "$SK"
  assert_eq "observe[A3] audit-diff rc=4（工具错误）→ 判定中止 exit 2" 2 "$R_RC"

  # ④ ob2 挂载缺失（audit-diff rc=0 但无载体）→ ob2 未达 exit 1，gaps 非空
  T=$(new_case); SK=$(stage_skill "$T"); make_audit_case "$T" 3
  run_cli_env "$T" STUB_RC_CHECK_DECL=0 STUB_RC_AUDIT_DIFF=0 observe audit --skill-dir "$SK"
  assert_eq "observe ob2 挂载缺失 → exit 1" 1 "$R_RC"
  run_cli_stdout "$T" observe audit --skill-dir "$SK" --json
  assert_contains "observe ob2 挂载缺失报 mount_missing" "$STD_OUT" "mount_missing"
  assert_not_contains "observe ob2 挂载缺失 gaps 非空" "$STD_OUT" '"gaps":[]'
  assert_not_contains "observe --json 时 skill 原始输出不得混入 stdout" "$STD_OUT" "STUB-CHECK-DECL"

  # ⑤ --level 目标级（ob3 显式拒绝；未达目标 exit 1）
  T=$(new_case); SK=$(stage_skill "$T"); make_audit_case "$T" 3
  run_cli_env "$T" STUB_RC_CHECK_DECL=0 STUB_RC_AUDIT_DIFF=1 observe audit --level ob2 --skill-dir "$SK"
  assert_eq "observe audit --level ob2（当前 ob1）→ exit 1" 1 "$R_RC"
  run_cli_env "$T" STUB_RC_CHECK_DECL=0 STUB_RC_AUDIT_DIFF=1 observe audit --level ob1 --skill-dir "$SK"
  assert_eq "observe audit --level ob1（当前 ob1）→ exit 0" 0 "$R_RC"
  run_cli "$T" observe audit --level ob3 --skill-dir "$SK"
  assert_eq "observe audit --level ob3 → die 1（目标画像不参与判定）" 1 "$R_RC"
  assert_contains "observe audit --level ob3 文案说明 ob3 不参与判定" "$R_OUT" "ob3"
  run_cli "$T" observe audit --level bogus --skill-dir "$SK"
  assert_eq "observe audit --level bogus → die 1" 1 "$R_RC"

  # ⑥ 顶层 audit 行为不变（§7.8 另一侧）
  T=$(new_case)
  run_cli "$T" audit --level S
  assert_eq "顶层 audit --level S 行为不变（exit 0）" 0 "$R_RC"
  assert_contains "顶层 audit 仍打印审计结果头" "$R_OUT" "===== ponygo 审计结果"

  # ⑦ audit / upgrade --check 只读：零写（快照）
  T=$(new_case); SK=$(stage_skill "$T"); make_audit_case "$T" 3; add_mount_carrier "$T"
  SNAP0=$(snap "$T")
  run_cli_env "$T" STUB_RC_CHECK_DECL=0 STUB_RC_AUDIT_DIFF=0 observe audit --skill-dir "$SK"
  assert_eq "observe audit（全达）exit 0" 0 "$R_RC"
  assert_same_tree "observe audit 只读：零写（文件树快照不变）" "$T" "$SNAP0"
  run_cli_env "$T" STUB_RC_CHECK_DECL=0 STUB_RC_AUDIT_DIFF=0 observe upgrade --check --skill-dir "$SK"
  assert_same_tree "observe upgrade --check 只读：零写" "$T" "$SNAP0"
}

s36_observe_json() {
  echo "--- 场景36：observe --json 逐字契约（A6）+ upgrade --check 版本门 + --mapping fail-closed"
  local T SK EXP JSON1 MAP SNAP0

  # ① status：current 恒 unknown；declaration_consistent / enforcement_mounted 恒 skip
  T=$(new_case); SK=$(stage_skill "$T")
  run_cli "$T" observe init --kind cli --skill-dir "$SK"
  run_cli_stdout "$T" observe status --skill-dir "$SK" --json
  EXP='{"schema":"ponygo.observe/1","command":"status","declared_kind":"cli","current":"unknown","target":"ob0","skill":{"present":true,"contract_version":"1.0.3","compatible":true},"judges":[{"id":"declaration_present","status":"pass"},{"id":"no_placeholder","status":"fail"},{"id":"declaration_consistent","status":"skip"},{"id":"enforcement_mounted","status":"skip"}],"gaps":["placeholder_present"]}'
  assert_eq "observe[A6] status --json 逐字（stdout 单行 JSON）" "$EXP" "$STD_OUT"
  assert_eq "observe[A6] status --json exit 0（静态报告不判定）" 0 "$STD_RC"
  assert_eq "observe[A6] status --json stdout 只有一行" 1 \
    "$(printf '%s\n' "$STD_OUT" | wc -l | tr -d ' ')"

  # ② audit skill rc=0 全达：current=ob2 / target=ob2 / judges 全 pass / gaps []
  T=$(new_case); SK=$(stage_skill "$T"); make_audit_case "$T" 3; add_mount_carrier "$T"
  run_cli_stdout_env "$T" STUB_RC_CHECK_DECL=0 STUB_RC_AUDIT_DIFF=0 \
    observe audit --level ob2 --skill-dir "$SK" --json
  EXP='{"schema":"ponygo.observe/1","command":"audit","declared_kind":"cli","current":"ob2","target":"ob2","skill":{"present":true,"contract_version":"1.0.3","compatible":true},"judges":[{"id":"declaration_present","status":"pass"},{"id":"no_placeholder","status":"pass"},{"id":"declaration_consistent","status":"pass"},{"id":"enforcement_mounted","status":"pass"}],"gaps":[]}'
  assert_eq "observe[A6] audit rc=0 全达 --json 逐字" "$EXP" "$STD_OUT"
  assert_eq "observe[A6] audit rc=0 全达 exit 0" 0 "$STD_RC"

  # ③ audit skill rc=2：current=ob0 / declaration_consistent=fail / gaps 含 below_target
  T=$(new_case); SK=$(stage_skill "$T"); make_audit_case "$T" 3
  run_cli_stdout_env "$T" STUB_RC_CHECK_DECL=2 observe audit --skill-dir "$SK" --json
  EXP='{"schema":"ponygo.observe/1","command":"audit","declared_kind":"cli","current":"ob0","target":"ob2","skill":{"present":true,"contract_version":"1.0.3","compatible":true},"judges":[{"id":"declaration_present","status":"pass"},{"id":"no_placeholder","status":"pass"},{"id":"declaration_consistent","status":"fail"},{"id":"enforcement_mounted","status":"skip"}],"gaps":["declaration_inconsistent","below_target"]}'
  assert_eq "observe[A6] audit skill rc=2 --json 逐字" "$EXP" "$STD_OUT"
  assert_eq "observe[A6] audit skill rc=2 exit 1" 1 "$STD_RC"

  # ④ audit skill rc=3：证据不足 → current=ob0 / declaration_consistent=unknown
  T=$(new_case); SK=$(stage_skill "$T"); make_audit_case "$T" 3
  run_cli_stdout_env "$T" STUB_RC_CHECK_DECL=3 observe audit --skill-dir "$SK" --json
  EXP='{"schema":"ponygo.observe/1","command":"audit","declared_kind":"cli","current":"ob0","target":"ob2","skill":{"present":true,"contract_version":"1.0.3","compatible":true},"judges":[{"id":"declaration_present","status":"pass"},{"id":"no_placeholder","status":"pass"},{"id":"declaration_consistent","status":"unknown"},{"id":"enforcement_mounted","status":"skip"}],"gaps":["evidence_insufficient","below_target"]}'
  assert_eq "observe[A6] audit skill rc=3 --json 逐字" "$EXP" "$STD_OUT"
  assert_eq "observe[A6] audit skill rc=3 exit 3" 3 "$STD_RC"

  # ⑤ audit skill rc=4：声明层不可判定 → current=unknown / gap=tool_error（A4）
  T=$(new_case); SK=$(stage_skill "$T"); make_audit_case "$T" 3
  run_cli_stdout_env "$T" STUB_RC_CHECK_DECL=4 observe audit --skill-dir "$SK" --json
  EXP='{"schema":"ponygo.observe/1","command":"audit","declared_kind":"cli","current":"unknown","target":"ob2","skill":{"present":true,"contract_version":"1.0.3","compatible":true},"judges":[{"id":"declaration_present","status":"pass"},{"id":"no_placeholder","status":"pass"},{"id":"declaration_consistent","status":"unknown"},{"id":"enforcement_mounted","status":"skip"}],"gaps":["tool_error"]}'
  assert_eq "observe[A6] audit skill rc=4（tool_error 路）--json 逐字" "$EXP" "$STD_OUT"
  assert_eq "observe[A6] audit skill rc=4 exit 2" 2 "$STD_RC"
  assert_not_contains "observe[A6] --json stdout 无 skill 原始输出" "$STD_OUT" "STUB-"

  # ⑥ audit-diff 判定中止（rc=3）：gap=evidence_insufficient（F7 裁决：与 check-declaration rc=3 同义），current=unknown，exit 3
  T=$(new_case); SK=$(stage_skill "$T"); make_audit_case "$T" 3; add_mount_carrier "$T"
  run_cli_stdout_env "$T" STUB_RC_CHECK_DECL=0 STUB_RC_AUDIT_DIFF=3 \
    observe audit --skill-dir "$SK" --json
  assert_eq "observe[A3] audit-diff rc=3 exit 3" 3 "$STD_RC"
  assert_contains "observe[A3] audit-diff rc=3 gaps 含 evidence_insufficient" "$STD_OUT" '"gaps":["evidence_insufficient"]'
  assert_contains "observe[A3] audit-diff rc=3 current=unknown" "$STD_OUT" '"current":"unknown"'

  # ⑦ ob2 挂载缺失的逐字 JSON（current=ob1 / enforcement_mounted=fail / 两缺口）
  T=$(new_case); SK=$(stage_skill "$T"); make_audit_case "$T" 3
  run_cli_stdout_env "$T" STUB_RC_CHECK_DECL=0 STUB_RC_AUDIT_DIFF=0 \
    observe audit --skill-dir "$SK" --json
  EXP='{"schema":"ponygo.observe/1","command":"audit","declared_kind":"cli","current":"ob1","target":"ob2","skill":{"present":true,"contract_version":"1.0.3","compatible":true},"judges":[{"id":"declaration_present","status":"pass"},{"id":"no_placeholder","status":"pass"},{"id":"declaration_consistent","status":"pass"},{"id":"enforcement_mounted","status":"fail"}],"gaps":["mount_missing","below_target"]}'
  assert_eq "observe[A6] 挂载缺失 --json 逐字" "$EXP" "$STD_OUT"
  assert_eq "observe[A6] 挂载缺失 exit 1" 1 "$STD_RC"

  # ⑧ A2：--level 前置与后置等价（不得静默丢弃）
  T=$(new_case); SK=$(stage_skill "$T"); make_audit_case "$T" 3
  run_cli_stdout_env "$T" STUB_RC_CHECK_DECL=0 STUB_RC_AUDIT_DIFF=1 \
    observe audit --level ob1 --skill-dir "$SK" --json
  JSON1="$STD_OUT"
  assert_eq "observe[A2] observe audit --level ob1（后置）exit 0" 0 "$STD_RC"
  run_cli_stdout_env "$T" STUB_RC_CHECK_DECL=0 STUB_RC_AUDIT_DIFF=1 \
    --level ob1 observe audit --skill-dir "$SK" --json
  assert_eq "observe[A2] --level ob1 observe audit（前置）exit 与后置相同" 0 "$STD_RC"
  assert_eq "observe[A2] 前置/后置 --json stdout 逐字相同" "$JSON1" "$STD_OUT"
  assert_contains "observe[A2] 前置结果非空（防「空==空」假绿）" "$JSON1" \
    '"schema":"ponygo.observe/1"'
  assert_contains "observe[A2] --level 前置生效（target=ob1）" "$STD_OUT" '"target":"ob1"'
  run_cli "$T" --level S observe audit --skill-dir "$SK"
  assert_eq "observe[A2] --level S + observe → die 1（值域隔离）" 1 "$R_RC"

  # ⑨ A3：--base 透传不破坏判定
  T=$(new_case); SK=$(stage_skill "$T"); make_audit_case "$T" 3; add_mount_carrier "$T"
  run_cli_env "$T" STUB_RC_CHECK_DECL=0 STUB_RC_AUDIT_DIFF=0 \
    observe audit --base HEAD --skill-dir "$SK"
  assert_eq "observe[A3] audit --base HEAD 透传后仍 exit 0" 0 "$R_RC"

  # ⑩ upgrade --check 版本门（逐段数值比较：1.0.10 ≥ 1.0.3；0.9.9 < 1.0.3）
  T=$(new_case); SK=$(stage_skill "$T" 1.0.3)
  run_cli "$T" observe upgrade --check --skill-dir "$SK"
  assert_eq "observe upgrade --check 1.0.3 兼容 → exit 0" 0 "$R_RC"
  T=$(new_case); SK=$(stage_skill "$T" 1.0.10)
  run_cli "$T" observe upgrade --check --skill-dir "$SK"
  assert_eq "observe upgrade --check 1.0.10 兼容（逐段数值比较）→ exit 0" 0 "$R_RC"
  run_cli "$T" observe upgrade --skill-dir "$SK"
  assert_eq "observe upgrade（无 --check）兼容 → exit 0" 0 "$R_RC"
  T=$(new_case); SK=$(stage_skill "$T" 0.9.9)
  run_cli "$T" observe upgrade --check --skill-dir "$SK"
  assert_eq "observe upgrade --check 0.9.9 不兼容 → exit 2" 2 "$R_RC"
  assert_contains "observe upgrade --check 不兼容提示 min 1.0.3" "$R_OUT" "1.0.3"

  # ⑪ --mapping fail-closed（缺键 / mapping_version≠1 / 文件不存在）+ 正向控制
  T=$(new_case); SK=$(stage_skill "$T"); make_audit_case "$T" 3; MAP="$T/map-broken.yaml"
  printf 'mapping_version: 1\n' > "$MAP"
  run_cli_env "$T" STUB_RC_CHECK_DECL=0 observe audit --skill-dir "$SK" --mapping "$MAP"
  assert_eq "observe --mapping 缺必需键 → exit 2（fail-closed）" 2 "$R_RC"
  assert_contains "observe --mapping 缺键时报出缺失键名" "$R_OUT" "contract_version_min"
  MAP="$T/map-v2.yaml"
  write_mapping_full "$T/map-base.tmp"
  { printf 'mapping_version: 2\n'; grep -v '^mapping_version:' "$T/map-base.tmp"; } > "$MAP"
  rm -f "$T/map-base.tmp"
  run_cli "$T" observe audit --skill-dir "$SK" --mapping "$MAP"
  assert_eq "observe --mapping mapping_version: 2 → exit 2" 2 "$R_RC"
  run_cli "$T" observe audit --skill-dir "$SK" --mapping "$T/没有这个映射文件.yaml"
  assert_eq "observe --mapping 文件不存在 → exit 2" 2 "$R_RC"
  MAP="$T/map-full.yaml"; write_mapping_full "$MAP"
  run_cli_env "$T" STUB_RC_CHECK_DECL=0 STUB_RC_AUDIT_DIFF=0 \
    observe audit --skill-dir "$SK" --mapping "$MAP" --level ob1
  assert_eq "observe --mapping 完整块可用（正向控制，非一律拒绝）→ exit 0" 0 "$R_RC"
  run_cli_env "$T" PONYGO_OBSERVE_MAPPING="$MAP" STUB_RC_CHECK_DECL=0 STUB_RC_AUDIT_DIFF=0 \
    observe audit --skill-dir "$SK" --level ob1
  assert_eq "observe PONYGO_OBSERVE_MAPPING env 同效 → exit 0" 0 "$R_RC"

  # ⑫ --json 也零写
  T=$(new_case); SK=$(stage_skill "$T"); make_audit_case "$T" 3; add_mount_carrier "$T"
  SNAP0=$(snap "$T")
  run_cli_stdout_env "$T" STUB_RC_CHECK_DECL=0 STUB_RC_AUDIT_DIFF=0 \
    observe audit --skill-dir "$SK" --json
  assert_same_tree "observe audit --json 零写（文件树快照不变）" "$T" "$SNAP0"

  # ⑬ A8 默认分支正向（B12）：不带 --skill-dir，skill 在 $HOME/<skill_dir_rel> 下 ⇒ 走判定路径
  T=$(new_case); make_audit_case "$T" 3
  mkdir -p "$T/home/.agents/skills/observability-onboarding"
  cp -R "$OBS_STUB/." "$T/home/.agents/skills/observability-onboarding/"
  run_cli_stdout_env "$T" HOME="$T/home" STUB_RC_CHECK_DECL=2 observe audit --json
  assert_eq "observe[A8] 假 HOME 默认 skill 路径：skill rc=2 → exit 1（ob0 达/ob1 未达）" 1 "$STD_RC"
  assert_contains "observe[A8] 默认分支 skill.present=true（未走缺 skill 分支）" "$STD_OUT" \
    '"present":true'
  assert_contains "observe[A8] 默认分支 contract_version 取自 references/contract.json" "$STD_OUT" \
    '"contract_version":"1.0.3"'
  assert_contains "observe[A8] 默认分支 current=ob0（真走了判定）" "$STD_OUT" '"current":"ob0"'
  assert_not_contains "observe[A8] 默认分支 stdout 不得含「安装」类缺 skill 提示" "$STD_OUT" "安装"
  #    负向：空 HOME（无 skill）⇒ rc=2 且给安装提示（不猜、不降级）
  T=$(new_case); make_audit_case "$T" 3
  mkdir -p "$T/emptyhome"
  run_cli_env "$T" HOME="$T/emptyhome" observe audit
  assert_eq "observe[A8] 空 HOME 无 skill → exit 2（缺 skill，非「未达标」）" 2 "$R_RC"
  assert_contains "observe[A8] 空 HOME 给安装提示" "$R_OUT" "安装"
}


s37_observe_regress() {
  echo "--- 场景37：第三轮审核回归钉（F1 YAML 注入 / F2 TMPDIR 哨兵 / F3 SIGTERM 残留 / F5 --level 只属 audit / F6 顶层路由 / F7 版本净化）"
  local T SK SNAP0 BG N FIRST RC

  # ① F5：--level obN 的判定目标档只属 'observe audit'（status/init/upgrade 一律显式拒绝，不静默忽略）
  T=$(new_case); SK=$(stage_skill "$T"); make_audit_case "$T" 3
  run_cli "$T" observe status --level ob1 --skill-dir "$SK"
  assert_eq "observe[F5] status --level ob1 → exit 1（不静默忽略）" 1 "$R_RC"
  assert_contains "observe[F5] status --level 文案含「只属 audit」" "$R_OUT" "只属 audit"
  SNAP0=$(snap "$T")
  run_cli "$T" observe init --kind cli --level ob1 --dry-run --skill-dir "$SK"
  assert_eq "observe[F5] init --level ob1 → exit 1（不静默忽略）" 1 "$R_RC"
  assert_same_tree "observe[F5] init --level ob1 被拒零写（文件树快照不变）" "$T" "$SNAP0"
  run_cli "$T" observe upgrade --level ob1 --skill-dir "$SK"
  assert_eq "observe[F5] upgrade --level ob1 → exit 1" 1 "$R_RC"
  assert_contains "observe[F5] upgrade --level 文案含「只属 audit」" "$R_OUT" "只属 audit"

  # ② F1：--reason-<dim> / --anchor-<dim> 的 YAML 标量注入（写盘前拦截，且绝不落盘）
  T=$(new_case); SK=$(stage_skill "$T"); SNAP0=$(snap "$T")
  run_cli "$T" observe init --kind cli --skill-dir "$SK" \
    --dims metrics --reason-tracing $'x\n  metrics:\n    applicable: false'
  assert_eq "observe[F1] --reason-tracing 含换行（YAML 注入）→ exit 2" 2 "$R_RC"
  assert_same_tree "observe[F1] 注入被拒后不落盘（文件树快照不变）" "$T" "$SNAP0"
  assert_eq "observe[F1] 注入被拒后无声明文件" "no" \
    "$([ -f "$T/docs/observability.yaml" ] && echo yes || echo no)"
  run_cli "$T" observe init --kind cli --skill-dir "$SK" --anchor-metrics 'src/a: b.ts'
  assert_eq "observe[F1] --anchor-metrics 含「: 」（会读成第二个键）→ exit 2" 2 "$R_RC"
  assert_same_tree "observe[F1] anchor 注入被拒后仍不落盘" "$T" "$SNAP0"

  # ③ F6：顶层路由滥用 'ponygo init observe init ...' 不得改跑 observe（也不得写盘）
  T=$(new_case); SNAP0=$(snap "$T")
  run_cli "$T" init observe init --kind cli
  assert_eq "observe[F6] ponygo init observe ... → exit 1（子命令位置非法）" 1 "$R_RC"
  assert_contains "observe[F6] 报子命令位置非法" "$R_OUT" "子命令位置非法"
  assert_same_tree "observe[F6] 路由滥用零写（文件树快照不变）" "$T" "$SNAP0"

  # ④ F2：TMPDIR 不可写 → 工具错误 rc=2 + gaps tool_error（绝不误标 declaration_inconsistent、绝不 exit 0）
  T=$(new_case); SK=$(stage_skill "$T"); make_audit_case "$T" 3
  run_cli_stdout_env "$T" TMPDIR=/nonexistent-dir-ponygo observe audit --skill-dir "$SK" --json
  assert_eq "observe[F2] TMPDIR 不可写 → exit 2（工具错误，非「声明不一致」）" 2 "$STD_RC"
  assert_contains "observe[F2] TMPDIR 不可写 gaps 含 tool_error" "$STD_OUT" '"gaps":["tool_error"]'
  assert_not_contains "observe[F2] 不得误标 declaration_inconsistent" "$STD_OUT" \
    "declaration_inconsistent"
  assert_contains "observe[F2] current=unknown（本次判定不可信）" "$STD_OUT" '"current":"unknown"'

  # ⑤ F3：SIGTERM 打断执行中的 skill → 临时文件不得残留（$TMPDIR 无 ponygo-obs.*）
  T=$(new_case); SK=$(stage_skill "$T"); make_audit_case "$T" 3
  mkdir -p "$T/tmpd"
  ( cd "$T" && exec env TMPDIR="$T/tmpd" STUB_SLEEP=2 bash "$ROOT/ponygo" \
      observe audit --skill-dir "$SK" ) >/dev/null 2>&1 &
  BG=$!
  # 条件轮询（禁盲等）：先证明临时文件真的被创建——否则「无残留」是空断言
  N=0; FIRST=0
  while [ "$N" -lt 5 ]; do
    FIRST=$(ls "$T/tmpd" 2>/dev/null | grep -c '^ponygo-obs\.')
    [ "$FIRST" -gt 0 ] && break
    sleep 1; N=$((N + 1))
  done
  assert_eq "observe[F3] 运行期确有 ponygo-obs.* 临时文件（前提取证）" 1 "$FIRST"
  kill -TERM "$BG" 2>/dev/null
  wait "$BG" 2>/dev/null; RC=$?
  assert_eq "observe[F3] TERM 后按信号语义退出（143，信号不得被吞）" 143 "$RC"
  assert_eq "observe[F3] TERM 后 TMPDIR 无 ponygo-obs.* 残留" 0 \
    "$(ls "$T/tmpd" 2>/dev/null | grep -c '^ponygo-obs\.')"

  # ⑥ F7：contract_version 非法 → --json 净化为 unknown 且 compatible=false（绝不产出非法 JSON）
  T=$(new_case); SK=$(stage_skill "$T" "1.0.x"); make_audit_case "$T" 3
  run_cli_stdout_env "$T" STUB_RC_CHECK_DECL=0 observe audit --skill-dir "$SK" --json
  assert_contains "observe[F7] 非法 contract_version 净化为 unknown" "$STD_OUT" \
    '"contract_version":"unknown"'
  assert_contains "observe[F7] 非法 contract_version → compatible=false" "$STD_OUT" '"compatible":false'
  run_cli "$T" observe upgrade --check --skill-dir "$SK"
  assert_eq "observe[F7] upgrade --check 遇非法版本 → exit 2" 2 "$R_RC"

  # ⑦ strict 模式：目标级已达但仍有缺口时，默认 exit 0，加 --strict 强制 exit 1
  T=$(new_case); SK=$(stage_skill "$T"); make_audit_case "$T" 0
  run_cli "$T" observe audit --skill-dir "$SK"
  assert_eq "observe[strict] 默认体检模式当前级 ob0 >= 目标级 ob0 → exit 0" 0 "$R_RC"
  run_cli "$T" observe audit --skill-dir "$SK" --strict
  assert_eq "observe[strict] --strict 下存在缺口强制 exit 1" 1 "$R_RC"
  assert_contains "observe[strict] 人读模式提示 strict" "$R_OUT" "[strict]"
  run_cli "$T" observe status --strict
  assert_eq "observe[strict] status --strict 报错拒收" 1 "$R_RC"
  assert_contains "observe[strict] status --strict 文案提示仅适用于 audit" "$R_OUT" "仅适用于 'ponygo observe audit'"
}

s38_observe_frontend_and_pipeline() {
  echo "--- 场景38：frontend 与 pipeline 新形态（init/status/audit 闭环）"
  local T SK TXT

  # 1. observe init --kind frontend 成功落地
  T=$(new_case); SK=$(stage_skill "$T")
  run_cli "$T" observe init --kind frontend --skill-dir "$SK"
  assert_eq "observe init --kind frontend exit 0" 0 "$R_RC"
  TXT=$(cat "$T/docs/observability.yaml" 2>/dev/null || true)
  assert_contains "frontend 声明含 kind: frontend" "$TXT" "kind: frontend"

  # 2. observe init --kind pipeline 成功落地
  T=$(new_case); SK=$(stage_skill "$T")
  run_cli "$T" observe init --kind pipeline --skill-dir "$SK"
  assert_eq "observe init --kind pipeline exit 0" 0 "$R_RC"
  TXT=$(cat "$T/docs/observability.yaml" 2>/dev/null || true)
  assert_contains "pipeline 声明含 kind: pipeline" "$TXT" "kind: pipeline"

  # 3. status 与 audit --json 正确解析 declared_kind
  run_cli_stdout_env "$T" STUB_RC_CHECK_DECL=2 observe audit --skill-dir "$SK" --json
  assert_contains "audit --json declared_kind 为 pipeline" "$STD_OUT" '"declared_kind":"pipeline"'
}

s39_observe_feedback_upgrades() {
  echo "--- 场景39：真实反馈4项升级（dry-run 覆盖放行/status 形态建议/收口点状态透出）"
  local T SK TXT

  # 1. 已有声明时，--dry-run（无 --force）不应 exit 2，必须 exit 0 且零写
  T=$(new_case); SK=$(stage_skill "$T")
  run_cli "$T" observe init --kind cli --skill-dir "$SK"
  assert_eq "observe init 首次落地 exit 0" 0 "$R_RC"
  local SNAP_BEFORE
  SNAP_BEFORE=$(snap "$T")
  run_cli "$T" observe init --kind frontend --skill-dir "$SK" --dry-run
  assert_eq "已有声明时 init --dry-run（无 --force）exit 0" 0 "$R_RC"
  assert_same_tree "已有声明时 init --dry-run 零写" "$T" "$SNAP_BEFORE"
  assert_contains "已有声明时 init --dry-run 提示加 --force" "$R_OUT" "force"

  # 2. status 缺声明时按特征文件提供形态建议
  T=$(new_case); SK=$(stage_skill "$T")
  touch "$T/tauri.conf.json"
  run_cli "$T" observe status --skill-dir "$SK"
  assert_contains "status 检测到 tauri 给出 desktop 建议" "$R_OUT" "desktop"

  T=$(new_case); SK=$(stage_skill "$T")
  echo '{"name":"my-ui"}' > "$T/package.json"
  run_cli "$T" observe status --skill-dir "$SK"
  assert_contains "status 检测到 package.json 给出 frontend 建议" "$R_OUT" "frontend"

  # 3. status 透出收口点状态 (enforcement_points)
  T=$(new_case); SK=$(stage_skill "$T")
  run_cli "$T" observe init --kind cli --skill-dir "$SK"
  run_cli "$T" observe status --skill-dir "$SK"
  assert_contains "status 提示收口点未配置" "$R_OUT" "收口点"
}

s40_observe_audit_clarity() {
  echo "--- 场景40：audit 输出明晰度（结论行提示/待办区分/收口点推荐指引）"
  local T SK

  # 1. status 提示收口点未配置时包含标准推荐项提示
  T=$(new_case); SK=$(stage_skill "$T")
  run_cli "$T" observe init --kind cli --skill-dir "$SK"
  run_cli "$T" observe status --skill-dir "$SK"
  assert_contains "status 包含收口点推荐项 http_client" "$R_OUT" "http_client"
  assert_contains "status 包含收口点推荐项 error_boundary" "$R_OUT" "error_boundary"

  # 2. audit 达成目标级（如 --level ob1 达成）时打印清晰结论行 PASS
  make_audit_case "$T" 1
  run_cli_env "$T" STUB_RC_CHECK_DECL=0 STUB_RC_AUDIT_DIFF=1 observe audit --level ob1 --skill-dir "$SK"
  assert_eq "audit --level ob1 达成 exit 0" 0 "$R_RC"
  assert_contains "audit 达成打印明确结论行 PASS" "$R_OUT" "结论: PASS"
  assert_contains "audit 打印明确已达目标级提示" "$R_OUT" "已达目标级"
  assert_contains "audit 将后续缺口标记为下一级待办" "$R_OUT" "下一级待办"
}

s41_observe_smart_inheritance_and_examples() {
  echo "--- 场景41：智能继承、收口点明细与帮助示例（force 继承/status 回显/examples）"
  local T SK TXT

  # 1. 帮助信息包含实战示例 Examples
  T=$(new_case)
  run_cli "$T" observe --help
  assert_contains "observe --help 包含示例段" "$R_OUT" "示例："

  # 2. observe init --force 智能继承原声明中的非占位内容
  SK=$(stage_skill "$T")
  mkdir -p "$T/src" && touch "$T/src/trace.ts" "$T/src/err.ts"
  run_cli "$T" observe init --kind desktop --service my-app --skill-dir "$SK" \
    --dims tracing,issues --anchor-tracing src/trace.ts --anchor-issues src/err.ts \
    --reason-metrics "桌面端无端口" --reason-logs "本地单行日志"
  TXT=$(cat "$T/docs/observability.yaml" 2>/dev/null || true)
  assert_contains "初始声明含真实 reason-metrics" "$TXT" "桌面端无端口"

  # 二次运行 init --force，只改 service，不传 reason-metrics，原有的结构性理由必须被继承，不得被抹为 __REPLACE_ME__
  run_cli "$T" observe init --kind desktop --service new-app --dims tracing,issues --skill-dir "$SK" --force
  TXT=$(cat "$T/docs/observability.yaml" 2>/dev/null || true)
  assert_contains "二次 force 后 service 更新" "$TXT" "service: new-app"
  assert_contains "二次 force 智能继承了原有的 reason-metrics" "$TXT" "桌面端无端口"
  assert_not_contains "二次 force 不得将原有 reason 抹为占位符" "$TXT" "__REPLACE_ME__"

  # 3. status 回显具体收口点名称及目标路径
  cat << 'EOF' >> "$T/docs/observability.yaml"

enforcement_points:
  error_boundary:
    path: src/main.ts
EOF
  run_cli "$T" observe status --skill-dir "$SK"
  assert_contains "status 回显收口点 error_boundary 规则名" "$R_OUT" "error_boundary"
  assert_contains "status 回显收口点目标路径 src/main.ts" "$R_OUT" "src/main.ts"
}

s42_observe_monorepo_subcomponents() {
  echo "--- 场景42：Monorepo 多组件感知（子目录独立前端/未纳管感知）"
  local T SK

  T=$(new_case); SK=$(stage_skill "$T")
  # 根目录初始化为 k8s-service
  run_cli "$T" observe init --kind k8s-service --service api-svc --skill-dir "$SK"
  assert_eq "根目录 init k8s-service exit 0" 0 "$R_RC"

  # 创建未纳管的前端子目录 front_end
  mkdir -p "$T/front_end"
  echo '{"name":"my-frontend"}' > "$T/front_end/package.json"

  # 在根目录运行 observe status，应探测到未纳管的前端工程并发出强警示与待办
  run_cli "$T" observe status --skill-dir "$SK"
  assert_contains "status 输出包含 WARN 警示" "$R_OUT" "[WARN]"
  assert_contains "status 输出包含未纳管子组件待办格式" "$R_OUT" "未纳管子组件待办（Monorepo 架构治理）："
  assert_contains "status 指出未纳管前端目录 - [ ] front_end/" "$R_OUT" "- [ ] front_end/"

  # status --json 的 gaps 列表应包含 unmanaged_subcomponents
  run_cli_stdout "$T" observe status --skill-dir "$SK" --json
  assert_contains "status --json gaps 包含 unmanaged_subcomponents" "$STD_OUT" "unmanaged_subcomponents"

  # 在子目录落地声明后，根目录不再报警该子组件
  mkdir -p "$T/front_end/docs"
  echo "service: web-svc" > "$T/front_end/docs/observability.yaml"
  echo "kind: frontend" >> "$T/front_end/docs/observability.yaml"
  run_cli "$T" observe status --skill-dir "$SK"
  assert_not_contains "子目录已纳管后根目录不再报警" "$R_OUT" "front_end"
  assert_not_contains "子目录已纳管后不再输出 WARN" "$R_OUT" "[WARN]"
}

s43_observe_pipeline_awareness() {
  echo "--- 场景43：CI/CD 流水线工程资产感知（pipeline 探测与指引）"
  local T SK

  T=$(new_case); SK=$(stage_skill "$T")
  # 根目录初始化为 k8s-service
  run_cli "$T" observe init --kind k8s-service --service my-svc --skill-dir "$SK"
  assert_eq "根目录 init k8s-service exit 0" 0 "$R_RC"

  # 创建 CI/CD 流水线资产文件
  mkdir -p "$T/.github/workflows"
  touch "$T/.github/workflows/ci.yml" "$T/.github/workflows/deploy.yml"

  # 在根目录运行 observe status，应探测到 CI/CD 流水线资产
  run_cli "$T" observe status --skill-dir "$SK"
  assert_contains "status 提示 CI/CD 流水线工程资产" "$R_OUT" "CI/CD 流水线工程资产"
  assert_contains "status 列出 workflows 数量或路径" "$R_OUT" ".github/workflows"
  assert_contains "status 给出 pipeline 治理命令建议" "$R_OUT" "kind pipeline"
}
s28_l2_reachability
s29_doc_level_parity
s30_release_chain
s31_upgrade_drift
s32_task004_static
s33_observe_stub
s34_observe_init
s35_observe_audit
s36_observe_json
s37_observe_regress
s38_observe_frontend_and_pipeline
s39_observe_feedback_upgrades
s40_observe_audit_clarity
s41_observe_smart_inheritance_and_examples
s44_observe_subcomponent_blocking() {
  echo "--- 场景44：子组件不一致的阻断语义（默认 backlog / --strict 阻断 / 结论行说实话）"
  local T SK
  T=$(new_case)
  # 自造 skill：根声明 rc=0，子组件声明 rc=2 —— 用来验证「同一判定里两种 rc 并存」时的退出码语义。
  SK="$T/skill"; mkdir -p "$SK/references" "$SK/scripts"
  printf '{"contract_version":"1.2.0"}\n' > "$SK/references/contract.json"
  cat > "$SK/scripts/check-declaration.sh" <<'SH'
#!/bin/bash
for a in "$@"; do case "$a" in */front_end) exit 2 ;; esac; done
exit 0
SH
  printf '#!/bin/bash\nexit 0\n' > "$SK/scripts/audit-diff.sh"
  chmod +x "$SK/scripts/"*.sh
  # 主声明（无占位符 ⇒ ob0 成立）+ 子组件声明（触发 rc=2）
  mkdir -p "$T/docs" "$T/front_end/docs"
  printf 'service: root-svc\nkind: k8s-service\ndimensions:\n  metrics: {applicable: false, reason: "x"}\n  tracing: {applicable: false, reason: "x"}\n  logs: {applicable: false, reason: "x"}\n  issues: {applicable: false, reason: "x"}\nreviewed_at: "2026-10-26"\n' > "$T/docs/observability.yaml"
  printf 'service: fe\nkind: frontend\nreviewed_at: "2026-10-26"\n' > "$T/front_end/docs/observability.yaml"
  # 挂载载体（含**非注释**的真调用行）：让 ob2 成立，从而 ids 只剩「子组件」这一类缺口，
  # ④ 的「不误阻断」才是在验 --strict 本身而不是被 mount_missing 顶掉。
  mkdir -p "$T/.github/workflows"
  printf 'jobs:\n  gate:\n    steps:\n      - run: bash scripts/audit-diff.sh --repo . --base origin/main\n' \
    > "$T/.github/workflows/ci.yml"

  # ① 默认（体检模式）：子组件缺口只进 backlog，不改变退出码
  run_cli "$T" observe audit --level ob0 --skill-dir "$SK"
  assert_eq "子组件不一致：默认不阻断（exit 0）" 0 "$R_RC"
  assert_contains "子组件不一致：报告可见（子组件声明巡检）" "$R_OUT" "子组件声明巡检"
  assert_contains "子组件不一致：缺口入 backlog" "$R_OUT" "subcomponent_inconsistent"

  # ② --strict：任一缺口即阻断（这是「全仓一票否决」的既有开关，无需新增 --scope）
  run_cli "$T" observe audit --level ob0 --strict --skill-dir "$SK"
  assert_eq "子组件不一致 + --strict：阻断（exit 1）" 1 "$R_RC"

  # ③ 结论行必须说实话：已达标时不得打成「未达目标级」（旧缺陷）
  assert_contains "strict 阻断时结论行承认已达目标级" "$R_OUT" "已达目标级"
  assert_contains "strict 阻断时结论行点明是 --strict 导致" "$R_OUT" "--strict"

  # ④ 反例保护：子组件一致时 --strict 不得误阻断
  printf '#!/bin/bash\nexit 0\n' > "$SK/scripts/check-declaration.sh"; chmod +x "$SK/scripts/check-declaration.sh"
  run_cli "$T" observe audit --level ob0 --strict --skill-dir "$SK"
  assert_eq "子组件一致 + --strict：不误阻断（exit 0）" 0 "$R_RC"
  assert_not_contains "子组件一致：无 subcomponent 缺口" "$R_OUT" "subcomponent_inconsistent"
}

# 场景45（R4 可观测性审查 P0-1 红相）：ob2 的 audit-diff 超时预算。
# 缺陷背景：audit-diff 曾用 local_timeout_seconds（3s），而真实 job_copilot 大仓实测 11.6s
# （636 变更文件 / 1495617 行新增）⇒ timeout 杀进程 rc=124 ⇒ 落入 rc 白名单外 ⇒ gaps=tool_error
# ⇒ ob2 **恒 FAIL**，真违规与工具超时不可辨（假红淹没真红）。
# 契约：
#   CT-1 audit-diff 使用独立预算 diff_timeout_seconds（缺省 ≥60s），不得复用 local_timeout_seconds；
#   CT-2 允许环境变量 PONYGO_OBS_DIFF_TIMEOUT 覆盖（正整数；非法值忽略并告警）；
#   CT-3 超时（rc=124/143）必须 fail-closed（exit 2）且诊断文本点名「超时」+ audit-diff；
#   CT-4 rc=2 真违规语义不变（enforcement_violation），不得被超时路径吞掉；
#   CT-5 快路径（rc=0 + 载体）零回归。
s45_observe_diff_timeout_budget() {
  echo "--- 场景45：ob2 audit-diff 超时预算（慢仓不再被 3s 杀掉 / 超时与违规可辨）"
  local T SK

  # ① CT-1/CT-4：慢 4s 的 audit-diff 必须跑到完成，并按真实 rc=2 判违规
  T=$(new_case); SK=$(stage_skill "$T"); make_audit_case "$T" 3; add_mount_carrier "$T"
  run_cli_env "$T" STUB_RC_CHECK_DECL=0 STUB_RC_AUDIT_DIFF=2 STUB_SLEEP_AUDIT_DIFF=4 \
    observe audit --skill-dir "$SK"
  assert_eq "observe[45] 慢 4s + rc=2 → ob2 未达 exit 1" 1 "$R_RC"
  assert_contains "observe[45] 慢 4s 的 audit-diff 跑到完成（stub 标记可见）" "$R_OUT" "STUB-AUDIT-DIFF rc=2"
  assert_contains "observe[45] 慢 4s + rc=2 按真违规判定" "$R_OUT" "enforcement_violation"
  assert_not_contains "observe[45] 慢 4s 不得退化为 tool_error" "$R_OUT" "tool_error"

  # ② CT-2/CT-3：显式收紧预算 → 超时路径 fail-closed 且诊断可辨（非笼统 tool_error）
  T=$(new_case); SK=$(stage_skill "$T"); make_audit_case "$T" 3; add_mount_carrier "$T"
  run_cli_env "$T" STUB_RC_CHECK_DECL=0 STUB_RC_AUDIT_DIFF=0 STUB_SLEEP_AUDIT_DIFF=3 \
    PONYGO_OBS_DIFF_TIMEOUT=1 observe audit --skill-dir "$SK"
  # 注（L3 复审标注）：本条「超时 → exit 2」在修复前亦为 ok（旧实现走通用 tool_error 分支同样 exit 2），
  # 属**回归守护**而非红相；CT-3 的鉴别力由紧随其后的两条诊断文案断言承担。
  assert_eq "observe[45] audit-diff 超时 → 判定中止 exit 2（fail-closed）" 2 "$R_RC"
  assert_contains "observe[45] 超时诊断含「超时」字样" "$R_OUT" "超时"
  assert_contains "observe[45] 超时诊断点名 audit-diff" "$R_OUT" "audit-diff"

  # ③ CT-2 负样本：非法覆盖值（0/负数/非数字）忽略并告警，退回缺省预算
  T=$(new_case); SK=$(stage_skill "$T"); make_audit_case "$T" 3; add_mount_carrier "$T"
  run_cli_env "$T" STUB_RC_CHECK_DECL=0 STUB_RC_AUDIT_DIFF=0 STUB_SLEEP_AUDIT_DIFF=4 \
    PONYGO_OBS_DIFF_TIMEOUT=abc observe audit --skill-dir "$SK"
  assert_eq "observe[45] 非法覆盖值 → 退回缺省预算，慢 4s 仍跑到完成 exit 0" 0 "$R_RC"
  assert_contains "observe[45] 非法覆盖值告警" "$R_OUT" "PONYGO_OBS_DIFF_TIMEOUT"

  # ③b CT-6（L3 审查 BLOCKING 回归）：取值校验必须 **locale 无关**。
  # 缺陷：`case "$raw" in ''|*[!0-9]*)` 在 UTF-8 locale 下对全角数字「６０」**不命中**
  # ⇒ 原样透传给 `timeout ６０` ⇒ GNU timeout 报 `invalid time interval`、rc=125
  # ⇒ 落入 rc 白名单外 ⇒ gaps=tool_error ⇒ 假红回归（正是本修复要消灭的东西）。
  # 判据：非 ASCII 数字一律判非法 → 告警 + 回落缺省预算，慢 4s 仍跑到完成。
  # 注（L3 复审标注）：紧随其后的「invalid time interval」与 ③d 的「不得断言内未跑完」两条，
  # 在修复前亦恒真（旧实现根本不把该值传给 timeout / 旧文案本无此句），属**防回退守护**；
  # 本组真正的红相是「告警出现」与「慢 4s 跑完 exit 0」两条。
  T=$(new_case); SK=$(stage_skill "$T"); make_audit_case "$T" 3; add_mount_carrier "$T"
  run_cli_env "$T" STUB_RC_CHECK_DECL=0 STUB_RC_AUDIT_DIFF=0 STUB_SLEEP_AUDIT_DIFF=4 \
    PONYGO_OBS_DIFF_TIMEOUT=６０ observe audit --skill-dir "$SK"
  assert_eq "observe[45] 全角数字覆盖值 → 判非法并回落缺省（慢 4s 跑完 exit 0）" 0 "$R_RC"
  assert_contains "observe[45] 全角数字覆盖值告警" "$R_OUT" "PONYGO_OBS_DIFF_TIMEOUT"
  assert_not_contains "observe[45] 全角数字不得落到 timeout 的 invalid time interval" "$R_OUT" \
    "invalid time interval"

  # ③c CT-6：超出可接受范围的天文数字同样判非法（否则等价于「永不超时」，破坏 fail-closed）。
  # 注：GNU timeout 接受 20 位数字（rc=0，等价不超时），故「exit 0 跑完」不能作为判据，
  # 唯一有鉴别力的是**必须告警**。
  T=$(new_case); SK=$(stage_skill "$T"); make_audit_case "$T" 3; add_mount_carrier "$T"
  run_cli_env "$T" STUB_RC_CHECK_DECL=0 STUB_RC_AUDIT_DIFF=0 STUB_SLEEP_AUDIT_DIFF=1 \
    PONYGO_OBS_DIFF_TIMEOUT=99999999999999999999 observe audit --skill-dir "$SK"
  assert_contains "observe[45] 天文数字覆盖值告警" "$R_OUT" "PONYGO_OBS_DIFF_TIMEOUT"

  # ③d CT-8：rc=143 只说明「进程死于 SIGTERM」，不等于「预算内没跑完」。
  # 瞬时返回的 143（skill 自身崩溃）不得被断言成「超时」，否则给出错误的处置建议（抬高预算）。
  T=$(new_case); SK=$(stage_skill "$T"); make_audit_case "$T" 3; add_mount_carrier "$T"
  run_cli_env "$T" STUB_RC_CHECK_DECL=0 STUB_RC_AUDIT_DIFF=143 observe audit --skill-dir "$SK"
  assert_eq "observe[45] rc=143 仍 fail-closed exit 2" 2 "$R_RC"
  assert_not_contains "observe[45] 瞬时 143 不得断言「预算内未跑完」" "$R_OUT" "内未跑完"

  # ③e CT-9：audit-diff 期间被 SIGINT 打断时，捕获用的临时文件必须被清理（否则 /tmp 泄漏）。
  # 用条件轮询等到临时文件出现再中断，避免硬 sleep 造成 flaky。
  # 隔离（L3 复审 ADVISORY A）：ponygo 的捕获文件落在 `${TMPDIR:-/tmp}`，若与同机其它 audit
  # 实例共用 /tmp，残留计数会把别人的文件算进来（本轮复审实测 6 次全量跑 3 次假红）。
  # 故本用例给被测进程注入**独立 TMPDIR**，断言只看该目录，形成进程级隔离。
  T=$(new_case); SK=$(stage_skill "$T"); make_audit_case "$T" 3; add_mount_carrier "$T"
  local lsm="$T/obstmp"
  mkdir -p "$lsm"
  ( cd "$T" && exec env TMPDIR="$lsm" STUB_RC_CHECK_DECL=0 STUB_RC_AUDIT_DIFF=0 STUB_SLEEP_AUDIT_DIFF=20 \
      bash "$ROOT/ponygo" observe audit --skill-dir "$SK" ) >/dev/null 2>&1 &
  local lp=$! lwait=0
  while [ "$lwait" -lt 100 ]; do
    ls "$lsm"/ponygo-obs-diff.* >/dev/null 2>&1 && break
    sleep 0.1; lwait=$((lwait+1))
  done
  kill -INT "$lp" 2>/dev/null
  wait "$lp" 2>/dev/null
  local lcount
  lcount=$(ls "$lsm"/ponygo-obs-diff.* 2>/dev/null | wc -l)
  assert_eq "observe[45] SIGINT 中断后 audit-diff 捕获临时文件无残留" 0 "$lcount"
  rm -f "${TMPDIR:-/tmp}"/ponygo-obs-diff.* 2>/dev/null

  # ③f CT-10：校验器自身不得 fail-open —— 判据依赖 `tr`，若 `tr` 不可用/失败（PATH 污染、
  # 裁剪镜像、被替换），旧实现会因「残渣为空」而放行非法值 ⇒ 又回到 timeout invalid interval
  # ⇒ 假红复活。空输出必须只在 `tr` 成功时才算「纯数字」。
  T=$(new_case); SK=$(stage_skill "$T"); make_audit_case "$T" 3; add_mount_carrier "$T"
  local FB="$T/fakebin"
  mkdir -p "$FB"
  printf '#!/bin/sh\nexit 3\n' > "$FB/tr"; chmod +x "$FB/tr"
  run_cli_env "$T" PATH="$FB:$PATH" STUB_RC_CHECK_DECL=0 STUB_RC_AUDIT_DIFF=0 \
    PONYGO_OBS_DIFF_TIMEOUT=abc observe audit --skill-dir "$SK"
  assert_contains "observe[45] tr 不可用时仍判非法并告警（不得 fail-open）" "$R_OUT" "PONYGO_OBS_DIFF_TIMEOUT"

  # ④ CT-5：快路径零回归
  T=$(new_case); SK=$(stage_skill "$T"); make_audit_case "$T" 3; add_mount_carrier "$T"
  run_cli_env "$T" STUB_RC_CHECK_DECL=0 STUB_RC_AUDIT_DIFF=0 observe audit --skill-dir "$SK"
  assert_eq "observe[45] 快路径 rc=0 + 载体 → 全达 exit 0" 0 "$R_RC"
}

# ============================================================
# ADR 交付门禁验收（s46~s57）—— L2-T 独立测试者冻结，实现方只读
#
# 真源：.dev-team/plan-freeze.md §2（资产契约 A1–A5）/§3+§6.6（2.4 五条 AND）/
#       §4（cmd_init 行为矩阵）/§6.1–6.5（非破坏性追加、CI 条件生成、钩子调用形态）。
# 铁律：每条断言必须是 rc / 输出子串 / 文件内容 / 文件模式（-x）之一；
#       禁「跑通即 pass」——每个反例都配正向控制，防「空==空」假绿。
# 注（Lead 终裁 T1 + wave-6 判据扩展）：判定真源是 .agents/skills/write-adr/verify-note.sh
#       （1.1–1.10）。s46~s57 的违例样本仍一律用 1.6（文件名/日期）、1.7（Status 与目录）、
#       1.8（骨架标题）三条——保持样本「只错一处」的纯粹性；其"应通过"样本已含
#       `## Alternatives considered`（1.10 自 2026-10-29 起为硬判据，见 s75–s77）。
# ============================================================

# 2.4 ④ 锚定口径（与 maturity-ladder §2.4 锚定命令逐字同款）：
# 取哨兵块区间，剔除注释行，剩下的必须含真实调用 adr-verify.sh
sentinel_noncomment() { # <hook 文件>
  sed -n '/>>> ponygo-gate: adr-verify v1 >>>/,/<<< ponygo-gate: adr-verify v1 <<</p' "$1" 2>/dev/null \
    | grep -vE '^[[:space:]]*#'
}

s46_init_gate_wiring() {
  echo "--- 场景46：init 在 git 仓内装配本地层（hooksPath/pre-commit/marker/执行位/A1·A2·A4）"
  local T; T=$(new_case)
  git_seed_repo "$T"
  run_cli "$T" init
  assert_eq "init（git 仓内）exit 0" 0 "$R_RC"
  assert_eq "core.hooksPath 设为 .githooks" ".githooks" "$(hookspath_of "$T")"
  assert_exists "生成 .githooks/pre-commit" "$T/.githooks/pre-commit"
  assert_exec ".githooks/pre-commit 可执行（R3：非可执行钩子被 git 静默忽略）" "$T/.githooks/pre-commit"
  assert_file_has "含 marker 行 # ponygo-gate: adr-verify v1" "$T/.githooks/pre-commit" \
    "# ponygo-gate: adr-verify v1"
  assert_file_has "含哨兵尾行（2.4 ④）" "$T/.githooks/pre-commit" "$GATE_MARKER_END"
  assert_contains "哨兵块内有非注释行调用 adr-verify.sh（2.4 ④）" \
    "$(sentinel_noncomment "$T/.githooks/pre-commit")" "adr-verify.sh"
  assert_exists "A1 .meta/gates/adr-verify.sh 落地" "$T/.meta/gates/adr-verify.sh"
  assert_exists "A2 .meta/gates/adr-verify.spec.sh 落地" "$T/.meta/gates/adr-verify.spec.sh"
  assert_exists "A4 .meta/gates/ci-verify.sh 恒生成（§6.3）" "$T/.meta/gates/ci-verify.sh"
  # 非 git 目录（R14）：不设 hooksPath、不静默、仍 exit 0
  T=$(new_case)
  run_cli "$T" init
  assert_eq "非 git 目录 init 仍 exit 0（R14）" 0 "$R_RC"
  assert_eq "非 git 目录不设 core.hooksPath（R14）" "" "$(hookspath_of "$T")"
  assert_contains "非 git 目录打印 git init 指引（R14 不静默）" "$R_OUT" "git init"
}

s47_adr_verify_semantics() {
  echo "--- 场景47：A1 语义（合法放行 / 1.6·1.7·1.8 违例拒绝 / 无 ADR 变更放行）+ A2 自检"
  local T; T=$(new_case)
  git_seed_repo "$T"
  run_cli "$T" init
  assert_exists "A1 已由 init 生成" "$T/.meta/gates/adr-verify.sh"

  # ① 无 ADR 变更（只暂存非-notes 文件）→ exit 0
  printf '# tweak\n' >> "$T/README.md"
  git_local "$T" add README.md >/dev/null 2>&1
  run_script "$T" .meta/gates/adr-verify.sh
  assert_eq "A1 无 ADR 变更（只暂存非-notes 文件）→ exit 0" 0 "$S_RC"

  # ② 合法 ADR 暂存 → exit 0
  git_local "$T" reset -q >/dev/null 2>&1
  write_valid_decision "$T" "implemented/feature/2026-01-02-good.md"
  git_local "$T" add .agents/notes/implemented/feature/2026-01-02-good.md >/dev/null 2>&1
  run_script "$T" .meta/gates/adr-verify.sh
  assert_eq "A1 合法 ADR 暂存 → exit 0" 0 "$S_RC"

  # ③ 1.7 违例：implemented/ 下 Status: proposed → 非零
  git_local "$T" reset -q >/dev/null 2>&1
  mkdir -p "$T/.agents/notes/implemented/feature"
  cat > "$T/.agents/notes/implemented/feature/2026-01-03-status.md" <<'EOF'
# Agent Note: status mismatch

Status: proposed

## Problem
why

## Decision
what

## Alternatives considered
other
EOF
  git_local "$T" add .agents/notes/implemented/feature/2026-01-03-status.md >/dev/null 2>&1
  run_script "$T" .meta/gates/adr-verify.sh
  assert_nonzero "A1 1.7 违例（Status 与目录不一致）暂存 → 非零" "$S_RC"
  assert_contains "A1 1.7 违例报出判据号" "$S_OUT" "1.7"

  # ④ 1.8 违例：implemented/ 下含 ## Proposal 标题 → 非零
  git_local "$T" reset -q >/dev/null 2>&1
  cat > "$T/.agents/notes/implemented/feature/2026-01-04-proposal.md" <<'EOF'
# Agent Note: proposal-era heading

Status: implemented

## Problem
why

## Proposal
what

## Alternatives considered
other
EOF
  git_local "$T" add .agents/notes/implemented/feature/2026-01-04-proposal.md >/dev/null 2>&1
  run_script "$T" .meta/gates/adr-verify.sh
  assert_nonzero "A1 1.8 违例（implemented 含 ## Proposal）暂存 → 非零" "$S_RC"
  assert_contains "A1 1.8 违例报出判据号" "$S_OUT" "1.8"

  # ⑤ 1.6 违例：坏文件名 → 非零
  git_local "$T" reset -q >/dev/null 2>&1
  cat > "$T/.agents/notes/implemented/feature/badname.md" <<'EOF'
# Agent Note: bad filename

Status: implemented

## Problem
why

## Decision
what

## Alternatives considered
other
EOF
  git_local "$T" add .agents/notes/implemented/feature/badname.md >/dev/null 2>&1
  run_script "$T" .meta/gates/adr-verify.sh
  assert_nonzero "A1 1.6 违例（文件名不符 yyyy-mm-dd-topic.md）暂存 → 非零" "$S_RC"
  assert_contains "A1 1.6 违例报出判据号" "$S_OUT" "1.6"

  # ⑥ 1.6 违例（非法日期）；仅 GNU date 环境机械可判（同 verify-note DATE_OK 降级，如实披露）
  if date -d @0 '+%Y' >/dev/null 2>&1; then
    git_local "$T" reset -q >/dev/null 2>&1
    cat > "$T/.agents/notes/implemented/feature/2026-02-30-baddate.md" <<'EOF'
# Agent Note: bad date

Status: implemented

## Problem
why

## Decision
what

## Alternatives considered
other
EOF
    git_local "$T" add .agents/notes/implemented/feature/2026-02-30-baddate.md >/dev/null 2>&1
    run_script "$T" .meta/gates/adr-verify.sh
    assert_nonzero "A1 1.6 违例（非法日期 2026-02-30）暂存 → 非零" "$S_RC"
  else
    ok "无 GNU date：坏日期用例降级跳过（verify-note 同款诚实条款，靠 review）"
  fi

  # ⑦ A2 负样本自检 exit 0 = 「门确实会拒绝非法样本，且会放行合法样本」
  run_script "$T" .meta/gates/adr-verify.spec.sh
  assert_eq "A2 adr-verify.spec.sh 自检 exit 0" 0 "$S_RC"
}

s48_adr_verify_toctou() {
  echo "--- 场景48：A1 TOCTOU（index 内非法、工作区已改回合法 → 必须非零，R6）"
  local T P; T=$(new_case); P=".agents/notes/implemented/feature/2026-01-05-toctou.md"
  git_seed_repo "$T"; run_cli "$T" init
  mkdir -p "$T/$(dirname "$P")"
  cat > "$T/$P" <<'EOF'
# Agent Note: staged is invalid

Status: proposed

## Problem
why

## Decision
what

## Alternatives considered
other
EOF
  git_local "$T" add "$P" >/dev/null 2>&1
  # 工作区改回合法、故意不再 git add：index 仍留非法字节
  cat > "$T/$P" <<'EOF'
# Agent Note: staged is invalid

Status: implemented

## Problem
why

## Decision
what

## Alternatives considered
other
EOF
  assert_contains "前提取证：index 与工作区确已分叉" "$(git_local "$T" diff --name-only)" \
    "2026-01-05-toctou.md"
  run_script "$T" .meta/gates/adr-verify.sh
  assert_nonzero "A1 index 非法 + 工作区合法 → 非零（R6 fail-closed）" "$S_RC"
  assert_contains "A1 拒绝文案含「未暂存」补救" "$S_OUT" "未暂存"
  # 补齐 git add 后放行（证明上面非零不是「一律非零」）
  git_local "$T" add "$P" >/dev/null 2>&1
  run_script "$T" .meta/gates/adr-verify.sh
  assert_eq "A1 补齐暂存（index=合法）→ exit 0" 0 "$S_RC"
}

s49_adr_verify_rename() {
  echo "--- 场景49：rename 逃逸（git mv 非法 ADR 进 notes → 非零；合法 ADR 同路径 → 放行）"
  local T V; T=$(new_case)
  git_seed_repo "$T"; run_cli "$T" init
  mkdir -p "$T/inbox"
  cat > "$T/inbox/2026-01-06-renamed-invalid.md" <<'EOF'
# Agent Note: renamed with status mismatch

Status: proposed

## Problem
why

## Decision
what

## Alternatives considered
other
EOF
  git_local "$T" add -A >/dev/null 2>&1
  git_local "$T" -c user.email=t@t -c user.name=t -c commit.gpgsign=false \
    commit -qm "seed inbox" --no-verify >/dev/null 2>&1
  mkdir -p "$T/.agents/notes/implemented/feature"
  git_local "$T" mv inbox/2026-01-06-renamed-invalid.md \
    .agents/notes/implemented/feature/2026-01-06-renamed-invalid.md >/dev/null 2>&1
  assert_contains "前提取证：索引内确为 rename（R）" \
    "$(git_local "$T" diff --cached --name-status --diff-filter=R)" "2026-01-06-renamed-invalid.md"
  run_script "$T" .meta/gates/adr-verify.sh
  assert_nonzero "A1 git mv 进 notes 的非法 ADR → 非零（--diff-filter=ACMR）" "$S_RC"

  # 正向控制：合法 ADR 被 mv 进 notes → 放行（证明不是「见 R 就拒」）
  V=$(new_case); git_seed_repo "$V"; run_cli "$V" init
  mkdir -p "$V/inbox"
  cat > "$V/inbox/2026-01-07-renamed-valid.md" <<'EOF'
# Agent Note: renamed valid

Status: implemented

## Problem
why

## Decision
what

## Alternatives considered
other
EOF
  git_local "$V" add -A >/dev/null 2>&1
  git_local "$V" -c user.email=t@t -c user.name=t -c commit.gpgsign=false \
    commit -qm "seed inbox" --no-verify >/dev/null 2>&1
  mkdir -p "$V/.agents/notes/implemented/feature"
  git_local "$V" mv inbox/2026-01-07-renamed-valid.md \
    .agents/notes/implemented/feature/2026-01-07-renamed-valid.md >/dev/null 2>&1
  assert_contains "前提取证：合法 ADR 的 mv 亦为 rename（R）" \
    "$(git_local "$V" diff --cached --name-status --diff-filter=R)" "2026-01-07-renamed-valid.md"
  run_script "$V" .meta/gates/adr-verify.sh
  assert_eq "A1 合法 ADR rename 进 notes → exit 0" 0 "$S_RC"
}

s50_preexisting_hook_preserved() {
  echo "--- 场景50：既有自定义 pre-commit 不被篡改（§6.1 零改写 + F1 块前置 shebang 之后）"
  local T orig bs es; T=$(new_case)
  git_seed_repo "$T"
  # 夹具按 F1 的动机场景建模：既有钩子以 exit 0 结尾（末尾追加块会被 exit 截断）
  ( cd "$T" && mkdir -p .githooks \
      && printf '#!/usr/bin/env bash\necho CUSTOM-GATE\nexit 0\n' > .githooks/pre-commit \
      && chmod +x .githooks/pre-commit ) >/dev/null 2>&1
  orig="$SBASE/hook.custom.orig"; cp "$T/.githooks/pre-commit" "$orig"
  run_cli "$T" init
  assert_eq "既有自定义钩子场景 init exit 0" 0 "$R_RC"
  assert_file_has "原自定义行仍在" "$T/.githooks/pre-commit" "echo CUSTOM-GATE"
  # 零篡改（F1 契约演进后的正确形式）：删掉哨兵区间（含边界行）后，剩余文本必须与原文件
  # 逐字节相等——既证明用户原有行零改动/顺序不变，又允许块被**前置插入**（前缀形式已不成立）。
  awk -v b="$GATE_MARKER" -v e="$GATE_MARKER_END" \
    '$0==b{skip=1} !skip{print} $0==e{skip=0}' \
    "$T/.githooks/pre-commit" > "$SBASE/hook.custom.stripped"
  if cmp -s "$SBASE/hook.custom.stripped" "$orig"; then
    ok "既有钩子零篡改：去掉哨兵区间后与原文逐字节一致（原行全在且顺序不变）"
  else
    bad "既有钩子被篡改：去掉哨兵区间后与原文不一致（违反 §6.1「永不改写既有行」）"
    diff "$orig" "$SBASE/hook.custom.stripped" | sed -n '1,6p' >&2
  fi
  # F1 位置契约：块必须在首个顶层 exit/exec 之前（否则永不执行）
  bs=$(block_begin_line "$T/.githooks/pre-commit"); es=$(first_exit_line "$T/.githooks/pre-commit")
  assert_eq "哨兵块紧接 shebang（第 2 行，F1 前置）" 2 "${bs:-缺失}"
  if [ -n "$bs" ] && [ -n "$es" ] && [ "$bs" -lt "$es" ]; then
    ok "哨兵块在首个顶层 exit/exec 之前（块 $bs 行 < exit $es 行）——不会被 exit 截断（F1）"
  else
    bad "哨兵块位置错误（块行 ${bs:-缺失} 应 < 首个顶层 exit/exec 行 ${es:-无}）——末尾追加会被 exit 截断（F1）"
  fi
  assert_file_has "追加哨兵块首行" "$T/.githooks/pre-commit" "$GATE_MARKER"
  assert_file_has "追加哨兵块尾行" "$T/.githooks/pre-commit" "$GATE_MARKER_END"
  assert_contains "追加块内有非注释调用行" "$(sentinel_noncomment "$T/.githooks/pre-commit")" "adr-verify.sh"
  assert_exec "追加后仍有执行位（§6.1：不改其权限）" "$T/.githooks/pre-commit"
  assert_eq "core.hooksPath 设为 .githooks" ".githooks" "$(hookspath_of "$T")"
  # 追加块必须被 2.4 机器识别
  printf 'level: 2\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/2026-01-02-gate.md"
  # shellcheck disable=SC2046
  run_cli_env "$T" $(sanitize_git) status
  assert_eq "追加块后 level:2 status exit 0（2.4 认块）" 0 "$R_RC"
  assert_contains "追加块后结论行 L0-L2" "$R_OUT" "L0-L2"
}

s51_husky_foreign_hookspath() {
  echo "--- 场景51：husky 式外来 hooksPath（§6.1：一律不动 hooksPath，直接对目录内 pre-commit 追加）"
  local T; T=$(new_case)
  git_seed_repo "$T"
  ( cd "$T" && git config core.hooksPath .husky && mkdir -p .husky \
      && printf '#!/usr/bin/env bash\necho HUSKY-COMMIT\n' > .husky/pre-commit \
      && chmod +x .husky/pre-commit ) >/dev/null 2>&1
  run_cli "$T" init
  assert_eq "husky 场景 init exit 0" 0 "$R_RC"
  assert_eq "外来 core.hooksPath 未被改动（§6.1 防停用 husky）" ".husky" "$(hookspath_of "$T")"
  assert_file_has "原 husky 内容保留" "$T/.husky/pre-commit" "echo HUSKY-COMMIT"
  assert_file_has "对 .husky/pre-commit 追加哨兵块首行" "$T/.husky/pre-commit" "$GATE_MARKER"
  assert_file_has "对 .husky/pre-commit 追加哨兵块尾行" "$T/.husky/pre-commit" "$GATE_MARKER_END"
  assert_contains "追加块内有非注释调用行" "$(sentinel_noncomment "$T/.husky/pre-commit")" "adr-verify.sh"
  assert_exec ".husky/pre-commit 仍有执行位" "$T/.husky/pre-commit"
  # 2.4 接线判定：level: 2 下必须 PASS（证明判据按 hooksPath 归一化目录判定，不写死 .githooks）
  printf 'level: 2\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/2026-01-02-husky.md"
  # shellcheck disable=SC2046
  run_cli_env "$T" $(sanitize_git) status
  assert_eq "husky 接线后 status exit 0（2.4 PASS）" 0 "$R_RC"
  assert_contains "husky 接线结论行 L0-L2" "$R_OUT" "L0-L2"
}

s52_init_idempotent() {
  echo "--- 场景52：已接线幂等（连续两次 init，钩子与 A1 的 md5 不变、哨兵块不重复）"
  local T h1 h2 g1 g2; T=$(new_case)
  git_seed_repo "$T"
  run_cli "$T" init
  assert_eq "首次 init exit 0" 0 "$R_RC"
  h1=$(md5_of "$T/.githooks/pre-commit"); g1=$(md5_of "$T/.meta/gates/adr-verify.sh")
  if [ "$h1" = "MISSING" ] || [ "$g1" = "MISSING" ]; then
    bad "前提取证：首次 init 未生成钩子/A1（缺 .githooks/pre-commit 或 .meta/gates/adr-verify.sh）"
  else
    ok "前提取证：首次 init 已生成钩子与 A1"
  fi
  run_cli "$T" init
  assert_eq "二次 init exit 0（has_meta 分支仍补装配，§6.2）" 0 "$R_RC"
  h2=$(md5_of "$T/.githooks/pre-commit"); g2=$(md5_of "$T/.meta/gates/adr-verify.sh")
  assert_eq "钩子文件 md5 不变（未重复追加）" "$h1" "$h2"
  assert_eq "A1 资产 md5 不变" "$g1" "$g2"
  assert_eq "哨兵尾行只出现 1 次（防「每次追加一块」冒充幂等）" 1 \
    "$(grep -cF "$GATE_MARKER_END" "$T/.githooks/pre-commit" 2>/dev/null || printf 0)"
}

s53_init_dry_run() {
  echo "--- 场景53：--dry-run 不落盘、不改 core.hooksPath（§4 矩阵）"
  local T; T=$(new_case)
  git_seed_repo "$T"
  run_cli "$T" init --dry-run
  assert_eq "git 仓内 init --dry-run exit 0" 0 "$R_RC"
  assert_missing "dry-run 未落盘（.meta 不存在）" "$T/.meta"
  assert_missing "dry-run 未生成 .githooks/pre-commit" "$T/.githooks/pre-commit"
  assert_eq "dry-run 未改 core.hooksPath" "" "$(hookspath_of "$T")"
  # 正向控制：同一目录真跑 init 必须落装配（证明上面「未落盘」不是空断言）
  run_cli "$T" init
  assert_exists "真跑 init 生成钩子（正向控制）" "$T/.githooks/pre-commit"
  assert_eq "真跑 init 设 hooksPath（正向控制）" ".githooks" "$(hookspath_of "$T")"
  # 已存在 .meta 但未接线 → --dry-run 仍只打印（R1 的 dry-run 语义）
  T=$(new_case); git_seed_repo "$T"
  run_cli "$T" init
  git_local "$T" config --unset core.hooksPath >/dev/null 2>&1
  rm -f "$T/.githooks/pre-commit"
  run_cli "$T" init --dry-run
  assert_eq "已初始化实例 --dry-run exit 0" 0 "$R_RC"
  assert_eq "已初始化实例 --dry-run 不改 hooksPath" "" "$(hookspath_of "$T")"
  assert_missing "已初始化实例 --dry-run 不生成钩子" "$T/.githooks/pre-commit"
  # 正向控制：去掉 --dry-run → has_meta 分支必须补齐（R1/§6.2）
  run_cli "$T" init
  assert_exists "has_meta 分支真跑 init 补齐钩子（R1）" "$T/.githooks/pre-commit"
  assert_eq "has_meta 分支真跑 init 设 hooksPath（R1）" ".githooks" "$(hookspath_of "$T")"
}

s54_init_non_tty_no_confirmation() {
  # wave-5 契约演进：R15（非 TTY 必须显式 --yes）随 --yes 整体删除。
  # 旧断言「非 TTY 不给 --yes → 非零 + 文案指引 --yes」与新契约互斥，故改写为正向控制：
  # 非 TTY（printf '' 关 stdin）下 init 必须一次做成，不得再问确认。
  echo "--- 场景54：非 TTY 无旗标 → init 直接落地（无交互确认，R15 已随 --yes 删除）"
  local T; T=$(new_case)
  R_OUT=$( cd "$T" && printf '' | bash "$ROOT/ponygo" init 2>&1 ); R_RC=$?
  assert_eq "printf '' | ponygo init → exit 0（无需确认）" 0 "$R_RC"
  assert_exists "非 TTY 也落盘 meta.yaml" "$T/.meta/meta.yaml"
  assert_not_contains "不再提示回车确认" "$R_OUT" "回车继续"
  assert_not_contains "不再出现已取消" "$R_OUT" "已取消"
  assert_not_contains "不再指引 --yes" "$R_OUT" "--yes"
  # 幂等正向控制：同目录二次 init 仍 exit 0（has_meta 分支）
  run_cli "$T" init
  assert_eq "同目录二次 init → exit 0（幂等）" 0 "$R_RC"
}

s55_ladder_24_strong() {
  echo "--- 场景55：2.4 强判据反证（一行注释骗不过；哨兵块内调用被注释也骗不过）"
  local T G; G=$(sanitize_git); T=$(new_case)
  git_seed_repo "$T"; run_cli "$T" init
  printf 'level: 2\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/2026-01-02-gate.md"
  # 2.1–2.3 隔离：保证 FAIL 只能归因到 2.4（否则「报 2.4」断言会被别的原因顶掉）
  printf '#!/usr/bin/env bash\nexit 0\n' > "$T/.meta/gates/format.sh"
  printf 'x\n' > "$T/.meta/gates/format.spec.md"
  git_local "$T" config core.hooksPath .githooks >/dev/null 2>&1
  mkdir -p "$T/.githooks"

  # ① 只有一行注释写 adr-verify（R5 反例）
  cat > "$T/.githooks/pre-commit" <<'EOF'
#!/usr/bin/env bash
# adr-verify：本钩子本应调用 .meta/gates/adr-verify.sh（这里只有注释）
echo hook
EOF
  chmod +x "$T/.githooks/pre-commit"
  # shellcheck disable=SC2046
  run_cli_env "$T" $G status
  assert_eq "仅注释提及 adr-verify → status exit 1（R5）" 1 "$R_RC"
  assert_contains "仅注释提及 → 报 2.4" "$R_OUT" "2.4"
  assert_contains "2.4 失败文案给出补救（重跑 ponygo init）" "$R_OUT" "ponygo init"

  # ② 哨兵块在、但块内调用行被注释掉（2.4 ④ 反例）
  cat > "$T/.githooks/pre-commit" <<'EOF'
#!/usr/bin/env bash
echo hook
# >>> ponygo-gate: adr-verify v1 >>>
# if [ -f "$(git rev-parse --show-toplevel)/.meta/gates/adr-verify.sh" ]; then
#   bash "$(git rev-parse --show-toplevel)/.meta/gates/adr-verify.sh" || exit 1
# fi
# <<< ponygo-gate: adr-verify v1 <<<
EOF
  chmod +x "$T/.githooks/pre-commit"
  # shellcheck disable=SC2046
  run_cli_env "$T" $G status
  assert_eq "哨兵块内调用被注释 → status exit 1（2.4 ④）" 1 "$R_RC"
  assert_contains "哨兵块内调用被注释 → 报 2.4" "$R_OUT" "2.4"

  # ③ 正向控制：补成真接线 → PASS（证明红来自缺非注释调用行，非其它原因）
  cat > "$T/.githooks/pre-commit" <<'EOF'
#!/usr/bin/env bash
echo hook
# >>> ponygo-gate: adr-verify v1 >>>
if [ -f "$(git rev-parse --show-toplevel)/.meta/gates/adr-verify.sh" ]; then
  bash "$(git rev-parse --show-toplevel)/.meta/gates/adr-verify.sh" || exit 1
fi
# <<< ponygo-gate: adr-verify v1 <<<
EOF
  chmod +x "$T/.githooks/pre-commit"
  # shellcheck disable=SC2046
  run_cli_env "$T" $G status
  assert_eq "真接线 → status exit 0（正向控制）" 0 "$R_RC"
  assert_contains "真接线结论行 L0-L2" "$R_OUT" "L0-L2"
}

s56_dual_write_parity() {
  echo "--- 场景56：双写一致性（init 生成的 A1/A2/A4 与仓库模板 eol 归一后逐字节一致）"
  local T a; T=$(new_case)
  git_seed_repo "$T"
  run_cli "$T" init
  assert_eq "init exit 0" 0 "$R_RC"
  for a in adr-verify.sh adr-verify.spec.sh ci-verify.sh; do
    assert_exists "生成 .meta/gates/$a" "$T/.meta/gates/$a"
    assert_same_as_template "生成 $a 与仓库模板 eol 归一后一致" \
      "$T/.meta/gates/$a" "$ROOT/.meta/gates/$a"
  done
}

s57_ci_conditional_generation() {
  echo "--- 场景57：CI 条件生成（§6.3：github 证据 → A5；无/他 provider → 不生成 + status 报远端层）"
  local T G; G=$(sanitize_git)
  # ① git remote 含 github → 生成 A5（薄壳），A4 可执行且自检 exit 0
  T=$(new_case); git_seed_repo "$T"
  git_local "$T" remote add origin https://github.com/example/demo.git >/dev/null 2>&1
  run_cli "$T" init
  assert_eq "github remote 场景 init exit 0" 0 "$R_RC"
  assert_exists "github 证据 → 生成 ponygo-governance.yml" "$T/.github/workflows/ponygo-governance.yml"
  assert_file_has "A5 是薄壳：只调 ci-verify.sh" "$T/.github/workflows/ponygo-governance.yml" "ci-verify.sh"
  assert_exists "A4 ci-verify.sh 恒生成（§6.3）" "$T/.meta/gates/ci-verify.sh"
  assert_exec "A4 ci-verify.sh 可执行" "$T/.meta/gates/ci-verify.sh"
  run_script "$T" .meta/gates/ci-verify.sh
  assert_eq "A4 ci-verify.sh 在本仓实跑 exit 0" 0 "$S_RC"
  # ② 预置 .github/ 同样视为 github 证据
  T=$(new_case); git_seed_repo "$T"; mkdir -p "$T/.github/workflows"
  run_cli "$T" init
  assert_exists "预置 .github/ → 生成 A5" "$T/.github/workflows/ponygo-governance.yml"
  # ③ 无任何 provider → 不生成 A5，A4 仍生成，status 报「远端层」缺口
  T=$(new_case); git_seed_repo "$T"
  run_cli "$T" init
  assert_missing "无 provider → 不生成 A5" "$T/.github/workflows/ponygo-governance.yml"
  assert_exists "无 provider 时 A4 仍生成（门禁本体恒在）" "$T/.meta/gates/ci-verify.sh"
  # shellcheck disable=SC2046
  run_cli_env "$T" $G status
  assert_contains "status 报「远端层」缺口行" "$R_OUT" "远端层"
  # ④ 非 GitHub 但检出其它 provider（gitlab）→ 不生成 A5，status 给可执行指引
  T=$(new_case); git_seed_repo "$T"; printf 'stages: [test]\n' > "$T/.gitlab-ci.yml"
  run_cli "$T" init
  assert_missing "gitlab 项目 → 不生成 A5" "$T/.github/workflows/ponygo-governance.yml"
  # shellcheck disable=SC2046
  run_cli_env "$T" $G status
  assert_contains "gitlab 项目 status 报远端层" "$R_OUT" "远端层"
  assert_contains "gitlab 项目 status 给出 ci-verify.sh 可执行指引" "$R_OUT" "ci-verify.sh"
}

# ============================================================
# Wave-2 加固验收（s58~s65）—— L2-T 独立测试者冻结，实现方只读
#
# 真源：.dev-team/plan-freeze.md §7（F1–F12 终裁）。三条铁律：
#   1) 每个反例都配**正向控制**（手工摆成合规形态后必须转绿），禁「跑通即 pass」；
#   2) 失败描述写清「期望 / 实得」，失败即可定位；
#   3) 平台降级如实披露、不静默跳过：目录写拒绝（chmod 555）、chmod -x、ln -s 在
#      MSYS/root 下可能不生效 → 先探测，不生效则 ok + 说明「本环境无法复现，靠 Linux CI」。
# ============================================================

assert_matches() { # <描述> <整体> <ERE>
  if printf '%s\n' "$2" | grep -Eq -- "$3"; then
    ok "$1"
  else
    bad "$1（未匹配 /$3/；实得尾部：$(printf '%s' "$2" | tail -n 2 | tr '\n' ' '))"
  fi
}
# 放行路径的反向断言用：输出里不得出现**针对某判据号**的 FAIL 行。
# 不能直接用 assert_not_contains "1.10"——成功横幅 "机械影子 1.1–1.10" 也含该串（假红）。
# 匹配串与 assert_fail_of 共用同一 ERE（见下），两侧同源，避免"收窄匹配串后真违例被放过"。
FAIL_LINE_OF_RE='^FAIL[[:space:]]+%s([^0-9]|$)'
assert_no_fail_of() { # <描述> <整体输出> <判据号>
  local hits
  hits=$(printf '%s\n' "$2" | grep -E "$(printf "$FAIL_LINE_OF_RE" "$3")" || true)
  if [ -n "$hits" ]; then
    bad "$1（不应出现 $3 违例；实得：$(printf '%s' "$hits" | head -2 | tr '\n' ' ')）"
  else
    ok "$1"
  fi
}
# assert_no_fail_of 的**正向控制**：同一匹配串必须能命中真实违例行
# （否则"不报 1.10"可能只是匹配写错而恒真——判定被削弱却看不出来）。
assert_fail_of() { # <描述> <整体输出> <判据号>
  local hits
  hits=$(printf '%s\n' "$2" | grep -E "$(printf "$FAIL_LINE_OF_RE" "$3")" || true)
  if [ -n "$hits" ]; then
    ok "$1"
  else
    bad "$1（匹配串未命中 $3 违例行；实得尾部：$(printf '%s' "$2" | tail -n 2 | tr '\n' ' ')）"
  fi
}
sentinel_block() { # <hook 文件> → 输出哨兵区间（含 BEGIN/END 两行）
  sed -n '/>>> ponygo-gate: adr-verify v1 >>>/,/<<< ponygo-gate: adr-verify v1 <<</p' "$1" 2>/dev/null
}
block_begin_line() { # <hook 文件> → 哨兵 BEGIN 行号（无则空）
  grep -nF -m1 "$GATE_MARKER" "$1" 2>/dev/null | head -n1 | cut -d: -f1
}
first_exit_line() { # <hook 文件> → 首个顶层 exit/exec 行号（无则空）
  grep -nE '^[[:space:]]*(exit|exec)[[:space:]]' "$1" 2>/dev/null | head -n1 | cut -d: -f1
}
assert_block_canonical() { # <描述> <hook 文件> <规范块文件>
  local got="$SBASE/got.block"
  sentinel_block "$2" > "$got"
  if [ ! -s "$got" ]; then bad "$1（哨兵区间为空：$2）"; return 0; fi
  if diff <(tr -d '\r' < "$got") <(tr -d '\r' < "$3") >/dev/null 2>&1; then
    ok "$1"
  else
    bad "$1（哨兵区间与规范块不一致——F3 要求逐字节相等）"
    diff <(tr -d '\r' < "$got") <(tr -d '\r' < "$3") | sed -n '1,6p' >&2
  fi
}
make_canonical_block() { # → 打印规范块文件路径（由一次性 ref 仓的 init 产物提取）
  local r b
  r=$(new_case); git_seed_repo "$r"; run_cli "$r" init
  b="$SBASE/canon.block"; sentinel_block "$r/.githooks/pre-commit" > "$b"
  printf '%s' "$b"
}
set_level2() { # <case 目录>：level: 2 + 一条合法决策（2.1–2.3 由 init 落地的 A1/A2/A4 满足）
  printf 'level: 2\n' > "$1/.meta/meta.yaml"
  write_valid_decision "$1" "implemented/feature/2026-01-02-gate.md"
}
stage_status_violation() { # <dir> <文件名>：写 implemented/ 下 Status: proposed（1.7 违例）并暂存
  local f=".agents/notes/implemented/feature/$2"
  mkdir -p "$1/.agents/notes/implemented/feature"
  cat > "$1/$f" <<'EOF'
# Agent Note: status mismatch

Status: proposed

## Problem
why

## Decision
what

## Alternatives considered
other
EOF
  git_local "$1" add "$f" >/dev/null 2>&1
  printf '%s' "$f"
}
C_RC=0; C_OUT=""
run_git_commit() { # <dir> <message>：真跑 git commit（钩子会执行），捕获合并输出与 rc
  local dir="$1" msg="$2" G
  G=$(sanitize_git)
  # shellcheck disable=SC2086
  C_OUT=$( cd "$dir" && env $G git -c user.email=t@t -c user.name=t -c commit.gpgsign=false \
    commit -qm "$msg" 2>&1 ); C_RC=$?
}

s58_f1_block_before_exit() {
  echo "--- 场景58：F1 哨兵块必须前置到 shebang 之后（exit 0 / exec 钩子下末尾追加=永不执行）"
  local T H bs es CANON
  T=$(new_case); git_seed_repo "$T"; run_cli "$T" init
  CANON="$SBASE/canon58.block"; sentinel_block "$T/.githooks/pre-commit" > "$CANON"

  # ① 既有钩子以 exit 0 结尾（极常见形态）
  T=$(new_case); git_seed_repo "$T"
  ( cd "$T" && mkdir -p .githooks && printf '#!/usr/bin/env bash\nexit 0\n' > .githooks/pre-commit \
      && chmod +x .githooks/pre-commit ) >/dev/null 2>&1
  run_cli "$T" init
  assert_eq "exit 0 钩子场景 init exit 0" 0 "$R_RC"
  H="$T/.githooks/pre-commit"
  bs=$(block_begin_line "$H"); es=$(first_exit_line "$H")
  assert_eq "exit 0 钩子：哨兵块紧接 shebang（第 2 行，F1 前置）" 2 "${bs:-缺失}"
  if [ -n "$es" ] && [ -n "$bs" ] && [ "$bs" -lt "$es" ]; then
    ok "exit 0 钩子：哨兵块在首个顶层 exit/exec 之前（块 $bs 行 < exit $es 行）"
  else
    bad "exit 0 钩子：哨兵块位置错误（块行 ${bs:-缺失} 应 < 首个顶层 exit/exec 行 ${es:-无}）——末尾追加被 exit 截断（F1）"
  fi
  stage_status_violation "$T" "2026-01-09-exit0.md" >/dev/null
  run_git_commit "$T" "must be rejected"
  assert_nonzero "exit 0 钩子下非法 ADR 提交必须 rc≠0（F1 假绿反证）" "$C_RC"
  assert_matches "提交被拒时输出点名判据（门真的跑到了）" "$C_OUT" '1\.7|adr-verify'

  # ② 既有钩子 exec 他进程（同样截断末尾追加）
  T=$(new_case); git_seed_repo "$T"
  ( cd "$T" && mkdir -p .githooks && printf '#!/usr/bin/env bash\nexec /bin/true\n' > .githooks/pre-commit \
      && chmod +x .githooks/pre-commit ) >/dev/null 2>&1
  run_cli "$T" init
  H="$T/.githooks/pre-commit"
  bs=$(block_begin_line "$H"); es=$(first_exit_line "$H")
  assert_eq "exec 钩子：哨兵块紧接 shebang（第 2 行，F1 前置）" 2 "${bs:-缺失}"
  if [ -n "$es" ] && [ -n "$bs" ] && [ "$bs" -lt "$es" ]; then
    ok "exec 钩子：哨兵块在 exec 之前（块 $bs 行 < exec $es 行）"
  else
    bad "exec 钩子：哨兵块位置错误（块行 ${bs:-缺失} 应 < 首个顶层 exec 行 ${es:-无}）——exec 会替换进程（F1）"
  fi
  stage_status_violation "$T" "2026-01-09-exec.md" >/dev/null
  run_git_commit "$T" "must be rejected"
  assert_nonzero "exec 钩子下非法 ADR 提交必须 rc≠0" "$C_RC"

  # ③ 正向控制：手工摆成 F1 合规位置（块在 shebang 后、exit 前）→ 同一非法 ADR 必被拒
  T=$(new_case); git_seed_repo "$T"; run_cli "$T" init
  H="$T/.githooks/pre-commit"
  { printf '#!/usr/bin/env bash\n'; cat "$CANON"; printf 'exit 0\n'; } > "$H.tmp" && mv -f "$H.tmp" "$H"
  chmod +x "$H"
  assert_eq "正向控制：手工合规块的起始行" 2 "$(block_begin_line "$H")"
  stage_status_violation "$T" "2026-01-09-ok.md" >/dev/null
  run_git_commit "$T" "must be rejected"
  assert_nonzero "正向控制：F1 合规位置下非法 ADR 提交被拒（rc≠0）" "$C_RC"
}

s59_f2_concurrent_atomicity() {
  echo "--- 场景59：F2 原子性（10 并行 init × 10 轮 → 哨兵尾行恒为 1）+ 半截块自愈"
  local T i r cnt maxc=0
  T=$(new_case); git_seed_repo "$T"
  ( cd "$T" && mkdir -p .githooks && git config core.hooksPath .githooks ) >/dev/null 2>&1
  for r in 1 2 3 4 5 6 7 8 9 10; do
    printf '#!/usr/bin/env bash\necho custom-gate\n' > "$T/.githooks/pre-commit"
    chmod +x "$T/.githooks/pre-commit"
    rm -f "$T/go"
    # 起跑栅栏（flag 文件自旋）：让 10 个进程尽量同时进「读-判-写」窗口，
    # 否则仅靠 & 的启动抖动会把竞态掩成偶然绿——这是**加强**同一契约，不换判据。
    for i in 1 2 3 4 5 6 7 8 9 10; do
      ( cd "$T" && while [ ! -f go ]; do :; done; exec bash "$ROOT/ponygo" init >/dev/null 2>&1 ) &
    done
    sleep 0.5
    : > "$T/go"
    wait
    cnt=$(grep -cF "$GATE_MARKER_END" "$T/.githooks/pre-commit" 2>/dev/null || printf 0)
    [ "${cnt:-0}" -gt "$maxc" ] && maxc=$cnt
    if [ "$cnt" -eq 1 ]; then
      ok "第 $r 轮：10 并行 init 后哨兵尾行恰好 1"
    else
      bad "第 $r 轮：10 并行 init 后哨兵尾行=$cnt（期望 1——F2 原子替换 + flock 缺失）"
    fi
  done
  assert_eq "10 轮并发峰值哨兵尾行数" 1 "$maxc"
  bash -n "$T/.githooks/pre-commit" 2>/dev/null
  assert_eq "并发后钩子仍语法合法（无交错写坏，F2）" 0 "$?"

  # 正向控制：顺序单次 init 必须恰好 1（证明「恰好 1」可达成、计数口径正确）
  T=$(new_case); git_seed_repo "$T"
  ( cd "$T" && mkdir -p .githooks && printf '#!/usr/bin/env bash\necho custom-gate\n' > .githooks/pre-commit \
      && chmod +x .githooks/pre-commit && git config core.hooksPath .githooks ) >/dev/null 2>&1
  run_cli "$T" init
  assert_eq "正向控制：顺序 init 后哨兵尾行恰好 1" 1 \
    "$(grep -cF "$GATE_MARKER_END" "$T/.githooks/pre-commit" 2>/dev/null || printf 0)"

  # ② 半截块（BEGIN + if…then，无 END/fi）→ init 后必须自愈：bash -n rc=0 且尾行恰好 1
  T=$(new_case); git_seed_repo "$T"
  ( cd "$T" && mkdir -p .githooks && git config core.hooksPath .githooks ) >/dev/null 2>&1
  cat > "$T/.githooks/pre-commit" <<'EOF'
#!/usr/bin/env bash
# >>> ponygo-gate: adr-verify v1 >>>
if [ -f "$(git rev-parse --show-toplevel)/.meta/gates/adr-verify.sh" ]; then
EOF
  chmod +x "$T/.githooks/pre-commit"
  run_cli "$T" init
  bash -n "$T/.githooks/pre-commit" 2>/dev/null
  assert_eq "半截块自愈后 bash -n rc=0（不得留下未闭合 if）" 0 "$?"
  assert_eq "半截块自愈后哨兵尾行恰好 1" 1 \
    "$(grep -cF "$GATE_MARKER_END" "$T/.githooks/pre-commit" 2>/dev/null || printf 0)"
}

s60_f3_canonical_block() {
  echo "--- 场景60：F3 哨兵块逐字节等于规范块（echo / || true / if false 三变体均判未接线）"
  local T V CANON TPL
  CANON=$(make_canonical_block)
  assert_contains "前提取证：规范块内含非注释调用行" "$(cat "$CANON")" "adr-verify.sh"
  for V in echo ortrue iffalse; do
    T=$(new_case); git_seed_repo "$T"
    ( cd "$T" && mkdir -p .githooks && git config core.hooksPath .githooks ) >/dev/null 2>&1
    case "$V" in
      echo) TPL='#!/usr/bin/env bash
echo hook
# >>> ponygo-gate: adr-verify v1 >>>
echo adr-verify.sh
# <<< ponygo-gate: adr-verify v1 <<<' ;;
      ortrue) TPL='#!/usr/bin/env bash
echo hook
# >>> ponygo-gate: adr-verify v1 >>>
if [ -f "$(git rev-parse --show-toplevel)/.meta/gates/adr-verify.sh" ]; then
  bash "$(git rev-parse --show-toplevel)/.meta/gates/adr-verify.sh" || true
fi
# <<< ponygo-gate: adr-verify v1 <<<' ;;
      iffalse) TPL='#!/usr/bin/env bash
echo hook
# >>> ponygo-gate: adr-verify v1 >>>
if false; then
  bash "$(git rev-parse --show-toplevel)/.meta/gates/adr-verify.sh" || exit 1
fi
# <<< ponygo-gate: adr-verify v1 <<<' ;;
    esac
    printf '%s\n' "$TPL" > "$T/.githooks/pre-commit"; chmod +x "$T/.githooks/pre-commit"
    run_cli "$T" init
    set_level2 "$T"
    # shellcheck disable=SC2046
    run_cli_env "$T" $(sanitize_git) status
    assert_eq "变体 $V：status exit 1（非规范块=未接线，F3）" 1 "$R_RC"
    assert_contains "变体 $V：报 2.4" "$R_OUT" "2.4"
    run_cli "$T" init
    assert_block_canonical "变体 $V：init 重写为规范块（F3 gate_hook_wired 语义）" \
      "$T/.githooks/pre-commit" "$CANON"
    assert_eq "变体 $V：重写后哨兵尾行恰好 1" 1 \
      "$(grep -cF "$GATE_MARKER_END" "$T/.githooks/pre-commit" 2>/dev/null || printf 0)"
    # shellcheck disable=SC2046
    run_cli_env "$T" $(sanitize_git) status
    assert_eq "变体 $V：重写后 status exit 0（正向控制）" 0 "$R_RC"
  done
}

s61_f4_write_failure_loud() {
  echo "--- 场景61：F4 写失败必须响亮（.githooks 不可写 → init rc≠0 + WARN + 补救）"
  local T; T=$(new_case)
  git_seed_repo "$T"
  ( cd "$T" && mkdir -p .githooks && git config core.hooksPath .githooks && chmod 555 .githooks ) >/dev/null 2>&1
  if ( : > "$T/.githooks/.wprobe" ) 2>/dev/null; then
    rm -f "$T/.githooks/.wprobe"; chmod 755 "$T/.githooks"
    ok "本环境目录写拒绝不生效（MSYS/root）→ F4 写失败场景降级跳过（由 Linux CI 复现）"
  else
    run_cli "$T" init
    assert_nonzero "钩子写入失败 → init rc≠0（F4：禁止 Permission denied + exit 0）" "$R_RC"
    assert_contains "输出点名失败目标 .githooks/pre-commit" "$R_OUT" ".githooks/pre-commit"
    assert_contains "输出含 WARN（F4 要求 WARN + 失败清单）" "$R_OUT" "WARN"
    assert_matches "输出给出可执行补救（非裸 Permission denied）" "$R_OUT" '补救|写入失败|不可写|修复失败'
    chmod 755 "$T/.githooks"
    run_cli "$T" init
    assert_eq "恢复权限后 init rc=0（正向控制）" 0 "$R_RC"
    assert_exists "恢复权限后钩子已生成（正向控制）" "$T/.githooks/pre-commit"
  fi
  chmod 755 "$T/.githooks" 2>/dev/null || true
}

s62_f5_remedy_by_cause() {
  echo "--- 场景62：F5 补救按因分支（非 git / hooksPath 不可达 / 钩子不可执行）且不得给统一 init 文案"
  local T G; G=$(sanitize_git)

  # ① 非 git → 补救 = git init
  T=$(new_case); run_cli "$T" init; set_level2 "$T"
  # shellcheck disable=SC2046
  run_cli_env "$T" $G status
  assert_eq "非 git 分支：status exit 1" 1 "$R_RC"
  assert_contains "非 git 分支：报 2.4" "$R_OUT" "2.4"
  assert_contains "非 git 分支：补救含 git init（F5）" "$R_OUT" "git init"
  assert_not_contains "非 git 分支：不得给统一 bash ponygo init 文案（F5）" "$R_OUT" "bash ponygo init"

  # ② hooksPath 指向不可达 → 补救 = git config core.hooksPath
  T=$(new_case); git_seed_repo "$T"; run_cli "$T" init; set_level2 "$T"
  rm -rf "$T/.githooks"
  # shellcheck disable=SC2046
  run_cli_env "$T" $G status
  assert_eq "hooksPath 不可达分支：status exit 1" 1 "$R_RC"
  assert_contains "hooksPath 不可达分支：报 2.4" "$R_OUT" "2.4"
  assert_contains "不可达分支：补救含 git config core.hooksPath（F5）" "$R_OUT" "git config core.hooksPath"
  assert_not_contains "不可达分支：不得给统一 bash ponygo init 文案（F5）" "$R_OUT" "bash ponygo init"

  # ③ 钩子不可执行 → 补救 = chmod +x；且 init 不得替它激活（§6.1 沉睡钩子是人的决定）
  T=$(new_case); git_seed_repo "$T"; run_cli "$T" init; set_level2 "$T"
  chmod -x "$T/.githooks/pre-commit" 2>/dev/null
  if [ -x "$T/.githooks/pre-commit" ]; then
    ok "本环境 chmod -x 不生效（MSYS）→ 钩子不可执行分支降级跳过（由 Linux CI 复现）"
  else
    # shellcheck disable=SC2046
    run_cli_env "$T" $G status
    assert_eq "钩子不可执行分支：status exit 1" 1 "$R_RC"
    assert_contains "钩子不可执行分支：报 2.4" "$R_OUT" "2.4"
    assert_matches "不可执行分支：补救含 chmod +x（F5）" "$R_OUT" 'chmod \+x'
    assert_not_contains "不可执行分支：不得给统一 bash ponygo init 文案（F5）" "$R_OUT" "bash ponygo init"
    run_cli "$T" init
    assert_eq "init 不替沉睡钩子 chmod（§6.1）" "no" \
      "$([ -x "$T/.githooks/pre-commit" ] && echo yes || echo no)"
  fi
}

s63_f6_tilde_expansion() {
  echo "--- 场景63：F6 hooksPath 的 ~ 展开（~/hk → \$HOME/hk，level:2 status 必须 rc=0）"
  local T G; G=$(sanitize_git); T=$(new_case)
  git_seed_repo "$T"; run_cli "$T" init; set_level2 "$T"
  mkdir -p "$T/home/hk"
  cp "$T/.githooks/pre-commit" "$T/home/hk/pre-commit"
  chmod +x "$T/home/hk/pre-commit"
  git_local "$T" config core.hooksPath '~/hk' >/dev/null 2>&1
  # shellcheck disable=SC2046
  run_cli_env "$T" HOME="$T/home" $G status
  assert_eq "F6：hooksPath=~/hk 且 \$HOME/hk 已接线 → status exit 0（不得假 FAIL）" 0 "$R_RC"
  assert_contains "F6：结论行为 L0-L2（2.4 判 PASS）" "$R_OUT" "L0-L2"
  assert_missing "F6：不得在仓内造 ./~/hk 目录" "$T/~/hk"
}

s64_f8_f11_dry_run_provider() {
  echo "--- 场景64：F8 dry-run 豁免非 TTY（含装配预览）+ F11 provider 收紧 + A5 timeout-minutes"
  local T G; G=$(sanitize_git)

  # ① F8：--dry-run 在非 TTY（</dev/null）下 rc=0、零落盘、且打印装配预览
  T=$(new_case); git_seed_repo "$T"
  R_OUT=$( cd "$T" && bash "$ROOT/ponygo" init --dry-run </dev/null 2>&1 ); R_RC=$?
  assert_eq "F8：init --dry-run（</dev/null）rc=0" 0 "$R_RC"
  assert_missing "F8：dry-run 零落盘（.meta 不存在）" "$T/.meta"
  assert_eq "F8：dry-run 不改 core.hooksPath" "" "$(hookspath_of "$T")"
  assert_contains "F8：dry-run 打印装配预览（含 .githooks 计划）" "$R_OUT" ".githooks"
  # ② F8 核心：--dry-run 且 stdin 非 TTY → 不得被交互确认判据 die 挡住
  T=$(new_case)
  R_OUT=$( cd "$T" && bash "$ROOT/ponygo" init --dry-run </dev/null 2>&1 ); R_RC=$?
  assert_eq "F8：init --dry-run（非 TTY）rc=0（dry-run 无需确认）" 0 "$R_RC"
  assert_missing "F8：dry-run 零落盘" "$T/.meta"

  # ③ F11：仅 .github/ISSUE_TEMPLATE/（无 workflows）+ remote 非 github → 不生成 A5
  T=$(new_case); git_seed_repo "$T"
  mkdir -p "$T/.github/ISSUE_TEMPLATE"; printf 'x\n' > "$T/.github/ISSUE_TEMPLATE/bug.md"
  git_local "$T" remote add origin https://gitlab.com/example/demo.git >/dev/null 2>&1
  run_cli "$T" init
  assert_missing "F11：仅 .github/ISSUE_TEMPLATE 不算 github → 不生成 A5" \
    "$T/.github/workflows/ponygo-governance.yml"
  assert_exists "F11：A4 门禁本体仍生成" "$T/.meta/gates/ci-verify.sh"
  # shellcheck disable=SC2046
  run_cli_env "$T" $G status
  assert_contains "F11：status 报远端层" "$R_OUT" "远端层"
  assert_not_contains "F11：status 不得误报「适配器已生成」" "$R_OUT" "适配器已生成"

  # ④ F11：真 GitHub 证据（.github/workflows/）→ 生成 A5，且含 timeout-minutes: 10（B9）
  T=$(new_case); git_seed_repo "$T"; mkdir -p "$T/.github/workflows"
  run_cli "$T" init
  assert_exists "F11：.github/workflows/ 存在 → 生成 A5" "$T/.github/workflows/ponygo-governance.yml"
  assert_file_has "F11：A5 含 timeout-minutes: 10（B9）" \
    "$T/.github/workflows/ponygo-governance.yml" "timeout-minutes: 10"
}

s65_f9_f10_symlink_and_selfheal() {
  echo "--- 场景65：F9 符号链接 ADR 必须拒绝 + F10 资产自愈（半截 A1 → init 恢复规范内容）"
  local T; T=$(new_case)
  git_seed_repo "$T"; run_cli "$T" init
  write_valid_decision "$T" "implemented/feature/2026-01-08-target.md"
  ( cd "$T/.agents/notes/implemented/feature" && ln -sf 2026-01-08-target.md 2026-01-08-link.md ) 2>/dev/null
  if [ ! -L "$T/.agents/notes/implemented/feature/2026-01-08-link.md" ]; then
    ok "本环境 ln -s 未生成真符号链接（Git Bash）→ F9 符号链接用例降级跳过（由 Linux CI 复现）"
  else
    git_local "$T" add .agents/notes/implemented/feature/2026-01-08-link.md >/dev/null 2>&1
    assert_contains "前提取证：索引内该 ADR 为符号链接（mode 120000）" \
      "$(git_local "$T" ls-files -s .agents/notes/implemented/feature/2026-01-08-link.md)" "120000"
    run_script "$T" .meta/gates/adr-verify.sh
    assert_nonzero "F9：符号链接 ADR 暂存 → A1 必须非零" "$S_RC"
    assert_matches "F9：拒绝文案说明必须是普通文件" "$S_OUT" '普通文件|符号链接|symlink|120000'
    # 正向控制：同内容换成普通文件 → 放行
    rm -f "$T/.agents/notes/implemented/feature/2026-01-08-link.md"
    cp "$T/.agents/notes/implemented/feature/2026-01-08-target.md" \
       "$T/.agents/notes/implemented/feature/2026-01-08-link.md"
    git_local "$T" add .agents/notes/implemented/feature/2026-01-08-link.md >/dev/null 2>&1
    run_script "$T" .meta/gates/adr-verify.sh
    assert_eq "F9 正向控制：普通文件同内容 → A1 exit 0" 0 "$S_RC"
  fi

  # ② F10：A1 被改成半截内容 → init 自愈为规范内容（与仓库模板 eol 归一逐字节一致）
  printf 'echo x\n' > "$T/.meta/gates/adr-verify.sh"
  run_cli "$T" init
  assert_same_as_template "F10：init 自愈 A1 为仓库模板内容" \
    "$T/.meta/gates/adr-verify.sh" "$ROOT/.meta/gates/adr-verify.sh"
  bash -n "$T/.meta/gates/adr-verify.sh" 2>/dev/null
  assert_eq "F10：自愈后 A1 bash -n rc=0" 0 "$?"
  assert_matches "F10：自愈时打 WARN 一行（F10 明写 WARN）" "$R_OUT" 'WARN'
  # 功能正向控制：自愈后的 A1 真的会拒绝 1.7 违例
  stage_status_violation "$T" "2026-01-10-selfheal.md" >/dev/null
  run_script "$T" .meta/gates/adr-verify.sh
  assert_nonzero "F10 正向控制：自愈后的 A1 拒绝 1.7 违例" "$S_RC"
}

# ============================================================
# Wave-3 复验红相（s66~s68）—— L2-T 独立测试者冻结，实现方只读
# 真源：review-verify-1.json / review-l3p-verify.json（2 BLOCKING + 1 ADVISORY，commit 5ee46ea）。
# 铁律不变：每条反例配正向控制；失败描述写清期望/实得。
# ============================================================

# 更严的顶层 exit/exec 行号探测：覆盖 `exit`（裸）、`exit;`、`exit $?`、`exec …`。
# 既有 first_exit_line 只认「exit + 空白」，裸 exit / 分号形态会漏检（正是 s66 的缺陷面）；
# 此处不改既有 helper（避免动老场景断言），另立新名供 wave-3 使用。
first_exit_line_v2() { # <hook 文件> → 首个顶层 exit/exec 行号（无则空）
  grep -nE '^[[:space:]]*(exit|exec)([[:space:];]|$)' "$1" 2>/dev/null | head -n1 | cut -d: -f1
}
gate_block_lines() { # 打印规范哨兵块（与 prepend_gate_block/ponygo 生成器逐字同款）
  printf '%s\n' "$GATE_MARKER"
  printf 'if [ -f "$(git rev-parse --show-toplevel)/.meta/gates/adr-verify.sh" ]; then\n'
  printf '  bash "$(git rev-parse --show-toplevel)/.meta/gates/adr-verify.sh" || exit 1\n'
  printf 'fi\n'
  printf '%s\n' "$GATE_MARKER_END"
}

s66_f1_bare_exit_position() {
  echo "--- 场景66：F1 位置判据须识别裸 exit / exit;（块落其后的 legacy 钩子=假接线）"
  local T V EXITLINE bs es G; G=$(sanitize_git)
  for V in bare semi dollar; do
    case "$V" in
      bare)   EXITLINE='exit' ;;
      semi)   EXITLINE='exit;' ;;
      dollar) EXITLINE='exit $?' ;;
    esac
    T=$(new_case); git_seed_repo "$T"; run_cli "$T" init; set_level2 "$T"
    # 模拟旧版「末尾追加」留下的 legacy 钩子：块在 exit 之后
    { printf '#!/usr/bin/env bash\n'; printf 'echo custom\n'; printf '%s\n' "$EXITLINE"; gate_block_lines; } \
      > "$T/.githooks/pre-commit"
    chmod +x "$T/.githooks/pre-commit"
    # shellcheck disable=SC2046
    run_cli_env "$T" $G status
    assert_eq "变体 $V（$EXITLINE）：legacy 假接线 → status exit 1" 1 "$R_RC"
    assert_contains "变体 $V：legacy 报 2.4" "$R_OUT" "2.4"
    run_cli "$T" init
    bs=$(block_begin_line "$T/.githooks/pre-commit"); es=$(first_exit_line_v2 "$T/.githooks/pre-commit")
    if [ -n "$bs" ] && [ -n "$es" ] && [ "$bs" -lt "$es" ]; then
      ok "变体 $V：init 后哨兵块前置到 exit 之前（块 $bs 行 < exit $es 行）"
    else
      bad "变体 $V：哨兵块仍在 exit 之后或缺失（块 ${bs:-缺失} 行 vs exit ${es:-无} 行）——该块永不执行（BLOCKING）"
    fi
    assert_file_has "变体 $V：用户原有行 echo custom 仍在" "$T/.githooks/pre-commit" "echo custom"
    stage_status_violation "$T" "2026-01-11-$V.md" >/dev/null
    run_git_commit "$T" "must be rejected"
    assert_nonzero "变体 $V：非法 ADR 提交必须 rc≠0（块真被执行）" "$C_RC"
  done

  # 正向控制：块正确前置在裸 exit 之前 → status 0 且非法 ADR 必被拒（证明判据可满足）
  T=$(new_case); git_seed_repo "$T"; run_cli "$T" init; set_level2 "$T"
  { printf '#!/usr/bin/env bash\n'; gate_block_lines; printf 'echo custom\nexit\n'; } \
    > "$T/.githooks/pre-commit"
  chmod +x "$T/.githooks/pre-commit"
  # shellcheck disable=SC2046
  run_cli_env "$T" $G status
  assert_eq "正向控制：块前置在裸 exit 之前 → status exit 0" 0 "$R_RC"
  assert_contains "正向控制：结论行 L0-L2" "$R_OUT" "L0-L2"
  stage_status_violation "$T" "2026-01-11-ok.md" >/dev/null
  run_git_commit "$T" "must be rejected"
  assert_nonzero "正向控制：裸 exit 钩子下非法 ADR 被拒（rc≠0）" "$C_RC"
}

s67_f2_foreign_lines_not_truncated() {
  echo "--- 场景67：未闭合哨兵块含外来行 → 不得静默截断（须 WARN + 非零）；纯半截块仍自愈"
  local T
  T=$(new_case); git_seed_repo "$T"
  ( cd "$T" && mkdir -p .githooks && git config core.hooksPath .githooks ) >/dev/null 2>&1
  cat > "$T/.githooks/pre-commit" <<'EOF'
#!/usr/bin/env bash
echo user-line-1
# >>> ponygo-gate: adr-verify v1 >>>
if [ -f "$(git rev-parse --show-toplevel)/.meta/gates/adr-verify.sh" ]; then
echo user-line-2
echo user-line-3
EOF
  chmod +x "$T/.githooks/pre-commit"
  run_cli "$T" init
  assert_nonzero "含外来内容的未闭合哨兵块 → init 必须非零退出（不得静默截断）" "$R_RC"
  assert_contains "输出含 WARN" "$R_OUT" "WARN"
  assert_matches "WARN 说明哨兵块未闭合" "$R_OUT" '未闭合'
  assert_matches "WARN 说明含外来内容/需人工清理" "$R_OUT" '外来|人工'
  assert_file_has "原有行 echo user-line-1 必须保留" "$T/.githooks/pre-commit" "echo user-line-1"
  assert_file_has "外来行 echo user-line-2 必须保留" "$T/.githooks/pre-commit" "echo user-line-2"
  assert_file_has "外来行 echo user-line-3 必须保留" "$T/.githooks/pre-commit" "echo user-line-3"

  # 正向对照：纯半截块（区域内只有规范行、无外来行）仍必须自愈为单块 + 语法合法
  T=$(new_case); git_seed_repo "$T"; run_cli "$T" init; set_level2 "$T"
  cat > "$T/.githooks/pre-commit" <<'EOF'
#!/usr/bin/env bash
# >>> ponygo-gate: adr-verify v1 >>>
if [ -f "$(git rev-parse --show-toplevel)/.meta/gates/adr-verify.sh" ]; then
EOF
  chmod +x "$T/.githooks/pre-commit"
  run_cli "$T" init
  assert_eq "正向对照：纯半截块自愈 init exit 0" 0 "$R_RC"
  assert_eq "正向对照：自愈后哨兵尾行恰好 1" 1 \
    "$(grep -cF "$GATE_MARKER_END" "$T/.githooks/pre-commit" 2>/dev/null || printf 0)"
  bash -n "$T/.githooks/pre-commit" 2>/dev/null
  assert_eq "正向对照：自愈后 bash -n rc=0" 0 "$?"
  # shellcheck disable=SC2046
  run_cli_env "$T" $(sanitize_git) status
  assert_eq "正向对照：自愈后 status exit 0（2.4 认接线）" 0 "$R_RC"
}

s68_f_hookspath_escape() {
  echo "--- 场景68：hooksPath 越界（core.hooksPath=..）→ init 必须拒绝且不得在仓外落钩子"
  local T parent
  T=$(new_case); git_seed_repo "$T"; parent=$(dirname "$T")
  ( cd "$T" && git config core.hooksPath .. ) >/dev/null 2>&1
  rm -f "$parent/pre-commit"
  run_cli "$T" init
  assert_nonzero "hooksPath=.. → init 必须非零拒绝（不得写到仓库外）" "$R_RC"
  assert_contains "输出含 WARN" "$R_OUT" "WARN"
  assert_matches "WARN 说明越界/仓库外" "$R_OUT" '仓库外|仓外|越界'
  assert_missing "不得在仓外创建 ../pre-commit" "$parent/pre-commit"
  rm -f "$parent/pre-commit"

  # 正向控制：hooksPath 未设 → init 正常装配（拒绝只针对越界，不是把正常路径也拒了）
  T=$(new_case); git_seed_repo "$T"
  run_cli "$T" init
  assert_eq "正向控制：hooksPath 未设 → init exit 0" 0 "$R_RC"
  assert_exists "正向控制：生成 .githooks/pre-commit" "$T/.githooks/pre-commit"
}

# ============================================================
# Wave-4 收尾红相（s69~s70）—— L2-T 独立测试者冻结，实现方只读
# 真源：Lead R4 裁决（对 77d1eb9 复验）：①特尾随/重复哨兵块不得删用户行；
# ②函数体内 exit 不得被误判为「顶层早退」（否则 2.4 假红）。
# 铁律不变：每条反例配正向/反向控制；失败描述写清期望/实得。
# ============================================================

s69_f_trailing_sentinel_no_user_loss() {
  echo "--- 场景69：重复/尾随哨兵块不得删用户行（零字节删除 + 非零 + WARN）"
  local T
  T=$(new_case); git_seed_repo "$T"
  ( cd "$T" && mkdir -p .githooks && git config core.hooksPath .githooks ) >/dev/null 2>&1
  # 完整规范块 + 其后的重复 BEGIN + 用户行（无 END）——写中断/重复装配的残留形态
  { printf '#!/usr/bin/env bash\n'; gate_block_lines; \
    printf '# >>> ponygo-gate: adr-verify v1 >>>\necho USER-KEEP-ME\n'; } \
    > "$T/.githooks/pre-commit"
  chmod +x "$T/.githooks/pre-commit"
  run_cli "$T" init
  assert_eq "① 用户行零删除（grep -c USER-KEEP-ME = 1）" 1 \
    "$(grep -c 'USER-KEEP-ME' "$T/.githooks/pre-commit" 2>/dev/null || printf 0)"
  assert_nonzero "② 尾随哨兵块残留 → init 必须非零（需人工清理，不得静默）" "$R_RC"
  assert_matches "③ 输出含 [WARN]" "$R_OUT" '\[WARN\]|WARN'
  assert_matches "③ WARN 点名哨兵块" "$R_OUT" '哨兵'
  assert_matches "③ WARN 说明残留/未闭合/需人工清理" "$R_OUT" '残留|未闭合|人工|外来'
  # 幂等守卫：再跑一次 init，用户行仍必须恰好 1（重复装配不得累积删除/重复插入）
  run_cli "$T" init
  assert_eq "①b 二次 init 后用户行仍恰好 1" 1 \
    "$(grep -c 'USER-KEEP-ME' "$T/.githooks/pre-commit" 2>/dev/null || printf 0)"

  # ④ 正向对照：两个**纯规范**块（无外来行）→ 去重为一个块、语法合法、rc=0
  T=$(new_case); git_seed_repo "$T"; run_cli "$T" init; set_level2 "$T"
  { printf '#!/usr/bin/env bash\n'; gate_block_lines; gate_block_lines; } > "$T/.githooks/pre-commit"
  chmod +x "$T/.githooks/pre-commit"
  run_cli "$T" init
  assert_eq "④ 纯规范重复块 → init exit 0" 0 "$R_RC"
  assert_eq "④ 去重后哨兵尾行恰好 1" 1 \
    "$(grep -cF "$GATE_MARKER_END" "$T/.githooks/pre-commit" 2>/dev/null || printf 0)"
  bash -n "$T/.githooks/pre-commit" 2>/dev/null
  assert_eq "④ 去重后 bash -n rc=0" 0 "$?"
}

s70_f_function_body_exit_not_early_exit() {
  echo "--- 场景70：函数体内 exit 不算顶层早退（否则 2.4 假红）；顶层裸 exit 仍必须红"
  local T G; G=$(sanitize_git)
  # ① 正向：cleanup() { exit 1; } 在规范块之前 —— 函数体内 exit 不是顶层早退，块照常执行
  T=$(new_case); git_seed_repo "$T"; run_cli "$T" init; set_level2 "$T"
  { printf '#!/usr/bin/env bash\ncleanup() { exit 1; }\n'; gate_block_lines; } > "$T/.githooks/pre-commit"
  chmod +x "$T/.githooks/pre-commit"
  # shellcheck disable=SC2046
  run_cli_env "$T" $G status
  assert_eq "① 函数体内 exit 不算早退 → status exit 0（不得假红）" 0 "$R_RC"
  assert_contains "① 结论行 L0-L2（2.4 判 PASS）" "$R_OUT" "L0-L2"
  # ② 反向对照：顶层裸 exit + 规范块 → 必须红并报 2.4（位置判据不得被放宽掉）
  T=$(new_case); git_seed_repo "$T"; run_cli "$T" init; set_level2 "$T"
  { printf '#!/usr/bin/env bash\nexit\n'; gate_block_lines; } > "$T/.githooks/pre-commit"
  chmod +x "$T/.githooks/pre-commit"
  # shellcheck disable=SC2046
  run_cli_env "$T" $G status
  assert_eq "② 顶层裸 exit 之后的块 → status exit 1" 1 "$R_RC"
  assert_contains "② 报 2.4" "$R_OUT" "2.4"
}

# ============================================================
# wave-5 红相（s71–s74）：契约三项改造的验收（对改造前 HEAD 必须真红）
#   ① --yes 彻底移除（含 observe init 同一全局解析）
#   ② 检出替代治理形态 → 适配任务书（不阻断 init；登记 decision 后 WARN 消失）
#   ③ docs-tier: off 的「建议录一条 decision」假提示修（已登记 → 静默）
#   ④ retire 非 TTY 无交互确认（rc=0 且 level 真的变）
# ============================================================

# init 的适配摘要行数：首行「检出替代治理形态 … 适配任务书：<路径>」+ 每项一行 + 收尾提示行。
# 只数摘要块本身（`- ` / `+ ` 项行 / 「未登记适配决策」收尾），不把后续 init 普通进度行算进去。
adapt_summary_lines() { # <输出文本> → 行数
  printf '%s\n' "$1" | awk '
    /检出替代治理形态/ && /适配任务书/ { inside=1; n=1; next }
    inside && /^ponygo: *(- |\+ |未登记适配决策)/ { n++; next }
    inside { inside=0 }
    END { printf "%s\n", n+0 }'
}

s71_yes_flag_rejected() {
  echo "--- 场景71：--yes 已彻底移除（传入即未知选项报错；无旗标即可执行）"
  local T SK
  # ① 负相：init --yes 必须被拒（不得静默接受半途落盘）
  T=$(new_case)
  run_cli "$T" init --yes
  assert_nonzero "①.1 ponygo init --yes → rc≠0" "$R_RC"
  assert_contains "①.2 报错点名被拒旗标 --yes" "$R_OUT" "--yes"
  case "$R_OUT" in
    *未知选项*|*未知参数*) ok "①.3 诊断为未知选项/未知参数" ;;
    *) bad "①.3 诊断为未知选项/未知参数（实得：$R_OUT）" ;;
  esac
  assert_contains "①.4 替代指引含「ponygo init」" "$R_OUT" "ponygo init"
  assert_contains "①.5 替代指引含「--dry-run」" "$R_OUT" "--dry-run"
  assert_missing "①.6 未知选项 → 零落盘（.meta 不应存在）" "$T/.meta"
  # ② 正向对照：同目录无旗标 init → rc=0 且骨架落盘（证明 ① 的 rc≠0 不是目录问题）
  run_cli "$T" init
  assert_eq "②.1 同目录 ponygo init（无旗标）→ rc=0" 0 "$R_RC"
  assert_exists "②.2 骨架已生成 .meta/meta.yaml" "$T/.meta/meta.yaml"
  # ③ observe init 走同一全局旗标解析：--yes 同样被拒，去掉后必须能执行
  T=$(new_case); SK=$(stage_skill "$T")
  run_cli "$T" observe init --kind frontend --dims tracing --skill-dir "$SK" --yes
  assert_nonzero "③.1 observe init … --yes → rc≠0（同一全局解析）" "$R_RC"
  assert_missing "③.2 observe init --yes → 零落盘（无 docs/observability.yaml）" "$T/docs/observability.yaml"
  run_cli "$T" observe init --kind frontend --dims tracing --skill-dir "$SK"
  assert_eq "③.3 observe init（去掉 --yes）→ rc=0（正向对照）" 0 "$R_RC"
  assert_exists "③.4 observe init 声明已落盘（正向对照）" "$T/docs/observability.yaml"
}

s72_adaptation_book() {
  echo "--- 场景72：检出替代治理形态 → 适配任务书（不阻断 init；登记 decision 后 WARN 消失）"
  local T BOOK md1 md2 n
  T=$(new_case); git_seed_repo "$T"
  # 既有仓四类替代物各一：决策载体 / 本地钩子 / 远端流水线 / 协作契约
  mkdir -p "$T/docs/adr" "$T/.husky" "$T/.github/workflows"
  printf '# ADR x\n\n既有决策目录里的历史 ADR。\n' > "$T/docs/adr/x.md"
  printf '#!/usr/bin/env bash\necho HUSKY-CUSTOM\n' > "$T/.husky/pre-commit"
  chmod +x "$T/.husky/pre-commit"
  printf 'name: ci\non: [push]\njobs:\n  t:\n    runs-on: ubuntu-latest\n    steps: []\n' \
    > "$T/.github/workflows/ci.yml"
  printf '# CONTRIBUTING\n\n既有贡献流程。\n' > "$T/CONTRIBUTING.md"
  BOOK="$T/.meta/adaptation/alt-governance.md"

  run_cli "$T" init
  assert_eq "① 检出既有治理形态仍 init exit 0（不阻断）" 0 "$R_RC"
  assert_exists "② 适配任务书已生成" "$BOOK"
  # ③ 四项逐项断言（缺哪项就报哪项，不合并成一个大断言）
  assert_file_has "③.1 任务书含 docs/adr（决策载体）" "$BOOK" "docs/adr"
  assert_file_has "③.2 任务书含 .husky（本地钩子）" "$BOOK" ".husky"
  assert_file_has "③.3 任务书含 .github/workflows（远端流水线）" "$BOOK" ".github/workflows"
  assert_file_has "③.4 任务书含 CONTRIBUTING.md（协作契约）" "$BOOK" "CONTRIBUTING.md"
  # ④ 终端摘要：3–6 行，含「适配任务书」与任务书路径
  assert_contains "④.1 摘要点名「适配任务书」" "$R_OUT" "适配任务书"
  assert_contains "④.2 摘要给出任务书路径" "$R_OUT" ".meta/adaptation/alt-governance.md"
  n=$(adapt_summary_lines "$R_OUT")
  if [ "${n:-0}" -ge 3 ] && [ "${n:-0}" -le 6 ]; then
    ok "④.3 摘要行数 3–6（实得 $n）"
  else
    bad "④.3 摘要行数 3–6（实得 [${n:-?}] 行；摘要块原文：$(printf '%s' "$R_OUT" | grep -E '适配任务书|^ponygo: *(- |\+ )' | head -8 | tr '\n' '/')）"
  fi
  # ⑤ 既有钩子一字不动（只在 .githooks 侧装配，不重写 .husky 内容）
  assert_file_has "⑤ 既有 .husky/pre-commit 内容仍在（HUSKY-CUSTOM 未被改写）" \
    "$T/.husky/pre-commit" "HUSKY-CUSTOM"
  # ⑥ 未登记适配决策 → status 持续 WARN，但不改退出码（L1 下 rc=0）
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/process/2026-01-01-bootstrap.md"
  run_cli "$T" status
  assert_eq "⑥.1 status(L1) rc=0（WARN 不改退出码）" 0 "$R_RC"
  assert_contains "⑥.2 status 报「适配决策未登记」" "$R_OUT" "适配决策未登记"
  # ⑦ 落一条合法适配决策 → 该 WARN 消失
  write_valid_decision "$T" "implemented/process/2026-01-02-alt-governance-x.md"
  run_cli "$T" status
  assert_eq "⑦.1 登记适配 decision 后 status rc=0（仍）" 0 "$R_RC"
  assert_not_contains "⑦.2 登记后「适配决策未登记」WARN 消失" "$R_OUT" "适配决策未登记"
  # ⑧ 幂等：再跑 init，任务书 md5 不变（纯函数重写，不追加）
  md1=$(md5_of "$BOOK")
  run_cli "$T" init
  assert_eq "⑧.1 二次 init exit 0" 0 "$R_RC"
  md2=$(md5_of "$BOOK")
  assert_eq "⑧.2 二次 init 后任务书 md5 不变（幂等）" "$md1" "$md2"
}

s73_docs_tier_hint_silent() {
  # 该提示挂在 2.5 判据（L2 才评估），故 fixture 必须 level: 2，否则测的是「根本没走到」。
  echo "--- 场景73：docs-tier: off「建议录一条 decision」假提示（已登记 → 静默）"
  local T DEC
  T=$(new_case); git_seed_repo "$T"; run_cli "$T" init
  DEC=".agents/notes/implemented/process/2026-01-01-docs-tier-optout.md"
  write_valid_decision "$T" "implemented/process/2026-01-01-bootstrap.md"
  printf 'level: 2\ndocs-tier: off\n' > "$T/.meta/meta.yaml"
  # 负相：删掉 docs-tier decision → 提示必须重现（先验「提示本身存在」，否则下面的静默是空断言）
  run_cli "$T" status
  assert_contains "① 无 docs-tier decision 时 status 提示「建议录一条 decision」" "$R_OUT" "建议录一条 decision"
  run_cli "$T" audit
  assert_contains "② 无 docs-tier decision 时 audit 同样提示" "$R_OUT" "建议录一条 decision"
  # 正相：登记合法 docs-tier decision（文件名含 docs-tier）→ 提示消失
  write_valid_decision "$T" "implemented/process/2026-01-01-docs-tier-optout.md"
  assert_exists "③ 前置取证：decision 已落 ${DEC}" "$T/$DEC"
  run_cli "$T" status
  assert_not_contains "④ 已登记 → status 静默（不催录 decision）" "$R_OUT" "建议录一条 decision"
  run_cli "$T" audit
  assert_not_contains "⑤ 已登记 → audit 静默" "$R_OUT" "建议录一条 decision"
  # 反向对照：再删掉 → 提示必须回来（证明④⑤的静默来自「已登记」而非提示被整体删掉）
  rm -f "$T/$DEC"
  run_cli "$T" status
  assert_contains "⑥ 删除 decision 后 status 提示重现（反向对照）" "$R_OUT" "建议录一条 decision"
  run_cli "$T" audit
  assert_contains "⑦ 删除 decision 后 audit 提示重现（反向对照）" "$R_OUT" "建议录一条 decision"
}

s74_retire_no_confirmation() {
  echo "--- 场景74：retire 非 TTY 无交互确认（rc=0 且 level 真的变）"
  local T lv
  T=$(new_case); run_cli "$T" init
  printf 'level: 2\n' > "$T/.meta/meta.yaml"
  # 前置取证：retire 前 level 确为 2（否则下面「level 变 1」可能空断言）
  assert_eq "⓪ 前置取证：retire 前 level 为 2" "level: 2" \
    "$(grep -m1 '^level' "$T/.meta/meta.yaml" 2>/dev/null)"
  # 非 TTY：显式关 stdin（printf ''），与真实 CI / 管道一致
  R_OUT=$( cd "$T" && printf '' | bash "$ROOT/ponygo" retire --level 1 2>&1 ); R_RC=$?
  assert_eq "① 非 TTY retire --level 1 → rc=0" 0 "$R_RC"
  assert_not_contains "② 输出无「回车继续」（不再等确认）" "$R_OUT" "回车继续"
  assert_not_contains "③ 输出无「已取消」（不得静默 no-op）" "$R_OUT" "已取消"
  lv=$(grep -m1 '^level' "$T/.meta/meta.yaml" 2>/dev/null)
  if [ "$lv" = "level: 1" ]; then
    ok "④ meta.yaml 的 level 真的变 1"
  else
    bad "④ meta.yaml 的 level 真的变 1（期望 [level: 1] 实得 [$lv]）"
  fi
  # 反向控制：无确认 ≠ 无校验——非法目标仍须 die 且不改写 level
  R_OUT=$( cd "$T" && printf '' | bash "$ROOT/ponygo" retire --level 9 2>&1 ); R_RC=$?
  assert_eq "⑤ 非法目标仍 rc=1（校验未被放宽）" 1 "$R_RC"
  lv=$(grep -m1 '^level' "$T/.meta/meta.yaml" 2>/dev/null)
  assert_eq "⑥ 非法目标后 level 未被改写" "level: 1" "$lv"
}

s75_alternatives_110_reject() {
  echo "--- 场景75：判据 1.10——缺 ## Alternatives considered 必拒（带参 + 整树）且补齐即放行"
  local T F
  T=$(new_case); run_cli "$T" init
  F=".agents/notes/implemented/feature/2026-01-02-no-alt.md"
  write_no_alt_decision "$T" "implemented/feature/2026-01-02-no-alt.md"
  # ⓪ 前置取证：样本除缺 1.10 那节外骨架合法（否则下面的拒绝可能来自 1.6/1.7/1.8，测不到 1.10）
  if grep -qE '^## Alternatives considered' "$T/$F"; then
    bad "⓪ 前置取证：反例样本不应含 ## Alternatives considered"
  else
    ok "⓪ 前置取证：样本确无 ## Alternatives considered（其余骨架合法：Status/## Decision 齐）"
  fi
  # ① 带参模式：单文件校验 → 非零 + 点名 1.10
  run_script "$T" .agents/skills/write-adr/verify-note.sh "$F"
  assert_nonzero "① 缺备选节（带参）→ verify-note 非零" "$S_RC"
  assert_contains "② 拒绝输出点名判据号 1.10" "$S_OUT" "1.10"
  # ②b 正向控制：同一匹配串（与 assert_no_fail_of 同源 ERE）必须命中这条真违例行——
  #     证明下面/别处的"不报 1.10"不是把匹配串写窄到恒真。
  assert_fail_of "②b 正向控制：同一匹配串命中真实 1.10 FAIL 行" "$S_OUT" "1.10"
  # ③ 整树模式：同一违例同样红（1.10 不是带参专属）
  run_script "$T" .agents/skills/write-adr/verify-note.sh
  assert_nonzero "③ 整树模式同样拒绝（1.10 非带参专属）" "$S_RC"
  assert_contains "④ 整树模式报出 1.10" "$S_OUT" "1.10"
  # ⑤ 正向对照：同一文件补上该节（位于 ## Decision 之后）→ 0，且不再报 1.10
  printf '\n## Alternatives considered\nother\n' >> "$T/$F"
  run_script "$T" .agents/skills/write-adr/verify-note.sh "$F"
  assert_eq "⑤ 补齐备选节（带参）→ exit 0（证明①③非「一律拒绝」）" 0 "$S_RC"
  assert_no_fail_of "⑥ 补齐后不再报 1.10" "$S_OUT" "1.10"
  run_script "$T" .agents/skills/write-adr/verify-note.sh
  assert_eq "⑦ 补齐后整树同样 exit 0" 0 "$S_RC"
}

s76_alternatives_exemptions() {
  echo "--- 场景76：1.10 豁免面（archived/ 冻结、README/AGENTS 非决策记录、深层合规文件整树 rc=0）"
  local T F
  # ① archived/ 冻结豁免：与反例逐字节同构的内容放进 archived/ → 仍通过
  T=$(new_case); run_cli "$T" init
  F=".agents/notes/archived/testing/2026-01-02-old.md"
  write_no_alt_decision "$T" "archived/testing/2026-01-02-old.md"
  run_script "$T" .agents/skills/write-adr/verify-note.sh "$F"
  assert_eq "① archived/ 下缺备选节 → 仍通过（1.10 冻结豁免）" 0 "$S_RC"
  assert_no_fail_of "② archived/ 放行时不报 1.10" "$S_OUT" "1.10"
  # ③ 反向对照：同一份内容换个 lifecycle → 必须红（证明①的放行来自位置豁免，不是 1.10 歇着）
  T=$(new_case); run_cli "$T" init
  F=".agents/notes/implemented/testing/2026-01-02-old.md"
  write_no_alt_decision "$T" "implemented/testing/2026-01-02-old.md"
  run_script "$T" .agents/skills/write-adr/verify-note.sh "$F"
  assert_nonzero "③ 对照：同内容移到 implemented/ → 非零" "$S_RC"
  assert_contains "④ 对照：报出 1.10（差异确由豁免位置造成）" "$S_OUT" "1.10"
  assert_fail_of "④b 正向控制：匹配串命中该 1.10 FAIL 行（① 的静默非同串写窄所致）" "$S_OUT" "1.10"
  # ⑤ README.md / AGENTS.md：非决策记录，缺该节不影响结果
  T=$(new_case); run_cli "$T" init
  if grep -qE '^## Alternatives considered' "$T/.agents/notes/README.md" 2>/dev/null \
     || grep -qE '^## Alternatives considered' "$T/.agents/notes/AGENTS.md" 2>/dev/null; then
    bad "⑤ 前置取证：README.md / AGENTS.md 本不该含备选节（夹具与契约漂移，豁免面没被测到）"
  else
    ok "⑤ 前置取证：README.md / AGENTS.md 均无备选节（正是被测豁免面）"
  fi
  run_script "$T" .agents/skills/write-adr/verify-note.sh
  assert_eq "⑥ README/AGENTS 缺该节不影响整树结果（rc=0）" 0 "$S_RC"
  assert_no_fail_of "⑦ 且不报 1.10" "$S_OUT" "1.10"
  # ⑧ 子目录深层的合规文件不受影响：豁免面 + 多个深层合规样本混合，整树 rc=0
  T=$(new_case); run_cli "$T" init
  write_no_alt_decision "$T" "archived/testing/2026-01-02-old.md"           # 豁免面
  write_valid_decision "$T" "implemented/architecture/2026-01-02-deep.md"   # 深层合规（确定态）
  write_proposal_decision "$T" "proposed/architecture/2026-01-03-deep.md"   # 深层合规（提案态）
  run_script "$T" .agents/skills/write-adr/verify-note.sh
  assert_eq "⑧ 整树：豁免面 + 深层合规样本混合 → exit 0" 0 "$S_RC"
  assert_no_fail_of "⑨ 混合树不得误报 1.10" "$S_OUT" "1.10"
  # ⑩ 反向对照：同样的深层路径放不合规样本 → 整树必红（证明 find 扫描确实到得了深层）
  write_no_alt_decision "$T" "implemented/process/2026-01-04-deep-bad.md"
  run_script "$T" .agents/skills/write-adr/verify-note.sh
  assert_nonzero "⑩ 深层不合规样本 → 整树非零（扫描未漏判）" "$S_RC"
  assert_contains "⑪ 且点名 1.10" "$S_OUT" "1.10"
}

s77_gate_chain_alternatives() {
  echo "--- 场景77：门禁链路联动（A1 非零含 1.10 / pre-commit 拒提交 / 补齐后放行）"
  local T F
  T=$(new_case); git_seed_repo "$T"; run_cli "$T" init
  F=".agents/notes/implemented/process/2026-01-02-alt-gate.md"
  write_no_alt_decision "$T" "implemented/process/2026-01-02-alt-gate.md"
  git_local "$T" add "$F" >/dev/null 2>&1
  # ⓪ 前置取证：该 ADR 确已进暂存区（否则 A1 会走「无暂存 ADR 变更」跳过 → 空断言）
  assert_contains "⓪ 前置取证：ADR 已暂存" "$(git_local "$T" diff --cached --name-only)" "$F"
  # ① A1 门：暂存区校验 → 非零，并透传真源判据号 1.10
  run_script "$T" .meta/gates/adr-verify.sh
  assert_nonzero "① 缺备选节暂存 → adr-verify.sh 非零" "$S_RC"
  assert_contains "② A1 输出含真源判据号 1.10（可定位补救）" "$S_OUT" "1.10"
  # ③ 链路末段：真跑 git commit（pre-commit 钩子执行 A1）→ 被拒 rc≠0 且输出含 1.10
  run_git_commit "$T" "must be rejected"
  assert_nonzero "③ 缺备选节 → git commit 被拒（rc≠0）" "$C_RC"
  assert_contains "④ 提交被拒输出含 1.10（门真的跑到了）" "$C_OUT" "1.10"
  # ⑤ 正向对照：补齐该节并重新暂存 → A1 exit 0，且同一提交成功（证明③④非「一律拒绝」）
  printf '\n## Alternatives considered\nother\n' >> "$T/$F"
  git_local "$T" add "$F" >/dev/null 2>&1
  run_script "$T" .meta/gates/adr-verify.sh
  assert_eq "⑤ 补齐备选节并重新暂存 → adr-verify.sh exit 0" 0 "$S_RC"
  run_git_commit "$T" "legal adr"
  assert_eq "⑥ 补齐后同一 ADR 提交成功（正向控制）" 0 "$C_RC"
}

s42_observe_monorepo_subcomponents
s43_observe_pipeline_awareness
s44_observe_subcomponent_blocking
s45_observe_diff_timeout_budget
s46_init_gate_wiring
s47_adr_verify_semantics
s48_adr_verify_toctou
s49_adr_verify_rename
s50_preexisting_hook_preserved
s51_husky_foreign_hookspath
s52_init_idempotent
s53_init_dry_run
s54_init_non_tty_no_confirmation
s55_ladder_24_strong
s56_dual_write_parity
s57_ci_conditional_generation
s58_f1_block_before_exit
s59_f2_concurrent_atomicity
s60_f3_canonical_block
s61_f4_write_failure_loud
s62_f5_remedy_by_cause
s63_f6_tilde_expansion
s64_f8_f11_dry_run_provider
s65_f9_f10_symlink_and_selfheal
s66_f1_bare_exit_position
s67_f2_foreign_lines_not_truncated
s68_f_hookspath_escape
s69_f_trailing_sentinel_no_user_loss
s70_f_function_body_exit_not_early_exit
s71_yes_flag_rejected
s72_adaptation_book
s73_docs_tier_hint_silent
s74_retire_no_confirmation
s75_alternatives_110_reject
s76_alternatives_exemptions
s77_gate_chain_alternatives
echo ""
echo "==== 测试结果：pass=$PASS fail=$FAIL ===="
[ "$FAIL" -eq 0 ] || exit 1
exit 0

