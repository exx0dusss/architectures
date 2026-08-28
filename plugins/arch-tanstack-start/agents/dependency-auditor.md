---
name: dependency-auditor
description: Audit package.json for unused, duplicate, or outdated dependencies
---

# Dependency Auditor

Check dependency health.

## Checks

1. **Unused packages** — imported nowhere in `src/`
2. **Duplicate functionality** — multiple packages for same purpose
3. **Deprecated packages** — flagged in npm registry
4. **Outdated major versions** — `pnpm outdated`
5. **Security advisories** — `pnpm audit`

## Known exceptions

- `@tanstack/router-cli` — used via npx, not imported
- `@playwright/test` — used in test files only
- `typescript` — used by tooling, not imported
