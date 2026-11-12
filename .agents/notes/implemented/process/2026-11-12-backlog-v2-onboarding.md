# Agent Note: pg-backlog v2 待办体系落地（账本契约 + 实例门 + 旧 md 任务单迁移）

Status: implemented

## Problem

本仓的任务载体是 `docs/dev-team/tasks/TASK-NNN.md`（md 任务单），它有三个结构性缺口：

1. **无状态机、无机器判据**：「状态」是自由文本表行，`Done/Backlog` 靠人写；谁在做、写了哪些文件、
   闭环证据是什么，没有任何非零退出命令能判。wave-14 收尾后 `TASK-005` 就以一行 `Backlog（…已定位未修）`
   沉在文档里，既不在看板里、也没有租约防止两个会话同时开工。
2. **并发不可控**：md 文件没有「同一任务同时只允许一个会话」的原子机制，多 lane 并行时靠自觉。
3. **历史与活动混居**：已闭环的 4 张单与未闭环的 1 张单同目录同形状，读的人（和 agent）无法一眼分辨
   哪些是活待办。框架自己的 backlog 体系（skill `pg-backlog`：单一 JSONL 账本 + CLI + 租约 + 归档）
   正好覆盖这三点，且本仓作为 ponygo 实例应当先吃自己的狗粮。

此前本仓没有任何 `backlog/` 载体，也没有第二份账本需要兼容——是「新仓、全新接入」而非迁移旧账本。

## Decision

1. **账本与判定真源随仓**
   - 新增 `backlog/tasks.jsonl`（唯一活账本）、`backlog/archive/tasks-<YYYY>.jsonl`（闭环归档）、
     `backlog/.next-id`（高水位，单调不减）、`scripts/backlog.mjs`（CLI，`validateRecord` / `lint` /
     `doctor` 是唯一判定真源）。`backlog/.locks/` 是本地运行时租约，已 `.gitignore`。
   - CLI 从上游基线仓 `pony-agent` 的同名脚本搬运，并做**三处本地差量**（写在文件头血缘注释里）：
     `ID_FLOOR = 1`（上游因 triage 迁移把候选编号钳在 56；本仓首批编号须从 `B001` 起）；
     `record` 强制显式 `--fingerprint`（上游缺省 `manual`：不同任务共用同一指纹会被静默合并成一条，
     `README` 却把 `metadata.fingerprint` 写成必填——声称与行为不一致）；`annotate` 拒绝 `--status`
     （状态迁移只走 `start` / `release` / `resolve`，不留「改字段顺手改状态」的旁路）。
     不搬运 `import-triage` / `normalizeLegacy`（只服务 pony-agent 的旧 triage 账本，本仓无该载体）。
2. **契约回家 `backlog/README.md`**：布局 / 必填字段 / 状态机 / 租约 / 命令 / 门禁 / 迁移映射 /
   诚实边界一处写清，并显式声明「判定真源 = `scripts/backlog.mjs`，本文不复刻判据」。跨仓通用操作留在
   skill `pg-backlog`，本仓特化事实（迁入路径、接线、ID 下限）只写在仓内契约。
3. **旧 md 任务单一次性迁移并冻结**
   - `git mv docs/dev-team/tasks/TASK-001..005.md → backlog/legacy/dev-team-tasks/`（保留血缘，冻结只读，
     `.rgignore` 隔离，避免冻结史挤掉当前检索结果）；
   - `TASK-001..004`（Done）→ `B001..B004` 写入 `backlog/archive/tasks-2026.jsonl`（`done` +
     `evidence` + `closed_at` + `source_ref`）；`TASK-005`（Backlog）→ `B005` 留在活账本（`todo`）；
   - 映射规则写进 `backlog/README.md`「迁移」节：`source_ref` 指向冻结路径；旧「状态」表行原文摘入
     `evidence`（保留当时口径）；旧单**没有闭环时间戳**时 `closed_at` 取该单创建时间并在 `evidence`
     末尾标「迁移近似」——迁移只补最小可判定字段，不改写事实。
4. **实例门 + 同 Stem 负样本 spec**
   - `.meta/gates/backlog-gate.sh` = `lint` + `doctor` 编排（不复刻判据）；账本缺失 → 明确跳过（迁移期语义）；
     无 `node` → fail-closed。
   - `.meta/gates/backlog-gate.spec.sh`：P1 合法账本放行、**P2 编号下限 B001**（防上游 56 常量回归）、
     **P3 真实操作闭环**（record→start→resolve，断言锁生成/释放、归档落盘、活跃池清空后再过门）、
     **P4 实例级在场**（本仓 `tasks.jsonl` / `.next-id` / `scripts/backlog.mjs` 必须存在——门对「账本缺失」
     是跳过语义，这是迁移期友好设计，但本仓已启用，删掉账本会让整链静默变绿，故由 spec 常驻看住）、
     **P5 接线静态断言**（CI governance job 与 pre-commit 都真调本门、钩子含 fail-closed 分支）、
     N1–N8 非法样本逐条拒绝（含 `record` 缺 `--fingerprint`）、
     **H/H2 pre-commit 接线**：H = 门在场放行 / 门缺失 fail-closed；H2 = 门在场但账本非法 → 提交被拒
     且拒绝证据含 `backlog-gate: FAIL`（证明钩子**真执行**了门，而不是只在文件存在性上做样子——
     把调用行换成 `true` 或 `|| true` 的 mutant 必须被 H2 抓住）。spec 按 `.meta/gates/README.md` 的
     `*.spec.sh` 契约自包裹（`PONYGO_GATE_SPEC_TIMEOUT` + `-k 5` + `PONYGO_SPEC_NO_GUARD`），
     spec 内零平台判定。
5. **三处接线**：`.githooks/pre-commit`（追加在 ADR 哨兵块**之外**——判据 2.4 要求哨兵块 BEGIN..END
   逐字节等于规范块）、`.github/workflows/ci.yml` 的 `governance` job 独立 step、
   `ponygo audit --run-specs` 自动发现 `gates/*.spec.sh`。
6. **登记面 `.meta/gates/INSTANCE-GATES.md`**：登记门 / spec 配对 / 接线 /「承诺 → 非零退出命令」，
   不改 `.meta/gates/README.md`（它在 `UPGRADE_UNIVERSE` 内、逐字节比对）。
7. **same-commit 文档**：根 `README.md` 仓库文件索引（`backlog/` + `scripts/backlog.mjs` 两行）、
   `docs/dev-team/README.md`（任务单不再在本目录 + 冻结指针）、`.meta/docs-tier/README.md`
   （新增「待办账本」文档家）、`.gitignore`（`backlog/.locks/`）、`.rgignore`（`/backlog/legacy/`）。

## Alternatives considered

- **照抄上游基线仓（含 `ID_FLOOR=56` 与 `import-triage`）**：首次 `record` 会凭空分配 `B056`，编号与
  仓内既有 `B001` 起点无因果关系；`import-triage` 只服务 pony-agent 的 triage 载体，本仓无消费者，
  搬进来即死代码 + 错误出处 → 落选（改为参量化下限 + 不搬运，并用 spec P2 把下限钉成可执行判据）。
- **用 CLI `record`/`resolve` 迁移已闭环的 4 张单**：`resolve` 把 `closed_at` 写成**迁移当天**，
  历史闭环时间被抹平 → 落选（改为按旧单状态直接生成 JSONL，并在 ADR/契约里标明时间戳的近似口径）。
- **保留 `docs/dev-team/tasks/` 原地不动，只在新账本里记 `source_ref`**：旧 md 与活账本同形共存，
  读的人无法分辨哪份是活待办（双载体必然漂移），且 skill 的迁移口径要求旧 md 冻结进 `backlog/legacy/`
  → 落选（改为 `git mv` 冻结 + 文档家登记改写）。
- **照抄上游 `record` 的 `--fingerprint` 缺省（`manual`）**：两条不同 title 的 `record` 都省旗标时，
  第二条被当成第一条的重复命中（`occurred_count`+1），任务从账本里消失；而本仓契约把
  `metadata.fingerprint` 写成必填——声称与行为不一致 → 落选（改为 CLI 层强制显式指纹 + spec N8 看守）。
- **保留「账本缺失 → 跳过」的单薄语义、不加实例级看守**：跳过分支的正当性是「尚未启用账本」，
  而本次提交正是启用那一刻；此后一次 `rm`/坏合并就会让门永远 exit 0，spec 也照样绿 → 落选
  （改为 spec P4 常驻断言本仓三个载体在场；跳过语义本身保留给新接入仓）。
- **H 用例只验「门在场放行 / 门缺失拒绝」**：实测把钩子里的调用行换成 `true` 或 `|| true`，
  三条断言仍全绿——它证明的是「文件存在性」，不是「门被执行」→ 落选（改为加 H2：门在场 + 账本非法
  必须被拒且拒绝证据含门输出）。
- **把 `backlog` 门塞进 `.meta/gates/ci-verify.sh`（A4）**：A4 属框架不可变门资产，`ponygo upgrade --check`
  逐字节比对，改它即制造永久 drift → 落选（改为 `ci.yml` governance job 的独立 step，与
  `scratch-hygiene` 同形）。
- **把实例门登记写进 `.meta/gates/README.md`**：同一逐字节锁定问题，追加一行就让升级检查常红
  → 落选（改为新增 `INSTANCE-GATES.md`，承认登记面分裂并在文件头写明原因）。
- **在 `tests/run.sh` 增加账本场景**：那套场景数是冻结契约（94/27 计数模型 + 叶子计数 A4/A5），
  加场景会连带改动计数断言与 README 口径；账本的执行判据本来就该放在门禁 spec（`audit --run-specs`
  真跑）→ 落选（改为在 `backlog-gate.spec.sh` 内做 P1–P5 + N1–N8 + H/H2）。
- **为 `ID_FLOOR` 造配置（env 或 `backlog/.id-floor` 文件）**：仓内只有一个取值，多一个配置面就多一条
  漂移路径；把「下限 = 1」写成常量并用 spec P2 看守更便宜 → 落选。

## Consequences

- 新增：`backlog/`（README / tasks.jsonl / archive/tasks-2026.jsonl / .next-id / legacy/ / legacy/README.md）、
  `scripts/backlog.mjs`、`.meta/gates/backlog-gate.sh`、`.meta/gates/backlog-gate.spec.sh`、
  `.meta/gates/INSTANCE-GATES.md`；改动：`.meta/gates/README.md` 不动，`.githooks/pre-commit`、
  `.github/workflows/ci.yml`、`.gitignore`、`.rgignore`、根 `README.md`、`docs/dev-team/README.md`、
  `.meta/docs-tier/README.md` 各一处接线/索引；`docs/dev-team/tasks/` 整体迁入 `backlog/legacy/`。
- 门禁语义：账本缺失时门明确跳过（新接入仓/干净克隆友好）；账本存在但记录非法、ID 越过高水位、
  活跃池残留 `done`、孤儿租约、锁在而记录非 `in_progress` → 拒绝提交与 CI。本仓已启用账本，
  「删账本 → 门跳过 → 全链绿」这条静默失效路径由 spec P4 常驻看住（它断言本仓三个载体在场）。
- **诚实边界**：`closed_at` 对 `B002`–`B004` 三条是「创建时间」近似（已在每条 `evidence` 标注；
  `B001` 用旧单状态行明写的收口日期）；
  spec 只证明「门会拒非法样本」，账本内容真实性靠 review；`doctor` 不解析 git 历史，识别不了
  「同时改记录与高水位」的伪装；本地钩子依赖 `core.hooksPath`（不随 clone 传播），未装配时由 CI 兜底；
  若连 `backlog-gate.spec.sh` 与 CI step 一起删掉，P4/P5 也随之消失——最终兜底是 review 与分支保护，
  机械门只能证明「当前这套接线在工作」。
- 后续任务一律经 CLI 流转，不再新增 md 任务单；`TASK-NNN` 编号成为冻结史里的检索键，活编号是 `B###`。
