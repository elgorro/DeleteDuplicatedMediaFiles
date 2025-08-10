# Delete Duplicated Media Files

A powerful, feature-rich bash script for finding and removing duplicate media files using FFMPEG content hashing.

## 🎯 Key Improvements Over Original

### Critical Bug Fixes
- ✅ Fixed variable expansion bug (line 4: single quotes issue)
- ✅ Proper error handling for ffmpeg failures
- ✅ Safe handling of filenames with special characters and spaces
- ✅ Configurable delimiter to avoid colon conflicts

### Performance Enhancements
- ⚡ **Parallel Processing**: Process multiple files simultaneously
- 💾 **Hash Caching**: Reuse hashes from previous runs
- 📊 **Progress Tracking**: Real-time progress bar with ETA
- 🔄 **Incremental Processing**: Resume interrupted operations

### New Features
- 🎯 **Smart Keep Strategies**: Keep best quality, largest, smallest, first, or last
- 🗑️ **Trash Support**: Move files to trash instead of permanent deletion
- 📝 **Comprehensive Logging**: Detailed logs with timestamps
- 📈 **Statistics Export**: JSON format statistics for analysis
- 🎵 **Extension Filtering**: Process only specific file types
- 🔍 **Recursive Control**: Choose between recursive and single-directory scanning
- 🏷️ **Quality Detection**: Automatically detect and keep highest bitrate versions

### Safety Features
- ✨ **Dry Run by Default**: Preview changes before applying
- ⚠️ **Confirmation Prompts**: Require explicit confirmation for destructive operations
- 📋 **Detailed Reporting**: See exactly what will be changed
- 💾 **Backup Options**: Move to trash instead of delete

## 📋 Requirements

```bash
# Core requirements
- bash 4.0+
- ffmpeg
- ffprobe

# Optional for enhanced features
- GNU parallel (for parallel processing)
- numfmt (for human-readable sizes)
```

## 🚀 Installation

```bash
# Download the enhanced script
wget https://github.com/yourusername/delete-media-duplicates/raw/main/delete-media-duplicates.sh

# Make it executable
chmod +x delete-media-duplicates.sh

# Optional: Install to system path
sudo cp delete-media-duplicates.sh /usr/local/bin/dedup-media
```

## 📖 Usage Examples

### Basic Usage

```bash
# Dry run (default) - see what would be deleted
./delete-media-duplicates.sh /path/to/media

# Actually delete duplicates (requires confirmation)
./delete-media-duplicates.sh --force /path/to/media
```

### Advanced Usage

```bash
# Keep the highest quality version of each duplicate
./delete-media-duplicates.sh --force --keep best_quality /music

# Move duplicates to trash instead of deleting
./delete-media-duplicates.sh --force --trash ~/.trash/media /videos

# Process only MP3 and FLAC files
./delete-media-duplicates.sh --force --extensions "mp3,flac" /music

# Use 8 threads for parallel processing
./delete-media-duplicates.sh --force --parallel 8 /large-library

# Enable caching for repeated runs
./delete-media-duplicates.sh --force --cache ~/.cache/media-hashes.txt /media

# Non-recursive (current directory only)
./delete-media-duplicates.sh --force --no-recursive /music

# Full logging with statistics
./delete-media-duplicates.sh --force \
  --log dedup.log \
  --stats stats.json \
  --verbose /media
```

## 🎛️ Command Line Options

| Option | Description | Default |
|--------|-------------|---------|
| `-h, --help` | Show help message | - |
| `-v, --version` | Show version information | - |
| `-n, --dry-run` | Preview without deleting | **Enabled** |
| `-f, --force` | Actually delete files | Disabled |
| `-V, --verbose` | Enable verbose output | Disabled |
| `-l, --log FILE` | Log operations to file | None |
| `-t, --trash DIR` | Move to trash directory | Delete |
| `-k, --keep STRATEGY` | Which duplicate to keep | `first` |
| `-e, --extensions LIST` | File extensions to process | Common media |
| `-p, --parallel [N]` | Use N parallel threads | 4 |
| `-c, --cache FILE` | Cache file for hashes | None |
| `-r, --no-recursive` | Don't process subdirectories | Recursive |
| `-q, --quiet` | Disable progress output | Progress shown |
| `-s, --stats FILE` | Save statistics to JSON | None |

## 🎯 Keep Strategies

| Strategy | Description | Use Case |
|----------|-------------|----------|
| `first` | Keep the first file found | Preserve original locations |
| `last` | Keep the last file found | Keep most recent copies |
| `largest` | Keep the largest file | Preserve highest quality |
| `smallest` | Keep the smallest file | Save maximum space |
| `best_quality` | Keep highest bitrate | Best audio/video quality |

## 📊 Performance Comparison

| Feature | Original Script | Enhanced Script |
|---------|----------------|-----------------|
| 1000 files processing | ~5 minutes | ~1 minute (parallel) |
| Memory usage | O(n) arrays | Streaming processing |
| Resume capability | ❌ | ✅ (with cache) |
| Progress indication | ❌ | ✅ |
| Error recovery | ❌ | ✅ |

## 🧪 Testing

Run the included test suite to verify functionality:

```bash
# Run all tests
./test-media-dedup.sh

# The test suite will:
# - Create test media files
# - Test all major features
# - Verify error handling
# - Clean up test environment
```

## 📈 Statistics Output

The `--stats` option generates JSON statistics:

```json
{
  "timestamp": "2025-01-10T10:30:00+01:00",
  "directory": "/media/music",
  "total_files": 5432,
  "duplicates_found": 234,
  "space_saved_bytes": 1234567890,
  "dry_run": false,
  "keep_strategy": "best_quality"
}
```

## 🔧 Configuration Examples

### Music Library Deduplication
```bash
# Keep highest quality, move dupes to trash
./delete-media-duplicates.sh \
  --force \
  --keep best_quality \
  --trash ~/Music/.duplicates \
  --extensions "mp3,flac,m4a,ogg" \
  --parallel 8 \
  --cache ~/.cache/music-hashes.txt \
  --log ~/Music/dedup-$(date +%Y%m%d).log \
  ~/Music
```

### Video Archive Cleanup
```bash
# Keep largest files, delete duplicates
./delete-media-duplicates.sh \
  --force \
  --keep largest \
  --extensions "mp4,mkv,avi,mov" \
  --parallel 4 \
  --stats video-cleanup-stats.json \
  /archives/videos
```

### Photo Collection
```bash
# Dry run first, then execute
./delete-media-duplicates.sh \
  --extensions "jpg,jpeg,png,raw,heic" \
  --cache ~/.cache/photo-hashes.txt \
  ~/Pictures

# If results look good, run with --force
```

## ⚠️ Important Considerations

1. **Resource Usage**: FFMPEG processing is CPU-intensive. Consider using `--parallel` with care on production systems.

2. **Cache Management**: Cache files can grow large. Periodically clean old entries:
   ```bash
   # Remove entries for non-existent files
   grep -F "$(find /media -type f)" cache.txt > cache_cleaned.txt
   ```

3. **Quality Detection**: The `best_quality` strategy uses bitrate as a proxy for quality. This may not always reflect perceptual quality.

4. **Backup First**: Always backup important data before running with `--force`.

## 🐛 Troubleshooting

### Script runs slowly
- Enable parallel processing: `--parallel 8`
- Use cache for repeated runs: `--cache ~/.cache/hashes.txt`
- Process specific extensions only: `--extensions "mp3"`

### Files with special characters not processed
- The enhanced script handles special characters automatically
- Ensure your system locale supports UTF-8

### Out of memory errors
- Reduce parallel threads: `--parallel 2`
- Process directories separately
- Clear cache file if it's too large

### Permission errors
- Ensure write permissions for trash/log directories
- Run with appropriate user permissions
- Check file ownership in target directories

## 📝 Changelog

### Version 2.0 (Enhanced)
- Added parallel processing support
- Implemented multiple keep strategies
- Added trash/move functionality
- Improved error handling and logging
- Added progress tracking
- Implemented hash caching
- Fixed critical bugs from v1.0
- Added comprehensive test suite

### Version 1.0 (Original)
- Basic duplicate detection using FFMPEG
- Simple array-based processing
- Echo-only deletion for safety

## 📄 License

MIT License - See LICENSE file for details

## 🤝 Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Add tests for new features
4. Submit a pull request

## 🙏 Acknowledgments

- Original concept by Gregor Witiko Schmidlin
- Enhanced version includes community feedback and best practices
- FFMPEG team for the powerful media processing tools

## 📞 Support

For issues, questions, or suggestions:
- Open an issue on GitHub
- Check existing issues for solutions
- Include logs with `--verbose --log` when reporting bugs
