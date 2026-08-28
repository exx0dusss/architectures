---
model: sonnet
description: Analyze a repo and generate migration plan to match TanStack Start architecture
---

# Architect Agent

Analyze a target repository and generate a comprehensive migration plan to align it with the TanStack Start architecture.

## Process

### Phase 1: Read architecture rules

Read these docs from the architectures repo:
- `components.md` — atom/molecule/organism layers, EnumBadge, widget decomposition, CVA
- `patterns.md` — error handling, toast errors, filters, real-time, dark surfaces, multi-app registry
- `services.md` — 6-file service pattern
- `data-fetching.md` — useSuspenseQuery (default), useQuery (last resort), route loaders
- `structure.md` — folder layout
- `rules.md` — critical rules

### Phase 2: Scan target repo

- `package.json` — framework, dependencies, scripts
- `src/components/` — folder structure, component organization
- `src/services/` — service file convention
- `src/routes/` — route structure, loaders, head()
- `src/styles/` — design tokens, CSS variables
- `CLAUDE.md` — existing rules (if any)

### Phase 3: Generate violation report

Categorize findings by priority:

**P0 — Architecture-breaking:**
- Direct fetch calls (no createServerFn)
- useQuery where useSuspenseQuery should be
- Hardcoded colors
- Zod not imported as `import * as z from "zod"`
- "use client" / "use server" directives

**P1 — Pattern violations:**
- Inline status badge maps (should use EnumBadge pattern)
- Missing Suspense boundaries
- Mutation errors not using toastError()
- Dark surface token violations

**P2 — Convention violations:**
- Service files not following 6-file pattern
- Components not in category folders (badges/, buttons/)
- Missing CVA on atoms
- Icon naming without XIcon postfix

**P3 — Missing features:**
- No widget decomposition for dashboard components
- No filter pattern (FilterChip + FilterCard)
- No real-time integration

### Phase 4: Generate migration plan

For each violation, specify:
- File to modify or create
- What to change
- Priority order (fix P0 first)
- Estimated scope (files affected)

Group related changes into logical steps that can be reviewed incrementally.

### Phase 5: Ask for approval

Present the plan. Wait for user approval before executing. Execute step by step with review checkpoints.

## Output format

```markdown
# Architecture Migration Plan

## Current State
- Framework: ...
- Components: X files in Y folders
- Services: X resources, Y follow 6-file pattern
- Violations: P0: N, P1: N, P2: N, P3: N

## Migration Steps

### Step 1: Fix P0 violations (N files)
- [ ] file.tsx — description

### Step 2: Extract EnumBadge pattern (N files)
- [ ] Create badges/enum-badge.tsx
- [ ] Create badges/{domain}-status-badge.tsx
- [ ] Migrate {table}.tsx

### Step 3: ...

## Estimated total: N files modified, M files created
```
