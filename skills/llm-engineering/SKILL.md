---
name: llm-engineering
description: Use when building LLM-powered applications — structured outputs via Pydantic, prompt versioning, token/cost tracking, evaluation harness integration, retry/caching patterns. Trigger on "structured output", "token count", "prompt version", "llm eval", "pydantic ai", "anthropic sdk".
---

# llm-engineering

Pattern untuk aplikasi LLM yang production-ready: type-safe, terukur, reproducible.

## Structured output via Pydantic

**WAJIB** untuk output LLM yang masuk ke logika downstream. JSON mode + manual parsing = fragile.

### Anthropic SDK

```python
from pydantic import BaseModel, Field
from anthropic import Anthropic

class InvoiceExtraction(BaseModel):
    vendor: str = Field(description="Nama vendor")
    total: float = Field(description="Total dalam IDR")
    items: list[str] = Field(description="Daftar item")
    due_date: str = Field(description="YYYY-MM-DD")

client = Anthropic()
response = client.messages.create(
    model="claude-sonnet-5",
    max_tokens=1024,
    messages=[{"role": "user", "content": prompt}],
    tools=[{
        "name": "extract_invoice",
        "description": "Extract invoice fields",
        "input_schema": InvoiceExtraction.model_json_schema(),
    }],
)

# Extract tool use
for block in response.content:
    if block.type == "tool_use" and block.name == "extract_invoice":
        result = InvoiceExtraction(**block.input)
        # result fully validated
```

### OpenAI SDK

```python
from pydantic import BaseModel
from openai import OpenAI

class InvoiceExtraction(BaseModel):
    vendor: str
    total: float

client = OpenAI()
completion = client.beta.chat.completions.parse(
    model="gpt-4",
    messages=[{"role": "user", "content": prompt}],
    response_format=InvoiceExtraction,
)

result: InvoiceExtraction = completion.choices[0].message.parsed
# Type-safe, no json.loads, no manual validation
```

## Token tracking & cost

### Per-call tracking

```python
from anthropic import Anthropic

client = Anthropic()
response = client.messages.create(...)

usage = response.usage
print(f"input: {usage.input_tokens}, output: {usage.output_tokens}")
# log ke mlflow (lihat ds-workflow skill)
mlflow.log_metrics({
    "tokens_input": usage.input_tokens,
    "tokens_output": usage.output_tokens,
})
```

### Cost calculation (rough, Anthropic Claude Sonnet 5)

```python
# Per juta token, update sesuai pricing aktual
COST = {
    "claude-sonnet-5": {"input": 3.0, "output": 15.0},  # USD per 1M tokens
    "claude-haiku-4-5": {"input": 0.80, "output": 4.0},
}

def calc_cost(model: str, in_tok: int, out_tok: int) -> float:
    rates = COST.get(model, {"input": 0, "output": 0})
    return (in_tok / 1e6) * rates["input"] + (out_tok / 1e6) * rates["output"]

mlflow.log_metric("cost_usd", calc_cost(model, usage.input_tokens, usage.output_tokens))
```

### Caching untuk hemat biaya

Anthropic prompt caching (5-minute TTL default):

```python
response = client.messages.create(
    model="claude-sonnet-5",
    system=[
        {
            "type": "text",
            "text": long_system_prompt,  # rarely changes
            "cache_control": {"type": "ephemeral"},
        }
    ],
    messages=[{"role": "user", "content": query}],
)
# Cek cache hit di usage
print(usage.cache_creation_input_tokens, usage.cache_read_input_tokens)
```

## Prompt versioning

**Jangan** hardcode prompt string di kode. Pakai file terpisah + versioning.

```
project/
├── prompts/
│   ├── extract_invoice.v1.txt
│   ├── extract_invoice.v2.txt    # iterasi
│   └── summarize.v1.txt
├── prompts_loader.py
```

```python
from pathlib import Path
import mlflow

PROMPTS_DIR = Path(__file__).parent / "prompts"

def load_prompt(name: str, version: int = 1) -> str:
    path = PROMPTS_DIR / f"{name}.v{version}.txt"
    if not path.exists():
        raise FileNotFoundError(f"Prompt {name} v{version} not found")
    return path.read_text()

# log ke mlflow untuk reproducibility
mlflow.log_param("prompt_name", "extract_invoice")
mlflow.log_param("prompt_version", 2)
mlflow.log_artifact("prompts/extract_invoice.v2.txt")
```

## Retry & resilience

### Exponential backoff

```python
import time
import random
from anthropic import APIError, RateLimitError

def call_with_retry(fn, *, max_retries=5, base_delay=1.0):
    for attempt in range(max_retries):
        try:
            return fn()
        except RateLimitError:
            if attempt == max_retries - 1:
                raise
            delay = base_delay * (2 ** attempt) + random.uniform(0, 1)
            time.sleep(delay)
        except APIError as e:
            if e.status_code >= 500 and attempt < max_retries - 1:
                time.sleep(base_delay * (2 ** attempt))
            else:
                raise
```

### Fallback model

```python
PRIMARY = ("claude-sonnet-5", Anthropic())
FALLBACK = ("claude-haiku-4-5", Anthropic())

def call_with_fallback(messages, **kwargs):
    for model_name, client in [PRIMARY, FALLBACK]:
        try:
            return client.messages.create(model=model_name, messages=messages, **kwargs)
        except (APIError, RateLimitError) as e:
            last_err = e
            continue
    raise last_err
```

## Evaluation (integrasi `eval-harness` skill)

Sebelum deploy perubahan prompt/model:

1. Tulis `eval_set.jsonl` dengan ~20-50 test cases (input + expected output).
2. Jalankan eval pakai `eval-harness` skill.
3. Track pass@k di mlflow sebagai regression metric.
4. Bandingkan dua versi prompt sebelum promote.

```python
# pseudo-code
for prompt_version in [1, 2]:
    prompt = load_prompt("extract_invoice", version=prompt_version)
    with mlflow.start_run(run_name=f"prompt-v{prompt_version}"):
        mlflow.log_param("prompt_version", prompt_version)
        results = run_eval_set(eval_set, prompt)
        mlflow.log_metric("pass_at_1", results["pass_at_1"])
        mlflow.log_metric("exact_match", results["exact_match"])
```

## Streaming untuk UX

```python
with client.messages.stream(
    model="claude-sonnet-5",
    max_tokens=1024,
    messages=[{"role": "user", "content": prompt}],
) as stream:
    for text in stream.text_stream:
        print(text, end="", flush=True)

# Hitung usage setelah stream selesai
final = stream.get_final_message()
print(final.usage)
```

## Common pitfalls

| Pitfall | Solusi |
|---|---|
| JSON output tidak konsisten | Pakai `tools` + `input_schema` (Anthropic) atau `response_format=Pydantic` (OpenAI) |
| Biaya membengkak tanpa sadar | Log `tokens_input/output` per call, alert kalau spike |
| Prompt drift antar versi | Versioning via file + log ke mlflow |
| Rate limit mendadak | Exponential backoff + queue (Celery/RQ) |
| Output hallucination di production | LLM-as-judge eval + human spot-check berkala |
| Caching tidak hit | Cek `cache_control` di system prompt, bukan di message user |

## Invokation

Auto-trigger saat:
- Edit file yang import `anthropic`, `openai`, `langchain`, `pydantic_ai`
- User sebut "structured output", "function calling", "tool use"
- Code pattern detection: `client.messages.create`, `chat.completions.create`
