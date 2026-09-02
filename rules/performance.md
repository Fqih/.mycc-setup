# Performance Optimization

## Model Selection Strategy

**Haiku 4.5** (90% of Sonnet capability, 3x cost savings):
- Lightweight agents with frequent invocation
- Pair programming and code generation
- Worker agents in multi-agent systems

**Sonnet 4.5** (Best coding model):
- Main development work
- Orchestrating multi-agent workflows
- Complex coding tasks

**Opus 4.5** (Deepest reasoning):
- Complex architectural decisions
- Maximum reasoning requirements
- Research and analysis tasks

## Context Window Management

Avoid last 20% of context window for:
- Large-scale refactoring
- Feature implementation spanning multiple files
- Debugging complex interactions

Lower context sensitivity tasks:
- Single-file edits
- Independent utility creation
- Documentation updates
- Simple bug fixes

## Ultrathink + Plan Mode

For complex tasks requiring deep reasoning:
1. Use `ultrathink` for enhanced thinking
2. Enable **Plan Mode** for structured approach
3. "Rev the engine" with multiple critique rounds
4. Use split role sub-agents for diverse analysis

## Build Troubleshooting

If build fails:
1. Use **build-error-resolver** agent
2. Analyze error messages
3. Fix incrementally
4. Verify after each fix

## Overnight / Long-Running Agent Loop

For long sessions (e.g. background work overnight):

- Batch work into 1-2 features per batch, not one giant task
- Commit and push per batch; pre-push hook triggers Telegram notify
- Compaction auto-runs at context limit; tune via `compaction.tail_turns` and `preserve_recent_tokens`
- Each agent has a `steps` limit to prevent runaway loops
- opencode snapshot is on by default; sessions resume after crash
- Qwen (paid) is invoked only via the `coder` agent for complex code; routine work stays on `coder-minimax` (free)
- Avoid one-commit-per-file churn; push in coherent batches

A typical overnight timeline:

```
19:00  start session; write todowrite list
19:15  batch 1 runs
19:45  /commit && git push (telegram fires)
20:00  batch 2 runs
...
08:00  morning: review last telegram notif
```

If the agent stalls or loops, stop the session and inspect `~/.local/share/opencode/`.
