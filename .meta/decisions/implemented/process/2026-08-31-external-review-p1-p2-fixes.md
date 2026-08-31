# Agent Note: 外部审核 EXTERNAL-001 的 P1/P2 组修复

Status: implemented

## Problem

外部审核（`docs/dev-team/reviews/review-EXTERNAL-001.md`）发现 P1 组 5 项、P2 组 5 项问题，
集中在：audit 与 status 判据分裂、audit 可被形状合规刷分、sync 硬编码中文标题、
read_level 空值宽放成假 L0、upgrade 空命令期望落差、class 封闭集无扩展口、
revisions/decisions 双轨边界不清、缺 LICENSE、HANDOFF 过期陈述、docs-tier 无可填模板。

## Decision

逐项修复（均为增量、不改命令面）：

1. **audit 内嵌级自洽验证**（P1-1）：`cmd_audit` 在存在 `.meta/meta.yaml` 时尾部直接调用
   `verify_ladder`，判据不符列 FAIL 项并 exit 1——不再把判据级结论推给 status。
2. **深度信号 4 剔除 `.meta`**（P1-2）：ponygo init 自己的产物不再把项目自动升 M 档；
   2.3 负样本 spec 在通过输出中补代理判据诚实标注（存在性 ≠ 真实负样本）。
3. **sync 投影体锚点化**（P1-3）：constitution 模板新增 `<!-- sync-body -->` 锚点（语言无关），
   无锚点回退中文「## 常载命约」标题兼容旧模板。
4. **read_level 空值不默认归 0**（P1-4）：`level:` 行存在但值为空/畸形时返回空串，
   交由 0.4 判 FAIL；`fmt_level` 对非法值显示 `L<非法:…>` 而非伪装 L0。
5. **README 方式 C 措辞收敛**（P1-5）：明示 `ponygo upgrade` 首版只打印纪律、不做合并，
   跟随升级靠 `git fetch && git merge`。
6. **classes.local 扩展口**（P2-1）：`decisions/classes.local` 每行一个额外 class 名即被
   判据 1.4 认可；封闭集本身不放开，扩展须显式落盘留审计载体。
7. **revisions 双轨边界成文**（P2-2）：框架规则演进 → `revisions/`；本仓库工程决策 →
   `.meta/decisions/`，写入 `revisions/README.md`。
8. **补 MIT LICENSE**（P2-3）。
9. **HANDOFF 过期陈述标注**（P2-4）：头部注明其为历史快照，"尚未 commit/剩余工作"已过时。
10. **docs-tier 模板落地**（P2-5）：占位 README 扩为含 8-tier 可填模板表 + slop checklist +
    词数预算纪律的全量版，生成器 heredoc 与仓库文件双改并纳入 s14 逐字节测试。

回归：`tests/run.sh` 新增场景 21（上述各点的正反对照例），s14 追加 docs-tier README
逐字节一致断言。

## Alternatives considered

- **upgrade 改名/移出命令面（P1-5 的强方案）**：否决——六命令面是 HANDOFF 拍板的不变量，
  改名是破坏性变更；措辞收敛以零破坏消除期望落差。
- **class 扩展走 meta.yaml 键**：否决——meta.yaml 合法键收敛为 level + ai-surface 是
  防漂移铁律；classes.local 用"文件夹即标签"同构的落盘文件承载，不污染 yaml。
- **sync 锚点做成 constitution 必填契约并拒绝旧模板**：否决——存量实例的 constitution
  没有锚点，回退中文标题保持兼容；新实例由模板自动获得锚点。
- **audit 验级只做 WARN 不改退出码**：否决——"机器可查缺口 = 非零退出"是 P2 原则，
  WARN-only 会构成假门禁（同 reviewer-1 P1-4 的裁决逻辑）。

## Consequences

- `ponygo audit` 的退出码语义变化：有治理根且判据不符时从 exit 0 变为 exit 1（语义收紧，
  已在帮助文本与 README 声明）。
- 模板生成的 decisions/docs-tier README 内容变更，s14 逐字节测试同步覆盖，防双源漂移复发。
