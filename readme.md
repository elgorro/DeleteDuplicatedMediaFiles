# Delete Duplicated Media Files

Find and remove duplicate media files by comparing their actual audio/video content — not just filenames or metadata.

Traditional duplicate finders hash the entire file, so two files with identical audio but different ID3 tags or filenames slip through. This tool uses [ffmpeg's MD5 muxer](https://ffmpeg.org/ffmpeg-all.html#md5-1) to hash only the decoded media stream, catching duplicates that other tools miss.

## Quick start

```bash
# Dry-run: find duplicates without deleting anything
./delete-media-duplicates.sh /path/to/media/

# Delete duplicates (keeps one copy of each)
./delete-media-duplicates.sh --delete /path/to/media/

# Verbose output
./delete-media-duplicates.sh --verbose /path/to/media/
```

## Requirements

- **Bash** 4.0+
- **[ffmpeg](https://ffmpeg.org/)**

## Options

| Flag        | Description                                   |
|-------------|-----------------------------------------------|
| `--delete`  | Remove duplicates (default is dry-run)        |
| `--verbose` | Show per-file processing details              |
| `--help`    | Show usage information                        |

## Supported formats

Any format ffmpeg can decode: MP3, FLAC, WAV, OGG, AAC, MP4, AVI, MKV, and [many more](https://www.ffmpeg.org/ffmpeg-codecs.html). Non-media files are skipped with a warning.

## Documentation

See the [docs/](docs/) folder for detailed guides:

- [Usage](docs/usage.md) — full usage instructions and performance notes
- [Development](docs/development.md) — project structure and design decisions
- [Testing](docs/testing.md) — running and extending the test suite

## Acknowledgments

Built on the shoulders of two giants:

- **[ffmpeg](https://ffmpeg.org/)** — the Swiss Army knife of media processing, making content-based hashing possible
- **[Bash](https://www.gnu.org/software/bash/)** & the **GNU/Linux coreutils** — proving that shell scripts can still get serious work done

## License

[MIT](license.txt)
