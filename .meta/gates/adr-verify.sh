#!/usr/bin/env bash
# ============================================================
# adr-verify.sh —— 暂存区 ADR 格式门（门禁资产 A1）
#
# 用法：
#   bash .meta/gates/adr-verify.sh            # 无参 = 校验「暂存区里改动的 ADR」
#   bash .meta/gates/adr-verify.sh <rel>...   # 带参 = 校验指定相对路径（相对仓库根）
#
# 退出码：0 = 放行；非零 = 拒绝（pre-commit 会把非零翻译成"提交被拒"）。
#
# 语义边界（P6 诚实条款）：本门**不自己判** ADR 格式——判定真源是
# `.agents/skills/write-adr/verify-note.sh`（maturity-ladder §5 的 1.1–1.10 机械影子）。
# 本门只多做三件它做不到的事：
#   1) R6 TOCTOU：verify-note 读**工作区**，而 pre-commit 的输入是**暂存区文件名**。
#      两者不一致时（staged 后又在工作区改过），校验的就不是将要提交的那份字节。
#      故先做「暂存区 blob vs 工作区」比对，不一致 → 直接拒绝，要求先 git add。
#   2) R7 覆盖面：用 `--diff-filter=ACMRD`（含 R 重命名，`git mv` 不能绕过；含 D 删除，
#      见 U3：删除必须同提交入册简化记录，否则 `die` 拒绝），并豁免 README.md / AGENTS.md
#      （治理契约载体，非决策记录）。
#   3) F9 非普通文件：symlink（120000）/ gitlink（160000）ADR 一律拒绝——否则"被校验的字节"
#      可以指向工作区外内容，判定面被换掉。此检查必须排在 EOL 归一兜底之前（见 §4a 注释）。
# 为什么不在本门里重写 1.1–1.10：一份判据两份实现必然漂移（P9），
# 且 `ponygo gate adr` 子命令已按同一理由被否决（见 ADR 的 Alternatives R-新子命令）。
#
# 只读纪律：本脚本**不写仓库任何文件**。临时文件一律 `mktemp -d`，`trap` 清理。
# 空场景一律放行（exit 0）：非 git 仓 / 无 .agents/notes / 无暂存 ADR 改动——
# 门禁只对"真的落了 ADR"这一事实负责，不替实例决定要不要写 ADR。
# ============================================================
set -u

PROG=adr-verify
MARK='ADR 有未暂存改动，请先 git add'

note() { printf '[%s] %s\n' "$PROG" "$*"; }
die() {
  printf '[%s] FAIL：%s\n' "$PROG" "$*" >&2
  exit 1
}
# 归档封印的评估结果（在**任何 skip 之前**算好；输出留到 ADR 段之后打印，见 archive_finish）
ARCHIVE_GATE=".meta/gates/archive-verify.sh"
ARCHIVE_DONE=0
ARCHIVE_RC=0
ARCHIVE_OUT=""

# 收口：打印归档段 → 归档未通过则拒绝（fail-closed），否则按调用方的退出码走。
# 顺序语义：ADR 段永远在前、归档段永远在后（本地层两段既有顺序不变）；但**判定**发生在
# 早期（archive_probe），所以"这次没有暂存 ADR"不能成为绕过封印的门。
archive_finish() {
  if [ "${ARCHIVE_DONE:-0}" = "1" ] && [ -n "${ARCHIVE_OUT:-}" ]; then
    printf '%s\n' "$ARCHIVE_OUT"
  fi
  if [ "${ARCHIVE_DONE:-0}" = "1" ] && [ "${ARCHIVE_RC:-0}" -ne 0 ]; then
    printf '[%s] 拒绝：归档封印未通过（见上：归档件被改动或未封印）→ 恢复原字节，或追加封印（bash .meta/gates/archive-verify.sh seal）后再提交\n' "$PROG" >&2
    exit 1
  fi
  return 0
}

# 归档封印探测（A6 缺失/被清空/被换成不判封印的空壳 → 一律 fail-closed：
# 删掉或掏空一个文件不能把封印从提交窗口里摘掉）
archive_probe() {
  if [ ! -f "$ARCHIVE_GATE" ]; then
    ARCHIVE_OUT="[adr-verify] 拒绝：归档封印门 A6 缺失（$ARCHIVE_GATE）——A6 不可判定 = fail-closed；跑 'ponygo init' 补回"
    ARCHIVE_RC=2
    ARCHIVE_DONE=1
    return 0
  fi
  ARCHIVE_OUT=$(bash "$ARCHIVE_GATE" check 2>&1)
  ARCHIVE_RC=$?
  ARCHIVE_DONE=1
  # 可判定性证据：A6 的 check 输出必须带「归档封印」判定标记（正常恒有——
  # `== 归档封印校验（…）==` / `== 归档封印：通过 ==`）。标记缺失 = 门被清空、或换成了
  # 不判封印的空壳：此时 rc 可能仍是 0，但封印**从未被判定过**——这与"删掉 A6"等价，
  # 同样 fail-closed（否则 `: > .meta/gates/archive-verify.sh` 一句就把判定摘掉了）。
  case "$ARCHIVE_OUT" in
    *归档封印*) ;;
    *)
      if [ -n "$ARCHIVE_OUT" ]; then
        ARCHIVE_OUT="$ARCHIVE_OUT
[adr-verify] 拒绝：归档封印门 A6 的输出不含「归档封印」判定标记（$ARCHIVE_GATE）——不可判定 = fail-closed；跑 'ponygo init' 补回 A6 后重试"
      else
        ARCHIVE_OUT="[adr-verify] 拒绝：归档封印门 A6 未输出任何封印判定（$ARCHIVE_GATE 输出不含「归档封印」判定标记）——不可判定 = fail-closed；跑 'ponygo init' 补回 A6 后重试"
      fi
      ARCHIVE_RC=2
      ;;
  esac
  return 0
}

skip() {
  printf '[%s] 跳过：%s\n' "$PROG" "$*"
  archive_finish
  exit 0
}

# 1) 非 git 仓 → 无暂存区可言，放行（2.4 会另行判"钩子无从挂载"）
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || skip "非 git 仓库"
[ -n "$ROOT" ] || skip "非 git 仓库"
cd "$ROOT" || die "无法进入仓库根：$ROOT"

# 1b) 归档封印（A6）在**任何 skip 之前**评估：删除/移出归档件不产生暂存 ADR 变更，
#     若把 A6 留在末尾（旧实现），"本次没有暂存 ADR" 就成了绕过封印的门（实测缺陷）。
archive_probe

# 2) 无 .agents/notes → 该实例没有决策记录制度，本门不越权造制度
[ -d .agents/notes ] || skip "无 .agents/notes 决策记录目录"

# 3) 判定真源必须在位；缺失 = 安装损坏，fail-closed（不得静默放行）
VERIFY=".agents/skills/write-adr/verify-note.sh"
[ -f "$VERIFY" ] || die "缺判定真源 $VERIFY → 恢复该文件后重跑（ponygo init，或 git checkout -- $VERIFY）"

# README.md / AGENTS.md 是治理契约载体，不是决策记录（同 verify-note 1.5/1.6 豁免）
is_adr() {
  case "$1" in
    *.md) ;;
    *) return 1 ;;
  esac
  case "${1##*/}" in
    README.md | AGENTS.md) return 1 ;;
  esac
  return 0
}

PATHS=()
if [ "$#" -gt 0 ]; then
  # 带参模式：只接受 .agents/notes/ 下的相对路径；其余跳过（避免误伤调用者的宽参）
  for p in "$@"; do
    p=${p#./}
    case "$p" in
      .agents/notes/*) ;;
      *)
        note "忽略非 ADR 路径：$p"
        continue
        ;;
    esac
    is_adr "$p" || {
      note "忽略豁免文件：$p"
      continue
    }
    [ -f "$p" ] || die "指定路径不存在：$p（带参校验要求工作区可见该文件）"
    PATHS+=("$p")
  done
else
  # U3（W2a）：删除决策记录必须**同提交入册**简化记录。
  # 为什么：删除是不可逆的治理动作；只留一个空 diff 等于把「为什么删/什么条件下装回来」
  # 丢给后人考古（常载命约 3 + 判据 1.11）。A1 只判**入册事实**，1.11 的形状仍由真源
  # verify-note.sh 判（P9：一份判据一份实现，本门不复刻）。
  #
  # 两类**不算删除**（否则就是 FALSE_REJECT）：
  #   a) 生命周期迁移：proposed→implemented 用 `git rm` + `git add`（或改写后相似度 <50%）时，
  #      暂存区是 D+A 两个路径，但**同一个 basename** 的新文件已经进 PATHS、照常由真源校验——
  #      "搬了一次家"不是删除（真仓 8edd7cf 就是这种形态）。
  #   b) `*.zh.md` 译文：与 1.7/1.10/1.11 的 zh 口径一致（译文随母语版同批补齐，不独立判）。
  # 归档件（.agents/notes/archived/**）的删除/移出由 A6 封印门（含 manifest 孤儿检测）承担，
  # 本判据只管**非 archived** 的删除，不重复判定。
  # rename 检测兜一层 `--find-renames=50%`：实例侧 diff.renames=false / renameLimit 很小时，
  # 改写幅度大的迁移会被表示成 D+A 而不是 R，上面的 basename 规则就是第二道网。
  DEL_ALL=" "
  ADD_BASE=" "
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    is_adr "$p" || continue
    ADD_BASE="$ADD_BASE${p##*/} "
  done < <(git diff --cached --name-only --find-renames=50% --diff-filter=A -- '.agents/notes/*.md' 2>/dev/null)
  FIRST_DEL=""
  DEL_NEEDED=0
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    is_adr "$p" || continue
    DEL_ALL="$DEL_ALL$p "
    case "$p" in
      .agents/notes/archived/*) continue ;;   # 归档件由 A6 封印门管（含 manifest 孤儿检测）
      *.zh.md) continue ;;                    # 译文不独立判（与 1.7/1.10/1.11 同口径）
    esac
    case "$ADD_BASE" in
      *" ${p##*/} "*) continue ;;             # 同 basename 的新增 = 生命周期迁移，不是删除
    esac
    DEL_NEEDED=$((DEL_NEEDED + 1))
    [ -n "$FIRST_DEL" ] || FIRST_DEL="$p"
  done < <(git diff --cached --name-only --find-renames=50% --diff-filter=D -- '.agents/notes/*.md' 2>/dev/null)
  if [ "$DEL_NEEDED" -gt 0 ]; then
    # 入册载体必须是**真决策记录**：`is_adr` 已排除 README.md/AGENTS.md，另按 zh 口径排除译文
    # （否则往 simplification/ 丢一个 README.md 就能"入册"——那是把门槛换成了目录存在性）。
    SIMPL_NOTE=""
    while IFS= read -r sp; do
      [ -n "$sp" ] || continue
      is_adr "$sp" || continue
      case "$sp" in *.zh.md) continue ;; esac
      SIMPL_NOTE="$sp"
      break
    done < <(git diff --cached --name-only --find-renames=50% --diff-filter=AM -- '.agents/notes/implemented/simplification/*.md' 2>/dev/null)
    if [ -z "$SIMPL_NOTE" ]; then
      die "拒绝：删除决策记录（$FIRST_DEL）必须同提交入册 implemented/simplification/（须含围栏外 ## Reintroduction conditions；若写了 ## Removed surface 还须给一行 rg/grep 检索收据）——移除本身是一次决策"
    fi
    # 语义关联（"这条简化记录讲的是不是这次移除"）不做硬判（P6）：只打一行可复核提示，
    # 让 review 有落点。未提及被删路径时把提示写得更具体（这是最常被漏的那类）。
    if grep -Fq "${FIRST_DEL##*/}" "$SIMPL_NOTE" 2>/dev/null; then
      printf '[%s] WARN 删除决策记录（%s）已入册 %s——语义关联靠 review，建议复核：该记录是否写清了移除范围与复活条件\n' "$PROG" "$FIRST_DEL" "$SIMPL_NOTE" >&2
    else
      printf '[%s] WARN 删除决策记录（%s）已入册 %s，但该记录**未提及**被删路径 %s——建议复核：它是否真是这次移除的简化记录\n' "$PROG" "$FIRST_DEL" "$SIMPL_NOTE" "${FIRST_DEL##*/}" >&2
    fi
  fi
  # 无参模式：暂存区改动的 ADR（ACMRD = 新增/复制/修改/重命名/删除；R7 + U3）
  # 删除项不进 PATHS：内容已不在暂存区，没有可校验的字节（删除入册已在上面判过）。
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    is_adr "$p" || continue
    case "$DEL_ALL" in *" $p "*) continue ;; esac
    PATHS+=("$p")
  done < <(git diff --cached --name-only --find-renames=50% --diff-filter=ACMRD -- '.agents/notes/*.md' 2>/dev/null)
fi

[ "${#PATHS[@]}" -gt 0 ] || skip "无暂存 ADR 变更"

# 4) R6 TOCTOU：暂存字节 vs 工作区字节。不一致 = 校验对象不是将要提交的内容。
TMP=$(mktemp -d) || die "mktemp -d 失败"
trap 'rm -rf "$TMP"' EXIT

drift=0
bad_mode=0
for p in ${PATHS[@]+"${PATHS[@]}"}; do
  if ! git cat-file -e ":$p" 2>/dev/null; then
    printf '[%s] %s：%s（暂存区无该文件；只自查未暂存的新 ADR 请直接跑 bash %s）\n' \
      "$PROG" "$MARK" "$p" "$VERIFY" >&2
    drift=1
    continue
  fi
  git show ":$p" >"$TMP/staged" 2>/dev/null || die "读取暂存区内容失败：$p"
  # 4a) F9：ADR 必须是普通文件（symlink 120000 / gitlink 160000 一律拒绝）。
  # 位置是判据本身的部分：必须早于 cmp 与下面的 EOL 归一兜底——
  # symlink 暂存时 blob = 链接文本、cmp 读工作区 = 目标内容，两者必然不同，
  # 而 `git diff --quiet` 对 symlink 只说"链接自身没改"（无差异）→ 会被兜底当假阳性放过。
  # 实测根因即此，故模式检查排在兜底之前。
  mode=$(git ls-files -s -- "$p" 2>/dev/null | awk '{print $1}' | head -1)
  case "$mode" in
    120000 | 160000)
      printf '[%s] 拒绝：%s 不是普通文件（mode=%s；ADR 必须是普通文件）\n' "$PROG" "$p" "$mode" >&2
      bad_mode=1
      continue
      ;;
  esac
  if cmp -s "$TMP/staged" "$p"; then
    continue
  fi
  # 字节不同还要排除一种假阳性：属性层 EOL 归一（.gitattributes `* text=auto eol=lf`）。
  # `git diff --quiet` 按 clean filter 比较索引与工作区——它说"无差异"，
  # 说明差异只来自归一化而非未暂存编辑。
  if git diff --quiet -- "$p" 2>/dev/null; then
    continue
  fi
  printf '[%s] %s：%s\n' "$PROG" "$MARK" "$p" >&2
  drift=1
done

if [ "$bad_mode" -ne 0 ] || [ "$drift" -ne 0 ]; then
  # 按因给补救（不给一条万能命令）：两类成因的修法完全不同。
  if [ "$bad_mode" -ne 0 ]; then
    printf '[%s] 拒绝：ADR 必须是普通文件（符号链接/gitlink 会让被校验的字节指向工作区外）→ 用普通文件重写该 ADR 后 git add\n' "$PROG" >&2
  fi
  if [ "$drift" -ne 0 ]; then
    printf '[%s] 拒绝：暂存区与工作区不一致（verify-note 读工作区，会校验错字节）→ 先 git add 再提交\n' "$PROG" >&2
  fi
  exit 1
fi

# 5) 交给判定真源（唯一真值，不在本门复刻 1.1–1.10）
bash "$VERIFY" ${PATHS[@]+"${PATHS[@]}"} || exit 1

printf '[%s] 通过：%d 条 ADR 经 %s 校验（暂存区与工作区一致）\n' "$PROG" "${#PATHS[@]}" "$VERIFY"

# 5) 归档 SHA-256 封印（A6 check）：**判定**已在步骤 1b 完成，这里只打印其输出并收口——
#    归档件被改一字节、或归档件未封印、或**A6 门本身缺失**（fail-closed：删掉门不能把封印
#    从提交窗口里摘掉），都拒绝提交。
archive_finish
exit 0
