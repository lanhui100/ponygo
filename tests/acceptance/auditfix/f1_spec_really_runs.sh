#!/usr/bin/env bash
# F1（P0-1）：--run-specs 必须**真跑** spec，不得让框架资产被自己注入的护栏挡成 SKIPPED。
#   F1-1 真跑：GO `2.3 spec 自检：`；NOGO `[skipped] 2.3 spec 自检：`（逐条 + 逐字）
#   F1-2 聚合行必须反映真跑通过：GO `2 个 spec 全部自检通过`；NOGO `全部自报 SKIPPED`/`本次未真正跑门`
#   F1-4 真跑可被外界观测：spec 的副作用探针 WITNESS 必须留下（物理收据，非纯文本）
#   反向：spec 改为 exit 1 → audit 非零（坏门不得变绿）
# 冻结契约来源：.dev-team/contract-matrix-auditfix.md F1-1/F1-2/F1-4（【L】/【C】）。
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# ---- 正例 ----
T=$(new_case)
if gov_repo "$T" 1; then
  cat > "$T/.meta/gates/zz-fake.spec.sh" <<'SPECEOF'
#!/usr/bin/env bash
# 验收夹具：一个「会拒绝非法样本」的假 spec（打印 [ok]、留物理探针、exit 0）
set -u
printf 'witness\n' > .meta/gates/WITNESS.txt
printf '[zz-fake.spec] [ok] 假门拒绝了非法样本，放行了合法样本（夹具）\n'
exit 0
SPECEOF
  chmod +x "$T/.meta/gates/zz-fake.spec.sh"
  rm -f "$T/.meta/gates/WITNESS.txt"

  run_in "$T" audit --run-specs
  assert_contains "F1-1 GO：--run-specs 输出含「2.3 spec 自检：」" "$R_OUT" "2.3 spec 自检："
  assert_not_contains "F1-1 NOGO：不得出现「[skipped] 2.3 spec 自检：」（框架资产必须真跑）" \
    "$R_OUT" "[skipped] 2.3 spec 自检："
  assert_not_contains "F1-1 NOGO：不得出现「自报 SKIPPED」" "$R_OUT" "自报 SKIPPED"
  assert_contains "F1-1 真跑取证：假 spec 已被执行（输出含其文件名）" "$R_OUT" "zz-fake.spec.sh"
  assert_contains "F1-1 真跑取证：输出含「2.3 执行判据」段" "$R_OUT" "2.3 执行判据"
  assert_contains "F1-2 GO：聚合行声明 2 个 spec 全部自检通过" "$R_OUT" "2 个 spec 全部自检通过"
  assert_not_contains "F1-2 NOGO：不得出现「全部自报 SKIPPED」" "$R_OUT" "全部自报 SKIPPED"
  assert_not_contains "F1-2 NOGO：不得出现「本次未真正跑门」" "$R_OUT" "本次未真正跑门"
  assert_exists "F1-4 物理收据：spec 副作用探针 WITNESS.txt 已产生" "$T/.meta/gates/WITNESS.txt"
  assert_zero "F1 正例：全部 spec 真跑通过 → audit exit 0" "$R_RC"
fi

# ---- 反例：spec 真的会失败 → audit 必须非零（不得把坏门当绿灯） ----
T=$(new_case)
if gov_repo "$T" 1; then
  cat > "$T/.meta/gates/zz-fake.spec.sh" <<'SPECEOF'
#!/usr/bin/env bash
# 验收夹具：假门接受了一个非法样本 → spec 自检必须失败
set -u
printf '[zz-fake.spec] [fail] 假门接受了非法样本（夹具）\n'
exit 1
SPECEOF
  chmod +x "$T/.meta/gates/zz-fake.spec.sh"

  run_in "$T" audit --run-specs
  assert_nonzero "F1 反例：spec exit 1 → audit 非零退出" "$R_RC"
fi

finish
