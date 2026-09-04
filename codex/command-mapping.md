# Command mapping for Codex

Codex does not use Claude Code's `~/.claude/commands` directory. The original
command documents remain under `commands/` for reference, while the equivalent
Codex interface is a natural-language prompt plus an automatically selected
skill.

| Legacy command family | Codex replacement |
|---|---|
| `/plan`, `/init-project` | Ask Codex to plan or initialize the project; use the `planner` or `project-guidelines-example` skill. |
| `/tdd`, `/test-coverage`, `/e2e` | Ask Codex to implement or audit tests; use `tdd-workflow` or `webapp-testing`. |
| `/code-review`, `/verify`, `/build-fix` | Ask Codex to review, verify, or fix the build; use `verification-loop` and the relevant language skill. |
| `/secret-scan`, `/dependency-audit` | Ask Codex for a secret or dependency audit; use `secret-scan` or `dependency-audit`. |
| `/atomic-push`, `/commit`, `/commit-push-pr` | Ask Codex to commit/push; use `atomic-github-push` and review the diff first. |
| `/pdf-read`, `/doc-extract`, `/doc-summarize` | Ask Codex to extract or summarize a document; use `document-intelligence`. |
| `/gpu-check`, `/experiment-init` | Ask Codex to inspect GPU readiness or initialize an experiment; use `local-ml-gpu` or `ds-workflow`. |
| `/audit-end-sprint` | Ask Codex to run an end-of-sprint audit; use `audit-workflow`. |
| `/learn`, `/natural-write` | Ask Codex to extract a reusable workflow or polish prose; use `continuous-learning` or `natural-writing`. |

For a command without a dedicated skill, tell Codex the desired outcome and
point it at the corresponding file under `commands/`.
