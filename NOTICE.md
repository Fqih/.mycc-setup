# NOTICE — Attribution & Licenses

Repo ini menggabungkan konten dari beberapa sumber. Semua konten di bawah lisensi aslinya masing-masing.

## Custom content (MIT, Copyright Fqih)

Konten original di repo ini oleh Fqih, dilisensikan di bawah MIT (lihat LICENSE):

- `skills/atomic-github-push/SKILL.md`
- `skills/secret-scan/SKILL.md`
- `skills/telegram-notify/SKILL.md`
- `skills/remote-workflow/SKILL.md`
- `skills/local-ml-gpu/SKILL.md`
- `skills/fullstack-web/SKILL.md`
- `skills/notebook-hygiene/SKILL.md`
- `skills/ds-workflow/SKILL.md`
- `skills/llm-engineering/SKILL.md`

## Forked content (MIT)

Konten di bawah ini di-fork dari [WorldFlowAI/everything-claude-code](https://github.com/WorldFlowAI/everything-claude-code) (Copyright affaan-m et al., MIT License).

Source: https://github.com/WorldFlowAI/everything-claude-code

`rules/`:
- agents.md, coding-style.md, git-workflow.md, hooks.md, patterns.md, performance.md, security.md, testing.md

`skills/`:
- backend-patterns/, clickhouse-io/, coding-standards/, continuous-learning/, eval-harness/, frontend-patterns/, project-guidelines-example/, security-review/, strategic-compact/, tdd-workflow/, verification-loop/

`agents/`:
- architect.md, build-error-resolver.md, code-reviewer.md, doc-updater.md, e2e-runner.md, planner.md, refactor-cleaner.md, security-reviewer.md, tdd-guide.md

`commands/`:
- build-fix.md, checkpoint.md, code-review.md, e2e.md, eval.md, learn.md, orchestrate.md, plan.md, refactor-clean.md, setup-pm.md, tdd.md, test-coverage.md, update-codemaps.md, update-docs.md, verify.md

## Modifications

Konten forked mungkin telah dimodifikasi untuk integrasi dengan custom skill (`atomic-github-push`, `secret-scan`) dan preferensi pribadi. Perubahan terdokumentasi di git history via commit messages.

## Additional resources (not bundled, referenced)

- [datalayer/jupyter-mcp-server](https://github.com/datalayer/jupyter-mcp-server) — Jupyter MCP
- [gitleaks/gitleaks](https://github.com/gitleaks/gitleaks) — secret scanner
- [mlflow/mlflow](https://github.com/mlflow/mlflow) — experiment tracking
- [tailscale/tailscale](https://github.com/tailscale/tailscale) — mesh VPN

## Verification

Semua file di-scan dengan `gitleaks` sebelum push. Custom `.gitleaks.toml` di root repo.
