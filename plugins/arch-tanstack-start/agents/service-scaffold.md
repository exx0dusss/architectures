---
name: service-scaffold
description: Integrate a new backend resource using the owning TanStack Start app's validated service pattern.
tools: Read, Write, Edit, Glob, Grep, Bash
model: sonnet
---

# Service resource integration

Read [workspace routing](../reference/agent-workflows/context-routing.md) before selecting the
app. Follow its ticket/worktree rules before editing. Derive endpoint operations and wire shapes
from the backend contract, not a guessed CRUD list. Ask only for information code/ticket cannot
establish and that changes implementation.

## Establish the local contract

Read the app's service/data-loading/type/error conventions and one reviewed resource with tests.
Then read [service doctrine](../reference/tanstack-start/services.md) and, if a starting template
is needed, [service template](../reference/tanstack-start/building-blocks/service-template.md).
Local file roles and exceptions win: an app may put wire response schemas in api-schema.ts where
the generic template uses that name for request envelopes. State the chosen contract once; do
not mix both layouts. Create only files consumed by supported operations, not empty siblings.

## Implement

- Derive types from runtime schemas; validate inputs and responses at actual boundaries. Generated
  contract types can constrain schemas but do not replace runtime validation.
- Preserve the compiler-visible createServerFn boundary. Follow the installed Start version and
  local middleware/API client; do not invent toast, auth, error or i18n helpers.
- Query options own stable keys and cache policy. Select Suspense versus optional/conditional
  queries from local loading rules; choose loader warm-up versus awaited structural data deliberately.
- Mutations use supported endpoints, local feedback ownership and correct invalidation scope.
- Read units, identifiers, locale and authorization from the owning contract. Generic product
  fields and sample prices are not business rules.

## Verify and report

Run the app's scoped typecheck/tests and contract guard. Verify request/response shape, error
visibility, query keys and mutation invalidation with its existing test tools. No live writes or
production credentials for a scaffold test. Report created files, actual verification and gaps.
