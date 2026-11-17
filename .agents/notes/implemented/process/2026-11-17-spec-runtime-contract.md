# Agent Note: 负样本 spec 的运行时契约（`##SPEC asserts/rejects`，灰度到 v3）

Status: implemented

## Problem

判据 2.3 要求"每个实例门的同名 spec 含**真实**拒绝断言"，但机械面只做**静态扫描**：
在代码位置找到 `exit/return [1-9]` 就算通过。审计复现的假门禁样本是

```bash
if false; then exit 1; fi   # 不可达分支：静态扫描命中
printf '跑了\n'             # 输出非空：执行判据也记 [ok]
exit 0
```

它同时骗过静态"拒绝断言"扫描与"执行 exit 0 + 非空输出 = 通过"两条面——
"门确实会拒绝非法样本"这条承诺在默认路径下从未被证明过。

## Decision

1. **spec 自报运行时计数**：成功路径最后一行打印 `##SPEC asserts=<a> rejects=<r>`。
2. **`audit --run-specs` 的判定（三态，灰度）**：
   - 有该行且 `rejects>=1` → 通过；
   - 有该行且 `rejects=0` → **判 FAIL**（`[bad] … 自报 rejects=0：没有拒绝断言`），exit 1；
   - 无该行（legacy spec）→ 逐 spec `[warn] … 未提供 ##SPEC 运行时计数（legacy；本轮 WARN，v3 起判 FAIL）`
     并在汇总打 `[warn] 2.3 legacy spec：K 个 …`；**退出码语义不变**。
3. **框架自带的 5 个 spec 本轮即补该行**（校准样例），`rejects` 由**逐断言累加**得出，禁止手写常数：
   `adr-verify.spec.sh` 38/24、`archive-verify.spec.sh` 6/5、`no-residue.spec.sh` 31/11、
   `scratch-hygiene.spec.sh` 10/4、`backlog-gate.spec.sh` 24/8（asserts/rejects）。
   A2/A7/A9 在宇宙表内，仓库副本与 `ponygo` heredoc 逐字节同步。
4. **文档**：`.meta/gates/README.md` 的 spec 契约节与 `maturity-ladder.md` 的 2.3 段写明格式、
   `rejects>=1`、灰度到 v3 与"为什么静态扫描抓不到不可达分支"。

## Alternatives considered

- **立即对所有 spec 硬判（不做灰度）**：否决——会让所有写过 spec 的实例（含 CI）一次性变红，
  与 W0 的"出厂即红 → 绕过"病灶同构；灰度把迁移成本显式化，且 `rejects=0` 这种**自报无拒绝**的情形
  已是硬 FAIL（可自证的那部分立刻生效）。
- **让 spec 声明一个常数 `REJECTS=12`**：否决——常数与断言条数会漂移，等于把"真实断言"换成"真实声明"；
  逐断言累加让数字由代码结构决定。
- **用"spec 输出行数 ≥ N"或"输出含 FAIL 字样"作为替代判据**：否决——横幅可伪造（审计已实测），
  长度不是拒绝证据。
- **对 bash 做 AST/不可达性分析**：否决——零依赖 bash 里没有可靠手段，做不到就会变成假门禁。
- **把 legacy 永久停留在 WARN**：否决——WARN 不计入 PASS 等于默认放过；故写死 v3 转 FAIL。

## Consequences

- `rejects=0` 的假 spec 现在立即被判红；legacy spec 在灰度期只告警，但告警文案点名 spec 与到期版本。
- 维护义务：新增"期望被拒"的断言时必须在旁 `REJECTS=$((REJECTS+1))`——这是**校准成本**，
  换来"数字由代码结构决定、不是手抄"。
- A2/A7/A9 字节变更 → 未升级的实例在 2.1 上会显示漂移（这是既有 upgrade 语义，配合 W0 的 seed
  `stale` 分类给出迁移信号）。
- 判不到的部分（诚实登记）：`rejects` 计数正确性仍靠 review（可以多累加）；"断言是否真的验证了应验之事"
  永远是语义判断。

## 环境备注（实施中发现）

开发机 `~/.local/bin/ponygo` 存在 2026-11-11 的旧安装副本：用裸 `ponygo`（PATH 解析）会命中旧副本，
使"本仓新版行为"的断言看似失败。验收套件因此统一用 `$CLI_BIN`/`bash "$ROOT/ponygo"` 而不是裸命令；
这也印证了 W0 的 U8 结论（跨仓植入必须可追溯版本，不能靠"PATH 上碰巧是哪个 CLI"）。
