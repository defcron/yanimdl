#!/bin/bash
# Enhanced image harvester from search JSON responses
# Supports multiple JSON files and better error handling

set -euo pipefail  # Exit on error, undefined vars, pipe failures

readonly SCRIPT_NAME="${0##*/}"
readonly TIMESTAMP=$(date -u +%s%N)
readonly PAGE_NUMBER="${PAGE_NUMBER:-1}"

usage() {
    cat << EOF
Usage: $SCRIPT_NAME <prefix> <json_file1> [json_file2] [...]
    prefix: Output filename prefix
    json_files: One or more JSON response files to process
    
Environment:
    PAGE_NUMBER: Page number suffix (default: 1)
    YANIMDL_THREADS: Parallel wget threads (default: 4)
    YANIMDL_TIMEOUT: Wget timeout in seconds (default: 20)
EOF
}

log() { echo "[$(date +'%H:%M:%S')] $*" >&2; }
die() { log "ERROR: $*"; exit 1; }

# Validate inputs
[[ $# -lt 2 ]] && { usage; exit 1; }

readonly PREFIX="$1"
shift
readonly JSON_FILES=("$@")

# Validate JSON files exist
for json_file in "${JSON_FILES[@]}"; do
    [[ -f "$json_file" ]] || die "JSON file not found: $json_file"
    command -v jq >/dev/null || die "jq not installed"
done

# Configuration
readonly THREADS="${YANIMDL_THREADS:-4}"
readonly TIMEOUT="${YANIMDL_TIMEOUT:-20}"
readonly WORK_DIR="${PREFIX}_${TIMESTAMP}_p${PAGE_NUMBER}"

# Create isolated work directory
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

log "Starting image harvest: $WORK_DIR"

extract_urls() {
    local json_file="$1"
    local url_type="$2"
    local jq_path="$3"
    local output_file="${PREFIX}.${url_type}.urls.txt"
    
    log "Extracting $url_type URLs from $json_file"
    
    # Use jq with proper error handling and null filtering
    if jq -r "$jq_path // empty" "$json_file" 2>/dev/null | \
       grep -E '^https?://' | \
       sort -u > "$output_file"; then
        local count=$(wc -l < "$output_file")
        log "Found $count unique $url_type URLs"
        [[ $count -gt 0 ]] && echo "$output_file"
    else
        log "Warning: No $url_type URLs found in $json_file"
        return 1
    fi
}

download_images() {
    local url_file="$1"
    [[ -f "$url_file" ]] || return 1
    
    log "Downloading images from $url_file ($(wc -l < "$url_file") URLs)"
    
    # Parallel wget with better error handling
    cat "$url_file" | xargs -n1 -P"$THREADS" -I{} bash -c '
        url="$1"
        filename=$(basename "$url" | sed "s/[^a-zA-Z0-9._-]/_/g")
        if [[ ${#filename} -gt 100 ]]; then
            filename="${filename:0:100}"
        fi
        
        if wget -T '"$TIMEOUT"' --max-redirect=5 --tries=2 \
               --user-agent="Mozilla/5.0 (compatible; ImageBot/1.0)" \
               --no-check-certificate -q -O "$filename" "$url" 2>/dev/null; then
            echo "✓ $filename"
        else
            echo "✗ Failed: $url" >&2
        fi
    ' _ {}
}

# Main processing loop
all_url_files=()

for json_file in "${JSON_FILES[@]}"; do
    log "Processing JSON file: $json_file"
    
    # Extract different URL types
    while IFS= read -r url_file; do
        all_url_files+=("$url_file")
    done < <(
        extract_urls "$json_file" "origUrl" '.blocks[1].params.adapterData.serpList.items.entities[]?.origUrl'
        extract_urls "$json_file" "preview" '.blocks[1].params.adapterData.serpList.items.entities[]?.viewerData.preview[]?.url'  
        extract_urls "$json_file" "dups" '.blocks[1].params.adapterData.serpList.items.entities[]?.viewerData.dups[]?.url'
    )
done

# Combine and deduplicate all URLs
if [[ ${#all_url_files[@]} -gt 0 ]]; then
    log "Combining and deduplicating URLs"
    cat "${all_url_files[@]}" | sort -u > "all_urls.txt"
    local total_urls=$(wc -l < "all_urls.txt")
    log "Total unique URLs to download: $total_urls"
    
    # Download images
    download_images "all_urls.txt"
    
    # Post-processing with better tools
    if command -v exiftool >/dev/null; then
        log "Renaming files with exiftool"
        exiftool -overwrite_original -q '-filename<%f%-c.%e' -ext '*' . 2>/dev/null || true
    fi
    
    if command -v fdupes >/dev/null; then
        log "Removing duplicates with fdupes"
        fdupes -dN . 2>/dev/null || true
    fi
    
    # Final stats
    local downloaded=$(find . -type f -name "*.*" | wc -l)
    log "Harvest complete: $downloaded files downloaded to $PWD"
    log "Total disk usage: $(du -sh . | cut -f1)"
else
    log "No URLs found in any JSON files"
    exit 1
fi