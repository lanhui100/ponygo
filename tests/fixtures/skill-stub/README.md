# tests/fixtures/skill-stub —— 假 skill（仅用于 observe 验收测试）

离线替身：让 `ponygo observe *` 在**无真实 skill / 无集群 / 无网络**时可被判定。
不是真 skill，也不得被 ponygo 当默认 skill 使用——测试一律 `cp -R` 到 case 目录后经
`--skill-dir` 或 `PONYGO_SKILL_DIR` 注入（避免并发互污）。

| 文件 | 作用 |
|---|---|
| `references/contract.json` | 契约版本来源：`contract_version`（测试用 printf 覆盖成本文，默认 1.0.3） |
| `scripts/check-declaration.sh` | 声明一致性判定替身：rc 由 `STUB_RC_CHECK_DECL` 决定（默认 0） |
| `scripts/audit-diff.sh` | 变更级门禁替身：rc 由 `STUB_RC_AUDIT_DIFF` 决定（默认 0） |

两条铁律（测试自查覆盖，见 tests/run.sh s33）：

1. **入参校验**：项目目录不存在 → `exit 4`（工具使用错误，与真 skill 的 4 语义一致），
   证明这两支不是「纯常量桩」——真调的入参被真的看了。
2. **可识别标记**：stdout 打印 `STUB-CHECK-DECL rc=<N>` / `STUB-AUDIT-DIFF rc=<N>`，
   既供断言锚定，也供 `--json` 用例反证「skill 输出不得混入 ponygo stdout」。
