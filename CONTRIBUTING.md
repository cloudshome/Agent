# Contributing

- Keep `deny_by_default: true` and allowlists. PRs that open `exec: ["*"]` will be rejected.
- Steps remain sequential — don't merge steps.
- Test `scripts/step1-system-check.sh` on both 22.04 and 24.04.
