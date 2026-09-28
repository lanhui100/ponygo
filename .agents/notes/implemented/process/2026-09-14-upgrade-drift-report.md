# Agent Note: upgrade 骨架漂移报告（宇宙 = s14 十文件 + --check）

Status: implemented

## Problem

`ponygo upgrade` 是六命令面里唯一不做实事的命令：只打印升级纪律与 remote 列表（`cmd_upgrade`）。
README 方式 C 以"方便跟随升级"为卖点，期望落差大。曾计划的"临时目录 write_skeleton 逐文件 diff
三态清单"被 TASK-002 双审实测否决：健康实例第一次运行就报 ≥3 条假漂移（constitution 填槽、
meta.yaml 的 level 是实例状态、README 真实 vs 占位）——一个"全是误报"的报告会被永久忽略。

## Decision

按 consultant 三选一裁决（Q2=A，`docs/dev-team/reviews/review-TASK-003-consultant.md`），
`cmd_upgrade` 重写为**骨架漂移报告**：

- **比对宇宙 = s14 的 10 个文件精确路径**（notes/README、skills/README、docs-tier/README、
  write-adr/SKILL、verify-note.sh、governance-review/SKILL、gates/README、change-review/SKILL、
  notes/AGENTS、archived/AGENTS），不另立清单文件（第三副本，slop 第一条）；
- 宇宙外文件（根 README、meta.yaml、已填 constitution、根 AGENTS.md/CLAUDE.md、classes.local、
  exemptions）根本不进报告；报告头一句话盲区声明"本报告只覆盖 s14 宇宙内十文件；宇宙外文件无基线，不判定"；
- **漂移是观察不是承诺**：默认 exit 0；新增 `--check`（漂移**或缺口**非零，供 CI）；
- donot 三场景：无 `.meta/`（真·空目录温和跳过 / 有实质内容 die 指引 init）、非 git WARN、
  无 level 按 L0（空值/畸形仍走 0.4 FAIL）；
- 已激活 docs-tier 实例：docs-tier/README.md 不参与比对（s14 锁模板态，P0-1(a)），其余九文件照常；
- 漂移行前缀 `drift:`、缺口行前缀 `缺口:`、末行自证 `tmpdir 已清理`。

框架规则细节（含否决的替代方案、采纳理由、影响面）见 `revisions/accepted/2026-09-14-upgrade-drift-report.md`。

## Alternatives considered

- **直接实现三态清单（一致/漂移/缺失）**：否决（实测）。健康实例首次运行即 ≥3 条假漂移。
- **改名 `ponygo guide upgrade` 或收敛命令面**：否决。六命令是拍板不变量（HANDOFF 决策表）。
- **mixed `<!-- instance:begin/end -->` 标记块**：否决（Q2 否决 B）。要求同提交改模板 + s14 契约 +
  激活程序，既有实例文件无标记 → 全量误报，属框架规则变更，留独立提案。
- **继续暂缓（C）**：否决。空命令价值为零；A 的 donot + 报告头是纯增量函数，可整函数 revert。

## Consequences

- `ponygo` 的 `cmd_upgrade` 重写（漂移报告 + 缺口 + `--check` + donot）、入口 parser 增 `--check`
  （仅 upgrade，与 `--dry-run` 互斥）、`UPGRADE_UNIVERSE` 常量、`usage()`；
- `tests/run.sh` s15 扩展双断言、s31 六场景 + 已激活 fixture；
- `README.md` §3.2 命令说明；
- 教训归因：`gates/README.md` 无"假漂移"一字，真源 = TASK-002 双审（不塞进用户可见输出）。

> 实证出处注：漂移报告形态源自 TASK-002 双审实测（"缺失才写"语义下基线从未建立、宇宙外文件
> 无基线）与 TASK-003 consultant 三选一裁决；本仓库为 ponygo 框架自身实例，宇宙十文件与模板
> 逐字节一致（s14 保证），`upgrade --check` exit 0。