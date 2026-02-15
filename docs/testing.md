# Testing

## Running the test suite

```bash
# Run with default script path (./delete-media-duplicates.sh)
bash test-delete-media-duplicates.sh

# Run against a specific script path
bash test-delete-media-duplicates.sh /path/to/delete-media-duplicates.sh
```

## Parameters

| Parameter | Description                          | Default                          |
|-----------|--------------------------------------|----------------------------------|
| `$1`      | Path to the script under test        | `./delete-media-duplicates.sh`   |

Test fixtures are auto-created under `/tmp` and cleaned up after each run.

## Test cases

| #  | Test case                    | What it verifies                                         |
|----|------------------------------|----------------------------------------------------------|
| 1  | No arguments                 | Exits non-zero, shows usage                              |
| 2  | `--help` flag                | Exits 0, shows usage                                    |
| 3  | Nonexistent directory        | Exits non-zero, reports "not a directory"                |
| 4  | Empty directory              | Exits 0, reports "No media files"                        |
| 5  | No duplicates                | Exits 0, reports "No duplicates found"                   |
| 6  | Duplicates (dry-run)         | Reports duplicate count, files remain untouched          |
| 7  | Colons in filenames          | Handles `:` in filenames without errors                  |
| 8  | Spaces in directory path     | Works correctly with spaces in the path                  |
| 9  | `--delete` mode              | Actually removes duplicates, keeps original              |
| 10 | `--verbose` flag             | Output contains `>>>` file details                       |
| 11 | Non-media file               | Shows warning, skips gracefully                          |

## How fixtures work

The test suite uses ffmpeg to generate small WAV files as fixtures:

- **Duplicate files**: Generated once, then copied (`cp`) to produce identical content
- **Unique files**: Generated with a different frequency (e.g. 440 Hz vs 880 Hz)
- **Non-media files**: Plain text created with `echo`

Each test function creates its own subdirectory, runs assertions, and cleans up.

## Adding a new test

1. Write a test function following the existing pattern:
   ```bash
   test_my_new_case() {
       local dir="$TEST_DIR/my_case"
       mkdir -p "$dir"
       # ... set up fixtures ...

       local out rc=0
       out=$(bash "$SCRIPT" "$dir" 2>&1) || rc=$?
       assert_exit 0 "$rc" "description"
       assert_contains "$out" "expected string"

       rm -rf "$dir"
   }
   ```

2. Register it at the bottom of the file:
   ```bash
   run_test "My new case description" test_my_new_case
   ```

## Available assertion helpers

| Helper                | Usage                                    |
|-----------------------|------------------------------------------|
| `assert_exit`         | `assert_exit <expected> <actual> [msg]`  |
| `assert_contains`     | `assert_contains <output> <substring>`   |
| `assert_file_exists`  | `assert_file_exists <path>`              |
| `assert_file_missing` | `assert_file_missing <path>`             |
