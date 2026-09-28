# Agent Note: 发布校验和链（README fail-closed + installer 同钉 tag + release workflow 裸哈希）

Status: implemented

## Problem

`README.md` §3.1 推荐生产安装钉版本 + 校验和（`PONYGO_VERSION` + `PONYGO_SHA256`），
`install.sh` 也已实现 fail-closed 校验，但校验和的**发布物不存在**：README 主命令块管道
`curl -fsSL ... | awk` 失败后经 awk exit 0 置空，下游被视为未设置而**静默跳过校验**
（主路径 fail-open）；且 installer 从 `main/install.sh` 浮动拉取，main 变动即全链失守；
死链（空附件）被当推荐生产路径。

## Decision

按 consultant 三选一裁决（Q3=A，`docs/dev-team/reviews/review-TASK-003-consultant.md`），
交付可验证的发布校验和链（新 tag `v2.6.0`；严禁补 v2.3.0 旧附件）：

- **README 主命令块 fail-closed**：`set -o pipefail` + `[ -n "$SHA" ] || exit 1`
  （空 SHA / 附件 404 → 安装拒绝，非跳过校验）；
- **installer 与载荷同钉 tag**：bootstrap 行取 `{tag}/install.sh` + `PONYGO_VERSION` 同钉；
  install.sh 未设版本时仍回退 main（兼容分支）；显式空串 `PONYGO_SHA256=""` 拒绝安装（fail-closed）；
- **.github/workflows/release.yml（新）**：仅语义化版本 tag-push 触发；`sha256sum ponygo | awk '{print $1}'`
  裸哈希管线（对象 = checkout 的 ponygo blob）；runner 钉 Linux + 发布前 CRLF 断言；顶层
  `permissions: {}` + job 级仅 `contents: write`；第三方 action 钉 commit 全 SHA；发布前回验
  raw.githubusercontent 服务的 blob 与附件一致；
- **未发布状态诚实标注**：README 注明"未发布时按本地自算口径"，bootstrap 钉 tag 后 installer
  与载荷同源；校验只保 `ponygo` 不保 `install.sh` 自身（信任链起点诚实标注）。

框架规则细节（含否决的替代方案、采纳理由、影响面）见 `revisions/accepted/2026-09-14-upgrade-drift-report.md` 同级；
本项目发布规则随 `revisions/accepted/` 框架规则体系统一归档。

## Alternatives considered

- **只修 README（不改 workflow / 不推 tag）**：否决（Q3 否决 C、B）。P0-1/P0-2 是 fail-closed
  生死线，只修 README 丢掉 installer 同钉（全链失守）与 workflow 最小权限；不端到端验证等于语义空转。
- **给 v2.3.0 补发附件**：否决。旧提交不含守卫，补发 = 用新口径为旧代码背书（失实认证）。
- **`install.sh` 内置校验和**：否决（既有提案）。校验和必须与版本绑定并对外公布，内置等于自证清白。

## Consequences

- `.github/workflows/release.yml`（新）+ `README.md` §3.1 fail-closed + `install.sh` 空 SHA 拒绝 +
  `tests/run.sh` s30（fail-closed / 同钉 tag / workflow 六断言 / CRLF / 裸哈希口径）+ s29 版本一致性；
- 发布动作（WP-P）由维护者执行：打 `v2.6.0` tag → push → 建 Release 传 ponygo.sha256 → 端到端验证 A5；
- 残余风险书面化：curl|bash 信任链起点、GitHub 托管/HTTPS 背书、install.sh 默认 main 回退分支
  （已明示仅供未发布新版本使用）。

> 实证出处注：fail-closed 双入口（README 守卫 + install.sh 空 SHA 拒绝）、workflow 裸哈希管线与
> CRLF 断言、action 钉 SHA 与 raw 回验，均源自 release 评审 P0-1/P0-2/P1-1/P1-3 与 security 快审
> P1-1/P1-2/P2-2 的修复闭环；本仓库 v2.6.0 发布时以真实附件值复核 A5。