# observe-b027 —— B027 四项独立验收（波2 · F2 CLI 发行物面）

B027 的来源是 job_copilot 的 B200（跨仓迁移）：ponygo 的 `observe audit` 曾有三处缺陷 +
一处判据过松，commit `7379930` 声称已修。本目录是**独立验收**：不写业务代码，只写负样本取证。
**不接入 `tests/run.sh`**——94 场景字面量是 gh6/R1 与 `verify-p0` 的硬锚，扩场景属范围变更。

## 四项判据（backlog B027 验收原文 → 本目录用例）

| # | 验收原文 | 用例 | 断言面 |
|---|---|---|---|
| ① | `.husky/` 或 `core.hooksPath` 挂载时 ob2 可得分 | `c1_carriers.sh` | `.githooks` / `.husky` / husky v9（`core.hooksPath=.husky/_`）/ 自建 `core.hooksPath` 目录 各一例；每条配「移除真调用 → `mount_missing`」归因负样本 |
| ② | 一级子组件声明被 audit 逐份巡检并给 PASS/缺口 | `c2_subcomponent.sh` | 混合 rc（根 0 / 子 2）同时出现；`subcomponent_inconsistent` / `subcomponent_evidence_insufficient` 两支；一致时不误报；二级声明不得越界巡检 |
| ③ | `docs/observability.d/*.yaml` 与根声明并存、各自独立判定 | `c3_multi_declaration.sh` | 逐份 rc 清单（`.yaml` 与 `.yml` 都纳入、`LC_ALL=C` 排序稳定）、`extra_declaration_inconsistent`、主声明 ob0/ob1/ob2 不受影响、`nested/` 不递归 |
| ④ | 纯注释 `# bash scripts/audit-diff.sh` 伪装 mount 必须判负 | `c4_comment_mount.sh` | shell 钩子 / husky 钩子 / yaml workflow 三形态纯注释均判负；去注释符即恢复得分（归因对照）；注释与真调用并存不遮蔽 |

## 运行

```bash
bash tests/acceptance/observe-b027/run-all.sh          # exit 0 = 四项全过
PONYGO_CLI=/path/to/other/ponygo bash tests/acceptance/observe-b027/run-all.sh   # 对旧版 CLI 取红相
```

- 自包裹：每例 `GT=${PONYGO_GATE_SPEC_TIMEOUT:-90}` + `exec timeout -k 5`（见 `selfwrap.sh`），
  套件外层预算 = 每例预算 × 4 + 30s；`PONYGO_SPEC_NO_GUARD=1` 时按约定不加包裹（如实降级）。
- 沙箱：每例 `mktemp -d`，EXIT 清理；**不写仓库**；git 全局/系统配置隔离到空文件。
- 退出码：`0` 全过 / `1` 任一 case RED（FAIL 行原样回显）/ `2` 配置错误（非法预算）。

## 为什么被判对象是 ponygo 而不是 skill

四项验的都是 **ponygo 的判定面**（载体发现、子声明遍历、附加声明遍历、注释过滤），
不是 skill 侧的规则集语义。故 `stub-skill/` 只替身 skill 的**退出码词表**，且是**内容驱动**：

- `check-declaration.sh`：`service:` 前缀 `bad-` → 2、`unk-` → 3、缺失 → 4、其余 → 0；
  入参（`--project` 目录 / `--declaration` 文件）不存在 → 4。
  内容驱动而非 env 单值，是为了让「根声明 0 + 子声明 2」这类**混合场景**能在一次运行内出现——
  否则「所有声明同判」会冒充「逐份判定」。
- `audit-diff.sh`：缺省 rc=0（`STUB_RC_AUDIT_DIFF` 可覆盖），`--repo` 不存在 → 4。

每个 case 首段都有**夹具自检**（stub 对不存在路径返回 4），证明替身不是「所有入参都返 0」的常量桩。
真 skill 的端到端取证（声明式判定 + audit-diff 真实规则集）另见
`.dev-team/b027-acceptance-receipt.md` 的「真 skill 冒烟」段。

## 已知边界（诚实登记）

- `c4` 的 4a 曾在 `main @ c42cb5c` 上判红：`observe_mount_hit()` 单文件分支用 `grep -In`，
  命中行不带 `file:` 前缀，注释排除正则永不匹配 → 单文件载体（`.githooks/pre-commit`、
  `.git/hooks/pre-commit`、`.pre-commit-config.yaml`、`lefthook.yml`）注释伪装假绿。
  裁决：修产品（`-In` → `-HIn`，一行），**不放宽断言**。取证件：
  `.scratch/2026-11-22-wave15/b027-c4-single-file-probe.log`。
- 载体判定仍是**文本判据**（不解析 AST、不验证钩子真会执行）；真执行证据是 `audit-diff` 自身的 rc。
- 只读验收：本目录不修改 `ponygo`、`.meta/gates/**`、`.github/**`。
