# Review 记录 —— TASK-003 提案评审（发布校验和自动化）

> 对象：`.agents/notes/proposed/process/2026-09-08-release-checksum-automation.md`（暂缓提案）
> + README §3.1 已交付口径 + install.sh + ci.yml + tag 现状
> 评审者：独立对抗 reviewer（子智能体）｜ 结论：**不通过**（无需 full consultant，修后双代码复审 +
> 一个 @security-reviewer 快审即可）
> 取证基线：本地 `git show-ref --tags` 有 v2.3.0，`git ls-remote --tags origin` 为空、
> 工作树 ahead 1——tag 未推送，Release 附件几乎 surely 不存在；releases/download 探测在受限
> 网络下超时，无法证实可用。
> 记录人：@orchestrator（转录子智能体上报消息，结论与分级原样保留）

## 现状取证

- install.sh：PONYGO_SHA256 非空才校验，`sha256sum "$TARGET" | awk '{print $1}'`（或 shasum 兜底），
  找不到工具 fail-closed，失配删文件——期望输入是**裸 hex**。
- README §3.1：`SHA=$(curl .../releases/download/v2.3.0/ponygo.sha256 | awk '{print $1}')` +
  `curl .../main/install.sh | PONYGO_VERSION=v2.3.0 ...`；维护者口径
  `sha256sum ponygo | awk '{print $1}' > ponygo.sha256`；`.gitattributes` 为
  `* text=auto eol=lf`，实测 ponygo 零 CRLF、check-attr eol=lf。

## P0（必须修，否则维持不通过）

- **P0-1 README 主路径 fail-open 降级。** 附件 404 时 `curl -fsSL` 失败但管道经 awk 后 exit 0，
  SHA 置空，第二步 `PONYGO_SHA256=""` 被 install.sh 视为未设置而跳过校验——用户以为"钉版本+校验"
  实则无校验安装。缺 `set -o pipefail`/空值守卫 `[ -n "$SHA" ]`。与 install.sh 的 fail-closed 自相矛盾。
- **P0-2 死链当推荐。** 本地 tag v2.3.0 存在但 `ls-remote` 为空、ahead 1 未推，Release 附件几乎
  surely 不存在，第一命令块即死链。提案验收"首次发布后可复跑"把验证无限延期，等于用不可验证的
  命令做当前态承诺。必须标注"v2.3.0 未发布前此块不可用"或先推 tag 发附件。
- **P0-3 计算口径规范不足。** 提案只写"计算 SHA-256"，未钉死发布物必须是裸哈希。若 workflow 误用
  `sha256sum ponygo > ponygo.sha256`（整行 `hash *ponygo`），直接复用必被 fail-closed 拒绝。
  验收可被形状相似蒙混。

## P1

- **P1-1 安装链版本钉住不一致。** installer 取 `main/install.sh` 浮动，载荷钉 v2.3.0。main 的
  install.sh 被改即全链失守，应同钉 tag。
- **P1-2 runner 钉 Linux 方向对但理由/措施不全。** 须同时规定哈希对象是 checkout 的 `ponygo` blob
  （非 zip/tarball）、加 `grep $'\r'` 断言、无 CRLF 才发布。
- **P1-3 permissions 只写"contents:write 仅限该 job"不够。** 须顶层 `permissions: {}` 默认拒绝、
  第三方 action 钉版本/SHA、说明仅 tag-push 触发且不执行 PR 非受信代码。

## P2

- **P2-1 "测试断言口径一致"当前不可测试。** 不推 tag 就只能做 YAML 文本形状断言，属语义空转。
  测试须拆成：(a)静态断言 workflow 含精确管线；(b)本地动态复跑 README 命令 vs workflow 抽取命令
  diff；(c)附件裸 hex 正则 `^[0-9a-f]{64}$`。且 tests/run.sh 纯 bash 解析 YAML 脆弱，成本未评估。
- **P2-2 v2.3.0 硬编码三处**（附件 URL / PONYGO_VERSION / checkout 命令），s29 只看守 L0-L6 口径，
  无版本示例漂移守卫，下次 bump 必漂。
- **P2-3 覆盖边界诚实但 README 未同步警示强度。** 校验只保 `ponygo` 不保 `install.sh` 自身，
  `curl|bash` 头部仍无校验——README"生产推荐"措辞过强。

## P3

提案部分落地未拆条（step1 已交付仍与 TODO 同文件），违反 notes 部分落地拆条规则；标题"暂缓"+
Status proposed 与"本次已交付"混写，后续 supersession 难追。

## 被挑战的假设

1. "consumer 侧 awk 兜底则附件整行也行"——错，直接复用必被 fail-closed 拒。
2. ".gitattributes 足够故 runner 无所谓"——错，raw 与 checkout 归一化差异真实存在。
3. "README 口径本身可验证"——仅本地自算可验证，远端获取路径当前 404。
4. "首次发布后验证"——无负责人/时间，404 可能永久化。

## 建议修改

1. README 命令块加 pipefail 与 `[ -n "$SHA" ] || exit 1` 守卫；
2. 未发布状态诚实标注 + installer 同钉 tag；
3. 提案把 workflow 计算命令钉死为裸哈希管线并附 CRLF 断言；
4. 验收测试拆静态+本地动态+格式三断言；
5. 顶层 permissions 默认拒绝 + action 钉 SHA；
6. 拆条：已交付口径归 implemented，workflow 留 proposed。
