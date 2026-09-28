# Revision: `ponygo upgrade` 骨架漂移报告（宇宙 = s14 十文件；Q2=A）

Status: accepted

## 回馈证据（upgrade 评审 4 P0 + consultant Q2 裁决）

`cmd_upgrade` 长期是六命令面里唯一"不做实事"的命令（只打印升级纪律 + remote 列表）。
曾计划"在临时目录用 write_skeleton 生成骨架逐文件 diff 输出三态清单"，TASK-002 双审实测否决：
健康实例第一次运行就报 ≥3 条假漂移（constitution 填槽、meta.yaml 的 level 是实例状态、
README 真实 vs 占位），一个"全是误报"的报告会被永久忽略。TASK-003 交由 consultant 三选一
（`reviews/review-TASK-003-consultant.md` Q2）：**选 A——按 spec §3.2 落地**；否决 B
（mixed `<!-- instance:begin/end -->` 标记块，框架规则变更不可搭车）；否决 C（继续暂缓，空命令价值为零）。

## 框架规则变更

1. **比对宇宙 = s14 的 10 个文件精确路径**（`.agents/notes/README.md`、`.agents/skills/README.md`、
   `.meta/docs-tier/README.md`、`.agents/skills/write-adr/SKILL.md`、`.agents/skills/write-adr/verify-note.sh`、
   `.agents/skills/governance-review/SKILL.md`、`.meta/gates/README.md`、`.agents/skills/change-review/SKILL.md`、
   `.agents/notes/AGENTS.md`、`.agents/notes/archived/AGENTS.md`）；**不另立清单文件**
   （第三副本，slop 第一条）。宇宙外文件（根 README、meta.yaml、已填 constitution、根 AGENTS.md/CLAUDE.md、
   classes.local、docs-tier/exemptions）根本不进报告。
2. **报告头一句话盲区声明**："本报告只覆盖 s14 宇宙内十文件；宇宙外文件无基线，不判定。"
   （architect P0-2 修法 a：诚实声明盲区，而非"无基线单列"逐项放水。）
3. **exit 语义：漂移是观察不是承诺**（status 管骨架缺口 exit 1，upgrade 管"与模板差多少"）：
   默认报告 exit 0；新增 `--check`（漂移**或缺口**非零，供 CI；复用 `audit --run-specs` 的 opt-in 范式）。
4. **donot 三场景**：
   - 无 `.meta/`：真·空目录（含仅 .git）温和跳过 exit 0；有实质内容的目录 die 并指引 init；
   - 非 git → WARN（对齐 status）；
   - 无 level（缺 meta.yaml 或缺 level 行）→ 按 L0 处理；空值/畸形仍走 0.4 FAIL 语义，不走 L0。
5. **已激活 docs-tier 实例**：`.meta/docs-tier/README.md` 不参与比对（s14 契约锁模板态，
   激活即破 s14，按 P0-1(a) 诚实声明不支持），其余九文件照常比对——不使合法激活实例恒漂移/`--check` 恒红。
6. **漂移行前缀钉为 `drift:`**；缺口行前缀 `缺口:`；输出末行打印 `tmpdir 已清理`（报告内自证，不断言 /tmp 全局 diff）。

## 采纳理由

- 范畴错误用"宇宙外置"根治：`write_skeleton` 全员"缺失才写"，对 init 时已存在的文件
  （真实 README、已填 constitution、已有 .gitignore）模板从未成为基线，拿 tmp 重生成 diff 是范畴错误；
  宇宙 = s14 十文件是模板保证逐字节一致的最小集合，健康实例零"漂移"行是机械真命题；
- 教训归因：`gates/README.md` 全文无"假漂移"一字，真源 = TASK-002 双审（不塞进用户可见输出）；
- 纯增量函数，可整函数 revert，风险不对称地低。

## Alternatives considered

- **直接实现三态清单（一致/漂移/缺失）**：否决（实测）。健康实例首次运行即 ≥3 条假漂移；
  宇宙外文件"无基线单列"就是诚实标注，不是逐项放水。
- **改名 `ponygo guide upgrade` 或收敛命令面**：否决。六命令是拍板不变量（HANDOFF 决策表）。
- **mixed `<!-- instance:begin/end -->` 标记块**：否决。要求同提交改模板 + s14 契约 + 激活程序，
  既有实例文件无标记 → 全量误报，属框架规则变更，留独立提案。
- **交付 v+2 自动合并**：否决。风险不可控，且与"保留 git 血缘"纪律冲突。

## 影响面

- `ponygo`：`cmd_upgrade` 重写（漂移报告 + 缺口 + `--check` + donot）、入口 parser 增 `--check`
  （仅 upgrade；与 `--dry-run` 互斥）、`UPGRADE_UNIVERSE` 常量、`usage()`；
- `tests/run.sh`：s15 扩展双断言、s31 六场景 + 已激活 fixture；
- `README.md` §3.2 命令说明；
- 版本：v2.6.0（README 示例同步）。