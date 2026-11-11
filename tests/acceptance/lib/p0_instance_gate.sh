#!/usr/bin/env bash
# ============================================================
# tests/acceptance/lib/p0_instance_gate.sh
# P0-2/P0-3 验收夹具（2026-11-11，Lead 授权扩写域）。
#
# 背景：判据 2.3 自 P0 批次起是三条 AND——
#   ① 仓内 ≥1 个非空 *.spec.*；
#   ② L2 必须 ≥1 个**实例门**（框架随 init 交付的 A1/A2/A4/A6/A7 明确不计实例门，
#      否则每个实例都白得，判据永远免判）；
#   ③ 每个 spec 含**拒绝断言**（至少一处 exit/return [1-9]；只 exit 0 的 spec 恒绿，
#      证明不了门会拒绝非法样本）。
#
# 后果：所有「level ≥2 且期望 status/audit exit 0」的既有夹具都缺第 ②③ 条 → 集体转红。
# 修法单点收口在这里：各套件的 make_gov_repo 在 level ≥2 时调用本函数加装一对最小门 + spec。
# **被测行为零改动**：门只判形状/配对（无参放行、未知参数拒绝），不参与任何被测语义；
# 专测 2.3 负向行为的用例自行覆盖/删除这对文件。
# ============================================================

# 加装实例门 + 含拒绝断言的同名 spec
add_instance_gate() { # <case 目录> [stem，默认 instance-gate]
  local d="$1" stem="${2:-instance-gate}"
  mkdir -p "$d/.meta/gates"
  cat > "$d/.meta/gates/$stem.sh" <<'P0GATE'
#!/usr/bin/env bash
# 夹具实例门：无参放行，未知参数非零拒绝——拒绝语义在场，才配得上同名负样本 spec。
case "${1:-}" in
  "") exit 0 ;;
  *)  printf 'instance gate: 拒绝非法样本 %s\n' "$1" >&2; exit 1 ;;
esac
P0GATE
  cat > "$d/.meta/gates/$stem.spec.sh" <<P0SPEC
#!/usr/bin/env bash
# 负样本夹具：违规输入必须被门拒绝（拒绝断言 = exit 1，P0-3 要求至少一条）。
if bash "\$(dirname "\$0")/$stem.sh" --bad >/dev/null 2>&1; then
  echo "$stem 未拒绝非法样本 --bad（负样本失败）"
  exit 1
fi
echo "$stem 负样本：--bad 已被拒绝"
exit 0
P0SPEC
  chmod +x "$d/.meta/gates/$stem.sh" "$d/.meta/gates/$stem.spec.sh"
}
