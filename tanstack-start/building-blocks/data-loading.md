---
status: stable
---

# Data loading & skeletons

React 19 + TanStack Start + TanStack Query v5. Loading state lives in Suspense boundaries with colocated skeleton components — never in `isLoading` ternaries inside the consumer.

## Three pieces

1. **Route loader** — preloads with `ensureQueryData` (blocking) or `prefetchQuery` (fire-and-forget, for below-the-fold data).
2. **Component** — calls `useSuspenseQuery` against the same query options. Suspends if cache is cold; renders synchronously if the loader populated it.
3. **Boundary** — `<Suspense fallback={<XSkeleton />}>` wraps the suspending component at the right granularity. Pair with `ErrorBoundary` when the section can fail independently (ErrorBoundary OUTSIDE Suspense, or it catches Suspense itself).

## Skeleton primitives

Two exports: `Skeleton` (a static bar) and `SkeletonGroup` (the surface that owns the motion — one light band sweeps the whole group while the bars inside stay still):

```tsx
<SkeletonGroup className="rounded-xl bg-card p-4 ring-1 ring-border">
  <Skeleton className="h-4 w-3/4" />
  <Skeleton className="h-3 w-1/2" />
</SkeletonGroup>
```

Rules:

- **Every `XSkeleton` root is a `SkeletonGroup`.** Groups must not nest — two bands = two light sources.
- A bar outside a group never moves; that is correct only for structurally-certain content (a compile-time prop). A bar standing in for fetched data belongs inside the group — a frozen header above a shimmering body reads as broken.
- Compile-time-known icons render for real in a skeleton; only data-dependent glyphs get bar-ised.
- `prefers-reduced-motion` drops the band automatically.
- **Never** inline `bg-muted animate-pulse` divs.

## Marks vs skeletons

A skeleton claims "content of this shape is coming". Where that claim would be a lie, use a **mark** instead. There are exactly three:

| Mark | Job |
|------|-----|
| `PageLoader` | **Auth boot only** — pre-chrome, unauthenticated; nothing is knowable, so a skeleton would be fabricated. |
| `Spinner variant="band"` | Indeterminate in-flight over a **region**: section refresh, table refetch, sync, unknown-size upload. |
| `Spinner variant="pulse"` | Indeterminate in-flight inside a **control**: button pending, inline status. |

**Never use a mark as a `Suspense` fallback for data.** A mark answers "an action is running", not "content is coming". Share keyframes between the band spinner and `SkeletonGroup` so a refreshing section and a loading section move the same way.

## Colocation rule

The skeleton lives **in the same file** as its consumer, as a sibling named export — `X` and `XSkeleton` (no `LoadingX`, no `XPlaceholder`, no `*.skeleton.tsx` files):

```tsx
export function ProductCard({ product }: { product: Product }) { /* … */ }

export function ProductCardSkeleton() {
  return (
    <SkeletonGroup className="rounded-xl border border-border bg-card">
      <Skeleton className="aspect-square w-full" />
      <div className="space-y-2 p-3">
        <Skeleton className="h-3 w-3/4" />
        <Skeleton className="h-3 w-1/2" />
      </div>
    </SkeletonGroup>
  );
}
```

The skeleton shares the consumer's wrapper element and spacing tokens — layout shift between fallback and content means the skeleton is wrong; fix the skeleton, not the layout. Tree-shaking removes unused exports, so colocation costs nothing. The only skeletons allowed in a shared `skeletons/` directory are **route-level composites** (full-page `pendingComponent` composing many section skeletons).

## Hook layer

Per the `x.z` service convention, each resource has a hooks file:

- **Default:** export `useX` as a `useSuspenseQuery` over the canonical query options — used by routes that preload in their loader.
- **Optional/deferred data** (user-driven search, secondary sections): export a distinctly-named plain `useQuery` hook with a one-line comment saying why it doesn't suspend.
- **Never** mix `useQuery(...).data ?? []` for critical route data — that renders an empty UI instead of a skeleton.

## Boundary granularity

Place Suspense as **deep as possible** so other content renders while a section loads:

- **Route-level** (`route.pendingComponent`) — only when the page is one indivisible unit.
- **Section-level** — default. One boundary per independently-loaded section.
- **Card-level** — grids that paginate or stream items in.

**A boundary above a blocking loader buys nothing.** If the loader `ensureQueryData`s the query inside a blocking `Promise.all`, the router holds the whole transition until it resolves and the boundary essentially never fires. Pick one deliberately: move the query to `prefetchQuery` (real streaming) or keep it blocking and comment that the boundary is a cold-cache/HMR safety net. What is NOT fine is a comment claiming sections "stream in independently" when the loader shape guarantees they cannot.

## Nullable query keys

`useSuspenseQuery` has no `enabled: false`. When a component's key is `T | null` (picker sheets, nothing-selected panels), split it: the shell renders a skeleton or `EmptyState` while the key is null, and mounts an inner body component — which can safely suspend — only with a non-null key. Decide explicitly what the null state shows, and say which you chose in a comment.

## Param-driven refetches — `useDeferredValue`

For UI that refetches on user input (search, filters, pagination):

```tsx
const deferredQuery = useDeferredValue(query);
const isPending = query !== deferredQuery;
const { data } = useSuspenseQuery(searchQueryOptions(deferredQuery));
// wrap content in cn(isPending && "opacity-60 transition-opacity")
```

The Suspense boundary shows the skeleton on *first* load; the opacity fade handles subsequent refetches without flicker. Pair with `placeholderData: keepPreviousData` on the query options.

## Anti-patterns

- `if (isLoading) return <Spinner />` — move loading into a Suspense fallback.
- `useQuery(...).data ?? []` for critical data — empty state instead of skeleton.
- `<Suspense fallback={<Spinner />}>` — a mark is not a skeleton; write the `XSkeleton`.
- Inline `animate-pulse` divs, `*.skeleton.tsx` files, generic shared skeletons.
- One `pendingComponent` covering a route whose sections could suspend independently.
- Nesting `SkeletonGroup`s — two light sources.

## Checklist for new features

1. Query options in `{r}.query-options.ts`.
2. `useX` (suspense) in `{r}.hooks.ts`.
3. `context.queryClient.ensureQueryData(...)` in the route `loader()`.
4. Component calls `useX(...)` — never `useQuery` for this data.
5. `XSkeleton` as a named export beside `X`, rooted in `SkeletonGroup`, same wrapper + spacing.
6. `<Suspense fallback={<XSkeleton />}>` at the section boundary.
7. Below the fold? `prefetchQuery` + its own boundary so it streams in.
