#!/usr/bin/env bash
# N3（fail-closed 参数面）：全树兜底门 ci-verify.sh 只接受**零参数**调用；
#   任何未知参数都必须 fail-closed（exit 1 + 明示未知/用法），不得静默忽略后照跑整套门——
#   静默忽略的后果是「CI 里传错旗标，门照常绿」，等于把承诺变成装饰。
#   被测契约（Lead 裁决，exec-core C5）：「ci-verify.sh：未知参数 fail-closed（exit 1）」。
#   本用例只读调用仓库真实资产，不写任何文件。
# 冻结契约来源：团队 task-3（修复 A · exec-core C5）、task-5（修复 C · T3-N3）。
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

assert_exists "N3 夹具：被测门 A4 资产在场" "$CI_VERIFY_SH"

# 每个未知参数形态都要被拒（长短旗标各一，防只做了 `-*` 或只做了 `--*` 的半吊子实现）
for bad_arg in --bogus-flag -x; do
  run_timeout_in "$ROOT" 120 "$CI_VERIFY_SH" "$bad_arg"
  assert_rc_is "N3 未知参数「$bad_arg」→ exit 1（fail-closed）" 1 "$R_RC"
  assert_matches "N3 GO：「$bad_arg」报未知参数类文案" "$R_OUT" '未知参数|不认识的参数|未知选项|用法|usage|Usage'
  assert_not_contains "N3 NOGO：「$bad_arg」不得给出通过结论（静默忽略 = 假绿）" "$R_OUT" "ci-verify: 通过"
  assert_no_crash "N3 未知参数「$bad_arg」不得炸栈" "$R_OUT"
done

# 未知参数必须在开跑门禁之前就拒（否则「参数错但仍跑了 3 段门」会掩盖门禁本身的状态）
run_timeout_in "$ROOT" 120 "$CI_VERIFY_SH" --bogus-flag
assert_not_matches "N3 NOGO：未知参数不得先跑第 1 段门（应在解析参数时即拒）" "$R_OUT" '== \[1/[0-9]'
assert_not_contains "N3 NOGO：未知参数不得报告任何门禁段结果" "$R_OUT" "全树 ADR 格式门未通过"

# 位置参数同样属于「未知参数」：不做静默忽略
run_timeout_in "$ROOT" 120 "$CI_VERIFY_SH" "some-positional"
assert_rc_is "N3 位置参数 → exit 1（不静默忽略）" 1 "$R_RC"
assert_not_contains "N3 NOGO：位置参数不得给出通过结论" "$R_OUT" "ci-verify: 通过"

finish
