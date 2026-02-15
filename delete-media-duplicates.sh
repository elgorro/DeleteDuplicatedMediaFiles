#!/bin/bash
set -euo pipefail

# --- Usage / Help ---
usage() {
    echo "Usage: $(basename "$0") [--delete] [--verbose] [--help] <directory>"
    echo
    echo "Find duplicate media files by comparing FFMPEG-rendered MD5 hashes."
    echo
    echo "Options:"
    echo "  --delete   Actually delete duplicate files (default is dry-run)"
    echo "  --verbose  Show detailed ffmpeg processing output"
    echo "  --help     Show this help message"
    echo
    echo "Examples:"
    echo "  $(basename "$0") /path/to/music          # dry-run, show duplicates"
    echo "  $(basename "$0") --delete /path/to/music  # delete duplicates"
}

# --- Parse arguments ---
delete_mode=false
verbose=false
files_dir=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --delete)
            delete_mode=true
            shift
            ;;
        --verbose)
            verbose=true
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        -*)
            echo "Error: Unknown option '$1'"
            usage
            exit 1
            ;;
        *)
            files_dir="$1"
            shift
            ;;
    esac
done

if [[ -z "$files_dir" ]]; then
    echo "Error: No directory specified."
    usage
    exit 1
fi

if [[ ! -d "$files_dir" ]]; then
    echo "Error: '$files_dir' is not a directory or does not exist."
    exit 1
fi

# --- Check dependencies ---
if ! command -v ffmpeg &>/dev/null; then
    echo "Error: ffmpeg is not installed or not in PATH."
    exit 1
fi

# --- Generate MD5 hashes ---
# Use tab as delimiter between md5 and filepath (handles colons in filenames)
DELIM=$'\t'
md5array=()
count=0

while IFS= read -r -d '' file || [[ -n "$file" ]]; do
    filename=$(basename "$file")
    if [[ "$verbose" == true ]]; then
        echo ">>> $filename"
    fi

    md5=$(ffmpeg -loglevel quiet -v quiet -err_detect ignore_err -i "$file" -f md5 - < /dev/null 2>/dev/null || true)

    # Validate ffmpeg output
    if [[ -z "$md5" || "$md5" != MD5=* ]]; then
        echo "Warning: ffmpeg failed or returned unexpected output for '$file', skipping."
        continue
    fi

    md5array+=( "${md5}${DELIM}${file}" )
    ((++count))
done < <(find "$files_dir" -type f -not -type l -print0)

printf "Analyzed %s files in %s\n\n" "$count" "$files_dir"

if [[ ${#md5array[@]} -eq 0 ]]; then
    echo "No media files found."
    exit 0
fi

printf "Found %s files total\n" "${#md5array[@]}"

# --- Sort by MD5 ---
readarray -t sortedmd5 < <(for e in "${md5array[@]}"; do printf '%s\n' "$e"; done | sort)

# --- Split into md5 and fullpath arrays ---
md5=()
fullpath=()
for entry in "${sortedmd5[@]}"; do
    # Split on tab delimiter
    md5+=( "${entry%%${DELIM}*}" )
    fullpath+=( "${entry#*${DELIM}}" )
done

# --- Detect duplicates (keep first occurrence, mark later ones) ---
countdupes=0
dupes=()
kept=()

for ((idx=0; idx<${#md5[@]}-1; ++idx)); do
    if [[ "${md5[$idx]}" == "${md5[$idx+1]}" ]]; then
        ((++countdupes))
        dupes+=( "${fullpath[$idx+1]}" )
        kept+=( "${fullpath[$idx]}" )
        if [[ "$verbose" == true ]]; then
            echo "Duplicate: '${fullpath[$idx+1]}' (same as '${fullpath[$idx]}')"
        fi
    fi
done

printf "\nFound %s duplicate(s)\n" "$countdupes"

if [[ $countdupes -eq 0 ]]; then
    echo "No duplicates found."
    exit 0
fi

# --- Calculate space that would be saved ---
total_bytes=0
for f in "${dupes[@]}"; do
    size=$(stat --printf='%s' "$f" 2>/dev/null || echo 0)
    total_bytes=$((total_bytes + size))
done

# Human-readable size (pure bash, integer division)
if [[ $total_bytes -ge 1073741824 ]]; then
    size_human="$((total_bytes / 1073741824)) GB"
elif [[ $total_bytes -ge 1048576 ]]; then
    size_human="$((total_bytes / 1048576)) MB"
elif [[ $total_bytes -ge 1024 ]]; then
    size_human="$((total_bytes / 1024)) KB"
else
    size_human="${total_bytes} bytes"
fi

# --- Delete or dry-run ---
if [[ "$delete_mode" == true ]]; then
    for f in "${dupes[@]}"; do
        [[ -f "$f" ]] || continue
        echo "Deleting: $f"
        rm -- "$f"
    done
    printf "\nDeleted %s duplicate file(s), freed %s\n" "${#dupes[@]}" "$size_human"
else
    echo
    echo "Dry run — the following files would be deleted:"
    for i in "${!dupes[@]}"; do
        echo "  Remove: ${dupes[$i]}"
        echo "    Keep: ${kept[$i]}"
    done
    printf "\n%s duplicate(s) found, %s would be freed. Run with --delete to remove them.\n" "${#dupes[@]}" "$size_human"
fi
