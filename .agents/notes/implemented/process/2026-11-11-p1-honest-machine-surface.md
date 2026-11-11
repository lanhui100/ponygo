# Agent Note: P1 修复批 —— 判定面诚实化与文档归家

Status: implemented

## Problem

P0 批关闭了"门可被替换/默认开/L2 零成本"三类断点后，审核报告 §4 的 P1 组仍有八类"表达与判定面"缺陷：

1. 机读面不可区分：`audit --json` 只有 `hits/total/ladder.verdict`，无 `level_declared` 与 `level_verified` 的区分，也无 `miss_ids`（缺哪些判据）与 `exempt_gates`（哪些门被配对豁免），机器消费者只能读到"pass"。
2. 「已接线」把"hook 挂载成功"讲成"门会拒绝"；`lv110_carrier` 的 non-GitHub 分支对零字节 CI 文件即判 wired。
3. 自适应深度把 `init` 自身产物（`.githooks`/`.github/workflows`）当重型信号，干净实例一 init 就被判 M 档。
4. `docs/HANDOFF.md` 自称"改东西前必读"，却不在 `README.md` §7 索引与 `.meta/docs-tier/README.md` 家清单里，且仍写 `level 0-6`、`.meta/decisions/`、`L0-L6` 等失效口径。
5. 家清单漏登 `audit/`（权威细目库）与 `maturity-ladder.md`（判据语义来源）；README 索引漏 `install.sh`/`.githooks/`/`docs/`；`.dev-team/` 被 `.gitignore` 忽略却登记为文档家。
6. `ai-surface` 关闭后残留投影只在 `sync` 报 WARN，`status`/`audit` 静默。
7. `level` 一词两义（`meta.yaml` 头注"当前档位" vs 停止线 2"成熟度目标"）。
8. 场景数等手抄计数不可复现（README「88 CLI 自测」与脚本枚举不符）。

不修正的代价：机读面与人类文案都"看起来通过"，与 P0 关闭的断点同源——判断权仍留在叙述里而不在证据里。

## Decision

按 `.dev-team/contract-p1-fixes.md`（含 L3 复核并入的附则 P1-9/10/11）与冻结验收 `tests/acceptance/p1-fixes/verify-p1.sh` 实施：

- **机读面**：`status --json`/`audit --json` 增 `level_declared`、`level_verified`（真正判过的最高档）、`miss_ids`（缺的判据 id）、`exempt_gates`（配对豁免门，按 `UPGRADE_UNIVERSE` 派生，至少含 `ci-verify.sh`）；未验证不得抬高 `level_verified`。
- **措辞与载体**：「已接线」→「已挂载」并显式写"未验证门会拒绝（验证入口 `ponygo audit --run-specs` / CI）"；non-GitHub forge 的 CI 文件须非空且含 `ci-verify`/`verify-note` 调用痕迹才判载体。
- **自适应深度**：`init` 自身产物不计重型信号，干净实例判 S 档。
- **HANDOFF 归家**：迁入 `docs/dev-team/HANDOFF.md` 并修正失效口径（`0-5`/`.agents/notes/`/`L0-L5`/现行文件数），旧路径删除。
- **家与索引**：docs-tier 家清单补 `audit/`、`maturity-ladder.md`，`.dev-team/` 改标"本地工作区（不入库），不作为文档家"（同步 `ponygo` 内嵌模板防漂移）；README §7 索引补 `install.sh`/`.githooks/`/`docs/`。
- **残留告警**：`status`/`audit` 对"填槽态 + 非 `on` + 根文件仍含 `BEGIN constitution`"给同源 WARN。
- **口径统一**：`level` = 当前档位；`level_declared > level_verified` 时结论行显式写"已声明 Lx，仅验证到 Ly"。
- **2.3 加固（P1-9）**：拒绝断言须来自**非注释、非 echo/printf** 行的 `exit|return [1-9]`；扫描范围限定与实例门配对的 spec，纯正向 smoke spec 不触发 2.3 FAIL。

验收收据（绑 sha256）：`verify-p1.sh` PASS 全绿、`verify-p0.sh` 仍 PASS=17 FAIL=0、`tests/run.sh` fail=0、本仓 `status`/`audit`/`upgrade --check` 均 exit 0。

## Alternatives considered

- **只改文案、不加 `declared/verified` 字段**：否决——机器消费者（CI、看板）需要可判定字段，只改人类文案等于把"未验证"继续留在叙述里（P2 的反面）。
- **直接删除 `docs/HANDOFF.md`**：否决——它承载"接手必读"的上下文；删掉会让新维护者失去入口，迁移到 `docs/dev-team/`（工程过程记录的家）并修正口径成本更低。
- **2.3 保持全仓 spec 扫描**：否决——会把与实例门无关的正向 smoke spec 判 FAIL（误杀），且注释可伪造拒绝证据（假放行）；"限定配对 + 剔注释/echo"同时收窄误杀与伪造面。
- **自适应深度保留 `.githooks` 信号**：否决——它是 `init` 自己写的，等于"脚手架自动把项目升档"，与注释里"ponygo 自己的产物不应升档"的意图相反。
- **non-GitHub forge 维持零字节即 wired**：否决——1.10 的覆盖声明会变成空头支票；要求"文件含调用痕迹"是可机械判定的最小证据。

## Consequences

- 判定面与文案对齐：`status`/`audit` 的机读字段可被 CI 直接消费；"已挂载"不再冒充"门会拒绝"。
- 家清单与索引一致：HANDOFF、`audit/`、`maturity-ladder.md`、`install.sh`、`.githooks/`、`docs/` 均有唯一可寻址的家；`.dev-team/` 明确为不入库的本地工作区。
- 已知边界：`exempt_gates` 与框架门判定依赖 `UPGRADE_UNIVERSE` 派生，新增框架门须同批复核；`level_verified` 仍只覆盖 1.x/2.x 可判部分（L3+ 属目标画像）。
- 与 P0 的边界：本批不改动 P0 的五条判据；两批收据各自绑 sha256，提交说明分开。
