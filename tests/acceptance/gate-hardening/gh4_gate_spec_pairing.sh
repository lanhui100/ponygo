#!/usr/bin/env bash
# GH4：同 Stem/同扩展名门-spec 配对；audit 人读与 JSON 同时可观察。
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

command -v python3 >/dev/null 2>&1 || { bad "GH4 需要 python3 解析 JSON"; finish; }

audit_pairing() { # <dir>：设置 PAIR_*，同时断言人读/JSON 命中数同源
  local d="$1"
  run_cli "$d" audit --level M
  PAIR_HRC=$R_RC
  PAIR_HOUT=$R_OUT
  PAIR_HIT=$(hits_of "$R_OUT")
  run_json "$d" audit --level M --json
  PAIR_JRC=$R_RC
  PAIR_JOUT=$R_OUT
  PAIR_JERR=$R_ERR
  assert_eq "GH4 人读/JSON 退出码一致" "$PAIR_HRC" "$PAIR_JRC"
  json_assert "GH4 JSON 机读面同源且 exit 真实" "$PAIR_JOUT" "
if d.get('schema') != 'ponygo.audit/1': fail.append(d.get('schema'))
if d.get('exit') != $PAIR_JRC: fail.append((d.get('exit'), $PAIR_JRC))
if d.get('hits') != int('$PAIR_HIT'): fail.append((d.get('hits'), '$PAIR_HIT'))
if d.get('total') != 16: fail.append(('M total 必须机械同步为 16', d.get('total')))
if 'skills' not in d: fail.append(('JSON 机读面缺 skills 字段', sorted(d.keys())))
"
}

# 合法 sh 配对正对照。
T=$(new_case)
if make_gov_repo "$T" 2; then
  write_gate_pair "$T" new-gate sh
  audit_pairing "$T"
  assert_rc_is "GH4 合法 sh 配对保持既有正例" 0 "$PAIR_HRC"
  assert_not_contains "GH4 合法 sh 配对不得误报" "$PAIR_HOUT" "gate_spec_missing"
  json_assert "GH4 合法 sh 配对 JSON 无 gate_spec_missing" "$PAIR_JOUT" "
if 'gate_spec_missing' in d.get('gaps', []): fail.append(d.get('gaps'))
"

  # 仅删合法 spec，保留同一实体门；默认只读必须硬 FAIL。
  rm "$T/.meta/gates/new-gate.spec.sh"
  assert_file "GH4 负样本门仍存在" "$T/.meta/gates/new-gate.sh"
  assert_missing "GH4 负样本确无配对 spec" "$T/.meta/gates/new-gate.spec.sh"
  audit_pairing "$T"
  assert_rc_is "GH4 无配对门必须默认只读硬 FAIL" 1 "$PAIR_HRC"
  assert_contains "GH4 人读稳定缺口 ID" "$PAIR_HOUT" "gate_spec_missing"
  assert_contains "GH4 人读指出无配对门" "$PAIR_HOUT" "new-gate.sh"
  assert_contains "GH4 人读指出期望 spec" "$PAIR_HOUT" "new-gate.spec.sh"
  json_assert "GH4 JSON gaps/ladder 同源硬 FAIL" "$PAIR_JOUT" "
if 'gate_spec_missing' not in d.get('gaps', []): fail.append(d.get('gaps'))
if '2.3' not in d.get('ladder', {}).get('fails', []): fail.append(d.get('ladder'))
if d.get('ladder', {}).get('verdict') != 'fail': fail.append(d.get('ladder'))
"
fi

# 空 spec 不是负样本：同 Stem 同后缀但无有效内容仍须硬 FAIL。
T=$(new_case)
if make_gov_repo "$T" 2; then
  write_gate_pair "$T" empty-gate sh
  : > "$T/.meta/gates/empty-gate.spec.sh"
  assert_eq "GH4 夹具：empty-gate.spec.sh 恰 0 字节" 0 "$(wc -c < "$T/.meta/gates/empty-gate.spec.sh" | tr -d ' ')"
  run_cli "$T" audit --level M
  assert_rc_is "GH4 空配对 spec 必须硬 FAIL" 1 "$R_RC"
  assert_contains "GH4 空配对 spec 报 gate_spec_missing" "$R_OUT" "gate_spec_missing"
  assert_contains "GH4 空配对 spec 指出文件" "$R_OUT" "empty-gate.spec.sh"
fi

# 无配对不是执行脚本才能发现：默认只读 audit 即须报告。
T=$(new_case)
if make_gov_repo "$T" 2; then
  cat > "$T/.meta/gates/unpaired-gate.sh" <<'GATEEOF'
#!/usr/bin/env bash
printf 'UNPAIRED_GATE_EXECUTED\n' > gate-executed.marker
exit 0
GATEEOF
  run_cli "$T" audit --level M
  assert_rc_is "GH4 默认只读 audit 对无配对门硬 FAIL" 1 "$R_RC"
  assert_contains "GH4 默认只读 audit 报无配对门" "$R_OUT" "gate_spec_missing"
  assert_contains "GH4 默认只读 audit 指出门文件" "$R_OUT" "unpaired-gate.sh"
  assert_missing "GH4 配对检查不得执行门脚本" "$T/gate-executed.marker"
fi

# PowerShell 仅验证命名结构配对，不执行 .ps1、不宣称其负样本语义已被验证。
# pony-agent 若只有合法基线 spec，仍须另行补非法样本拒绝证据。
T=$(new_case)
if make_gov_repo "$T" 2; then
  write_gate_pair "$T" check-governance ps1
  run_cli "$T" audit --level M
  assert_rc_is "GH4 合法 ps1 配对保持既有正例" 0 "$R_RC"
  assert_not_contains "GH4 pony-agent 形态 ps1 合法配对" "$R_OUT" "check-governance.ps1.*缺"
  assert_not_contains "GH4 合法 ps1 配对无稳定缺口" "$R_OUT" "gate_spec_missing"

  # 同名但不同扩展名的 spec 不能抵偿。
  mv "$T/.meta/gates/check-governance.spec.ps1" "$T/.meta/gates/check-governance.spec.sh"
  run_cli "$T" audit --level M
  assert_rc_is "GH4 ps1 无同扩展名 spec 必须硬 FAIL" 1 "$R_RC"
  assert_contains "GH4 ps1 负样本人读缺口" "$R_OUT" "gate_spec_missing"
  assert_contains "GH4 ps1 负样本指出正确扩展名" "$R_OUT" "check-governance.spec.ps1"
fi

# 编排器豁免不能派生一个永远缺失的 ci-verify.spec.sh。
T=$(new_case)
if make_gov_repo "$T" 2; then
  assert_file "GH4 ci-verify 编排器存在" "$T/.meta/gates/ci-verify.sh"
  assert_missing "GH4 夹具无 ci-verify.spec.sh" "$T/.meta/gates/ci-verify.spec.sh"
  run_cli "$T" audit --level M
  assert_rc_is "GH4 ci-verify 豁免不误伤正例" 0 "$R_RC"
  assert_not_contains "GH4 不得要求 ci-verify.spec.sh" "$R_OUT" "ci-verify.spec.sh"
  assert_not_contains "GH4 编排器豁免不得产生缺口" "$R_OUT" "gate_spec_missing"
fi

finish
