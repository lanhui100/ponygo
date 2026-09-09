# Review 记录 —— TASK-002 代码审查（@code-reviewer-a / @code-reviewer-b 独立双审 + 处置）

> 2026-09-08 ｜ 对象：TASK-002 / spec rev2 的未提交工作树
> 说明：两个 reviewer 首次运行时长时间未落定（~55 分钟），经中断 + 索取后均交付报告；
> 期间工作区有 3 次并发改动，reviewer 结论针对其各自快照，处置以**当前工作区**为准。

## 一、独立审核结论

| 角色 | 结论 | 要点 |
|---|---|---|
| @code-reviewer-a（正确性/回归/可维护性） | **有条件通过**（无 P0/P1） | 2 条 P2 必修 + 若干 P3 |
| @code-reviewer-b（边界/失败路径/简化） | **不通过**（1 P0 + 3 P1） | 功能正例/反例/聚合/dry-run/递归/无 spec 实测均通过 |

## 二、问题与处置

### P0（B）

| 问题 | 处置 | 验证 |
|---|---|---|
| level:2 实例跑 `audit --run-specs`：先报 SKIPPED，结论仍打印「L0-L2 机械判据全部 PASS」且 exit 0 | **采纳**：`cmd_audit` 用 `case` 消费 rc（0 通过 / 2 置 `SPEC_SKIPPED=1` / 其余 exit 1），`verify_ladder` 结论行追加「；2.3 执行判据 SKIPPED——本次未验证」 | 复现命令输出：`级自洽验证：通过（L0-L2 机械判据全部 PASS；2.3 执行判据 SKIPPED——本次未验证）` |

### P1

| 问题 | 处置 | 验证 |
|---|---|---|
| 外部预置 `PONYGO_IN_SPEC=1` 静默关闭执行判据，消息谎称"正在 spec 内执行" | **采纳**：改述为「检测到 PONYGO_IN_SPEC=1（递归护栏）」+ 补一行「该变量若由外部预置，执行判据同样被跳过，且**不视为验证通过**」 | s27⑤ + 复现 |
| `timeout 30` 兜不住「后台进程 + 立即退出」的 spec（命令替换等管道写端关闭） | **采纳**：输出改重定向到 `mktemp` 文件（顺带解决大输出全量进变量） | 墙钟：修复前 19s → 修复后 9s（基线 4s，Windows/MSYS 残留 +5s）；挂死 spec（sleep 45）→ 36s rc=1，上限生效 |
| 发布口径不可执行（404 + 校验和整行比对失败） | **部分采纳**：`README` 生成/消费口径改为 `awk '{print $1}'` 取裸哈希（与 `install.sh` 整串比对对齐）；404 属"tag 未推送"的预期态，README 已写明"未发布时本地自算" | 端到端实测：裸哈希 → 安装成功；错误值 → fail-closed 拒绝且残留 0 文件 |

### P2

| 问题 | 处置 |
|---|---|
| `sha256sum ponygo > ponygo.sha256` 产出行含文件名列（A P2-1 / B P1-3） | 采纳：`sha256sum ponygo \| awk '{print $1}'`；README 消费侧同样 `awk` |
| README `bash .meta/gates/*.spec.sh` 多 spec 只跑第一个（A P2-2） | 采纳：改为 `bash .meta/gates/<name>.spec.sh`，并加一句"勿写通配" |
| `${tail_:-（无输出）}` 死代码、FAIL 行尾部为空（B P2-4） | 采纳：文件重定向后空文件 → 空串 → 回退文案生效 |
| 无 `timeout` 时不披露（B P2-5） | 采纳：新增 `[warn] 本环境无 timeout：spec 自检无时间上限——如实披露，不假装有护栏` |
| s27① 用 level:1，覆盖不到 L2 分支（B P2-6） | 采纳：新增 ①b —— level:2 实例放会落盘的门禁脚本，断言 `status` 不执行（`2.2` 只做 `bash -n`） |
| s29 漏 `0—6`（em dash）与 `.meta/gates/README.md`（B P2-7 / A P3） | 采纳：正则改 `0[[:space:]]*[-–—][[:space:]]*6`；白名单加 `.meta/gates/README.md` |
| `meta.yaml` 称唯一真源而 `ponygo` 的 `LEVELS` 仍复述档位名且无断言（B P2-8） | 部分采纳：`meta.yaml` 改述为"本字段是当前档位的唯一真值源；各档定义见 maturity-ladder.md"；s29 新增「CLI LEVELS 仅 L0-L5」断言 |

### P3

| 问题 | 处置 |
|---|---|
| `rc∉{0,1,2}` 时 fail-open（A） | 采纳：`case` 的 `*) exit 1` |
| 测试不断言护栏变量真导出（A） | 采纳：新增 ②b —— spec 内断言 `PONYGO_IN_SPEC=1`，缺则 exit 3 |
| 缺 ≥2 失败聚合断言（A） | 采纳：③ 改为两个失败 spec（exit 1 / exit 5），断言两条都报 |
| 缺 usage 披露断言（A） | 采纳：新增 ①c |
| `docs/methodology.md` 含旧 bug 叙事、未列入影响面（A/B） | 采纳：删除叙事括注；spec §5 与 revision 影响面补 `docs/methodology.md` §4.6 |
| ADR 称"6 处"实为 7 处（B） | 采纳：改 7 处（README×4 + meta.yaml + constitution + retire） |
| 明细 stdout / 汇总 stderr 不一致（B） | 保留：明细与汇总均面向用户报告；不改（汇总进 stderr 便于 `2>/dev/null` 时静音，属可接受残余） |
| 根目录游离 `.full-test-out.txt`（A/B） | 已删除（编排器临时文件） |

### 未采纳

- **B 建议"砍掉整个 `--run-specs`"**：不采纳。维护者已裁决采用 opt-in 形态（Q2=A）；
  B 列出的 P0/P1 已逐条修复，且新增 12 条断言把契约锁死。

## 三、修复后验证

| 检查 | 结果 |
|---|---|
| `bash tests/run.sh` 目标场景（s12/s14/s27/s28/s29） | **pass=53 fail=0** |
| B 的 P0 复现（level:2 + 无 `.sh` spec） | 结论行已限定「2.3 执行判据 SKIPPED——本次未验证」 |
| B 的 P1-2 复现（后台进程 spec） | 墙钟 19s → 9s（基线 4s） |
| 挂死 spec（sleep 45） | 36s、rc=1（30s 上限生效） |
| 发布口径端到端 | 裸哈希安装成功；错误校验和 fail-closed 且残留 0 文件 |
| 全量回归 | 见 task 卡收口记录 |

## 四、可接受残余风险

- 执行判据仍是「spec 自证 exit 0」的代理判据（是否真构造非法样本靠 review）——已在模板与阶梯注明；
- opt-in 执行实例脚本本身（已披露只读契约，但无沙箱）；
- `timeout` 不杀孙进程；Windows/MSYS 下后台进程 spec 有数秒残留（Linux 预期为 0）；
- 仓库停 L1，`audit` 恒报「无本地钩子」（ADR 已记为机器事实，非缺陷）。
