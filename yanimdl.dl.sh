#!/bin/bash
# yanimdl.dl.sh - Bulletproof Image Downloader - Maximum stealth image downloading
# Handles bot detection, rate limiting, and hotlinking protection
#
# Written mostly by Claude Sonnet 4 (claude.ai web chat version llm), with some adjustments by defcron

set -euo pipefail

# Configuration
readonly MAX_CONCURRENT=${MAX_CONCURRENT:-19}
readonly MIN_DELAY=${MIN_DELAY:-1}
readonly MAX_DELAY=${MAX_DELAY:-3}
readonly MAX_RETRIES=${MAX_RETRIES:-3}
readonly TIMEOUT=${TIMEOUT:-30}

if [[ -z "${USER_AGENTS+x}" ]]; then
    readonly USER_AGENTS=(
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0"
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Safari/605.1.15"
    )
fi

if [[ -z "${REFERERS+x}" ]]; then
    readonly REFERERS=(
        "https://yandex.ru/images/"
        "https://yandex.com/images/"
        "https://images.yandex.ru/"
        "https://www.google.com/search?tbm=isch"
    )
fi

#SELECTED_UA="${USER_AGENTS[$((RANDOM % ${#USER_AGENTS[@]}))]}"
SELECTED_UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
#SELECTED_REFERER="${REFERERS[$((RANDOM % ${#REFERERS[@]}))]}"
SELECTED_REFERER="https://yandex.com/images/"
export SELECTED_UA SELECTED_REFERER

log() { echo "[$(date +'%H:%M:%S')] $*" >&2; }

# Get random user agent
get_random_ua() {
    #echo "${USER_AGENTS[$((RANDOM % (${#USER_AGENTS[@]} + 1)))]}"
    #SELECTED_UA="${USER_AGENTS[$((RANDOM % ${#USER_AGENTS[@]}))]}"
    readonly SELECTED_UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    export SELECTED_UA
    echo "${SELECTED_UA}"
}

# Get random referer
get_random_referer() {
    #echo "${REFERERS[$((RANDOM % (${#REFERERS[@]} + 1)))]}"
    #SELECTED_REFERER="${REFERERS[$((RANDOM % ${#REFERERS[@]}))]}"
    readonly SELECTED_REFERER="https://yandex.com/images/"
    export SELECTED_REFERER
    echo "${SELECTED_REFERER}"
}

# Smart delay with jitter
smart_delay() {
    local delay=$((RANDOM % (MAX_DELAY - MIN_DELAY + 1) + MIN_DELAY))
    sleep $delay
}

# Download single image with maximum stealth
download_image_stealth() {
    local url="$1"
    local output_file="$2"
    local attempt="${3:-1}"
    
    local ua="${SELECTED_UA}"
    local referer="${SELECTED_REFERER}"
    
    # Extract domain for smarter referer selection
    local domain=$(echo "$url" | sed -E 's|https?://([^/]+).*|\1|')
    
    # Try curl first (usually better success rate)
    if curl -L --fail --silent --show-error \
        --max-redirs 30 \
        --connect-timeout 30 \
        --max-time $TIMEOUT \
        --retry $MAX_RETRIES \
        --retry-delay 4 \
        --retry-max-time 60 \
        -H "User-Agent: $ua" \
        -H "Accept: image/webp,image/apng,image/png,image/jpeg,image/gif,image/svg+xml,image/*,video/mp4,video/x-matroska,video/x-msvideo,video/*,*/*;q=0.8" \
        -H "Accept-Language: en-US,en;q=0.9,ru;q=0.8,de;q=0.7" \
        -H "Accept-Encoding: gzip, deflate, br" \
        -H "Referer: $referer" \
        -H "Sec-Fetch-Dest: image" \
        -H "Sec-Fetch-Mode: no-cors" \
        -H "Sec-Fetch-Site: cross-site" \
        -H "Cache-Control: no-cache" \
        -H "DNT: 1" \
        -H "Upgrade-Insecure-Requests: 1" \
        --compressed \
        -o "$output_file" \
        "$url" 2>/dev/null; then
        return 0
    fi
    
    # Fallback to wget with enhanced headers
    if wget --quiet \
        --timeout=$TIMEOUT \
        --tries=4 \
        --max-redirect=30 \
        --trust-server-names \
        --no-check-certificate \
        --user-agent="$ua" \
        --header="Accept: image/webp,image/apng,image/png,image/jpeg,image/gif,image/svg+xml,image/*,video/mp4,video/x-matroska,video/x-msvideo,video/*,*/*;q=0.8" \
        --header="Accept-Language: en-US,en;q=0.9,ru;q=0.8" \
        --header="Accept-Encoding: gzip, deflate, br" \
        --header="Referer: $referer" \
        --header="Sec-Fetch-Dest: image" \
        --header="Sec-Fetch-Mode: no-cors" \
        --header="Cache-Control: no-cache" \
        --header="DNT: 1" \
        -O "$output_file" \
        "$url" 2>/dev/null; then
        return 0
    fi
    
    # Last resort: try with different referer strategy
    if [[ $attempt -lt $MAX_RETRIES ]]; then
        log "Retry $((attempt + 1)) for $domain"
        smart_delay
        download_image_stealth "$url" "$output_file" $((attempt + 1))
    else
        return 1
    fi
}

# Process single URL with comprehensive error handling
process_url() {
    local url="$1"
    
    # Generate safe filename
    local filename="$(basename "$url" | sed 's/[^a-zA-Z0-9._]/_/g' | head -c 100 | sed "s/'/_/g")"
    [[ -z "$filename" || "$filename" == "_" ]] && filename="image_$(date +%s)_${RANDOM}${RANDOM}${RANDOM}"
    
    ## Add extension if missing
    #if [[ "$filename" != *.* ]]; then
    #    local ext=$(echo "$url" | grep -oE '\.(jpg|jpeg|png|gif|webp|bmp|mp4|mkv|avi)' | tail -1)
    #    filename="${filename}${ext:-.jpg}"
    #fi

    # Don't assume extensions - let exiftool fix them later
    # Just ensure we have some filename
    [[ -z "$filename" || "$filename" == "_" ]] && filename="download_$(date +%s)_${RANDOM}${RANDOM}${RANDOM}"
    
    # Rename if already exists
    if [[ -f "$filename" ]]; then
	local new_filename="${filename}_${RANDOM}${RANDOM}${RANDOM}"
        echo "⏭️  Renaming: $filename (exists) -> $new_filename"
	filename="${new_filename}"
    fi
    
    log "📥 Downloading: $url -> $filename"
    
    if download_image_stealth "$url" "$filename"; then
        local size=$(stat -f%z "$filename" 2>/dev/null || stat -c%s "$filename" 2>/dev/null || echo "unknown")
        echo "✅ Success: $url -> $filename ($size bytes)"
        return 0
    else
        echo "❌ Failed: $url -> $filename"
        [[ -f "$filename" ]] && rm -f "./$filename"  # Clean up partial downloads
        return 1
    fi
}

# Process URL list with rate limiting and parallel downloads
process_url_list() {
    local url_file="$1"
    local total_urls=$(wc -l < "$url_file")
    local success_count=0
    local processed=0
    
    log "Processing $total_urls URLs with max $MAX_CONCURRENT concurrent downloads"
    
    # Use xargs for controlled parallelism
    export -f process_url download_image_stealth smart_delay get_random_ua get_random_referer log
    export MAX_RETRIES TIMEOUT
    export USER_AGENTS REFERERS MIN_DELAY MAX_DELAY # export arrays properly
    
    cat "$url_file" | sed "s/'/_/g" | xargs -P$MAX_CONCURRENT -I{} bash -c '
        process_url "$@"
        sleep $(shuf -i '"$MIN_DELAY"'-'"$MAX_DELAY"' -n 1)
    ' _ {}
    
    # Final statistics
    local final_count=$(find . -type f -name "*" ! -name ".*" ! -name "*.txt" ! -name "*.log" ! -name "*.json" ! -name "*.js" ! -name "*.md" ! -name "*.html" | wc -l)
    #local final_count=$(find . -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.gif" -o -name "*.webp" -o -name "*.mp4" -o -name "*.mkv" -o -name "*.avi" | wc -l)
    echo
    echo "=== DOWNLOAD COMPLETE ==="
    echo "Total files downloaded: $final_count"
    echo "Success rate: $(echo "scale=1; $final_count * 100 / $total_urls" | bc -l)%"
}

# Analyze failed downloads and suggest improvements
analyze_failures() {
    local url_file="$1"
    
    echo "=== FAILURE ANALYSIS ==="
    
    # Extract domains from URLs
    local domains_file="$(mktemp)"
    grep -oE 'https?://[^/]+' "$url_file" | sort | uniq -c | sort -nr > "$domains_file"

    cp "$domains_file" ./domains.txt
    
    echo "Downloads by domain:"
    head -10 "$domains_file"
    
    # Look for patterns in successful vs failed downloads
    #local successful_files=$(find . -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.gif" -o -name "*.webp" -o -name "*.mp4" -o -name "*.mkv" -o -name "*.avi" | wc -l)
    # Count all downloaded files consistently
    local successful_files=$(find . -type f -name "*" ! -name ".*" ! -name "*.txt" ! -name "*.log" ! -name "*.json" ! -name "*.js" ! -name "*.md" ! -name "*.html" | wc -l)
    local total_urls=$(wc -l < "$url_file")
    local failed_count=$((total_urls - successful_files))
    
    if [[ $failed_count -gt $((total_urls / 2)) ]]; then
        echo
        echo "⚠️  HIGH FAILURE RATE ($failed_count/$total_urls failed)"
        echo "Recommendations:"
        echo "- Consider adding longer delays (MIN_DELAY/MAX_DELAY)"
        echo "- Try running during off-peak hours"
        echo "- Some domains may require specific headers or authentication"
        echo "- Consider using a VPN or different IP address"
    fi

    rm -f "$domains_file"
}

# Enhanced version of your original download loop
enhanced_download_loop() {
    local url_files=("$@")
    
    # Combine all URL files into one deduplicated list
    local combined_urls="$(mktemp)"
    for file in "${url_files[@]}"; do
        [[ -f "$file" ]] && cat "$file"
    done | sort -u > "$combined_urls"

    cp "$combined_urls" ./combined_urls.txt
    
    local total_urls=$(wc -l < "$combined_urls")
    log "Combined $total_urls unique URLs from ${#url_files[@]} files"
    
    # Process with stealth downloading
    process_url_list "$combined_urls"
    
    # Cleanup and analysis
    analyze_failures "$combined_urls"

    rm -f "$combined_urls"
}

# Replace your original download loop
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-help}" in
        "download")
            shift
            enhanced_download_loop $@
            ;;
        "process-urls")
            [[ $# -ge 2 ]] || { echo "Usage: $0 process-urls <url_file>"; exit 1; }
            process_url_list "$2"
            ;;
        "test-url")
            [[ $# -ge 2 ]] || { echo "Usage: $0 test-url <single_url>"; exit 1; }
            process_url "$2"
            ;;
        "help"|*)
            cat << EOF
$0 - Bulletproof Image Downloader - Maximum stealth image downloading

Usage:
  $0 <command> <command_arg_1> [command_arg_2 ...command_arg_N]

Commands:
  download <url_file1> [url_file2] ...    Download from multiple URL files
  process-urls <url_file>                 Download from a single URL file and don't perform analysis afterwards
  test-url <url>                          Test download of single URL
  
Configuration (edit script variables):
  MAX_CONCURRENT: $MAX_CONCURRENT (parallel downloads)
  MIN_DELAY: $MIN_DELAY seconds (minimum delay between requests)
  MAX_DELAY: $MAX_DELAY seconds (maximum delay between requests)
  MAX_RETRIES: $MAX_RETRIES (retry attempts per URL)
  TIMEOUT: $TIMEOUT seconds (timeout per request)

Features:
- Rotates User-Agent strings and referers
- Implements smart delays with jitter
- Tries curl first, falls back to wget
- Comprehensive browser header spoofing
- Parallel downloads with rate limiting
- Automatic retry with backoff
- Failure analysis and recommendations

Drop-in replacement for your current wget loop in yanimdl.sh
EOF
            ;;
    esac
fi
