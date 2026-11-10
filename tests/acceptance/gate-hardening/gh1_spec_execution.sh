#!/usr/bin/env bash
# GH1：PONYGO_IN_SPEC 不得让 spec SKIPPED+0；ci-verify 不得吞掉未验证。
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# 直接真实 spec：完成标记 + 无 SKIPPED，证明不是仅凭 exit 0 放行。
for name in adr-verify scratch-hygiene; do
  spec="$ROOT/.meta/gates/$name.spec.sh"
  assert_file "GH1($name) 真实 spec 存在" "$spec"
  OUT=$(cd "$ROOT" && PONYGO_IN_SPEC=1 bash "$spec" 2>&1)
  RC=$?
  assert_rc_is "GH1($name) PONYGO_IN_SPEC=1 下完整自检" 0 "$RC"
  assert_not_contains "GH1($name) 不得自报 SKIPPED" "$OUT" "SKIPPED"
  case "$name" in
    adr-verify) assert_contains "GH1(A2) 必须到达真实完成标记" "$OUT" "[adr-verify.spec] 全部通过" ;;
    scratch-hygiene)
      assert_contains "GH1(scratch) 必须到达真实完成标记" "$OUT" "scratch-hygiene.spec: PASS"
      assert_contains "GH1(scratch) install E3 运行时隔离断言已执行" "$OUT" "SCRATCH_E3_INSTALL isolated"
      assert_contains "GH1(scratch) release E3 运行时隔离断言已执行" "$OUT" "SCRATCH_E3_RELEASE isolated"
      ;;
  esac
done

# E3 隔离只接受运行时标记：标记前 spec 必须真实断言 case 内无交叉文件、
# gate.out 各自含 [E3] 与目标路径；不接受只写注释或无条件打印标记。

# CLI 递归护栏不得被本轮修复削弱。
T=$(new_case)
if make_gov_repo "$T" 1; then
  run_cli "$T" PONYGO_AUDIT_SPEC_DEPTH=1 audit --run-specs
  assert_rc_is "GH1 深度护栏：嵌套 audit 必须证据不足" 3 "$R_RC"
  assert_contains "GH1 深度护栏仍披露嵌套执行" "$R_OUT" "嵌套执行"
  run_cli "$T" PONYGO_IN_SPEC=1 audit --run-specs
  assert_rc_is "GH1 外部旧变量：audit 仍证据不足" 3 "$R_RC"
fi

# A4 正基线 -> A2 无精确完成标记即非零。SKIPPED 与任意 exit-0 输出分开对抗，
# 禁止用 grep SKIPPED 冒充执行完成证明。
T=$(new_case)
if make_gov_repo "$T" 1; then
  OUT=$(cd "$T" && bash .meta/gates/ci-verify.sh 2>&1)
  RC=$?
  assert_rc_is "GH1 A4 正向基线" 0 "$RC"

  for mode in skipped arbitrary; do
    if [ "$mode" = skipped ]; then
      probe_text='GH1_WITNESS: A2 invoked but SKIPPED; not verified'
    else
      probe_text='GH1_WITNESS: arbitrary successful output without completion marker'
    fi
    printf '#!/usr/bin/env bash\nprintf "%%s\\n" "%s"\nexit 0\n' "$probe_text" > "$T/.meta/gates/adr-verify.spec.sh"
    OUT=$(cd "$T" && bash .meta/gates/ci-verify.sh 2>&1)
    RC=$?
    assert_nonzero "GH1 A4($mode) 无精确完成标记不得洗绿" "$RC"
    assert_contains "GH1 A4($mode) 捕获并透出执行 witness" "$OUT" "GH1_WITNESS"
    assert_contains "GH1 A4($mode) 必须报硬失败" "$OUT" "ci-verify: FAIL"
  done
fi

# 双写真源：仓库模板与 CLI heredoc 必须同步。
python3 - "$ROOT" <<'PY'
import pathlib, sys
root = pathlib.Path(sys.argv[1])
cli = (root / "ponygo").read_text()
marker = 'gate_asset_put "$META_DIR/gates/ci-verify.sh"'
pos = cli.find(marker)
if pos < 0:
    print("GH1 heredoc: missing gate_asset_put", file=sys.stderr)
    sys.exit(1)
start = cli.find("<<'PONYGO_EOF'", pos)
if start < 0:
    print("GH1 heredoc: missing opener", file=sys.stderr)
    sys.exit(1)
body_start = cli.find("\n", start) + 1
end = cli.find("\nPONYGO_EOF", body_start)
if end < 0:
    print("GH1 heredoc: missing terminator", file=sys.stderr)
    sys.exit(1)
embedded = cli[body_start:end].replace("\r\n", "\n").rstrip("\n")
repo = (root / ".meta/gates/ci-verify.sh").read_text().replace("\r\n", "\n").rstrip("\n")
if embedded != repo:
    print("GH1 heredoc differs from .meta/gates/ci-verify.sh", file=sys.stderr)
    sys.exit(1)
PY
assert_zero "GH1 A4 仓库模板与 CLI heredoc 逐字节同源" "$?"

finish
