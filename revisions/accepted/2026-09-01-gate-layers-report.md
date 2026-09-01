# Revision: 门禁分层操作化——audit 增加 P7 时间经济三层报告 + gates 模板教学（accepted）

Status: accepted

## 框架规则变更

1. **audit 新增「门禁分层参考」报告**（`gate_layers_report()`）：机械探测三层
   ——本地层 pre-commit（秒级：hooksPath 非空钩子 / lefthook / pre-commit / husky）、
   中继层 pre-push（10 秒级：hooksPath 下 pre-push / lefthook 声明）、远端层 CI
   （分钟级：workflows / gitlab-ci / 等跨平台探测）。输出三层有/无矩阵 + 缺层引导。
   报告性、不改退出码（时间经济性是"值不值"，P6——小项目只上 CI 也合法）。
2. **gates/README 模板升级**：从一行占位扩为全量版（heredoc 与模板仓库双写），
   补「门禁分层的三个时间经济层（P7，dsh 实证）」表：本地层秒级 / 中继层 10 秒级 /
   远端层分钟级各抓什么 + 落地形态（非零退出 = 拒绝、负样本 spec、hooksPath 挂载）。

## 采纳理由（回馈证据）

pony_clean 旧项目植入实证：ponygo 载入后 audit 只笼统报"无本地钩子"，
未检查门禁分层时间经济性——该项目的实际缺口是"有 CI（远端层）但缺本地层与中继层"，
最该补的是秒级 pre-commit（fmt/clippy 快速子集在提交时就拦住，而非等 CI 跑分钟级）。
P7 分层强制原理（methodology §4 dsh 实证：pre-commit 秒级 6 项 / pre-push typecheck /
CI 9 聚合 job）此前只停留在原理层，机制层（audit / gates 模板）没有把它操作化。
本次把"讲为什么"下沉为"怎么查 + 怎么学"。

## Alternatives considered

- **门禁分层做成硬判据（缺层即 FAIL）**：否决——时间经济性是价值判断（P6），
  小项目只上 CI 也合法；硬 FAIL 会把"值不值"错判成"有没有"。
- **分层写入 L2 判据（2.5）**：否决——L2 2.4 已查 hooksPath（本地层），
  分层经济性属 review 层；并入 audit 报告比塞进判据更诚实。
- **只改 gates 模板不查**：否决——旧项目植入时用户需要的是"当场知道缺哪层"，
  模板是教学、探测是诊断，两者都要。

## 影响面

- CLI 新增 `gate_layers_report()`（audit 尾部调用）；gates/README heredoc 化
  （heredoc 总数 6→7，s14 逐字节覆盖）。
- 测试：s24 覆盖零门禁（三层全无 + 缺层引导）与三层齐备（全有 + 无缺层引导）；
  s14 追加 gates/README 逐字节 + P7 分层断言。
