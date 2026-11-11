# Agent Note: 2.6 校验 canonical 投影新鲜度并收口临时产物承诺

Status: implemented

## Problem

`ai-surface: on` 的实例把 constitution 投影到根 `AGENTS.md` / `CLAUDE.md`，但判据 2.6 只检查哨兵块的存在、成对、顺序与非空，不检查块正文是否仍等于 constitution 的 canonical 投影。只要有人改了宪法而忘了重跑 `ponygo sync`，`status` 与 `audit` 都返回 0：AI 会话读到的是过期命约，而治理报告宣称「级自洽验证通过」。这是「凭据存在」冒充「承诺成立」的假绿。

同一类缺口还有两处。命约 7 把「临时产物不得平铺源码旁」整体归因于 `scratch-hygiene.sh`，但该门只检查已跟踪 `.scratch` 条目、`.gitignore` 声明与发布/安装链引用，从不检查平铺文件；门禁 PASS 文案却写「工作区卫生合规」。`maturity-ladder.md` 的 L2 降级条写「降级要过同样的判据」，而 `retire` 只改写 `meta.yaml` 并打印提醒，代码注释自认「指引式，非硬校验」。

## Decision

判据 2.6 在原编号内扩展为「结构 + 正文新鲜度」两段，不新增 `sync --check`、不新增 2.6b、不改 `--json` 的 fail id。`AGENTS.md` 与 `CLAUDE.md` 都判：先逐文件判缺文件、缺 BEGIN/END、重复、倒序、空块；结构合法后才比较块正文与 constitution 的 canonical 投影。正文漂移给 `bash ponygo sync`；重复/倒序只提示手工清理；constitution 无投影体属 source 错误，只给 source 修法。`off` / 未声明 / 非法值、级别门槛、块外用户内容与 JSON 单行收口均保持原语义。

投影写入与校验共用一份 canonical 实现：`projection_body()` 选择 bootstrap 或锚点后的正文，`projection_write()` 是唯一写入路径，`projection_marker_count/line` 与 `projection_block_body()` 是唯一结构读取路径。写入改用 shell 变量经 stdin 交给 awk，删除 `awk -v body=`，从而消除反斜杠转义与 CRLF 哨兵失配（`docs/dev-team/specs/spec-ponygo-v0-v1.1.md:184-185` 记录的已知缺陷）。

`scratch-hygiene.sh` 的 PASS 文案收窄为「仅 E1–E3 通过」，并显式声明平铺临时文件不在覆盖范围；constitution 命约 7 与 `docs/AGENTS.md` 同步收窄承诺，不再把平铺禁令归因于该门。`maturity-ladder.md` 的 L2 降级条改为「留痕并由 review 验收；`retire` 不机械校验」，不把退场程序塞进 ADR 内容质量的非机械项表。

## Alternatives considered

- **新增 `ponygo sync --check`**：否决——同一判据出现两个入口（status/audit 与 sync --check）会产生两套别名与旗标预算；2.6 已在 `status`/`audit` 与 CI 的 `audit` 步执行，新增命令不增加观测面，只增加契约面。
- **新增 2.6b 子判据**：否决——`--json` 的 fail id 提取只认数字编号，2.6b 会成为第二个 id；且结构错误与正文漂移共享同一个补救对象（sync），拆号会让报告更难读。
- **只改文档、承认 2.6 只判存在性**：否决——该缺口机械可判且代价低；承认它等于让「AI 常载命约」这条核心承诺继续靠自觉。
- **在 `sync` 中自动修复陈旧投影**：否决——`status`/`audit` 是只读判定面，`sync` 是显式写路径；读取时隐式改写会让治理报告产生副作用，违背只读纪律。
- **把平铺临时文件检查塞进 `scratch-hygiene.sh`**：否决——只查 untracked/nonignored 文件会被 `git add`、ignore 规则与其它扩展名绕过；根目录限定又漏源码子目录，合法截图/字体会误报。改为收窄承诺与 PASS 文案，平铺由 review 判断。
- **把退级留痕加入 §5 非机械项表**：否决——该表专指 ADR 判据 1.7/1.8/1.10 的内容质量，且与 notes README 三行同表；退场程序属另一类，加入是分类错误。

## Consequences

- 改宪法未重投影会立即在 `status`/`audit` 报 2.6 FAIL（exit 1），并点名 AGENTS.md 或 CLAUDE.md；`sync` 后恢复 PASS。两份投影不再可能只更新一份。
- `sync` 对含反斜杠的正文逐字节保真；CRLF 文件不再被误判为缺哨兵（比较仅归一 `\r`），块外用户内容不动。
- 新测试 `tests/acceptance/projection-freshness/run.sh` 以黑盒方式覆盖 21 个场景（fresh/bootstrap、双文件漂移、结构错误、开关语义、块外改动、inline marker、CRLF、末尾空行、反斜杠、JSON），并接入 `tests/run.sh`；`tests/acceptance/deferred/f9_ai_surface_26.sh` 中手写任意正文断言 PASS 的假正例、以及重复/倒序「sync 可修」文案断言同步修正。
- 代价：`status`/`audit` 在 `ai-surface: on` 时多做两次投影体求值与块比较（毫秒级、临时文件、无网络）；没有默认加到 pre-commit，本仓由 CI 的 `audit` 步看守，通用实例若需要本地即时拦截须另行接线。
