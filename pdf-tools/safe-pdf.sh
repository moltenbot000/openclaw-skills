#!/bin/bash
# safe-pdf.sh — Secure wrapper for poppler-utils
# Enforces timeouts, size limits, and input validation

set -euo pipefail

# === Configuration ===
MAX_FILE_SIZE_MB="${PDF_MAX_SIZE_MB:-50}"
MAX_PAGES="${PDF_MAX_PAGES:-500}"
TIMEOUT_SECONDS="${PDF_TIMEOUT:-60}"
MAX_OUTPUT_SIZE_MB="${PDF_MAX_OUTPUT_MB:-100}"

# === Colors ===
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# === Helper Functions ===

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    exit 1
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

usage() {
    cat <<EOF
safe-pdf.sh — Secure wrapper for poppler-utils

Usage: safe-pdf.sh <command> [options] <input.pdf> [output]

Commands:
    text        Extract text (pdftotext)
    info        Get metadata (pdfinfo)
    images      Extract images (pdfimages)
    png         Convert to PNG (pdftocairo)
    jpeg        Convert to JPEG (pdftocairo)
    merge       Merge PDFs (pdfunite)
    split       Split PDF (pdfseparate)
    html        Convert to HTML (pdftohtml)

Options:
    -f <num>    First page (default: 1)
    -l <num>    Last page (default: $MAX_PAGES or document end)
    -r <dpi>    Resolution for image output (default: 150)
    --layout    Preserve layout (text extraction)
    --unsafe    Skip safety checks (use with caution)

Environment:
    PDF_MAX_SIZE_MB     Max input file size (default: 50)
    PDF_MAX_PAGES       Max pages to process (default: 500)
    PDF_TIMEOUT         Command timeout in seconds (default: 60)
    PDF_MAX_OUTPUT_MB   Max output size (default: 100)

Examples:
    safe-pdf.sh text document.pdf                    # Extract text to stdout
    safe-pdf.sh text document.pdf output.txt        # Extract text to file
    safe-pdf.sh text --layout invoice.pdf           # Preserve layout
    safe-pdf.sh info document.pdf                   # Get metadata
    safe-pdf.sh png -r 300 document.pdf ./images/   # High-res PNG conversion
    safe-pdf.sh merge a.pdf b.pdf output.pdf        # Merge PDFs
    safe-pdf.sh split document.pdf ./pages/page     # Split into pages

EOF
    exit 0
}

# === Validation Functions ===

validate_filename() {
    local file="$1"
    
    # Check for shell metacharacters and path traversal
    if [[ "$file" =~ [\"\'\`\$\|\;\&\<\>\(\)\{\}\[\]\\] ]]; then
        error "Filename contains dangerous characters: $file"
    fi
    
    # Check for path traversal
    if [[ "$file" == *".."* ]]; then
        error "Path traversal detected: $file"
    fi
}

validate_pdf() {
    local file="$1"
    
    validate_filename "$file"
    
    # Check file exists
    if [[ ! -f "$file" ]]; then
        error "File not found: $file"
    fi
    
    # Check file size
    local size_bytes
    size_bytes=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
    local size_mb=$((size_bytes / 1024 / 1024))
    
    if [[ $size_mb -gt $MAX_FILE_SIZE_MB ]]; then
        error "File too large: ${size_mb}MB (max: ${MAX_FILE_SIZE_MB}MB)"
    fi
    
    # Check it's actually a PDF (magic bytes)
    local magic
    magic=$(head -c 5 "$file" 2>/dev/null || true)
    if [[ "$magic" != "%PDF-" ]]; then
        error "Not a valid PDF file (bad magic bytes): $file"
    fi
    
    # Quick sanity check with pdfinfo (with timeout)
    if ! timeout 5 pdfinfo "$file" >/dev/null 2>&1; then
        error "PDF validation failed (corrupt or malformed): $file"
    fi
}

get_page_count() {
    local file="$1"
    timeout 5 pdfinfo "$file" 2>/dev/null | grep "^Pages:" | awk '{print $2}' || echo "0"
}

validate_output_path() {
    local path="$1"
    
    validate_filename "$path"
    
    # Get directory
    local dir
    dir=$(dirname "$path")
    
    # Check directory exists or can be created
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir" 2>/dev/null || error "Cannot create output directory: $dir"
    fi
    
    # Check we can write there
    if [[ ! -w "$dir" ]]; then
        error "Output directory not writable: $dir"
    fi
}

# === Command Implementations ===

cmd_text() {
    local input=""
    local output="-"
    local first_page=""
    local last_page=""
    local layout=""
    local unsafe=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f) first_page="$2"; shift 2 ;;
            -l) last_page="$2"; shift 2 ;;
            --layout) layout="-layout"; shift ;;
            --unsafe) unsafe=true; shift ;;
            -*) error "Unknown option: $1" ;;
            *)
                if [[ -z "$input" ]]; then
                    input="$1"
                else
                    output="$1"
                fi
                shift
                ;;
        esac
    done
    
    [[ -z "$input" ]] && error "No input file specified"
    
    if [[ "$unsafe" != true ]]; then
        validate_pdf "$input"
        [[ "$output" != "-" ]] && validate_output_path "$output"
    fi
    
    # Build command
    local cmd=(timeout "$TIMEOUT_SECONDS" pdftotext)
    [[ -n "$first_page" ]] && cmd+=(-f "$first_page")
    [[ -n "$last_page" ]] && cmd+=(-l "$last_page")
    [[ -n "$layout" ]] && cmd+=("$layout")
    cmd+=("$input" "$output")
    
    "${cmd[@]}"
}

cmd_info() {
    local input=""
    local unsafe=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --unsafe) unsafe=true; shift ;;
            -*) error "Unknown option: $1" ;;
            *) input="$1"; shift ;;
        esac
    done
    
    [[ -z "$input" ]] && error "No input file specified"
    
    if [[ "$unsafe" != true ]]; then
        validate_pdf "$input"
    fi
    
    timeout "$TIMEOUT_SECONDS" pdfinfo "$input"
}

cmd_images() {
    local input=""
    local output_prefix=""
    local first_page=""
    local last_page=""
    local format="-png"
    local unsafe=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f) first_page="$2"; shift 2 ;;
            -l) last_page="$2"; shift 2 ;;
            --png) format="-png"; shift ;;
            --jpeg|-j) format="-j"; shift ;;
            --unsafe) unsafe=true; shift ;;
            -*) error "Unknown option: $1" ;;
            *)
                if [[ -z "$input" ]]; then
                    input="$1"
                else
                    output_prefix="$1"
                fi
                shift
                ;;
        esac
    done
    
    [[ -z "$input" ]] && error "No input file specified"
    [[ -z "$output_prefix" ]] && error "No output prefix specified"
    
    if [[ "$unsafe" != true ]]; then
        validate_pdf "$input"
        validate_output_path "${output_prefix}-000.png"
    fi
    
    local cmd=(timeout "$TIMEOUT_SECONDS" pdfimages "$format")
    [[ -n "$first_page" ]] && cmd+=(-f "$first_page")
    [[ -n "$last_page" ]] && cmd+=(-l "$last_page")
    cmd+=("$input" "$output_prefix")
    
    "${cmd[@]}"
}

cmd_png() {
    cmd_image_convert "png" "$@"
}

cmd_jpeg() {
    cmd_image_convert "jpeg" "$@"
}

cmd_image_convert() {
    local format="$1"
    shift
    
    local input=""
    local output_prefix=""
    local first_page=""
    local last_page=""
    local resolution="150"
    local unsafe=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f) first_page="$2"; shift 2 ;;
            -l) last_page="$2"; shift 2 ;;
            -r) resolution="$2"; shift 2 ;;
            --unsafe) unsafe=true; shift ;;
            -*) error "Unknown option: $1" ;;
            *)
                if [[ -z "$input" ]]; then
                    input="$1"
                else
                    output_prefix="$1"
                fi
                shift
                ;;
        esac
    done
    
    [[ -z "$input" ]] && error "No input file specified"
    [[ -z "$output_prefix" ]] && output_prefix="${input%.pdf}"
    
    if [[ "$unsafe" != true ]]; then
        validate_pdf "$input"
        validate_output_path "${output_prefix}-1.${format}"
        
        # Check page count
        local pages
        pages=$(get_page_count "$input")
        if [[ $pages -gt $MAX_PAGES ]]; then
            warn "Document has $pages pages, limiting to $MAX_PAGES"
            last_page="$MAX_PAGES"
        fi
    fi
    
    local cmd=(timeout "$TIMEOUT_SECONDS" pdftocairo "-$format" -r "$resolution")
    [[ -n "$first_page" ]] && cmd+=(-f "$first_page")
    [[ -n "$last_page" ]] && cmd+=(-l "$last_page")
    cmd+=("$input" "$output_prefix")
    
    "${cmd[@]}"
}

cmd_merge() {
    local inputs=()
    local output=""
    local unsafe=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --unsafe) unsafe=true; shift ;;
            -*) error "Unknown option: $1" ;;
            *)
                if [[ $# -eq 1 ]]; then
                    output="$1"
                else
                    inputs+=("$1")
                fi
                shift
                ;;
        esac
    done
    
    [[ ${#inputs[@]} -lt 2 ]] && error "Need at least 2 input files to merge"
    [[ -z "$output" ]] && error "No output file specified"
    
    if [[ "$unsafe" != true ]]; then
        for f in "${inputs[@]}"; do
            validate_pdf "$f"
        done
        validate_output_path "$output"
    fi
    
    timeout "$TIMEOUT_SECONDS" pdfunite "${inputs[@]}" "$output"
}

cmd_split() {
    local input=""
    local output_pattern=""
    local first_page=""
    local last_page=""
    local unsafe=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f) first_page="$2"; shift 2 ;;
            -l) last_page="$2"; shift 2 ;;
            --unsafe) unsafe=true; shift ;;
            -*) error "Unknown option: $1" ;;
            *)
                if [[ -z "$input" ]]; then
                    input="$1"
                else
                    output_pattern="$1"
                fi
                shift
                ;;
        esac
    done
    
    [[ -z "$input" ]] && error "No input file specified"
    [[ -z "$output_pattern" ]] && output_pattern="${input%.pdf}-%d.pdf"
    
    # Ensure pattern has %d
    if [[ "$output_pattern" != *"%"* ]]; then
        output_pattern="${output_pattern}-%d.pdf"
    fi
    
    if [[ "$unsafe" != true ]]; then
        validate_pdf "$input"
        # Validate base output path
        local base_path="${output_pattern/\%*/}"
        validate_output_path "${base_path}1.pdf"
    fi
    
    local cmd=(timeout "$TIMEOUT_SECONDS" pdfseparate)
    [[ -n "$first_page" ]] && cmd+=(-f "$first_page")
    [[ -n "$last_page" ]] && cmd+=(-l "$last_page")
    cmd+=("$input" "$output_pattern")
    
    "${cmd[@]}"
}

cmd_html() {
    local input=""
    local output=""
    local unsafe=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --unsafe) unsafe=true; shift ;;
            -*) error "Unknown option: $1" ;;
            *)
                if [[ -z "$input" ]]; then
                    input="$1"
                else
                    output="$1"
                fi
                shift
                ;;
        esac
    done
    
    [[ -z "$input" ]] && error "No input file specified"
    [[ -z "$output" ]] && output="${input%.pdf}.html"
    
    if [[ "$unsafe" != true ]]; then
        validate_pdf "$input"
        validate_output_path "$output"
    fi
    
    timeout "$TIMEOUT_SECONDS" pdftohtml -s "$input" "$output"
}

# === Main ===

[[ $# -eq 0 ]] && usage

command="$1"
shift

case "$command" in
    text)   cmd_text "$@" ;;
    info)   cmd_info "$@" ;;
    images) cmd_images "$@" ;;
    png)    cmd_png "$@" ;;
    jpeg)   cmd_jpeg "$@" ;;
    merge)  cmd_merge "$@" ;;
    split)  cmd_split "$@" ;;
    html)   cmd_html "$@" ;;
    -h|--help|help) usage ;;
    *) error "Unknown command: $command (try: safe-pdf.sh --help)" ;;
esac
