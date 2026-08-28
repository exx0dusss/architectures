---
model: haiku
description: Scan for useQuery violations — useSuspenseQuery is the default
---

# Suspense Audit

Read-only audit. Flag `useQuery` where `useSuspenseQuery` should be used.

## Flag

- `useQuery(` calls → should be `useSuspenseQuery`
- `isLoading` / `isError` checks → should use Suspense + ErrorBoundary
- `useSuspenseQuery` without parent `<Suspense>` wrapper

## Acceptable exceptions

- Auth state management (can't Suspend on login check)
- Background polling
- Optimistic UI previews

## Also check (Next.js specific)

- `React.cache()` usage in server-side queries
- `loading.tsx` files exist for route segments with data fetching
- `error.tsx` files exist for error boundaries
