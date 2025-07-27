#!/bin/bash
# Aesthetic Catalog Helper - Simple companion to yanimdl.sh
# Just adds some metadata tracking without changing your working flow

if [ $# -lt 1 ]; then
    echo "usage: $0 <project_name> [seed_image_description]"
    exit 1
fi

PROJECT_NAME="$1"
SEED_DESC="${2:-unknown}"
TIMESTAMP=$(date -u +%Y%m%d_%H%M%S)

# Simple project log
PROJECT_LOG="${PROJECT_NAME}_catalog.txt"

# Count existing images before run
BEFORE_COUNT=$(find . -name "*.jpg" -o -name "*.png" -o -name "*.gif" 2>/dev/null | wc -l)

echo "=== AESTHETIC CATALOG ENTRY ==="
echo "Project: $PROJECT_NAME"
echo "Timestamp: $TIMESTAMP" 
echo "Seed: $SEED_DESC"
echo "Images before: $BEFORE_COUNT"
echo

# Log the session
cat >> "$PROJECT_LOG" << EOF
---
Session: $TIMESTAMP
Seed: $SEED_DESC
Pre-count: $BEFORE_COUNT
JSON files: $(ls *.json 2>/dev/null | wc -l)
EOF

echo "Ready to run yanimdl.sh *.json"
echo "After download, run: $0 finish $PROJECT_NAME"

# If called with 'finish', calculate final stats
if [[ "$1" == "finish" && -n "$2" ]]; then
    PROJECT_NAME="$2"
    PROJECT_LOG="${PROJECT_NAME}_catalog.txt"
    
    AFTER_COUNT=$(find . -name "*.jpg" -o -name "*.png" -o -name "*.gif" 2>/dev/null | wc -l)
    GAINED=$((AFTER_COUNT - $(tail -1 "$PROJECT_LOG" | grep -o 'Pre-count: [0-9]*' | cut -d' ' -f2)))
    
    echo "Post-count: $AFTER_COUNT" >> "$PROJECT_LOG"
    echo "Gained: $GAINED" >> "$PROJECT_LOG"
    echo "" >> "$PROJECT_LOG"
    
    echo "Session complete: $GAINED new images"
    echo "Total collection: $AFTER_COUNT images"
    
    # Optional: peek at some new filenames for flavor
    echo "Sample discoveries:"
    find . -name "*.jpg" -o -name "*.png" | tail -3 | sed 's|./||'
fi