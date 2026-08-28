---
name: module-scaffold
description: Scaffold a new NestJS DDD module with all four layers. Use when adding a domain to a NestJS backend built on the blueprint — a new bounded context such as coupon, loyalty, or analytics.
tools: Read, Grep, Glob, Write, Edit, Bash
model: sonnet
---

# Module scaffold

Generate a new domain module following the four-layer DDD structure.

Read `nestjs-backend/structure.md` and `nestjs-backend/rules.md` from the bundled reference
before writing anything — the layer layout and the naming rules below are an index, not the
authority. If the consumer repo has its own `docs/conventions/` copies, those outrank the
blueprint.

## Input

The module name, singular and lowercase — the bounded context, not a table (`order`, not
`order_items`).

## Layout

```
src/modules/{module}/
├── domain/                    # Pure business logic — no NestJS imports
│   ├── entities/
│   ├── value-objects/
│   ├── events/                # Domain event classes
│   └── interfaces/            # Repository contracts
├── application/
│   ├── commands/              # Write operations
│   ├── queries/               # Read operations
│   ├── services/
│   └── handlers/              # @OnEvent handlers for other modules' events
├── infrastructure/
│   ├── repositories/          # Drizzle implementations
│   ├── adapters/              # Third-party clients
│   └── consumers/             # BullMQ job consumers
├── presentation/
│   ├── controllers/
│   ├── dtos/                  # Zod schemas
│   ├── guards/
│   └── decorators/
└── {module}.module.ts
```

**Flatten the layers for a small module.** The four directories are not a quota — the constraint
that matters is that imports flow inward (presentation → application → domain) and never outward.
A module with one entity and two endpoints should be flat. See the flat example in
`structure.md`.

## Rules the scaffold must satisfy

- **No cross-module imports.** A module imports only its own files, the shared module, and
  external packages. Everything else is a domain event, `{module}.{action}`, via `EventEmitter2`.
- **Event handlers stay fast.** No synchronous third-party calls — dispatch a BullMQ job.
- **Repository pattern.** No raw Drizzle in a service; repositories own transactions.
- **Domain layer is dependency-free.** No NestJS decorators, no Drizzle, no infrastructure
  imports in `domain/`.
- **Zod DTOs** — `import * as z from "zod"`, error messages as `{ error: "..." }`.
- **CASL on every non-public route.** A role check alone is not authorization. The reference
  design uses `@RequirePermission({ action, subject })` read by `PermissionGuard`, but grep an
  existing controller before writing one — the decorator's name is a house choice and repos
  rename it.
- **Schema helpers** — use the shared `pk()`, `timestamps`, and soft-delete helpers rather than
  redeclaring columns.
- **Register the module** in `app.module.ts`, and in `worker.module.ts` **only if** it ships a
  BullMQ consumer.

## Before you finish

State which layers you flattened and why, and list every domain event the module emits or
handles. A module that emits nothing and handles nothing is either genuinely standalone or is
about to become a cross-module import — say which.
