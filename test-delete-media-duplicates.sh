#!/bin/bash
set -euo pipefail

SCRIPT="${1:-./delete-media-duplicates.sh}"
TEST_DIR=$(mktemp -d)
passed=0
failed=0
total=0

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
BOLD='\033[1m'
RESET='\033[0m'

# --- Helpers ---

# Create a small wav file with a given frequency
# Usage: make_wav <output_path> [frequency]
make_wav() {
    local out="$1"
    local freq="${2:-440}"
    ffmpeg -y -loglevel quiet -f lavfi -i "sine=frequency=${freq}:duration=1" "$out"
}

# Run test function, capture result
# Usage: run_test "Test name" test_function
run_test() {
    local name="$1"
    local func="$2"
    ((++total))
    printf "${BOLD}[TEST %2d]${RESET} %-50s " "$total" "$name"
    local result
    if result=$("$func" 2>&1); then
        ((++passed))
        printf "${GREEN}PASS${RESET}\n"
    else
        ((++failed))
        printf "${RED}FAIL${RESET}\n"
        # Indent failure details
        echo "$result" | sed 's/^/         /'
    fi
}

# Assert exit code
# Usage: assert_exit <expected> <actual> [context]
assert_exit() {
    local expected="$1" actual="$2" ctx="${3:-}"
    if [[ "$actual" -ne "$expected" ]]; then
        echo "Expected exit code $expected, got $actual. $ctx"
        return 1
    fi
}

# Assert output contains string
# Usage: assert_contains <output> <substring>
assert_contains() {
    local output="$1" substring="$2"
    if [[ "$output" != *"$substring"* ]]; then
        echo "Expected output to contain: '$substring'"
        echo "Got: $output"
        return 1
    fi
}

# Assert file exists
assert_file_exists() {
    if [[ ! -f "$1" ]]; then
        echo "Expected file to exist: $1"
        return 1
    fi
}

# Assert file does not exist
assert_file_missing() {
    if [[ -f "$1" ]]; then
        echo "Expected file to NOT exist: $1"
        return 1
    fi
}

# --- Test cases ---

test_no_arguments() {
    local out rc=0
    out=$(bash "$SCRIPT" 2>&1) || rc=$?
    assert_exit 1 "$rc" "no arguments should fail"
    assert_contains "$out" "Usage"
}

test_help_flag() {
    local out rc=0
    out=$(bash "$SCRIPT" --help 2>&1) || rc=$?
    assert_exit 0 "$rc" "--help should succeed"
    assert_contains "$out" "Usage"
}

test_nonexistent_directory() {
    local out rc=0
    out=$(bash "$SCRIPT" "/tmp/nonexistent_dir_$$_$(date +%s)" 2>&1) || rc=$?
    assert_exit 1 "$rc" "nonexistent dir should fail"
    assert_contains "$out" "not a directory"
}

test_empty_directory() {
    local dir="$TEST_DIR/empty"
    mkdir -p "$dir"

    local out rc=0
    out=$(bash "$SCRIPT" "$dir" 2>&1) || rc=$?
    assert_exit 0 "$rc" "empty dir should succeed"
    assert_contains "$out" "No media files"

    rm -rf "$dir"
}

test_no_duplicates() {
    local dir="$TEST_DIR/no_dupes"
    mkdir -p "$dir"
    make_wav "$dir/a.wav" 440
    make_wav "$dir/b.wav" 880

    local out rc=0
    out=$(bash "$SCRIPT" "$dir" 2>&1) || rc=$?
    assert_exit 0 "$rc" "no duplicates should succeed"
    assert_contains "$out" "No duplicates found"

    rm -rf "$dir"
}

test_duplicates_dry_run() {
    local dir="$TEST_DIR/dry_run"
    mkdir -p "$dir"
    make_wav "$dir/original.wav" 440
    cp "$dir/original.wav" "$dir/copy.wav"
    make_wav "$dir/unique.wav" 880

    local out rc=0
    out=$(bash "$SCRIPT" "$dir" 2>&1) || rc=$?
    assert_exit 0 "$rc" "dry run should succeed"
    assert_contains "$out" "1 duplicate"
    assert_contains "$out" "Dry run"
    # All files should still exist
    assert_file_exists "$dir/original.wav"
    assert_file_exists "$dir/copy.wav"
    assert_file_exists "$dir/unique.wav"

    rm -rf "$dir"
}

test_colons_in_filename() {
    local dir="$TEST_DIR/colons"
    mkdir -p "$dir"
    make_wav "$dir/song:remix:v2.wav" 440
    cp "$dir/song:remix:v2.wav" "$dir/song:remix:v2_copy.wav"

    local out rc=0
    out=$(bash "$SCRIPT" "$dir" 2>&1) || rc=$?
    assert_exit 0 "$rc" "colons in filename should succeed"
    assert_contains "$out" "1 duplicate"

    rm -rf "$dir"
}

test_spaces_in_directory_path() {
    local dir="$TEST_DIR/test dir with spaces"
    mkdir -p "$dir"
    make_wav "$dir/a.wav" 440
    cp "$dir/a.wav" "$dir/b.wav"

    local out rc=0
    out=$(bash "$SCRIPT" "$dir" 2>&1) || rc=$?
    assert_exit 0 "$rc" "spaces in path should succeed"
    assert_contains "$out" "1 duplicate"

    rm -rf "$dir"
}

test_delete_mode() {
    local dir="$TEST_DIR/delete_mode"
    mkdir -p "$dir"
    make_wav "$dir/original.wav" 440
    cp "$dir/original.wav" "$dir/copy.wav"

    local out rc=0
    out=$(bash "$SCRIPT" --delete "$dir" 2>&1) || rc=$?
    assert_exit 0 "$rc" "--delete should succeed"
    assert_contains "$out" "Deleted 1 duplicate"

    # Exactly one of the two should remain
    local remaining
    remaining=$(find "$dir" -name '*.wav' -type f | wc -l)
    if [[ "$remaining" -ne 1 ]]; then
        echo "Expected 1 file remaining, found $remaining"
        return 1
    fi

    rm -rf "$dir"
}

test_verbose_flag() {
    local dir="$TEST_DIR/verbose"
    mkdir -p "$dir"
    make_wav "$dir/a.wav" 440

    local out rc=0
    out=$(bash "$SCRIPT" --verbose "$dir" 2>&1) || rc=$?
    assert_exit 0 "$rc" "--verbose should succeed"
    assert_contains "$out" ">>>"

    rm -rf "$dir"
}

test_non_media_file() {
    local dir="$TEST_DIR/non_media"
    mkdir -p "$dir"
    echo "just a text file" > "$dir/notes.txt"

    local out rc=0
    out=$(bash "$SCRIPT" "$dir" 2>&1) || rc=$?
    assert_exit 0 "$rc" "non-media file should not crash"
    assert_contains "$out" "Warning"

    rm -rf "$dir"
}

# --- Run all tests ---
echo "============================================"
echo " Test suite for delete-media-duplicates.sh"
echo " Script under test: $SCRIPT"
echo "============================================"
echo

run_test "No arguments → exits non-zero with Usage" test_no_arguments
run_test "--help → exits 0 with Usage" test_help_flag
run_test "Nonexistent directory → error" test_nonexistent_directory
run_test "Empty directory → No media files" test_empty_directory
run_test "No duplicates → No duplicates found" test_no_duplicates
run_test "Duplicates found (dry-run)" test_duplicates_dry_run
run_test "Colons in filenames" test_colons_in_filename
run_test "Spaces in directory path" test_spaces_in_directory_path
run_test "--delete mode removes duplicates" test_delete_mode
run_test "--verbose shows >>> details" test_verbose_flag
run_test "Non-media file → warning, skipped" test_non_media_file

# --- Cleanup ---
rm -rf "$TEST_DIR"

# --- Summary ---
echo
echo "============================================"
if [[ $failed -eq 0 ]]; then
    printf " ${GREEN}All $passed tests passed!${RESET}\n"
else
    printf " ${GREEN}$passed passed${RESET}, ${RED}$failed failed${RESET}\n"
fi
echo "============================================"

exit "$failed"
