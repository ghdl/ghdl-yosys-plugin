#!/bin/sh
# Common test utilities for rename and write_vhdl tests
# within the integrated ghdl-yosys-plugin testsuite.
#
# The caller must set SCRIPT_DIR to the directory of the test script
# before sourcing this file.  For example:
#   SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
#   . "$SCRIPT_DIR/../common.sh"

# Resolve the plugin path (relative to SCRIPT_DIR)
# common.sh is at testsuite/rename/common.sh; repo root is 2 levels up
COMMON_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TOP_DIR="$(cd "$COMMON_DIR/../.." && pwd)"
PLUGIN="${PLUGIN:-$TOP_DIR/ghdl.so}"
GHDL=${GHDL:-ghdl}

# Temporary working directory for each test
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# Check that required tools are available
check_tools() {
    if ! command -v yosys >/dev/null 2>&1; then
        echo "SKIP: yosys not found"
        exit 0
    fi
    if ! command -v "$GHDL" >/dev/null 2>&1; then
        echo "SKIP: ghdl not found"
        exit 0
    fi
    if [ ! -f "$PLUGIN" ]; then
        echo "SKIP: $PLUGIN not built (run make first)"
        exit 0
    fi
}

# Write VHDL source to the temp directory
# Usage: write_vhdl filename.vhd <<'EOF' ... EOF
write_vhdl() {
    cat > "$WORK/$1"
}

# Write Verilog source to the temp directory
# Usage: write_verilog filename.v <<'EOF' ... EOF
write_verilog() {
    cat > "$WORK/$1"
}

# Run GHDL analysis on files in the temp directory
# Usage: ghdl_analyze file1.vhd file2.vhd ...
ghdl_analyze() {
    (cd "$WORK" && "$GHDL" -a "$@") || { echo "FAIL: ghdl -a failed"; exit 1; }
}

# Run yosys with the integrated plugin
# Usage: run_yosys "script_commands"
run_yosys() {
    (cd "$WORK" && yosys -m "$PLUGIN" -p "$1") \
        >"$WORK/yosys.log" 2>&1 || {
        echo "FAIL: yosys failed"
        cat "$WORK/yosys.log" >&2
        exit 1
    }
}

# Run yosys + ghdl import + vhdl_rename + write_verilog
# Usage: run_rename entity_name [extra_yosys_commands]
run_rename() {
    local entity="$1"
    shift
    local extra="$*"
    (cd "$WORK" && yosys -m "$PLUGIN" \
        -p "ghdl $entity; $extra vhdl_rename; write_verilog -noattr out.v") \
        >"$WORK/yosys.log" 2>&1 || {
        echo "FAIL: yosys failed"
        cat "$WORK/yosys.log" >&2
        exit 1
    }
}

# Same as run_rename but uses --rename flag on ghdl command
# Usage: run_ghdl_rename entity_name [extra_yosys_commands]
run_ghdl_rename() {
    local entity="$1"
    shift
    local extra="$*"
    (cd "$WORK" && yosys -m "$PLUGIN" \
        -p "ghdl --rename $entity; $extra write_verilog -noattr out.v") \
        >"$WORK/yosys.log" 2>&1 || {
        echo "FAIL: yosys failed"
        cat "$WORK/yosys.log" >&2
        exit 1
    }
}

# Run yosys + ghdl import only (no rename) + write_verilog
# Usage: run_norename entity_name [extra_yosys_commands]
run_norename() {
    local entity="$1"
    shift
    local extra="$*"
    (cd "$WORK" && yosys -m "$PLUGIN" \
        -p "ghdl $entity; $extra write_verilog -noattr before.v") \
        >"$WORK/yosys_nr.log" 2>&1 || {
        echo "FAIL: yosys (no rename) failed"
        cat "$WORK/yosys_nr.log" >&2
        exit 1
    }
}

# Assert that a port/wire name exists in the Verilog output
# Usage: assert_has_port filename port_name
assert_has_port() {
    local file="$WORK/$1"
    local name="$2"
    if grep -qw "$name" "$file"; then
        return 0
    else
        echo "FAIL: expected port '$name' not found in $1"
        echo "--- file contents ---"
        cat "$file"
        exit 1
    fi
}

# Assert that an escaped name does NOT exist in the output
# Usage: assert_no_escaped filename '\name[field]'
assert_no_escaped() {
    local file="$WORK/$1"
    local pattern="$2"
    if grep -qF "$pattern" "$file"; then
        echo "FAIL: escaped name '$pattern' still present in $1"
        echo "--- file contents ---"
        cat "$file"
        exit 1
    else
        return 0
    fi
}

# Assert that an escaped name exists in the output
# Usage: assert_has_escaped filename '\name[field]'
assert_has_escaped() {
    local file="$WORK/$1"
    local pattern="$2"
    if grep -qF "$pattern" "$file"; then
        return 0
    else
        echo "FAIL: expected escaped name '$pattern' not found in $1"
        echo "--- file contents ---"
        cat "$file"
        exit 1
    fi
}

# Assert that a string pattern exists in the VHDL output
# Usage: assert_has_vhdl filename pattern
assert_has_vhdl() {
    local file="$WORK/$1"
    local pattern="$2"
    if grep -qF "$pattern" "$file"; then
        return 0
    else
        echo "FAIL: expected pattern '$pattern' not found in $1"
        echo "--- file contents ---"
        cat "$file"
        exit 1
    fi
}

# Dump a file for debugging
dump() {
    echo "--- $1 ---"
    cat "$WORK/$1"
    echo "--- end ---"
}

# Clean up GHDL analysis data
clean() {
    "$GHDL" --remove --workdir="$WORK" 2>/dev/null || true
}