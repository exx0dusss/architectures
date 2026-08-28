---
name: arch-modules
description: Use when adding or changing a backend module — a new bounded context, a domain event, an event handler, a BullMQ job or consumer, a WebSocket gateway, or anything crossing the boundary between two modules. Also use when one module needs another module's data, when a handler is slow, when a job runs in the wrong process, or when deciding whether new code belongs in domain, application, infrastructure, or presentation.
stacks: [nestjs-backend]
---

# Backend modules, events, and workers

**Applies only to repos built on the `exx0dusss/architectures` blueprint.** If this repo has no
`@nestjs/core` in `package.json`, this skill does not apply — stop and ignore it.

The backend is a **modular monolith**: one deployable, hard internal boundaries. The boundaries
are the whole design. Everything below exists to keep a monolith from quietly becoming a big ball
of mud with folders.

## Read the reference

Read from `reference/nestjs-backend/` in this skill's plugin (`../../reference/nestjs-backend/`):

| Task | Read |
| --- | --- |
| Where a file goes; layer direction | `structure.md` |
| The non-negotiables | `rules.md` |
| Emitting and handling events, queues, idempotency, exception filter | `patterns.md` |
| WebSocket gateways, Redis pub/sub, role channels | `real-time.md` |
| Which process runs what | `deployment.md` |

If the repo has its own `docs/conventions/` copies, read those instead — a consumer's local
instantiation outranks the blueprint.

For the data layer itself — repositories, schemas, transactions — use `arch-services`. For guards
and permissions, use `arch-auth`. This skill owns the **boundaries between modules**, not what
happens inside one.

## The three rules everything else follows from

1. **Modules never import each other.** A module imports its own files, the shared module, and
   external packages. Nothing else. When module A needs something from module B, A emits or
   handles a domain event named `{module}.{action}`.
2. **Imports flow inward.** presentation → application → domain. The domain layer is
   dependency-free: no NestJS, no Drizzle, no infrastructure. If a domain entity imports a
   repository, the design is inverted — the interface belongs in `domain/interfaces/`, the
   implementation in `infrastructure/`.
3. **Event handlers are fast and in-process. Slow work is a job.** A handler that calls a third
   party synchronously has coupled request latency to someone else's uptime. Dispatch BullMQ.

## Choosing where code goes

| The code… | Layer |
| --- | --- |
| encodes a business rule that would survive a rewrite of the framework | `domain/` |
| orchestrates a use case, coordinates repositories, reacts to an event | `application/` |
| talks to Postgres, a queue, or a third party | `infrastructure/` |
| turns HTTP or WebSocket into a use-case call | `presentation/` |

**Flatten the layers for a small module.** Four directories per module is a maximum, not a quota;
the constraint that must hold is the direction of imports, not the depth of the tree.

## Two processes, one codebase

The API process serves HTTP and WebSocket; the worker process consumes BullMQ. A module ships a
consumer **only** if it is registered in the worker module — and a module registered there with
no consumer is dead weight. Read `deployment.md` before adding either.

## Red flags — stop and re-read the reference

- An `import` from another module's `application/`, `infrastructure/`, or `domain/` → emit a
  domain event instead
- The same import wearing a relative path (`../../order/...`) → same violation
- An event name that is not `{module}.{action}`
- `await fetch(...)`, an SDK call, or an email send inside an `@OnEvent` handler → dispatch a job
- A NestJS decorator, a Drizzle import, or an infrastructure import inside `domain/`
- A repository implementation under `application/`
- A controller importing a repository directly → go through an application service
- A queue consumer registered in the API process rather than the worker
- A shared "utils" or "common" module accumulating another module's business logic — that is a
  cross-module import with extra steps
- A new module created for a table rather than a bounded context → the module is the domain, not
  the schema

## When the boundary genuinely hurts

Sometimes an event is the wrong answer: a synchronous read of another module's data, needed
inside one request. Prefer, in order — a read model the owning module publishes, a shared
read-only query exposed by the owning module's application layer, or moving the two modules'
overlapping concept into one module because the boundary was drawn in the wrong place.

Reaching directly into another module's repository is never on that list.
