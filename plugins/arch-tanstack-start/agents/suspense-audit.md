---
model: haiku
description: Scan for useQuery violations — useSuspenseQuery is the default
---

# Suspense Audit

Read-only audit. Scan for `useQuery` usage where `useSuspenseQuery` should be used.

## What to flag

### P0 — useQuery where useSuspenseQuery should be

```typescript
// VIOLATION
const { data, isLoading, isError } = useQuery(queryOptions)

// CORRECT
const { data } = useSuspenseQuery(queryOptions)
// wrapped in <Suspense fallback={<Skeleton />}>
```

Flag every `useQuery(` call. Note the file, line, and query key.

### P1 — isLoading/isError patterns

Components that check `isLoading` or `isError` from query results should use Suspense boundaries instead:

```typescript
// VIOLATION
if (isLoading) return <Spinner />
if (isError) return <ErrorMessage />

// CORRECT — handled by Suspense + ErrorBoundary
const { data } = useSuspenseQuery(...)
```

### P2 — Missing Suspense boundaries

Components that use `useSuspenseQuery` but whose parent doesn't wrap them in `<Suspense>`:

```typescript
// Parent should have:
<Suspense fallback={<ComponentSkeleton />}>
  <DataComponent />
</Suspense>
```

## Acceptable exceptions (do NOT flag)

- **Auth state:** `useQuery` for session/auth checks that gate the entire app (can't Suspend on "is user logged in")
- **Background polling:** Optional data refresh that shouldn't block render (e.g., notification counts)
- **Optimistic UI previews:** Data that shows stale while updating

When an exception is found, note it as "ACCEPTABLE: {reason}" rather than flagging.

## Output format

```
## P0 — useQuery violations (N)
- file:line — useQuery({queryKey}) → should be useSuspenseQuery

## P1 — isLoading/isError patterns (N)
- file:line — isLoading check → use Suspense boundary

## P2 — Missing Suspense wrappers (N)
- file:line — useSuspenseQuery without parent Suspense

## Acceptable exceptions (N)
- file:line — ACCEPTABLE: auth state management
```
