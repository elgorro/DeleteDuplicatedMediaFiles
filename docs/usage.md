# Usage

## Prerequisites

- **Bash** 4.0+
- **ffmpeg** installed and available in `PATH`

## Quick start

```bash
# Dry-run: show duplicates without deleting anything
./delete-media-duplicates.sh /path/to/media/

# Actually delete duplicates
./delete-media-duplicates.sh --delete /path/to/media/

# Verbose output showing each file being processed
./delete-media-duplicates.sh --verbose /path/to/media/

# Combine flags
./delete-media-duplicates.sh --delete --verbose /path/to/media/
```

## Options

| Flag        | Description                                      |
|-------------|--------------------------------------------------|
| `--delete`  | Delete duplicate files (default is dry-run)      |
| `--verbose` | Show detailed processing output for each file    |
| `--help`    | Show help message                                |

## How it works

1. Scans the given directory recursively for all files
2. Computes an [ffmpeg MD5 hash](https://ffmpeg.org/ffmpeg-all.html#md5-1) of each file's **media content only** (ignoring metadata/tags)
3. Groups files by identical hashes
4. Reports duplicates (dry-run) or deletes them (`--delete`), keeping the first occurrence

This approach catches duplicates that traditional file-hash tools miss — files with identical audio/video content but different ID3 tags, filenames, or metadata.

## Supported formats

Any format supported by ffmpeg: MP3, FLAC, WAV, OGG, AAC, MP4, AVI, MKV, and [many more](https://www.ffmpeg.org/ffmpeg-codecs.html).

Non-media files (e.g. `.txt`, `.jpg`) are skipped with a warning.

## Performance notes

- ffmpeg renders each file to compute the hash, so processing is CPU-intensive
- Large libraries may take significant time — consider processing subdirectories separately
- The script handles filenames with special characters (spaces, colons) correctly
