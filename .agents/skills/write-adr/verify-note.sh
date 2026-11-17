#!/usr/bin/env bash
# ============================================================
# verify-note.sh —— 决策记录机械校验器（write-adr 技能的验证脚本）
#
# 用法：bash .agents/skills/write-adr/verify-note.sh [--json] [<notes 相对路径>…]
#   无参     = 校验整个 .agents/notes/ 树（推荐；等价 ponygo status 的 L1 判据）
#   带路径   = 只校验给定文件（如 .agents/notes/proposed/architecture/xxx.md）
#   --json   = stdout 只留一行机读 JSON（schema=ponygo.verify-note/1；可带路径参数，
#              用 mode 字段区分 tree / files），人类 FAIL/WARN 行整体改道 stderr；
#              退出码与不带 --json 完全一致（契约 §1.3 / §4 E-07）。
#
# 退出码（契约 §4 冻结）：0 = 全部通过（含「违例全被存量基线豁免」）／
#   1 = 存在**未被基线覆盖**的违例（逐项打印 FAIL）／
#   2 = fail-closed：存量基线损坏或无法判定（不猜、不放行；契约 §3.2）。
#
# 存量违例基线（.meta/notes-baseline.json，棘轮，机器写入禁止手填）：
#   状态 ok 的基线条目按 fingerprint 命中 → 该违例标记 baselined:true 并**豁免**（不计 FAIL）；
#   状态 expired → 全部违例重回生效 + 一行 WARN（到期日按 .meta 文件里的 expires_at）；
#   状态 absent → 无豁免；状态 corrupt → exit 2（fail-closed，不判违例）。
#   fingerprint = sha256( criterion "\t" file "\t" detail_key )，detail_key 为违例明细的
#   规范化（CRLF→LF、首尾空白剥除、连续空白折叠为单空格；纯存在型判据取空串）。
#   为什么把「判据 + 位置 + 明细」三元组一起哈希：只有明细也参与，才能把「同一文件同一判据
#   但内容变了」判成**新违例**——否则冻结就变成给该判据开永久后门（契约 §1.1.4）。
#   指纹由**本脚本**单点计算（P9 一份判据一份实现）：`ponygo upgrade adopt` 只解析本脚本
#   的 --json 输出，不在 CLI 复刻任何 1.x 判据、也不自己算指纹。
#
# 退出码：全部通过 exit 0；任一违例 exit 1（逐项打印 FAIL）。
# 对应判据：maturity-ladder §5 的 L1 判据 1.1–1.10，外加 1.11（负空间形状，见下），
# 影子来自 DSH verify-agent-note-format / verify-agent-note-classification。
# 1.1–1.8 与 ponygo verify_ladder 逐项对齐；1.9 只对齐 1.9a（详见下文「对齐契约」）；
# 1.10（必含 ## Alternatives considered）于 2026-10-29 新增为硬判据，**只由本脚本判定**——
# CLI 不重复实现（P9：一份判据一份实现，两份必然漂移），故 `ponygo status` 的 L1 段仍报
# 「判据 1.1–1.9」（1.9b 条件未判定时收窄为 1.1–1.8）并明文声明该范围；
# 1.10 的看守面由 A1 暂存区门与 A4 全树门承担（两者都经本脚本）。
# 见 revisions/accepted/2026-10-29-alternatives-criterion-1-10.md。
# 1.11（负空间形状，2026-11-11 新增）同样只由本脚本判定：`implemented/simplification/` 的简化记录
# 必须写清「什么条件下把删掉的东西装回来」（围栏外 `## Reintroduction conditions`），
# 且一旦写了 `## Removed surface`，就必须给出一行**检索收据**（`rg` / `grep` / `git grep`）——
# 「删代码前先搜消费者」不能只在散文里宣称（常载命约 3）。看守面同样由 A1/A4 承担。
#
# 设计快照（为何是 bash、为何一个脚本）：
# - 语言：bash 与 ponygo CLI 同源（单文件、零依赖铁律，见 notes/
#   implemented/architecture/2026-08-30-single-file-zero-dependency-cli.md）。
#   ponygo 是栈无关元框架，实例可能是任意语言——只有 bash 是装了 ponygo 就
#   保证存在的运行时。DSH 用 TS 是因为其本身就是 Node monorepo，工具链现成；
#   两种定位的正确分岔，非能力差异。
# - 合并一脚本：DSH 拆 format/classification 两个 gate 是服务其门禁矩阵的粒度
#   （分开挂钩子/CI、独立 spec）；ponygo 的真源合一（maturity-ladder §5 一张表），
#   且本脚本的消费者是 write-adr 的"写一条验证一次"自证步——单出口优于双出口。
#   未来实例升 L2 建门禁矩阵时再拆分，YAGNI。
#
# 语义边界（P6 诚实条款）：本脚本只锁**机械可查的影子**——路径两轴、文件名、
# 日期合法性、Status 与目录一致、骨架标题与 lifecycle 匹配、必含备选节（1.10）。
# 不判"implemented 内容是否真的已落地"（真实性）与"多类是否该拆条"
# （分类）——这两者是语义判断，靠 review + write-adr 校准样例。
#
# 对齐契约（2026-11-09 改准，原文「1.1–1.9 逐项对齐」已不成立）：
#   1.1–1.8：与 CLI 的 verify_ladder 逐项对齐（两道面同判、同文案关键字）；
#   1.9：**只部分对齐**——本脚本只判 1.9a（`docs/AGENTS.md` 存在，且仅无参整树模式）。
#         1.9b（根 `AGENTS.md` 是否链到 `docs/AGENTS.md`，条件于 `ai-surface: on`）与
#         1.9c（包文档覆盖）**只由 CLI 的 verify_ladder 判定**（`ponygo status` 与 `ponygo audit`
#         共用同一函数、都报 1.9 FAIL——不是只有 status 才判，勿低估判定面）：
#         它们要读 meta.yaml 开关 + 扫描包目录，属实例状态而非单条 ADR 的格式。
#         故 `A1/A4 绿 ≠ 1.9b PASS`——本地/远端门只证明 ADR 格式与归档封印，不证明 AI 常载入口完好。
#   1.10：只在本脚本实现（CLI 不复刻，P9 一份判据一份实现）。
#   1.11：只在本脚本实现（同上；负空间形状是**单条记录的形状**判据，不是实例状态）。
# 若发现 1.1–1.8 行为不一致，以 maturity-ladder §5 判据真源为准并回改两者。
# ============================================================
set -u

# ---------- 参数解析：--json 是**载体开关**（不改判定、不改退出码） ----------
VN_JSON=0
VN_ARGS=()
for vn_a in "$@"; do
  case "$vn_a" in
    --json) VN_JSON=1 ;;
    *) VN_ARGS+=("$vn_a") ;;
  esac
done
set -- ${VN_ARGS[@]+"${VN_ARGS[@]}"}
VN_MODE="tree"
[ $# -gt 0 ] && VN_MODE="files"

NOTES_DIR=".agents/notes"
BASELINE_PATH=".meta/notes-baseline.json"
LIFECYCLES="proposed implemented rejected archived"
CLASSES="feature bug-fix simplification architecture process testing"

# ---------- 违例结构化收集（判据号 / 位置 / 明细 / 指纹 四件套） ----------
# 收集与渲染分离：基线豁免必须在**判定之后、渲染之前**生效（豁免项不打印 FAIL，
# 否则「exit 0 + 横幅全部通过」与「上方一行 FAIL」自相矛盾，看输出的人只会更迷惑）。
V_CRIT=(); V_FILE=(); V_DETAIL=(); V_BASE=(); V_FP=(); V_ORDER=()

# sha256 先探测 sha256sum，再探测 shasum -a 256（零依赖；两者皆无 → 需要指纹时 fail-closed）
VN_SHA=""
if command -v sha256sum >/dev/null 2>&1; then
  VN_SHA=sha256sum
elif command -v shasum >/dev/null 2>&1; then
  VN_SHA=shasum
fi
vn_sha() { # stdin → 64hex
  { if [ "$VN_SHA" = "shasum" ]; then shasum -a 256; else sha256sum; fi; } | awk '{print $1}'
}

# detail_key：契约 §1.1.4 的规范化（CRLF→LF、剥首尾空白、连续空白折叠为单个半角空格）
vn_detail_key() {
  printf '%s' "$1" | tr -d '\r' | tr '\n\t' '  ' \
    | sed -e 's/[[:space:]][[:space:]]*/ /g' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

# 判据号排序键：点分字段按**数值**（1.3 < 1.10 < 1.11），每段零填充到 3 位后当字符串比
vn_crit_key() {
  local s="$1" out="" seg n=0
  local IFS='.'
  for seg in $s; do
    case "$seg" in
      ''|*[!0-9]*) out="${out}${out:+.}${seg}" ;;
      *) n=$((10#$seg)); out="${out}${out:+.}$(printf '%03d' "$n")" ;;
    esac
  done
  printf '%s' "$out"
}

vfail() { # <判据号> <文件（可空：目录级/实例级判据）> <明细>
  local i="${#V_CRIT[@]}" c="$1" f="$2" d="$3"
  V_CRIT[$i]="$c"; V_FILE[$i]="$f"; V_DETAIL[$i]="$d"; V_BASE[$i]=0
  V_FP[$i]=""
  if [ -n "$VN_SHA" ]; then
    V_FP[$i]=$(printf '%s\t%s\t%s' "$c" "$f" "$(vn_detail_key "$d")" | vn_sha)
  fi
  return 0
}

# JSON 字符串转义（零依赖；值经环境变量传入，避免 awk -v 的转义二次解释与 ARGV 当文件名）
vn_jesc() { # <任意字符串> → JSON 安全内容（不含外层引号）
  VN_JESC_IN="$1" awk 'BEGIN{
    s = ENVIRON["VN_JESC_IN"]
    gsub(/\\/, "\\\\", s); gsub(/"/, "\\\"", s)
    gsub(/\t/, "\\t", s); gsub(/\r/, "\\r", s); gsub(/\n/, "\\n", s)
    printf "%s", s
  }'
}

# ---------- 存量基线读取（§2.1 格式 / §3.2 状态机；单点判定，供本脚本与 adopt 共用口径） ----------
# 解析纪律：
# - **容忍缩进/换行差异**（有人用 json 工具重排过文件不算损坏——契约只看 schema 语义），
# - **不容忍**：顶层键集/键序漂移、schema 漂移、version≠1、日期不可解析、entries 对象缺键/多键、
#   指纹非 64hex。任一命中 → corrupt → 上层 exit 2（fail-closed，绝不猜一份"大概能用"的基线）。
# 实现取巧：§2.1 的值域里没有空格（路径按 / 分隔且 1.6 限 yyyy-mm-dd-topic.md、判据号是数字、
# 指纹是 hex、时间戳无空格），故先整体去掉空白再单行严格匹配——零依赖且不会误吞多行对象。
B_STATE="absent"; B_EXPIRES=""; B_N=0; B_FPSET=" "; B_GEN=""
baseline_read() {
  B_STATE="absent"; B_EXPIRES=""; B_N=0; B_FPSET=" "; B_GEN=""
  [ -f "$BASELINE_PATH" ] || return 0
  local c="" objs="" obj f cc fp n_obj=0 n_all=0 today=""
  c=$(tr -d ' \t\r\n' < "$BASELINE_PATH" 2>/dev/null) || c=""
  [ -n "$c" ] || { B_STATE="corrupt"; return 0; }
  if ! printf '%s' "$c" | grep -Eq '^\{"schema":"ponygo\.notes-baseline/1","version":1,"generated_at":"[^"]+","expires_at":"[^"]+","framework_ref":"[^"]*","previous":\{"generated_at":(null|"[^"]*"),"entries":[0-9]+\},"delta":\{"added":[0-9]+,"dropped":[0-9]+\},"entries":\[(\]|\{[^{}]*\}(,\{[^{}]*\})*\])\}$'; then
    B_STATE="corrupt"; return 0
  fi
  B_GEN=$(printf '%s' "$c" | sed -e 's/^{"schema":"ponygo\.notes-baseline\/1","version":1,"generated_at":"//' -e 's/","expires_at".*//')
  B_EXPIRES=$(printf '%s' "$c" | sed -e 's/.*"expires_at":"//' -e 's/","framework_ref".*//')
  # 无 GNU date ⇒ 无法机械判定到期日 ⇒ 无法判定（fail-closed，不假设基线还有效）
  [ "$DATE_OK" = "1" ] || { B_STATE="corrupt"; return 0; }
  case "$B_EXPIRES" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ;;
    *) B_STATE="corrupt"; return 0 ;;
  esac
  date -d "$B_EXPIRES" >/dev/null 2>&1 || { B_STATE="corrupt"; return 0; }
  date -d "$B_GEN" >/dev/null 2>&1 || { B_STATE="corrupt"; return 0; }
  # entries：每个对象必须恰为 file→criterion→fingerprint 三键（缺键/多键/坏指纹都算损坏）
  objs=$(printf '%s' "$c" | grep -oE '\{"file":"[^"]*","criterion":"[^"]*","fingerprint":"[0-9a-f]{64}"\}')
  n_all=$(printf '%s' "$c" | grep -oF '{"file":' | wc -l | tr -d ' \t')
  n_obj=$(printf '%s' "$objs" | grep -cE '^{"file":' 2>/dev/null || true)
  n_obj=${n_obj:-0}
  [ "$n_all" = "$n_obj" ] || { B_STATE="corrupt"; return 0; }
  while IFS= read -r obj; do
    [ -n "$obj" ] || continue
    f=$(printf '%s' "$obj" | sed -e 's/^{"file":"//' -e 's/","criterion":.*//')
    cc=$(printf '%s' "$obj" | sed -e 's/.*","criterion":"//' -e 's/","fingerprint":.*//')
    fp=$(printf '%s' "$obj" | sed -e 's/.*","fingerprint":"//' -e 's/"}$//')
    # 缺键/多键/坏指纹（含上面 sed 未命中导致空值）一律损坏：绝不让空指纹变成"匹配一切"的豁免。
    # 注意：`file` **允许为空串**——1.3/1.4/1.9 是目录级/实例级判据，没有文件位（契约 §1.3 的
    # file 字段同步为空串），这类存量违例必须能入册，否则整树类违例永远冻结不进基线。
    [ -n "$cc" ] || { B_STATE="corrupt"; return 0; }
    printf '%s' "$fp" | grep -Eq '^[0-9a-f]{64}$' || { B_STATE="corrupt"; return 0; }
    B_FPSET="$B_FPSET$fp "
    B_N=$((B_N+1))
  done <<< "$objs"
  [ "$B_N" = "$n_all" ] || { B_STATE="corrupt"; return 0; }
  [ -n "$B_GEN" ] && [ -n "$B_EXPIRES" ] || { B_STATE="corrupt"; return 0; }
  today=$(date '+%Y-%m-%d')
  if [ "$B_EXPIRES" \< "$today" ]; then B_STATE="expired"; else B_STATE="ok"; fi
  return 0
}

# ---------- 机读出口（§1.3）：单行 JSON；人类行一律已改道 stderr ----------
vn_json_line() { # <exit 码>
  local code="$1" i=0 n=${#V_CRIT[@]} nb=0 nn=0 sep="" viol="" bs=""
  for ((i=0; i<n; i++)); do [ "${V_BASE[$i]}" = "1" ] && nb=$((nb+1)); done
  nn=$((n - nb))
  V_ORDER=()
  if [ "$n" -gt 0 ]; then
    # 分隔符刻意用 **US（0x1F，非 IFS 空白）**而不是 TAB：TAB 属 bash 的 IFS-whitespace，
    # `IFS=$'\t' read` 会把**前导**分隔符折叠成空 → `file` 为空的违例（1.3/1.4/1.9 这类
    # 目录级/实例级判据）首列被吞、`$((10#))` 得空串直接打死管道 → 整条违例从 violations[]
    # 里消失，而 counts.total 仍按收集数报 → 恒等式破裂（对抗审核 BLOCKING#1）。
    while IFS= read -r i; do [ -n "$i" ] && V_ORDER+=("$i"); done < <(
      for ((i=0; i<n; i++)); do
        printf '%s\037%s\037%s\037%06d\n' "${V_FILE[$i]}" "$(vn_crit_key "${V_CRIT[$i]}")" "${V_FP[$i]}" "$i"
      done | LC_ALL=C sort | while IFS=$'\037' read -r _vf _vc _vp _vi; do printf '%s\n' "$((10#$_vi))"; done
    )
  fi
  for i in ${V_ORDER[@]+"${V_ORDER[@]}"}; do
    viol="$viol$sep{\"criterion\":\"$(vn_jesc "${V_CRIT[$i]}")\",\"file\":\"$(vn_jesc "${V_FILE[$i]}")\",\"detail\":\"$(vn_jesc "${V_DETAIL[$i]}")\",\"fingerprint\":\"${V_FP[$i]}\",\"baselined\":$( [ "${V_BASE[$i]}" = "1" ] && echo true || echo false )}"
    sep=","
  done
  case "$B_STATE" in
    absent) bs="\"expires_at\":null,\"entries\":0" ;;
    corrupt) bs="\"expires_at\":null,\"entries\":0" ;;
    *) bs="\"expires_at\":\"$(vn_jesc "$B_EXPIRES")\",\"entries\":$B_N" ;;
  esac
  printf '{"schema":"ponygo.verify-note/1","command":"verify-note","mode":"%s","criteria":"1.1-1.11","violations":[%s],"counts":{"total":%d,"baselined":%d,"new":%d},"baseline":{"path":"%s","state":"%s",%s},"exit":%d}\n' \
    "$VN_MODE" "$viol" "$n" "$nb" "$nn" "$BASELINE_PATH" "$B_STATE" "$bs" "$code"
}

vn_fail_closed() { # <因由> → 人读 stderr（--json 时改由 JSON 承载）+ exit 2
  if [ "$VN_JSON" = "1" ]; then
    vn_json_line 2
  else
    printf 'verify-note: %s（fail-closed：不猜、不放行）\n' "$1" >&2
  fi
  exit 2
}

# 渲染一条 FAIL（与历史输出逐字节同形：`FAIL  <判据号> <文件>：<明细>`；
# 目录级/实例级判据无文件位 → `FAIL  <判据号> <明细>`）
vn_render_fail() { # <下标>
  local i="$1"
  if [ -n "${V_FILE[$i]}" ]; then
    printf 'FAIL  %s %s：%s\n' "${V_CRIT[$i]}" "${V_FILE[$i]}" "${V_DETAIL[$i]}" >&2
  else
    printf 'FAIL  %s %s\n' "${V_CRIT[$i]}" "${V_DETAIL[$i]}" >&2
  fi
}

[ -d "$NOTES_DIR" ] || { echo "verify-note: 无 $NOTES_DIR（先 ponygo init）" >&2; exit 1; }

# DATE_OK：GNU date 可用才机械判日期，否则降级"靠 review"（与 CLI 同款诚实条款）
DATE_OK=0
date -d @0 '+%Y' >/dev/null 2>&1 && DATE_OK=1

# 基线在判定之前读：损坏时**不判违例**（§3.2 fail-closed），避免给出任何"看起来通过"的输出
baseline_read
[ "$B_STATE" = "corrupt" ] && vn_fail_closed "存量基线 $BASELINE_PATH 损坏或无法判定（见契约 §2.1）→ 重跑 'ponygo upgrade adopt' 重建，或手工修正后重试"
# 需要指纹的两种情形（读基线做豁免 / --json 机读面）都必须有 sha256 工具，否则无法保证口径
if [ "$B_STATE" != "absent" ] || [ "$VN_JSON" = "1" ]; then
  [ -n "$VN_SHA" ] || vn_fail_closed "缺少 sha256 工具（需要 sha256sum 或 shasum -a 256）"
fi

# 实例扩展 class（classes.local，与 CLI extra_classes 同构）
extra_classes() {
  [ -f "$NOTES_DIR/classes.local" ] || return 0
  sed 's/\r$//' "$NOTES_DIR/classes.local" | grep -vE '^[[:space:]]*(#|$)' | grep -E '^[a-z0-9][a-z0-9-]*$'
}

# 1.3 顶层目录 ⊆ 四态封闭集
while IFS= read -r d; do
  [ -n "$d" ] || continue
  case " $LIFECYCLES " in *" $d "*) ;; *) vfail "1.3" "" "顶层目录越界：$d" ;; esac
done < <(find "$NOTES_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null)

# 1.4 二级目录 ⊆ 六类封闭集 ∪ classes.local
classes_all=" $CLASSES $(extra_classes | tr '\n' ' ') "
while IFS= read -r d; do
  [ -n "$d" ] || continue
  case "$classes_all" in *" $d "*) ;; *) vfail "1.4" "" "class 越界：$d" ;; esac
done < <(find "$NOTES_DIR" -mindepth 2 -maxdepth 2 -type d -exec basename {} \; 2>/dev/null)

# ---------- 判定辅助（CLI 侧有同名同语义实现，两面必须逐项一致） ----------
# 理由正文归一（判据 1.7）：剥掉 ASCII 空白/标点、em dash、全角空格与 CJK 标点闭集后，剩下的才是"正文"。
# 为什么每个字符用独立 -e 而不是 `[。，、]` 字符组：C locale 下字符组按**字节**匹配，会连带剥掉恰好
# 共享字节的正常汉字（`突` = E7 AA 81 含 0x81，而 `、` = E3 80 81 也含 0x81）——逐序列替换是精确的
# UTF-8 序列匹配，不误伤正文。闭集见契约 §D1；新增标点须两侧（本脚本 + CLI 影子）同时加。
reason_body_of() {
  printf '%s' "$1" | tr -d '[:space:][:punct:]' \
    | sed -e 's/—//g' -e 's/　//g' \
          -e 's/，//g' -e 's/。//g' -e 's/、//g' -e 's/；//g' -e 's/：//g' \
          -e 's/！//g' -e 's/？//g' -e 's/「//g' -e 's/」//g' -e 's/『//g' -e 's/』//g' \
          -e 's/（//g' -e 's/）//g' -e 's/【//g' -e 's/】//g' -e 's/《//g' -e 's/》//g' \
          -e 's/…//g' -e 's/～//g' -e 's/·//g' -e 's/﹁//g' -e 's/﹂//g' \
          -e 's/“//g' -e 's/”//g' -e 's/‘//g' -e 's/’//g'
}

# 围栏感知的标题探测（判据 1.8 / 1.10）：只在**围栏外**认 `## ` 标题。
# 围栏口径（契约 §D2）：以「可选缩进 + ```」开头的行**切换**围栏态（```text / ```bash 等语言标记同样
# 是围栏行）；未闭合的围栏 → 其后全部视为围栏内（fail-closed：不认里面的标题，宁可误拒不可假绿）。
# 用法：heading_outside_fence <文件> <ERE（不含 ^ 锚）>；返回 0 = 围栏外存在该标题。
# 实操陷阱（写 ADR 时最常见的一次踩坑）：正文里想**引用**三反引号时，不要让那三个字符出现在行首
#   （含缩进行首）——围栏态只看"行首可选缩进 + ```"，一行以它开头就会被当成围栏开启；若之后没有配对
#   的关闭行，其后**所有真标题**都落进围栏内 → 该条 ADR 会自判 1.8 缺 ## Decision + 1.10 缺
#   ## Alternatives considered（看起来像门禁误报，其实是文档里多了一行行首反引号）。安全写法：行内引用
#   （前后加文字）或加前缀字符（如 `> ` / `- ` 之外的文字前缀），别让三个反引号起行。
# 未识别的边界（诚实条款）：4 空格缩进式代码块、HTML 注释里的标题仍会被认（只认 ``` 围栏，见契约）；
# 需要更严时由 review 兜，本脚本不冒充全 Markdown 解析器。
heading_outside_fence() {
  awk -v pat="$2" '
    /^[[:space:]]*```/ { infence = !infence; next }
    infence { next }
    $0 ~ ("^" pat) { found = 1 }
    END { exit(found ? 0 : 1) }
  ' "$1" 2>/dev/null
}

check_one() { # $1 = 决策文件路径
  local f="$1" b rel lc slashes st stline rest sep reason_body d8
  b="${f##*/}"
  [ "$b" = "README.md" ] || [ "$b" = "AGENTS.md" ] && return 0
  rel="${f#"$NOTES_DIR"/}"
  [ "$rel" = "$f" ] && rel="$f"
  lc="${rel%%/*}"
  # 1.5 深度：恰好 {lifecycle}/{class}/ 两级
  slashes="${rel//[!\/]/}"
  [ "${#slashes}" -eq 2 ] || { vfail "1.5" "$f" "未恰好位于 {lifecycle}/{class}/ 两级"; return 0; }
  # 1.6 文件名 + 日期合法性
  if ! printf '%s\n' "$b" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}-.+\.md$'; then
    vfail "1.6" "$f" "文件名不符 yyyy-mm-dd-topic.md"
    return 0
  fi
  if [ "$DATE_OK" = "1" ]; then
    d8="${b:0:10}"
    date -d "$d8" >/dev/null 2>&1 || vfail "1.6" "$f" "日期不合法（$d8）"
  fi
  # 1.7 Status 首词与所在 lifecycle 一致（archived 允许 implemented/archived）
  # stline = Status: 行剥标记后的原文（供下面的 rejected 理由判据复用，避免二次读文件）
  stline=$(sed -n 's/\r$//;s/^Status:[[:space:]]*//p' "$f" 2>/dev/null | head -n1)
  st=$(printf '%s\n' "$stline" | awk '{print $1}')
  # 容忍粘写冒号的理由分隔符：`Status: rejected: <理由>` 的首词是 `rejected:`——剥掉尾随冒号
  # 再与目录比，否则「冒号分隔」这种写法会被误判成 Status 漂移（`—` / `-` 两种分隔符要求留空格，
  # 无空格时仍按 Status 漂移拒绝——fail-closed，不会静默放行）。
  st="${st%:}"
  if [ -z "$st" ]; then
    vfail "1.7" "$f" "缺 Status: 行"
  elif [ "$lc" = "archived" ]; then
    [ "$st" = "implemented" ] || [ "$st" = "archived" ] || vfail "1.7" "$f" "archived 下 Status 应为 implemented/archived，实得 $st"
  elif [ "$st" != "$lc" ]; then
    vfail "1.7" "$f" "Status($st) 与目录($lc) 不一致"
  fi
  # 1.7（判据补强）rejected 必须带一行理由：`rejected` 之后须有分隔符（`—` / `-` / `:`）
  # 且剥掉分隔符与空白后**剩余正文**至少 2 个非空白字节。为什么是硬判据：否决理由是这条记录唯一不可再生的信息——
  # 没有理由的 rejected 只是"有人不同意"，重新面对同一岔路时既不能避免重开争执，
  # 也不能解释现状为何是现在这样（状态轴有位置、没有内容）。
  # 豁免：`archived/`（冻结，与 1.8/1.10 同口径）、README.md / AGENTS.md（函数入口早退）、
  # `*.zh.md`（双语配对，随母语版同批补齐，不独立判——与 1.10 同口径）。
  # 计数口径（Wave-2 §D1）：剥掉**分隔符本身**、空白、ASCII 标点、em dash 与 **CJK 标点**闭集后，
  # 剩余正文 ≥2 字节才算理由。`Status: rejected ——`（纯分隔符）与 `Status: rejected — 。`（纯中文标点）
  # 都必须拒——分隔符/标点不是理由。CJK 标点的剥离实现在 reason_body_of（逐 UTF-8 序列，不误伤汉字）。
  if [ "$st" = "rejected" ] && [ "$lc" != "archived" ]; then
    case "$b" in
      *.zh.md) ;;
      *)
        rest="${stline#"$st"}"
        rest="${rest#"${rest%%[![:space:]]*}"}"   # 剥前导空白（纯字节操作，不依赖 locale）
        sep=0
        case "$rest" in
          —*|--*|-*|:*) sep=1 ;;
        esac
        if [ "$sep" = "1" ]; then
          case "$rest" in
            —*) rest="${rest#—}" ;;
            -*) rest="${rest#-}"; rest="${rest#-}" ;;
            :*) rest="${rest#:}" ;;
          esac
        fi
        # 正文 = 剥掉 ASCII 空白/标点（含 - 与 :）与 em dash 之后的剩余字节。
        # `——` / `--` / `:` / `?!` 之类的"纯分隔符/纯标点"在这里归零 → 缺一行理由。
        reason_body=$(reason_body_of "$rest")
        if [ "$sep" != "1" ] || [ "$(printf '%s' "$reason_body" | wc -c | tr -d ' ')" -lt 2 ]; then
          vfail "1.7" "$f" "rejected 缺一行理由（Status: rejected — <为何否决>）"
        fi
        ;;
    esac
  fi
  # 1.8 骨架标题与 lifecycle 匹配
  # implemented/：现在时 `## Decision` 必须在场（迁移即改写——proposed→implemented 的
  # 那次变更必须把 `## Proposal` 改写为 `## Decision`，否则正文层状态轴失真）；
  # 并禁提案时代标题——英文等价与**中文等价**都算（中文标题同样是提案态残留：
  # 标题语言不该成为绕过判据的后门）。中文清单：提案/计划/迁移计划/验收标准/验收/风险/待办。
  # 匹配口径（2026-11-09 收口）：英文按**边界**匹配（标题词后有空白或行尾）；中文按**前缀**匹配
  # ——中文标题无词间空格，边界匹配会让 `## 验收清单` / `## 风险与缓解` / `## 待办事项` 等复合词
  # 全部放行（等于开个洞）。前缀匹配的代价：`## 计划性…` 这类以禁词开头的标题也一并拒（fail-closed，可接受）。
  # 豁免：archived/ 冻结（详见 `.agents/notes/README.md` 格式契约与 write-adr 技能）。
  # 围栏口径（Wave-2 §D2）：全部标题判定走 heading_outside_fence——**围栏内的标题不算在场**，
  # 否则把 `## Decision` 塞进示例代码块即可骗过 1.8/1.10（Wave-1 遗留的假绿面）。
  case "$lc" in
    implemented)
      heading_outside_fence "$f" '## Decision([[:space:]]|$)' \
        || vfail "1.8" "$f" "implemented 缺 ## Decision（迁移即改写：现在时 Decision 必须在场）"
      heading_outside_fence "$f" '## (Proposal|Plan|Migration plan|Acceptance criteria)([[:space:]]|$)' \
        && vfail "1.8" "$f" "implemented 含提案时代标题（## Proposal/## Plan/## Migration plan/## Acceptance criteria）"
      heading_outside_fence "$f" '## (提案|计划|迁移计划|验收标准|验收|风险|待办)' \
        && vfail "1.8" "$f" "implemented 含提案时代标题（中文提案时代标题：## 提案/## 计划/## 迁移计划/## 验收标准/## 验收/## 风险/## 待办，按前缀匹配含复合词）"
      ;;
    proposed|rejected)
      heading_outside_fence "$f" '## Proposal([[:space:]]|$)' || vfail "1.8" "$f" "$lc 缺 ## Proposal"
      heading_outside_fence "$f" '## Decision([[:space:]]|$)' && vfail "1.8" "$f" "$lc 含现在时 ## Decision（提案伪装成决定）" ;;
  esac
  # 1.10 必含 ## Alternatives considered（2026-10-29 起为硬判据，不是 WARN）
  # 为何是硬判据：备选与落选理由是"非平凡决策"的实质内容——只写 Decision 的 ADR 会退化为
  # 事后记录，重新面对同一岔路时答不出"为什么不选另一条"；契约本就在 .agents/notes/README.md
  # 里，只是此前没有机械看守（覆盖缺口见 implemented/process/2026-10-29-forced-adr-gate-wiring.md）。
  # 豁免口径：archived/ 冻结豁免（与 1.8 同口径，保持归档时原貌）；README.md / AGENTS.md 在
  # 函数入口早退；*.zh.md（双语配对）豁免——译文随母语版同批补齐，不独立判。
  case "$b" in
    *.zh.md) ;;
    *)
      if [ "$lc" != "archived" ]; then
        heading_outside_fence "$f" '## Alternatives considered([[:space:]]|$)' \
          || vfail "1.10" "$f" "缺 ## Alternatives considered（非平凡决策必须写明被否决的备选与理由）"
      fi
      ;;
  esac
  # 1.11 负空间形状（简化记录专用）：只锁 implemented/simplification/，不外溢到其它 class。
  # 为什么是硬判据：删除是**不可逆**的治理动作。只写「删了什么」而不写「什么条件下装回来」，
  # 下一个人面对同一需求时只能靠考古重建；只写「已全树清理」而不留检索收据，
  # 「零残留」就是一句无法复核的宣称（常载命约 3：搜索零残留才是验收）。
  # 豁免口径与 1.8/1.10 完全一致：archived/ 冻结豁免、README/AGENTS 入口早退、*.zh.md 双语配对不独立判。
  # 围栏口径：`## Reintroduction conditions` 与 1.8/1.10 同样**围栏内不算在场**（fail-closed）；
  #   检索收据行则**围栏内外都算**——命令本来就常写在代码块里，收据的载体是人写的命令行。
  # 判据号不出现在成功横幅里（见文件末尾注释），失败时以 `FAIL  1.11 …` 前缀出现。
  case "$b" in
    *.zh.md) ;;
    *)
      case "$rel" in
        implemented/simplification/*)
          heading_outside_fence "$f" '## Reintroduction conditions([[:space:]]|$)' \
            || vfail "1.11" "$f" "implemented/simplification 缺 ## Reintroduction conditions（写清什么条件下把删掉的东西装回来，别留「以后可能用得上」）"
          if heading_outside_fence "$f" '## Removed surface([[:space:]]|$)' \
             && ! grep -Eq '(^|[^[:alnum:]_])(rg|grep)([^[:alnum:]_]|$)' "$f" 2>/dev/null; then
            vfail "1.11" "$f" "含 ## Removed surface 但缺检索收据行（须有一行 rg / grep / git grep 检索命令，证明「搜索零残留」）"
          fi
          ;;
      esac
      ;;
  esac
  return 0
}

if [ $# -gt 0 ]; then
  for f in "$@"; do check_one "$f"; done
else
  while IFS= read -r -d '' f; do check_one "$f"; done \
    < <(find "$NOTES_DIR" -type f -name '*.md' -print0 2>/dev/null)
  # 1.9 文档有家（v2.0，整树模式才判）：docs/AGENTS.md 是文档标准的家（agent 自动加载）。
  # 与 1.1-1.8 同属 L1 判据；docs/AGENTS.md 由 ponygo init 骨架播种。
  [ -f "docs/AGENTS.md" ] || vfail "1.9" "" "缺文档标准家 docs/AGENTS.md（agent 自动加载）→ 补 docs/AGENTS.md（tier 分类 + 写作规则 + slop checklist）"
fi

# ---------- 基线豁免（§3.2）：状态 ok 时按 fingerprint 命中即豁免，不计 FAIL ----------
BASELINED_N=0; NEW_N=0; VN_CODE=0
if [ "$B_STATE" = "ok" ]; then
  for i in ${V_CRIT[@]+"${!V_CRIT[@]}"}; do
    # 空指纹绝不参与匹配（否则 `*"  "*` 会命中一切 = 假绿豁免）；fprint 缺失时已在读取期 fail-closed
    [ -n "${V_FP[$i]}" ] || continue
    case "$B_FPSET" in
      *" ${V_FP[$i]} "*) V_BASE[$i]=1; BASELINED_N=$((BASELINED_N+1)) ;;
    esac
  done
fi
NEW_N=$(( ${#V_CRIT[@]} - BASELINED_N ))

# 人类行只在**非 --json** 时输出：--json 的契约是「stdout 只有一行 JSON」，而冻结验收
# （T-U6-19b：整树违例 + --json → 直接 json.load 合并流）进一步要求 stderr 也不得掺人类行——
# 否则两种载体在同一进程里各说一遍，机读方必须先把 JSON 从散文里挖出来（正是 --json 要消灭的事）。
# 违例与基线状态在 JSON 里各自有字段（violations[] / baseline.state），不靠散文承载事实。
if [ "$VN_JSON" != "1" ]; then
  # 过期 WARN：即便零违例也要打印（E-05：exit 0 + WARN 照打），否则"基线悄悄失效"没人看得见
  if [ "$B_STATE" = "expired" ]; then
    printf 'verify-note: [WARN] 存量基线已过期（expires_at=%s）→ 全部违例重回生效；修法：重跑 ponygo upgrade adopt 重新冻结\n' "$B_EXPIRES" >&2
  fi
  # FAIL 行按**收集顺序**渲染（与历史输出逐字节同形，仅跳过被豁免项）
  for i in ${V_CRIT[@]+"${!V_CRIT[@]}"}; do
    [ "${V_BASE[$i]}" = "1" ] && continue
    vn_render_fail "$i"
  done
fi

if [ "$NEW_N" -eq 0 ]; then VN_CODE=0; else VN_CODE=1; fi

if [ "$VN_JSON" = "1" ]; then
  vn_json_line "$VN_CODE"
elif [ "$VN_CODE" -eq 0 ]; then
  # 成功横幅刻意**不写**「1.11」编号串：验收契约要求正例输出不得含该串（否则「本次没报 1.11 违例」
  # 与「横幅里出现 1.11」无法机械区分）。判据名写在括号里，失败时按 `FAIL  1.11 …` 前缀出现。
  if [ "$BASELINED_N" -gt 0 ]; then
    echo "verify-note: 全部通过（机械影子 1.1–1.10 + 负空间形状判据；真实性/分类/备选质量靠 review）（存量基线豁免 ${BASELINED_N} 条）"
  else
    echo "verify-note: 全部通过（机械影子 1.1–1.10 + 负空间形状判据；真实性/分类/备选质量靠 review）"
  fi
else
  echo "verify-note: 未通过（见上方 FAIL 项；逐项修复后重跑）" >&2
fi
exit "$VN_CODE"
