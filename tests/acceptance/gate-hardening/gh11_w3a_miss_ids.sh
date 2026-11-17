#!/usr/bin/env bash
# GH11：W3a 契约验收（B022：audit/status 的 miss_ids 覆盖 hits<total）
# 契约源：.dev-team/contract-w3a-b022.md §2（T-B022-*）
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

IDS='q1.decisions_dir q1.lifecycles q1.decisions_present q1.rejected_trace q1.status_head q1.alternatives q1.hook_trace q2.instance_gate q2.local_hook q2.ci_present q2.negative_spec q2.gate_spec_paired q3.instance_skill q3.skill_shape_name q3.skill_shape_four q4.sealed_archive'

# ---------- 构造「缺 rejected 留痕」的夹具（其余尽量齐）----------
T=$(new_case)
make_gov_repo "$T" 2
mkdir -p "$T/.agents/notes/rejected"
printf '# placeholder\n' > "$T/.agents/notes/rejected/README.md"   # 占位不计入留痕
run_json "$T" audit --level M --json
assert_zero "T-B022 前置：audit --json exit 0（无硬 FAIL）" "$R_RC"
MISS=$(json_get "$R_OUT" "' '.join(d.get('miss_ids') or [])")
assert_contains "T-B022-1 缺 rejected 留痕 → miss_ids 含 q1.rejected_trace" "$MISS" "q1.rejected_trace"
HITS=$(json_get "$R_OUT" "d.get('hits')")
TOTAL=$(json_get "$R_OUT" "d.get('total')")
assert_eq "T-B022-5 计分不变：M 档 total=16" "16" "$TOTAL"
run_cli "$T" audit --level M
assert_contains "T-B022-5b 人读「命中 X / N 项」仍在" "$R_OUT" "命中 $HITS / $TOTAL 项"
assert_contains "T-B022-2 人读输出含「未命中项：」并列出 id" "$R_OUT" "未命中项："
assert_contains "T-B022-2b 未命中行点名该 id" "$R_OUT" "q1.rejected_trace"

# ---------- id 合法性与去重 ----------
python3 - "$MISS" "$IDS" <<'PY' && ok "T-B022-4 miss_ids 无重复且 id 均在冻结词表内" || bad "T-B022-4 miss_ids 含重复或词表外 id"
import sys
miss = sys.argv[1].split()
allowed = set(sys.argv[2].split())
if len(miss) != len(set(miss)): raise SystemExit(1)
if any(x not in allowed for x in miss): raise SystemExit(1)
PY

# ---------- 全命中夹具：补 rejected 留痕 + 实例门配对 + 技能 + 封印归档 ----------
T2=$(new_case)
make_gov_repo "$T2" 2
mkdir -p "$T2/.agents/notes/rejected/process"
printf '# 被否方案\n\nStatus: rejected — 与单文件零依赖铁律冲突，落选\n\n## Proposal\n\n引入外部依赖。\n' > "$T2/.agents/notes/rejected/process/2026-01-10-rejected.md"
mkdir -p "$T2/.agents/skills/demo-skill"
cat > "$T2/.agents/skills/demo-skill/SKILL.md" <<'SKILL'
---
name: demo-skill
description: 何时用：演示技能四要素时使用。
---
# demo-skill
## 真相源
- 契约：README
## 步骤
1. 跑一条命令。
## 校准样例
- 正例：输出 exit 0。
## 验证与报告
- 报告：贴 exit code。
SKILL
run_json "$T2" audit --level M --json
assert_zero "T-B022-3 前置：全命中夹具 audit exit 0" "$R_RC"
MISS2=$(json_get "$R_OUT" "' '.join(d.get('miss_ids') or [])")
assert_not_contains "T-B022-3b 已补齐项不再出现在 miss_ids" "$MISS2" "q1.rejected_trace"
run_cli "$T2" audit --level M
assert_not_contains "T-B022-3c 无未命中项时不打印「未命中项：」行" "$R_OUT" "未命中项："

finish
