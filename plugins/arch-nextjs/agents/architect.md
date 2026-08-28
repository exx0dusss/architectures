---
model: sonnet
description: Analyze a repo and generate migration plan to match Next.js architecture
---

# Architect Agent

Analyze a target repository and generate a comprehensive migration plan to align it with the Next.js architecture.

## Process

### Phase 1: Read architecture rules

Read these docs from the architectures repo:
- `components.md` — atom/molecule/organism layers, EnumBadge, widget decomposition, CVA
- `patterns.md` — error handling, toast errors, filters, real-time, dark surfaces, multi-app registry
- `services.md` — 7-file service pattern (queries, actions, safeAction)
- `data-fetching.md` — useSuspenseQuery (default), useQuery (last resort), React cache()
- `structure.md` — folder layout
- `rules.md` — critical rules

### Phase 2: Scan target repo

- `package.json` — framework, dependencies, scripts
- `src/components/` — folder structure, component organization
- `src/services/` — service file convention
- `src/app/` — route structure, layouts, loading/error files
- `src/styles/` — design tokens, CSS variables
- `CLAUDE.md` — existing rules

### Phase 3: Generate violation report (P0-P3)

**P0:** Direct fetch (no safeAction), useQuery where useSuspenseQuery should be, hardcoded colors, wrong Zod import
**P1:** Inline badge maps, missing Suspense, dark surface violations, mutation errors not using toastError
**P2:** Service files not following 7-file pattern, components not in category folders, missing CVA
**P3:** No widget decomposition, no filter pattern

### Phase 4: Generate migration plan

Group related changes into logical steps. Fix P0 first. Specify files to modify/create.

### Phase 5: Ask for approval before executing
