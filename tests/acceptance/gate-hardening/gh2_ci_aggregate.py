#!/usr/bin/env python3
"""GH2：用 YAML 结构与聚合表达式验收主 CI，拒绝语法合法的语义掏空。"""
from __future__ import annotations

import copy
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

import yaml


class GitHubDumper(yaml.SafeDumper):
    pass


def _github_str(dumper, value):
    # 防止 YAML 1.1 safe_dump 把 GitHub 的 on 键重新写成布尔 true。
    return dumper.represent_scalar("tag:yaml.org,2002:str", value, style='"' if value == "on" else None)


GitHubDumper.add_representer(str, _github_str)


def load(path: pathlib.Path):
    value = yaml.safe_load(path.read_text())
    if not isinstance(value, dict):
        raise ValueError("workflow root is not a mapping")
    # YAML 1.1 会把裸 on 解析成布尔 True；GitHub Actions 使用 YAML 1.2 的 on 键。
    if True in value:
        value["on"] = value.pop(True)
    return value


def norm(value) -> str:
    return " ".join(str(value).split())


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
    required = {"selftest-linux", "selftest-windows", "governance"}
    if not required.issubset(set(needs)):
        errors.append(f"aggregate.needs missing {sorted(required - set(needs))}")
    steps = agg.get("steps")
    aggregate_text = "\n".join(str(s.get("run", "")) for s in steps or [] if isinstance(s, dict))
    for job in sorted(required):
        if f"needs.{job}.result" not in aggregate_text:
            errors.append(f"aggregate expression missing needs.{job}.result")
    # 结果必须同时约束三个真实依赖，且唯一成功组合是三 success。
    result_assignment = re.search(
        r'(?m)^\s*result="\s*'
        r'\$\{\{\s*needs\.selftest-linux\.result\s*\}\}\s+'
        r'\$\{\{\s*needs\.selftest-windows\.result\s*\}\}\s+'
        r'\$\{\{\s*needs\.governance\.result\s*\}\}\s*"\s*$',
        aggregate_text,
    )
    exact_gate = re.search(r'(?m)^\s*\[\s*"\$result"\s*=\s*"success success success"\s*\]\s*$', aggregate_text)
    if not result_assignment or not exact_gate:
        errors.append("aggregate does not bind all three needs results and require exactly three success results")
    return errors


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
    check("GH2 主 CI governance 执行面与三结果聚合", governance_errors(original))
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

    actionlint = shutil.which("actionlint")
    with tempfile.TemporaryDirectory(prefix="gate-hardening-ci-") as tmp:
        tmp_path = pathlib.Path(tmp)
        for label, doc in mutations.items():
            candidate = tmp_path / (re.sub(r"[^a-zA-Z0-9]+", "-", label) + ".yml")
            candidate.write_text(yaml.dump(doc, Dumper=GitHubDumper, allow_unicode=True, sort_keys=False))
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
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
