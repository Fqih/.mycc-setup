---
name: agent-design
description: Use when designing AI agents — tool use patterns, ReAct/plan-and-execute loops, memory, multi-agent orchestration, error recovery, observability. Reference LangGraph, CrewAI, Anthropic tool use. Trigger on "agent", "tool use", "react", "autonomous", "multi-agent", "/agent-design".
---

# agent-design

Pattern untuk AI agent yang bisa pakai tools, plan, dan recover dari error.

## Agent arsitektur

```
[User input]
    ↓
[Reasoning / Planning]
    ↓ decide action
[Tool selection]
    ↓
[Tool execution]
    ↓ result
[Observation + state update]
    ↓
[Loop until done or max_iter]
    ↓
[Final response]
```

## Pola dasar

### 1. ReAct (Reason + Act) — paling umum

```
Thought: Saya perlu cek cuaca di Jakarta
Action: get_weather
Action Input: {"city": "Jakarta"}
Observation: 28°C, cerah
Thought: Sekarang saya bisa jawab
Final Answer: Cuaca di Jakarta hari ini 28°C, cerah
```

```python
# Anthropic pattern
import anthropic

client = anthropic.Anthropic()

def agent_loop(query: str, tools: list, max_iter: int = 10):
    messages = [{"role": "user", "content": query}]

    for i in range(max_iter):
        response = client.messages.create(
            model="claude-sonnet-5",
            tools=tools,
            messages=messages,
            max_tokens=2048,
        )

        if response.stop_reason == "end_turn":
            return next(b.text for b in response.content if b.type == "text")

        # process tool use
        tool_results = []
        for block in response.content:
            if block.type == "tool_use":
                result = execute_tool(block.name, block.input)
                tool_results.append({
                    "type": "tool_result",
                    "tool_use_id": block.id,
                    "content": str(result),
                })

        messages.append({"role": "assistant", "content": response.content})
        messages.append({"role": "user", "content": tool_results})

    return "Agent hit max iterations"
```

### 2. Plan-and-Execute

```
1. Plan dulu: list langkah-langkah
2. Execute langkah 1, observe
3. Re-plan kalau perlu (jika observation unexpected)
4. Continue sampai semua langkah done
```

Bagus untuk task yang clear goal-nya tapi path-nya tidak pasti. Lebih token-efficient dari ReAct murni.

```python
# Pattern: langgraph atau manual
def plan_and_execute(query: str):
    plan = planner_llm(query)  # → ["step 1", "step 2", ...]
    results = []

    for step in plan:
        result = executor(step, context=results)
        results.append(result)

        if should_replan(plan, results):
            plan = replanner(query, plan, results)

    return synthesize(plan, results)
```

### 3. Multi-agent (supervisor + workers)

```
[Supervisor] → delegate task
    ↓
[Worker A] → result A
[Worker B] → result B
[Worker C] → result C
    ↓
[Supervisor] → synthesize → final
```

Pattern:
- **Supervisor pattern**: 1 supervisor decide worker mana yang handle task apa
- **Hierarchical**: supervisor → sub-supervisor → workers
- **Debate**: 2+ agents disagree, supervisor adjudicate

```python
# CrewAI pattern
from crewai import Agent, Task, Crew

researcher = Agent(role="Researcher", goal="Find facts", tools=[web_search_tool])
writer = Agent(role="Writer", goal="Write article", tools=[])

task1 = Task(description="Research topic X", agent=researcher, expected_output="facts")
task2 = Task(description="Write article based on research", agent=writer, expected_output="article")

crew = Crew(agents=[researcher, writer], tasks=[task1, task2])
crew.kickoff()
```

## Tool design

```python
# Anthropic tool definition
tools = [{
    "name": "get_weather",
    "description": """Get current weather untuk kota tertentu.
    Use ini kalau user tanya cuaca, temperature, atau kondisi cuaca.
    Input kota dalam bahasa inggris atau sesuai API support.""",
    "input_schema": {
        "type": "object",
        "properties": {
            "city": {"type": "string", "description": "Nama kota"},
            "unit": {
                "type": "string",
                "enum": ["celsius", "fahrenheit"],
                "default": "celsius",
            },
        },
        "required": ["city"],
    },
}]
```

**Tool design rules:**
- ✅ Specific description (kalau buat apa, kapan pakai)
- ✅ Parameter schema detail (description per field)
- ✅ Enum untuk nilai terbatas
- ❌ Jangan terlalu banyak tools (>20 = LLM bingung)
- ❌ Jangan tool yang overlap (model tidak pilih)
- ❌ Jangan vague description ("do something useful")

## Memory patterns

### Short-term (in-conversation)
```python
messages = []  # grow each turn
```

### Long-term (vector store)
```python
# Save important info dari conversation
relevant = retrieve_relevant(query, vector_store_of_past_convos)
# Inject ke system prompt atau context
```

### Episodic (kalau perlu recall episode spesifik)
```python
# Save setiap completed task sebagai "episode"
episode = {"task": ..., "actions": [...], "outcome": ..., "timestamp": ...}
store.put(episode)
```

### Working memory (untuk planning)
```python
# Plan scratchpad — apa yang sudah dilakukan, apa next
scratchpad = """
- [x] Search user info
- [x] Get preferences
- [ ] Generate response
"""
```

## Error recovery

| Failure | Recovery |
|---|---|
| Tool returns error | Retry 1-2x, kalau masih fail → replan atau tell user |
| Invalid tool input | Validator sebelum execute, retry dengan error msg |
| Loop (same tool, same args) | Detect via state hash, force break ke user |
| Max iter reached | Return partial result + flag "incomplete" |
| Tool timeout | Async with timeout, kill + report |
| Hallucinated tool name | Validate tool name vs whitelist, reject |

```python
def execute_with_retry(tool_name, tool_input, max_retries=2):
    for attempt in range(max_retries + 1):
        try:
            return TOOLS[tool_name].run(**tool_input)
        except ToolError as e:
            if attempt < max_retries:
                time.sleep(2 ** attempt)
            else:
                raise
```

## Loop detection

```python
state_hashes = []

def is_looping(state) -> bool:
    h = hash_state(state)
    state_hashes.append(h)
    if len(state_hashes) > 5:
        recent = state_hashes[-5:]
        if len(set(recent)) < 3:
            return True
    return False
```

## Observability

Log per iter:
- Timestamp
- Current state (messages length, scratchpad)
- Decision (next action atau final)
- Tool name + args
- Tool result (truncated)
- Latency per step
- Token usage cumulative

```python
import structlog

logger = structlog.get_logger()

logger.info("agent_iter",
    iter=i,
    action=tool_name,
    args=tool_input,
    result_preview=str(result)[:200],
    tokens=response.usage,
)
```

Log ke MLflow (lihat `ds-workflow`) atau LangSmith / Helicone.

## Human-in-the-loop

```python
def critical_action(action, payload):
    if action in CRITICAL_ACTIONS:
        approved = ask_human(payload)
        if not approved:
            return "Action rejected by user"
    return execute_action(action, payload)
```

Critical actions: send email, deploy, delete data, payment.

## Cost & latency budget

| Agent type | Token cost | Latency |
|---|---|---|
| Single LLM call | 1x | 1-3s |
| ReAct (5 iter) | ~5-10x | 5-30s |
| Plan+execute (3 steps) | ~3-5x | 3-15s |
| Multi-agent (4 agents) | ~4-8x | 10-60s |
| Deep research (10+ sources) | 20-50x | 1-5min |

**Mitigation:**
- Cache tool results (Redis)
- Smaller model untuk simple steps, big model untuk planning
- Parallel tool execution kalau independent
- Streaming untuk UX (lihat skill `llm-engineering`)

## Framework pilihan

| Framework | When to use |
|---|---|
| **Anthropic SDK** raw + manual loop | Custom, full control |
| **LangGraph** | Stateful, complex flows, persistence |
| **CrewAI** | Multi-agent quick start |
| **AutoGen** | Microsoft stack, conversational |
| **LlamaIndex** | RAG-heavy agents |
| **OpenAI Assistants API** | OpenAI-only, hosted state |
| **smolagents / pydantic-ai** | Lightweight, Pythonic |

**Default**: Anthropic SDK manual loop untuk custom. LangGraph kalau perlu state machine. CrewAI untuk quick multi-agent prototype.

## Anti-patterns

❌ **Agent untuk task yang bisa one-shot prompt**: extra cost, latency, fragility
❌ **Agent tanpa observability**: tidak bisa debug
❌ **Agent yang loop tanpa detection**: hang forever
❌ **Tool tanpa error handling**: 1 tool fail = agent crash
❌ **Tidak ada fallback kalau max_iter**: user stuck
❌ **Multi-agent untuk simple task**: overkill, latencies stack
❌ **State di global variable**: race condition, hard to test
❌ **Agent kasih user kode langsung tanpa test**: bug di code tanpa verifikasi

## Invokation

Auto-trigger saat:
- Edit file yang import anthropic/openai + tool definitions
- User sebut "agent", "autonomous", "tool use", "react"
- Code pattern: while loop + tool execution + LLM decision