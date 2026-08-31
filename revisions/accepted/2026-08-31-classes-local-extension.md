# Revision: classes.local —— class 封闭集开放实例扩展口（accepted）

Status: accepted

## 框架规则变更

决策记录的 class 轴从"全封闭六类"改为"六类封闭集 ∪ `decisions/classes.local`
实例扩展"：每行一个额外 class 名（小写字母/数字/连字符，`#` 起注释与空行忽略），
判据 1.4 认可扩展类目录。封闭集本身不放开——扩展必须显式落盘成文件，
扩展即一次留有审计载体的治理决策，而非随手 mkdir。

## 采纳理由（回馈证据）

外部审核 EXTERNAL-001 P2-1：class 封闭集写死在 CLI，与 L6"领域定制"矛盾——
领域定制的第一个诉求往往就是加一个 class（如 `security`、`data-schema`）。
但完全放开封闭集会让"路径即标签"失去门禁意义。落盘文件扩展口是
"文件夹即标签"的同构解：标签集合本身也由一个可寻址、可评审的文件承载。

## 影响面

- 判据真源 maturity-ladder §5 1.4 已回写；`.meta/decisions/README.md` 契约
  （生成器 heredoc 与模板仓库文件）同步更新，s14 逐字节测试看守。
- 回归：`tests/run.sh` 场景 21 覆盖"未登记扩展 → FAIL / 登记后 → PASS"。
