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
  dir="$1/.meta/decisions/$(dirname "$2")"
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
    [ -d "$T/.meta/decisions/$d" ] && ok "decisions/$d 存在" || bad "decisions/$d 缺失"
  done
  for d in constitution gates skills docs-tier; do
    [ -d "$T/.meta/$d" ] && ok ".meta/$d 存在" || bad ".meta/$d 缺失"
  done
  [ -f "$T/.meta/meta.yaml" ] && ok "meta.yaml 存在" || bad "meta.yaml 缺失"
  grep -q '^level: 0' "$T/.meta/meta.yaml" && ok "level: 0" || bad "level 字段异常"
  [ -f "$T/.meta/decisions/README.md" ] && ok "decisions/README.md 生成" || bad "decisions/README.md 缺失"
  [ ! -f "$T/AGENTS.md" ] && [ ! -f "$T/CLAUDE.md" ] && ok "模板态不投影" || bad "模板态不应投影"
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

s04_todo_reject() {
  echo "--- 场景4：TODO 拒投影"
  local T; T=$(new_case)
  run_cli "$T" init --yes
  run_cli "$T" sync
  [ "$R_RC" -ne 0 ] && ok "TODO 模板 sync exit 非 0" || bad "TODO 模板 sync 应拒绝"
  assert_contains "报槽位未填" "$R_OUT" "槽位未填"
  [ ! -f "$T/AGENTS.md" ] && [ ! -f "$T/CLAUDE.md" ] && ok "无投影文件" || bad "不应生成投影文件"
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
  local T T2; T=$(new_case); T2=$(new_case)
  run_cli "$T" init --yes; write_constitution_filled "$T"
  printf 'ai-surface: off\n' >> "$T/.meta/meta.yaml"
  run_cli "$T" sync
  assert_eq "ai-surface: off → sync exit 0" 0 "$R_RC"
  [ ! -f "$T/AGENTS.md" ] && [ ! -f "$T/CLAUDE.md" ] && ok "off 不投影" || bad "off 仍投影"
  assert_contains "提示 off 跳投影" "$R_OUT" "ai-surface: off"
  run_cli "$T2" init --yes; write_constitution_filled "$T2"
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
  assert_contains "S 档命中 4 / 10" "$R_OUT" "命中 4 / 10"
  # shellcheck disable=SC2046
  run_cli_env "$T" $G audit --level M
  assert_contains "M 档命中 4 / 14" "$R_OUT" "命中 4 / 14"
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
  sed -i 's/^Status: implemented/Status: proposed/' "$T/.meta/decisions/implemented/feature/2026-01-02-x.md"
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
  sed -i 's/^Status: implemented/Status: rejected/' "$T/.meta/decisions/archived/testing/2026-01-02-old.md"
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
  mkdir -p "$T/.meta/decisions/implemented/feature/extra"
  cp "$T/.meta/decisions/implemented/feature/2026-01-02-x.md" "$T/.meta/decisions/implemented/feature/extra/2026-01-02-deep.md"
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
  sed -i 's/$/\r/' "$T/.meta/decisions/implemented/feature/2026-01-02-crlf.md"
  run_cli "$T" status
  assert_eq "CRLF 决策文件不假 FAIL（1.7）→ exit 0" 0 "$R_RC"
}

s12_l2_criteria() {
  echo "--- 场景12：L2 判据（齐 → 过；缺钩子 → FAIL）"
  local T
  T=$(new_case); run_cli "$T" init --yes
  printf 'level: 1\n' > "$T/.meta/meta.yaml"
  write_valid_decision "$T" "implemented/feature/2026-01-02-gate.md"
  printf 'level: 2\n' > "$T/.meta/meta.yaml"
  ( cd "$T" && git init -q && git config core.hooksPath .githooks \
      && mkdir -p .githooks && printf '#!/usr/bin/env bash\necho hook\n' > .githooks/pre-commit ) >/dev/null 2>&1
  printf '#!/usr/bin/env bash\nexit 0\n' > "$T/.meta/gates/format.sh"
  printf 'purpose: negative sample spec\n' > "$T/.meta/gates/format.spec.md"
  run_cli "$T" status
  assert_eq "门禁+spec+钩子齐 → exit 0" 0 "$R_RC"
  assert_contains "L0-L2 通过" "$R_OUT" "L0-L2"
  assert_contains "2.2 标注代理判据" "$R_OUT" "代理判据"

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

  T=$(new_case); run_cli "$T" init --yes
  printf '# comment\r\n\r\nlevel: 0\r\n' > "$T/.meta/meta.yaml"
  run_cli "$T" status
  assert_not_contains "CRLF meta.yaml 不假 WARN" "$R_OUT" "WARN"
  assert_eq "CRLF meta.yaml status exit 0" 0 "$R_RC"
}

s14_decisions_readme() {
  echo "--- 场景14：生成 decisions/ skills/ README 与模板 eol 归一逐字节一致（F3 + skills 契约）"
  local T; T=$(new_case)
  run_cli "$T" init --yes
  if diff <(tr -d '\r' < "$T/.meta/decisions/README.md") \
          <(tr -d '\r' < "$ROOT/.meta/decisions/README.md") >/dev/null 2>&1; then
    ok "生成 decisions/README 与模板 eol 归一后一致"
  else
    bad "生成 decisions/README 与模板不一致"
  fi
  if diff <(tr -d '\r' < "$T/.meta/skills/README.md") \
          <(tr -d '\r' < "$ROOT/.meta/skills/README.md") >/dev/null 2>&1; then
    ok "生成 skills/README 与模板 eol 归一后一致（含五要素契约）"
  else
    bad "生成 skills/README 与模板不一致"
  fi
  grep -q '五要素' "$T/.meta/skills/README.md" && ok "skills 契约含五要素" || bad "skills 契约缺五要素"
  if diff <(tr -d '\r' < "$T/.meta/docs-tier/README.md") \
          <(tr -d '\r' < "$ROOT/.meta/docs-tier/README.md") >/dev/null 2>&1; then
    ok "生成 docs-tier/README 与模板 eol 归一后一致（含 tier 模板）"
  else
    bad "生成 docs-tier/README 与模板不一致"
  fi
}

s15_upgrade() {
  echo "--- 场景15：upgrade exit 0"
  run_cli "$(new_case)" upgrade
  assert_eq "upgrade exit 0" 0 "$R_RC"
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
  echo "--- 场景18：F1 口径 grep（checklist.md 骨架8/机制15/精微8）+ .gitattributes"
  if grep -Eq '骨架[[:space:]]*8|8[[:space:]]*项' "$ROOT/audit/checklist.md" 2>/dev/null; then
    ok "checklist.md 含骨架层数 8"
  else
    bad "checklist.md 缺骨架层数 8 口径"
  fi
  if grep -Eq '机制[[:space:]]*15|15[[:space:]]*项' "$ROOT/audit/checklist.md" 2>/dev/null; then
    ok "checklist.md 含机制层数 15"
  else
    bad "checklist.md 缺机制层数 15 口径"
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
  mkdir -p "$T/.meta/decisions/random-stuff"
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
  sed -i '/^Status:/d' "$T/.meta/decisions/implemented/feature/2026-01-02-c.md"
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
s04_todo_reject
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
  printf '# 领域扩展\ndomain-x\n' > "$T/.meta/decisions/classes.local"
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

s20_installer
s21_external001_regress

echo ""
echo "==== 测试结果：pass=$PASS fail=$FAIL ===="
[ "$FAIL" -eq 0 ] || exit 1
exit 0

