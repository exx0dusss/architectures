---
status: stable
---

# Mutation feedback — the global error net

Every data mutation must report its outcome — exactly once. What differs is **who** reports it and **whether success is worth saying out loud**. Get this wrong in either direction and the operator either misses a failure or learns to ignore toasts.

## The global net

Install a `MutationCache.onError` on the QueryClient so every failed mutation toasts by default:

```ts
// query-client setup
import { MutationCache, QueryClient } from "@tanstack/react-query";

const queryClient = new QueryClient({
  mutationCache: new MutationCache({
    onError: (error, _vars, _ctx, mutation) => {
      const meta = mutation.meta as
        | { skipGlobalError?: boolean; errorLabel?: string }
        | undefined;
      if (meta?.skipGlobalError) return;
      if (mutation.options.onError) return; // local handler owns reporting
      toastError(meta?.errorLabel ?? t("mutation.errorDefault"), error);
    },
  }),
});
```

Two consequences that are easy to get backwards:

- **Omitting `onError` is the safe default.** The hook gets a failure toast for free.
- **Declaring a local `onError` opts the mutation OUT of the net.** A handler that only rolls back optimistic state is therefore *worse* than no handler at all — it removes the safety net and puts nothing in its place. This is the single most common failure mode; make CI reject it (see below).
- **A per-call `mutate(vars, { onError })` does NOT count as a local handler.** Per-call callbacks live on the observer; the cache callback only inspects `mutation.options` (verified in `@tanstack/query-core` — the cache `onError` is awaited before `options.onError`). A per-call `onError` that toasts produces **two** toasts unless the hook carries `meta: { skipGlobalError: true }`.

## Choosing the error path

| Situation | Do this |
|---|---|
| Nothing special to say | Nothing. The net toasts the generic label. |
| Surface hosts several mutations, or the action deserves naming | `meta: { errorLabel: t("x.error") }` — keeps the net, replaces the label |
| Optimistic mutation that must roll back | Local `onError` that rolls back **and** toasts |
| Caller already reports the failure (try/catch + toast, inline error line) | `meta: { skipGlobalError: true }` on the hook, with a comment naming the owner |
| Background mutation the operator never triggered (read-marking, presence pings) | `meta: { skipGlobalError: true }` — an error for an action nobody took is noise |

**Never leave a mutation reported twice.** One failure, one message.

## Choosing the success path

A success toast is for outcomes the operator **cannot see**. It is not a receipt.

| Result after success | Toast? |
|---|---|
| Overlay closes, row leaves the list, work queued server-side, navigation happens | **Yes** — `toast.success(...)` |
| Bulk action with partial failures | **Yes** — `toast.warning` with processed / skipped / failed counts |
| Toggle flips, selector shows the new value, field updates in place | **No** |
| Optimistic update already painted the new state | **No** |

Word the toast from the **server's response**, not from the requested action, whenever the two can diverge (e.g. an endpoint that resolves several intents to one status — read the response status, don't echo the request).

## Copy rules

- Toast strings come from the i18n catalog, never literals.
- Name the action, not the mechanism: "Couldn't apply the decision", not "Mutation error".
- A destructive action's toast/label names its object ("Cancel run", not a bare "Cancel" that collides with the overlay's dismiss button).

## CI guard

Back the convention with a check script (e.g. `scripts/check-mutation-feedback.ts`) that fails on:

1. A mutation hook whose `onError` only rolls back (no toast, no rethrow) — it silently suppressed the net.
2. A caller `catch`/per-call `onError` that toasts around a hook with no `meta: { skipGlobalError: true }` — double toast.

## Anti-patterns

- `onError` that only rolls back — suppresses the net, reports nothing.
- A success toast for a toggle or anything whose new state is on screen.
- A hardcoded toast string.
- Trusting `mutateAsync` inside `form.onSubmit` to report anything by itself.
