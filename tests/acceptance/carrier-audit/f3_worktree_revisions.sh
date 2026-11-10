#!/usr/bin/env bash
# CA-17~20：linked worktree 贡献者同选 M；无 revisions/ 普通实例静默 N/A。
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

command -v python3 >/dev/null 2>&1 || { bad "CA-17~20 需要 python3 解析真实 JSON"; finish; }

# ---------- CA-17：主工作树 / linked worktree 同一 HEAD、同一三位贡献者 ----------
MAIN=$(new_case)
git_at "$MAIN" init -q . >/dev/null 2>&1 || { bad "CA-17 夹具 git init 失败"; finish; }
for spec in 'Alice|alice@example.test' 'Bob|bob@example.test' 'Carol|carol@example.test'; do
  name=${spec%%|*}; email=${spec#*|}
  printf '%s\n' "$name" >> "$MAIN/contributors.txt"
  git_at "$MAIN" add contributors.txt >/dev/null 2>&1
  git_at "$MAIN" -c user.name="$name" -c user.email="$email" -c commit.gpgsign=false \
    commit -qm "commit by $name" >/dev/null 2>&1
  assert_rc_is "CA-17 夹具：$name 提交成功" 0 "$?"
done
MAIN_HEAD=$(git_at "$MAIN" rev-parse HEAD)
CONTRIB=$(git_at "$MAIN" shortlog -sne HEAD | wc -l | tr -d ' ')
assert_eq "CA-17 夹具：主工作树贡献者恰为 3" 3 "$CONTRIB"
run_json "$MAIN" audit --json
MAIN_RC=$R_RC; MAIN_JSON=$R_OUT; MAIN_HUMAN=$R_ERR
assert_rc_is "CA-17 正对照：主工作树 audit" 0 "$MAIN_RC"
assert_json_shape "CA-17 主工作树" "$MAIN_RC" "$MAIN_JSON"
json_assert "CA-17 正对照：主工作树自适应 M，total=15" "$MAIN_JSON" "
if d.get('tier') != 'M': fail.append(d.get('tier'))
if d.get('total') != 15: fail.append(d.get('total'))
"
assert_contains "CA-17 正对照：人读触发理由贡献者≥3(3)" "$MAIN_HUMAN" "贡献者≥3(3)"
MAIN_LINE=$(printf '%s\n' "$MAIN_HUMAN" | grep '审计深度：' | head -n1)
assert_contains "CA-17 正对照：主工作树档位行非空且为 M" "$MAIN_LINE" "审计深度：M 档"
MAIN_HITS=$(json_get "$MAIN_JSON" "d['hits']")

LINK="$SBASE/linked-worktree"
git_at "$MAIN" worktree add --detach "$LINK" HEAD >"$SBASE/worktree-add.log" 2>&1
assert_rc_is "CA-17 夹具：git worktree add" 0 "$?"
assert_file "CA-17 夹具：linked worktree 的 .git 必须是文件" "$LINK/.git"
assert_eq "CA-17 夹具：linked 与主工作树 HEAD 相同" "$MAIN_HEAD" "$(git_at "$LINK" rev-parse HEAD)"
run_json "$LINK" audit --json
assert_rc_is "CA-17 GO：linked worktree 与主仓退出码相同" "$MAIN_RC" "$R_RC"
assert_json_shape "CA-17 linked worktree" "$R_RC" "$R_OUT"
json_assert "CA-17 GO：linked worktree 同样自适应 M，total=15" "$R_OUT" "
if d.get('tier') != 'M': fail.append(d.get('tier'))
if d.get('total') != 15: fail.append(d.get('total'))
if d.get('hits') != $MAIN_HITS: fail.append('hits=%r main=$MAIN_HITS' % d.get('hits'))
"
assert_contains "CA-17 GO：linked 人读同样报告贡献者≥3(3)" "$R_ERR" "贡献者≥3(3)"
LINK_LINE=$(printf '%s\n' "$R_ERR" | grep '审计深度：' | head -n1)
assert_contains "CA-17 GO：linked 档位行非空且为 M" "$LINK_LINE" "审计深度：M 档"
assert_eq "CA-17 GO：同提交两工作树档位与触发理由逐字一致" "$MAIN_LINE" "$LINK_LINE"

# CA-17 反例：父仓已有 3 位贡献者，普通无 .git 子目录不得继承父仓贡献者升 M。
CHILD="$MAIN/plain-child"
mkdir -p "$CHILD"
printf '普通子目录，不是独立 git 工作树\n' > "$CHILD/README.txt"
assert_missing "CA-17 反例夹具：普通子目录自身确无 .git" "$CHILD/.git"
run_json "$CHILD" audit --json
assert_rc_is "CA-17 反例：普通子目录保持既有退出码" 0 "$R_RC"
assert_json_shape "CA-17 普通无 .git 子目录" "$R_RC" "$R_OUT"
json_assert "CA-17 反例 GO：父仓三贡献者不得让普通子目录误判 M，期望 S=10" "$R_OUT" "
if d.get('tier') != 'S': fail.append(d.get('tier'))
if d.get('total') != 10: fail.append(d.get('total'))
"
assert_contains "CA-17 反例 GO：人读必须为 S 档" "$R_ERR" "审计深度：S 档"
assert_not_contains "CA-17 反例 NOGO：不得伪造继承父仓的贡献者理由" "$R_ERR" "贡献者≥3"

# ---------- CA-18：非 git / unborn HEAD 不崩溃、不伪造贡献者 ----------
for mode in non-git unborn; do
  T=$(new_case)
  if [ "$mode" = "unborn" ]; then
    git_at "$T" init -q . >/dev/null 2>&1
    assert_rc_is "CA-18 夹具：unborn git init" 0 "$?"
  fi
  run_json "$T" audit --json
  assert_rc_is "CA-18($mode) 保持既有退出码" 0 "$R_RC"
  assert_json_shape "CA-18($mode)" "$R_RC" "$R_OUT"
  json_assert "CA-18($mode) GO：不命中贡献者重型信号，保持 S=10" "$R_OUT" "
if d.get('tier') != 'S': fail.append(d.get('tier'))
if d.get('total') != 10: fail.append(d.get('total'))
"
  assert_contains "CA-18($mode) GO：人读 S 档" "$R_ERR" "审计深度：S 档"
  assert_not_contains "CA-18($mode) NOGO：不得伪造贡献者理由" "$R_ERR" "贡献者≥3"
  assert_no_crash "CA-18($mode) 不得崩溃" "$R_ERR"
done

# ---------- CA-19：普通实例无 revisions/，即使父仓有也静默 N/A ----------
P=$(new_case)
mkdir -p "$P/revisions"
printf '# 父目录框架轨道，不属于子实例\n' > "$P/revisions/README.md"
T="$P/ordinary-instance"
make_gov_repo "$T" 1 || finish
assert_missing "CA-19 夹具：实例自身确无 revisions/" "$T/revisions"
run_in "$T" audit --level S
ORD_RC=$R_RC; ORD_HITS=$(hits_of "$R_OUT")
assert_rc_is "CA-19 普通实例保持既有退出码" 0 "$ORD_RC"
assert_eq "CA-19 S 档总项数恒为 10" 10 "$(total_of "$R_OUT")"
assert_not_contains "CA-19 GO：不得输出 revisions 检查结论" "$R_OUT" "revisions/ 轨道冻结"
assert_not_contains "CA-19 GO：不得输出冻结提交不可见 WARN" "$R_OUT" "冻结提交 cbc6f15 不在当前历史"
assert_not_contains "CA-19 GO：不得以其它轨道冻结文案替代静默" "$R_OUT" "轨道冻结检查 SKIPPED"

# CA-20 对照：有 revisions/ 的框架形态仍走既有 SKIPPED 分支，分数/退出码不变。
C=$(new_case); make_gov_repo "$C" 1 || finish
mkdir -p "$C/revisions"
printf '# 框架轨道说明（README 豁免）\n' > "$C/revisions/README.md"
run_in "$C" audit --level S
assert_rc_is "CA-20 对照：有 revisions/ 仍不改变退出码" "$ORD_RC" "$R_RC"
assert_eq "CA-20 对照：revisions 报告不参与 hits" "$ORD_HITS" "$(hits_of "$R_OUT")"
assert_eq "CA-20 对照：S 档总项数仍为 10" 10 "$(total_of "$R_OUT")"
assert_contains "CA-20 GO：冻结提交不在历史时仍如实 SKIPPED" "$R_OUT" "revisions/ 轨道冻结检查 SKIPPED"
assert_contains "CA-20 GO：冻结提交仍为 cbc6f15" "$R_OUT" "冻结提交 cbc6f15 不在当前历史"
assert_contains "CA-20 GO：SKIPPED 不计入 PASS" "$R_OUT" "不计入 PASS"

# CA-20 正对照：真实框架仓保留既有 PASS 文案与冻结提交。
run_in "$ROOT" audit --level S
assert_rc_is "CA-20 正对照：框架仓 audit 保持 exit 0" 0 "$R_RC"
assert_contains "CA-20 正对照：框架仓原 PASS 分支不删除" "$R_OUT" \
  "revisions/ 轨道冻结：自冻结提交 cbc6f15 起无新增/改动"

finish
