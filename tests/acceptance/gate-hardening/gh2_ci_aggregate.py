#!/usr/bin/env python3
"""GH2：用 YAML 结构与聚合表达式验收主 CI，拒绝语法合法的语义掏空。

Wave-14 契约迁移（`.dev-team/contract-wave14.md` §4 D1–D8）：
- required 三元组 = {selftest-linux, windows-core, governance}，必须恰为 `success success success`；
- `windows-full` 是第四项 needs，其结果必须 ∈ {success, skipped}，其余值判失败；
- 放行 `skipped` 必须**事件感知**（rev3）：`windows-full=skipped` 仅当 `github.event_name != 'schedule'`
  才通过；schedule（夜间全量）下 skipped 必须失败 —— 结果级负样本按事件参数化；
- 除结构变异外，另做**结果级负样本**（D8）：把 needs.<job>.result 就地换成具体值后离线求值聚合脚本，
  windows-core=skipped 必须失败、windows-full=skipped 必须成功 —— 证明"skipped 不得冒充通过"是真实行为，
  而不只是正则形状。迁移只允许加强，不得删除或放宽任何既有断言。
"""
from __future__ import annotations

import copy
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

import yaml

# Windows 编码自保（CI 实跑 run 43031069740）：cp1252 控制台下打印中文会抛 UnicodeEncodeError
# → rc=1 且 stdout 为空（上层的 /tmp 断言与折叠计数随之连锁失败）。这里显式把流切到 UTF-8，
# 即使调用方设置了 PYTHONIOENCODING=cp1252 也能自保。
for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

# required 三元组：三项必须全部 success（skipped 一律判失败，D7）。
REQUIRED = ("selftest-linux", "windows-core", "governance")
# 第四项：允许 skipped（夜间全量，PR 事件不跑），但 failure/cancelled 必须失败（D6/D7）。
OPTIONAL = "windows-full"
NEEDS_EXPECTED = set(REQUIRED) | {OPTIONAL}


class GitHubDumper(yaml.SafeDumper):
    pass


def _github_str(dumper, value):
    # 防止 YAML 1.1 safe_dump 把 GitHub 的 on 键重新写成布尔 true。
    return dumper.represent_scalar("tag:yaml.org,2002:str", value, style='"' if value == "on" else None)


GitHubDumper.add_representer(str, _github_str)


def load(path: pathlib.Path):
    value = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError("workflow root is not a mapping")
    # YAML 1.1 会把裸 on 解析成布尔 True；GitHub Actions 使用 YAML 1.2 的 on 键。
    if True in value:
        value["on"] = value.pop(True)
    return value


def norm(value) -> str:
    return " ".join(str(value).split())


BASH_RESOLVE_TRIED: list[str] = []


def _is_wsl_stub(path: str) -> bool:
    """Windows 上 C:\\Windows\\System32\\bash.exe 是 WSL 存根：会打印 "to list available
    distributions" 并 rc=1，绝不接受（CI run 43043638972 的 3 条 GH2 结果级裁决即此因）。"""
    flat = path.replace("\\", "/").lower()
    return "/system32/" in flat or "/windowsapps/" in flat or flat.endswith("/system32/bash.exe")


def resolve_bash() -> str | None:
    """按序解析真 bash：$BASH → which(bash)（排除存根）→ Windows Git 固定候选；
    每个候选都跑 `bash -c "exit 0"` 做语义探针，全部失败则返回 None（调用方显式失败）。"""
    import os

    cands: list[str] = []
    env_bash = os.environ.get("BASH")
    if env_bash:
        cands.append(env_bash)
    which = shutil.which("bash")
    if which:
        cands.append(which)
    if os.name == "nt":
        for base in (os.environ.get("ProgramFiles"), os.environ.get("ProgramFiles(x86)"),
                     r"C:\\Program Files"):
            if base:
                cands.append(os.path.join(base, "Git", "bin", "bash.exe"))
                cands.append(os.path.join(base, "Git", "usr", "bin", "bash.exe"))
    seen: set[str] = set()
    for c in cands:
        if not c or c in seen:
            continue
        seen.add(c)
        BASH_RESOLVE_TRIED.append(c)
        if _is_wsl_stub(c):
            continue
        try:
            probe = subprocess.run([c, "-c", "exit 0"], capture_output=True, text=True)
        except OSError:
            continue
        if probe.returncode == 0:
            return c
    return None


def aggregate_steps(doc) -> list[dict]:
    agg = doc.get("jobs", {}).get("all-checks-passed", {})
    steps = agg.get("steps") if isinstance(agg, dict) else None
    return [s for s in steps or [] if isinstance(s, dict)]


def aggregate_text(doc) -> str:
    return "\n".join(str(s.get("run", "")) for s in aggregate_steps(doc))


def governance_errors(doc) -> list[str]:
    errors: list[str] = []
    jobs = doc.get("jobs")
    if not isinstance(jobs, dict):
        return ["jobs is not a mapping"]
    gov = jobs.get("governance")
    if not isinstance(gov, dict):
        errors.append("jobs.governance missing")
    else:
        if not gov.get("runs-on"):
            errors.append("governance.runs-on missing")
        if str(gov.get("if", "true")).strip().lower() in {"false", "false()"}:
            errors.append("governance disabled by if")
        steps = gov.get("steps")
        if not isinstance(steps, list):
            errors.append("governance.steps missing")
        else:
            runs = [norm(s.get("run", "")) for s in steps if isinstance(s, dict)
                    and str(s.get("if", "true")).strip().lower() not in {"false", "false()"}]
            if "bash .meta/gates/ci-verify.sh" not in runs:
                errors.append("governance has no exact ci-verify.sh run step")
    agg = jobs.get("all-checks-passed")
    if not isinstance(agg, dict):
        errors.append("jobs.all-checks-passed missing")
        return errors
    if norm(agg.get("if", "")) != "always()":
        errors.append("aggregate must have if: always()")
    needs = agg.get("needs")
    if not isinstance(needs, list):
        errors.append("aggregate.needs must be an explicit list")
        needs = []
    need_set = {norm(n) for n in needs}
    if not NEEDS_EXPECTED.issubset(need_set):
        errors.append(f"aggregate.needs missing {sorted(NEEDS_EXPECTED - need_set)}")
    text = aggregate_text(doc)
    for job in sorted(NEEDS_EXPECTED):
        if f"needs.{job}.result" not in text:
            errors.append(f"aggregate expression missing needs.{job}.result")
    # required 三项必须同时被约束，且唯一成功组合是三 success（顺序与契约 D6 一致）。
    result_assignment = re.search(
        r'(?m)^\s*result="\s*'
        + r'\s+'.join(r'\$\{\{\s*needs\.' + re.escape(job) + r'\.result\s*\}\}' for job in REQUIRED)
        + r'\s*"\s*$',
        text,
    )
    exact_gate = re.search(r'(?m)^\s*\[\s*"\$result"\s*=\s*"success success success"\s*\]\s*$', text)
    if not result_assignment or not exact_gate:
        errors.append(
            "aggregate does not bind the required triple "
            f"({' + '.join(REQUIRED)}) and require exactly three success results")
    # windows-full 允许 success/skipped，其余值必须失败；不得被并入 required 精确串（D6/D7）。
    if "success success success success" in text:
        errors.append("aggregate must not fold windows-full into the required exact triple")
    if "needs.windows-full.result" not in text or "skipped" not in text:
        errors.append("aggregate must accept windows-full in {success, skipped} explicitly")
    # rev3：skipped 的放行必须事件感知（schedule 下 skipped 必须失败）。
    if "github.event_name" not in text or "schedule" not in text:
        errors.append("aggregate must be event-aware (read github.event_name and distinguish schedule)")
    return errors


def render_aggregate(doc) -> str:
    """把 needs.<job>.result / github.event_name 表达式替换为占位符，得到可离线求值的纯 bash。"""
    text = aggregate_text(doc)
    # 事件比较式先替换为可判定占位符（支持 == / != 两种方向）。
    text = re.sub(
        r"\$\{\{\s*github\.event_name\s*(==|!=)\s*(['\"])([a-z_]+)\2\s*\}\}",
        lambda m: "__EVENT_CMP_%s_%s__" % ("e" if m.group(1) == "==" else "n", m.group(3)),
        text,
    )
    text = re.sub(r"\$\{\{\s*github\.event_name\s*\}\}", "__EVENT__", text)
    for job in sorted(NEEDS_EXPECTED):
        text = re.sub(r'\$\{\{\s*needs\.' + re.escape(job) + r'\.result\s*\}\}',
                      '__' + job.upper().replace("-", "_") + '__', text)
    return text


def evaluate(doc, results: dict[str, str], event: str = "pull_request") -> tuple[int, str]:
    """把渲染后的聚合脚本占位符换回具体结果值/事件，用真 bash 求值（D8 结果级负样本）。"""
    script = render_aggregate(doc)
    script = script.replace("__EVENT__", event)
    script = re.sub(r"__EVENT_CMP_e_([a-z_]+)__", lambda m: "true" if event == m.group(1) else "false", script)
    script = re.sub(r"__EVENT_CMP_n_([a-z_]+)__", lambda m: "false" if event == m.group(1) else "true", script)
    for job, value in results.items():
        script = script.replace("__" + job.upper().replace("-", "_") + "__", value)
    bash_bin = resolve_bash()
    if bash_bin is None:
        # 显式失败并打印尝试过的路径：绝不把「没有可用 bash」静默记成 rc=1（那会与
        # 「聚合门判失败」混淆，把环境缺陷伪装成契约红）。
        tried = ", ".join(BASH_RESOLVE_TRIED) or "（无候选：$BASH/which/Git 固定路径均为空）"
        raise RuntimeError(f"找不到可用的真 bash（已尝试：{tried}）")
    proc = subprocess.run([bash_bin, "-c", script], capture_output=True, text=True)
    return proc.returncode, (proc.stdout + proc.stderr)


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: gh2_ci_aggregate.py <repository-root>", file=sys.stderr)
        return 2
    root = pathlib.Path(sys.argv[1]).resolve()
    source = root / ".github/workflows/ci.yml"
    failures = 0

    def check(label: str, errors: list[str]) -> None:
        nonlocal failures
        if errors:
            failures += 1
            print(f"FAIL {label}: {'; '.join(errors)}", file=sys.stderr)
        else:
            print(f"  ok   {label}")

    original = load(source)
    check("GH2 主 CI governance 执行面与 required 三元组聚合", governance_errors(original))
    if actionlint := shutil.which("actionlint"):
        proc = subprocess.run([actionlint, "-no-color", str(source)], capture_output=True, text=True)
        if proc.returncode == 0:
            print("  ok   GH2 本仓 ci.yml actionlint 原生 exit 0")
        else:
            failures += 1
            print(f"FAIL GH2 本仓 ci.yml actionlint: {proc.stdout}{proc.stderr}", file=sys.stderr)

    mutations = {}
    removed_step = copy.deepcopy(original)
    gov = removed_step.get("jobs", {}).get("governance", {})
    gov["steps"] = [s for s in gov.get("steps", [])
                    if norm(s.get("run", "")) != "bash .meta/gates/ci-verify.sh"]
    mutations["删除 governance 执行步骤"] = removed_step

    removed_need = copy.deepcopy(original)
    agg = removed_need.get("jobs", {}).get("all-checks-passed", {})
    if isinstance(agg.get("needs"), list):
        agg["needs"] = [n for n in agg["needs"] if n != "governance"]
    # 同步删除悬空 result 引用，使变异仍是 GitHub 语法/表达式合法的工作流；
    # 本用例专门证明 needs 缺 governance 的语义拒绝，而非靠 actionlint 表达式报错。
    for step in agg.get("steps", []):
        if isinstance(step, dict) and "run" in step:
            step["run"] = str(step["run"]).replace("needs.governance.result", "needs.selftest-linux.result")
    mutations["needs 删除 governance"] = removed_need

    removed_result = copy.deepcopy(original)
    agg = removed_result.get("jobs", {}).get("all-checks-passed", {})
    for step in agg.get("steps", []):
        if isinstance(step, dict) and "run" in step:
            step["run"] = str(step["run"]).replace("needs.governance.result", "needs.selftest-linux.result")
            step["run"] = step["run"].replace("success success success", "success success")
    mutations["聚合结果删除 governance"] = removed_result

    # 第四项 needs 缺失：windows-full 被删（D6「needs 含四项」的负样本）。
    removed_full = copy.deepcopy(original)
    agg = removed_full.get("jobs", {}).get("all-checks-passed", {})
    if isinstance(agg.get("needs"), list):
        agg["needs"] = [n for n in agg["needs"] if n != OPTIONAL]
    for step in agg.get("steps", []):
        if isinstance(step, dict) and "run" in step:
            step["run"] = str(step["run"]).replace("needs.windows-full.result", "needs.selftest-linux.result")
    mutations["needs 删除 windows-full"] = removed_full

    actionlint = shutil.which("actionlint")
    with tempfile.TemporaryDirectory(prefix="gate-hardening-ci-") as tmp:
        tmp_path = pathlib.Path(tmp)
        for label, doc in mutations.items():
            candidate = tmp_path / (re.sub(r"[^a-zA-Z0-9]+", "-", label) + ".yml")
            candidate.write_text(yaml.dump(doc, Dumper=GitHubDumper, allow_unicode=True, sort_keys=False),
                                 encoding="utf-8")
            if actionlint:
                proc = subprocess.run([actionlint, "-no-color", str(candidate)], capture_output=True, text=True)
                if proc.returncode != 0:
                    print(f"FAIL GH2 变异夹具语法无效({label}): {proc.stdout}{proc.stderr}", file=sys.stderr)
                    failures += 1
            errors = governance_errors(doc)
            if errors:
                print(f"  ok   GH2 负样本被拒：{label}（{'; '.join(errors)}）")
            else:
                failures += 1
                print(f"FAIL GH2 负样本被放行：{label}", file=sys.stderr)

    # ---- D8：结果级负样本。聚合脚本必须对「结果值」而不仅是「表达式形状」做出正确裁决。----
    ok_all = {job: "success" for job in NEEDS_EXPECTED}
    verdict_cases = [
        # <描述> <结果表> <事件> <期望 rc>
        ("全绿（PR 事件，windows-full=success）", dict(ok_all), "pull_request", 0),
        ("全绿（schedule 事件，windows-full=success）", dict(ok_all), "schedule", 0),
        ("windows-full=skipped + PR 事件 → 通过", {**ok_all, OPTIONAL: "skipped"}, "pull_request", 0),
        ("windows-full=skipped + schedule 事件 → 必须失败（事件感知）", {**ok_all, OPTIONAL: "skipped"}, "schedule", 1),
        ("windows-full=failure 必须失败", {**ok_all, OPTIONAL: "failure"}, "pull_request", 1),
        ("windows-full=cancelled 必须失败", {**ok_all, OPTIONAL: "cancelled"}, "schedule", 1),
        ("required windows-core=skipped 必须失败", {**ok_all, "windows-core": "skipped"}, "pull_request", 1),
        ("required selftest-linux=skipped 必须失败", {**ok_all, "selftest-linux": "skipped"}, "schedule", 1),
        ("required governance=skipped 必须失败", {**ok_all, "governance": "skipped"}, "pull_request", 1),
        ("required governance=failure 必须失败", {**ok_all, "governance": "failure"}, "schedule", 1),
    ]
    rendered = render_aggregate(original)
    if "${{" in rendered:
        # 聚合步仍含无法离线求值的 needs 表达式（例如旧拓扑的 selftest-windows）：这是
        # 「契约 D6/D7 尚未实现」的直接证据。逐条记账为失败，禁止静默跳过结果级裁决。
        leftovers = sorted(set(re.findall(r'needs\.([a-z-]+)\.result', rendered)))
        failures += 1
        print(f"FAIL GH2 聚合步含未按四 job 拓扑绑定的 needs 表达式（残留 needs: {leftovers}）", file=sys.stderr)
        for label, _results, _event, _expected in verdict_cases:
            failures += 1
            print(f"FAIL GH2 结果级裁决：{label}（聚合步表达式无法离线求值——契约 D6/D7/D7-rev3 尚未实现）",
                  file=sys.stderr)
    else:
        for label, results, event, expected in verdict_cases:
            try:
                rc, out = evaluate(original, results, event)
            except RuntimeError as exc:
                failures += 1
                print(f"FAIL GH2 结果级裁决：{label}（harness：{exc}）", file=sys.stderr)
                continue
            if rc == expected:
                print(f"  ok   GH2 结果级裁决：{label}（rc={rc}）")
            else:
                failures += 1
                print(f"FAIL GH2 结果级裁决：{label}（期望 rc={expected}，实得 rc={rc}；输出尾部：{out.strip()[-160:]}）",
                      file=sys.stderr)
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
