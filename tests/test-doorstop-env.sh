#!/usr/bin/env bash
# Unit tests for Doorstop environment variable exports in valheim-server.
#
# Verifies that both Doorstop 3 (DOORSTOP_ENABLE, DOORSTOP_INVOKE_DLL_PATH)
# and Doorstop 4 (DOORSTOP_ENABLED, DOORSTOP_TARGET_ASSEMBLY) variable names
# are exported in the BepInEx block and passed through the setsid env wrapper.
# See #17.

set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
launcher="$repo_root/valheim-server"

failures=0

ok()   { echo "  ok   - $*"; }
fail() { echo "  FAIL - $*"; failures=$((failures + 1)); }

assert_grep() {
    local pattern="$1" label="$2"
    if grep -q "$pattern" "$launcher"; then
        ok "$label"
    else
        fail "$label (pattern not found: $pattern)"
    fi
}

echo "== valheim-server Doorstop env exports"

# Doorstop 4 exports must be present in the BepInEx block
assert_grep "export DOORSTOP_ENABLED=1" "DOORSTOP_ENABLED=1 exported in BepInEx block"
assert_grep 'export DOORSTOP_TARGET_ASSEMBLY="./BepInEx/core/BepInEx.Preloader.dll"' "DOORSTOP_TARGET_ASSEMBLY exported in BepInEx block"

# Both schemes must be listed in the setsid env wrapper
assert_grep 'DOORSTOP_ENABLED="\$DOORSTOP_ENABLED"' "DOORSTOP_ENABLED passed to setsid env"
assert_grep 'DOORSTOP_TARGET_ASSEMBLY="\$DOORSTOP_TARGET_ASSEMBLY"' "DOORSTOP_TARGET_ASSEMBLY passed to setsid env"

# Both must be in the inner export list for bash -c
assert_grep "export LD_LIBRARY_PATH DOORSTOP_ENABLE DOORSTOP_ENABLED DOORSTOP_INVOKE_DLL_PATH DOORSTOP_TARGET_ASSEMBLY DOORSTOP_CORLIB_OVERRIDE_PATH" "both schemes in inner export list"

# Doorstop 3 exports must still be present (backward compatibility)
assert_grep "export DOORSTOP_ENABLE=TRUE" "DOORSTOP_ENABLE=TRUE still exported"
assert_grep 'export DOORSTOP_INVOKE_DLL_PATH="./BepInEx/core/BepInEx.Preloader.dll"' "DOORSTOP_INVOKE_DLL_PATH still exported"

if [ "$failures" -gt 0 ]; then
    echo "$failures assertion(s) failed"
    exit 1
fi
echo "all doorstop-env tests passed"
