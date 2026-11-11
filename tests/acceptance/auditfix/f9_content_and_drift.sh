#!/usr/bin/env bash
# F9（封版前最后一批：Wave-6「六处口径统一」的回归网缺口，Lead 授权）
# delta 终审变异实验证明：把 2.1 的 file_has_content 换回 `[ -s ]`、把 status 的
# `|| st_drift=$((st_drift+1))` 换成 `|| true`，三套测试仍全绿 → 4 处口径零回归网。
# 本文件逐条钉死（每条都成对：负样本必须被判、正样本必须仍通过）：
#   F9-1 2.1 级自洽「实质门禁」：gates/ 只有注释-only .sh → 2.1 FAIL（rc=1）；正对照（真有内容）→ 无 2.1 FAIL
#   F9-2 2.3 形状判据：只有注释-only *.spec.sh → `2.3 gates/ 无负样本 spec`（不算作有 spec）；且 2.1 仍 PASS
#   F9-3 audit ② 实质门禁计分：注释-only gates/*.sh 不计分（与真有内容对照，命中差恰 1）
#   F9-4 upgrade 的 gates/README 条件分支：注释-only → 「缺骨架文件」；真有内容 → 「已有实质门禁但缺 README」
#   F9-5 status 逐字节比对：篡改 → 「内容漂移 1 处」+「逐字节比对」且不得「与模板一致」；恢复 → 「与模板一致」
#   F9-6 repair 锁告警：.git/ponygo-init.lock 被占成目录 → 输出「无法打开骨架补齐锁文件」且 rc=0
# 冻结契约来源：Lead 授权（封版前回归网补齐）；判据口径真源 = ponygo W6「有效内容为空」。
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

COMMENT_ONLY='# nothing here（注释-only：有效内容为空）'

# ================= F9-1 2.1「实质门禁」判据 =================
# 负样本：gates/ 只剩注释-only 文件（且无任何有内容的 *.sh / *.spec.*）→ 2.1 FAIL
# 注意：骨架文件必须在位（否则 status 会先报「骨架文件缺口」并早退，走不到级自洽验证），
# 故把交付的三个门禁资产清成空文件（存在但无有效内容）+ 一个注释-only 门禁。
T=$(new_case)
if gov_repo "$T" 2; then
  : > "$T/.meta/gates/adr-verify.sh"
  : > "$T/.meta/gates/adr-verify.spec.sh"
  : > "$T/.meta/gates/ci-verify.sh"
  # 新增 A6/A7 同属骨架门禁资产；若保留有效内容，本负样本根本走不到「无实质门禁」分支。
  : > "$T/.meta/gates/archive-verify.sh"
  : > "$T/.meta/gates/archive-verify.spec.sh"
  # 负空间批次新增 A8/A9（no-residue 门 + 其负样本 spec）同样属**骨架交付资产**：
  # 只要它们留着有效内容，本负样本就永远走不到「无实质门禁」分支（夹具假绿面）→ 同步清空。
  : > "$T/.meta/gates/no-residue.sh"
  : > "$T/.meta/gates/no-residue.spec.sh"
  # P0-2（2026-11-11）：gov_repo(2) 现在会加装一对合规实例门（instance-gate.sh/.spec.sh）；
  # 它同样是「有实质内容」的门，不清空就永远走不到「无实质门禁」分支（夹具假绿面）→ 同步清空。
  : > "$T/.meta/gates/instance-gate.sh"
  : > "$T/.meta/gates/instance-gate.spec.sh"
  printf '%s\n' "$COMMENT_ONLY" > "$T/.meta/gates/comment-only-gate.sh"
  chmod +x "$T/.meta/gates/comment-only-gate.sh"
  run_in "$T" status
  assert_rc_is "F9-1a gates/ 只有注释-only/空 .sh → status exit 1" 1 "$R_RC"
  assert_contains "F9-1a GO：2.1 判据报无实质门禁文件" "$R_OUT" "2.1 gates/ 无实质门禁文件"
  assert_not_contains "F9-1a 夹具：未落到「骨架文件缺口」早退分支" "$R_OUT" "骨架文件缺口"
fi

# 正对照：gates/ 有真有内容的门禁（init 交付的 A1）→ 2.1 不得报 FAIL
T=$(new_case)
if gov_repo "$T" 2; then
  run_in "$T" status
  assert_zero "F9-1b 正对照：有实质门禁 → status exit 0" "$R_RC"
  assert_not_contains "F9-1b NOGO：不得报 2.1 无实质门禁文件" "$R_OUT" "2.1 gates/ 无实质门禁文件"
fi

# ================= F9-2 2.3「负样本 spec」形状判据 =================
# 注释-only 的 *.spec.sh 不算 spec 形状成立；同时 2.1 仍 PASS（A1 有内容）证明两条口径相互独立
T=$(new_case)
if gov_repo "$T" 2; then
  # 骨架文件在位（不早退），但唯一的 *.spec.* 只有注释 → 2.3 形状判据不成立
  printf '%s\n' "$COMMENT_ONLY" > "$T/.meta/gates/adr-verify.spec.sh"
  # A7 也是负样本 spec；必须同步为注释-only，才能继续检验「仓内无任何有效 spec」的 2.3 分支。
  printf '%s\n' "$COMMENT_ONLY" > "$T/.meta/gates/archive-verify.spec.sh"
  # A9（no-residue.spec.sh）同属骨架交付的负样本 spec——不清成注释-only，2.3 永远 PASS。
  printf '%s\n' "$COMMENT_ONLY" > "$T/.meta/gates/no-residue.spec.sh"
  # P0-2/P0-3（2026-11-11）：gov_repo(2) 加装的实例门 spec 也是有效 spec，同样要清成注释-only。
  printf '%s\n' "$COMMENT_ONLY" > "$T/.meta/gates/instance-gate.spec.sh"
  chmod +x "$T/.meta/gates/adr-verify.spec.sh" "$T/.meta/gates/archive-verify.spec.sh" \
    "$T/.meta/gates/no-residue.spec.sh" "$T/.meta/gates/instance-gate.spec.sh"
  run_in "$T" status
  assert_rc_is "F9-2 注释-only spec → status exit 1（2.3 形状不成立）" 1 "$R_RC"
  assert_contains "F9-2 GO：报「2.3 gates/ 无负样本 spec」" "$R_OUT" "2.3 gates/ 无负样本 spec"
  assert_not_contains "F9-2 正对照：2.1 不得因 spec 变红（A1 仍有内容）" "$R_OUT" "2.1 gates/ 无实质门禁文件"
fi

# ================= F9-3 audit ② 实质门禁计分 =================
T=$(new_case)
if gov_repo "$T" 1; then
  rm -f "$T"/.meta/gates/*.spec.* 2>/dev/null
  # 唯一变量必须是 my-gate.sh：A8（no-residue.sh，骨架交付、自带有效内容）会先占住
  # 「gates/ 有实例实质门禁」这一分，让「注释-only 不计分」的 +1 差分恒为 0 → 清空隔离。
  : > "$T/.meta/gates/no-residue.sh"
  printf '%s\n' "$COMMENT_ONLY" > "$T/.meta/gates/my-gate.sh"
  chmod +x "$T/.meta/gates/my-gate.sh"
  run_in "$T" audit --level M
  HIT_C=$(hits_n_of "$R_OUT")
  assert_matches "F9-3 夹具：注释-only 门禁下仍可解析命中数（[$HIT_C]）" "$HIT_C" '^[0-9]+$'

  printf '#!/usr/bin/env bash\n# 真有内容的门禁\nprintf "deny\\n" >&2\nexit 1\n' > "$T/.meta/gates/my-gate.sh"
  chmod +x "$T/.meta/gates/my-gate.sh"
  run_in "$T" audit --level M
  HIT_R=$(hits_n_of "$R_OUT")
  assert_matches "F9-3 夹具：真有内容门禁下仍可解析命中数（[$HIT_R]）" "$HIT_R" '^[0-9]+$'
  if [ -n "$HIT_C" ] && [ -n "$HIT_R" ]; then
    assert_eq "F9-3 注释-only 门禁不计分（真有内容必须恰 +1：注释=$HIT_C / 真内容=$HIT_R）" \
      "$((HIT_C + 1))" "$HIT_R"
  fi
  assert_eq "F9-3 M 档总项数仍为 16" 16 "$(hits_t_of "$R_OUT")"
fi

# ================= F9-4 upgrade 的 gates/README 条件分支 =================
T=$(new_case)
if gov_repo "$T" 1; then
  rm -f "$T"/.meta/gates/* 2>/dev/null
  printf '%s\n' "$COMMENT_ONLY" > "$T/.meta/gates/my-gate.sh"
  chmod +x "$T/.meta/gates/my-gate.sh"
  run_in "$T" upgrade
  GAP_LINE=$(printf '%s\n' "$R_OUT" | grep -F '缺口: .meta/gates/README.md' | head -n1)
  assert_contains "F9-4a GO：注释-only 门禁 → 走「缺骨架文件」分支" "$GAP_LINE" "缺骨架文件"
  assert_not_contains "F9-4a NOGO：不得声称「已有实质门禁」" "$GAP_LINE" "已有实质门禁"

  printf '#!/usr/bin/env bash\n# 真有内容\nexit 1\n' > "$T/.meta/gates/my-gate.sh"
  chmod +x "$T/.meta/gates/my-gate.sh"
  run_in "$T" upgrade
  GAP_LINE2=$(printf '%s\n' "$R_OUT" | grep -F '缺口: .meta/gates/README.md' | head -n1)
  assert_contains "F9-4b GO：真有内容门禁 → 走「已有实质门禁但缺 README」分支" "$GAP_LINE2" "已有实质门禁"
fi

# ================= F9-5 status 的逐字节比对 =================
T=$(new_case)
if gov_repo "$T" 2; then
  run_in "$T" status
  assert_contains "F9-5a 基线：status 声明骨架文件与模板一致" "$R_OUT" "与模板一致"
  assert_not_contains "F9-5a 基线：不得报内容漂移" "$R_OUT" "内容漂移"

  KEEP=$(mktemp "$SBASE/ci-verify.XXXXXX")
  cp "$T/.meta/gates/ci-verify.sh" "$KEEP"
  printf '# 篡改：追加一行（drift 探针）\n' >> "$T/.meta/gates/ci-verify.sh"
  run_in "$T" status
  assert_contains "F9-5b GO：篡改后报「内容漂移 1 处」" "$R_OUT" "内容漂移 1 处"
  assert_contains "F9-5b GO：声明比对口径为「逐字节比对」" "$R_OUT" "逐字节比对"
  assert_not_contains "F9-5b NOGO：篡改后不得再声称「与模板一致」" "$R_OUT" "与模板一致"

  cp "$KEEP" "$T/.meta/gates/ci-verify.sh"
  run_in "$T" status
  assert_contains "F9-5c 恢复后：status 重新声明「与模板一致」" "$R_OUT" "与模板一致"
  assert_not_contains "F9-5c 恢复后：不得再报内容漂移" "$R_OUT" "内容漂移"
fi

# ================= F9-6 repair 锁告警 =================
T=$(new_case)
if gov_repo "$T" 1; then
  rm -f "$T/.agents/notes/README.md"     # 造缺口，确保走到补缺写路径
  if command -v flock >/dev/null 2>&1; then
    rm -f "$T/.git/ponygo-init.lock"
    mkdir -p "$T/.git/ponygo-init.lock"  # 用目录占住锁文件 → exec 8>> 打不开
    run_in "$T" init --repair-skeleton
    assert_contains "F9-6 GO：锁文件不可打开时给出「无法打开骨架补齐锁文件」告警" \
      "$R_OUT" "无法打开骨架补齐锁文件"
    assert_zero "F9-6 无锁仍继续补缺 → exit 0" "$R_RC"
    assert_exists "F9-6 取证：骨架缺口仍被补齐" "$T/.agents/notes/README.md"
  else
    ok "F9-6 环境无 flock（走 mkdir 降级锁）→ 本条不适用，跳过"
  fi
fi

finish
