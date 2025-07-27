#!/bin/bash
# Bulletproof Image Downloader - Maximum stealth image downloading
# Handles bot detection, rate limiting, and hotlinking protection

set -euo pipefail

# Configuration
readonly MAX_CONCURRENT=3
readonly MIN_DELAY=1
readonly MAX_DELAY=4
readonly MAX_RETRIES=3
readonly TIMEOUT=30
readonly USER_AGENTS=(
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0"
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Safari/605.1.15"
)

readonly REFERERS=(
    "https://yandex.ru/images/"
    "https://yandex.com/images/"
    "https://images.yandex.ru/"
    "https://www.google.com/search?tbm=isch"
)

log() { echo "[$(date +'%H:%M:%S')] $*" >&2; }

# Get random user agent
get_random_ua() {
    echo "${USER_AGENTS[$((RANDOM % ${#USER_AGENTS[@]}))]}"
}

# Get random referer
get_random_referer() {
    echo "${REFERERS[$((RANDOM % ${#REFERERS[@]}))]}"
}

# Smart delay with jitter
smart_delay() {
    local delay=$((RANDOM % (MAX_DELAY - MIN_DELAY + 1) + MIN_DELAY))
    sleep "$delay"
}

# Download single image with maximum stealth
download_image_stealth() {
    local url="$1"
    local output_file="$2"
    local attempt="${3:-1}"
    
    local ua=$(get_random_ua)
    local referer=$(get_random_referer)
    
    # Extract domain for smarter referer selection
    local domain=$(echo "$url" | sed -E 's|https?://([^/]+).*|\1|')
    
    # Try curl first (usually better success rate)
    if curl -L --fail --silent --show-error \
        --max-redirs 10 \
        --connect-timeout 15 \
        --max-time "$TIMEOUT" \
        --retry 2 \
        --retry-delay 2 \
        --retry-max-time 60 \
        -H "User-Agent: $ua" \
        -H "Accept: image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8" \
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
        --timeout="$TIMEOUT" \
        --tries=2 \
        --max-redirect=10 \
        --trust-server-names \
        --no-check-certificate \
        --user-agent="$ua" \
        --header="Accept: image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8" \
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
    local filename=$(basename "$url" | sed 's/[^a-zA-Z0-9._-]/_/g' | head -c 100)
    [[ -z "$filename" || "$filename" == "_" ]] && filename="image_$(date +%s)_$RANDOM"
    
    # Add extension if missing
    if [[ "$filename" != *.* ]]; then
        local ext=$(echo "$url" | grep -oE '\.(jpg|jpeg|png|gif|webp|bmp)' | tail -1)
        filename="${filename}${ext:-.jpg}"
    fi
    
    # Skip if already exists
    if [[ -f "$filename" ]]; then
        echo "⏭️  Skip: $filename (exists)"
        return 0
    fi
    
    log "📥 Downloading: $filename"
    
    if download_image_stealth "$url" "$filename"; then
        local size=$(stat -f%z "$filename" 2>/dev/null || stat -c%s "$filename" 2>/dev/null || echo "unknown")
        echo "✅ Success: $filename ($size bytes)"
        return 0
    else
        echo "❌ Failed: $url"
        [[ -f "$filename" ]] && rm -f "$filename"  # Clean up partial downloads
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
    export MAX_RETRIES TIMEOUT USER_AGENTS REFERERS MIN_DELAY MAX_DELAY
    
    cat "$url_file" | xargs -n1 -P"$MAX_CONCURRENT" -I{} bash -c '
        process_url "$@"
        sleep $(shuf -i '"$MIN_DELAY"'-'"$MAX_DELAY"' -n 1)
    ' _ {}
    
    # Final statistics
    local final_count=$(find . -name "*.jpg" -o -name "*.png" -o -name "*.gif" -o -name "*.webp" | wc -l)
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
    local domains_file=$(mktemp)
    grep -oE 'https?://[^/]+' "$url_file" | sort | uniq -c | sort -nr > "$domains_file"
    
    echo "Downloads by domain:"
    head -10 "$domains_file"
    
    # Look for patterns in successful vs failed downloads
    local successful_files=$(find . -name "*.jpg" -o -name "*.png" -o -name "*.gif" -o -name "*.webp" | wc -l)
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
    local combined_urls=$(mktemp)
    for file in "${url_files[@]}"; do
        [[ -f "$file" ]] && cat "$file"
    done | sort -u > "$combined_urls"
    
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
            enhanced_download_loop "$@"
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
Bulletproof Image Downloader - Maximum stealth image downloading

Commands:
  download <url_file1> [url_file2] ...    Download from multiple URL files
  process-urls <url_file>                 Process single URL file
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