---
name: natural-writing
description: Use when writing documentation (README, docs, blog, commit messages) to avoid AI-tells — banned phrases, active voice, concrete examples, direct start. Trigger on "write readme", "natural writing", "anti-ai", "human voice", "docs style".
---

# natural-writing

Style guide untuk technical writing yang natural, tidak kelihatan AI-generated. Cocok untuk README, docs, blog posts, commit messages.

## Banned phrases (AI-tells)

Hapus dari draft:

| ❌ Banned | ✅ Alternative |
|---|---|
| "In this article, we'll explore" | Langsung ke point: "X works by..." |
| "Let's dive in" / "Let's delve" | Skip, langsung content |
| "It's important to note that" | Hapus, atau move ke point utama |
| "leverage" | "use" |
| "robust" / "seamless" / "cutting-edge" | Deskripsi konkret apa yang robust |
| "comprehensive" | List apa saja yang di-cover |
| "tapestry" / "symphony" / "ecosystem" (kecuali literal ecosystem) | Plain word |
| "embark on a journey" | Hapus |
| "navigate the complexities" | "handle X" |
| "in the realm of" | Hapus |
| "moreover" / "furthermore" | "also", atau pisah jadi 2 kalimat |
| "It is worth noting" | Hapus |
| "plays a crucial role" | Hapus atau "X is needed for Y" |
| "delve into" | "explore", atau langsung explain |
| "harness the power of" | Hapus |
| "unlock the potential" | Hapus |
| "elevate your workflow" | Hapus |
| "in today's fast-paced world" | Hapus |
| "whether you're a beginner or expert" | Skip, atau pisah per audience |
| "without further ado" | Hapus |

## Emoji policy

Default: **no emoji**. Exception:
- README badge status (CI, license) — itu memang icon
- CLI tools output example
- Slack/Discord message

❌ **Jangan**: 🎉✨🚀💡🔥 di section header, "🚀 Quick Start", "🎯 Features"  
✅ **Boleh**: Status badge di README top

## Sentence style

### Active voice > passive
```markdown
❌ The file is read by the parser.
✅ The parser reads the file.

❌ A bug was introduced in v2.
✅ v2 introduced a bug.
```

### Concrete > abstract
```markdown
❌ "This library provides a robust solution for data processing."
✅ "Parses CSV/JSON/Parquet. 10x faster than pandas for files >1GB."
```

### Short sentences
```markdown
❌ "The function, which takes a configuration object as its parameter and returns a Promise that resolves with the result of the asynchronous operation, is documented below."
✅ "Takes a config object. Returns a Promise."
```

### Direct start, no preamble
```markdown
❌ "Welcome to the Foo library! We're excited to share this with you. In this README, we'll cover installation, usage, and advanced features."
✅ "Foo parses CSV files 10x faster than pandas.

Install: `pip install foo`"
```

## README structure template

```markdown
# Project Name

One-line description: what it does + for whom.

## Install

[code block]

## Usage

Minimal example yang langsung jalan.

## API / Reference

[link to docs site atau table]

## Configuration

[table atau bullet list]

## License

MIT
```

Skip section yang tidak perlu:
- ❌ "Introduction" / "Overview" boilerplate
- ❌ "Motivation" panjang (kalau README, ringkas saja)
- ❌ "Roadmap" yang berisi wishlist tanpa timeline
- ❌ "Acknowledgments" panjang
- ❌ "Contributing" generic (link ke CONTRIBUTING.md kalau ada detail)

## Commit message style

```
feat: add rag retrieval pipeline

BM25 + dense hybrid search, rerank dengan bge-reranker-v2.
```

✅ Specific, imperative, max 72 char subject.  
❌ "I've added a new feature for retrieving documents using a sophisticated hybrid approach combining BM25 and dense embeddings with state-of-the-art reranking."

## Code comments

```python
# ❌ AI-style: explains what (which code already shows)
# This function calculates the sum of all the numbers in the list
def sum_list(numbers):
    return sum(numbers)

# ✅ Human-style: explains why atau edge case
# NaN di-sum as 0 untuk avoid propagation di downstream
def sum_list(numbers):
    return sum(n or 0 for n in numbers)
```

## Variable + function naming

❌ `processData()`, `handleRequest()`, `performCalculation()`  
✅ `parse_csv()`, `route_request()`, `compute_total()`

Specific verbs > generic "process/handle/perform".

## Documentation anti-patterns

❌ **Tautology**: "This is a fast function that performs quickly"  
❌ **Hedge stack**: "It might be the case that possibly..."  
❌ **Filler lists**: "Features: - Easy - Simple - Powerful" (no meaning)  
❌ **Apologetic**: "Sorry, this is a bit complex but..."  
❌ **Self-promotion**: "We're proud to announce..." (just describe it)  

## Before/after examples

### Before (AI-feel)
> "In this comprehensive guide, we'll embark on a journey to explore the intricate tapestry of modern data processing. Whether you're a seasoned developer or just starting out, this robust library will seamlessly revolutionize your workflow. Let's dive in!"

### After (natural)
> "Parses CSV/JSON/Parquet. Use it when pandas is too slow for files >1GB.

```python
import foo
foo.read_csv('big.csv')  # 10x faster than pandas
```"

## When to break the rules

Style guide ini default. Break kalau:
- Marketing copy (boleh sedikit hype)
- Tutorial blog post (boleh sedikit personal)
- Open source README yang memang playful

Intinya: match audience expectation. Untuk technical docs/dev tools, default to clean + direct.

## Quick checklist sebelum publish

- [ ] Scan draft untuk banned phrases
- [ ] Tidak ada emoji berlebihan
- [ ] First sentence langsung to the point
- [ ] Concrete examples untuk setiap claim
- [ ] Active voice dominan
- [ ] Sentence length rata-rata < 20 kata
- [ ] Tidak ada preamble ("Welcome to...", "Let's explore...")

## Integration dengan skills lain

- `update-docs` / `update-codemaps`: apply style ini
- `fullstack-web`: README + API docs style
- `commit` (slash command): subject max 72 char, imperative
- `CONTRIBUTING.md`: pakai commit convention + style guide

## Per-language notes

### Indonesian (campuran English, gaya user)
User sering pakai code-switching. Itu natural, bukan AI-tell. Match:
- Technical terms in English (`git push`, `commit`)
- Narasi bisa Indonesia atau English
- Drop "silakan", "mari kita" kalau langsung to the point OK

### English
Strict no-preamble. Start dengan what + why dalam 1-2 kalimat.

## Invokation

Auto-trigger:
- Edit `README.md`, `CONTRIBUTING.md`, docs files
- Reference ke "write doc", "natural", "anti-ai"
- Slash command: `/natural-write`, `/deai`
