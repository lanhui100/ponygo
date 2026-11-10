#!/usr/bin/env bash
# GH5：真实 scratch 门必须拒绝 release.yml 的 .scratch 引用，并能恢复放行。
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

GATE="$ROOT/.meta/gates/scratch-hygiene.sh"
assert_file "GH5 真实 scratch 门存在" "$GATE"
T=$(new_case)
mkdir -p "$T/.github/workflows"
printf '.scratch/\n' > "$T/.gitignore"
cat > "$T/.github/workflows/release.yml" <<'YAMLEOF'
name: release
on:
  push:
    tags: ['v*']
jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - run: sha256sum ponygo > ponygo.sha256
YAMLEOF
(cd "$T" && git init -q .)
OUT=$(cd "$T" && bash "$GATE" 2>&1)
RC=$?
assert_rc_is "GH5 合法 release 基线放行" 0 "$RC"

python3 - "$T/.github/workflows/release.yml" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
s = p.read_text()
s = s.replace("      - run: sha256sum ponygo > ponygo.sha256", "      - run: cp .scratch/artifact ponygo.sha256")
p.write_text(s)
PY
assert_contains "GH5 负样本确实注入 release run" "$(cat "$T/.github/workflows/release.yml")" "cp .scratch/artifact ponygo.sha256"
OUT=$(cd "$T" && bash "$GATE" 2>&1)
RC=$?
assert_rc_is "GH5 release 引用 .scratch 必须拒绝" 1 "$RC"
assert_contains "GH5 拒绝带 E3" "$OUT" "[E3]"
assert_contains "GH5 拒绝指出 release.yml" "$OUT" ".github/workflows/release.yml"
assert_contains "GH5 拒绝指出 .scratch" "$OUT" ".scratch"

python3 - "$T/.github/workflows/release.yml" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
p.write_text(p.read_text().replace("cp .scratch/artifact ponygo.sha256", "sha256sum ponygo > ponygo.sha256"))
PY
OUT=$(cd "$T" && bash "$GATE" 2>&1)
RC=$?
assert_rc_is "GH5 恢复 release 后重新放行（非粘滞拒绝）" 0 "$RC"

# install 独立夹具：不得复用 release 目录，避免一个残留替另一个制造失败。
I=$(new_case)
printf '.scratch/\n' > "$I/.gitignore"
printf '#!/usr/bin/env bash\ncp .scratch/payload ponygo\n' > "$I/install.sh"
assert_missing "GH5 install 专用夹具无 release" "$I/.github/workflows/release.yml"
(cd "$I" && git init -q .)
OUT=$(cd "$I" && bash "$GATE" 2>&1)
RC=$?
assert_rc_is "GH5 install 独立夹具仍拒绝 .scratch" 1 "$RC"
assert_contains "GH5 install 独立失败带 E3" "$OUT" "[E3]"
assert_contains "GH5 install 独立失败指出自身" "$OUT" "install.sh"
finish
