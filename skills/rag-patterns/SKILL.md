---
name: rag-patterns
description: Use when building RAG (Retrieval-Augmented Generation) systems — chunking strategies, embedding models, vector stores, retrieval (BM25/hybrid), reranking, evaluation, anti-patterns. Trigger on "rag", "retrieval", "embedding", "vector db", "chunking", "/rag-design".
---

# rag-patterns

RAG architecture patterns untuk LLM apps yang perlu akses ke knowledge base eksternal.

## Pipeline standard

```
[Documents]
    ↓ loaders (PDF, HTML, MD, DOCX, CSV, API)
[Parsed text]
    ↓ chunking (semantic / fixed / recursive)
[Chunks] (300-1000 tokens, overlap 10-20%)
    ↓ embedding model (bge-small, text-embedding-3-small)
[Vectors]
    ↓ store (pgvector, Chroma, Weaviate, Qdrant)
[Vector DB]

[Query]
    ↓ embedding
[Query vector]
    ↓ retrieval (top-k, hybrid)
[Candidate chunks]
    ↓ reranking (cross-encoder)
[Final context]
    ↓ prompt template
[LLM]
[Answer]
```

## Chunking strategies

| Strategy | Use case | Trade-off |
|---|---|---|
| **Fixed-size** | Simple, predictable | Break semantic units |
| **Recursive char split** | General text (langchain default) | Works for most cases |
| **Sentence splitter** | Q&A, conversational | Loses paragraph context |
| **Semantic chunking** | Variable content | Best quality, slower |
| **Document-aware** (markdown header, code AST) | Structured docs | Requires parser per format |
| **Sliding window with overlap** | Long context needed | Duplicate storage cost |

**Default rule**: chunk size 512 tokens, overlap 64 tokens, recursive splitter dengan markdown/code awareness.

```python
from langchain.text_splitter import RecursiveCharacterTextSplitter

splitter = RecursiveCharacterTextSplitter(
    chunk_size=512,
    chunk_overlap=64,
    separators=["\n\n", "\n", ". ", " ", ""],
)
```

## Embedding models (2025-2026)

| Model | Dim | Multilingual | Cost | Notes |
|---|---|---|---|---|
| `text-embedding-3-small` (OpenAI) | 1536 | Ya | $0.02/1M | Default quality/cost |
| `text-embedding-3-large` (OpenAI) | 3072 | Ya | $0.13/1M | Higher accuracy |
| `voyage-3` (Voyage AI) | 1024 | Ya | $0.06/1M | Retrieval-specialized |
| `bge-m3` (BAAI) | 1024 | Ya | Free (self-host) | SOTA open, multilingual |
| `nomic-embed-text-v1.5` | 768 | Ya | Free (self-host) | Matryoshka (variable dim) |
| `cohere-embed-multilingual-v3` | 1024 | Ya | $0.10/1M | Strong i18n |
| `mxbai-embed-large` | 1024 | Limited | Free (self-host) | English-only SOTA |

**Pick by use case:**
- Budget ketat + self-host: `bge-m3` atau `nomic-embed-text`
- API OK + multilingual: `text-embedding-3-small`
- Retrieval-only (no general purpose): `voyage-3`

## Vector store pilihan

| Store | Best for | Scale | Self-host |
|---|---|---|---|
| **pgvector** | Postgres already in stack | Millions | Yes |
| **Chroma** | Prototype, local-first | Thousands | Yes |
| **Weaviate** | Production hybrid search | Billions | Yes |
| **Qdrant** | High-perf Rust-based | Billions | Yes |
| **LanceDB** | Embedded (serverless) | Millions | Yes |
| **Pinecone** | Managed, zero-ops | Billions | No |
| **Milvus** | Distributed, GPU-accel | Billions | Yes |

**Default**: pgvector kalau Postgres sudah dipakai. Else Qdrant untuk production.

## Retrieval strategies

### Dense (semantic) — default
```python
results = vector_store.similarity_search(query, k=10)
```

### Sparse (BM25 / keyword) — bagus untuk exact match
```python
# pakai rank_bm25 atau elasticsearch
```

### Hybrid (gabungan) — production recommended
```python
from langchain.retrievers import EnsembleRetriever

dense = vector_store.as_retriever(search_kwargs={"k": 10})
sparse = bm25_retriever

hybrid = EnsembleRetriever(
    retrievers=[dense, sparse],
    weights=[0.7, 0.3],  # tune
)
```

### Multi-query / HyDE / Step-back
Generate beberapa variasi query untuk handle ambiguity:
```python
# multi-query
queries = generate_related_queries_llm(original_query, n=3)
all_docs = []
for q in queries:
    all_docs.extend(retriever.invoke(q))
# deduplicate + rerank
```

### Self-query / metadata filtering
Extract filter dari natural language:
```python
# "papers from 2024 about transformers"
# → filter={"year": 2024, "topic": "transformers"}
```

## Reranking (critical untuk quality)

First-stage retrieval = recall tinggi (top-k 20-50). Second-stage rerank = precision tinggi.

```python
from sentence_transformers import CrossEncoder

reranker = CrossEncoder("BAAI/bge-reranker-v2-m3")  # multilingual SOTA

def rerank(query: str, docs: list, top_k: int = 5) -> list:
    pairs = [[query, d.page_content] for d in docs]
    scores = reranker.predict(pairs)
    ranked = sorted(zip(docs, scores), key=lambda x: x[1], reverse=True)
    return [d for d, s in ranked[:top_k]]
```

## Evaluation (lihat skill `eval-harness`)

RAG eval metrics:
- **Context precision**: % retrieved chunks yang relevan
- **Context recall**: % ground-truth chunks yang ke-retrieve
- **Faithfulness**: jawaban didukung context (no hallucination)
- **Answer relevance**: jawaban menjawab query

Tool: `ragas`, `deepeval`, atau custom LLM-as-judge.

```python
from ragas import evaluate
from ragas.metrics import context_precision, faithfulness, answer_relevancy

results = evaluate(
    dataset,
    metrics=[context_precision, faithfulness, answer_relevancy],
)
```

## Anti-patterns

❌ **Chunk terlalu besar** (>1500 token): noise, mahal embedding, recall turun
❌ **Chunk terlalu kecil** (<100 token): konteks hilang, embedding generic
❌ **No overlap**: info di boundary hilang
❌ **Top-k = 3 atau kurang**: recall rendah, miss jawaban valid
❌ **No reranking**: top-k besar noisy, LLM overwhelmed
❌ **Embedding English-only + multilingual corpus**: cosine distance meaningless antar bahasa
❌ **Re-embed setiap restart**: simpan metadata `embedding_model` + `embedding_date` di metadata chunk
❌ **No source citation di jawaban**: hallucination risk, user tidak bisa verify
❌ **Vector store tanpa backup**: data hilang saat drop DB
❌ **Pakai cosine untuk binary embeddings**: harus hamming/Jaccard

## Cost optimization

```python
# Cache embeddings
@lru_cache(maxsize=10000)
def embed(text: str) -> list[float]:
    return embedding_model.embed_query(text)

# Batch embed untuk bulk load
texts = [chunk.text for chunk in chunks]
vectors = embedding_model.embed_documents(texts)  # batched internally

# Re-rank hanya top-N candidates
candidates = retriever.invoke(query, k=50)
final = rerank(query, candidates, top_k=5)
```

## When NOT pakai RAG

| Case | Use instead |
|---|---|
| Data sedikit (< 100 docs) | Full context in prompt |
| Real-time data (pricing, stock) | Function calling / API |
| Structured queries (SQL) | Text-to-SQL |
| Data updates tiap detik | Streaming + cache |
| Reasoning-heavy tasks | ReAct agent + tools |

## Invokation

Auto-trigger saat:
- User sebut "rag", "retrieval", "embedding", "vector"
- Build chat with knowledge base / docs
- Implementasi QA over PDF/web/code