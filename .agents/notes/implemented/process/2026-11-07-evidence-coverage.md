# Agent Note: 判据覆盖诚实化与 audit 漂移可见性

Status: implemented

## Problem

DSH 系列第 1/2 篇审查暴露出 ponygo 的「声明强于证据」问题：

1. `status` / `audit` 的机械影子只覆盖 1.1–1.9；1.10（必含 `## Alternatives considered`）
   只由 `.agents/skills/write-adr/verify-note.sh` 判定。但结论行写「L0-L1/L0-L2 机械判据
   全部 PASS」——一个缺备选节的 ADR 会让 `status` exit 0 并宣称全 PASS，实际 1.10 未验证。
2. 第 1 篇宣称 `audit` / `status` 可巡检「契约漂移」，但骨架漂移只在 `status` / `upgrade`
   报告，`audit` 不报；`--json` 也没有 drift 字段。
3. 生成的 `.meta/gates/README.md` 写「首版（L2 及以下）此目录为空 / 实例仓照旧从空开始」，
   而 `init` 实际生成 A1/A2/A4 资产——生成物自相矛盾。
4. 「零依赖」未说明运行依赖：git、GNU date/find/sed；`observe` 还需外部 skill。
   用户只能在失败后才知道。

## Decision

四项都做成**默认行为，零新增旗标**：

1. **覆盖声明精确化**：`lv>=1` 的结论行改为「判据 1.1–1.9 PASS；1.10 未由本命令验证——
   由 A1/A4 门把关」；无本地/远端门禁载体时追加「1.10 无门禁载体」并 stderr WARN。
   `--json` 增加固定词表 `coverage: {verified:["1.1-1.9"], unverified:["1.10"],
   reason:"readonly-no-repo-exec"}`。不在 CLI 复刻 1.10（P9），也不让 `status` 执行仓库脚本。
2. **audit 漂移可见**：复用 status 的骨架比对（同一 `UPGRADE_UNIVERSE` + 模板基准），
   `audit` 默认打印「骨架漂移（观察项，不改退出码）」段；`--json` 增加
   `drift:{count:N, files:[...]}`。漂移不改变退出码。
3. **生成物文案与事实一致**：gates/README 改为「框架交付资产 A1/A2/A4/A6/A7 常驻；
   实例自有门禁从 L2 起按需添加」，并补 pre-push 可选一行（不生成 hook、不加旗标）。
4. **环境依赖默认可见**：`status` 在「治理级」后打印
   `环境：git ✓ / GNU date ✓ / find -printf ✓ / sed -i ✓ / observe skill ✓`（缺项 `✗`）。
   不改退出码。

## Alternatives considered

- **status/audit 直接执行 verify-note.sh 以硬判 1.10**：否决——违反「只读命令不执行仓库脚本」
   的安全边界（陌生遗留仓 = 任意代码执行面）；用覆盖声明 + A1/A4 门承担执行判据。
- **在 CLI 内复刻 1.10 判定**：否决——一份判据两份实现必然漂移（P9），且 1.10 的真源是
   verify-note.sh / A1 / A4。
- **新增 `--drift` / `--doctor` / `--coverage` 旗标**：否决——违反旗标预算；默认输出
   已经能表达观察项，机器面复用既有 `--json`。
- **status 直接 exit 1 以强制 1.10**：否决——只读命令无法安全验证 1.10 时，硬失败会把
   「未验证」误报成「违规」；诚实标注比伪造门禁更坚固（P6）。
- **让 audit 自己复制一份骨架比对**：否决——两份实现必然漂移；抽同一函数复用。

## Consequences

- 用户不再看到「全部 PASS」掩盖未验证判据；JSON 消费者能区分 verified / unverified。
- audit 的漂移报告与 status/upgrade 同源，三处口径一致；漂移仍是观察项，不阻断。
- 生成物不再自相矛盾；环境缺失在 status 首屏可见。
- 输出契约变更需同步 tests/run.sh 的既有断言（由 Test Agent 冻结）。
