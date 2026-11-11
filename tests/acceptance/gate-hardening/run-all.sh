#!/usr/bin/env bash
# Windows 编码硬化（CI 实跑 run 43031069740）：cp1252 控制台下 python3 打印中文会抛
# UnicodeEncodeError → rc=1 且无 stdout（gh2 3/1、gh3 9/1、gh6 83/8 均为其连锁反应）。
# 在调用任何 python3 之前强制 UTF-8；standalone 执行时由本文件/lib.sh 顶部覆盖生效。
export PYTHONUTF8=1 PYTHONIOENCODING=utf-8
# gate-hardening 独立验收入口：所有 case 均运行；任一 RED 整体 exit 1。
set -u
DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
FAILED=0
TOTAL=0
for case_file in \
  gh1_spec_execution.sh \
  gh2_ci_aggregate.sh \
  gh3_checklist_alignment.sh \
  gh4_gate_spec_pairing.sh \
  gh5_release_scratch.sh \
  gh6_test_tiering_contract.sh
do
  TOTAL=$((TOTAL+1))
  printf '\n===== %s =====\n' "$case_file"
  bash "$DIR/$case_file"
  rc=$?
  printf '##EXIT %s rc=%s\n' "$case_file" "$rc"
  if [ "$rc" -ne 0 ]; then FAILED=$((FAILED+1)); fi
done
printf '\n##SUMMARY gate-hardening cases=%s failed=%s\n' "$TOTAL" "$FAILED"
if [ "$FAILED" -ne 0 ]; then exit 1; fi
exit 0
