#!/usr/bin/env bash
# Regression test for write_bepinex_config (common) -- #13.
#
# Before the fix, the plugin sync only ran when BepInEx's own runtime
# plugins/ directory already existed ([ -d "$plugins_path" ]), so a fresh
# BepInEx extraction that hadn't created that directory yet caused the sync
# to silently no-op: no error, no log line, server boots with zero plugins.
# This reproduces that shape directly against the real `write_bepinex_config`
# function from `common`.

set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

failures=0

ok()   { echo "  ok   - $*"; }
fail() { echo "  FAIL - $*"; failures=$((failures + 1)); }

# --- stub the logging/hook symbols write_bepinex_config depends on --------
debug() { :; }
info()  { :; }
error() { :; }
fatal() { :; }

PRE_BEPINEX_CONFIG_HOOK=""
POST_BEPINEX_CONFIG_HOOK=""
BEPINEX_CFG_ENV_PREFIX="BEPINEX_CFG__NEVER_MATCHES__"

# Pull in just write_bepinex_config without executing the rest of `common`
# (which expects a full container filesystem).
write_bepinex_config_src="$(sed -n '/^write_bepinex_config()/,/^}/p' "$repo_root/common")"
eval "$write_bepinex_config_src"

config_path="$work_dir/config/bepinex"
plugins_path="$work_dir/runtime/BepInEx/plugins"

mkdir -p "$config_path/plugins/SomePlugin"
touch "$config_path/plugins/SomePlugin/SomePlugin.dll"

# The runtime plugins directory deliberately does NOT exist yet -- this is
# the exact live-server condition from the 2026-09-19 incident.
if [ -d "$plugins_path" ]; then
    fail "test setup: plugins_path should not pre-exist"
else
    ok "test setup: plugins_path absent, matching the live-incident condition"
fi

write_bepinex_config "$config_path" "$plugins_path"

if [ -f "$plugins_path/SomePlugin/SomePlugin.dll" ]; then
    ok "plugin synced into a runtime plugins dir that did not pre-exist"
else
    fail "plugin was NOT synced -- write_bepinex_config silently no-op'd (the #13 bug)"
fi

echo
if [ "$failures" -eq 0 ]; then
    echo "test-bepinex-plugin-sync: all checks passed"
    exit 0
else
    echo "test-bepinex-plugin-sync: $failures check(s) failed"
    exit 1
fi
