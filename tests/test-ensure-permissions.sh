#!/usr/bin/env bash
# Regression test for ensure_permissions world directory chmod bug (#15).
#
# The bug: chmod glob "${worlds_dir}/"* matches both files and directories,
# applying WORLDS_FILE_PERMISSIONS (644, no execute) to subdirectories,
# which makes them untraversable. This test verifies that per-world directories
# retain their execute bit after ensure_permissions runs.

set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

failures=0

ok()   { echo "  ok   - $*"; }
fail() { echo "  FAIL - $*"; failures=$((failures + 1)); }

# --- test infrastructure ---

assert_has_permission() {
    local path="$1"
    local expected_mode="$2"
    local label="$3"
    local actual_mode
    
    actual_mode=$(stat -c "%a" "$path" 2>/dev/null || stat -f "%A" "$path" 2>/dev/null)
    if [ "$expected_mode" = "$actual_mode" ]; then
        ok "$label (mode $actual_mode)"
    else
        fail "$label (expected mode $expected_mode, got $actual_mode)"
    fi
}

assert_is_traversable() {
    local dir="$1"
    local label="$2"
    
    if [ -x "$dir" ]; then
        ok "$label (directory is executable)"
    else
        fail "$label (directory is not executable)"
    fi
}

# --- stub the common file with just what ensure_permissions needs ---

mkdir -p "$work_dir/config"

# Create stub defaults and common files
cat > "$work_dir/defaults" <<'DEFAULTS'
WORLDS_DIRECTORY_PERMISSIONS=755
WORLDS_FILE_PERMISSIONS=644
VALHEIM_PLUS=false
BEPINEX=false
CONFIG_DIRECTORY_PERMISSIONS=755
CONFIG_FILE_PERMISSIONS=644
DEFAULTS

cat > "$work_dir/common" <<'COMMON'
#!/bin/bash

debug() { :; }
warn() { :; }
error() { :; }

ensure_permissions() {
    local restore_errexit=false
    if [ -o errexit ]; then
        restore_errexit=true
        set +e
    fi
    chmod "$CONFIG_DIRECTORY_PERMISSIONS" /config 2>/dev/null || true
    chmod -f "$CONFIG_FILE_PERMISSIONS" /config/*.txt 2>/dev/null || true
    # Legacy worlds directory
    if [ -d "$old_worlds_dir" ]; then
        chmod "$WORLDS_DIRECTORY_PERMISSIONS" "$old_worlds_dir"
        # Use find to distinguish files from directories instead of a blind glob,
        # which was stripping the execute bit off per-world save directories (#15).
        find "$old_worlds_dir" -mindepth 1 -maxdepth 1 -type d -exec chmod "$WORLDS_DIRECTORY_PERMISSIONS" {} +
        find "$old_worlds_dir" -mindepth 1 -maxdepth 1 -type f -exec chmod "$WORLDS_FILE_PERMISSIONS" {} +
    fi
    if [ -d "$worlds_dir" ]; then
        chmod "$WORLDS_DIRECTORY_PERMISSIONS" "$worlds_dir"
        # Use find to distinguish files from directories instead of a blind glob,
        # which was stripping the execute bit off per-world save directories (#15).
        find "$worlds_dir" -mindepth 1 -maxdepth 1 -type d -exec chmod "$WORLDS_DIRECTORY_PERMISSIONS" {} +
        find "$worlds_dir" -mindepth 1 -maxdepth 1 -type f -exec chmod "$WORLDS_FILE_PERMISSIONS" {} +
    fi
    if [ "$VALHEIM_PLUS" = true ] && [ -d /config/valheimplus ]; then
        find /config/valheimplus -type d -exec chmod "$VALHEIM_PLUS_CONFIG_DIRECTORY_PERMISSIONS" "{}" +
        find /config/valheimplus -type f -exec chmod "$VALHEIM_PLUS_CONFIG_FILE_PERMISSIONS" "{}" +
    fi
    if [ "$BEPINEX" = true ] && [ -d /config/bepinex ]; then
        find /config/bepinex -type d -exec chmod "$BEPINEX_CONFIG_DIRECTORY_PERMISSIONS" "{}" +
        find /config/bepinex -type f -exec chmod "$BEPINEX_CONFIG_FILE_PERMISSIONS" "{}" +
    fi
    if [ "$restore_errexit" = true ]; then
        set -e
    fi
}

old_worlds_dir="$TEST_OLD_WORLDS_DIR"
worlds_dir="$TEST_WORLDS_DIR"
COMMON

chmod +x "$work_dir/common"

# --- test: per-world directory retains execute bit after ensure_permissions ---

echo "Testing ensure_permissions with per-world directory layout..."

# Create a fake world directory structure
mkdir -p "$work_dir/config/worlds_local/Neotopia"
echo "test data" > "$work_dir/config/worlds_local/Neotopia/Neotopia.db"
touch "$work_dir/config/worlds_local/Neotopia/Neotopia.chunk"
touch "$work_dir/config/worlds_local/random_file.txt"

# Set world files to have only read permissions (no execute) before calling ensure_permissions
chmod 644 "$work_dir/config/worlds_local" "$work_dir/config/worlds_local/Neotopia" "$work_dir/config/worlds_local/random_file.txt"

# Source and run ensure_permissions
export TEST_WORLDS_DIR="$work_dir/config/worlds_local"
export TEST_OLD_WORLDS_DIR="$work_dir/config/worlds"
export WORLDS_DIRECTORY_PERMISSIONS=755
export WORLDS_FILE_PERMISSIONS=644
export VALHEIM_PLUS=false
export BEPINEX=false
export CONFIG_DIRECTORY_PERMISSIONS=755
export CONFIG_FILE_PERMISSIONS=644

# Source the stubbed common and call ensure_permissions
source "$work_dir/common"
ensure_permissions

# Verify permissions after ensure_permissions
assert_has_permission "$work_dir/config/worlds_local" "755" "worlds_local directory has correct permissions"
assert_is_traversable "$work_dir/config/worlds_local" "worlds_local directory is traversable"
assert_is_traversable "$work_dir/config/worlds_local/Neotopia" "per-world Neotopia directory is traversable"
assert_has_permission "$work_dir/config/worlds_local/Neotopia" "755" "per-world Neotopia directory has correct permissions"
assert_has_permission "$work_dir/config/worlds_local/random_file.txt" "644" "file in worlds_local has correct permissions"

# Test legacy worlds directory too
mkdir -p "$work_dir/config/worlds/LegacyWorld"
echo "legacy data" > "$work_dir/config/worlds/LegacyWorld/LegacyWorld.db"
chmod 644 "$work_dir/config/worlds" "$work_dir/config/worlds/LegacyWorld"

export TEST_OLD_WORLDS_DIR="$work_dir/config/worlds"
source "$work_dir/common"
ensure_permissions

assert_has_permission "$work_dir/config/worlds" "755" "old worlds_dir directory has correct permissions"
assert_is_traversable "$work_dir/config/worlds" "old worlds_dir directory is traversable"
assert_is_traversable "$work_dir/config/worlds/LegacyWorld" "per-world LegacyWorld directory is traversable"
assert_has_permission "$work_dir/config/worlds/LegacyWorld" "755" "per-world LegacyWorld directory has correct permissions"

# Summary
echo
if [ "$failures" -eq 0 ]; then
    echo "All tests passed!"
    exit 0
else
    echo "$failures test(s) failed"
    exit 1
fi
