---
name: arch-state
description: Use when deciding where a piece of state belongs, or when adding or changing a Zustand store, a URL search-param parser, pagination/filter/sort/tab state, or persisted client state. Also use when the same fact appears to live in two places, when state resets on refresh that should survive it, when a filter change does not refetch, or when a store field mirrors something the API already returns.
stacks: [nextjs, tanstack-start]
---

# State layering

**Applies only to repos built on the `exx0dusss/architectures` blueprint.** If this repo has no
`docs/architecture/` directory and no `AGENTS.md` naming one of these stacks, this skill does not
apply — stop and ignore it.

Three layers, no overlap. **If two layers could hold the same fact, one of them is wrong.**

| Layer | Tool | Owns |
| --- | --- | --- |
| Server state | TanStack Query | Everything the API returns |
| URL state | nuqs (Next.js) / `validateSearch` (TanStack Start) | Pagination, filters, sort, search, tab, layout |
| Client global | Zustand | Cross-component UI state and intents |

State used by exactly one component stays in `useState`. Do not promote it.

## Read the reference for this repo's stack

| `package.json` has | Read |
| --- | --- |
| `next` | `../../reference/nextjs/state.md` |
| `@tanstack/react-start` | `../../reference/tanstack-start/state.md` |

If the repo has its own `docs/architecture/state.md` or `docs/conventions/state.md`, read that
instead — a consumer's local instantiation outranks the blueprint.

## The test for where state goes

Ask in this order and stop at the first yes:

1. Does the API own this fact? → TanStack Query. Never copy it into a store.
2. Would a user reasonably bookmark, share, or reach it with the back button? → URL.
3. Do two unrelated components need it? → Zustand.
4. Otherwise → `useState`, in the one component that uses it.

## Red flags — stop and re-read the reference

- An API response cached in a Zustand store → delete the field and read the query
- A store field that mirrors something the API returns → same; one fact, one owner
- Page, page size, search text, filter selection, sort, or active tab held in `useState` or a store → belongs in the URL
- A search-param parser redeclared at a call site → import the resource's parser set; a drifted default silently splits the query key
- A persisted store whose shape changed without its rehydrate validation changing → persisted shapes outlive code; bump both in the same commit
- `File` objects (or anything non-JSON-serializable) in a persisted store → persist metadata only
- User-specific or sensitive data marked for cache persistence → never persist it
- **(TanStack Start)** search params read inside a loader → they are not available there; extract them with `loaderDeps`
- **(TanStack Start)** `validateSearch` without a Zod v4 schema → pass the schema directly, no adapter
