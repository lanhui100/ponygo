# Agent Note: windows-full 取证交回 CI（判词归档步 + 停用本地 cron 触发）

Status: implemented

## Problem

B005 判据 4 要求「windows-full 至少一次完整绿证」。这条证据的取得方式一直靠**本地定时脚本**
（`.scratch/2026-11-22-backlog-v3/nightly-full.sh` + `crontab 0 1 * * *`）自触发、自轮询、自抓判词。
2026-11-23 连续三次红（run 45042996846 cancelled@240min、45103476794 failure@133min、
45222755424 failure 94/94 但有 10 条红）暴露出四个具体缺陷：

1. **重复触发**：`ci.yml` 已有原生 `schedule: '0 18 * * *'`(UTC) = 02:00 CST 跑同一 workflow，
   本地 01:00 再触发一次 ⇒ Actions 分钟翻倍、两轮结论混淆（夜间日志里两条 run 交叉）。
2. **marker 先写后触发**：脚本第 11 行写日期 marker、第 15 行才 dispatch —— 一次 dispatch 失败
   就锁死当天，不再重试（`[ -f "$MARK" ] && exit 0`）。
3. **判词 grep 截断**：`grep -oE "RED  s[0-9]+[a-z_]*"` 在遇到「字母后接数字」的场景 id 时截断，
   实测输出 `RED  s94_p`（丢 `1_fixes_acceptance`）—— 即取证脚本自身会伪造不完整证据。
4. **无人看**：结果只落 `.scratch/`，机器重启/cron 挂掉即静默丢失；且 `sleep 30` 后
   `run list --limit 1` 有抓错 run 的竞态。

外部评审（Antigravity 子智能体，会话 336ce99f…）独立复核出同一组缺陷，并给出「等待与取证
全部交回 GitHub Actions」的建议；本记录采纳该方向。

## Decision

**把 windows-full 的取证责任从「本地脚本」移回「CI 自身」，本地 cron 触发停用。**

1. **判词归档步（`if: always()`）**：测试步改为
   `set -o pipefail; bash tests/run.sh 2>&1 | tee "$RUNNER_TEMP/full.log"`；
   后置步从该日志提取「场景结果 / 总体判定 / TIMEOUT 与 RED 名单」，写入 `$GITHUB_STEP_SUMMARY`
   **并回显到 job log**（后者可用 `gh run view <id> --log --job <jid>` 复跑取证）。
   `pipefail` 保证 tee 不吞退出码；`if: always()` 保证**失败时也留证**（失败才是取证的价值点）。
2. **判词 grep 模式修正**：场景 id 一律按 `s[0-9]` 起头、后续吃字母/数字/下划线匹配，
   不允许 `s[0-9]+[a-z_]` 这类「数字即截断」的写法。
3. **停用本地定时触发**：删除 crontab 的 `nightly-full.sh` 行（备份见
   `.scratch/2026-11-22-backlog-v3/crontab.{before,after}`），触发改由 **GitHub 原生 schedule**
   或人工 `gh workflow run ci.yml --ref main` 承担。
4. **告警通道**：`all-checks-passed` 已按 gh6/D7 把 `windows-full` 的 failure/cancelled 判为失败，
   即红灯会直接把 main 的聚合门打红 —— 这就是「有人看到」的机械通道，不另开 Issue 机器人。
5. **防回退**：gh6 新增 D3c 三条断言（测试步必须 tee+pipefail；必须有 `if: always()` 的
   `$GITHUB_STEP_SUMMARY` 判词步；判词 grep 不得使用截断模式）。负样本实测：删掉判词步 →
   `gh6 rc=1` 并点名 D3c。

## Alternatives considered

- **方案 B：`ponycli`（LLM agent）全程托管触发+3~4h 轮询+汇总**：否决。token 成本与轮询次数成正比，
  turn 截断会产出「已完成」的幻觉结论；一旦给写权限，等于让模型绕过 review 与 ADR 门禁改码。
  取证这件事的确定性部分（等、抓、截判词）没有任何需要模型判断的成分。
- **方案 C：本地短命任务只做「拉结论 + 只读分析」**：不否决，但**降级为按需**。它在 D 之上没有新增
  可靠性，只多了「本地进程要活到那一刻」的依赖；红灯时人工跑一次只读分析即可。
- **保留本地 cron 但修好三处缺陷（marker 后移 / 按 run_id 幂等 / 判词模式改正）**：否决。修完仍与
  GitHub 原生 schedule 重复触发，且本地进程无守护（本机无 `systemd --user`，只能 cron/nohup）；
  复杂度用来重建 CI 已有的能力（run 日志保留、step summary、聚合门红相）。
- **把判词日志 `upload-artifact`**：暂不采纳。job log 本身就是不可篡改的留存（90 天），
  且 `gh run view --log` 可直接复跑取证；引入新 action 需要钉 SHA，收益不抵成本。
  若将来需要跨 run 归档，再单独决策。

## Consequences

- 取证路径变成：`gh run view <id>` 看 step summary；需要全文时
  `gh run view <id> --log --job <jid> | grep -aE 'TIMEOUT s|RED  s[0-9]|==== (测试结果|结果)：'`。
- 夜间不再有本地进程常驻；本机 cron 与 Actions 分钟不再双烧。
- B005 判据 4 的绿证由「CI run id + job log + step summary」三件构成，账本 `evidence` 直接引用 run id。
- 待办衔接：`backlog:B1795384149537`（windows-full 取证双因）继续跟踪 s91/s94 的 Windows 侧复证。
