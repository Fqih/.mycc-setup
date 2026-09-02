# Git Workflow

## Commit Message Format

```
<type>: <description>

<optional body>
```

Types: feat, fix, refactor, docs, test, chore, perf, ci

Note: Attribution disabled globally via ~/.claude/settings.json.

## Commit Style (Professional, Not AI-Looking)

Subject line:
- Imperative mood: "add" not "added" / "adds"
- Lowercase body after type prefix
- Max 72 chars total
- No trailing period
- No emoji, no marketing words ("leverage", "robust", "seamless", "powerful")
- No symbols like arrows or prices in subject

Body:
- Wrap at 72 chars per line
- Bullet points: parallel structure, short, technical
- Explain WHY not WHAT (the diff already shows WHAT)
- Reference issue or ticket number if applicable

Forbidden:
- `Co-Authored-By:` trailers (per identity rules)
- `🤖 Generated with ...` footers
- Self-congratulatory phrasing
- Mixed languages without reason
- Excessive nesting of lists

Good:
```
fix(auth): handle token refresh on 401

retry once before failing the request to avoid
flaky behavior on transient auth errors
```

Bad:
```
🚀 I have implemented an awesome, robust, and seamless
authentication token refresh mechanism that handles 401
errors beautifully! Co-Authored-By: Claude ✨
```

## Pull Request Workflow

When creating PRs:
1. Analyze full commit history (not just latest commit)
2. Use `git diff [base-branch]...HEAD` to see all changes
3. Draft comprehensive PR summary
4. Include test plan with TODOs
5. Push with `-u` flag if new branch

## Feature Implementation Workflow

1. **Plan First**
   - Use **planner** agent to create implementation plan
   - Identify dependencies and risks
   - Break down into phases

2. **TDD Approach**
   - Use **tdd-guide** agent
   - Write tests first (RED)
   - Implement to pass tests (GREEN)
   - Refactor (IMPROVE)
   - Verify 80%+ coverage

3. **Code Review**
   - Use **code-reviewer** agent immediately after writing code
   - Address CRITICAL and HIGH issues
   - Fix MEDIUM issues when possible

4. **Commit & Push**
   - Follow professional commit style above
   - Conventional commit format
   - One logical change per commit
