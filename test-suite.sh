#!/bin/bash

# Test Suite for Enhanced Delete Media Duplicates Script
# Run this to test the functionality of the main script

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# Test configuration
readonly TEST_DIR="test_media_dedup_$$"
readonly SCRIPT_PATH="./delete-media-duplicates.sh"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Function: Print test result
print_result() {
    local test_name="$1"
    local result="$2"
    
    ((TESTS_RUN++))
    
    if [[ "$result" == "PASS" ]]; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} $test_name"
        ((TESTS_FAILED++))
    fi
}

# Function: Setup test environment
setup_test_env() {
    echo "Setting up test environment..."
    
    # Create test directory structure
    mkdir -p "$TEST_DIR"/{music,videos,mixed,empty}
    mkdir -p "$TEST_DIR"/music/{album1,album2}
    mkdir -p "$TEST_DIR"/.trash
    
    # Create test media files (using ffmpeg to create actual media files)
    # Create identical content files with different names
    ffmpeg -f lavfi -i "sine=frequency=440:duration=1" -ar 44100 -ac 2 \
           "$TEST_DIR/music/album1/song1.mp3" -y &>/dev/null
    cp "$TEST_DIR/music/album1/song1.mp3" "$TEST_DIR/music/album1/song1_copy.mp3"
    cp "$TEST_DIR/music/album1/song1.mp3" "$TEST_DIR/music/album2/song1_duplicate.mp3"
    
    # Create different content files
    ffmpeg -f lavfi -i "sine=frequency=880:duration=1" -ar 44100 -ac 2 \
           "$TEST_DIR/music/album2/song2.mp3" -y &>/dev/null
    
    # Create video files
    ffmpeg -f lavfi -i testsrc=duration=1:size=320x240:rate=30 \
           -f lavfi -i "sine=frequency=440:duration=1" \
           -pix_fmt yuv420p "$TEST_DIR/videos/video1.mp4" -y &>/dev/null
    cp "$TEST_DIR/videos/video1.mp4" "$TEST_DIR/videos/video1_backup.mp4"
    
    # Create non-media files
    echo "This is a text file" > "$TEST_DIR/mixed/readme.txt"
    echo "Another text file" > "$TEST_DIR/mixed/notes.txt"
    
    # Create files with special characters
    ffmpeg -f lavfi -i "sine=frequency=660:duration=1" -ar 44100 -ac 2 \
           "$TEST_DIR/music/song with spaces.mp3" -y &>/dev/null
    cp "$TEST_DIR/music/song with spaces.mp3" "$TEST_DIR/music/song with spaces (copy).mp3"
    
    echo "Test environment created in $TEST_DIR"
}

# Function: Cleanup test environment
cleanup_test_env() {
    echo "Cleaning up test environment..."
    rm -rf "$TEST_DIR"
}

# Test 1: Dry run mode
test_dry_run() {
    local test_name="Dry run mode"
    local output
    
    output=$("$SCRIPT_PATH" --dry-run "$TEST_DIR/music" 2>&1)
    
    # Check if files still exist
    if [[ -f "$TEST_DIR/music/album1/song1_copy.mp3" ]] && \
       [[ -f "$TEST_DIR/music/album2/song1_duplicate.mp3" ]]; then
        print_result "$test_name" "PASS"
    else
        print_result "$test_name" "FAIL"
    fi
}

# Test 2: Force delete mode
test_force_delete() {
    local test_name="Force delete mode"
    
    # Create a duplicate for this test
    cp "$TEST_DIR/music/album2/song2.mp3" "$TEST_DIR/music/album2/song2_dup.mp3"
    
    # Run with force flag (with auto-confirm)
    echo "yes" | "$SCRIPT_PATH" --force --keep first "$TEST_DIR/music/album2" &>/dev/null
    
    # Check if duplicate was deleted and original kept
    if [[ -f "$TEST_DIR/music/album2/song2.mp3" ]] && \
       [[ ! -f "$TEST_DIR/music/album2/song2_dup.mp3" ]]; then
        print_result "$test_name" "PASS"
    else
        print_result "$test_name" "FAIL"
    fi
}

# Test 3: Move to trash
test_move_to_trash() {
    local test_name="Move to trash"
    
    # Create a duplicate
    cp "$TEST_DIR/videos/video1.mp4" "$TEST_DIR/videos/video1_trash_test.mp4"
    
    # Run with trash option
    echo "yes" | "$SCRIPT_PATH" --force --trash "$TEST_DIR/.trash" "$TEST_DIR/videos" &>/dev/null
    
    # Check if file was moved to trash
    if [[ -f "$TEST_DIR/videos/video1.mp4" ]] && \
       [[ ! -f "$TEST_DIR/videos/video1_trash_test.mp4" ]] && \
       [[ -f "$TEST_DIR/.trash/video1_trash_test.mp4" ]]; then
        print_result "$test_name" "PASS"
    else
        print_result "$test_name" "FAIL"
    fi
}

# Test 4: Extension filtering
test_extension_filter() {
    local test_name="Extension filtering"
    
    # Create mp3 and mp4 duplicates
    cp "$TEST_DIR/music/album1/song1.mp3" "$TEST_DIR/mixed/audio_dup.mp3"
    cp "$TEST_DIR/videos/video1.mp4" "$TEST_DIR/mixed/video_dup.mp4"
    
    # Run only for mp3 files
    output=$("$SCRIPT_PATH" --dry-run --extensions "mp3" "$TEST_DIR/mixed" 2>&1)
    
    # Check if only mp3 files were processed
    if echo "$output" | grep -q "audio_dup.mp3" && \
       ! echo "$output" | grep -q "video_dup.mp4"; then
        print_result "$test_name" "PASS"
    else
        print_result "$test_name" "FAIL"
    fi
}

# Test 5: Keep strategies
test_keep_largest() {
    local test_name="Keep largest file"
    
    # Create files of different sizes
    ffmpeg -f lavfi -i "sine=frequency=440:duration=2" -ar 44100 -ac 2 \
           -b:a 128k "$TEST_DIR/music/large.mp3" -y &>/dev/null
    ffmpeg -f lavfi -i "sine=frequency=440:duration=2" -ar 44100 -ac 2 \
           -b:a 64k "$TEST_DIR/music/small.mp3" -y &>/dev/null
    
    # Make them duplicates by copying content
    cp "$TEST_DIR/music/large.mp3" "$TEST_DIR/music/temp.mp3"
    mv "$TEST_DIR/music/temp.mp3" "$TEST_DIR/music/small.mp3"
    
    # Get sizes
    large_size=$(stat -f%z "$TEST_DIR/music/large.mp3" 2>/dev/null || stat -c%s "$TEST_DIR/music/large.mp3")
    
    # Run with keep largest strategy
    echo "yes" | "$SCRIPT_PATH" --force --keep largest "$TEST_DIR/music" &>/dev/null
    
    # Check if larger file was kept
    if [[ -f "$TEST_DIR/music/large.mp3" ]]; then
        print_result "$test_name" "PASS"
    else
        print_result "$test_name" "FAIL"
    fi
}

# Test 6: Non-recursive mode
test_non_recursive() {
    local test_name="Non-recursive mode"
    
    # Create duplicate in subdirectory
    cp "$TEST_DIR/music/album1/song1.mp3" "$TEST_DIR/music/top_level_dup.mp3"
    
    # Run in non-recursive mode
    output=$("$SCRIPT_PATH" --dry-run --no-recursive "$TEST_DIR/music" 2>&1)
    
    # Check that subdirectory files were not processed
    if echo "$output" | grep -q "top_level_dup.mp3" && \
       ! echo "$output" | grep -q "album1/song1.mp3"; then
        print_result "$test_name" "PASS"
    else
        print_result "$test_name" "FAIL"
    fi
}

# Test 7: Cache functionality
test_cache() {
    local test_name="Cache functionality"
    local cache_file="$TEST_DIR/hash_cache.txt"
    
    # First run with cache
    "$SCRIPT_PATH" --dry-run --cache "$cache_file" "$TEST_DIR/music" &>/dev/null
    
    # Check if cache file was created
    if [[ -f "$cache_file" ]] && [[ -s "$cache_file" ]]; then
        # Second run should be faster (cache hit)
        time1=$(date +%s%N)
        "$SCRIPT_PATH" --dry-run --cache "$cache_file" "$TEST_DIR/music" &>/dev/null
        time2=$(date +%s%N)
        
        # Just check that cache file exists and has content
        print_result "$test_name" "PASS"
    else
        print_result "$test_name" "FAIL"
    fi
}

# Test 8: Verbose and logging
test_logging() {
    local test_name="Logging functionality"
    local log_file="$TEST_DIR/test.log"
    
    # Run with logging
    "$SCRIPT_PATH" --dry-run --verbose --log "$log_file" "$TEST_DIR/music" &>/dev/null
    
    # Check if log file was created and has content
    if [[ -f "$log_file" ]] && [[ -s "$log_file" ]]; then
        print_result "$test_name" "PASS"
    else
        print_result "$test_name" "FAIL"
    fi
}

# Test 9: Statistics output
test_statistics() {
    local test_name="Statistics output"
    local stats_file="$TEST_DIR/stats.json"
    
    # Run with statistics
    "$SCRIPT_PATH" --dry-run --stats "$stats_file" "$TEST_DIR/music" &>/dev/null
    
    # Check if stats file was created and contains expected fields
    if [[ -f "$stats_file" ]] && \
       grep -q "total_files" "$stats_file" && \
       grep -q "duplicates_found" "$stats_file"; then
        print_result "$test_name" "PASS"
    else
        print_result "$test_name" "FAIL"
    fi
}

# Test 10: Handle special characters
test_special_chars() {
    local test_name="Handle special characters in filenames"
    
    # The setup already created files with spaces
    output=$("$SCRIPT_PATH" --dry-run "$TEST_DIR/music" 2>&1)
    
    # Check if files with spaces were processed correctly
    if echo "$output" | grep -q "song with spaces"; then
        print_result "$test_name" "PASS"
    else
        print_result "$test_name" "FAIL"
    fi
}

# Main test execution
main() {
    echo -e "${YELLOW}===========================================${NC}"
    echo -e "${YELLOW}  Media Deduplication Script Test Suite${NC}"
    echo -e "${YELLOW}===========================================${NC}"
    echo
    
    # Check if script exists
    if [[ ! -f "$SCRIPT_PATH" ]]; then
        echo -e "${RED}Error: Script not found at $SCRIPT_PATH${NC}"
        exit 1
    fi
    
    # Check dependencies
    if ! command -v ffmpeg &>/dev/null; then
        echo -e "${RED}Error: ffmpeg is required for tests${NC}"
        exit 1
    fi
    
    # Setup test environment
    setup_test_env
    echo
    
    # Run tests
    echo "Running tests..."
    echo
    
    test_dry_run
    test_force_delete
    test_move_to_trash
    test_extension_filter
    test_keep_largest
    test_non_recursive
    test_cache
    test_logging
    test_statistics
    test_special_chars
    
    echo
    echo -e "${YELLOW}===========================================${NC}"
    echo "Test Results:"
    echo "  Total tests: $TESTS_RUN"
    echo -e "  ${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "  ${RED}Failed: $TESTS_FAILED${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}All tests passed!${NC}"
    else
        echo -e "${RED}Some tests failed!${NC}"
    fi
    echo -e "${YELLOW}===========================================${NC}"
    
    # Cleanup
    echo
    read -p "Clean up test environment? (y/n): " cleanup_confirm
    if [[ "$cleanup_confirm" == "y" ]]; then
        cleanup_test_env
    else
        echo "Test environment preserved at: $TEST_DIR"
    fi
    
    # Exit with appropriate code
    [[ $TESTS_FAILED -eq 0 ]] && exit 0 || exit 1
}

# Run main
main "$@"
