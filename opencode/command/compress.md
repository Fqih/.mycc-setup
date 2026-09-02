---
description: Compress long text via local Ollama (qwen3.5:9b-ctx), saves API tokens
---

Compress input text using local Ollama model.

```
content="$ARGUMENTS"
[ -z "$content" ] && { echo "Usage: /compress <text or path>"; exit 1; }
printf 'You are a log compressor. Summarize concisely (max 2000 chars). Preserve errors, warnings, key events. Strip redundant timestamps and noise.\n\n%s' "$content" \
  | ollama run qwen3.5:9b-ctx
```
