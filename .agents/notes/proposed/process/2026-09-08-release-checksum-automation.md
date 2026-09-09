# Agent Note: 发布校验和自动化（暂缓）——先交付可验证的本地口径

Status: proposed

## Problem

`README.md` §3.1 推荐生产安装钉版本 + 校验和（`PONYGO_VERSION` + `PONYGO_SHA256`），
`install.sh` 也已实现 fail-closed 校验（P0-3），但**校验和的发布物不存在**：`git tag` 为空，
README 只写 `<公布的校验和>`。即机制的输入从未发布，README 那句话是空话。

TASK-002 曾计划新增 `.github/workflows/release.yml`（tag push 时计算 `ponygo` 的 SHA-256 并
作为 Release 附件发布）。双审指出：该 workflow 只有推 tag 才触发，而本次任务不推送远端，
**交付时零验证**——不可验证的交付物等于散文（P2）。

## Proposal

分两步：

1. **本次已交付**（可验证部分）：README 写清校验和的**生成口径**与获取路径
   （`git checkout <tag> && sha256sum ponygo > ponygo.sha256`，随 Release 附件发布；
   `ponygo` 以 LF 存储，raw 下载与本地自算一致），版本示例同步到当前版本号。
2. **待做**：`.github/workflows/release.yml`（tag push 触发，`permissions: contents: write`
   仅限该 job，runner 钉 Linux 以避免 CRLF 影响校验和），并配一条测试断言
   "workflow 计算口径与 README 自算口径一致"。

## Alternatives considered

- **本次直接交付 workflow**：否决。不可在本任务内执行/验证，且与"不推送远端"的非目标冲突。
- **不写 README 口径，只留 TODO**：否决。README 的口径本身可验证（一条命令），
  交付它零成本；留下的只是"发布物由谁上传"这一维护者动作。
- **让 `install.sh` 内置校验和**：否决。校验和必须与版本绑定并对外公布，内置等于自证清白，
  起不到供应链校验作用。

## Acceptance criteria

- README 的安装节给出可复制执行的校验和获取/生成命令，版本号与当前版本一致；
- 新增 workflow 后，有一条测试断言其计算口径与 README 自算一致（或直接复用同一脚本）；
- 首次发布后，`PONYGO_VERSION=<tag> PONYGO_SHA256=<release 附件值>` 安装路径可复跑成功。

## Risks

- 若维护者忘记上传 Release 附件，README 的"优先用发布物"路径会 404——需在 README 注明
  "未发布时按下方口径本地自算"，本次已写。
- 校验和只覆盖 `ponygo` 载荷，不覆盖 `install.sh` 自身（`curl|bash` 的头部仍无校验）；
  这是已知边界，需在 README 或本提案中诚实标注。
