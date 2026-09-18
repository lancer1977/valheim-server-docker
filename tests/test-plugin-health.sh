#!/usr/bin/env bash
# Unit tests for valheim-plugin-health's detection logic.
#
# These run on a plain runner (no container), so defaults/common are stubbed
# with just the symbols the watchdog touches. The log fixtures use the real
# exception text captured from the 2026-09-17 incident, so a regression that
# stops matching the actual Valheim/BepInEx output will fail here.

set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

failures=0

ok()   { echo "  ok   - $*"; }
fail() { echo "  FAIL - $*"; failures=$((failures + 1)); }

assert_eq() {
    local expected actual label
    expected="$1"; actual="$2"; label="$3"
    if [ "$expected" = "$actual" ]; then
        ok "$label"
    else
        fail "$label (expected '$expected', got '$actual')"
    fi
}

assert_grep() {
    if grep -q "$1" "$TEST_LOG_SINK"; then ok "$2"; else fail "$2"; fi
}

# --- stub the container filesystem the watchdog sources -------------------

mkdir -p "$work_dir/etc" "$work_dir/bepinex/BepInEx/plugins"

cat > "$work_dir/etc/defaults" <<'EOF'
PLUGIN_HEALTH_CHECK=${PLUGIN_HEALTH_CHECK:-true}
PLUGIN_HEALTH_CHECK_INTERVAL=${PLUGIN_HEALTH_CHECK_INTERVAL:-60}
PLUGIN_HEALTH_CHECK_THRESHOLD=${PLUGIN_HEALTH_CHECK_THRESHOLD:-25}
PLUGIN_HEALTH_LOG_MAX_BYTES=${PLUGIN_HEALTH_LOG_MAX_BYTES:-268435456}
BEPINEX=${BEPINEX:-true}
VALHEIM_PLUS=${VALHEIM_PLUS:-false}
EOF

cat > "$work_dir/etc/common" <<'EOF'
bepinex_install_path="$TEST_BEPINEX_PATH"
vp_install_path="$TEST_BEPINEX_PATH"
debug() { :; }
info()  { echo "INFO - $*" >> "$TEST_LOG_SINK"; }
warn()  { echo "WARN - $*" >> "$TEST_LOG_SINK"; }
error() { echo "ERROR - $*" >> "$TEST_LOG_SINK"; }
update_server_status() { echo "$1" > "$TEST_STATUS_FILE"; }
server_is_running() { return 0; }
iec_size_format() { echo "$1 B"; }
EOF

export TEST_BEPINEX_PATH="$work_dir/bepinex"
export TEST_STATUS_FILE="$work_dir/status"
export TEST_LOG_SINK="$work_dir/logsink"
export VALHEIM_ETC="$work_dir/etc"
export PLUGIN_HEALTH_SOURCE_ONLY=true
export PLUGIN_HEALTH_CHECK_THRESHOLD=25

: > "$TEST_LOG_SINK"
echo running > "$TEST_STATUS_FILE"

loader_log="$work_dir/bepinex/BepInEx/LogOutput.log"
: > "$loader_log"

# Real text from the 2026-09-17 Serverside_Simulations failure.
append_incident_errors() {
    local n="$1" i
    for ((i = 0; i < n; i++)); do
        cat >> "$loader_log" <<'EOF'
[Error  : Unity Log] MissingMethodException: Method not found: Vector2i .ZoneSystem.GetZone(UnityEngine.Vector3)
  at (wrapper dynamic-method) ZNetScene.DMD<ZNetScene::CreateDestroyObjects>(ZNetScene)
  at ZNetScene.Update () [0x0002c] in <a63433e8968e407a918a9f9fe7e7ba9a>:0
EOF
    done
}

append_benign_lines() {
    local n="$1" i
    for ((i = 0; i < n; i++)); do
        echo "[Info   : Unity Log] Connections 1 ZDOS:60940  sent:0 recv:419" >> "$loader_log"
    done
}

# shellcheck source-path=SCRIPTDIR/..
# shellcheck source=valheim-plugin-health
. "$repo_root/valheim-plugin-health"

echo "== valheim-plugin-health"

# 1. A healthy log must not trip the watchdog.
append_benign_lines 200
check_loader_log "$loader_log"
assert_eq "running" "$(cat "$TEST_STATUS_FILE")" "benign log leaves status untouched"

# 2. Errors above the threshold flip the server to unhealthy.
append_incident_errors 30
check_loader_log "$loader_log"
assert_eq "unhealthy" "$(cat "$TEST_STATUS_FILE")" "burst above threshold marks unhealthy"
assert_grep "PLUGIN API INCOMPATIBILITY DETECTED" "operator-facing banner logged"
assert_grep "ZoneSystem.GetZone" "offending signature named in the log"

# 3. The banner must not repeat every interval while the episode continues.
banner_count_before=$(grep -c "PLUGIN API INCOMPATIBILITY DETECTED" "$TEST_LOG_SINK")
append_incident_errors 30
check_loader_log "$loader_log"
banner_count_after=$(grep -c "PLUGIN API INCOMPATIBILITY DETECTED" "$TEST_LOG_SINK")
assert_eq "$banner_count_before" "$banner_count_after" "banner is not repeated while unhealthy"

# 4. Recovery: once errors stop, status returns to running.
append_benign_lines 50
check_loader_log "$loader_log"
assert_eq "running" "$(cat "$TEST_STATUS_FILE")" "status recovers when errors stop"

# 5. A trickle below the threshold must not trip it. This is the false-positive
#    guard: isolated reflection errors do happen without gameplay being broken.
append_incident_errors 5
check_loader_log "$loader_log"
assert_eq "running" "$(cat "$TEST_STATUS_FILE")" "sub-threshold trickle does not trip"

# 6. Only newly appended bytes are counted, so a large historical backlog of
#    errors does not re-trigger on every interval.
check_loader_log "$loader_log"
assert_eq "running" "$(cat "$TEST_STATUS_FILE")" "no new bytes means no re-evaluation"

# 7. Truncation resets the read offset instead of wedging the watchdog.
: > "$loader_log"
append_incident_errors 30
check_loader_log "$loader_log"
assert_eq "unhealthy" "$(cat "$TEST_STATUS_FILE")" "detection survives log truncation"

# 8. The size cap truncates in place, preserving the writer's file handle.
PLUGIN_HEALTH_LOG_MAX_BYTES=100
inode_before=$(stat -c %i "$loader_log")
cap_loader_log "$loader_log"
inode_after=$(stat -c %i "$loader_log")
assert_eq "0" "$(stat -c %s "$loader_log")" "oversized log is truncated"
assert_eq "$inode_before" "$inode_after" "truncation keeps the same inode"

# 9. The cap is opt-out-able.
PLUGIN_HEALTH_LOG_MAX_BYTES=0
append_benign_lines 50
size_before=$(stat -c %s "$loader_log")
cap_loader_log "$loader_log"
assert_eq "$size_before" "$(stat -c %s "$loader_log")" "cap of 0 disables truncation"

# 10. Loader path resolution follows the active loader.
BEPINEX=true
assert_eq "$TEST_BEPINEX_PATH/BepInEx/LogOutput.log" "$(loader_log_path)" "resolves BepInEx log path"

echo "== valheim-healthcheck"

# The HEALTHCHECK is what turns SERVER_STATUS_FILE into a signal Docker and
# Portainer can act on, so its exit-code contract is worth pinning: only
# `running` may report healthy.
echo "SERVER_STATUS_FILE=$work_dir/status" >> "$work_dir/etc/defaults"

healthcheck_exit() {
    echo "$1" > "$TEST_STATUS_FILE"
    VALHEIM_ETC="$work_dir/etc" bash "$repo_root/valheim-healthcheck" >/dev/null 2>&1
    echo "$?"
}

assert_eq "0" "$(healthcheck_exit running)"       "running reports healthy"
assert_eq "1" "$(healthcheck_exit unhealthy)"     "unhealthy reports unhealthy"
assert_eq "1" "$(healthcheck_exit bootstrapping)" "bootstrapping reports unhealthy"
assert_eq "1" "$(healthcheck_exit starting)"      "starting reports unhealthy"
assert_eq "1" "$(healthcheck_exit stopping)"      "stopping reports unhealthy"
assert_eq "1" "$(healthcheck_exit stopped)"       "stopped reports unhealthy"
assert_eq "1" "$(healthcheck_exit '')"            "empty status reports unhealthy"

rm -f "$TEST_STATUS_FILE"
VALHEIM_ETC="$work_dir/etc" bash "$repo_root/valheim-healthcheck" >/dev/null 2>&1
assert_eq "1" "$?" "missing status file reports unhealthy"

# The unhealthy message must point the operator at the logs, since that is the
# only place the offending plugin is named.
echo unhealthy > "$TEST_STATUS_FILE"
message=$(VALHEIM_ETC="$work_dir/etc" bash "$repo_root/valheim-healthcheck" 2>&1)
case "$message" in
    *"container logs"*) ok "unhealthy message points at the container logs" ;;
    *) fail "unhealthy message points at the container logs (got '$message')" ;;
esac

if [ "$failures" -gt 0 ]; then
    echo "$failures assertion(s) failed"
    exit 1
fi
echo "all plugin-health tests passed"
