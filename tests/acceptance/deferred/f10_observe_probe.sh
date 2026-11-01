#!/usr/bin/env bash
# F10（ponygo observe probe）：受控探针——由 ponygo 自己投递带 provenance 的 span。
#   成功路径（本地 python3 OTLP/HTTP 接收器，零外网）：
#     PONYGO_OTEL_ENDPOINT=http://127.0.0.1:<port> PONYGO_OTEL_TOKEN=test-token ponygo observe probe
#     → exit 0；payload 为 OTLP/HTTP JSON；resource attributes 含 service.name、
#       deployment.environment、ponygo.probe=true、ponygo.probe.version=1；span 名 ponygo.probe；
#       输出不得出现 token 明文；须含「等待 N 秒后…observe audit」类指引。
#   失败路径：无 endpoint → 1；无 token → 1；endpoint 未监听 / HTTP 500 → 2。
#   --dry-run：零网络（探针服务收到 0 请求）且 token 以 <redacted> 形式出现。
# 冻结契约来源：Lead 裁决（task-5 · F10）。
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

if ! command -v python3 >/dev/null 2>&1; then
  bad "F10 需要 python3（本地 OTLP 探针接收器）——当前环境缺失"
  finish
fi

T=$(new_case)
gov_repo "$T" 1

# ================= F10-1 成功路径 =================
if start_probe_server "$T" 200; then
  EP="http://127.0.0.1:$PROBE_PORT"
  run_in "$T" PONYGO_OTEL_ENDPOINT="$EP" PONYGO_OTEL_TOKEN=test-token observe probe
  assert_zero "F10-1 observe probe（本地接收器 200）→ exit 0" "$R_RC"
  assert_eq "F10-1 GO：探针恰好投递 1 个请求" 1 "$(probe_requests)"
  CAP_TXT=$(cat "$PROBE_CAP" 2>/dev/null || :)
  assert_contains "F10-1 GO：payload 为 OTLP/HTTP JSON（含 resourceSpans）" "$CAP_TXT" '"resourceSpans"'
  assert_contains "F10-1 GO：span 名为 ponygo.probe" "$CAP_TXT" '"ponygo.probe"'
  assert_not_contains "F10-1 NOGO：输出不得泄漏 token 明文" "$R_OUT" "test-token"
  assert_contains "F10-1 GO：输出给出等待后跑 observe audit 的指引" "$R_OUT" "observe audit"
  assert_matches "F10-1 GO：输出说明等待窗口（N 秒）" "$R_OUT" '等待[^\n]*秒'

  # payload 结构断言（OTLP/HTTP JSON：resourceSpans[].resource.attributes 的 key/value）
  PAYLOAD_CHECK=$(CAP_FILE="$PROBE_CAP" python3 - <<'PY' 2>&1
import json, os

raw = open(os.environ["CAP_FILE"], encoding="utf-8", errors="replace").read()
body = raw.split("---REQ---")[0].strip()
try:
    d = json.loads(body)
except Exception as exc:
    print("PAYLOAD-NOT-JSON: %s" % exc)
    raise SystemExit(1)

def av(val):
    if not isinstance(val, dict):
        return val
    for k in ("stringValue", "boolValue", "intValue", "doubleValue"):
        if k in val:
            return val[k]
    return val

problems = []
rs = d.get("resourceSpans")
if not isinstance(rs, list) or not rs:
    problems.append("resourceSpans 缺失/为空")
    attrs = {}
else:
    attr_list = ((rs[0].get("resource") or {}).get("attributes") or [])
    attrs = {a.get("key"): av(a.get("value")) for a in attr_list if isinstance(a, dict)}

for key in ("service.name", "deployment.environment", "ponygo.probe", "ponygo.probe.version"):
    if key not in attrs:
        problems.append("resource attribute 缺 %s" % key)

if attrs.get("ponygo.probe") not in (True, "true"):
    problems.append("ponygo.probe=%r（应为 true）" % attrs.get("ponygo.probe"))
if str(attrs.get("ponygo.probe.version")) != "1":
    problems.append("ponygo.probe.version=%r（应为 1）" % attrs.get("ponygo.probe.version"))

names = []
for srs in (rs or []):
    for ss in (srs.get("scopeSpans") or srs.get("instrumentationLibrarySpans") or []):
        for sp in (ss.get("spans") or []):
            names.append(sp.get("name"))
if "ponygo.probe" not in names:
    problems.append("span 名不是 ponygo.probe（实得 %r）" % names)

if problems:
    print("; ".join(problems))
    raise SystemExit(1)
raise SystemExit(0)
PY
)
  if [ "$?" -eq 0 ]; then
    ok "F10-1 GO：payload 的 resource attributes 与 span 名全部合规"
  else
    bad "F10-1 payload 结构不合规（$PAYLOAD_CHECK）"
  fi
  stop_probe_server
fi

# ================= F10-2 失败路径 =================
T=$(new_case)
gov_repo "$T" 1

run_in "$T" PONYGO_OTEL_ENDPOINT="http://127.0.0.1:1" observe probe
assert_rc_is "F10-2 缺 token → exit 1" 1 "$R_RC"

run_in "$T" PONYGO_OTEL_TOKEN=test-token observe probe
assert_rc_is "F10-2 缺 endpoint → exit 1" 1 "$R_RC"
assert_not_contains "F10-2 NOGO：失败路径不得回显 token 明文" "$R_OUT" "test-token"

run_in "$T" PONYGO_OTEL_ENDPOINT="http://127.0.0.1:1" PONYGO_OTEL_TOKEN=test-token observe probe
assert_rc_is "F10-2 endpoint 未监听（连接被拒）→ exit 2" 2 "$R_RC"

if start_probe_server "$T" 500; then
  EP="http://127.0.0.1:$PROBE_PORT"
  run_in "$T" PONYGO_OTEL_ENDPOINT="$EP" PONYGO_OTEL_TOKEN=test-token observe probe
  assert_rc_is "F10-2 接收器 HTTP 500 → exit 2" 2 "$R_RC"
  assert_eq "F10-2 取证：HTTP 500 路径确实发出了请求" 1 "$(probe_requests)"
  stop_probe_server
fi

# ================= F10-3 --dry-run 零网络 =================
T=$(new_case)
gov_repo "$T" 1
if start_probe_server "$T" 200; then
  EP="http://127.0.0.1:$PROBE_PORT"
  run_in "$T" PONYGO_OTEL_ENDPOINT="$EP" PONYGO_OTEL_TOKEN=test-token observe probe --dry-run
  assert_zero "F10-3 observe probe --dry-run → exit 0" "$R_RC"
  assert_eq "F10-3 GO：--dry-run 零网络（接收器收到 0 请求）" 0 "$(probe_requests)"
  assert_contains "F10-3 GO：token 以 <redacted> 形式呈现" "$R_OUT" "<redacted>"
  assert_not_contains "F10-3 NOGO：--dry-run 输出不得含 token 明文" "$R_OUT" "test-token"
  stop_probe_server
fi

finish
