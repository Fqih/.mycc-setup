---
description: Baca PDF/Word document — extract text, struktur (headings/tables), summarize, atau chunk untuk RAG. Default local-first pakai PyMuPDF + python-docx + pypandoc.
---

Baca document file, extract + summarize. Default local processing (no cloud upload).

## Usage

```
/pdf-read <path> [--pages N] [--mode extract|summarize|chunk] [--query "..."]
```

Examples:
```
/pdf-read paper.pdf
/pdf-read paper.pdf --pages 1-10
/pdf-read paper.pdf --mode summarize
/pdf-read paper.pdf --mode chunk --query "find the methodology section"
/pdf-read report.docx --mode extract
/pdf-read presentation.pptx --mode extract
```

## Step 1: Detect format

```bash
file_path="$1"
extension="${file_path##*.}"
extension=$(echo "$extension" | tr '[:upper:]' '[:lower:]')

case "$extension" in
    pdf)  tool="pymupdf" ;;
    docx|doc)  tool="python-docx" ;;
    odt|rtf|epub|pptx)  tool="pypandoc" ;;
    *)  echo "Unsupported format: $extension"; exit 1 ;;
esac
```

## Step 2: Extract (mode default)

### PDF (PyMuPDF)

```python
import fitz
import sys

path = sys.argv[1]
doc = fitz.open(path)

# Optional: page range
pages_arg = sys.argv[2] if len(sys.argv) > 2 else None  # e.g., "1-10"

start, end = 0, doc.page_count
if pages_arg and "-" in pages_arg:
    start, end = map(int, pages_arg.split("-"))
    start = max(0, start - 1)
    end = min(doc.page_count, end)

for page_num in range(start, end):
    page = doc[page_num]
    print(f"--- Page {page_num + 1} of {doc.page_count} ---")
    print(page.get_text())
```

### Word (python-docx)

```python
from docx import Document
import sys

doc = Document(sys.argv[1])

for para in doc.paragraphs:
    style = para.style.name
    text = para.text
    if style.startswith("Heading"):
        print(f"\n[{style}] {text}\n")
    elif text.strip():
        print(text)

for table_idx, table in enumerate(doc.tables):
    print(f"\n--- Table {table_idx} ---")
    for row in table.rows:
        cells = [cell.text.strip() for cell in row.cells]
        print(" | ".join(cells))
```

### Universal (pypandoc)

```python
import pypandoc
import sys

md = pypandoc.convert_file(sys.argv[1], "md")
print(md)
```

## Step 3: Summarize mode

```python
import fitz
import anthropic

doc = fitz.open(sys.argv[1])
full_text = "\n\n".join(page.get_text() for page in doc)

# Truncate kalau terlalu panjang
if len(full_text) > 100000:
    full_text = full_text[:100000] + "\n\n[... truncated ...]"

client = anthropic.Anthropic()
msg = client.messages.create(
    model="claude-sonnet-5",
    max_tokens=1500,
    messages=[{
        "role": "user",
        "content": f"""Summarize this document in 500 words or less.
Use markdown sections: Thesis, Key Arguments, Methodology, Findings, Implications.

<document>
{full_text}
</document>""",
    }],
)
print(msg.content[0].text)
```

## Step 4: Chunk mode (untuk RAG)

```python
import fitz
import json

doc = fitz.open(sys.argv[1])
chunks = []

for page_num, page in enumerate(doc, start=1):
    page_text = page.get_text()
    # Simple chunking: paragraph-based
    paragraphs = [p.strip() for p in page_text.split("\n\n") if p.strip()]
    for i, para in enumerate(paragraphs):
        chunks.append({
            "text": para,
            "metadata": {
                "source": sys.argv[1],
                "page": page_num,
                "chunk_index": i,
            },
        })

# Output JSON
with open("chunks.json", "w") as f:
    json.dump(chunks, f, indent=2)

print(f"Wrote {len(chunks)} chunks to chunks.json")
```

## Step 5: OCR fallback (kalau PDF text kosong)

```python
import fitz
import pytesseract
from PIL import Image
import io

doc = fitz.open(sys.argv[1])

for page_num, page in enumerate(doc, start=1):
    pix = page.get_pixmap(dpi=300)
    img = Image.open(io.BytesIO(pix.tobytes("png")))
    text = pytesseract.image_to_string(img, lang="eng+ind")
    print(f"--- Page {page_num} (OCR) ---")
    print(text)
```

Deteksi scanned PDF: cek apakah `page.get_text()` kosong atau `< 50 chars` per page. Kalau ya, fallback ke OCR.

## Step 6: Citation format

Saat refer ke dokumen dalam jawaban, selalu cite:
- PDF: `[filename, p. N]`
- Word: `[filename, Section X.Y]` atau `[filename, ¶ N]`
- Web: `[URL, accessed YYYY-MM-DD]`

## Common pitfalls

| Symptom | Fix |
|---|---|
| PDF text kosong | Scanned — pakai OCR |
| Tabel berantakan | camelot atau convert ke Excel via pypandoc |
| Formula tidak extract | Mathpix API atau extract as image |
| Encoding mojibake | Specify encoding atau pakai PyMuPDF (handles internal) |
| Password-protected | `fitz.open(path, password="...")` |

Lihat skill `document-intelligence` untuk detail lengkap + advanced patterns.

## Privacy

❌ Jangan upload dokumen proprietary ke cloud tanpa consent  
✅ Local processing by default — PyMuPDF + python-docx stay local  
✅ Redact PII sebelum share summary
