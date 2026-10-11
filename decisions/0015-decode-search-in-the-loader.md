---
id: 0015
title: Decode a route's search inside its loader instead of keying loaderDeps on it
date: 2026-10-11
status: Accepted
supersedes: []
superseded_by: []
tags: [tanstack-start, data-loading, routing]
---

# ADR-0015 — Decode a route's search inside its loader instead of keying loaderDeps on it

## Context

`tanstack-start/rules.md` rule 18 told every route whose loader depends on search params to
extract them with `loaderDeps`, and claimed search params are not available in a loader. The
`page-scaffold` agent and the `arch-state` red-flag list repeated it, so every scaffolded list
page shipped with search-keyed deps.

The claim is false and the rule is harmful on list pages. A loader receives `location`, whose
`search` holds the parsed URL. A router match id is the route id, its interpolated path and its
`loaderDeps` hash, so deps built from the search mint a new match on every sort, filter or page
change. A new match starts pending; once the navigation outlives `defaultPendingMs`, the router
presents the route's `pendingComponent` in place of the whole leaf. The toolbar disappears, and the
deferred params and section-level `Suspense` that were meant to keep the previous rows on screen
sit inside the hidden match and never run. In production this showed as a full-page loader
flashing on an ordinary column sort, on pages whose downstream loading code was correct.

## Decision

- A route never keys `loaderDeps` on its search. Without deps the match id is stable, the mounted
  match stays successful, and the loader re-runs as a background revalidation.
- The loader decodes the search itself: `location.search` is raw, so it is parsed through the
  route's own `validateSearch` schema, and the component reads the search through the same
  schema, so loader and component resolve to one query key.
- `loaderDeps` stays available for keys that are not the search, where one blocking load per
  navigation is the intended behaviour.

Carried by `tanstack-start/rules.md` rule 18, the `page-scaffold` agent's route template, and the
`arch-state` red-flag list.

## Consequences

- Filter, sort and pagination changes keep the page mounted; the section boundary and deferred
  params own the refetch, as `building-blocks/data-loading.md` already describes.
- Each list loader parses the search once more than before. The parse is the schema the route
  already declares, so it costs a function call, not a second definition.
- Consumer routes scaffolded from the old template carry search-keyed deps and need migrating.
  A consumer that wants the rule enforced writes a guard that walks the AST for a `loaderDeps`
  function reading `search`; a text search also matches comments that mention the rule.

## Compliance

Manual — no guard exists upstream. `arch-review` and `suspense-audit` reviews read rule 18;
nothing here fails on a search-keyed `loaderDeps` in consumer code.

## Alternatives rejected

| Alternative | Why rejected |
|-------------|--------------|
| Keep search-keyed deps and raise `defaultPendingMs` | Delays the swap without removing it; a slow request still replaces the whole page. |
| Keep search-keyed deps and drop the route's `pendingComponent` | The route still needs a fallback for the code-split chunk window on first navigation. |
| Read `location.search` in the loader without the schema | The raw search can differ from the validated one (defaults, coercion), splitting the query key between loader and component. |
