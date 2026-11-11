#!/usr/bin/env bash
# GH6：Wave-14 四段契约的机械验收（A 计数格式 / B 分层 / C spec 超时分档 / D CI 拓扑）。
# 契约源：.dev-team/contract-wave14.md（Lead 已冻结，唯一真源）；断言描述里标注契约 ID。
#
# 纪律（为什么这样写）：
#   - 全部为「便宜断言」：静态结构化解析 + 两次快速退出码探针，整份用例正常耗时 < 1s；
#     **禁止**在本用例内跑 `bash tests/run.sh` 全量（它会反过来跑本用例所属的 s90）。
#   - **不新增 run.sh 场景**：场景数恒为 94（契约 R1/B7），本用例由既有 s90 折叠场景执行，
#     且 s90 属 CORE 层（契约 §2.1），故 windows-core 也覆盖本契约。
#   - 依赖尚未实现行为的断言照样写死：红相必须红（not-implemented 语义），不得为了让测试变绿而弱化。
#   - 探针用外层 `timeout` 兜底：实现缺失时被测脚本不会 hang（红相快速返回，靠断言失败而非超时挂死）。
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

RUN_SH="$ROOT/tests/run.sh"
CI_YML="$ROOT/.github/workflows/ci.yml"
CLI_SRC="$ROOT/ponygo"
AT2="$ROOT/tests/acceptance/adversarial/auditfix/a2_hung_spec_timeout.sh"

# 分层探针外层守卫：正确实现下 `bash tests/run.sh` 在 0.1s 内 exit 2；此值只在实现缺失时兜底。
LAYER_GUARD_SECS=8
# 非法 PONYGO_SPEC_TIMEOUT 探针外层守卫：正确实现下立即 exit 2。
SPEC_GUARD_SECS=20

assert_file_matches() { # <描述> <文件> <ERE>
  if grep -Eq -- "$3" "$2" 2>/dev/null; then ok "$1"; else bad "$1（$2 内无匹配 /$3/）"; fi
}
assert_file_not_matches() { # <描述> <文件> <ERE>
  if grep -Eq -- "$3" "$2" 2>/dev/null; then bad "$1（$2 命中禁用形态 /$3/）"; else ok "$1"; fi
}
assert_not_matches() { # <描述> <整体> <ERE>
  if printf '%s\n' "$2" | grep -Eq -- "$3"; then bad "$1（不应匹配 /$3/）"; else ok "$1"; fi
}

# ---------- 前置：被测对象存在（缺文件 = harness 前提错误，仍以 bad 记录，不静默跳过） ----------
for f in "$RUN_SH" "$CI_YML" "$CLI_SRC" "$AT2"; do
  assert_file "GH6 契约被测文件存在：${f#"$ROOT"/}" "$f"
done

# 与 CLI 同源的平台判定（C3/C14：Windows 档 180s，其余 90s）；避免把 Linux 期望值写死到 Windows CI。
is_windows_platform() {
  case "${OSTYPE:-}" in msys* | cygwin* | MSYS* | CYGWIN*) return 0 ;; esac
  case "$(uname -s 2>/dev/null)" in MINGW* | MSYS* | CYGWIN* | mingw* | msys* | cygwin*) return 0 ;; esac
  return 1
}
if ! command -v python3 >/dev/null 2>&1; then
  bad "GH6 需要 python3 做结构化解析（缺失即失败，不跳过契约断言）"
  finish
fi

# ============================================================
# 契约 A（§1.1–§1.4）+ 契约 B 静态面（§2）：结构化解析 tests/run.sh
# ============================================================
RUN_PY=$(python3 - "$RUN_SH" <<'PY'
import re
import sys

path = sys.argv[1]
text = open(path, encoding="utf-8", errors="replace").read()
lines = text.splitlines()
out = []


def ok(desc):
    out.append("CHECK OK " + desc)


def fail(desc, detail=""):
    out.append("CHECK FAIL " + desc + ("（实得：%s）" % detail if detail else ""))


def emit():
    out.append("#PARSE-END")
    sys.stdout.write("\n".join(out) + "\n")


try:
    # ---------- A1/A2/A3：汇总行唯一生产者 + 键序固定 ----------
    summary = [l for l in lines if "==== 测试结果：" in l]
    if len(summary) == 1:
        ok("GH6/A3 汇总行唯一生产者（tests/run.sh 内恰 1 处，禁止多处打印）")
    else:
        fail("GH6/A3 汇总行唯一生产者（tests/run.sh 内恰 1 处）", "命中 %d 处" % len(summary))

    if not summary:
        fail("GH6/A1 汇总行前缀 `==== 测试结果：` 逐字保留", "未找到汇总行")
    else:
        line = summary[0]
        if "==== 测试结果：" in line:
            ok("GH6/A1 汇总行前缀 `==== 测试结果：` 逐字保留")
        keys = ["scenarios=", "pass=", "fail=", "checks=", "skipped="]
        pos = [line.find(k) for k in keys]
        if all(p >= 0 for p in pos) and pos == sorted(pos):
            ok("GH6/A2 键序固定 scenarios→pass→fail→checks→skipped 且 pass=/fail= 保留")
        else:
            fail("GH6/A2 键序固定 scenarios→pass→fail→checks→skipped", line.strip())
        bound = [k for k in keys
                 if not re.search(re.escape(k) + r'\$?\{?[A-Za-z_][A-Za-z0-9_]*', line)]
        if not bound:
            ok("GH6/A2/A6 五个键全部绑定计数变量（禁止字面量假绿）")
        else:
            fail("GH6/A2/A6 五个键全部绑定计数变量", "未绑定：%s" % ",".join(bound))
        if re.search(r'====\s*"?\s*$', line):
            ok("GH6/A1 汇总行以 `====` 收尾（正则 `^==== 测试结果：… ====$` 可锚定）")
        else:
            fail("GH6/A1 汇总行以 `====` 收尾", line.strip())

    # ---------- A4/A5：叶子 ok()/bad() 是 pass/fail 的唯一来源 ----------
    violations = []
    for no, l in enumerate(lines, 1):
        if re.search(r'\bPASS=\$\(\(PASS\b', l) and not re.search(r'PASS=\$\(\(PASS\s*\+\s*1\)\)', l):
            violations.append(":%d %s" % (no, l.strip()))
        if re.search(r'\bFAIL=\$\(\(FAIL\b', l) and not re.search(r'FAIL=\$\(\(FAIL\s*\+\s*1\)\)', l):
            violations.append(":%d %s" % (no, l.strip()))
    if violations:
        fail("GH6/A4/A5 pass/fail 只来自叶子 ok()/bad()（嵌套/折叠不得并入）", "；".join(violations[:3]))
    else:
        ok("GH6/A4/A5 pass/fail 只来自叶子 ok()/bad()（无 PASS=$((PASS + p)) 式并入）")
    if re.search(r'PASS=\$\(\(PASS\s*\+\s*[a-z]', text):
        fail("GH6/A4 禁止 `PASS=$((PASS + p))` 把嵌套计数并入叶子", "命中")
    else:
        ok("GH6/A4 禁止 `PASS=$((PASS + p))` 把嵌套计数并入叶子")

    # ---------- A6/A7：三类计数变量落地 ----------
    for prefix, cid in (("NESTED", "A7 嵌套"), ("FOLDED", "A7 折叠")):
        if re.search(r'(?m)(?:^|[;\s])' + prefix + r'_[A-Z_]+\s*=', text):
            ok("GH6/%s 计数变量（%s_*）落地" % (cid, prefix))
        else:
            fail("GH6/%s 计数变量（%s_*）落地" % (cid, prefix), "0 处赋值")
    if re.search(r'(?m)(?:^|[;\s])[A-Z_]*SKIP[A-Z_]*\s*=', text):
        ok("GH6/A6 skipped 计数变量落地（场景级层过滤专用）")
    else:
        fail("GH6/A6 skipped 计数变量落地", "0 处赋值")

    # ---------- B3/B8：统一守卫函数（函数体内引用 PONYGO_TEST_LAYER）+ 94 处调用 ----------
    # 函数体抽取必须做花括号配平：`ok()  { PASS=$((PASS+1)); }` 这类单行函数若按「下一个 ^} 收尾」
    # 抽取，会把后面整段（含守卫函数）吞进 ok() 的 body，从而误判守卫归属。
    defs = []
    i = 0
    while i < len(lines):
        m = re.match(r'^([A-Za-z_][A-Za-z0-9_]*)\(\)\s*\{', lines[i])
        if m:
            name = m.group(1)
            depth = 0
            seen = False
            body = []
            j = i
            while j < len(lines):
                if j > i:
                    body.append(lines[j])
                for ch in lines[j]:
                    if ch == "{":
                        depth += 1
                        seen = True
                    elif ch == "}":
                        depth -= 1
                if seen and depth <= 0:
                    break
                j += 1
            if not (seen and depth <= 0):  # 配平失败 → 退回「下一个 ^}」兜底，避免漏抽整段
                j = i + 1
                body = []
                while j < len(lines) and not re.match(r'^\}', lines[j]):
                    body.append(lines[j])
                    j += 1
            defs.append((name, i, "\n".join(body)))
            i = j
        i += 1
    guards = [d for d in defs if "PONYGO_TEST_LAYER" in d[2]]
    if len(guards) == 1:
        gname, gstart, _ = guards[0]
        ok("GH6/B3 统一分层守卫函数唯一（%s）" % gname)
        calls = [k for k, l in enumerate(lines)
                 if re.match(r'^\s+' + re.escape(gname) + r'(\s|$)', l)]
        if len(calls) >= 94:
            ok("GH6/B3/B8 守卫在场景函数体内逐场景调用（%d 处 ≥ 94）" % len(calls))
        else:
            fail("GH6/B3/B8 守卫在场景函数体内逐场景调用（≥94 处）", "%d 处" % len(calls))
        if calls and calls[0] > gstart:
            ok("GH6/B3 守卫定义先于首次调用")
        else:
            fail("GH6/B3 守卫定义先于首次调用", "首次调用行 = %s" % (calls[0] if calls else "无"))
    elif not guards:
        fail("GH6/B3 统一分层守卫函数（函数体内引用 PONYGO_TEST_LAYER）存在", "0 处")
    else:
        fail("GH6/B3 统一分层守卫函数唯一", "%d 处：%s" % (len(guards), ",".join(g[0] for g in guards)))

    # ---------- R1/B7：94 个场景顶层裸调用行逐字保留 ----------
    scenarios = [l for l in lines if re.fullmatch(r's[0-9]+_[a-z0-9_]+', l)]
    if len(scenarios) == 94:
        ok("GH6/R1+B7 场景顶层裸调用恒为 94（grep -cE '^s[0-9]+_[a-z0-9_]+$'）")
    else:
        fail("GH6/R1+B7 场景顶层裸调用恒为 94", "%d" % len(scenarios))

    # ---------- B6：CORE/NONCORE 数据块（标记块 + 块内禁止裸场景行） ----------
    def block(tag):
        start = "# >>> ponygo-test-layer: %s >>>" % tag
        end = "# <<< ponygo-test-layer: %s <<<" % tag
        s = [k for k, l in enumerate(lines) if l.strip() == start]
        if not s:
            return None
        s = s[0]
        e = [k for k, l in enumerate(lines) if k > s and l.strip() == end]
        if not e:
            return None
        return lines[s + 1:e[0]]

    parsed = {}
    for tag in ("CORE-SET", "NONCORE-SET"):
        blk = block(tag)
        if blk is None:
            fail("GH6/B6 %s 标记块成对存在（`# >>> ponygo-test-layer: %s >>>` … `<<<`）" % (tag, tag), "缺标记")
            continue
        ok("GH6/B6 %s 标记块成对存在" % tag)
        bare = [l for l in blk if re.fullmatch(r's[0-9]+_[a-z0-9_]+', l)]
        if bare:
            fail("GH6/B6/B7 %s 块内不得出现裸场景行（会把 R1 计数从 94 翻倍）" % tag, ",".join(bare[:3]))
        else:
            ok("GH6/B6/B7 %s 块内无裸场景行（R1 计数不被数据块打断）" % tag)
        want = tag.split("-")[0]
        names = []
        for l in blk:
            m = re.match(r'^\s*([A-Z]+)\s+(s[0-9]+_[a-z0-9_]+)\s*(#.*)?$', l)
            if m and m.group(1) == want:
                names.append(m.group(2))
        parsed[want] = names

    # ---------- B4/B5：分区大小与互斥/并集 ----------
    core = parsed.get("CORE", [])
    noncore = parsed.get("NONCORE", [])
    if len(core) == 27:
        ok("GH6/B4 CORE-SET 恰 27 项（core 层 scenarios=27）")
    else:
        fail("GH6/B4 CORE-SET 恰 27 项", "%d" % len(core))
    if len(noncore) == 67:
        ok("GH6/B4 NONCORE-SET 恰 67 项（core 层 skipped=67）")
    else:
        fail("GH6/B4 NONCORE-SET 恰 67 项", "%d" % len(noncore))
    overlap = sorted(set(core) & set(noncore))
    if overlap:
        fail("GH6/B5 CORE 与 NONCORE 互斥", ",".join(overlap[:3]))
    else:
        ok("GH6/B5 CORE 与 NONCORE 互斥")
    union = set(core) | set(noncore)
    scen_set = set(scenarios)
    if union == scen_set:
        ok("GH6/B5 两集合并集 = 94 个场景（不重不漏）")
    else:
        miss = sorted(scen_set - union)
        extra = sorted(union - scen_set)
        fail("GH6/B5 两集合并集 = 94 个场景（不重不漏）",
             "未分类=%s 不存在=%s" % (miss[:3], extra[:3]))

    # ---------- §2.1 权威 CORE-SET 逐名比对 ----------
    expected_core = [
        "s02_init", "s11_l1_criteria", "s13_meta_violations", "s24_gate_layers",
        "s27_run_specs", "s30_release_chain", "s31_upgrade_drift",
        "s46_init_gate_wiring", "s47_adr_verify_semantics", "s52_init_idempotent",
        "s56_dual_write_parity", "s57_ci_conditional_generation",
        "s58_f1_block_before_exit", "s59_f2_concurrent_atomicity",
        "s60_f3_canonical_block", "s61_f4_write_failure_loud",
        "s62_f5_remedy_by_cause", "s64_f8_f11_dry_run_provider",
        "s65_f9_f10_symlink_and_selfheal", "s66_f1_bare_exit_position",
        "s67_f2_foreign_lines_not_truncated", "s68_f_hookspath_escape",
        "s69_f_trailing_sentinel_no_user_loss", "s70_f_function_body_exit_not_early_exit",
        "s79_wave1_contract_c1_c2_c3_c6", "s90_gate_hardening_acceptance",
        "s92_p0_fixes_acceptance",
    ]
    got = set(core)
    want = set(expected_core)
    if got == want:
        ok("GH6/§2.1 CORE-SET 与契约权威 27 名逐名一致（含 s90 本套件、s92 硬数字）")
    else:
        fail("GH6/§2.1 CORE-SET 与契约权威 27 名逐名一致",
             "缺=%s 多=%s" % (sorted(want - got)[:3], sorted(got - want)[:3]))
    # ---------- A8：checks 必须是「leaf + nested + folded」三类之和恒等式（Lead rev2 裁决） ----------
    summary_line = summary[0] if summary else ""
    mcv = re.search(r'checks=\$?\{?([A-Za-z_][A-Za-z0-9_]*)', summary_line)
    if not mcv:
        fail("GH6/A8 checks 由 leaf+nested+folded 三类之和计算（恒等式，非独立累加器）",
             "汇总行未绑定 checks 计数变量")
        cv = "CHECKS"
    else:
        cv = mcv.group(1)
        assigns = [l for l in lines if re.match(r'^\s*' + re.escape(cv) + r'=\$\(\(', l)]
        self_inc = [l for l in lines if re.search(r'\b' + re.escape(cv) + r'=\$\(\s*' + re.escape(cv) + r'\b', l)]
        expr = " ".join(assigns)
        refs = set(re.findall(r'[A-Za-z_][A-Za-z0-9_]{2,}', expr))
        classes = {r for r in refs if re.match(r'(NESTED|FOLDED)_', r)}
        leaf = bool(refs & {"PASS", "FAIL"}) or any(r.startswith("LEAF") for r in refs)
        if assigns and not self_inc and leaf and len(classes) >= 2 and "+" in expr:
            ok("GH6/A8 checks 由 leaf+nested+folded 三类之和计算（恒等式，非独立累加器）")
        else:
            fail("GH6/A8 checks 由 leaf+nested+folded 三类之和计算（恒等式，非独立累加器）",
                 "三类之和赋值=%d 自增=%d 叶子项=%s 嵌套/折叠项=%s" % (len(assigns), len(self_inc), leaf, sorted(classes)))
    if re.search(r'\b' + re.escape(cv) + r'=\$\(\(' + re.escape(cv), text):
        fail("GH6/A8 checks 不得逐条断言独立累加（会破坏三类之和恒等式）", "命中自增")
    else:
        ok("GH6/A8 checks 不得逐条断言独立累加（会破坏三类之和恒等式）")

    # ---------- A12：子套件 rc != 0 必须进失败谓词（禁止「解析出 fail=0」就判绿） ----------
    def body_of(name):
        for d in defs:
            if d[0] == name:
                return d[2]
        return None

    for fn, label in (("s78_wave13_acceptance", "s78"), ("s81_carrier_audit_acceptance", "s81")):
        b = body_of(fn)
        if b is None:
            fail("GH6/A12 %s 场景函数存在（可检查 rc 失败谓词）" % label, "未找到函数定义")
            continue
        if re.search(r'rc"?\s+-(?:ne|gt)\s+0|rc"?\s*!=\s*0', b):
            ok("GH6/A12 %s 的失败分支以子进程 rc 为条件（不只看解析出的 fail）" % label)
        else:
            fail("GH6/A12 %s 的失败分支以子进程 rc 为条件（不只看解析出的 fail）" % label, "函数体内无 rc 比较")
        if re.search(r'NESTED_(?:FAIL|CHECKS)\s*=\s*\$\(\(', b):
            ok("GH6/A12 %s 在 rc!=0 分支递增 NESTED_* 计数（禁止只 printf RED 不记账）" % label)
        else:
            fail("GH6/A12 %s 在 rc!=0 分支递增 NESTED_* 计数（禁止只 printf RED 不记账）" % label, "无 NESTED_* 递增")

    fold_related = {d[0] for d in defs if "FOLDED_" in d[2]}
    for name, _start, b in defs:
        if any(re.search(r'(?m)^\s+' + re.escape(f) + r'(\s|$)', b) for f in sorted(fold_related)):
            fold_related.add(name)
    folded_scen = ["s88_projection_freshness", "s89_auditfix_acceptance", "s90_gate_hardening_acceptance",
                   "s91_deferred_acceptance", "s92_p0_fixes_acceptance", "s93_negspace_acceptance",
                   "s94_p1_fixes_acceptance"]
    fold_fns = [d for d in defs if re.search(r'FOLDED_[A-Z]+\s*=\s*\$\(\(', d[2])]
    if not fold_fns:
        fail("GH6/A12 折叠路径存在统一解析函数（rc!=0 → FOLDED_* 记失败）", "无 FOLDED_* 递增")
    else:
        fname, _fstart, fbody = fold_fns[0]
        ok("GH6/A12 折叠路径存在统一解析函数（%s）" % fname)
        if re.search(r'rc"?\s+-(?:ne|gt)\s+0|rc"?\s*!=\s*0', fbody):
            ok("GH6/A12 折叠解析函数以子进程 rc 为失败条件")
        else:
            fail("GH6/A12 折叠解析函数以子进程 rc 为失败条件", "函数体内无 rc 比较")
        missed = [n for n in folded_scen
                  if not (body_of(n) and any(re.search(r'(?m)^\s+' + re.escape(f) + r'(\s|$)', body_of(n))
                                             for f in sorted(fold_related)))]
        if not missed:
            ok("GH6/§1.2 折叠解析函数被 s88–s94 全部复用（7/7 场景经统一解析）")
        else:
            fail("GH6/§1.2 折叠解析函数被 s88–s94 全部复用（7/7 场景经统一解析）", "未复用：%s" % ",".join(missed))
    s88 = body_of("s88_projection_freshness")
    fold_buf = any(re.search(r'\$\(|tee ', d[2]) for d in fold_fns) if fold_fns else False
    s88_buf = bool(s88 and re.search(r'\$\(|tee ', s88))
    if s88 is None:
        fail("GH6/§1.2 s88 折叠路径缓冲子套件输出（$() 捕获或 tee 临时文件），非裸跑", "s88 函数未找到")
    elif fold_buf or s88_buf:
        ok("GH6/§1.2 s88 折叠路径缓冲子套件输出（统一解析函数或 s88 体内 $() / tee），非裸跑")
    else:
        fail("GH6/§1.2 s88 折叠路径缓冲子套件输出（统一解析函数或 s88 体内 $() / tee），非裸跑",
             "折叠路径与 s88 体内均无输出捕获")

    # ---------- A12/A13：汇总退出谓词必须同时判三类 fail ----------
    tail_lines = "\n".join(lines[-40:])
    pred_missing = [k for k in ("FAIL", "NESTED_FAIL", "FOLDED_FAIL")
                    if not re.search(r'\b' + k + r'\b', tail_lines)]
    if not pred_missing:
        ok("GH6/A12/A13 汇总退出谓词同时判叶子/嵌套/折叠三类 fail（rc!=0 不得假绿）")
    else:
        fail("GH6/A12/A13 汇总退出谓词同时判叶子/嵌套/折叠三类 fail", "尾部缺 %s" % ",".join(pred_missing))

    # ---------- A10：不可解析子套件必须带可识别标注（禁止静默丢弃） ----------
    if "UNPARSED" in text:
        ok("GH6/A10 不可解析子套件回退计数带 `UNPARSED` 标注（禁止静默丢弃）")
    else:
        fail("GH6/A10 不可解析子套件回退计数带 `UNPARSED` 标注", "全树无 UNPARSED")

    # ---------- 契约 A17（rev4）：场景看门狗预算 env + SCN_CUR 陈旧二次校验 ----------
    scn_env = [l for l in lines if "PONYGO_SCN_TIMEOUT" in l and not l.strip().startswith("#")]
    if scn_env:
        ok("GH6/A17 tests/run.sh 读取 PONYGO_SCN_TIMEOUT（场景看门狗预算 env）")
    else:
        fail("GH6/A17 tests/run.sh 读取 PONYGO_SCN_TIMEOUT（场景看门狗预算 env）", "0 处引用")
    if re.search(r'非法 PONYGO_SCN_TIMEOUT', text):
        ok("GH6/A17 非法 PONYGO_SCN_TIMEOUT 走配置类错误通道（exit 2，与 A14 同源）")
    else:
        fail("GH6/A17 非法 PONYGO_SCN_TIMEOUT 走配置类错误通道（exit 2，与 A14 同源）",
             "无「非法 PONYGO_SCN_TIMEOUT」报错文本")
    scn_cur = [l for l in lines if "SCN_CUR" in l and not l.strip().startswith("#")]
    if len(scn_cur) >= 2 and any(re.search(r'SCN_CUR\}?"?[^\n]*?(?:!=|=|-ne|-eq|\+)', l) for l in scn_cur):
        ok("GH6/A17 SCN_CUR 陈旧看门狗二次校验存在（进度未推进 → 判失败）")
    else:
        fail("GH6/A17 SCN_CUR 陈旧看门狗二次校验存在（进度未推进 → 判失败）",
             "SCN_CUR 代码引用 %d 处" % len(scn_cur))

    # ---------- A16（L3-A ADVISORY）：折叠绿相行不得复用叶子前缀 `  ok   ` ----------
    # 叶子前缀与折叠前缀都从源码 printf 形态解析（不硬编码），再把折叠前缀交给运行时段落锚定行数。
    leaf_prefix = None
    for l in lines:
        m = re.search(r"printf '([^']*)'", l)
        if m and m.group(1).startswith("  ok ") and "PASS" in l:
            leaf_prefix = m.group(1).split('%')[0]
            break
    fold_prefix = None
    for l in lines:
        if "PC_PASS" in l and "PC_SRC" in l and "printf" in l:
            m = re.search(r"printf '([^']*)'", l)
            if m:
                fold_prefix = m.group(1).split('%')[0]
    if leaf_prefix is None:
        fail("GH6/A16 叶子 ok() 前缀可从源码解析（用于比对折叠前缀）", "未找到 ok() 的 printf")
    if fold_prefix is None:
        fail("GH6/A16 折叠绿相行有独立前缀（须可解析，不得复用叶子前缀）", "未找到折叠绿相 printf")
    else:
        out.append("#FOLD-PREFIX|" + fold_prefix + "|")
        if fold_prefix.lstrip().startswith("ok"):
            fail("GH6/A16 折叠绿相行不得复用叶子前缀 `  ok   `", "折叠前缀为 [%s]" % fold_prefix)
        else:
            ok("GH6/A16 折叠绿相行前缀独立于叶子前缀（[%s] vs [%s]）" % (fold_prefix, leaf_prefix or "?"))
        if fold_prefix.startswith("  ") and fold_prefix.strip():
            ok("GH6/A16 折叠前缀保留两空格缩进且可用 grep 锚定（[%s]）" % fold_prefix)
        else:
            fail("GH6/A16 折叠前缀保留两空格缩进且可用 grep 锚定", "实得 [%s]" % fold_prefix)

    # ---------- Lead rev3：进度行机制 scn_begin / scn_end（head/tail 双守卫，禁 RETURN trap） ----------
    bdef = body_of("scn_begin")
    edef = body_of("scn_end")
    if bdef is None:
        fail("GH6/rev3 scn_begin() 定义存在（场景体首行 head 守卫）", "未找到定义")
    else:
        ok("GH6/rev3 scn_begin() 定义存在（场景体首行 head 守卫）")
    if edef is None:
        fail("GH6/rev3 scn_end() 定义存在（场景体末行 tail 记尾）", "未找到定义")
    else:
        ok("GH6/rev3 scn_end() 定义存在（场景体末行 tail 记尾）")
    # 逐场景判定：94 个「顶层裸调用」场景的函数体首行/末行必须分别是 scn_begin / scn_end。
    # 这样比「全树 grep -c」更真实：每个被调用的场景都真的接了头尾守卫。
    def meaningful(body):
        rows = [x for x in (body or "").splitlines()
                if x.strip() and not x.strip().startswith("#") and x.strip() not in ("}", "};")]
        return rows

    head_bad, tail_bad = [], []
    for scn in scenarios:
        rows = meaningful(body_of(scn))
        first = rows[0].strip() if rows else ""
        last = rows[-1].strip() if rows else ""
        if not re.match(r'scn_begin\s*\|\|\s*return 0\s*$', first):
            head_bad.append(scn)
        if not re.match(r'scn_end\s*$', last):
            tail_bad.append(scn)
    if not head_bad:
        ok("GH6/rev3 94/94 场景体首行为 `scn_begin || return 0`（层过滤 + 进度合一的双守卫）")
    else:
        fail("GH6/rev3 94/94 场景体首行为 `scn_begin || return 0`",
             "未接守卫 %d 个：%s" % (len(head_bad), ",".join(head_bad[:3])))
    if not tail_bad:
        ok("GH6/rev3 94/94 场景体末行为 `scn_end`（tail 记尾，禁 RETURN trap）")
    else:
        fail("GH6/rev3 94/94 场景体末行为 `scn_end`",
             "未接尾 %d 个：%s" % (len(tail_bad), ",".join(tail_bad[:3])))
    if re.search(r'trap[^\n]*\bRETURN\b', text):
        fail("GH6/rev3 禁止用 RETURN trap 做场景进度（必须显式 scn_begin/scn_end）", "命中 RETURN trap")
    else:
        ok("GH6/rev3 禁止用 RETURN trap 做场景进度（必须显式 scn_begin/scn_end）")
    prog = (bdef or "") + "\n" + (edef or "")
    if re.search(r'FUNCNAME', prog):
        ok("GH6/rev3 场景 id 由 FUNCNAME 派生（不手填场景名）")
    else:
        fail("GH6/rev3 场景 id 由 FUNCNAME 派生（不手填场景名）", "scn_begin/scn_end 内无 FUNCNAME")
    if re.search(r'date[^\n]*\+%s|\bSECONDS\b', prog):
        ok("GH6/rev3 开始/结束行时间可解析（date +%s 或 SECONDS）")
    else:
        fail("GH6/rev3 开始/结束行时间可解析（date +%s 或 SECONDS）", "无时间基准")
    for fname2, fbody2 in (("scn_begin", bdef), ("scn_end", edef)):
        if not fbody2:
            continue
        if re.search(r'printf|echo', fbody2):
            ok("GH6/rev3 %s 打印可观测进度行（可 grep 锚定）" % fname2)
        else:
            fail("GH6/rev3 %s 打印可观测进度行（可 grep 锚定）" % fname2, "无 printf/echo")

    emit()
except Exception as exc:  # 解析器自身异常必须显性失败，禁止静默吞掉
    out.append("CHECK FAIL GH6/A-B 结构化解析器异常（%s）" % exc)
    out.append("#PARSE-END")
    sys.stdout.write("\n".join(out) + "\n")
PY
)
RUN_PY_RC=$?
assert_zero "GH6/A-B harness：tests/run.sh 结构化解析器正常结束（rc=0）" "$RUN_PY_RC"
if ! printf '%s\n' "$RUN_PY" | grep -qx '#PARSE-END'; then
  bad "GH6/A-B harness：解析器未产出 #PARSE-END 哨兵（输出被截断或崩溃）"
fi
while IFS= read -r line; do
  case "$line" in
    'CHECK OK '*) ok "${line#CHECK OK }" ;;
    'CHECK FAIL '*) bad "${line#CHECK FAIL }" ;;
    '#FOLD-PREFIX|'*) FOLD_PREFIX="${line:13}"; FOLD_PREFIX="${FOLD_PREFIX%|}" ;;
    '#PARSE-END') : ;;
    '') : ;;
    *) printf '  [gh6-parse] %s\n' "$line" ;;
  esac
done <<< "$RUN_PY"

# 独立锚（Lead rev2 裁决）：94 必须在**本用例内以字面量**核对，不把守恒寄托在
# tests/acceptance/p0-fixes/verify-p0.sh:121-122 的「SCN 现算 vs README」自证式比对上
# （那种比对改两处即可洗白）。这里是唯一真源 tests/run.sh 的机械读数。
SCN_LITERAL=$(grep -cE '^s[0-9]+_[a-z0-9_]+$' "$RUN_SH" 2>/dev/null || echo "grep-failed")
assert_eq "GH6/R1 独立锚：场景顶层裸调用行字面恒为 94（不依赖 verify-p0 自证式比对）" 94 "$SCN_LITERAL"

# ============================================================
# 契约 B1：动态断言 PONYGO_TEST_LAYER 合法值域（便宜：正确实现立即 exit 2）
# ============================================================
LOUT=$(mktemp "$SBASE/gh6-layer-out.XXXXXX")
LERR=$(mktemp "$SBASE/gh6-layer-err.XXXXXX")
if command -v timeout >/dev/null 2>&1; then
  ( cd "$ROOT" && PONYGO_TEST_LAYER=bogus timeout "$LAYER_GUARD_SECS" bash tests/run.sh >"$LOUT" 2>"$LERR" )
else
  ( cd "$ROOT" && PONYGO_TEST_LAYER=bogus bash tests/run.sh >"$LOUT" 2>"$LERR" )
fi
LRC=$?
LOUT_TXT=$(cat "$LOUT" 2>/dev/null)
LERR_TXT=$(cat "$LERR" 2>/dev/null)
assert_rc_is "GH6/B1 非法 PONYGO_TEST_LAYER=bogus 必须 exit 2（配置类错误，见 A14）" 2 "$LRC"
assert_contains "GH6/B1 非法层值在 stderr 指出变量名 PONYGO_TEST_LAYER" "$LERR_TXT" "PONYGO_TEST_LAYER"
assert_matches "GH6/B1 stderr 列出合法值域 full|core" "$LERR_TXT" 'full.*core|core.*full'
assert_not_matches "GH6/B1 非法层值不得执行任何场景（stdout 无汇总行）" "$LOUT_TXT" '^==== 测试结果：'
assert_not_matches "GH6/B1 非法层值不得执行任何场景（stdout 无叶子 ok 行）" "$LOUT_TXT" '^  ok   '

# ============================================================
# 契约 A17③（rev4）：非法 PONYGO_SCN_TIMEOUT 必须 exit 2，且不得执行任何场景
# ============================================================
SCNOUT=$(mktemp "$SBASE/gh6-scn-out.XXXXXX")
SCNERR=$(mktemp "$SBASE/gh6-scn-err.XXXXXX")
if command -v timeout >/dev/null 2>&1; then
  ( cd "$ROOT" && PONYGO_SCN_TIMEOUT=abc timeout "$LAYER_GUARD_SECS" bash tests/run.sh >"$SCNOUT" 2>"$SCNERR" )
else
  ( cd "$ROOT" && PONYGO_SCN_TIMEOUT=abc bash tests/run.sh >"$SCNOUT" 2>"$SCNERR" )
fi
SCNRC=$?
SCNOUT_TXT=$(cat "$SCNOUT" 2>/dev/null)
SCNERR_TXT=$(cat "$SCNERR" 2>/dev/null)
assert_rc_is "GH6/A17 非法 PONYGO_SCN_TIMEOUT=abc 必须 exit 2（配置类错误，不得执行场景）" 2 "$SCNRC"
assert_contains "GH6/A17 非法值在 stderr 指出变量名 PONYGO_SCN_TIMEOUT" "$SCNERR_TXT" "PONYGO_SCN_TIMEOUT"
assert_not_matches "GH6/A17 非法值不得执行任何场景（stdout 无汇总行）" "$SCNOUT_TXT" '^==== 测试结果：'
assert_not_matches "GH6/A17 非法值不得执行任何场景（stdout 无叶子 ok 行）" "$SCNOUT_TXT" '^  ok   '

# ============================================================
# 契约 A12 动态小实验（Lead rev2 裁决）：
# 合成一个「##CASE … fail=0 但进程 exit 1」的子套件，验证实现确实以 rc 判红，
# 而不是「解析出 fail=0 就放行」。实现缺失（无 CORE/NONCORE 数据块）时本段按失败记账。
# ------------------------------------------------------------
# 做法：把真实 tests/run.sh 复制进沙箱，**只改分层集合数据块**（让 core 层仅跑 s78/s90），
# 并把这两个子套件目录换成合成夹具；真实仓一个字节都不动。
PROBE_ROOT=$(mktemp -d "$SBASE/gh6-probe.XXXXXX")
PROBE_GUARD_SECS=90
mkdir -p "$PROBE_ROOT/tests/acceptance/wave13" "$PROBE_ROOT/tests/acceptance/gate-hardening"
for f in ponygo README.md; do
  ln -s "$ROOT/$f" "$PROBE_ROOT/$f" 2>/dev/null || true
done
cat > "$PROBE_ROOT/tests/acceptance/wave13/f1_liar.sh" <<'LIAR'
#!/usr/bin/env bash
# 合成嵌套子套件：汇总行自称 fail=0，但进程真退出码 = 1（rc 假绿诱饵）
set -u
printf '##CASE f1_liar.sh pass=3 fail=0\n'
exit 1
LIAR
cat > "$PROBE_ROOT/tests/acceptance/gate-hardening/run-all.sh" <<'LIAR2'
#!/usr/bin/env bash
# 合成折叠子套件：##SUMMARY 自称 failed=0，但进程真退出码 = 1（rc 假绿诱饵）
set -u
printf '##CASE stub_case.sh pass=3 fail=0\n'
printf '##SUMMARY gate-hardening cases=1 failed=0\n'
exit 1
LIAR2
if python3 - "$RUN_SH" "$PROBE_ROOT/tests/run.sh" <<'PYPROBE'
import re
import sys

src, dst = sys.argv[1], sys.argv[2]
lines = open(src, encoding="utf-8").read().splitlines(keepends=True)


def block(tag):
    start = "# >>> ponygo-test-layer: %s >>>" % tag
    end = "# <<< ponygo-test-layer: %s <<<" % tag
    s = [i for i, l in enumerate(lines) if l.strip() == start]
    e = [i for i, l in enumerate(lines) if l.strip() == end]
    if not s or not e or e[0] < s[0]:
        return None
    return s[0], e[0]


core_span = block("CORE-SET")
noncore_span = block("NONCORE-SET")
if not core_span or not noncore_span:
    raise SystemExit(3)  # 契约 B6 未实现 → 探针无法构造
names = [l.strip() for l in lines if re.fullmatch(r's[0-9]+_[a-z0-9_]+', l.strip())]
probe_core = ["s78_wave13_acceptance", "s90_gate_hardening_acceptance"]
if any(x not in names for x in probe_core):
    raise SystemExit(4)
rest = [x for x in names if x not in probe_core]
# 只替换两个数据块的块内行（从后往前替换，行号不漂移）；其余行逐字节保持，
# 故探针跑的就是真实聚合逻辑，而不是手写复制品。
spans = (("CORE", core_span, probe_core), ("NONCORE", noncore_span, rest))
for tag, span, items in sorted(spans, key=lambda t: -t[1][0]):
    s, e = span
    lines[s + 1:e] = ["%s %s\n" % (tag, x) for x in items]
open(dst, "w", encoding="utf-8").write("".join(lines))
raise SystemExit(0)
PYPROBE
then
  PROBE_BUILD=0
else
  PROBE_BUILD=$?
fi
if [ "$PROBE_BUILD" -eq 0 ]; then
  POUT=$(mktemp "$SBASE/gh6-probe-out.XXXXXX")
  PERR=$(mktemp "$SBASE/gh6-probe-err.XXXXXX")
  ( cd "$PROBE_ROOT" && PONYGO_TEST_LAYER=core timeout "$PROBE_GUARD_SECS" bash tests/run.sh >"$POUT" 2>"$PERR" )
  PRC=$?
  POUT_TXT=$(cat "$POUT" 2>/dev/null)
  assert_nonzero "GH6/A12 动态实验：子套件 rc=1 而解析出 fail=0 → 汇总必须非零退出（rc 不得假绿）" "$PRC"
  assert_matches "GH6/A12 动态实验：探针 core 层计数由集合推导（scenarios=2 skipped=92，非硬编码 27）" \
    "$POUT_TXT" '^==== 测试结果：scenarios=2 pass=[0-9]+ fail=[0-9]+ checks=[0-9]+ skipped=92 ====$'
  # ---------- 契约 A18（rev4）：SKIP 行必须在**真实运行**上钉死 ----------
  # 只查 run.sh 里的 printf 形态是可以被绕过的（把 s78_wave13_acceptance 整体塞进第一个 %s 也能绿），
  # 故这里消费派生复制件 PONYGO_TEST_LAYER=core 的**真实 stdout**。
  SKIP_TXT=$(printf '%s\n' "$POUT_TXT" | grep '^  SKIP ' || :)
  SKIP_N=$(printf '%s\n' "$SKIP_TXT" | grep -c '^  SKIP ' || :)
  SKIP_BAD_N=$(printf '%s\n' "$SKIP_TXT" | grep -Evc '^  SKIP s[0-9][0-9] [a-z0-9_]+（layer=core）$' || :)
  SKIP_SUM=$(printf '%s\n' "$POUT_TXT" | sed -n 's/^==== 测试结果：scenarios=[0-9]* pass=[0-9]* fail=[0-9]* checks=[0-9]* skipped=\([0-9][0-9]*\) ====$/\1/p' | head -n1)
  if [ "${SKIP_N:-0}" -gt 0 ] && [ "${SKIP_BAD_N:-1}" -eq 0 ]; then
    ok "GH6/A18 真实运行 SKIP 行逐行匹配 /^  SKIP s[0-9][0-9] [a-z0-9_]+（layer=core）$/（共 ${SKIP_N} 行）"
  else
    bad "GH6/A18 真实运行 SKIP 行逐行匹配 /^  SKIP s[0-9][0-9] [a-z0-9_]+（layer=core）$/（不合规 ${SKIP_BAD_N:-?} 行 / 共 ${SKIP_N:-0} 行）"
    printf '%s\n' "$SKIP_TXT" | grep -Ev '^  SKIP s[0-9][0-9] [a-z0-9_]+（layer=core）$' | head -3
  fi
  assert_eq "GH6/A18 真实运行 SKIP 行数 == 汇总 skipped（派生副本 core 层应为 92）" "${SKIP_SUM:-?}" "${SKIP_N:-0}"

  # ---------- 契约 A17④（rev4）：未设 PONYGO_SCN_TIMEOUT 时零行为差异（同一副本对照）----------
  POUT2=$(mktemp "$SBASE/gh6-probe-out2.XXXXXX")
  PERR2=$(mktemp "$SBASE/gh6-probe-err2.XXXXXX")
  if command -v timeout >/dev/null 2>&1; then
    ( cd "$PROBE_ROOT" && PONYGO_TEST_LAYER=core PONYGO_SCN_TIMEOUT=999 timeout "$PROBE_GUARD_SECS" bash tests/run.sh >"$POUT2" 2>"$PERR2" )
  else
    ( cd "$PROBE_ROOT" && PONYGO_TEST_LAYER=core PONYGO_SCN_TIMEOUT=999 bash tests/run.sh >"$POUT2" 2>"$PERR2" )
  fi
  PRC2=$?
  SUM_A=$(printf '%s\n' "$POUT_TXT" | grep '^==== 测试结果：' | head -n1)
  SUM_B=$(sed -n '/^==== 测试结果：/p' "$POUT2" 2>/dev/null | head -n1)
  if [ "$PRC" -eq "$PRC2" ] && [ -n "$SUM_A" ] && [ "$SUM_A" = "$SUM_B" ]; then
    ok "GH6/A17 未设 PONYGO_SCN_TIMEOUT 与显式合法值等价（同一派生副本：汇总行逐字相同、退出码相同）"
  else
    bad "GH6/A17 未设 PONYGO_SCN_TIMEOUT 与显式合法值等价（rc ${PRC}/${PRC2}；汇总 [${SUM_A}] vs [${SUM_B}]）"
  fi

  # ---------- 契约 C14（rev6）：PONYGO_SCN_TIMEOUT 越界 exit 2；上界 86400 必须可跑 ----------
  # 两者都在**派生副本**上跑，core 层只含 2 个合成场景：控时且避免 s90→gh6 递归。
  BIGO=$(mktemp "$SBASE/gh6-scnbig-out.XXXXXX")
  BIGE=$(mktemp "$SBASE/gh6-scnbig-err.XXXXXX")
  if command -v timeout >/dev/null 2>&1; then
    ( cd "$PROBE_ROOT" && PONYGO_SCN_TIMEOUT=99999999999999999999 timeout "$PROBE_GUARD_SECS" bash tests/run.sh >"$BIGO" 2>"$BIGE" )
  else
    ( cd "$PROBE_ROOT" && PONYGO_SCN_TIMEOUT=99999999999999999999 bash tests/run.sh >"$BIGO" 2>"$BIGE" )
  fi
  BIGRC=$?
  assert_rc_is "GH6/C14 越界 PONYGO_SCN_TIMEOUT（20 位）必须 exit 2（值域 1..86400）" 2 "$BIGRC"
  assert_not_matches "GH6/C14 越界 PONYGO_SCN_TIMEOUT 不得执行场景（stdout 无汇总行）" \
    "$(cat "$BIGO" 2>/dev/null)" '^==== 测试结果：'
  # 上界可跑：把两个合成子套件换成「fail=0 + exit 0」，86400 必须放行（正对照）
  cat > "$PROBE_ROOT/tests/acceptance/wave13/f1_liar.sh" <<'OKSTUB'
#!/usr/bin/env bash
# 合成嵌套子套件（正对照）：fail=0 且 exit 0
printf '##CASE f1_ok.sh pass=3 fail=0\n'
exit 0
OKSTUB
  cat > "$PROBE_ROOT/tests/acceptance/gate-hardening/run-all.sh" <<'OKSTUB2'
#!/usr/bin/env bash
# 合成折叠子套件（正对照）：fail=0 且 exit 0
printf '##CASE stub_case.sh pass=3 fail=0\n'
printf '##SUMMARY gate-hardening cases=1 failed=0\n'
exit 0
OKSTUB2
  CAPO=$(mktemp "$SBASE/gh6-scncap-out.XXXXXX")
  CAPE=$(mktemp "$SBASE/gh6-scncap-err.XXXXXX")
  if command -v timeout >/dev/null 2>&1; then
    ( cd "$PROBE_ROOT" && PONYGO_SCN_TIMEOUT=86400 PONYGO_TEST_LAYER=core timeout "$PROBE_GUARD_SECS" bash tests/run.sh >"$CAPO" 2>"$CAPE" )
  else
    ( cd "$PROBE_ROOT" && PONYGO_SCN_TIMEOUT=86400 PONYGO_TEST_LAYER=core bash tests/run.sh >"$CAPO" 2>"$CAPE" )
  fi
  CAPRC=$?
  assert_rc_is "GH6/C14 上界 PONYGO_SCN_TIMEOUT=86400 必须可跑（派生副本 core 层 → exit 0）" 0 "$CAPRC"
  assert_matches "GH6/C14 上界运行确实执行场景（汇总行 scenarios=2）" \
    "$(cat "$CAPO" 2>/dev/null)" '^==== 测试结果：scenarios=2 '

else
  bad "GH6/A12 动态实验：无法构造探针（tests/run.sh 缺成对的 CORE/NONCORE 数据块或场景名不符 → 契约 B6 未实现，构造 rc=$PROBE_BUILD）"
fi

# ============================================================
# 契约 A16（L3-A ADVISORY）：折叠绿相行**不得**复用叶子前缀 `  ok   `；
#   pass= 只来自叶子，折叠绿相行必须走独立前缀（逐字前缀由源码 fold 打印行推导，不硬编码）。
# ------------------------------------------------------------
# 做法：沙箱派生复制件（core 只含 7 个折叠场景）+ 7 个子套件正对照存根。
# 于是：汇总 pass= 必为 0、`^  ok   ` 行必为 0，而折叠前缀行必为 7。
gh6_derive_copy() { # <dst_root> <core-scenario> [<core-scenario> ...]
  local dst="$1"
  shift
  mkdir -p "$dst/tests/acceptance"
  for f in ponygo README.md; do
    ln -sfn "$ROOT/$f" "$dst/$f" 2>/dev/null || true
  done
  python3 - "$RUN_SH" "$dst/tests/run.sh" "$@" <<'PYDERIVE'
import re
import sys

src, dst, core = sys.argv[1], sys.argv[2], sys.argv[3:]
lines = open(src, encoding="utf-8").read().splitlines(keepends=True)


def span(tag):
    s = [i for i, l in enumerate(lines) if l.strip() == "# >>> ponygo-test-layer: %s >>>" % tag]
    e = [i for i, l in enumerate(lines) if l.strip() == "# <<< ponygo-test-layer: %s <<<" % tag]
    if not s or not e or e[0] < s[0]:
        return None
    return s[0], e[0]


c, n = span("CORE-SET"), span("NONCORE-SET")
if not c or not n:
    raise SystemExit(3)  # 契约 B6 未实现
names = [l.strip() for l in lines if re.fullmatch(r's[0-9]+_[a-z0-9_]+', l.strip())]
if any(x not in names for x in core):
    raise SystemExit(4)
rest = [x for x in names if x not in core]
# 只改两个分层数据块的块内行；其余行逐字节保持 → 探针跑的是真实聚合/记账逻辑。
for tag, sp, items in sorted((("CORE", c, core), ("NONCORE", n, rest)), key=lambda t: -t[1][0]):
    s, e = sp
    lines[s + 1:e] = ["%s %s\n" % (tag, x) for x in items]
open(dst, "w", encoding="utf-8").write("".join(lines))
raise SystemExit(0)
PYDERIVE
}

gh6_stub_suite() { # <path>：合成折叠子套件（正对照 fail=0 / exit 0）
  mkdir -p "$(dirname "$1")"
  cat > "$1" <<'FOLDSTUB'
#!/usr/bin/env bash
# 合成折叠子套件（正对照）：汇总自称 fail=0，进程也 exit 0
printf '##CASE stub_case.sh pass=3 fail=0\n'
exit 0
FOLDSTUB
}

FOLD_ROOT=$(mktemp -d "$SBASE/gh6-fold.XXXXXX")
FOLD_CORE="s88_projection_freshness s89_auditfix_acceptance s90_gate_hardening_acceptance s91_deferred_acceptance s92_p0_fixes_acceptance s93_negspace_acceptance s94_p1_fixes_acceptance"
FOLD_BUILD=1
# shellcheck disable=SC2086
gh6_derive_copy "$FOLD_ROOT" $FOLD_CORE
FOLD_BUILD=$?
if [ "$FOLD_BUILD" -eq 0 ]; then
  gh6_stub_suite "$FOLD_ROOT/tests/acceptance/projection-freshness/run.sh"
  gh6_stub_suite "$FOLD_ROOT/tests/acceptance/auditfix/run-all.sh"
  gh6_stub_suite "$FOLD_ROOT/tests/acceptance/gate-hardening/run-all.sh"
  gh6_stub_suite "$FOLD_ROOT/tests/acceptance/deferred/run-all.sh"
  gh6_stub_suite "$FOLD_ROOT/tests/acceptance/p0-fixes/verify-p0.sh"
  gh6_stub_suite "$FOLD_ROOT/tests/acceptance/negspace/run-all.sh"
  gh6_stub_suite "$FOLD_ROOT/tests/acceptance/p1-fixes/verify-p1.sh"
  FOUTF=$(mktemp "$SBASE/gh6-fold-out.XXXXXX")
  FERRF=$(mktemp "$SBASE/gh6-fold-err.XXXXXX")
  if command -v timeout >/dev/null 2>&1; then
    ( cd "$FOLD_ROOT" && PONYGO_TEST_LAYER=core timeout "$PROBE_GUARD_SECS" bash tests/run.sh >"$FOUTF" 2>"$FERRF" )
  else
    ( cd "$FOLD_ROOT" && PONYGO_TEST_LAYER=core bash tests/run.sh >"$FOUTF" 2>"$FERRF" )
  fi
  FOLDRC=$?
  FOLD_TXT=$(cat "$FOUTF" 2>/dev/null)
  FOLD_SUM=$(printf '%s\n' "$FOLD_TXT" | grep '^==== 测试结果：' | head -n1)
  FOLD_PASS_N=$(printf '%s\n' "$FOLD_SUM" | sed -n 's/.* pass=\([0-9][0-9]*\) .*/\1/p')
  LEAF_OK_N=$(printf '%s\n' "$FOLD_TXT" | grep -c '^  ok   ' || :)
  if [ -n "${FOLD_PREFIX:-}" ]; then
    FOLD_LINE_N=$(printf '%s\n' "$FOLD_TXT" | awk -v p="$FOLD_PREFIX" 'index($0, p) == 1 { n++ } END { print n + 0 }')
  else
    FOLD_LINE_N="no-prefix"
  fi
  assert_rc_is "GH6/A16 折叠正对照（core 只含 7 个折叠场景）必须 exit 0" 0 "$FOLDRC"
  assert_eq "GH6/A16 折叠绿相行不得复用叶子前缀（grep -c '^  ok   ' == 汇总 pass=）" \
    "${FOLD_PASS_N:-?}" "${LEAF_OK_N:-?}"
  assert_eq "GH6/A16 折叠绿相行使用独立前缀且 7 个折叠场景各一行" 7 "${FOLD_LINE_N:-?}"
else
  bad "GH6/A16 无法构造折叠派生存根（tests/run.sh 缺 CORE/NONCORE 数据块或折叠场景名不符，构造 rc=$FOLD_BUILD）"
fi

# ============================================================
# 契约 A17（L3-A ADVISORY）：看门狗不得占住 stdout、不得留孤儿
# ------------------------------------------------------------
# 沙箱派生复制件 core 只留 1 个场景 + PONYGO_SCN_TIMEOUT=10：
#   - 若 watcher 持有调用方管道，`| tail -1` 会被拖到 ~10s（断言 ≤5s）；
#   - 若 watcher 的 sleep 孙进程未被回收，事后 ps 仍有 `sleep 10` 残留（断言零残留）。
ORPH_ROOT=$(mktemp -d "$SBASE/gh6-orphan.XXXXXX")
ORPH_BUILD=1
gh6_derive_copy "$ORPH_ROOT" s78_wave13_acceptance
ORPH_BUILD=$?
if [ "$ORPH_BUILD" -eq 0 ]; then
  mkdir -p "$ORPH_ROOT/tests/acceptance/wave13"
  cat > "$ORPH_ROOT/tests/acceptance/wave13/f1_ok.sh" <<'ORPHSTUB'
#!/usr/bin/env bash
# 合成嵌套子套件（正对照）：fail=0 且 exit 0
printf '##CASE f1_ok.sh pass=3 fail=0\n'
exit 0
ORPHSTUB
  ORPH_BEFORE=$(ps -ef 2>/dev/null | grep -c '[s]leep 10' || :)
  T0=$(date +%s)
  ORPH_LAST=$( ( cd "$ORPH_ROOT" && PONYGO_TEST_LAYER=core PONYGO_SCN_TIMEOUT=10 bash tests/run.sh 2>/dev/null ) | tail -1 )
  ORPH_ELAPSED=$(( $(date +%s) - T0 ))
  if [ "$ORPH_ELAPSED" -le 5 ]; then
    ok "GH6/A17 看门狗不占 stdout（管道 tail 用时 ${ORPH_ELAPSED}s ≤ 5s，SCN_TIMEOUT=10 未拖住）"
  else
    bad "GH6/A17 看门狗不占 stdout（管道 tail 用时 ${ORPH_ELAPSED}s > 5s，疑似被当轮看门狗拖住）"
  fi
  assert_matches "GH6/A17 管道末行仍是汇总行（进度/看门狗均未污染 stdout 尾部）" \
    "$ORPH_LAST" '^==== 测试结果：'
  ORPH_AFTER=$(ps -ef 2>/dev/null | grep -c '[s]leep 10' || :)
  assert_eq "GH6/A17 看门狗不留孤儿进程（事后 ps 的 sleep 10 计数不增加）" \
    "${ORPH_BEFORE:-0}" "${ORPH_AFTER:-0}"
else
  bad "GH6/A17 无法构造看门狗派生存根（tests/run.sh 缺 CORE/NONCORE 数据块，构造 rc=$ORPH_BUILD）"
fi

# ============================================================
# 契约 C（§3）：spec 软超时分档（静态 + 一次快速退出码探针）
# ============================================================
assert_file_matches "GH6/C1 ponygo 处理 PONYGO_SPEC_TIMEOUT" "$CLI_SRC" 'PONYGO_SPEC_TIMEOUT'
assert_file_matches "GH6/C2 ponygo 对非法 PONYGO_SPEC_TIMEOUT 报错（可定位变量名）" "$CLI_SRC" '非法 PONYGO_SPEC_TIMEOUT'
assert_file_not_matches "GH6/C3 软超时不得再是字面量 90（须 env/平台分档推导）" "$CLI_SRC" 'timeout -k 5 +90([^0-9]|$)'
assert_file_matches "GH6/C3/C5 软超时以变量传入且 KILL 兜底保持字面 5s" "$CLI_SRC" 'timeout -k 5 +"?\$\{?[A-Za-z_]'
assert_file_not_matches "GH6/C5 KILL 兜底 5s 不得参数化" "$CLI_SRC" 'timeout -k +\$'
assert_file_matches "GH6/C4 Windows 判定（OSTYPE msys*/cygwin* 或 uname -s MINGW/MSYS/CYGWIN）" "$CLI_SRC" 'msys|cygwin|MINGW|MSYS|CYGWIN'

# C3 平台分档默认值：必须是「赋值」而非散落字面量，且 Windows 分支的 180 必须与平台判定同域
# （禁止「180 只出现在注释里」或「180/90 与平台判定无因果」的伪实现）。
C_PY=$(python3 - "$CLI_SRC" <<'PY2'
import re
import sys

text = open(sys.argv[1], encoding="utf-8", errors="replace").read()
lines = [re.sub(r'#.*$', '', l) for l in text.splitlines()]
out = []
plat = re.compile(r'msys|cygwin|MINGW|MSYS|CYGWIN|windows|win_|is_win')


def ok(desc):
    out.append("CHECK OK " + desc)


def fail(desc, detail=""):
    out.append("CHECK FAIL " + desc + ("（实得：%s）" % detail if detail else ""))


def window(i, radius=30):
    return "\n".join(lines[max(0, i - radius):i + radius + 1])


def defaults(value):
    hits = [i for i, l in enumerate(lines) if re.search(r'(=|:-)[ \t]*' + value + r'([^0-9]|$)', l)]
    return hits


try:
    win = defaults("180")
    lin = defaults("90")
    if not win:
        fail("GH6/C3 Windows 默认软超时 180s 以赋值形式落地", "无 `=180`/`:-180` 赋值")
    elif any(plat.search(window(i)) for i in win):
        ok("GH6/C3 Windows 默认软超时 180s 以赋值形式落地且与平台判定同域（同一分支窗口内）")
    else:
        fail("GH6/C3 Windows 默认软超时 180s 与平台判定同域",
             "180 赋值离平台判定 >30 行：%d" % win[0])
    if not lin:
        fail("GH6/C3 非 Windows 默认软超时 90s 以赋值形式落地（Linux 现状不变）", "无 `=90`/`:-90` 赋值")
    elif any(plat.search(window(i)) for i in lin):
        ok("GH6/C3 非 Windows 默认软超时 90s 以赋值形式落地且与平台判定同域")
    else:
        fail("GH6/C3 非 Windows 默认软超时 90s 与平台判定同域", "90 赋值离平台判定 >30 行：%d" % lin[0])
    # ---------- C11（rev3）：timeout 护栏必须经**语义探针**启用，仅存在性判定判 FAIL ----------
    guard_idx = [i for i, l in enumerate(lines) if "command -v timeout" in l]
    probe_re = re.compile(r'timeout\s+[0-9]+\s+bash\s+-c')
    near = []
    if not guard_idx:
        fail("GH6/C11 存在 `command -v timeout` 判定点（可挂语义探针）", "0 处")
    else:
        near = [i for i in guard_idx
                if any(probe_re.search(lines[j]) for j in range(max(0, i - 10), min(len(lines), i + 11)))]
        if near:
            ok("GH6/C11 `command -v timeout` 之后有语义探针（timeout N bash -c …）才启用护栏")
        else:
            fail("GH6/C11 `command -v timeout` 之后必须有语义探针才启用护栏（仅存在性判定不算）",
                 "%d 处判定点均无探针" % len(guard_idx))
    # 探针失败必须留可机械断言的固定原因行（E2 口径），不得静默降级。
    warn_fix = "ponygo: WARN spec 守卫不可用：timeout 语义探针失败"
    if warn_fix in text:
        ok("GH6/C11 探针失败打固定 WARN 原因行（`ponygo: WARN spec 守卫不可用：timeout 语义探针失败（rc=<rc>）`）")
        if re.search(r'timeout 语义探针失败[^\n]*rc=', text):
            ok("GH6/C11 原因行含探针真实 rc（可定位失败原因）")
        else:
            fail("GH6/C11 原因行含探针真实 rc（可定位失败原因）", "无 rc= 片段")
    else:
        fail("GH6/C11 探针失败打固定 WARN 原因行（`ponygo: WARN spec 守卫不可用：timeout 语义探针失败（rc=<rc>）`）",
             "未找到固定形态")
    # 位置：探针必须在 `command -v timeout` 之后、预算解析（PONYGO_SPEC_TIMEOUT）之前。
    budget_ln = [i for i, l in enumerate(lines) if "PONYGO_SPEC_TIMEOUT" in l]
    probe_idx = [i for i, l in enumerate(lines) if probe_re.search(l)]
    if guard_idx and probe_idx and budget_ln:
        g, pr = min(guard_idx), min(probe_idx)
        later = [b for b in budget_ln if b > pr]
        if g <= pr and later:
            ok("GH6/C11 探针位置正确：`command -v timeout` 之后 → 预算解析（PONYGO_SPEC_TIMEOUT）之前")
        else:
            fail("GH6/C11 探针位置正确：`command -v timeout` 之后 → 预算解析之前",
                 "guard=%d probe=%d 探针之后无预算行" % (g, pr))
    else:
        fail("GH6/C11 探针位置正确：`command -v timeout` 之后 → 预算解析之前",
             "缺 guard/probe/budget 之一（%d/%d/%d）" % (len(guard_idx), len(probe_idx), len(budget_ln)))

    # ---------- C12（rev3）：结论区必须打印可 grep 的预算行 ----------
    budget_idx = [i for i, l in enumerate(lines) if "spec 预算=" in l]
    if budget_idx and all(any("来源" in lines[j] for j in range(i, min(len(lines), i + 4)))
                          for i in budget_idx):
        ok("GH6/C12 `audit --run-specs` 结论区打印可 grep 的预算行 `spec 预算=<N>s（来源：…）`")
    else:
        fail("GH6/C12 `audit --run-specs` 结论区打印可 grep 的预算行 `spec 预算=<N>s（来源：…）`",
             "预算行缺失或缺来源标注")

    out.append("#PARSE-END")
    sys.stdout.write("\n".join(out) + "\n")
except Exception as exc:
    out.append("CHECK FAIL GH6/C3 默认值静态解析器异常（%s）" % exc)
    out.append("#PARSE-END")
    sys.stdout.write("\n".join(out) + "\n")
PY2
)
C_PY_RC=$?
assert_zero "GH6/C3 harness：默认值静态解析器正常结束（rc=0）" "$C_PY_RC"
if ! printf '%s\n' "$C_PY" | grep -qx '#PARSE-END'; then
  bad "GH6/C3 harness：解析器未产出 #PARSE-END 哨兵（输出被截断或崩溃）"
fi
while IFS= read -r line; do
  case "$line" in
    'CHECK OK '*) ok "${line#CHECK OK }" ;;
    'CHECK FAIL '*) bad "${line#CHECK FAIL }" ;;
    '#PARSE-END' | '') : ;;
    *) printf '  [gh6-parse] %s\n' "$line" ;;
  esac
done <<< "$C_PY"

SOUT=$(mktemp "$SBASE/gh6-spec-out.XXXXXX")
SERR=$(mktemp "$SBASE/gh6-spec-err.XXXXXX")
if command -v timeout >/dev/null 2>&1; then
  ( cd "$ROOT" && PONYGO_SPEC_TIMEOUT=abc timeout "$SPEC_GUARD_SECS" bash ponygo audit --run-specs >"$SOUT" 2>"$SERR" )
else
  ( cd "$ROOT" && PONYGO_SPEC_TIMEOUT=abc bash ponygo audit --run-specs >"$SOUT" 2>"$SERR" )
fi
SRC=$?
SERR_TXT=$(cat "$SERR" 2>/dev/null)
assert_rc_is "GH6/C2 非法 PONYGO_SPEC_TIMEOUT=abc 必须 exit 2（禁止静默回落默认）" 2 "$SRC"
assert_contains "GH6/C2 非法值在 stderr 指出变量名" "$SERR_TXT" "PONYGO_SPEC_TIMEOUT"
assert_matches "GH6/C2 非法值报错语义可识别（非法/FAIL）" "$SERR_TXT" '非法|FAIL'

# AT2 外层兜底：与 CLI 同源推导（内层 + 30），禁止字面量 120（C8/C9）
assert_file_matches "GH6/C8 AT2 外层兜底由内层预算推导（+30）" "$AT2" '\+[[:space:]]*30'
assert_file_matches "GH6/C8 AT2 与 CLI 同源读取 PONYGO_SPEC_TIMEOUT" "$AT2" 'PONYGO_SPEC_TIMEOUT'
assert_file_matches "GH6/C8 AT2 平台分档判定与 CLI 同源" "$AT2" 'msys|cygwin|MINGW|MSYS|CYGWIN|uname'
AT2_CODE=$(sed -e 's/#.*$//' "$AT2")
if printf '%s\n' "$AT2_CODE" | grep -Eq '(^|[^0-9])120([^0-9]|$)'; then
  bad "GH6/C8 AT2 不得保留字面量 120（须同一 env/平台推导，注释外代码零命中）"
else
  ok "GH6/C8 AT2 不得保留字面量 120（注释外代码零命中）"
fi
assert_file_matches "GH6/C9 AT2 保留「rc=124 即护栏失效」判据" "$AT2" '124'
assert_file_matches "GH6/C9 AT2 保留「耗时落在外层窗口内」判据" "$AT2" 'ELAPSED'

# ============================================================
# 契约 C14（rev6）：三个超时 env 的值域 1..86400，越界 → exit 2；空串 = 未设（不得静默 2）
# ============================================================
C14O=$(mktemp "$SBASE/gh6-c14-out.XXXXXX")
C14E=$(mktemp "$SBASE/gh6-c14-err.XXXXXX")
if command -v timeout >/dev/null 2>&1; then
  ( cd "$ROOT" && PONYGO_SPEC_TIMEOUT=99999999999999999999 timeout "$SPEC_GUARD_SECS" bash ponygo audit --run-specs >"$C14O" 2>"$C14E" )
else
  ( cd "$ROOT" && PONYGO_SPEC_TIMEOUT=99999999999999999999 bash ponygo audit --run-specs >"$C14O" 2>"$C14E" )
fi
C14RC=$?
C14E_TXT=$(cat "$C14E" 2>/dev/null)
assert_rc_is "GH6/C14 越界 PONYGO_SPEC_TIMEOUT（20 位）必须 exit 2（值域 1..86400，越界不得静默回落）" 2 "$C14RC"
assert_contains "GH6/C14 越界 PONYGO_SPEC_TIMEOUT 在 stderr 点名变量" "$C14E_TXT" "PONYGO_SPEC_TIMEOUT"

# 空串 = 未设：必须走平台默认预算并 exit 0（不得因空串静默 exit 2）
C14O2=$(mktemp "$SBASE/gh6-c14-out2.XXXXXX")
C14E2=$(mktemp "$SBASE/gh6-c14-err2.XXXXXX")
if command -v timeout >/dev/null 2>&1; then
  ( cd "$ROOT" && PONYGO_SPEC_TIMEOUT= timeout "$SPEC_GUARD_SECS" bash ponygo audit --run-specs >"$C14O2" 2>"$C14E2" )
else
  ( cd "$ROOT" && PONYGO_SPEC_TIMEOUT= bash ponygo audit --run-specs >"$C14O2" 2>"$C14E2" )
fi
C14RC2=$?
C14O2_TXT=$(cat "$C14O2" 2>/dev/null)
if is_windows_platform; then C14_DEFAULT=180; else C14_DEFAULT=90; fi
assert_rc_is "GH6/C14 空串 PONYGO_SPEC_TIMEOUT 视作未设 → exit 0（不得静默 exit 2）" 0 "$C14RC2"
assert_matches "GH6/C14 空串时预算行取平台默认（Windows 180s / 其他 90s，来源标注=平台默认）" \
  "$C14O2_TXT" "spec 预算=${C14_DEFAULT}s（来源：平台默认）"

# 出厂 spec 侧：PONYGO_GATE_SPEC_TIMEOUT 越界同样 exit 2
GSPO=$(mktemp "$SBASE/gh6-gsp-out.XXXXXX")
GSPE=$(mktemp "$SBASE/gh6-gsp-err.XXXXXX")
if command -v timeout >/dev/null 2>&1; then
  ( cd "$ROOT" && PONYGO_GATE_SPEC_TIMEOUT=99999999999999999999 timeout "$SPEC_GUARD_SECS" bash .meta/gates/adr-verify.spec.sh >"$GSPO" 2>"$GSPE" )
else
  ( cd "$ROOT" && PONYGO_GATE_SPEC_TIMEOUT=99999999999999999999 bash .meta/gates/adr-verify.spec.sh >"$GSPO" 2>"$GSPE" )
fi
GSPRC=$?
GSPE_TXT=$(cat "$GSPE" 2>/dev/null)
assert_rc_is "GH6/C14 越界 PONYGO_GATE_SPEC_TIMEOUT（20 位）必须 exit 2（spec 自包裹同口径）" 2 "$GSPRC"
assert_contains "GH6/C14 spec 侧越界值在 stderr 点名变量" "$GSPE_TXT" "PONYGO_GATE_SPEC_TIMEOUT"

# ============================================================
# 契约 C13（rev4 收窄闭包）：3 个出厂 spec 自包裹**只读** PONYGO_GATE_SPEC_TIMEOUT
#   —— 平台判定只允许存在于 ponygo 一处（spec 内不得再做 OSTYPE/uname 探测）；
#      未设默认 30s、KILL 兜底恒 5s（timeout -k 5）、非法值 exit 2；repo↔heredoc 逐字节一致。
# ============================================================
for spec in adr-verify scratch-hygiene archive-verify; do
  SPEC_F="$ROOT/.meta/gates/$spec.spec.sh"
  assert_file "GH6/C13 出厂 spec 存在：$spec.spec.sh" "$SPEC_F"
  assert_file_matches "GH6/C13($spec) 自包裹只读 PONYGO_GATE_SPEC_TIMEOUT（env 单一来源）" "$SPEC_F" 'PONYGO_GATE_SPEC_TIMEOUT'
  assert_file_matches "GH6/C13($spec) 未设时默认 30s" "$SPEC_F" '(PONYGO_GATE_SPEC_TIMEOUT:?-?[[:space:]]*30|=30([^0-9]|$))'
  assert_file_matches "GH6/C13($spec) KILL 兜底仍为字面 5s（timeout -k 5）" "$SPEC_F" 'timeout -k 5'
  assert_file_matches "GH6/C13($spec) 非法值报错含变量名" "$SPEC_F" '非法 PONYGO_GATE_SPEC_TIMEOUT'
  assert_file_matches "GH6/C13($spec) 非法值 exit 2（不静默回落默认）" "$SPEC_F" 'exit 2'
  assert_file_not_matches "GH6/C13($spec) spec 内不得再做平台判定（OSTYPE/uname 收敛到 ponygo 一处）" "$SPEC_F" 'OSTYPE|uname'
  assert_file_not_matches "GH6/C13($spec) 不得保留字面量 exec timeout 30" "$SPEC_F" 'exec timeout 30'
done
assert_file_matches "GH6/C13 ponygo 的 spec heredoc 副本同步分档（同 env 名）" "$CLI_SRC" 'PONYGO_GATE_SPEC_TIMEOUT'
assert_file_not_matches "GH6/C13 ponygo heredoc 内不得残留字面量 exec timeout 30" "$CLI_SRC" 'exec timeout 30'
assert_file_matches "GH6/C13 平台判定只在 ponygo 一处（spec 侧零平台分支）" "$CLI_SRC" 'msys|cygwin|MINGW|MSYS|CYGWIN'
assert_file_matches "GH6/C13 ponygo 调用 spec 时下传 PONYGO_GATE_SPEC_TIMEOUT（派生一处）" "$CLI_SRC" '(^|[^A-Za-z_])PONYGO_GATE_SPEC_TIMEOUT=|export PONYGO_GATE_SPEC_TIMEOUT'
# 逐字节一致由 CLI 宇宙表门禁承担（契约 R4：模板 ↔ 仓库文件零漂移），比逐文件抽 heredoc 更权威且更便宜。
UC_TXT=$( cd "$ROOT" && ./ponygo upgrade --check 2>&1 )
UC_RC=$?
assert_rc_is "GH6/C13 repo 副本与 ponygo heredoc 逐字节一致（upgrade --check 零漂移）" 0 "$UC_RC"

# ============================================================
# 契约 C15（L3-A）：PONYGO_SPEC_NO_GUARD —— 环境不具备护栏时的显式信号
#   ponygo 必须识别该 env（≥1 处），3 个出厂 spec 必须都引用它（standalone 时如实披露无护栏）。
# ============================================================
assert_file_matches "GH6/C15 ponygo 识别 PONYGO_SPEC_NO_GUARD 信号" "$CLI_SRC" 'PONYGO_SPEC_NO_GUARD'
for spec in adr-verify scratch-hygiene archive-verify; do
  assert_file_matches "GH6/C15($spec) 出厂 spec 引用 PONYGO_SPEC_NO_GUARD 信号" \
    "$ROOT/.meta/gates/$spec.spec.sh" 'PONYGO_SPEC_NO_GUARD'
done

# ============================================================
# Lead rev3：文档指针不得写死 CI 行号（拓扑一变就漂移；现为漂移状态）
# ============================================================
assert_file_not_matches "GH6/rev3 .meta/gates/README.md 不得写死 ci.yml:<行号> 行号指针" \
  "$ROOT/.meta/gates/README.md" 'ci\.yml:[0-9]'
assert_file_not_matches "GH6/rev3 ponygo 内同源 README heredoc 不得写死 ci.yml:<行号> 行号指针" \
  "$CLI_SRC" 'ci\.yml:[0-9]'

# ============================================================
# 契约 D（§4）：CI 拓扑（真 YAML 结构化解析，禁止一行注释/子串命中冒充接线）
# ============================================================
CI_PY=$(python3 - "$CI_YML" <<'PY'
import re
import sys

path = sys.argv[1]
out = []


def ok(desc):
    out.append("CHECK OK " + desc)


def fail(desc, detail=""):
    out.append("CHECK FAIL " + desc + ("（实得：%s）" % detail if detail else ""))


def emit():
    out.append("#PARSE-END")
    sys.stdout.write("\n".join(out) + "\n")


try:
    import yaml
except ImportError as exc:
    fail("GH6/D harness 需要 PyYAML 做结构化解析（禁止 grep 子串冒充）", str(exc))
    emit()
    raise SystemExit(0)

try:
    doc = yaml.safe_load(open(path, encoding="utf-8").read())
    if not isinstance(doc, dict):
        raise ValueError("workflow root is not a mapping")
    # YAML 1.1 会把裸 on 解析成布尔 True；GitHub Actions 用 YAML 1.2 的 on 键。
    if True in doc:
        doc["on"] = doc.pop(True)

    def norm(v):
        return " ".join(str(v).split())

    jobs = doc.get("jobs") or {}
    if not isinstance(jobs, dict):
        jobs = {}

    def job(name):
        v = jobs.get(name)
        return v if isinstance(v, dict) else {}

    def runs_of(j):
        return [norm(s.get("run", "")) for s in (j.get("steps") or []) if isinstance(s, dict)]

    def extra(j, key):
        v = j.get(key)
        if isinstance(v, int) and v > 0:
            return v
        if isinstance(v, str) and re.fullmatch(r'[0-9]+', v.strip()) and int(v) > 0:
            return int(v)
        return None

    # ---------- D1/D2：job 集合与改名迁移 ----------
    expected = {"selftest-linux", "windows-core", "windows-full", "governance", "all-checks-passed"}
    if set(jobs) == expected:
        ok("GH6/D1 job 集合恰为 {selftest-linux, windows-core, windows-full, governance, all-checks-passed}")
    else:
        fail("GH6/D1 job 集合恰为五 job 拓扑（windows-full 不得删除）",
             "缺=%s 多=%s" % (sorted(expected - set(jobs)), sorted(set(jobs) - expected)))
    if "selftest-windows" in jobs:
        fail("GH6/D2 selftest-windows 已改名迁移为 windows-core", "仍存在 selftest-windows")
    else:
        ok("GH6/D2 selftest-windows 已改名迁移为 windows-core（非删覆盖）")

    # ---------- D4：触发器 ----------
    on = doc.get("on")
    if not isinstance(on, dict):
        fail("GH6/D4 on 触发器为映射且含 push/pull_request/schedule/workflow_dispatch", repr(on))
        on = {}
    push = on.get("push") if isinstance(on.get("push"), dict) else None
    if push and "main" in [str(b) for b in (push.get("branches") or [])]:
        ok("GH6/D4 保留 push: branches: [main]")
    else:
        fail("GH6/D4 保留 push: branches: [main]", repr(on.get("push")))
    if "pull_request" in on:
        ok("GH6/D4 保留 pull_request 触发")
    else:
        fail("GH6/D4 保留 pull_request 触发", "缺 pull_request")
    sched = on.get("schedule")
    crons = []
    if isinstance(sched, list):
        crons = [norm(s.get("cron")) for s in sched
                 if isinstance(s, dict) and s.get("cron")]
    if crons and all(len(c.split()) == 5 for c in crons):
        ok("GH6/D4 新增 schedule（nightly，cron 表达式落盘且为五段）")
    else:
        fail("GH6/D4 新增 schedule（nightly，cron 表达式落盘且为五段）", repr(sched))
    if "workflow_dispatch" in on:
        ok("GH6/D4 新增 workflow_dispatch 触发")
    else:
        fail("GH6/D4 新增 workflow_dispatch 触发", "缺 workflow_dispatch")

    # ---------- D5：既有 job 的超时预算 ----------
    if extra(job("selftest-linux"), "timeout-minutes") == 45:
        ok("GH6/D5 selftest-linux timeout-minutes: 45（rev3 预算）")
    else:
        fail("GH6/D5 selftest-linux timeout-minutes: 45（rev3 预算）",
             repr(job("selftest-linux").get("timeout-minutes")))
    if extra(job("governance"), "timeout-minutes") == 10:
        ok("GH6/D5 governance 保留 timeout-minutes: 10")
    else:
        fail("GH6/D5 governance 保留 timeout-minutes: 10", repr(job("governance").get("timeout-minutes")))

    # ---------- D2：windows-core ----------
    core = job("windows-core")
    if core:
        if norm(core.get("runs-on", "")) == "windows-latest":
            ok("GH6/D2 windows-core runs-on: windows-latest")
        else:
            fail("GH6/D2 windows-core runs-on: windows-latest", repr(core.get("runs-on")))
        env = core.get("env") if isinstance(core.get("env"), dict) else {}
        layer = norm(env.get("PONYGO_TEST_LAYER", "")) if env else ""
        if layer == "core":
            ok("GH6/D2 windows-core env: PONYGO_TEST_LAYER=core（core 层 27 场景）")
        else:
            fail("GH6/D2 windows-core env: PONYGO_TEST_LAYER=core", repr(layer))
        if extra(core, "timeout-minutes") == 60:
            ok("GH6/D2 windows-core timeout-minutes: 60（rev3 预算）")
        else:
            fail("GH6/D2 windows-core timeout-minutes: 60（rev3 预算）", repr(core.get("timeout-minutes")))
        runs = runs_of(core)
        if any("bash tests/run.sh" in r for r in runs):
            ok("GH6/D2 windows-core 跑 `bash tests/run.sh`")
        else:
            fail("GH6/D2 windows-core 跑 `bash tests/run.sh`", "；".join(runs)[:120])
        shells = [norm(s.get("shell", "")) for s in (core.get("steps") or []) if isinstance(s, dict)]
        if "bash" in shells:
            ok("GH6/D2 windows-core 步骤 shell: bash")
        else:
            fail("GH6/D2 windows-core 步骤 shell: bash", repr(shells))
        if norm(core.get("if", "true")).lower() in {"false", "false()"}:
            fail("GH6/D9 windows-core 不得被 if 关闭（PR 事件必须实际执行）", repr(core.get("if")))
        else:
            ok("GH6/D9 windows-core 未被 if 关闭（PR 事件必须实际执行）")
    else:
        for desc in ("windows-core runs-on: windows-latest",
                     "windows-core env: PONYGO_TEST_LAYER=core",
                     "windows-core 必须有 timeout-minutes",
                     "windows-core 跑 `bash tests/run.sh`",
                     "windows-core 步骤 shell: bash"):
            fail("GH6/D2 " + desc, "job 缺失")

    # ---------- D3：windows-full ----------
    full = job("windows-full")
    if full:
        if extra(full, "timeout-minutes") == 240:
            ok("GH6/D3 windows-full timeout-minutes: 240（rev3 预算，历史 ≈91.7min 留 2.6 倍余量）")
        else:
            fail("GH6/D3 windows-full timeout-minutes: 240（rev3 预算）", repr(full.get("timeout-minutes")))
        runs = runs_of(full)
        if any("bash tests/run.sh" in r for r in runs):
            ok("GH6/D3 windows-full 全量 `bash tests/run.sh`")
        else:
            fail("GH6/D3 windows-full 全量 `bash tests/run.sh`", "；".join(runs)[:120])
        guard = norm(full.get("if", ""))
        if "github.event_name" in guard and "schedule" in guard and "workflow_dispatch" in guard:
            ok("GH6/D3 windows-full 仅在 schedule/workflow_dispatch 触发（if 白名单守卫）")
        else:
            fail("GH6/D3 windows-full 仅在 schedule/workflow_dispatch 触发（if 白名单守卫）", guard or "无 if")
        if "pull_request" in guard:
            fail("GH6/D3 windows-full 不得在 pull_request 事件执行（PR 必跑性靠 windows-core）", guard)
        else:
            ok("GH6/D3 windows-full 不得在 pull_request 事件执行（PR 必跑性靠 windows-core）")
    else:
        for desc in ("windows-full 必须有 timeout-minutes",
                     "windows-full 全量 `bash tests/run.sh`",
                     "windows-full 仅在 schedule/workflow_dispatch 触发（if 白名单守卫）"):
            fail("GH6/D3 " + desc, "job 缺失")

    # ---------- D6/D7：all-checks-passed 聚合语义 ----------
    agg = job("all-checks-passed")
    if not agg:
        fail("GH6/D6 all-checks-passed 存在（分支保护唯一依赖，名字不变）", "job 缺失")
    else:
        ok("GH6/D6 all-checks-passed 存在（分支保护唯一依赖，名字不变）")
        if norm(agg.get("if", "")) == "always()":
            ok("GH6/D6 all-checks-passed 必须 if: always()")
        else:
            fail("GH6/D6 all-checks-passed 必须 if: always()", repr(agg.get("if")))
        needs = agg.get("needs")
        needs = [norm(n) for n in needs] if isinstance(needs, list) else []
        want_needs = {"selftest-linux", "windows-core", "windows-full", "governance"}
        if set(needs) == want_needs:
            ok("GH6/D6 all-checks-passed needs 恰含四项（linux/core/full/governance）")
        else:
            fail("GH6/D6 all-checks-passed needs 恰含四项",
                 "缺=%s 多=%s" % (sorted(want_needs - set(needs)), sorted(set(needs) - want_needs)))
        text = "\n".join(runs_of(agg))
        missing = [j for j in sorted(want_needs) if ("needs.%s.result" % j) not in text]
        if not missing:
            ok("GH6/D6 聚合步读取全部四项 needs.<job>.result")
        else:
            fail("GH6/D6 聚合步读取全部四项 needs.<job>.result", "缺 %s" % ",".join(missing))
        triple = re.search(
            r'result="\s*\$\{\{\s*needs\.selftest-linux\.result\s*\}\}\s+'
            r'\$\{\{\s*needs\.windows-core\.result\s*\}\}\s+'
            r'\$\{\{\s*needs\.governance\.result\s*\}\}\s*"', text)
        if triple:
            ok("GH6/D6 required 三元组按 linux→windows-core→governance 顺序绑定（windows-full 不在三元组内）")
        else:
            fail("GH6/D6 required 三元组按 linux→windows-core→governance 顺序绑定", "无匹配的三元组赋值")
        if "success success success" in text:
            ok("GH6/D6/D7 required 三元组必须恰为 success success success（skipped 不得冒充通过）")
        else:
            fail("GH6/D6/D7 required 三元组必须恰为 success success success", "聚合步无该精确比较")
        if "success success success success" in text:
            fail("GH6/D6 不得把 windows-full 并入 required 精确三元组", "命中四连 success")
        else:
            ok("GH6/D6 不得把 windows-full 并入 required 精确三元组")
        if "needs.windows-full.result" in text and "skipped" in text:
            ok("GH6/D7 windows-full 结果允许 success 或 skipped（failure/cancelled 必须失败）")
        else:
            fail("GH6/D7 windows-full 结果允许 success 或 skipped",
                 "缺 windows-full result 读取或缺 skipped 分支")
        # rev3：skipped 的放行必须**事件感知**——schedule（夜间全量）下 skipped 必须失败。
        if "github.event_name" in text and "schedule" in text:
            ok("GH6/D7 rev3 聚合门事件感知（读 github.event_name 且区分 schedule）")
        else:
            fail("GH6/D7 rev3 聚合门事件感知（读 github.event_name 且区分 schedule）",
                 "聚合步未事件感知")
    emit()
except Exception as exc:  # 解析器自身异常必须显性失败
    out.append("CHECK FAIL GH6/D 结构化解析器异常（%s）" % exc)
    out.append("#PARSE-END")
    sys.stdout.write("\n".join(out) + "\n")
PY
)
CI_PY_RC=$?
assert_zero "GH6/D harness：ci.yml 结构化解析器正常结束（rc=0）" "$CI_PY_RC"
if ! printf '%s\n' "$CI_PY" | grep -qx '#PARSE-END'; then
  bad "GH6/D harness：解析器未产出 #PARSE-END 哨兵（输出被截断或崩溃）"
fi
while IFS= read -r line; do
  case "$line" in
    'CHECK OK '*) ok "${line#CHECK OK }" ;;
    'CHECK FAIL '*) bad "${line#CHECK FAIL }" ;;
    '#PARSE-END') : ;;
    '') : ;;
    *) printf '  [gh6-parse] %s\n' "$line" ;;
  esac
done <<< "$CI_PY"

finish
