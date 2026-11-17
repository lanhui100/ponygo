#!/usr/bin/env bash
# GH7：W0 契约验收（U6 存量违例基线棘轮 / U8 植入 seed 与漂移分类）
# 契约源：.dev-team/contract-w0-u6-u8.md（§4 退出码矩阵 / §6 验收接口 T-U6-* / T-U8-* / T-INV-*）
# 纪律：黑盒断言（只经 CLI 公开参数与退出码 + 临时仓文件系统状态），纯 bash + lib.sh；
#      不新增 run.sh 场景（本文件由 s90 折叠套件执行，属 CORE 层，Windows 也跑）。
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

VNOTE_REL=".agents/skills/write-adr/verify-note.sh"
SEED_REL=".meta/.ponygo-seed"
BASE_REL=".meta/notes-baseline.json"

sha_of_file() { # <file>：EOL 归一后 sha256（与 skeleton_drift 同口径）
  if command -v sha256sum >/dev/null 2>&1; then
    tr -d '\r' < "$1" | sha256sum | awk '{print $1}'
  else
    tr -d '\r' < "$1" | shasum -a 256 | awk '{print $1}'
  fi
}

vnote() { # <dir> [args...] → R_RC/R_OUT
  local dir="$1"
  shift
  R_OUT=$(cd "$dir" && bash "$VNOTE_REL" "$@" 2>&1)
  R_RC=$?
}

mk_legacy_repo() { # <dir>：合法治理仓 + 1 条违反 1.10 的存量 note
  local dir="$1"
  make_gov_repo "$dir" 1 || return 1
  mkdir -p "$dir/.agents/notes/implemented/process"
  cat > "$dir/.agents/notes/implemented/process/2026-01-02-legacy-debt.md" <<'LEGACYEOF'
# 2026-01-02 历史遗留记录

Status: implemented

## Decision

存量债夹具：故意不写备选节，用于验证基线棘轮。
LEGACYEOF
}

json_field() { # <json> <python 表达式>
  printf '%s' "$1" | python3 -c 'import json,sys
try:
    d = json.load(sys.stdin)
except Exception:
    print(""); raise SystemExit(0)
print(eval(sys.argv[1]))' "$2" 2>/dev/null
}

# ============================================================
# U6：存量违例基线棘轮 `upgrade adopt`
# ============================================================
T=$(new_case)
mk_legacy_repo "$T"
vnote "$T"
assert_nonzero "T-U6-1 前置：无基线时 verify-note 对存量违例 exit 1" "$R_RC"
assert_contains "T-U6-1 前置：违例行含判据号 1.10" "$R_OUT" "1.10"

run_cli "$T" upgrade adopt
assert_zero "T-U6-2 upgrade adopt 首次冻结 exit 0" "$R_RC"
assert_file "T-U6-3 基线文件已生成" "$T/$BASE_REL"
assert_matches "T-U6-4 摘要行格式「存量 N（较上次 +M/-K）」" "$R_OUT" '存量 [0-9]+（较上次 \+[0-9]+/-[0-9]+）'
assert_contains "T-U6-4b 首次冻结打印 +1" "$R_OUT" "+1/-0"
BASE1=$(sha_of_file "$T/$BASE_REL")

vnote "$T"
assert_zero "T-U6-5 基线生效后 verify-note exit 0（存量被豁免）" "$R_RC"
assert_contains "T-U6-6 无 --json 时成功横幅逐字不变" "$R_OUT" \
  "verify-note: 全部通过（机械影子 1.1–1.10 + 负空间形状判据；真实性/分类/备选质量靠 review）"

# 新增违例（基线外）→ 必须红
cat > "$T/.agents/notes/implemented/process/2026-01-03-new-debt.md" <<'NEWEOF'
# 2026-01-03 新违例

Status: implemented

## Decision

基线之后新增的违例不得被存量基线吞掉。
NEWEOF
vnote "$T"
assert_nonzero "T-U6-7 新增违例不被基线吞掉（verify-note exit 1）" "$R_RC"
assert_contains "T-U6-7b 红相点名新文件" "$R_OUT" "2026-01-03-new-debt.md"

# 增长：再次 adopt 必须打印 +1 并写入 2 条
run_cli "$T" upgrade adopt
assert_zero "T-U6-8 增长后重跑 adopt exit 0" "$R_RC"
assert_contains "T-U6-8b 增长行打印 +1" "$R_OUT" "+1"
ENT=$(json_field "$(cat "$T/$BASE_REL")" "len(d['entries'])")
assert_eq "T-U6-8c 基线条目数 = 2" "2" "$ENT"

# 出册：修复老违例后 adopt 必须 -1（棘轮只收紧不膨胀）
cat > "$T/.agents/notes/implemented/process/2026-01-02-legacy-debt.md" <<'FIXEDEOF'
# 2026-01-02 历史遗留记录（已修复）

Status: implemented

## Decision

存量债已补齐备选节。

## Alternatives considered

- 保持原样并接受永久告警：否决，存量债不得无限期挂账。
FIXEDEOF
run_cli "$T" upgrade adopt
assert_zero "T-U6-9 修复后重跑 adopt exit 0" "$R_RC"
assert_contains "T-U6-9b 出册行打印 -1" "$R_OUT" "-1"
ENT=$(json_field "$(cat "$T/$BASE_REL")" "len(d['entries'])")
assert_eq "T-U6-9c 出册后基线条目数 = 1" "1" "$ENT"

# --dry-run：同码、零落盘
DRY_BEFORE=$(sha_of_file "$T/$BASE_REL")
run_cli "$T" upgrade adopt --dry-run
assert_zero "T-U6-10 --dry-run exit 0（与实跑同码）" "$R_RC"
assert_contains "T-U6-10b dry-run 末行声明未写盘" "$R_OUT" "[dry-run] 未写盘"
assert_eq "T-U6-10c dry-run 零落盘（基线字节不变）" "$DRY_BEFORE" "$(sha_of_file "$T/$BASE_REL")"

# --expires 非法三态：exit 2 且零落盘
for bad_exp in "abc" "2020-01-01" "2999-01-01"; do
  run_cli "$T" upgrade adopt --expires "$bad_exp"
  assert_rc_is "T-U6-11 --expires $bad_exp 必须 exit 2" 2 "$R_RC"
done
assert_eq "T-U6-11b 非法 --expires 零落盘" "$DRY_BEFORE" "$(sha_of_file "$T/$BASE_REL")"

# 互斥：写路径 vs 只读检查
run_cli "$T" upgrade adopt --check
assert_nonzero "T-U6-12 'upgrade adopt --check' 互斥拒绝（exit 1）" "$R_RC"
run_cli "$T" status --expires 2027-01-01
assert_nonzero "T-U6-12b '--expires' 仅属 upgrade adopt（其余命令 exit 1）" "$R_RC"

# 过期：基线整体失效 → 全部违例重回生效
python3 - "$T/$BASE_REL" <<'PYEOF'
import json, sys
p = sys.argv[1]
d = json.load(open(p, encoding="utf-8"))
d["expires_at"] = "2020-01-01"
json.dump(d, open(p, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PYEOF
vnote "$T"
assert_nonzero "T-U6-13 基线过期后 verify-note exit 1（违例重回生效）" "$R_RC"
run_cli "$T" upgrade adopt
assert_zero "T-U6-14 过期后重跑 adopt exit 0（按全新冻结处理）" "$R_RC"
assert_contains "T-U6-14b 打印过期提示行" "$R_OUT" "既有基线已过期"

# 损坏：fail-closed（不猜、不覆盖）
cp "$T/$BASE_REL" "$T/baseline.good"
printf '{oops' > "$T/$BASE_REL"
vnote "$T"
assert_rc_is "T-U6-15 基线损坏 verify-note exit 2（fail-closed）" 2 "$R_RC"
CORRUPT=$(sha_of_file "$T/$BASE_REL")
run_cli "$T" upgrade adopt
assert_rc_is "T-U6-16 基线损坏时 adopt 拒绝并 exit 2" 2 "$R_RC"
assert_eq "T-U6-16b adopt 不得覆盖损坏基线" "$CORRUPT" "$(sha_of_file "$T/$BASE_REL")"
cp "$T/baseline.good" "$T/$BASE_REL"

# --json：单行机读（stdout 只 JSON，人类行走 stderr）
run_json "$T" upgrade adopt --json
assert_zero "T-U6-17 'upgrade adopt --json' exit 0" "$R_RC"
JSON_LINES=$(printf '%s\n' "$R_OUT" | wc -l | tr -d ' \t')
JSON_HEAD=$(printf '%s' "$R_OUT" | cut -c1)
assert_eq "T-U6-17b JSON 为恰一行且以 { 开头" "1:{" "$JSON_LINES:$JSON_HEAD"
json_assert "T-U6-17c JSON schema/entries/exit 字段正确" "$R_OUT" '
fail = []
if d.get("schema") != "ponygo.upgrade-adopt/1": fail.append("schema=%r" % d.get("schema"))
if not isinstance(d.get("entries"), int): fail.append("entries 非整数")
if d.get("exit") != 0: fail.append("exit=%r" % d.get("exit"))
if d.get("mode") != "adopt": fail.append("mode=%r" % d.get("mode"))
'
vnote "$T" --json
assert_zero "T-U6-18 'verify-note --json' exit 0（基线覆盖后）" "$R_RC"
json_assert "T-U6-18b verify-note JSON 的 counts 恒等式与 baseline.state" "$R_OUT" '
fail = []
c = d.get("counts") or {}
if c.get("total") != (c.get("baselined", 0) + c.get("new", 0)): fail.append("counts 恒等式不成立：%r" % c)
b = d.get("baseline") or {}
if b.get("state") not in ("absent", "ok", "expired", "corrupt"): fail.append("baseline.state=%r" % b.get("state"))
if d.get("schema") != "ponygo.verify-note/1": fail.append("schema=%r" % d.get("schema"))
'

# ============================================================
# U8：植入 seed 与漂移分类
# ============================================================
T2=$(new_case)
make_gov_repo "$T2" 1
assert_file "T-U8-1 init 后写入 .meta/.ponygo-seed" "$T2/$SEED_REL"
json_assert "T-U8-2 seed 的 files 键集恰为 17 个骨架文件 + 含 framework.commit" "$(cat "$T2/$SEED_REL")" '
fail = []
f = d.get("files") or {}
if len(f) != 17: fail.append("files 条目=%d（应 17）" % len(f))
fw = d.get("framework") or {}
if "commit" not in fw: fail.append("缺 framework.commit")
if d.get("schema") != "ponygo.seed/1": fail.append("schema=%r" % d.get("schema"))
'
SEED_SHA1=$(sha_of_file "$T2/$SEED_REL")
run_cli "$T2" init
assert_zero "T-U8-3 重复 init exit 0" "$R_RC"
assert_contains "T-U8-3b 重复 init 声明跳过写 seed" "$R_OUT" "跳过"
assert_eq "T-U8-4 重复 init 不覆盖 seed（字节不变）" "$SEED_SHA1" "$(sha_of_file "$T2/$SEED_REL")"

# 篡改框架资产 → modified（--check 退出码语义不变：有漂移即 1）
printf '\n# tampered by gh7\n' >> "$T2/.meta/gates/ci-verify.sh"
run_cli "$T2" upgrade --check
assert_nonzero "T-U8-5 篡改框架资产后 upgrade --check exit 1（既有语义不变）" "$R_RC"
assert_contains "T-U8-6 漂移行带 [modified] 分类" "$R_OUT" "[modified]"
assert_matches "T-U8-6b modified 行指向被改文件" "$R_OUT" 'drift: \.meta/gates/ci-verify\.sh  \[modified\]'

# stale：seed 记录 = 当前字节，但 ≠ 模板字节
CUR_SHA=$(sha_of_file "$T2/.meta/gates/ci-verify.sh")
python3 - "$T2/$SEED_REL" ".meta/gates/ci-verify.sh" "$CUR_SHA" <<'PYEOF'
import json, sys
seed_p, rel, sha = sys.argv[1], sys.argv[2], sys.argv[3]
d = json.load(open(seed_p, encoding="utf-8"))
d["files"][rel] = sha
json.dump(d, open(seed_p, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PYEOF
run_cli "$T2" upgrade --check
assert_matches "T-U8-7 seed 字节==当前字节但≠模板 → [stale]" "$R_OUT" 'drift: \.meta/gates/ci-verify\.sh  \[stale\]'
assert_contains "T-U8-8 打印 seed 分类汇总行" "$R_OUT" "seed 分类："

# 修复回模板 → 分类回到 in-sync（不再有该文件的 drift 行）
run_cli "$T2" upgrade apply
assert_zero "T-U8-9 upgrade apply exit 0（刷新模板 + 重签 seed）" "$R_RC"
assert_contains "T-U8-9b apply 打印 seed 重签行" "$R_OUT" "重签"
run_cli "$T2" upgrade --check
assert_zero "T-U8-10 apply 后 --check exit 0（零漂移）" "$R_RC"

# 无 seed（旧实例）→ unknown + 修法提示，退出码语义不变
rm -f "$T2/$SEED_REL"
run_cli "$T2" upgrade --check
assert_zero "T-U8-11 无 seed 不改变 --check 退出码（零漂移仍 exit 0）" "$R_RC"
assert_contains "T-U8-12 无 seed 打印修法提示" "$R_OUT" "seed：未找到 .meta/.ponygo-seed"

# --repair-skeleton 不得写 seed
T3=$(new_case)
mkdir -p "$T3"
(cd "$T3" && git init -q . >/dev/null 2>&1)
run_cli "$T3" init --repair-skeleton
assert_zero "T-U8-13 init --repair-skeleton exit 0" "$R_RC"
assert_missing "T-U8-14 --repair-skeleton 不写 seed（补缺失≠改 provenance）" "$T3/$SEED_REL"

# ============================================================
# INV：命令面 / A1–A9 字节 / 默认输出面
# ============================================================
run_cli "$ROOT" --help
CMDS=$(printf '%s\n' "$R_OUT" | sed -n 's/^  ponygo \([a-z][a-z-]*\).*/\1/p' | LC_ALL=C sort -u | tr '\n' ' ')
assert_eq "T-INV-1 顶层命令词集合恰为 7 词（未新增/未删除）" "audit init observe retire status sync upgrade " "$CMDS"
assert_not_contains "T-INV-2 usage 不得出现顶层 adopt 行" "$R_OUT" "  ponygo adopt"
# A1–A9 = 门禁脚本与负样本 spec；`.meta/gates/README.md` 是文档家（W0 同批更新），不属门资产
GATES_DIFF=$(git -C "$ROOT" status --porcelain -- .meta/gates 2>/dev/null | grep -v 'README\.md' || true)
assert_eq "T-INV-3 A1–A9 门资产（脚本与 spec）字节零改动" "" "$GATES_DIFF"

T4=$(new_case)
mk_legacy_repo "$T4"
vnote "$T4"
assert_nonzero "T-INV-4 无 --json 时反例仍 exit 1（默认面不变）" "$R_RC"
assert_contains "T-INV-4b 无 --json 时失败横幅逐字不变" "$R_OUT" "verify-note: 未通过（见上方 FAIL 项；逐项修复后重跑）"

finish
