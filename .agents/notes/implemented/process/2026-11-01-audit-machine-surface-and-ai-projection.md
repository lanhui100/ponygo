# Agent Note: 审计机读面、AI 常载命约判据与受控探针

Status: implemented

## Problem

上一轮 fail-closed 修复（`2026-11-01-audit-judgement-fail-closed.md`）留下了三项延后项，
它们共同点是「判定面缺一个可机读/可复现的入口」，导致人（或 agent）只能靠散文取证：

1. **审计结果不可机读**：顶层 `audit`/`status` 只输出中文散文，`--json` 是 observe 子域专属
   （其余命令显式拒绝）。CI 与 agent 无法稳定解析「命中几项、哪条判据 FAIL、退出码为何」。
2. **AI 常载命约是否投影，没有任何判据**：`ponygo sync` 会往根 `AGENTS.md` 写
   `<!-- BEGIN constitution -->` … `<!-- END constitution -->` 哨兵块，但 L2 的 14 项与 2.4
   六条 AND 都不判它。实测某实例 `AGENTS.md` 里 `ponygo` 出现 0 次（从未投影），
   `ponygo audit` 仍 14/14 通过——这是「承诺可验」的覆盖空洞。
3. **observe 的动态证据不可复现**：ob1/ob2 依赖「Tempo 里有一条该 service 的 span」，
   而 CLI 不提供产出该证据的手段。会话审计里 agent 为此翻了 skill 的 shell 脚本、
   从集群 secret 抠 token、手写 OTLP POST，合计约 24 次工具调用；且这条人工 POST 一旦
   去掉标记就能把 ob0 刷成 ob2。

## Decision

1. **`--json` 升级为顶层审计机读契约**：`ponygo audit --json` / `ponygo status --json` 输出
   单行固定词表 JSON（`ponygo.audit/1`、`ponygo.status/1`），`exit` 字段与进程真实退出码同源；
   接受面是**显式白名单**（`audit`/`status`/`observe status`/`observe audit`），
   补集 6 条命令继续 die。不带 `--json` 时人类 stdout 逐字节不变（F8 把它冻成 `cmp` 契约）。
   JSON 内禁自由文本：`fails`/`gaps` 用稳定 id（判据号、`no_decisions`、`no_local_hook` 等）。
2. **新增 L2 条件判据 2.6「AI 常载命约已投影」**，完全仿 2.5 的三态：未声明 `ai-surface`
   → SKIP + WARN（只走 stderr，见例外 EX-1）；`off` → 显式 opt-out，结论行禁写「全部 PASS」；
   `on` → 根 `AGENTS.md` 必须含成对哨兵块。哨兵字面量上提为唯一真值（`SYNC_BEGIN`/`SYNC_END`），
   `do_sync` 与 2.6 共用，禁第二副本。**硬约束：未声明 `ai-surface` 的既有实例行为零变化。**
3. **新增 `ponygo observe probe`**（observe 子命令，不是新顶层命令）：从 env 取 endpoint/token
   （`--endpoint` > `PONYGO_OTEL_ENDPOINT`；token 只认 `PONYGO_OTEL_TOKEN`，永远 `<redacted>`、
   永不落盘），发一条带 provenance 的 OTLP/HTTP span（`ponygo.probe=true`、
   `ponygo.probe.version=1`、span 名 `ponygo.probe`），成功打印「等待 10 秒后执行 observe audit」；
   网络/非 2xx/超时 → exit 2，用法/缺参 → exit 1。**不改 `observability-onboarding` 技能本体**；
   T4 绑定证据来源需要技能侧改动，已落 `docs/dev-team/reviews/rfc-observe-t4-provenance.md` 提案。

## Alternatives considered

- **让 `audit --json` 与 observe 共用 `ponygo.observe/1` schema**：否决。顶层审计的字段
  （tier/hits/ladder/gates）与 observe 的四维判定完全异构，混用会让下游解析分支爆炸；
  独立 schema + 同一 `command` 字段即可分流。
- **`--json` 直接把人类输出"降级"为机器可读（如 `KEY=VAL` 行）**：否决。半结构化等于
  既不人类友好也不机器友好；`--json` 必须严格单行 JSON，人类文案继续走 stderr。
- **2.6 直接强制（不做条件判据）**：否决。会给所有 L2 实例新增 FAIL 面（跨仓破坏性变更），
  且各仓根 `AGENTS.md` 多有手工内容；沿用 2.5 的「声明即承诺」模式，让是否启用成为显式选择。
- **让框架仓自己立刻声明 `ai-surface: on`**：否决（本轮不做）。本仓根 `AGENTS.md` 是文档体系
  **标准的家**（人写的契约），投影会在其中插入生成块，需先决定"标准与投影共存"的形态；
  当前保持未声明 = SKIP + WARN，是诚实的"未表态"，不是假绿。
- **`observe probe` 顺手把 token 写进 `.env` 或缓存**：否决。凭据落盘会把"一次性探针"
  变成长期秘密面；token 只从 env 读、绝不回显。
- **在 `obserse probe` 里实现"探针不得冒充线上流量"的检测**：否决（超出 CLI 能力）。
  真假证据只能由服务端指纹 + 技能侧判据区分，故本案只做 RFC，不动技能。

## Consequences

- CI 可直接 `ponygo audit --json | jq -r .exit` 或按 `ladder.fails` 做分级处置；
  新增一种**不改变退出码**的消费方式，`!=0 即红` 的旧用法不受影响。
- 2.6 让「AI 常载命约是否投影」第一次可被机器判；未声明实例只多一行 stderr WARN，
  这是 EX-1 显式例外（F8 把人类 stdout 冻成 `cmp` 契约，告知面只能走 stderr）。
- `observe probe` 把「人工伪造 span」变成「受控探针」，但**判据仍未绑定来源**——
  probe-only 证据仍能达成 ob1 PASS。真正的收口在 RFC 第 1 条（技能侧 T4 分档），
  在此之前 `observe probe` 的定位是"可复现的取证入口"，不是"更强的门"。
- 命令面仍六条；`ponygo probe` 会被当作未知参数拒绝（probe 只在 `observe` 之后合法）。

## Consequences

**第二批处置（终审 7 条 BLOCKING 收口，2026-11-01 第三轮）**：

1. **CE-7（契约澄清，不改实现）**：F8-10「不带 `--json` 时人类 stdout 逐字节不变」的本意是
   **同一二进制**在带/不带 `--json` 下内容与退出码一致，**不是**「与上一版二进制逐字节相同」——
   后者会禁止任何新判据上线（2.5 的 SKIPPED 说明本就在 stdout 结论行）。故 2.6 的
   「SKIPPED」说明保留在 stdout（与 2.5 同先例），WARN 走 stderr；不变量只剩「退出码不变」。
2. **`status --json` 的 `skeleton` 三字段是路径数组**（不是计数），`missing_files` 口径严格等于
   `UPGRADE_UNIVERSE` 的 15 条（`.meta/meta.yaml` 不在其中，它由 0.4/目录存在性另判）——
   人类「骨架文件缺口：N」与 JSON 数组同源同数。
3. **probe 的三处硬失败**：`--service` 与声明 service 双缺 → exit 1（不再静默 `unknown_service`）；
   `--timeout` 只接受正整数（`0` 等于取消预算，实测会静默挂死）、默认 10s；
   `--endpoint` 必须 `http(s)://` 开头，非法即用法错 exit 1（不是网络错 2）。
4. **凭据面**：token 不再出现在 curl argv（`/proc/<pid>/cmdline` 可读），改用 `-K` 临时配置文件
   （`mktemp` + `chmod 600` + EXIT/INT/TERM 三钩清理，内容不进日志）。
5. **报文体**：`--service`/`--env` 等进入 JSON 的字符串走 `json_escape()`，注入样例
   （`--service 'x","y'`）后 body 仍为合法 JSON、原值原样保留。
6. **2.6 成对性**：恰一个 BEGIN、恰一个 END、BEGIN 行号 < END、块内非空，任一不满足即 FAIL
   （此前只判两条字面量出现过，END 在上/空块都能骗过）。
7. **JSON 单行不被污染**：spec 子进程调用处一律 `3>&-`，避免其继承人类报告 fd 破坏单行输出；
   `verdict` 兜底改为「verify_ladder 未跑但进程硬失败 → `fail`」，不再把 spec 硬失败写成 `unverified`。
