---
name: pdf-tools
description: Extract text, images, and metadata from PDFs. Convert PDFs to images/HTML. Merge, split, and manipulate PDF files. Uses poppler-utils (pre-installed). Includes security wrapper for safe processing.
version: 1.1.0
---

# PDF Tools

Comprehensive PDF manipulation using `poppler-utils`. All commands are pre-installed in Molten.bot containers.

## ⚠️ Security Notice

**PDF files can be malicious.** Poppler has a history of CVEs (buffer overflows, crashes, potential code execution). When processing untrusted PDFs:

1. **Use the safe wrapper** (recommended): `safe-pdf.sh`
2. Or apply manual safeguards (timeouts, size limits, validation)

See [Security Considerations](#security-considerations) below.

---

## Quick Reference

| Task | Safe Command | Raw Command |
|------|--------------|-------------|
| Extract text | `safe-pdf.sh text input.pdf` | `pdftotext input.pdf output.txt` |
| Get metadata | `safe-pdf.sh info input.pdf` | `pdfinfo input.pdf` |
| Convert to PNG | `safe-pdf.sh png input.pdf out` | `pdftocairo -png input.pdf out` |
| Merge PDFs | `safe-pdf.sh merge a.pdf b.pdf out.pdf` | `pdfunite a.pdf b.pdf out.pdf` |
| Split pages | `safe-pdf.sh split input.pdf page` | `pdfseparate input.pdf page-%d.pdf` |
| Extract images | `safe-pdf.sh images input.pdf img` | `pdfimages -png input.pdf img` |

---

## Safe Wrapper (Recommended)

The `safe-pdf.sh` wrapper enforces:
- ✅ File size limits (default: 50MB)
- ✅ Page count limits (default: 500 pages)
- ✅ Timeouts (default: 60 seconds)
- ✅ Input validation (magic bytes, pdfinfo check)
- ✅ Filename sanitization (blocks shell injection, path traversal)
- ✅ Output path validation

### Installation

```bash
# Copy to PATH (one-time setup)
cp safe-pdf.sh /usr/local/bin/
chmod +x /usr/local/bin/safe-pdf.sh
```

### Usage

```bash
safe-pdf.sh <command> [options] <input.pdf> [output]

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
    -f <num>    First page
    -l <num>    Last page
    -r <dpi>    Resolution (image output)
    --layout    Preserve layout (text)
    --unsafe    Skip safety checks (use with caution)
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PDF_MAX_SIZE_MB` | 50 | Max input file size |
| `PDF_MAX_PAGES` | 500 | Max pages to process |
| `PDF_TIMEOUT` | 60 | Timeout in seconds |
| `PDF_MAX_OUTPUT_MB` | 100 | Max output size |

### Examples

```bash
# Extract text safely
safe-pdf.sh text document.pdf output.txt

# Extract with layout (for tables)
safe-pdf.sh text --layout invoice.pdf

# Get PDF info
safe-pdf.sh info document.pdf

# Convert to high-res PNG
safe-pdf.sh png -r 300 document.pdf ./images/page

# Only first 10 pages
safe-pdf.sh png -f 1 -l 10 document.pdf ./preview/page

# Merge multiple PDFs
safe-pdf.sh merge report1.pdf report2.pdf combined.pdf

# Split into individual pages
safe-pdf.sh split book.pdf ./chapters/chapter

# Extract embedded images
safe-pdf.sh images document.pdf ./extracted/img
```

---

## Raw Commands (Use with Caution)

For trusted PDFs or when you need full control, use raw poppler commands.

### Text Extraction

```bash
# Basic extraction
pdftotext input.pdf output.txt

# Preserve layout (for tables, forms)
pdftotext -layout input.pdf output.txt

# Specific pages
pdftotext -f 1 -l 5 input.pdf output.txt

# Output to stdout
pdftotext input.pdf -

# TSV with bounding boxes
pdftotext -tsv input.pdf output.tsv
```

### PDF Metadata

```bash
# Basic info
pdfinfo input.pdf

# With page boxes
pdfinfo -box input.pdf

# XML metadata
pdfinfo -meta input.pdf

# Check for JavaScript (security!)
pdfinfo -js input.pdf
```

### Convert to Images

```bash
# PNG (best quality)
pdftocairo -png input.pdf output
# Creates: output-1.png, output-2.png, etc.

# JPEG (smaller files)
pdftocairo -jpeg input.pdf output

# Single page thumbnail
pdftocairo -png -singlefile -f 1 -scale-to 400 input.pdf thumb

# Custom resolution (300 DPI)
pdftocairo -png -r 300 input.pdf output

# SVG (vector)
pdftocairo -svg input.pdf output
```

### Merge PDFs

```bash
pdfunite file1.pdf file2.pdf file3.pdf output.pdf
```

### Split PDFs

```bash
# All pages
pdfseparate input.pdf page-%d.pdf

# Specific range
pdfseparate -f 5 -l 10 input.pdf page-%d.pdf
```

### Extract Images

```bash
# As PNG
pdfimages -png input.pdf output-dir/img

# Keep original format
pdfimages -j input.pdf output-dir/img

# List without extracting
pdfimages -list input.pdf
```

### Convert to HTML

```bash
# Single HTML file
pdftohtml -s input.pdf output.html
```

---

## Common Workflows

### Analyze Unknown PDF (Safe)

```bash
# 1. Quick validation and info
safe-pdf.sh info document.pdf

# 2. Check for JavaScript (potential malware)
pdfinfo -js document.pdf

# 3. Extract text if safe
safe-pdf.sh text document.pdf content.txt
```

### Process Invoice/Receipt

```bash
# Layout-preserved extraction for tables
safe-pdf.sh text --layout invoice.pdf - | head -50
```

### Create Thumbnails

```bash
# First page only, scaled
safe-pdf.sh png -f 1 -l 1 document.pdf thumb
# Or for single file output:
pdftocairo -png -singlefile -f 1 -scale-to 400 document.pdf thumb
```

### Batch Convert Directory

```bash
# Convert all PDFs to PNG (with safety)
for pdf in *.pdf; do
    safe-pdf.sh png "$pdf" "${pdf%.pdf}"
done
```

---

## Security Considerations

### Known Vulnerabilities

Poppler has an active CVE history. Recent issues include:
- **CVE-2025-32365** — Out-of-bounds read (crafted PDF)
- **CVE-2025-32364** — Floating-point exception crash
- **CVE-2024-56378** — Out-of-bounds read
- **CVE-2020-23804** — Infinite recursion in pdfinfo/pdftops

**Keep poppler-utils updated** and monitor security advisories.

### Attack Vectors

| Risk | Description | Mitigation |
|------|-------------|------------|
| **Malicious PDFs** | Crafted files exploit parser bugs | Use safe wrapper, keep updated |
| **DoS (recursion)** | Infinite loops crash process | Timeout enforcement |
| **DoS (resource)** | Huge files exhaust memory/disk | Size and page limits |
| **Command injection** | Malicious filenames | Validate/sanitize filenames |
| **Path traversal** | Write outside intended directory | Validate output paths |
| **JavaScript** | PDFs can contain JS | Check with `pdfinfo -js` |

### Manual Safeguards

If not using `safe-pdf.sh`, apply these manually:

```bash
# 1. Always use timeouts
timeout 30 pdftotext input.pdf output.txt

# 2. Check file size first
size=$(stat -c%s input.pdf)
[[ $size -gt 52428800 ]] && echo "Too large" && exit 1

# 3. Verify it's a PDF
head -c 5 input.pdf | grep -q "%PDF-" || exit 1

# 4. Validate with pdfinfo first
pdfinfo input.pdf > /dev/null 2>&1 || exit 1

# 5. Limit pages for large documents
pdftotext -f 1 -l 100 input.pdf output.txt

# 6. Check for JavaScript
js_check=$(pdfinfo -js input.pdf 2>/dev/null)
[[ -n "$js_check" ]] && echo "Warning: PDF contains JavaScript"
```

### Filename Safety

```bash
# DANGEROUS — command injection possible
pdftotext "$user_input.pdf" output.txt

# SAFER — quote and validate
if [[ "$filename" =~ ^[a-zA-Z0-9._-]+\.pdf$ ]]; then
    pdftotext "$filename" output.txt
fi
```

### Sandboxing

For maximum security with untrusted PDFs:

```bash
# Run in isolated container
docker run --rm -v ./input:/data:ro poppler pdftotext /data/file.pdf

# Or use firejail
firejail --private pdftotext untrusted.pdf output.txt
```

---

## Limitations

- **No PDF creation**: poppler extracts/converts but doesn't create PDFs from scratch
- **No OCR**: For scanned documents, combine with `tesseract`
- **No form filling**: Cannot modify PDF form fields
- **No digital signatures**: Can read (`pdfsig`) but not sign

For PDF generation from HTML/Markdown, consider `weasyprint` or `pandoc`.

---

## Version Info

```bash
pdftotext -v 2>&1 | head -1
# pdftotext version 25.03.0
```

Check for updates: https://poppler.freedesktop.org/releases.html

Debian security tracker: https://security-tracker.debian.org/tracker/source-package/poppler
