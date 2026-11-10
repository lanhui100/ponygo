#!/usr/bin/env python3
"""GH3：checklist 2.3/2.4 与 CLI 的严格接线语义必须一致。"""
from __future__ import annotations

import pathlib
import re
import sys


def main() -> int:
    if len(sys.argv) != 2:
        return 2
    path = pathlib.Path(sys.argv[1]) / "audit/checklist.md"
    text = path.read_text()
    lines = text.splitlines()
    failures = 0

    def check(label, condition, detail=""):
        nonlocal failures
        if condition:
            print(f"  ok   {label}")
        else:
            failures += 1
            print(f"FAIL {label}{(': ' + detail) if detail else ''}", file=sys.stderr)

    rows = {}
    for line in lines:
        match = re.match(r"^\|\s*(2\.[34])\s*\|(.*)$", line)
        if match:
            rows.setdefault(match.group(1), []).append(match.group(2))
    check("GH3 2.3 恰一行", len(rows.get("2.3", [])) == 1, repr(rows.get("2.3")))
    check("GH3 2.4 恰一行（禁止骨架/机制双义）", len(rows.get("2.4", [])) == 1, repr(rows.get("2.4")))
    if len(rows.get("2.3", [])) == 1:
        row = rows["2.3"][0]
        check("GH3 2.3 判定为负样本 spec", "负样本" in row and "spec" in row)
        check("GH3 2.3 检查域限定 .meta/gates", ".meta/gates" in row)
        check("GH3 2.3 使用门禁 spec 后缀", "*.spec" in row)
        check("GH3 2.3 不得偷换为 CI 存在", "CI 存在" not in row and "有 CI 配置" not in row)
    if len(rows.get("2.4", [])) == 1:
        row = rows["2.4"][0]
        for token, label in [
            ("core.hooksPath", "包含 hooksPath"),
            ("pre-commit", "包含 pre-commit"),
            ("可执行", "要求可执行"),
            ("哨兵", "要求 ADR 哨兵接线"),
            (".meta/gates/adr-verify.sh", "要求 ADR 门资产"),
        ]:
            check(f"GH3 2.4 {label}", token in row)
        check("GH3 2.4 不得退化为目录非空", "目录非空" not in row or "不得只查" in row)
        check("GH3 2.4 不得错挂负样本 spec", "负样本" not in row and "test_*.py" not in row)

    # 如果保留负样本补充行，其搜索域必须收敛在 .meta/gates。
    negative_rows = [line for line in lines if "负样本" in line and line.startswith("|")]
    for row in negative_rows:
        check("GH3 负样本补充项不得扫描全仓普通单测", "test_*.py" not in row and "*_test.go" not in row)
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
