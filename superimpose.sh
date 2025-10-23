#!/bin/bash

# Check if both parameters provided
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "superimpose - turns A5 and A6 PDFs into print-ready A4 layouts"
    echo "Usage: ./impose.sh input.pdf output.pdf"
    exit 1
fi

INPUT="$1"
OUTPUT="$2"

# Check if input file exists
if [ ! -f "$INPUT" ]; then
    echo "Error: File '$INPUT' not found"
    exit 1
fi

echo ""
echo "superimpose!"
echo "https://github.com/pidg/superimpose"
echo ""

# Get page count with multiple methods
METHOD=""
PAGE_COUNT=""

# Try pdfinfo first (most reliable)
if command -v pdfinfo &> /dev/null; then
    PAGE_COUNT=$(pdfinfo "$INPUT" 2>/dev/null | grep "^Pages:" | awk '{print $2}')
    if [ ! -z "$PAGE_COUNT" ]; then
        METHOD="pdfinfo"
    fi
fi

# Fallback to mdls
if [ -z "$PAGE_COUNT" ]; then
    PAGE_COUNT=$(mdls -name kMDItemNumberOfPages -raw "$INPUT" 2>/dev/null)
    if [ ! -z "$PAGE_COUNT" ] && [ "$PAGE_COUNT" != "(null)" ]; then
        METHOD="mdls"
    fi
fi

# Fallback to Python
if [ -z "$PAGE_COUNT" ]; then
    PAGE_COUNT=$(python3 -c "from pypdf import PdfReader; print(len(PdfReader('$INPUT').pages))" 2>/dev/null)
    if [ ! -z "$PAGE_COUNT" ]; then
        METHOD="python"
    fi
fi

if [ -z "$PAGE_COUNT" ]; then
    echo " Error: Could not determine page count"
    exit 1
fi

echo " Detected $PAGE_COUNT pages (using $METHOD)"

# Get page dimensions using pdfinfo (in points)
if command -v pdfinfo &> /dev/null; then
    PAGE_DIMS=$(pdfinfo "$INPUT" 2>/dev/null | grep "Page size:" | head -1)
    PAGE_WIDTH=$(echo "$PAGE_DIMS" | awk '{print $3}')
    PAGE_HEIGHT=$(echo "$PAGE_DIMS" | awk '{print $5}')
else
    # Fallback to Python if pdfinfo not available
    PAGE_DIMS=$(python3 -c "from pypdf import PdfReader; page = PdfReader('$INPUT').pages[0]; print(float(page.mediabox.width), float(page.mediabox.height))" 2>/dev/null)
    PAGE_WIDTH=$(echo "$PAGE_DIMS" | awk '{print $1}')
    PAGE_HEIGHT=$(echo "$PAGE_DIMS" | awk '{print $2}')
fi

if [ -z "$PAGE_WIDTH" ] || [ -z "$PAGE_HEIGHT" ]; then
    echo "  Error: Could not determine page dimensions"
    echo "  Try: brew install poppler (for pdfinfo)"
    exit 1
fi

echo "  Page dimensions: ${PAGE_WIDTH} x ${PAGE_HEIGHT} points"

# Detect page size (with 10 point tolerance)
detect_size() {
    local w=$1
    local h=$2
    
    # Check both portrait and landscape orientations
    # A4: 595 x 842 points
    if (( $(echo "$w > 585 && $w < 605 && $h > 832 && $h < 852" | bc -l) )) || \
       (( $(echo "$h > 585 && $h < 605 && $w > 832 && $w < 852" | bc -l) )); then
        echo "A4"
    # A5: 420 x 595 points
    elif (( $(echo "$w > 410 && $w < 430 && $h > 585 && $h < 605" | bc -l) )) || \
         (( $(echo "$h > 410 && $h < 430 && $w > 585 && $w < 605" | bc -l) )); then
        echo "A5"
    # A6: 298 x 420 points
    elif (( $(echo "$w > 288 && $w < 308 && $h > 410 && $h < 430" | bc -l) )) || \
         (( $(echo "$h > 288 && $h < 308 && $w > 410 && $w < 430" | bc -l) )); then
        echo "A6"
    else
        echo "UNKNOWN"
    fi
}

PAGE_SIZE=$(detect_size "$PAGE_WIDTH" "$PAGE_HEIGHT")

# Determine layout based on page size
NEEDS_ROTATION=false
case "$PAGE_SIZE" in
    "A4")
        echo "   Input is A4 - no imposition needed, copying file..."
        cp "$INPUT" "$OUTPUT"
        echo "   ✓ Done! File copied to: $OUTPUT"
        exit 0
        ;;
    "A5")
        PAGES_PER_SIDE=2
        NUP="1x2"
        PAGES_PER_SHEET=4
        NEEDS_ROTATION=true
        ;;
    "A6")
        PAGES_PER_SIDE=4
        NUP="2x2"
        PAGES_PER_SHEET=8
        ;;
    *)
        echo "   Error: Could not detect paper size (detected ${PAGE_WIDTH}x${PAGE_HEIGHT} points)"
        echo "   Supported sizes: A4, A5, A6"
        exit 1
        ;;
esac

echo "  Detected: $PAGE_SIZE paper size ($PAGES_PER_SIDE pages per side, $NUP layout)"

# Rotate input pages if needed (A5)
if [ "$NEEDS_ROTATION" = true ]; then
    echo "    Rotating pages 90° for proper fit..."
    pdfjam --angle 90 --fitpaper true "$INPUT" --outfile "superimpose-rotated_input.pdf" --quiet 2>/dev/null
    WORK_INPUT="superimpose-rotated_input.pdf"
else
    WORK_INPUT="$INPUT"
fi

# Check if page count is valid
if [ $((PAGE_COUNT % PAGES_PER_SHEET)) -ne 0 ]; then
    echo "    Warning: Page count ($PAGE_COUNT) is not a multiple of $PAGES_PER_SHEET"
    echo "    Adding blank pages to make it divisible..."
    # Round up to nearest multiple
    PAGE_COUNT=$(( ((PAGE_COUNT + PAGES_PER_SHEET - 1) / PAGES_PER_SHEET) * PAGES_PER_SHEET ))
    echo "    Adjusted to $PAGE_COUNT pages"
fi

# Calculate number of physical sheets
NUM_SHEETS=$((PAGE_COUNT / PAGES_PER_SHEET))
echo "   Creating $NUM_SHEETS imposed sheets..."

# Generate imposition for each sheet
SHEET_FILES=()

for ((i=0; i<NUM_SHEETS; i++)); do
    SHEET_NUM=$((i + 1))
    
    # Build page sequences using the correct formula
    front_pages_array=()
    back_pages_array=()
    
    for ((j=0; j<PAGES_PER_SIDE; j++)); do
        if [ $((j % 2)) -eq 0 ]; then
            # Even positions on front: count from end
            front_page=$((PAGE_COUNT - PAGES_PER_SIDE*i - j))
            # Even positions on back: count from start + 2
            back_page=$((PAGES_PER_SIDE*i + j + 2))
        else
            # Odd positions on front: count from start
            front_page=$((PAGES_PER_SIDE*i + j))
            # Odd positions on back: count from end
            back_page=$((PAGE_COUNT - PAGES_PER_SIDE*i - j))
        fi
        
        front_pages_array+=($front_page)
        back_pages_array+=($back_page)
    done
    
    # If rotation needed, reverse the page order
    if [ "$NEEDS_ROTATION" = true ]; then
        # Reverse the arrays
        front_pages_reversed=()
        back_pages_reversed=()
        for ((k=${#front_pages_array[@]}-1; k>=0; k--)); do
            front_pages_reversed+=(${front_pages_array[k]})
            back_pages_reversed+=(${back_pages_array[k]})
        done
        front_pages=$(IFS=,; echo "${front_pages_reversed[*]}")
        back_pages=$(IFS=,; echo "${back_pages_reversed[*]}")
    else
        front_pages=$(IFS=,; echo "${front_pages_array[*]}")
        back_pages=$(IFS=,; echo "${back_pages_array[*]}")
    fi
    
    echo "     Sheet $SHEET_NUM front: $front_pages"
    pdfjam --nup "$NUP" --frame false --scale 1.0 --quiet \
      "$WORK_INPUT" "$front_pages" --outfile "superimpose-sheet${SHEET_NUM}-side1.pdf" 2>/dev/null
    
    echo "     Sheet $SHEET_NUM back:  $back_pages"
    pdfjam --nup "$NUP" --frame false --scale 1.0 --quiet \
      "$WORK_INPUT" "$back_pages" --outfile "superimpose-sheet${SHEET_NUM}-side2.pdf" 2>/dev/null
    
    SHEET_FILES+=("superimpose-sheet${SHEET_NUM}-side1.pdf" "superimpose-sheet${SHEET_NUM}-side2.pdf")
done

# Combine all sheets
echo "   Combining all sheets..."
pdfjam "${SHEET_FILES[@]}" --outfile "$OUTPUT" --quiet 2>/dev/null

# Clean up
echo "   Cleaning up temporary files..."
rm -f superimpose-sheet*-side*.pdf
if [ "$NEEDS_ROTATION" = true ]; then
    rm -f superimpose-rotated_input.pdf
fi

echo ""
echo "✓ Done! Your imposed booklet is saved as: $OUTPUT"
echo "  Input size:   $PAGE_SIZE ($PAGES_PER_SIDE pages per side)"
echo "  Total sheets: $NUM_SHEETS (print duplex)"
echo ""
