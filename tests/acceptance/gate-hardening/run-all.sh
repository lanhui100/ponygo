#!/usr/bin/env bash
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
  gh5_release_scratch.sh
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
