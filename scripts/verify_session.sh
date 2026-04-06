#!/usr/bin/env bash
# verify_session.sh - Verify collected FER session data
# Usage: ./verify_session.sh <data_dir> [expected_count]

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

DATA_DIR="${1:-}"
EXPECTED_COUNT="${2:-30}"
MIN_FILE_SIZE=102400  # 100 KB in bytes

SCENARIOS=(antusias bosan bingung frustrasi)

if [[ -z "$DATA_DIR" ]]; then
    echo "Usage: $0 <data_dir> [expected_count]"
    echo "Example: $0 ./data 30"
    exit 1
fi

if [[ ! -d "$DATA_DIR" ]]; then
    echo -e "${RED}Error: Directory '$DATA_DIR' does not exist${NC}"
    exit 1
fi

# Count subjects and track stats
total_subjects=0
complete_subjects=0
missing_files=0
small_files=0

# Print header
echo ""
printf "%-38s  %-10s  %-10s  %-10s  %-10s  %s\n" \
    "Subject ID" "antusias" "bosan" "bingung" "frustrasi" "Status"
printf '%.0s-' {1..100}
echo ""

# Process each subject directory
shopt -s nullglob
dirs=("$DATA_DIR"/*/)
shopt -u nullglob

for subject_dir in "${dirs[@]}"; do
    [[ -d "$subject_dir" ]] || continue
    
    subject_id=$(basename "$subject_dir")
    ((total_subjects++)) || true
    
    subject_complete=true
    cols=()
    
    for scenario in "${SCENARIOS[@]}"; do
        file_path="${subject_dir}${scenario}.webm"
        
        if [[ -f "$file_path" ]]; then
            file_size=$(stat -c%s "$file_path" 2>/dev/null || stat -f%z "$file_path" 2>/dev/null || echo 0)
            size_kb=$((file_size / 1024))
            
            if [[ "$file_size" -ge "$MIN_FILE_SIZE" ]]; then
                cols+=("${GREEN}${size_kb}KB${NC}")
            else
                cols+=("${YELLOW}${size_kb}KB${NC}")
                subject_complete=false
                ((small_files++)) || true
            fi
        else
            cols+=("${RED}MISSING${NC}")
            subject_complete=false
            ((missing_files++)) || true
        fi
    done
    
    # Determine overall status
    if $subject_complete; then
        status="${GREEN}COMPLETE${NC}"
        ((complete_subjects++)) || true
    else
        status="${RED}INCOMPLETE${NC}"
    fi
    
    # Print row - truncate UUID for display
    display_id="${subject_id:0:36}"
    printf "%-38s  " "$display_id"
    printf "%-19b  " "${cols[0]}"
    printf "%-19b  " "${cols[1]}"
    printf "%-19b  " "${cols[2]}"
    printf "%-19b  " "${cols[3]}"
    printf "%b\n" "$status"
done

# Print summary
printf '%.0s-' {1..100}
echo ""
echo ""
echo "Summary:"
echo "  Subjects found: $total_subjects (expected: $EXPECTED_COUNT)"
echo "  Complete: $complete_subjects"
echo "  Missing files: $missing_files"
echo "  Files < 100KB: $small_files"
echo ""

# Final status
if [[ "$complete_subjects" -eq "$total_subjects" ]] && [[ "$total_subjects" -ge "$EXPECTED_COUNT" ]]; then
    echo -e "${GREEN}Ready for processing: YES${NC}"
    exit 0
else
    echo -e "${RED}Ready for processing: NO${NC}"
    exit 1
fi
