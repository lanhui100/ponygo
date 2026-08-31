# Revision: 骨架文档的 methodology 引用显式外部化——修死链，不复制文件（accepted）

Status: accepted

## 框架规则变更

实例骨架文档中对 methodology 的裸引用（`methodology.md §x`，实例仓库里并无此文件，
全是死链）统一改为**显式外部引用**：指向 ponygo 框架仓库
`docs/methodology.md`（附 GitHub 永久链接形态 URL），并统一加注
"原理层唯一真相源在框架仓库，实例不复制——复制即漂移"。涉及：
decisions/README（§2.3）、skills/README（§3.1/§3.3，加出处注）、
docs-tier/README（§5.1/§5.4，加出处注）、constitution 命约"链"头注、
write-adr/SKILL.md 的 maturity-ladder 引用（补 URL）。

**methodology.md 不进实例骨架**——这不是遗漏，是设计：原理层（为什么）归框架仓库，
机制层（怎么做）已自包含在各目录 README 契约；复制 44KB 进每个实例 = 框架一修订、
全部存量副本过期（两份真相），外加实例阅读税/上下文税。

## 采纳理由（回馈证据）

骨架文件的"想懂为什么"指针在实例里查无此文件，违反框架自己的引用可达纪律
（dsh verify-md-links 门抓的就是死链）。修法二选一——复制文件（漂移）或
指针可达（零漂移）——显式外部引用是唯一不引入第二份真相的解。

## Alternatives considered

- **init 拷贝 methodology.md 进实例**：否决——复制即漂移 + 实例上下文税。
- **`ponygo init --with-methodology` 选装拷贝**：暂缓——有离线/私有部署的真实
  诉求再加，不为假想需求预建（停止线）。
- **删掉所有"原理"引用**：否决——"想懂为什么"是合法需求，死链的修法是修指针，
  不是消灭延伸阅读。

## 影响面

- 骨架 heredoc × 3 + 仓库骨架文件 × 3 + constitution + write-adr SKILL 双写同步，
  s14 逐字节测试看守；存量实例的旧骨架不受影响（引用失效程度不变，重 init 或
  手工同步可得新版）。
