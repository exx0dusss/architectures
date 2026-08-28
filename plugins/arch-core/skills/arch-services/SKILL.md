---
name: arch-services
description: Use when adding or changing anything in the service/data layer — a new backend resource, a Zod schema, a server action or server function, a query hook, query keys, prefetch or hydration, cache invalidation, or pagination. Also use when a response fails to parse, a query refetches instead of using data the server already loaded, a mutation leaves stale data on screen, or a resource folder is missing files.
stacks: [nextjs, tanstack-start, nestjs-backend]
---

# Service and data layer

**Applies only to repos built on the `exx0dusss/architectures` blueprint.** If this repo has no
`docs/architecture/` directory and no `AGENTS.md` naming one of these stacks, this skill does not
apply — stop and ignore it.

Every backend resource gets a fixed file set. Zod is the single source of truth; TypeScript types
are derived from schemas, never written alongside them.

## Read the reference for this repo's stack

Detect the stack from `package.json`, then read the matching files under `reference/` in this
skill's plugin (`../../reference/<stack>/`). Do not work from memory of a similar resource — the
file contract differs per stack.

| `package.json` has | Stack | Read |
| --- | --- | --- |
| `next` | `nextjs` | `nextjs/services.md`, `nextjs/data-fetching.md` |
| `@tanstack/react-start` | `tanstack-start` | `tanstack-start/services.md`, `tanstack-start/data-fetching.md` |
| `@nestjs/core` | `nestjs-backend` | `nestjs-backend/services.md`, `nestjs-backend/data-layer.md` |

For a copy-ready starting point, read `<stack>/building-blocks/service-template.md`. For the
`Result` type and `safeAction`, read `<stack>/building-blocks/errors-and-result.md`.

If the repo has its own `docs/architecture/` or `docs/conventions/` copies of these docs, read
those instead — a consumer's local instantiation outranks the blueprint.

## File contract — index only, the reference is authoritative

**Next.js — 7 files per resource, `services/{service}/{resource}/`**

`schema.ts` · `api-schema.ts` · `queries.ts` (`"server-only"`) · `query-options.ts` ·
`actions.ts` (`"use server"`) · `use-{resource}.ts` (`"use client"`) · `search-params.ts`

**TanStack Start — 6 files per resource, `{r}.x.ts` naming**

`{r}.schema.ts` · `{r}.api-schema.ts` · `{r}.functions.ts` · `{r}.query-options.ts` ·
`{r}.hooks.ts` · `{r}.search-params.ts`

**NestJS — module per domain**, repository pattern over Drizzle; no raw queries in services.

Enums go at the **top** of the schema file, before create/update/DTO schemas, in all three.

## Red flags — stop and re-read the reference

- Hand-written `interface` or `type` mirroring a Zod schema → use `z.infer` (`z.input` only for form/request input)
- A type named `XSchema` → drop the suffix; the schema constant carries it, the type does not
- `any`, `as any`, or `as unknown as` anywhere outside a test mock → fix the type at its source
- A one-off query key built inline in a page or route → import the key factory from the resource's query-options file
- Raw millisecond literal for `staleTime`/`gcTime` → use the named time constants
- An entry point that skips input validation → every server action / server function / query fn validates with Zod
- **(Next.js)** `revalidateTag`, `revalidatePath`, `unstable_cache`, `next: { revalidate }`, `next: { tags }`, `cache: "force-cache"`, or overriding `serverFetch`'s `cache: "no-store"` → TanStack Query is the sole caching layer
- **(Next.js)** a server action that throws → wrap in `safeAction()` and return `ApiResult<T>`
- **(Next.js)** `cache()` imported from `"next/cache"` → import from `"react"`; it is for request dedup only
- **(TanStack Start)** a backend called directly from client code → route it through `createServerFn`
- **(TanStack Start)** a server function called from a component for initial data → use `ensureQueryData` in the route `loader`
- **(TanStack Start)** manual `.parse()` inside a server function → pass the schema to `.inputValidator()`
- **(TanStack Start)** `createServerFn` wrapped in a custom factory → Start must see the real boundary; use middleware
- **(TanStack Start)** `*.server.ts` statically imported from route or component code → keep it behind `createServerFn`
- **(NestJS)** a module importing another module's service or repository → emit a `{module}.{action}` domain event
- **(NestJS)** raw Drizzle query inside a service → go through the repository
- **(NestJS)** money as a float → integers (kopecks); IDs are UUID v7; timestamps are `timestamptz` UTC

## Invalidation

Invalidate at the **broadest key that is still correct** — the resource's `all` key — because
scope and filters are part of the key and a narrower invalidation leaves stale lists on screen.
