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
  run_cli "$T" init --yes
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
  run_cli "$T" init --yes
  assert_eq "重复 init exit 0（不覆盖）" 0 "$R_RC"
  assert_contains "重复 init 提示已存在" "$R_OUT" "已存在"
  grep -q '^level: 0' "$T/.meta/meta.yaml" && ok "重复 init 未改 level" || bad "重复 init 改了 level"
}

s03_status() {
  echo "--- 场景3：status 完整（exit 0）"
  local T; T=$(new_case)
  run_cli "$T" init --yes
  run_cli "$T" status
  assert_eq "新 init 后 status exit 0" 0 "$R_RC"
  assert_contains "骨架完整" "$R_OUT" "骨架完整"
  assert_contains "级自洽验证通过" "$R_OUT" "级自洽验证：通过"
}

s04_bootstrap_projection() {
  echo "--- 场景4：TODO 模板 → bootstrap 引导投影；填槽后自动替换为常载命约"
  local T; T=$(new_case)
  run_cli "$T" init --yes
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
  run_cli "$T" init --yes
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
  run_cli "$T" init --yes; write_constitution_filled "$T"
  rm -f "$T/AGENTS.md" "$T/CLAUDE.md"
  printf 'ai-surface: off\n' >> "$T/.meta/meta.yaml"
  run_cli "$T" sync
  assert_eq "ai-surface: off → sync exit 0" 0 "$R_RC"
  [ ! -f "$T/AGENTS.md" ] && [ ! -f "$T/CLAUDE.md" ] && ok "off 不投影" || bad "off 仍投影"
  assert_contains "提示 off 跳投影" "$R_OUT" "ai-surface: off"
  run_cli "$T2" init --yes; write_constitution_filled "$T2"
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
  run_cli "$T" init --yes
  printf 'level: 3\n' > "$T/.meta/meta.yaml"
  run_cli "$T" retire --level 1 --yes
  assert_eq "retire --level 1 exit 0" 0 "$R_RC"
  grep -q '^level: 1' "$T/.meta/meta.yaml" && ok "level 降到 1" || bad "level 未降级"
  run_cli "$T" retire --level off --yes
  assert_eq "retire --level off exit 0" 0 "$R_RC"
  grep -q '^level: 0' "$T/.meta/meta.yaml" && ok "off 归 level 0" || bad "off 未归 0"
  grep -q '^ai-surface: off' "$T/.meta/meta.yaml" && ok "off 置 ai-surface" || bad "off 未置 ai-surface"
  run_cli "$T" retire --level 9 --yes
  assert_eq "非法值 die exit 1" 1 "$R_RC"
  assert_contains "非法值报错" "$R_OUT" "目标非法"
}

s08_level_normalize() {
  echo "--- 场景8：level L 前缀归一 + level: 12 拒绝"
  local T; T=$(new_case)
  run_cli "$T" init --yes
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
  run_cli "$T" init --yes
  run_cli "$T" init --yes
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
  run_cli "$T" init --yes
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
  T=$(new_case); run_cli "$T" init --yes
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/2026-01-02-add-widget.md"
  run_cli "$T" status
  assert_eq "合法决策 → exit 0" 0 "$R_RC"
  assert_contains "L0-L1 通过" "$R_OUT" "L0-L1"

  T=$(new_case); run_cli "$T" init --yes
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/2026-01-02-bare.md"
  run_cli "$T" status
  assert_eq "缺 class 轴 → exit 1" 1 "$R_RC"
  assert_contains "报 1.5" "$R_OUT" "1.5"

  T=$(new_case); run_cli "$T" init --yes
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/badname.md"
  run_cli "$T" status
  assert_eq "坏文件名 → exit 1" 1 "$R_RC"
  assert_contains "报 1.6" "$R_OUT" "1.6"

  T=$(new_case); run_cli "$T" init --yes
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/2026-01-02-x.md"
  sed -i 's/^Status: implemented/Status: proposed/' "$T/.agents/notes/implemented/feature/2026-01-02-x.md"
  run_cli "$T" status
  assert_eq "Status 不符 → exit 1" 1 "$R_RC"
  assert_contains "报 1.7" "$R_OUT" "1.7"

  T=$(new_case); run_cli "$T" init --yes
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "archived/testing/2026-01-02-old.md"
  run_cli "$T" status
  assert_eq "archived 下 Status: implemented 豁免 → exit 0" 0 "$R_RC"

  T=$(new_case); run_cli "$T" init --yes
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "archived/testing/2026-01-02-old.md"
  sed -i 's/^Status: implemented/Status: rejected/' "$T/.agents/notes/archived/testing/2026-01-02-old.md"
  run_cli "$T" status
  assert_eq "archived 下 Status: rejected → exit 1" 1 "$R_RC"
  assert_contains "报 1.7（archived 违例）" "$R_OUT" "1.7"

  T=$(new_case); run_cli "$T" init --yes
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/2026-02-30-topic.md"
  run_cli "$T" status
  assert_eq "非法日期 2026-02-30 → exit 1" 1 "$R_RC"
  assert_contains "日期不合法被判" "$R_OUT" "日期不合法"

  T=$(new_case); run_cli "$T" init --yes
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/2026-01-02-x.md"
  mkdir -p "$T/.agents/notes/implemented/feature/extra"
  cp "$T/.agents/notes/implemented/feature/2026-01-02-x.md" "$T/.agents/notes/implemented/feature/extra/2026-01-02-deep.md"
  run_cli "$T" status
  assert_eq "depth-4 违例 → exit 1" 1 "$R_RC"
  assert_contains "报 1.5（depth-4）" "$R_OUT" "1.5"

  T=$(new_case); run_cli "$T" init --yes
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/2026-01-02-my topic.md"
  run_cli "$T" status
  assert_eq "含空格文件名（合法）→ exit 0" 0 "$R_RC"

  T=$(new_case); run_cli "$T" init --yes
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/2026-01-02-crlf.md"
  sed -i 's/$/\r/' "$T/.agents/notes/implemented/feature/2026-01-02-crlf.md"
  run_cli "$T" status
  assert_eq "CRLF 决策文件不假 FAIL（1.7）→ exit 0" 0 "$R_RC"

  # 1.8 正文骨架与 lifecycle 匹配（ponyllm 实证漂移回归）
  T=$(new_case); run_cli "$T" init --yes
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/2026-01-02-x.md"
  write_proposal_decision "$T" "proposed/architecture/2026-01-02-y.md"
  run_cli "$T" status
  assert_eq "1.8 合法（Decision+Proposal 各归其位）→ exit 0" 0 "$R_RC"

  T=$(new_case); run_cli "$T" init --yes
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "proposed/architecture/2026-01-02-y.md"
  run_cli "$T" status
  assert_eq "1.8 proposed 误用 ## Decision → exit 1" 1 "$R_RC"
  assert_contains "报 1.8" "$R_OUT" "1.8"

  T=$(new_case); run_cli "$T" init --yes
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_proposal_decision "$T" "implemented/feature/2026-01-02-x.md"
  run_cli "$T" status
  assert_eq "1.8 implemented 含提案时代标题 → exit 1" 1 "$R_RC"
  assert_contains "报 1.8" "$R_OUT" "1.8"

  # 1.9 文档有家（v2.0）：删掉 docs/AGENTS.md → FAIL；根 AGENTS.md 断链 → FAIL
  T=$(new_case); run_cli "$T" init --yes
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/2026-01-02-x.md"
  rm -f "$T/docs/AGENTS.md"
  run_cli "$T" status
  assert_eq "缺 docs/AGENTS.md → exit 1" 1 "$R_RC"
  assert_contains "报 1.9" "$R_OUT" "1.9"

  T=$(new_case); run_cli "$T" init --yes
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/2026-01-02-x.md"
  sed -i 's/docs\/AGENTS\.md//g' "$T/AGENTS.md"
  run_cli "$T" status
  assert_eq "根 AGENTS.md 断链（无 docs/AGENTS.md 引用）→ exit 1" 1 "$R_RC"
  assert_contains "报 1.9" "$R_OUT" "1.9"

  # 1.9c 包文档缺失：packages/ 下子目录无 AGENTS.md/README.md → FAIL；豁免清单可免
  T=$(new_case); run_cli "$T" init --yes
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/2026-01-02-x.md"
  mkdir -p "$T/packages/mod-a" "$T/packages/mod-b"
  run_cli "$T" status
  assert_eq "包文档缺失 → exit 1" 1 "$R_RC"
  assert_contains "报 1.9" "$R_OUT" "1.9"

  T=$(new_case); run_cli "$T" init --yes
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
  T=$(new_case); run_cli "$T" init --yes
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/2026-01-02-gate.md"
  printf 'level: 2\n' > "$T/.meta/meta.yaml"
  ( cd "$T" && git init -q && git config core.hooksPath .githooks \
      && mkdir -p .githooks && printf '#!/usr/bin/env bash\necho hook\n' > .githooks/pre-commit ) >/dev/null 2>&1
  printf '#!/usr/bin/env bash\nexit 0\n' > "$T/.meta/gates/format.sh"
  printf 'purpose: negative sample spec\n' > "$T/.meta/gates/format.spec.md"
  # 分支：未声明 docs-tier + 已激活 → PASS（实际做到优先于声明）
  printf '## 已激活文档家清单\n' >> "$T/.meta/docs-tier/README.md"
  run_cli "$T" status
  assert_eq "未声明+文档分层已激活（PASS）→ exit 0" 0 "$R_RC"
  assert_contains "L0-L2 通过" "$R_OUT" "L0-L2"
  assert_contains "2.2 标注代理判据" "$R_OUT" "代理判据"
  assert_not_contains "已激活不触发 2.5 告警" "$R_OUT" "WARN docs-tier"

  T=$(new_case); run_cli "$T" init --yes
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
  T=$(new_case); run_cli "$T" init --yes
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/2026-01-02-gate.md"
  printf 'level: 2\n' > "$T/.meta/meta.yaml"
  ( cd "$T" && git init -q && git config core.hooksPath .githooks \
      && mkdir -p .githooks && printf '#!/usr/bin/env bash\necho hook\n' > .githooks/pre-commit ) >/dev/null 2>&1
  printf '#!/usr/bin/env bash\nexit 0\n' > "$T/.meta/gates/format.sh"
  printf 'x\n' > "$T/.meta/gates/format.spec.md"
  run_cli "$T" status
  assert_eq "未声明+模板态（SKIP）→ exit 0" 0 "$R_RC"
  assert_contains "催声明 WARN" "$R_OUT" "未声明 docs-tier"
  assert_contains "结论行标 SKIPPED" "$R_OUT" "2.5 SKIPPED"

  # 分支：docs-tier: off + 模板态 → 显式 opt-out，结论行禁写"全部 PASS"，改写为"2.1–2.4 PASS；2.5 未启用"
  T=$(new_case); run_cli "$T" init --yes
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/2026-01-02-gate.md"
  printf 'level: 2\n' > "$T/.meta/meta.yaml"
  printf 'docs-tier: off\n' >> "$T/.meta/meta.yaml"
  ( cd "$T" && git init -q && git config core.hooksPath .githooks \
      && mkdir -p .githooks && printf '#!/usr/bin/env bash\necho hook\n' > .githooks/pre-commit ) >/dev/null 2>&1
  printf '#!/usr/bin/env bash\nexit 0\n' > "$T/.meta/gates/format.sh"
  printf 'x\n' > "$T/.meta/gates/format.spec.md"
  run_cli "$T" status
  assert_eq "docs-tier: off → exit 0" 0 "$R_RC"
  assert_contains "off 改写结论行" "$R_OUT" "2.1–2.4 PASS；2.5 未启用"
  assert_not_contains "off 禁写全部 PASS" "$R_OUT" "全部 PASS"

  # 分支：docs-tier: on + 模板态（未激活）→ FAIL（声明即承诺，未激活即违约）
  T=$(new_case); run_cli "$T" init --yes
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/2026-01-02-gate.md"
  printf 'level: 2\n' > "$T/.meta/meta.yaml"
  printf 'docs-tier: on\n' >> "$T/.meta/meta.yaml"
  ( cd "$T" && git init -q && git config core.hooksPath .githooks \
      && mkdir -p .githooks && printf '#!/usr/bin/env bash\necho hook\n' > .githooks/pre-commit ) >/dev/null 2>&1
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
  T=$(new_case); run_cli "$T" init --yes
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/2026-01-02-gate.md"
  printf 'level: 2\ndocs-tier: off\n' > "$T/.meta/meta.yaml"
  ( cd "$T" && git init -q && git config core.hooksPath .githooks \
      && mkdir -p .githooks && printf '#!/usr/bin/env bash\necho hook\n' > .githooks/pre-commit ) >/dev/null 2>&1
  printf '#!/usr/bin/env bash\nexit 0\n' > "$T/.meta/gates/format.sh"
  printf 'x\n' > "$T/.meta/gates/format.spec.md"
  printf '## 已激活文档家清单\n\n| tier | 家 |\n|---|---|\n| 决策记录 | .agents/notes/ |\n' > "$T/.meta/docs-tier/README.md"
  run_cli "$T" status
  assert_eq "off + 已激活（矛盾 WARN）→ exit 0" 0 "$R_RC"
  assert_contains "off 矛盾 WARN" "$R_OUT" "矛盾"
  assert_contains "off 结论行" "$R_OUT" "2.1–2.4 PASS；2.5 未启用"
  assert_contains "off 提示录 decision" "$R_OUT" "建议录一条 decision"

  # 分支：docs-tier: on + 已激活 + 无 TODO → PASS（声明且做到）
  T=$(new_case); run_cli "$T" init --yes
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/2026-01-02-gate.md"
  printf 'level: 2\n' > "$T/.meta/meta.yaml"
  printf 'docs-tier: on\n' >> "$T/.meta/meta.yaml"
  ( cd "$T" && git init -q && git config core.hooksPath .githooks \
      && mkdir -p .githooks && printf '#!/usr/bin/env bash\necho hook\n' > .githooks/pre-commit ) >/dev/null 2>&1
  printf '#!/usr/bin/env bash\nexit 0\n' > "$T/.meta/gates/format.sh"
  printf 'x\n' > "$T/.meta/gates/format.spec.md"
  # 清零模板态 TODO：重写为已激活清单（无 TODO 残留）
  printf '## 已激活文档家清单\n\n| tier | 家 |\n|---|---|\n| 决策记录 | .agents/notes/ |\n' > "$T/.meta/docs-tier/README.md"
  run_cli "$T" status
  assert_eq "docs-tier: on + 已激活 + 无 TODO → exit 0" 0 "$R_RC"
  assert_contains "on 全过结论行" "$R_OUT" "L0-L2"

  # 分支（P1-1 回归）：引号值（docs-tier: "off"）不得激活状态机——走非法键 WARN + 未声明 SKIP，不兑现 off
  T=$(new_case); run_cli "$T" init --yes
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/2026-01-02-gate.md"
  printf 'level: 2\n' > "$T/.meta/meta.yaml"
  printf 'docs-tier: "off"\n' >> "$T/.meta/meta.yaml"
  ( cd "$T" && git init -q && git config core.hooksPath .githooks \
      && mkdir -p .githooks && printf '#!/usr/bin/env bash\necho hook\n' > .githooks/pre-commit ) >/dev/null 2>&1
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
  T=$(new_case); run_cli "$T" init --yes
  printf 'foo: bar\n' >> "$T/.meta/meta.yaml"
  run_cli "$T" status
  assert_eq "status 违例键仍 exit 0" 0 "$R_RC"
  assert_contains "status WARN" "$R_OUT" "WARN"
  assert_contains "status WARN 指出键" "$R_OUT" "foo: bar"
  run_cli "$T" audit --level S
  assert_eq "audit 违例键仍 exit 0" 0 "$R_RC"
  assert_contains "audit WARN（双挂）" "$R_OUT" "WARN"

  T=$(new_case); run_cli "$T" init --yes
  printf '  level: 2\n' >> "$T/.meta/meta.yaml"
  run_cli "$T" status
  assert_contains "缩进 level: 行告警" "$R_OUT" "WARN"

  # 注意：非 git 场景会触发卫生 WARN（s22），本例在 git 仓库内隔离出 meta 键 WARN 单变量
  T=$(new_case); run_cli "$T" init --yes
  ( cd "$T" && git init -q ) >/dev/null 2>&1
  printf '# comment\r\n\r\nlevel: 0\r\n' > "$T/.meta/meta.yaml"
  run_cli "$T" status
  assert_not_contains "CRLF meta.yaml 不假 WARN" "$R_OUT" "WARN"
  assert_eq "CRLF meta.yaml status exit 0" 0 "$R_RC"

  # docs-tier: on|off 是合法键（L 包原子补丁）：顶格声明不告警，缩进才告警
  T=$(new_case); run_cli "$T" init --yes
  printf 'level: 0\ndocs-tier: off\n' > "$T/.meta/meta.yaml"
  run_cli "$T" status
  assert_eq "docs-tier: off 为合法键 → exit 0" 0 "$R_RC"
  assert_not_contains "docs-tier: off 不告警" "$R_OUT" "非法键"
  T=$(new_case); run_cli "$T" init --yes
  printf 'level: 0\n  docs-tier: on\n' > "$T/.meta/meta.yaml"
  run_cli "$T" status
  assert_contains "缩进 docs-tier 行告警" "$R_OUT" "WARN"
  # docs-tier 非法值（yes/大写 ON）走违例键 WARN（新键从严，不继承 ai-surface 的 Off 大小写先例）
  T=$(new_case); run_cli "$T" init --yes
  printf 'level: 0\ndocs-tier: ON\n' > "$T/.meta/meta.yaml"
  run_cli "$T" status
  assert_contains "docs-tier 非法值告警" "$R_OUT" "非法键"
}

s14_decisions_readme() {
  echo "--- 场景14：生成 decisions/ skills/ README 与模板 eol 归一逐字节一致（F3 + skills 契约）"
  local T; T=$(new_case)
  run_cli "$T" init --yes
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
  if diff <(tr -d '\r' < "$T/.meta/docs-tier/README.md") \
          <(tr -d '\r' < "$ROOT/.meta/docs-tier/README.md") >/dev/null 2>&1; then
    ok "生成 docs-tier/README 与模板 eol 归一后一致（含 tier 模板）"
  else
    bad "生成 docs-tier/README 与模板不一致"
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
  run_cli "$T" init --yes
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
  run_cli "$T" init --yes --dry-run
  assert_eq "init --dry-run exit 0" 0 "$R_RC"
  [ ! -e "$T/.meta" ] && ok "init --dry-run 零落盘" || bad "init --dry-run 落盘了"
  T=$(new_case)
  run_cli "$T" init --yes
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
  T=$(new_case); run_cli "$T" init --yes
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/2026-01-02-a.md"
  mkdir -p "$T/.agents/notes/random-stuff"
  run_cli "$T" status
  assert_eq "1.3 杂项目录 → exit 1" 1 "$R_RC"
  assert_contains "报 1.3" "$R_OUT" "1.3"
  # 1.4 class 越界
  T=$(new_case); run_cli "$T" init --yes
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/not-a-class/2026-01-02-b.md"
  run_cli "$T" status
  assert_eq "1.4 class 越界 → exit 1" 1 "$R_RC"
  assert_contains "报 1.4" "$R_OUT" "1.4"
  # 1.7 缺 Status: 行
  T=$(new_case); run_cli "$T" init --yes
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/2026-01-02-c.md"
  sed -i '/^Status:/d' "$T/.agents/notes/implemented/feature/2026-01-02-c.md"
  run_cli "$T" status
  assert_eq "缺 Status 行 → exit 1" 1 "$R_RC"
  assert_contains "报 1.7" "$R_OUT" "1.7"
  # sync：既有 AGENTS.md 带标记区 → 只替换块内、块外保留
  T=$(new_case); run_cli "$T" init --yes; write_constitution_filled "$T"
  printf 'my notes head\n<!-- BEGIN constitution -->\nold body\n<!-- END constitution -->\nmy notes tail\n' > "$T/AGENTS.md"
  run_cli "$T" sync
  assert_eq "标记区替换 exit 0" 0 "$R_RC"
  grep -q 'my notes head' "$T/AGENTS.md" && ok "块外头保留" || bad "块外头丢失"
  grep -q 'my notes tail' "$T/AGENTS.md" && ok "块外尾保留" || bad "块外尾丢失"
  grep -q 'old body' "$T/AGENTS.md" && bad "旧投影体未替换" || ok "旧投影体已替换"
  [ -f "$T/AGENTS.md.tmp" ] && bad "残留 .tmp" || ok "无 .tmp 残留"
  # sync：既有 AGENTS.md 无标记区 → 追加、原文保留
  T=$(new_case); run_cli "$T" init --yes; write_constitution_filled "$T"
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
  T=$(new_case); run_cli "$T" init --yes
  printf 'level: \n' > "$T/.meta/meta.yaml"
  run_cli "$T" status
  assert_eq "空 level → exit 1" 1 "$R_RC"
  assert_contains "报 0.4" "$R_OUT" "0.4"
  # P2-1：classes.local 扩展 class
  T=$(new_case); run_cli "$T" init --yes
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/domain-x/2026-01-02-ext.md"
  run_cli "$T" status
  assert_eq "未登记的扩展 class → exit 1" 1 "$R_RC"
  assert_contains "报 1.4" "$R_OUT" "1.4"
  printf '# 领域扩展\ndomain-x\n' > "$T/.agents/notes/classes.local"
  run_cli "$T" status
  assert_eq "classes.local 登记后 → exit 0" 0 "$R_RC"
  # P1-3：sync 锚点（英文标题 + <!-- sync-body -->）
  T=$(new_case); run_cli "$T" init --yes
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
  T=$(new_case); run_cli "$T" init --yes
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  # shellcheck disable=SC2046
  run_cli_env "$T" $G audit --level S
  assert_eq "audit 内嵌验级（L1 无决策）→ exit 1" 1 "$R_RC"
  assert_contains "audit 输出级自洽 FAIL" "$R_OUT" "级自洽验证：未通过"
  # P1-2：深度信号4 仅 .meta 不升 M 档
  T=$(new_case); run_cli "$T" init --yes
  # shellcheck disable=SC2046
  run_cli_env "$T" $G audit
  assert_contains "仅 .meta 仍 S 档" "$R_OUT" "审计深度：S 档"
}

s22_hygiene_warn() {
  echo "--- 场景22：治理卫生 WARN（非 git / 游离计划 / 缺 .gitignore；exit 不变）"
  local T
  # 非 git 仓库 WARN + bootstrap 第 0 步与自证线
  T=$(new_case); run_cli "$T" init --yes
  run_cli "$T" status
  assert_eq "非 git status 仍 exit 0" 0 "$R_RC"
  assert_contains "WARN 非 git 仓库" "$R_OUT" "不在 git 仓库"
  grep -q 'git init' "$T/AGENTS.md" && ok "bootstrap 含第 0 步 git init" || bad "bootstrap 缺 git init"
  grep -q '无 FAIL 且无 WARN' "$T/AGENTS.md" && ok "bootstrap 自证线含无 WARN" || bad "bootstrap 自证线未升级"
  # 游离计划文档 WARN（git 仓库内，与上一条 WARN 隔离）
  T=$(new_case); run_cli "$T" init --yes
  ( cd "$T" && git init -q ) >/dev/null 2>&1
  printf '# plan\n' > "$T/IMPLEMENTATION_PLAN.md"
  run_cli "$T" status
  assert_eq "游离计划 status 仍 exit 0" 0 "$R_RC"
  assert_contains "WARN 游离计划文档" "$R_OUT" "游离计划文档"
  # git 仓库无 .gitignore WARN（init 已生成，删掉再测）
  T=$(new_case); run_cli "$T" init --yes
  ( cd "$T" && git init -q ) >/dev/null 2>&1
  rm -f "$T/.gitignore"
  run_cli "$T" status
  assert_contains "WARN 缺 .gitignore" "$R_OUT" "无 .gitignore"
  # 干净场景无卫生 WARN
  T=$(new_case); run_cli "$T" init --yes
  ( cd "$T" && git init -q ) >/dev/null 2>&1
  run_cli "$T" status
  assert_not_contains "干净场景无卫生 WARN" "$R_OUT" "WARN"
}

s23_verify_note() {
  echo "--- 场景23：write-adr/verify-note.sh 机械校验器正反例"
  local T; T=$(new_case)
  run_cli "$T" init --yes
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
  T=$(new_case); run_cli "$T" init --yes
  # shellcheck disable=SC2046
  run_cli_env "$T" $G audit --level S
  assert_contains "audit 含门禁分层参考" "$R_OUT" "门禁分层参考"
  assert_contains "本地层 pre-commit 无" "$R_OUT" "本地层 pre-commit（秒级）：无"
  assert_contains "中继层 pre-push 无" "$R_OUT" "中继层 pre-push（10秒级）：无"
  assert_contains "远端层 CI 无" "$R_OUT" "远端层 CI（分钟级）：无"
  assert_contains "缺本地层引导" "$R_OUT" "缺本地层"
  # 三层齐备：audit 应报三层全有、无缺层引导
  T=$(new_case); run_cli "$T" init --yes
  ( cd "$T" && mkdir -p .githooks .github/workflows \
      && printf '#!/usr/bin/env bash\necho fmt\n' > .githooks/pre-commit \
      && printf '#!/usr/bin/env bash\necho typecheck\n' > .githooks/pre-push \
      && printf 'name: ci\n' > .github/workflows/ci.yml \
      && git init -q && git config core.hooksPath .githooks ) >/dev/null 2>&1
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
  T=$(new_case); run_cli "$T" init --yes
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
  T=$(new_case); run_cli "$T" init --yes
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
  T=$(new_case); run_cli "$T" init --yes
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
  T=$(new_case); run_cli "$T" init --yes
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
  T=$(new_case); run_cli "$T" init --yes
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
  T=$(new_case); run_cli "$T" init --yes
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
  T=$(new_case); run_cli "$T" init --yes
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/2026-01-02-gate.md"
  printf '#!/usr/bin/env bash\ntouch "$(cd "$(dirname "$0")" && pwd)/WITNESS.txt"\nexit 0\n' \
    > "$T/.meta/gates/x.spec.sh"
  run_cli "$T" audit --run-specs
  assert_eq "--run-specs 全过 → exit 0" 0 "$R_RC"
  assert_contains "报执行判据" "$R_OUT" "2.3 执行判据"
  [ -f "$T/.meta/gates/WITNESS.txt" ] && ok "--run-specs 确实执行了 spec" || bad "--run-specs 未执行 spec"

  # ②b 护栏变量必须真导出给子进程（删掉导出前缀则此断言红——护栏不得静默失效）
  T=$(new_case); run_cli "$T" init --yes
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
  T=$(new_case); run_cli "$T" init --yes
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/2026-01-02-gate.md"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$T/.meta/gates/z.spec.sh"
  run_cli_env "$T" PONYGO_IN_SPEC=1 audit --run-specs
  assert_contains "递归护栏报 SKIPPED" "$R_OUT" "SKIPPED"
  assert_not_contains "SKIPPED 不得并入全部通过" "$R_OUT" "spec 全部自检通过"
  assert_contains "结论行限定未验证" "$R_OUT" "2.3 执行判据 SKIPPED——本次未验证"

  # ⑥ 无 *.spec.sh → SKIPPED（不计入 PASS），非 FAIL
  T=$(new_case); run_cli "$T" init --yes
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
  local T; T=$(new_case); run_cli "$T" init --yes
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/2026-01-02-gate.md"
  # L2 四件套：门禁脚本 + 负样本 spec + 本地钩子挂载 + 文档分层激活
  printf '#!/usr/bin/env bash\n[ -f README.md ] || exit 1\nexit 0\n' > "$T/.meta/gates/readme.sh"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$T/.meta/gates/readme.spec.sh"
  ( cd "$T" && git init -q && git config core.hooksPath .githooks && mkdir -p .githooks \
      && printf '#!/usr/bin/env bash\nexit 0\n' > .githooks/pre-commit ) >/dev/null 2>&1
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
  T=$(new_case); run_cli "$T" init --yes
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
  T=$(new_case); run_cli "$T" init --yes
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
  T=$(new_case); run_cli "$T" init --yes
  # init 在 mktemp 目录内，天然非 git——WARN 但 exit 0
  run_cli "$T" upgrade
  assert_eq "非 git 场景 upgrade exit 0" 0 "$R_RC"
  assert_contains "非 git WARN" "$R_OUT" "WARN 不在 git 仓库"
  # ⑤ 缺 meta.yaml/缺 level 行 → 按 L0 处理（不崩）
  T=$(new_case); run_cli "$T" init --yes
  rm -f "$T/.meta/meta.yaml"
  run_cli "$T" upgrade
  assert_eq "缺 meta.yaml upgrade exit 0（按 L0）" 0 "$R_RC"
  assert_contains "L0 处理" "$R_OUT" "L0"
  T=$(new_case); run_cli "$T" init --yes
  printf 'docs-tier: off\n' > "$T/.meta/meta.yaml"  # 有 meta.yaml 但无 level 行
  run_cli "$T" upgrade
  assert_eq "缺 level 行 upgrade exit 0（按 L0）" 0 "$R_RC"
  # ⑥ usage/parser 联动：--check 非 upgrade 拒绝；--check 与 --dry-run 互斥
  T=$(new_case); run_cli "$T" init --yes
  run_cli "$T" status --check
  assert_eq "status --check → exit 1（显式拒绝）" 1 "$R_RC"
  assert_contains "报仅适用于 upgrade" "$R_OUT" "仅适用于 'ponygo upgrade'"
  run_cli "$T" upgrade --check --dry-run
  assert_eq "upgrade --check --dry-run → exit 1（互斥）" 1 "$R_RC"
  assert_contains "报互斥" "$R_OUT" "互斥"
  # ⑦ 已激活 docs-tier 实例（P2-1）：docs-tier/README.md 不参与比对（s14 锁模板态）——
  #    upgrade exit 0 且不报该文件 drift；--check 仍 exit 0（不假红）
  T=$(new_case); run_cli "$T" init --yes
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
  run_cli "$T" observe status init --yes
  assert_eq "observe[A1] observe status init --yes → exit 1（不得执行 init）" 1 "$R_RC"
  assert_same_tree "observe[A1] observe status init --yes 零写（文件树快照不变）" "$T" "$SNAP0"
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
  run_cli "$T" observe init --kind cli --skill-dir "$SK" --yes
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
  T=$(new_case); SK=$(stage_skill "$T"); make_audit_case "$T" 0
  run_cli_env "$T" STUB_RC_CHECK_DECL=2 observe audit --skill-dir "$SK"
  assert_eq "observe[A5] 注释含占位/正文无占位 → ob1 未达 exit 1（占位不误判）" 1 "$R_RC"
  run_cli_stdout_env "$T" STUB_RC_CHECK_DECL=2 observe audit --skill-dir "$SK" --json
  assert_contains "observe[A5] 该声明 current=ob0（ob0 已达）" "$STD_OUT" '"current":"ob0"'
  assert_contains "observe[A5] no_placeholder 判 pass" "$STD_OUT" \
    '{"id":"no_placeholder","status":"pass"}'

  # ⑤ 参数校验（§5：init 各类输入错误 → 2）
  T=$(new_case); SK=$(stage_skill "$T")
  run_cli "$T" observe init --skill-dir "$SK" --yes
  assert_eq "observe init 缺 --kind → exit 2" 2 "$R_RC"
  run_cli "$T" observe init --kind bogus --skill-dir "$SK" --yes
  assert_eq "observe init --kind bogus → exit 2" 2 "$R_RC"
  run_cli "$T" observe init --kind cli --service 'a: b' --skill-dir "$SK" --yes
  assert_eq "observe init --service 'a: b'（YAML 注入形状）→ exit 2" 2 "$R_RC"
  run_cli "$T" observe init --kind cli --service 'svc-a' --skill-dir "$SK" --yes
  assert_eq "observe init 合法 service 名 exit 0" 0 "$R_RC"
  run_cli "$T" observe init --kind cli --service 'svc-a' --skill-dir "$SK" --yes
  assert_eq "observe init 声明已存在且无 --force → exit 2" 2 "$R_RC"
  run_cli "$T" observe init --kind cli --service 'svc-a' --skill-dir "$SK" --force --yes
  assert_eq "observe init --force 覆盖 → exit 0" 0 "$R_RC"

  # ⑥ 全参 init 一条命令达 ob0（--dims 内 applicable:true + anchor，外 false + reason）
  T=$(new_case); SK=$(stage_skill "$T"); mkdir -p "$T/src"
  : > "$T/src/tracing.txt"; : > "$T/src/issues.txt"
  run_cli "$T" observe init --kind cli --skill-dir "$SK" --yes \
    --dims tracing,issues --anchor-tracing src/tracing.txt --anchor-issues src/issues.txt \
    --reason-metrics "指标由 k8s 侧采集" --reason-logs "日志走集群采集"
  assert_eq "observe init 全参 exit 0" 0 "$R_RC"
  DECL=$(decl_file "$T") || DECL=""
  TXT=$(cat "$DECL" 2>/dev/null || :)
  assert_not_contains "observe init 全参声明无占位残留" "$TXT" "__REPLACE_ME__"
  assert_contains "observe init 全参：dims 外 applicable: false" "$TXT" "applicable: false"
  assert_contains "observe init 全参：dims 内 anchor 写入" "$TXT" "src/tracing.txt"
  assert_contains "observe init 全参：dims 外 reason 写入" "$TXT" "指标由 k8s 侧采集"
  run_cli_env "$T" STUB_RC_CHECK_DECL=2 observe audit --skill-dir "$SK"
  assert_eq "observe audit（全参 + stub rc=2）→ ob1 未达 exit 1" 1 "$R_RC"

  # ⑦ A8 版本门：<skill>/references/contract.json 是唯一版本源；低版本 init → 2
  T=$(new_case); SKL=$(stage_skill "$T" 0.9.9)
  run_cli "$T" observe init --kind cli --skill-dir "$SKL" --yes
  assert_eq "observe[A8] contract 0.9.9（低于 1.0.3）init → exit 2" 2 "$R_RC"
  assert_contains "observe[A8] 低版本提示 min 版本 1.0.3" "$R_OUT" "1.0.3"
  T=$(new_case); SK=$(stage_skill "$T")
  run_cli_env "$T" PONYGO_SKILL_DIR="$SK" observe init --kind cli --yes
  assert_eq "observe[A8] PONYGO_SKILL_DIR 注入 init exit 0" 0 "$R_RC"
  T=$(new_case)
  run_cli "$T" observe init --kind cli --skill-dir "$T/根本没有这个 skill" --yes
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
  run_cli "$T" observe init --kind cli --skill-dir "$SK" --yes
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
  run_cli "$T" observe init --kind cli --skill-dir "$SK" --yes \
    --dims metrics --reason-tracing $'x\n  metrics:\n    applicable: false'
  assert_eq "observe[F1] --reason-tracing 含换行（YAML 注入）→ exit 2" 2 "$R_RC"
  assert_same_tree "observe[F1] 注入被拒后不落盘（文件树快照不变）" "$T" "$SNAP0"
  assert_eq "observe[F1] 注入被拒后无声明文件" "no" \
    "$([ -f "$T/docs/observability.yaml" ] && echo yes || echo no)"
  run_cli "$T" observe init --kind cli --skill-dir "$SK" --yes --anchor-metrics 'src/a: b.ts'
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

echo ""
echo "==== 测试结果：pass=$PASS fail=$FAIL ===="
[ "$FAIL" -eq 0 ] || exit 1
exit 0

