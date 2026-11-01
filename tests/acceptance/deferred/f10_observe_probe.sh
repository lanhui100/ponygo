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
write_decl_with_service "$T" svc-a     # 声明里有 service → 允许省略 --service

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
write_decl_with_service "$T" svc-a

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
write_decl_with_service "$T" svc-a
if start_probe_server "$T" 200; then
  EP="http://127.0.0.1:$PROBE_PORT"
  run_in "$T" PONYGO_OTEL_ENDPOINT="$EP" PONYGO_OTEL_TOKEN=test-token observe probe --dry-run
  assert_zero "F10-3 observe probe --dry-run → exit 0" "$R_RC"
  assert_eq "F10-3 GO：--dry-run 零网络（接收器收到 0 请求）" 0 "$(probe_requests)"
  assert_contains "F10-3 GO：token 以 <redacted> 形式呈现" "$R_OUT" "<redacted>"
  assert_not_contains "F10-3 NOGO：--dry-run 输出不得含 token 明文" "$R_OUT" "test-token"
  stop_probe_server
fi

# ================= F10-4 缺 --service 且声明无 service（L3 终审新增）=================
T=$(new_case)
gov_repo "$T" 1
mkdir -p "$T/docs"
cat > "$T/docs/observability.yaml" <<'DECLEOF'
# 归属声明：刻意不含 service 字段（probe 不得静默用 unknown_service 顶包）
kind: cli
dimensions:
  metrics:
    applicable: false
    reason: 指标由 k8s 侧采集
  tracing:
    applicable: false
    reason: 由网关统一接入
  logs:
    applicable: false
    reason: 走集群采集
  issues:
    applicable: false
    reason: 无前端
DECLEOF
if start_probe_server "$T" 200; then
  EP="http://127.0.0.1:$PROBE_PORT"
  run_in "$T" PONYGO_OTEL_ENDPOINT="$EP" PONYGO_OTEL_TOKEN=test-token observe probe
  assert_rc_is "F10-4 缺 --service 且声明无 service → exit 1" 1 "$R_RC"
  assert_eq "F10-4 GO：用法错时不得发出任何请求" 0 "$(probe_requests)"
  assert_not_contains "F10-4 NOGO：payload/输出不得出现 unknown_service" "$(cat "$PROBE_CAP" 2>/dev/null)$R_OUT" "unknown_service"
  stop_probe_server
fi

# ================= F10-5 --timeout 校验 + 缺省档 10s（L3 终审新增）=================
T=$(new_case)
gov_repo "$T" 1
if start_probe_server "$T" 200 6; then     # 慢后端 6s：只有缺省档（10s）才可能成功
  EP="http://127.0.0.1:$PROBE_PORT"
  run_in "$T" PONYGO_OTEL_ENDPOINT="$EP" PONYGO_OTEL_TOKEN=test-token observe probe --timeout 0
  assert_rc_is "F10-5 --timeout 0 → exit 1（用法错）" 1 "$R_RC"
  run_in "$T" PONYGO_OTEL_ENDPOINT="$EP" PONYGO_OTEL_TOKEN=test-token observe probe --timeout abc
  assert_rc_is "F10-5 --timeout abc → exit 1（用法错）" 1 "$R_RC"
  run_in "$T" PONYGO_OTEL_ENDPOINT="$EP" PONYGO_OTEL_TOKEN=test-token observe probe --service svc-a
  assert_zero "F10-5 GO：缺省 timeout（10s）能覆盖 6s 慢后端 → exit 0" "$R_RC"
  stop_probe_server
fi

# ================= F10-6 token 不得出现在 argv（观测桩，确定性）=================
# 早先版本扫 /proc/<pid>/cmdline 取样，存在两处假阳/假阴：grep 自身 argv 命中、curl 可能在取样前退出。
# 现行做法：PATH 前置 curl 观测桩记录「真实传给 curl 的 argv」，再断言 token 不在其中。
T=$(new_case)
gov_repo "$T" 1
if start_probe_server "$T" 200 6; then
  EP="http://127.0.0.1:$PROBE_PORT"
  SHIM_LOG="$T/.curl-argv.log"
  if install_curl_shim "$T/.shim-bin" "$SHIM_LOG"; then
    run_in "$T" PATH="$T/.shim-bin:$PATH" PONYGO_OTEL_ENDPOINT="$EP" PONYGO_OTEL_TOKEN=test-token \
      observe probe --service svc-a
    assert_zero "F10-6 观测桩下 probe 仍成功 → exit 0" "$R_RC"
    assert_eq "F10-6 取证：观测桩确实记录了 curl 调用" 1 "$(grep -c 'v1/traces' "$SHIM_LOG" 2>/dev/null | tr -d ' ')"
    assert_contains "F10-6 GO：凭据经 -K 配置文件传入（不进 argv）" "$(cat "$SHIM_LOG" 2>/dev/null || :)" "-K "
    assert_not_contains "F10-6 NOGO：token 不得出现在任何进程 argv" "$(cat "$SHIM_LOG" 2>/dev/null || :)" "test-token"
    assert_not_contains "F10-6 NOGO：argv 中不得出现 Authorization 头" "$(cat "$SHIM_LOG" 2>/dev/null || :)" "Authorization"
  fi
  stop_probe_server
fi
run_in "$T" PONYGO_OTEL_ENDPOINT="http://127.0.0.1:1" PONYGO_OTEL_TOKEN=test-token observe probe --service svc-a
assert_not_contains "F10-6 NOGO：错误信息也不得回显 token" "$R_OUT" "test-token"

# ================= F10-7 --service 取值含引号 → payload 仍是合法 JSON（L3 终审新增）=================
T=$(new_case)
gov_repo "$T" 1
if start_probe_server "$T" 200; then
  EP="http://127.0.0.1:$PROBE_PORT"
  run_in "$T" PONYGO_OTEL_ENDPOINT="$EP" PONYGO_OTEL_TOKEN=test-token observe probe --service 'x","y'
  assert_zero "F10-7 --service 'x\",\"y' → exit 0" "$R_RC"
  SVC=$(CAP_FILE="$PROBE_CAP" python3 - <<'PY2' 2>&1
import json, os
raw = open(os.environ["CAP_FILE"], encoding="utf-8", errors="replace").read()
body = raw.split("---REQ---")[0].strip()
try:
    d = json.loads(body)
except Exception as exc:
    print("PAYLOAD-NOT-JSON: %s" % exc)
    raise SystemExit(1)
attrs = {}
for rs in d.get("resourceSpans") or []:
    for a in ((rs.get("resource") or {}).get("attributes") or []):
        v = a.get("value") or {}
        attrs[a.get("key")] = v.get("stringValue", v.get("boolValue", v.get("intValue")))
print(attrs.get("service.name"))
PY2
)
  assert_eq "F10-7 GO：payload 合法 JSON 且 service.name 原样保留（含引号）" 'x","y' "$SVC"
  stop_probe_server
fi

# ================= F10-8 --endpoint 非 URL → exit 1（用法错，不是 2）=================
T=$(new_case)
gov_repo "$T" 1
run_in "$T" PONYGO_OTEL_ENDPOINT=not-a-url PONYGO_OTEL_TOKEN=test-token observe probe --service svc-a
assert_rc_is "F10-8 --endpoint 非 URL（not-a-url）→ exit 1" 1 "$R_RC"

# ================= F10-9 token 含控制字符（Wave-11）=================
# 契约：token 含换行等控制字符 → 用法错 exit 1，且**零请求**、不落临时文件、输出点明「非法控制字符」；
#      反向：单行 token → exit 0。
T=$(new_case)
gov_repo "$T" 1
write_decl_with_service "$T" svc-a
TMPD="$T/.tmpd"; mkdir -p "$TMPD"
if start_probe_server "$T" 200; then
  EP="http://127.0.0.1:$PROBE_PORT"
  run_in "$T" TMPDIR="$TMPD" PONYGO_OTEL_ENDPOINT="$EP" PONYGO_OTEL_TOKEN=$'ab\ncd' observe probe
  assert_rc_is "F10-9 token 含换行（控制字符）→ exit 1" 1 "$R_RC"
  assert_contains "F10-9 GO：文案点明「非法控制字符」" "$R_OUT" "非法控制字符"
  assert_eq "F10-9 GO：控制字符 token 不得发出任何请求" 0 "$(probe_requests)"
  assert_eq "F10-9 GO：控制字符 token 不得在 TMPDIR 落文件" "" \
    "$(find "$TMPD" -mindepth 1 -print -quit 2>/dev/null)"

  run_in "$T" TMPDIR="$TMPD" PONYGO_OTEL_ENDPOINT="$EP" PONYGO_OTEL_TOKEN=test-token observe probe
  assert_zero "F10-9 反向对照：单行 token → exit 0" "$R_RC"
  stop_probe_server
fi

# ================= F10-10 --service 纯空白（Wave-11）=================
# 契约：--service ' ' 与「缺 service」同一判定同一文案（逐字相同）。夹具用无 service 的声明。
T=$(new_case)
gov_repo "$T" 1
mkdir -p "$T/docs"
cat > "$T/docs/observability.yaml" <<'DECLEOF'
kind: cli
dimensions:
  metrics: { applicable: false, reason: 指标由 k8s 侧采集 }
  tracing: { applicable: false, reason: 由网关统一接入 }
  logs: { applicable: false, reason: 走集群采集 }
  issues: { applicable: false, reason: 无前端 }
DECLEOF
if start_probe_server "$T" 200; then
  EP="http://127.0.0.1:$PROBE_PORT"
  run_in "$T" PONYGO_OTEL_ENDPOINT="$EP" PONYGO_OTEL_TOKEN=test-token observe probe
  OUT_MISSING="$R_OUT"; RC_MISSING=$R_RC
  run_in "$T" PONYGO_OTEL_ENDPOINT="$EP" PONYGO_OTEL_TOKEN=test-token observe probe --service ' '
  OUT_BLANK="$R_OUT"; RC_BLANK=$R_RC
  assert_rc_is "F10-10 缺 service → exit 1" 1 "$RC_MISSING"
  assert_rc_is "F10-10 --service 纯空白 → exit 1" 1 "$RC_BLANK"
  if [ "$OUT_MISSING" = "$OUT_BLANK" ]; then
    ok "F10-10 GO：--service 纯空白的文案与「缺 service」逐字相同"
  else
    bad "F10-10 --service 纯空白与「缺 service」文案不同"
  fi
  assert_eq "F10-10 取证：两种用法错均不得发出请求" 0 "$(probe_requests)"
  stop_probe_server
fi

# ================= F10-11 失败路径不得泄漏 curl 双前缀（Wave-11）=================
T=$(new_case)
gov_repo "$T" 1
write_decl_with_service "$T" svc-a
run_split "$T" PONYGO_OTEL_ENDPOINT="http://127.0.0.1:1" PONYGO_OTEL_TOKEN=test-token observe probe
assert_nonzero "F10-11 endpoint 未监听 → 非零退出" "$R_RC"
CURL_DUP=$(printf '%s\n' "$R_ERR" | grep -oF 'curl: curl:' | wc -l | tr -d ' ')
assert_eq "F10-11 NOGO：stderr 中「curl: curl:」出现 0 次（不得双前缀泄漏）" 0 "$CURL_DUP"

finish
