# Agent Note: 门资产两处实例侧修复上游化（A1 未知选项 fail-closed + 真源跨平台日期解析）

Status: implemented

## Problem

ponyllm 实例（`lanhui100/ponyllm`）在 2026-11-22 的治理收口里，为解除自身 pre-commit 红与 macOS CI 红，
**在实例侧直接改了框架门资产**（门资产按契约是「框架不可变资产，实例侧不编辑」）：

1. `8765882`：`.meta/gates/adr-verify.sh` 带参模式把 `--x` 当「非 ADR 宽参」跳过并以 0 退出，
   于是 `pre-commit.spec.sh` 的负样本（`adr-verify.sh --non-existent-illegal-flag-test-fail` 必须非零）
   在 HEAD 即红——门自己对非法输入 fail-open。实例加了 3 行 `-*) die` 修掉。
2. `090e3c7`：`.agents/skills/write-adr/verify-note.sh` 用 GNU `date -d` 判基线到期日与 1.6 文件名日期，
   macOS（BSD date）上 `date -d` 不存在 → 基线判 corrupt / 日期判定降级，CI 红。实例加了 `vn_date_ok`
   三段探测（`date -d` / `date -j -f "%Y-%m-%d"` / `date -j -f "%Y-%m-%dT%H:%M:%S%z"`）。

两处都是**框架缺陷**，但修在实例侧的直接后果是：

- `ponygo status` 判 2.1「框架门资产漂移（可能被替换）」→ **恒 exit 1**；
- `ponygo upgrade --check` 报 7 处 drift（含 `adr-verify.spec.sh` / `archive-verify.spec.sh` /
  `no-residue.spec.sh` 等纯版本差）；
- 实例的 pre-push 三步中第 2 步恒红，推送只能 `git push --no-verify`——本地治理门事实上被关闭。

即：**修得越对，越被判违规**。框架侧不认这两处修复，实例就没有合法路径让门变绿。

## Decision

**把两处修复原样上游到框架仓，作为框架门资产的正式字节；实例随后 `ponygo upgrade apply` 回到
「字节 = 内嵌模板」，2.1 漂移归零。**

同批落地三件事（缺一即自红）：

1. **A1 `adr-verify.sh`**：带参模式 `for p in "$@"` 循环首部加 `case "$p" in -*) die ...`。
   `die` 文案点名「本门只接受 `.agents/notes/` 下的相对路径；未知选项一律拒绝」，保证补救可执行。
2. **真源 `verify-note.sh`**：引入 `vn_date_ok()`（GNU `date -d` → BSD `date -j -f` 两级回退），
   把基线 `expires_at`/`generated_at` 校验、`DATE_OK` 探测、1.6 文件名日期三处调用点统一改用它。
   `DATE_OK` 语义保持「有可用实现才机械判，否则降级靠 review」——不把无实现伪装成通过。
3. **A2 `adr-verify.spec.sh`**：补 ⑦ 用例——未知选项必须被拒（`REJECTS` 累加）+ 同仓合法相对路径
   仍放行（反向对照，证明不是「带参一律拒」）。收尾结论行与 `##SPEC asserts/rejects` 由运行时计数产出。

**双写纪律**：`ponygo` CLI 内嵌模板（`gate_asset_put ... <<'PONYGO_EOF'`）与仓库 `.meta/gates/`、
`.agents/skills/write-adr/` 下的模板副本必须逐字节一致。三处 heredoc 已按 EOL 归一比对为 `True`。

## Alternatives considered

- **实例侧保留修复 + 给 2.1 开例外白名单**（落选）：门资产「不可变」是框架的封印语义，白名单等于把
  封印改成可协商——下次真被替换（恶意或误操作）也照样放行。且要让 `status`/`upgrade` 同时认白名单，
  改的是判定真源本身，风险远大于改门。
- **实例侧 `git restore` 回滚两处修复**（落选）：会让 pre-commit 负样本重新 fail-open、
  macOS CI 重新红。等于用「关掉看守」换取「status 变绿」，与治理目标相反。
- **只上游 A1，日期兼容留给实例**（落选）：`verify-note.sh` 同样是 2.1 判据覆盖的框架资产，
  只修一半仍判漂移；且 BSD date 缺陷在框架侧对所有 macOS 实例都存在，不是单实例问题。
- **把 `PONYGO_GATE_SPEC_TIMEOUT` 默认值 30s 一并对齐到 90s**（本批不做）：这是纯默认值差异，
  与本次两处缺陷无关；混入会把「修 fail-open」和「调预算」绑成一次不可分割的变更，评审无法分开否决。
  留作独立决策。
- **CLI 侧不再复刻判据，改为调用 `verify-note.sh`**（落选）：属框架架构级重构（CLI 只读边界、
  无实例文件时如何降级），与本缺陷修复不同量级，另案。

## Consequences

- 实例侧 `ponygo status` 2.1 转绿的前提是**先装新版 CLI**（`install.sh` 会拷 `ponygo` 单文件），
  再 `ponygo upgrade apply`。顺序颠倒（先 apply 后装 CLI）会用旧内嵌字节覆盖回旧版，漂移复现。
- `no-residue.sh` / `README.md` / `governance-review/SKILL.md` 等其余 drift 项由 `upgrade apply`
  一并刷新——它们是版本差不是缺陷，刷新即消失。
- A2 断言数 38 → 40（新增 2 条），`##SPEC asserts/rejects` 运行时产出，不手写常数。
- 框架仓 `verify-note.sh` 与 CLI heredoc 两份副本此后必须继续同批改（本记录写下的是纪律，不是自动化：
  双写一致性目前靠 review + 本仓 `tests/run.sh` 的模板比对场景看守）。
