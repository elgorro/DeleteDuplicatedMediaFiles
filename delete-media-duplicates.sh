#!/bin/bash

# Enhanced Delete Duplicated Media Files Script
# Version 2.0
# Original Author: Gregor Witiko Schmidlin
# Enhanced by: Assistant

set -euo pipefail  # Exit on error, undefined variables, and pipe failures

# Configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly VERSION="2.0"
readonly DELIMITER="|||"  # Use uncommon delimiter to avoid conflicts
readonly DEFAULT_THREADS=4
readonly DEFAULT_EXTENSIONS="mp3,mp4,flac,wav,m4a,aac,ogg,avi,mkv,mov,wmv,webm"

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Global variables
declare -g FILES_DIR=""
declare -g DRY_RUN=true
declare -g VERBOSE=false
declare -g LOG_FILE=""
declare -g MOVE_TO_TRASH=false
declare -g TRASH_DIR=""
declare -g KEEP_STRATEGY="first"  # first, last, largest, smallest, best_quality
declare -g EXTENSIONS=""
declare -g USE_PARALLEL=false
declare -g THREADS="$DEFAULT_THREADS"
declare -g HASH_CACHE_FILE=""
declare -g RECURSIVE=true
declare -g PROGRESS=true
declare -g TOTAL_FILES=0
declare -g PROCESSED_FILES=0
declare -g STATS_FILE=""

# Function: Display usage information
usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS] <directory>

Find and remove duplicate media files using FFMPEG content hashing.

OPTIONS:
    -h, --help              Show this help message
    -v, --version           Show version information
    -n, --dry-run           Show what would be deleted without actually deleting (default)
    -f, --force             Actually delete files (disable dry-run)
    -V, --verbose           Enable verbose output
    -l, --log FILE          Log operations to FILE
    -t, --trash DIR         Move duplicates to trash directory instead of deleting
    -k, --keep STRATEGY     Which duplicate to keep:
                           first (default), last, largest, smallest, best_quality
    -e, --extensions LIST   Comma-separated list of extensions to process
                           Default: $DEFAULT_EXTENSIONS
    -p, --parallel [N]      Use parallel processing with N threads (default: $DEFAULT_THREADS)
    -c, --cache FILE        Use cache file for hashes (speeds up repeated runs)
    -r, --no-recursive      Don't process subdirectories
    -q, --quiet             Disable progress output
    -s, --stats FILE        Save statistics to FILE

EXAMPLES:
    # Dry run (default)
    $SCRIPT_NAME /path/to/media

    # Actually delete duplicates
    $SCRIPT_NAME --force /path/to/media

    # Move duplicates to trash
    $SCRIPT_NAME --force --trash ~/.trash/media /path/to/media

    # Keep highest quality version
    $SCRIPT_NAME --force --keep best_quality /path/to/media

    # Use parallel processing with 8 threads
    $SCRIPT_NAME --force --parallel 8 /path/to/media

EOF
}

# Function: Log message
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    
    if [[ -n "$LOG_FILE" ]]; then
        echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    fi
    
    if [[ "$VERBOSE" == true ]] || [[ "$level" != "DEBUG" ]]; then
        case "$level" in
            ERROR)   echo -e "${RED}[ERROR]${NC} $message" >&2 ;;
            WARNING) echo -e "${YELLOW}[WARNING]${NC} $message" >&2 ;;
            INFO)    echo -e "${GREEN}[INFO]${NC} $message" ;;
            DEBUG)   [[ "$VERBOSE" == true ]] && echo -e "${BLUE}[DEBUG]${NC} $message" ;;
        esac
    fi
}

# Function: Show progress
show_progress() {
    if [[ "$PROGRESS" == true ]] && [[ $TOTAL_FILES -gt 0 ]]; then
        local percent=$((PROCESSED_FILES * 100 / TOTAL_FILES))
        printf "\rProgress: [%-50s] %d%% (%d/%d files)" \
               "$(printf '#%.0s' $(seq 1 $((percent / 2))))" \
               "$percent" "$PROCESSED_FILES" "$TOTAL_FILES"
    fi
}

# Function: Validate dependencies
check_dependencies() {
    local deps=("ffmpeg" "find" "sort" "cut")
    
    if [[ "$USE_PARALLEL" == true ]]; then
        deps+=("parallel")
    fi
    
    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            log ERROR "Required command '$cmd' not found. Please install it."
            exit 1
        fi
    done
}

# Function: Get file hash from cache or generate it
get_file_hash() {
    local file="$1"
    local hash=""
    
    # Check cache if enabled
    if [[ -n "$HASH_CACHE_FILE" ]] && [[ -f "$HASH_CACHE_FILE" ]]; then
        local cached_hash
        cached_hash=$(grep "^[^${DELIMITER}]*${DELIMITER}$(echo "$file" | sed 's/[[\.*^$()+?{|]/\\&/g')$" "$HASH_CACHE_FILE" 2>/dev/null | cut -d"$DELIMITER" -f1)
        if [[ -n "$cached_hash" ]]; then
            log DEBUG "Using cached hash for: $file"
            echo "$cached_hash"
            return 0
        fi
    fi
    
    # Generate hash using ffmpeg
    log DEBUG "Generating hash for: $file"
    if hash=$(ffmpeg -loglevel quiet -v error -i "$file" -f md5 - 2>/dev/null); then
        # Cache the hash if caching is enabled
        if [[ -n "$HASH_CACHE_FILE" ]]; then
            echo "${hash}${DELIMITER}${file}" >> "$HASH_CACHE_FILE"
        fi
        echo "$hash"
    else
        log WARNING "Failed to generate hash for: $file"
        return 1
    fi
}

# Function: Get file quality metrics
get_file_quality() {
    local file="$1"
    
    # Get bitrate using ffprobe
    local bitrate
    bitrate=$(ffprobe -v error -show_entries format=bit_rate -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null || echo "0")
    
    echo "$bitrate"
}

# Function: Process single file
process_file() {
    local file="$1"
    local hash
    
    if hash=$(get_file_hash "$file"); then
        echo "${hash}${DELIMITER}${file}"
        ((PROCESSED_FILES++))
        show_progress
    fi
}

# Function: Find media files
find_media_files() {
    local dir="$1"
    local find_opts=("-type" "f")
    
    if [[ "$RECURSIVE" == false ]]; then
        find_opts+=("-maxdepth" "1")
    fi
    
    # Build extension filter
    if [[ -n "$EXTENSIONS" ]]; then
        local ext_filter="("
        local first=true
        IFS=',' read -ra EXT_ARRAY <<< "$EXTENSIONS"
        for ext in "${EXT_ARRAY[@]}"; do
            if [[ "$first" == true ]]; then
                first=false
            else
                ext_filter+=" -o"
            fi
            ext_filter+=" -iname \"*.${ext}\""
        done
        ext_filter+=" )"
        
        eval find "$dir" "${find_opts[@]}" $ext_filter
    else
        find "$dir" "${find_opts[@]}"
    fi
}

# Function: Select which duplicate to keep
select_keeper() {
    local -a duplicates=("$@")
    local keeper=""
    
    case "$KEEP_STRATEGY" in
        first)
            keeper="${duplicates[0]}"
            ;;
        last)
            keeper="${duplicates[-1]}"
            ;;
        largest)
            local largest_size=0
            for file in "${duplicates[@]}"; do
                local size
                size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo 0)
                if [[ $size -gt $largest_size ]]; then
                    largest_size=$size
                    keeper="$file"
                fi
            done
            ;;
        smallest)
            local smallest_size=999999999999
            for file in "${duplicates[@]}"; do
                local size
                size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo 999999999999)
                if [[ $size -lt $smallest_size ]]; then
                    smallest_size=$size
                    keeper="$file"
                fi
            done
            ;;
        best_quality)
            local best_bitrate=0
            for file in "${duplicates[@]}"; do
                local bitrate
                bitrate=$(get_file_quality "$file")
                if [[ $bitrate -gt $best_bitrate ]]; then
                    best_bitrate=$bitrate
                    keeper="$file"
                fi
            done
            ;;
        *)
            keeper="${duplicates[0]}"
            ;;
    esac
    
    echo "$keeper"
}

# Function: Handle duplicate files
handle_duplicates() {
    local -a duplicates=("$@")
    local keeper
    keeper=$(select_keeper "${duplicates[@]}")
    
    log INFO "Found duplicate set (keeping: $(basename "$keeper")):"
    
    for file in "${duplicates[@]}"; do
        if [[ "$file" != "$keeper" ]]; then
            if [[ "$DRY_RUN" == true ]]; then
                log INFO "  [DRY RUN] Would remove: $file"
            else
                if [[ "$MOVE_TO_TRASH" == true ]]; then
                    local trash_path="${TRASH_DIR}/$(basename "$file")"
                    local counter=1
                    while [[ -e "$trash_path" ]]; do
                        trash_path="${TRASH_DIR}/$(basename "$file" .${file##*.})_${counter}.${file##*.}"
                        ((counter++))
                    done
                    log INFO "  Moving to trash: $file -> $trash_path"
                    mv "$file" "$trash_path"
                else
                    log INFO "  Deleting: $file"
                    rm -f "$file"
                fi
            fi
        else
            log INFO "  Keeping: $file"
        fi
    done
}

# Function: Main processing logic
process_directory() {
    local dir="$1"
    
    log INFO "Processing directory: $dir"
    
    # Count total files
    TOTAL_FILES=$(find_media_files "$dir" | wc -l)
    log INFO "Found $TOTAL_FILES media files to process"
    
    # Process files and collect hashes
    local temp_file
    temp_file=$(mktemp)
    
    if [[ "$USE_PARALLEL" == true ]]; then
        export -f get_file_hash log show_progress
        export HASH_CACHE_FILE VERBOSE LOG_FILE DELIMITER PROCESSED_FILES TOTAL_FILES PROGRESS
        
        find_media_files "$dir" | \
            parallel -j "$THREADS" process_file {} > "$temp_file"
    else
        while IFS= read -r file; do
            process_file "$file" >> "$temp_file"
        done < <(find_media_files "$dir")
    fi
    
    [[ "$PROGRESS" == true ]] && echo  # New line after progress bar
    
    # Sort by hash
    sort -t"$DELIMITER" -k1,1 "$temp_file" > "${temp_file}.sorted"
    
    # Find and handle duplicates
    local prev_hash=""
    local -a duplicate_group=()
    local duplicate_count=0
    local total_saved_space=0
    
    while IFS="$DELIMITER" read -r hash file; do
        if [[ "$hash" == "$prev_hash" ]]; then
            duplicate_group+=("$file")
        else
            if [[ ${#duplicate_group[@]} -gt 1 ]]; then
                handle_duplicates "${duplicate_group[@]}"
                ((duplicate_count += ${#duplicate_group[@]} - 1))
                
                # Calculate saved space
                for dup_file in "${duplicate_group[@]:1}"; do
                    local size
                    size=$(stat -f%z "$dup_file" 2>/dev/null || stat -c%s "$dup_file" 2>/dev/null || echo 0)
                    ((total_saved_space += size))
                done
            fi
            duplicate_group=("$file")
            prev_hash="$hash"
        fi
    done < "${temp_file}.sorted"
    
    # Handle last group
    if [[ ${#duplicate_group[@]} -gt 1 ]]; then
        handle_duplicates "${duplicate_group[@]}"
        ((duplicate_count += ${#duplicate_group[@]} - 1))
        
        for dup_file in "${duplicate_group[@]:1}"; do
            local size
            size=$(stat -f%z "$dup_file" 2>/dev/null || stat -c%s "$dup_file" 2>/dev/null || echo 0)
            ((total_saved_space += size))
        done
    fi
    
    # Clean up
    rm -f "$temp_file" "${temp_file}.sorted"
    
    # Report statistics
    log INFO "===== SUMMARY ====="
    log INFO "Total files processed: $PROCESSED_FILES"
    log INFO "Duplicate files found: $duplicate_count"
    log INFO "Space to be freed: $(numfmt --to=iec-i --suffix=B $total_saved_space 2>/dev/null || echo "${total_saved_space} bytes")"
    
    if [[ -n "$STATS_FILE" ]]; then
        cat > "$STATS_FILE" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "directory": "$dir",
  "total_files": $PROCESSED_FILES,
  "duplicates_found": $duplicate_count,
  "space_saved_bytes": $total_saved_space,
  "dry_run": $DRY_RUN,
  "keep_strategy": "$KEEP_STRATEGY"
}
EOF
        log INFO "Statistics saved to: $STATS_FILE"
    fi
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -v|--version)
                echo "$SCRIPT_NAME version $VERSION"
                exit 0
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -f|--force)
                DRY_RUN=false
                shift
                ;;
            -V|--verbose)
                VERBOSE=true
                shift
                ;;
            -l|--log)
                LOG_FILE="$2"
                shift 2
                ;;
            -t|--trash)
                MOVE_TO_TRASH=true
                TRASH_DIR="$2"
                shift 2
                ;;
            -k|--keep)
                KEEP_STRATEGY="$2"
                shift 2
                ;;
            -e|--extensions)
                EXTENSIONS="$2"
                shift 2
                ;;
            -p|--parallel)
                USE_PARALLEL=true
                if [[ -n "${2:-}" ]] && [[ "$2" =~ ^[0-9]+$ ]]; then
                    THREADS="$2"
                    shift 2
                else
                    shift
                fi
                ;;
            -c|--cache)
                HASH_CACHE_FILE="$2"
                shift 2
                ;;
            -r|--no-recursive)
                RECURSIVE=false
                shift
                ;;
            -q|--quiet)
                PROGRESS=false
                shift
                ;;
            -s|--stats)
                STATS_FILE="$2"
                shift 2
                ;;
            -*)
                log ERROR "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                FILES_DIR="$1"
                shift
                ;;
        esac
    done
}

# Main function
main() {
    # Parse arguments
    parse_arguments "$@"
    
    # Set default extensions if not specified
    if [[ -z "$EXTENSIONS" ]]; then
        EXTENSIONS="$DEFAULT_EXTENSIONS"
    fi
    
    # Validate input
    if [[ -z "$FILES_DIR" ]]; then
        log ERROR "No directory specified"
        usage
        exit 1
    fi
    
    if [[ ! -d "$FILES_DIR" ]]; then
        log ERROR "Directory does not exist: $FILES_DIR"
        exit 1
    fi
    
    # Initialize log file
    if [[ -n "$LOG_FILE" ]]; then
        mkdir -p "$(dirname "$LOG_FILE")"
        : > "$LOG_FILE"  # Clear/create log file
    fi
    
    # Initialize trash directory if needed
    if [[ "$MOVE_TO_TRASH" == true ]]; then
        if [[ -z "$TRASH_DIR" ]]; then
            log ERROR "Trash directory not specified"
            exit 1
        fi
        mkdir -p "$TRASH_DIR"
    fi
    
    # Initialize cache file if specified
    if [[ -n "$HASH_CACHE_FILE" ]]; then
        mkdir -p "$(dirname "$HASH_CACHE_FILE")"
        touch "$HASH_CACHE_FILE"
    fi
    
    # Check dependencies
    check_dependencies
    
    # Show configuration
    log INFO "Starting duplicate media file detection"
    log INFO "Configuration:"
    log INFO "  Directory: $FILES_DIR"
    log INFO "  Mode: $([ "$DRY_RUN" == true ] && echo "DRY RUN" || echo "LIVE")"
    log INFO "  Keep strategy: $KEEP_STRATEGY"
    log INFO "  Extensions: $EXTENSIONS"
    log INFO "  Recursive: $RECURSIVE"
    log INFO "  Parallel: $USE_PARALLEL (threads: $THREADS)"
    
    if [[ "$DRY_RUN" == true ]]; then
        log WARNING "DRY RUN MODE - No files will be deleted"
    else
        log WARNING "LIVE MODE - Files will be deleted!"
        read -p "Are you sure you want to continue? (yes/no): " confirmation
        if [[ "$confirmation" != "yes" ]]; then
            log INFO "Operation cancelled by user"
            exit 0
        fi
    fi
    
    # Process directory
    process_directory "$FILES_DIR"
    
    log INFO "Operation completed successfully"
}

# Run main function
main "$@"
