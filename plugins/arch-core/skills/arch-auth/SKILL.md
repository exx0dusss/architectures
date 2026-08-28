---
name: arch-auth
description: Use when touching authentication, sessions, tokens, token refresh, cookies, roles, permissions, route guards, middleware, or any check that decides whether a user may see or do something. Also use when a user is logged out unexpectedly, a refresh races or loops, a protected route is reachable while signed out, an admin-only surface leaks, or a permission check needs adding to a new endpoint or page.
stacks: [nextjs, tanstack-start, nestjs-backend]
---

# Auth and RBAC

**Applies only to repos built on the `exx0dusss/architectures` blueprint.** If this repo has no
`docs/architecture/` directory and no `AGENTS.md` naming one of these stacks, this skill does not
apply — stop and ignore it.

Authorization is enforced at more than one layer, and **no layer substitutes for another**. Client
checks are presentation only — hiding a control the user cannot use. The server decides.

## Read the reference for this repo's stack

| `package.json` has | Read |
| --- | --- |
| `next` | `../../reference/nextjs/auth-rbac.md`, `../../reference/nextjs/building-blocks/auth.md`, `../../reference/nextjs/building-blocks/rbac.md` |
| `@tanstack/react-start` | `../../reference/tanstack-start/auth-rbac.md`, `../../reference/tanstack-start/building-blocks/auth.md`, `../../reference/tanstack-start/building-blocks/rbac.md` |
| `@nestjs/core` | `../../reference/nestjs-backend/auth-rbac.md` |

Read the reference **before** changing refresh or guard logic. Both stacks document a concurrency
hazard in refresh that is not obvious from the code.

If the repo has its own `docs/architecture/auth-rbac.md` or `docs/conventions/auth-rbac.md`, read
that instead — a consumer's local instantiation outranks the blueprint.

## Red flags — stop and re-read the reference

- A token in `localStorage` or `sessionStorage` → cookies only, `httpOnly`, `secure`, `sameSite: lax`
- A backend URL or token in a client-exposed env var → server-only, always
- A client-side role check used as the only gate on an operation → gate it server-side too
- A new protected page or endpoint with no server-side access requirement declared → add it
- Token decoding scattered outside the one designated accessor → use the single session accessor
- **(Next.js)** token refresh without the shared lock → use `refreshWithLock()`; concurrent refreshes race and log users out
- **(TanStack Start)** `session.update()` called inside the shared refresh promise → sessions are per-request, so only the first caller would get the new tokens and siblings would retry with an already-rotated refresh token. Dedupe on a `Map<refreshToken, Promise>` and apply the result to each caller's own session after it resolves
- **(TanStack Start)** a protected layout trusting cached user state → revalidate in `beforeLoad` with `staleTime: 0`
- **(TanStack Start)** queries or mutations retrying on `401` → stop retrying so logout/refresh is immediate
- **(TanStack Start)** a barrel file inside `lib/auth/` → import from the owning file; barrels risk pulling server-only modules into the client graph
- **(NestJS)** a non-public route without a CASL `@RequirePermission({ action, subject })` guard → role checks alone are not enough
- **(NestJS)** a payment webhook processed before its signature is verified → verify first
