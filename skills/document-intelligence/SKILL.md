---
name: document-intelligence
description: Use when reading, extracting, summarizing, or citing from PDF / Word / Markdown / HTML / EPUB documents. Triggers on "read this pdf", "extract from word", "summarize paper", "cite from document", "/pdf-read", "/doc-extract", "/doc-summarize".
---

# document-intelligence

Pattern untuk Claude baca, extract, summarize, dan cite dari dokumen offline. Fokus pada local-first (no cloud upload) + reproducibility.

## Tools yang tersedia

| Format | Tool | Install |
|---|---|---|
| **PDF** | PyMuPDF (`fitz`) | `pip install pymupdf` |
| **Word (.docx)** | python-docx | `pip install python-docx` |
| **Universal converter** | pypandoc + pandoc | `pip install pypandoc` + `apt install pandoc` |
| **Markdown / HTML** | native (stdlib) | built-in |
| **EPUB** | ebooklib | `pip install ebooklib` |
| **OCR (scanned PDF)** | pytesseract + tesseract | `pip install pytesseract` + `apt install tesseract` |
| **Tables (advanced)** | camelot / tabula-py | `pip install camelot-py[cv]` |

PyMuPDF + python-docx + pypandoc sudah ter-install di env ini.

## When to use which

| Task | Best tool |
|---|---|
| Read PDF (text-based) | PyMuPDF |
| Read PDF (scanned/image) | OCR via pytesseract |
| Extract tables from PDF | camelot atau tabula |
| Read .docx | python-docx |
| Read .doc (legacy) | pypandoc convert → markdown |
| Read .odt, .rtf, .epub | pypandoc convert → markdown |
| Read .pptx | python-pptx atau pypandoc |
| Read .xlsx | openpyxl atau pandas |

## PyMuPDF — basic PDF reading

```python
import fitz  # PyMuPDF

doc = fitz.open("paper.pdf")
print(f"Pages: {doc.page_count}")
print(f"Metadata: {doc.metadata}")

# Extract per-page text
for page_num, page in enumerate(doc, start=1):
    text = page.get_text()
    print(f"--- Page {page_num} ---")
    print(text[:500])  # preview
```

## Extract with structure (headings, paragraphs)

PyMuPDF blocks API preserves layout:

```python
import fitz

doc = fitz.open("paper.pdf")

for page in doc:
    blocks = page.get_text("dict")["blocks"]
    for block in blocks:
        if block["type"] == 0:  # text block
            for line in block["lines"]:
                for span in line["spans"]:
                    font_size = span["size"]
                    flags = span["flags"]
                    is_bold = flags & 2**4  # bold flag
                    if is_bold or font_size > 12:
                        # likely heading
                        print(f"[H] {span['text']}")
                    else:
                        print(span["text"])
```

## Extract images from PDF

```python
import fitz

doc = fitz.open("paper.pdf")
for page_num, page in enumerate(doc, start=1):
    for img_index, img in enumerate(page.get_images(full=True)):
        xref = img[0]
        pix = fitz.Pixmap(doc, xref)
        if pix.n - pix.alpha > 3:  # CMYK
            pix = fitz.Pixmap(fitz.csRGB, pix)
        pix.save(f"page{page_num}_img{img_index}.png")
        pix = None
```

## Extract tables from PDF

```python
import camelot

tables = camelot.read_pdf("paper.pdf", pages="1-end", flavor="lattice")
print(f"Found {len(tables)} tables")

for i, table in enumerate(tables):
    print(f"--- Table {i} (accuracy: {table.accuracy:.2f}) ---")
    print(table.df.head())
    table.to_csv(f"table_{i}.csv")
```

## python-docx — Word reading

```python
from docx import Document

doc = Document("report.docx")

# Paragraphs
for para in doc.paragraphs:
    style = para.style.name  # Heading 1, Normal, dll
    text = para.text
    if style.startswith("Heading"):
        print(f"[{style}] {text}")
    else:
        print(text)

# Tables
for table_idx, table in enumerate(doc.tables):
    print(f"--- Table {table_idx} ---")
    for row in table.rows:
        cells = [cell.text for cell in row.cells]
        print(" | ".join(cells))
```

## pypandoc — universal converter

```python
import pypandoc

# Convert ke markdown (preserve structure)
md = pypandoc.convert_file("paper.docx", "md")
print(md)

# Batch convert
for f in ["doc1.docx", "doc2.rtf", "doc3.odt"]:
    md = pypandoc.convert_file(f, "md")
    out = f.replace(".", "_") + ".md"
    with open(out, "w") as fp:
        fp.write(md)
```

## OCR untuk scanned PDF

```python
import fitz
import pytesseract
from PIL import Image
import io

doc = fitz.open("scanned.pdf")
full_text = []

for page_num, page in enumerate(doc, start=1):
    # Render page ke image
    pix = page.get_pixmap(dpi=300)
    img = Image.open(io.BytesIO(pix.tobytes("png")))

    # OCR
    text = pytesseract.image_to_string(img, lang="eng+ind")  # multi-lang
    full_text.append(f"--- Page {page_num} ---\n{text}")

print("\n".join(full_text))
```

## Chunking untuk RAG (lihat skill `rag-patterns`)

```python
from langchain.text_splitter import RecursiveCharacterTextSplitter

# Extract full text
full_text = ""
for page in doc:
    full_text += page.get_text() + "\n\n"

# Chunk dengan metadata page number
splitter = RecursiveCharacterTextSplitter(chunk_size=512, chunk_overlap=64)

# Better: chunk per-page untuk preserve page citations
chunks = []
for page_num, page in enumerate(doc, start=1):
    page_text = page.get_text()
    page_chunks = splitter.split_text(page_text)
    for i, chunk in enumerate(page_chunks):
        chunks.append({
            "text": chunk,
            "metadata": {
                "source": "paper.pdf",
                "page": page_num,
                "chunk_index": i,
            },
        })

# Save ke vector store
from langchain.vectorstores import Chroma
from langchain.embeddings import HuggingFaceEmbeddings

embeddings = HuggingFaceEmbeddings(model_name="BAAI/bge-m3")
vectorstore = Chroma.from_documents(
    documents=[Document(page_content=c["text"], metadata=c["metadata"]) for c in chunks],
    embedding=embeddings,
    persist_directory="./chroma_db",
)
```

## Summarization patterns

### Extract summary (cepat, no LLM)
```python
import fitz

doc = fitz.open("paper.pdf")

# Ambil abstract + conclusion biasanya di awal & akhir
abstract_section = []
conclusion_section = []

for page_num, page in enumerate(doc, start=1):
    text = page.get_text().lower()
    if page_num <= 3 and ("abstract" in text or "introduction" in text):
        abstract_section.append(page.get_text())
    if page_num >= doc.page_count - 2 and "conclusion" in text:
        conclusion_section.append(page.get_text())
```

### LLM summary (panggil Claude API)
```python
import anthropic

client = anthropic.Anthropic()

def summarize_document(text: str, max_words: int = 500) -> str:
    msg = client.messages.create(
        model="claude-sonnet-5",
        max_tokens=1024,
        messages=[{
            "role": "user",
            "content": f"""Summarize the following document in {max_words} words or less.
Focus on: main thesis, key arguments, methodology, findings, implications.
Output format: markdown with sections (Thesis, Arguments, Method, Findings, Implications).

<document>
{text[:100000]}  # truncate ke 100k chars untuk fit context
</document>""",
        }],
    )
    return msg.content[0].text

# Usage
full_text = "\n\n".join(page.get_text() for page in doc)
summary = summarize_document(full_text)
```

## Citation patterns

Saat refer ke dokumen, selalu include source + page/paragraph:

```markdown
According to [Smith et al., 2023, p. 5], the model achieves 92% accuracy
on the benchmark. The methodology section [p. 3] describes a novel
training procedure using...
```

Format citations:
- **PDF**: `[Author et al., Year, p. N]` atau `[Doc name, p. N]`
- **Word**: `[Doc name, Section X.Y, ¶ N]` atau `[Doc name, page N]`
- **Web**: `[URL, accessed YYYY-MM-DD]`

## Common pitfalls

| Pitfall | Solusi |
|---|---|
| PDF text kosong | Scanned PDF, pakai OCR (pytesseract) |
| Tabel berantakan | camelot / tabula, atau pandas.read_html kalau web |
| Encoding salah | `page.get_text("text", flags=fitz.TEXT_PRESERVE_WHITESPACE)` |
| Formula matematika | KaTeX/Mathpix; atau extract as image dan rujuk visual |
| Dokumen sangat besar (>1000 pages) | Chunk + summarize per section, jangan load all |
| PDF ter-encrypt (password) | `fitz.open(path, password="...")` atau decrypt dulu |
| Multi-column layout | `page.get_text("blocks")` lalu sort by Y coordinate |
| Bahasa campuran | OCR `lang="eng+ind+jpn"` atau per-bahasa pipeline |
| Image-heavy doc | Extract images + caption text separately, link via position |

## Workflow untuk Claude session

1. **Read**: `Read(path)` atau Bash dengan python script
2. **Extract**: PyMuPDF / python-docx / pypandoc
3. **Chunk** (kalau panjang): split per page atau section
4. **Process**: summarize / answer questions / compare dengan doc lain
5. **Cite**: selalu include `[source, page]` di output

## Install kalau belum

```bash
pip install --user pymupdf python-docx pypandoc
# Optional:
pip install --user ebooklib pytesseract camelot-py[cv] openpyxl
# System deps:
sudo dnf install pandoc tesseract tesseract-eng tesseract-ind
```

## Privacy + security

- ❌ Jangan upload dokumen ke cloud service tanpa consent
- ✅ Local-first: PyMuPDF + python-docx process di lokal
- ✅ Redact PII sebelum summarize kalau di-share
- ✅ Hati-hati proprietary docs — jangan paste ke public chat

## Performance tips

| Doc size | Strategy |
|---|---|
| < 50 pages | Load all in context |
| 50-200 pages | Load summary dulu, drill-down per section |
| 200-1000 pages | Chunk + vector store + retrieval |
| > 1000 pages | Index dulu, query per-chunk via RAG |

## Invokation

Auto-trigger saat:
- Edit file path mengandung `.pdf`, `.docx`, `.doc`, `.odt`, `.epub`, `.rtf`
- User sebut "pdf", "word", "document", "paper", "report", "summarize", "extract"
- Slash command: `/pdf-read`, `/doc-extract`, `/doc-summarize`
