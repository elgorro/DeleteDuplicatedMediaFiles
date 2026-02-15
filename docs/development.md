# Development

## Project structure

```
.
├── delete-media-duplicates.sh    # Main script
├── test-delete-media-duplicates.sh  # Test suite
├── docs/
│   ├── usage.md                  # End-user documentation
│   ├── development.md            # This file
│   └── testing.md                # Testing guide
├── readme.md
├── license.txt
└── .editorconfig
```

## Design decisions

### Tab-delimited internal storage

The script uses a tab character (`$'\t'`) as a delimiter between MD5 hashes and file paths in the internal array. This avoids issues with colons in filenames (which broke the original colon-delimited approach).

### Null-byte file iteration

Files are discovered with `find -print0` and read with `read -d ''` to correctly handle filenames containing spaces, newlines, or other special characters.

### ffmpeg stdin redirect

The ffmpeg command uses `< /dev/null` to prevent it from consuming stdin, which would otherwise interfere with the `while read` loop.

### Graceful ffmpeg failures

If ffmpeg cannot process a file (non-media, corrupt, etc.), the script catches the failure, prints a warning, and continues processing remaining files.

## Coding conventions

- **Shell**: Bash with `set -euo pipefail`
- **Formatting**: Follow `.editorconfig` settings (spaces, final newline)
- **Quoting**: All variables are double-quoted to prevent word splitting
- **Comments**: Inline comments for non-obvious logic only

## Making changes

1. Edit `delete-media-duplicates.sh`
2. Run the test suite to verify nothing is broken (see [testing.md](testing.md))
3. Test manually with a real media directory if the change affects file handling
4. Commit with a descriptive message
