# Authentication & RBAC

TanStack Start auth is **server session-driven**. The Start session is the application source of truth. External backend JWTs and refresh tokens live inside server-only bridge modules and never reach the browser.

This replaces the older "read cookies directly everywhere and refresh on the client" pattern. It also replaces any implementation that mutates the session inside a shared refresh promise — see the race condition warning below.

## TL;DR

```text
Login form
  -> createServerFn(loginFn)
  -> loginWithCredentials() (server-only)
     -> POST /api/auth/login
     -> extract token pair from body + Set-Cookie
     -> validate CRM role
     -> write user + tokens into THIS request's session
  -> redirect to protected area

Protected navigation
  -> _authed route beforeLoad
  -> queryClient.fetchQuery(authMeQueryOptions({ staleTime: 0 }))
  -> getCurrentUserFn() revalidates the session
  -> redirect to /login when null

Authenticated data request
  -> createServerFn(resourceFn)
  -> services/_shared/fetch-client/api-fetch.ts calls ensureAccessToken()
     -> fast path: return cached access token if not near expiry
     -> slow path: join a shared refresh promise keyed on the refresh
        token, then write the result into THIS request's session
  -> one forced-refresh retry on 401
  -> clear session if refresh fails
```

## Critical: the per-request session race

TanStack Start sessions are **cookie-backed and per-request**. Each concurrent server function triggered by the same browser request gets its own `session` instance built from the incoming cookie. `session.update()` mutates that one instance and queues a `Set-Cookie` on that one response. **It does not broadcast to sibling sessions.**

This collides catastrophically with rotating refresh tokens. If you dedupe concurrent refreshes the naive way — wrap the whole refresh in a module-level `refreshPromise` that also calls `session.update()` — exactly one sibling's session receives the new tokens. The rest observe "refresh succeeded" but their own in-memory session still holds the old (now-rotated) refresh token. The next time they try to refresh, the API rejects the rotated token, the session gets cleared, and the user is logged out mid-navigation.

Symptoms to watch for in logs:

```
Access token expired, attempting refresh
Auth session refreshed
Access token expired, attempting refresh   (×N for the siblings)
Auth refresh failed
```

followed by 401s bubbling out of `useSuspenseQuery` into the route boundary.

**The fix is architectural, not a one-line patch.** Split the HTTP refresh (shared across callers) from the session write (local to each caller). Every caller applies the shared result to its own request session. See `ensureAccessToken` below.

## Directory layout

Two separate modules, deliberately not colocated:

```
src/lib/auth/                              # auth bridge — session + token plumbing
├── core/
│   └── roles.ts                           # isCrmRole(), allowlist of CRM roles
└── server/
    ├── session.ts                         # useAppSession, getSessionUser,
    │                                      # clearAuthSession, getAuthLogoutState
    ├── refresh.ts                         # performRefresh — pure HTTP, no session
    ├── ensure-access-token.ts             # race-safe refresh + REFRESH_LEEWAY_SECONDS
    ├── ensure-access-token.test.ts        # concurrency proofs
    └── login.ts                           # loginWithCredentials — full login flow

src/services/_shared/fetch-client/         # shared fetch wrapper — generic HTTP
├── api-fetch.ts                           # calls ensureAccessToken(), attaches
│                                          # Bearer, handles 401 retry with
│                                          # ensureAccessToken({ force: true })
└── constants.ts
```

Why the split:

- `lib/auth/` owns "who is logged in" and "how do we get a valid token for this request." Nothing else.
- `services/_shared/fetch-client/` owns "how do we talk to the backend." It calls into `lib/auth/` for one thing (the token) and stays HTTP-shaped otherwise (errors, schemas, query strings).

Keeping them separate means the auth module has no idea the fetch client exists, so it can be unit-tested in total isolation, and the fetch client has no idea what a session is — it just asks for a token.

Rules for `lib/auth/`:

- **No barrels.** Every consumer imports the exact file. `index.ts` in `lib/auth/` or `lib/auth/server/` is forbidden — they drift, they hide unused code, and they pull in server-only modules through a client-safe name.
- **No re-exports.** If a symbol is used in one place, define it there. If it's used in two places, pick an owner and import directly.
- **Every export has a consumer.** Prune aggressively. Types that are only used inside one file are not `export interface`.

## The session — app auth boundary

```ts
// src/lib/auth/server/session.ts
import { useSession } from '@tanstack/react-start/server'
import type { AuthUser } from '~/services/auth/auth.types'
import { isCrmRole } from '../core/roles'

interface AppSessionData {
  user?: AuthUser
  apiAccessToken?: string
  apiRefreshToken?: string
}

export function useAppSession() {
  const password = process.env['SESSION_SECRET']
  if (!password && process.env.NODE_ENV !== 'development') {
    throw new Error('SESSION_SECRET is required outside development')
  }

  return useSession<AppSessionData>({
    name: 'app-session',
    password: password ?? 'dev-secret-min-32-chars!!',
    cookie: {
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'lax',
      httpOnly: true,
      maxAge: 7 * 24 * 60 * 60,
    },
  })
}

export async function clearAuthSession(): Promise<void> {
  const session = await useAppSession()
  await session.clear()
}

export async function getSessionUser(): Promise<AuthUser | null> {
  const session = await useAppSession()
  const user = session.data.user
  if (!user) return null
  if (!isCrmRole(user.role)) {
    await clearAuthSession()
    return null
  }
  return user
}
```

Invariants:

- The browser never reads session contents directly.
- External backend tokens are stored inside the encrypted session cookie only — never in `localStorage`, Zustand, or any client-readable cookie.
- The session is the source of truth for "is this browser logged into the app." External backend authentication is one level deeper and is mediated by the bridge below.

## Pure refresh helper

```ts
// src/lib/auth/server/refresh.ts
import { extractTokensFromResponse } from '@your-org/shared/lib/token-extract'
import { logger } from '~/lib/logger'
import type { AuthUser } from '~/services/auth/auth.types'
import { isCrmRole } from '../core/roles'

export interface RefreshResult {
  accessToken: string
  refreshToken: string
  user: AuthUser
}

async function fetchCurrentUser(accessToken: string): Promise<AuthUser> {
  const response = await fetch(`${API_BASE_URL}/api/auth/me`, {
    headers: { Authorization: `Bearer ${accessToken}` },
  })
  if (!response.ok) throw new Error('Failed to fetch current user')
  return response.json() as Promise<AuthUser>
}

/**
 * Pure HTTP refresh. MUST NOT touch the session. Its return value is
 * applied to the session by each calling request independently, which is
 * what makes concurrent refresh correct under TanStack Start's per-request
 * session model.
 *
 * Re-fetching /api/auth/me after refresh is intentional — it ensures the
 * role is still valid after rotation (e.g. a user demoted out-of-band
 * won't keep a valid session just because their refresh token is still
 * good).
 *
 * Never throws. Returns null on any failure.
 */
export async function performRefresh(
  refreshToken: string,
): Promise<RefreshResult | null> {
  try {
    const response = await fetch(`${API_BASE_URL}/api/auth/refresh`, {
      method: 'POST',
      headers: { Cookie: `refresh_token=${refreshToken}` },
    })
    if (!response.ok) return null

    const headerTokens = extractTokensFromResponse(response)
    const body = await response.json().catch(() => ({}))
    const accessToken = body.accessToken ?? headerTokens.accessToken
    const nextRefreshToken =
      body.refreshToken ?? headerTokens.refreshToken ?? refreshToken
    if (!accessToken) return null

    const user = await fetchCurrentUser(accessToken)
    if (!isCrmRole(user.role)) return null

    return { accessToken, refreshToken: nextRefreshToken, user }
  } catch (error) {
    logger.error({ error }, 'Auth refresh failed')
    return null
  }
}
```

## ensureAccessToken — the race-safe bridge

```ts
// src/lib/auth/server/ensure-access-token.ts
import { shouldRefreshToken } from '@your-org/shared/lib/jwt-utils'
import { logger } from '~/lib/logger'
import { performRefresh, type RefreshResult } from './refresh'
import { useAppSession } from './session'

const REFRESH_LEEWAY_SECONDS = 30

/**
 * Keyed on the refresh token that triggered the call. All concurrent
 * callers refreshing the SAME token share one HTTP exchange. Keying on the
 * token (rather than a single global lock) lets two different user
 * sessions refresh in parallel.
 */
const inflightRefreshes = new Map<string, Promise<RefreshResult | null>>()

function sharedRefresh(refreshToken: string): Promise<RefreshResult | null> {
  const existing = inflightRefreshes.get(refreshToken)
  if (existing) return existing

  const promise = performRefresh(refreshToken).finally(() => {
    // Clear the slot only after every awaiter has observed the result.
    // A late joiner with the same token would otherwise kick off a second
    // refresh that uses the now-rotated token.
    if (inflightRefreshes.get(refreshToken) === promise) {
      inflightRefreshes.delete(refreshToken)
    }
  })

  inflightRefreshes.set(refreshToken, promise)
  return promise
}

/**
 * Returns a valid API access token for the current request, refreshing
 * transparently if the cached token is expired or stale.
 *
 * Concurrency model: the HTTP refresh is shared across siblings via
 * `sharedRefresh`, the session write is local to each caller. Every
 * sibling writes a matching Set-Cookie header and reads matching
 * in-memory data. See the race condition warning at the top of this doc.
 *
 * Returns undefined when there is no session or the refresh failed. Never
 * throws — callers treat undefined as "redirect to login".
 *
 * Pass `force: true` from the fetch client's 401 retry path when the
 * server rejects a token the client still considers fresh (clock skew,
 * out-of-band revocation).
 */
export async function ensureAccessToken(options?: {
  force?: boolean
}): Promise<string | undefined> {
  const session = await useAppSession()
  const user = session.data.user
  const accessToken = session.data.apiAccessToken
  const refreshToken = session.data.apiRefreshToken

  if (!user || !accessToken || !refreshToken) return undefined

  if (!options?.force && !shouldRefreshToken(accessToken, REFRESH_LEEWAY_SECONDS)) {
    return accessToken
  }

  logger.info({ userId: user.id }, 'Access token expired, attempting refresh')

  const result = await sharedRefresh(refreshToken)
  if (!result) {
    logger.warn({ userId: user.id }, 'Unable to refresh API session')
    await session.clear()
    return undefined
  }

  // Apply the shared refresh result to THIS request's session.
  await session.update({
    ...session.data,
    user: result.user,
    apiAccessToken: result.accessToken,
    apiRefreshToken: result.refreshToken,
  })

  logger.info({ userId: result.user.id }, 'Auth session refreshed')
  return result.accessToken
}
```

The concurrency test that proves this works belongs in the same folder. Minimum coverage:

1. Fast path returns the cached token without calling `performRefresh`.
2. Forced refresh bypasses the leeway check.
3. Two parallel callers with the same refresh token share one `performRefresh` call and both receive the new tokens in their own sessions (gate `performRefresh` with a manually-resolved promise to deterministically hit the race window).
4. When `performRefresh` returns `null`, both sessions are cleared.
5. After the singleton settles, a new call triggers a fresh refresh with the rotated token.

Without test #3 you cannot verify the fix. The old broken behaviour passes every other test.

## Login — one function, no re-fetch

Keep the full login flow in one server-only helper and make `loginFn` a thin server-function wrapper:

```ts
// src/lib/auth/server/login.ts
export async function loginWithCredentials(
  data: { email: string; password: string },
): Promise<{ user: AuthUser }> {
  const response = await fetch(`${API_BASE_URL}/api/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  })
  if (!response.ok) {
    const error = await response.json().catch(() => ({ message: 'Login failed' }))
    throw new Error(error.message ?? 'Invalid credentials')
  }

  const body = await response.json()
  const headerTokens = extractTokensFromResponse(response)
  const accessToken = body.accessToken ?? headerTokens.accessToken
  const refreshToken = body.refreshToken ?? headerTokens.refreshToken
  if (!accessToken) throw new Error('Missing access token in login response')
  if (!isCrmRole(body.user.role)) {
    await clearAuthSession()
    throw new Error('Unauthorized access')
  }

  const session = await useAppSession()
  await session.update({
    ...session.data,
    user: body.user,
    apiAccessToken: accessToken,
    apiRefreshToken: refreshToken ?? session.data.apiRefreshToken,
  })
  return { user: body.user }
}
```

```ts
// src/services/auth/auth.functions.ts
export const loginFn = createServerFn({ method: 'POST' })
  .inputValidator(loginSchema)
  .handler(async ({ data }) => {
    const { loginWithCredentials } = await import('~/lib/auth/server/login')
    return loginWithCredentials(data)
  })
```

Anti-pattern to avoid: a `syncSessionFromTokens` helper that re-fetches `/api/auth/me` right after login. The login response already returns the user. Trust it; don't round-trip again.

## Protected layout — `_authed`

```ts
// src/routes/_authed.tsx
import { createFileRoute, Outlet, redirect } from '@tanstack/react-router'
import { authMeQueryOptions } from '~/services/auth/auth.query-options'

export const Route = createFileRoute('/_authed')({
  beforeLoad: async ({ location, context }) => {
    const user = await context.queryClient.fetchQuery({
      ...authMeQueryOptions(),
      staleTime: 0,
    })
    if (!user) {
      throw redirect({
        to: '/login',
        search: { redirect: location.href },
      })
    }
    return { user }
  },
  component: AuthedLayout,
  errorComponent: ({ error, reset }) => (
    <AppLayout>
      <PageError error={error} reset={reset} />
    </AppLayout>
  ),
})

function AuthedLayout() {
  return <AppLayout><Outlet /></AppLayout>
}
```

Why `fetchQuery` with `staleTime: 0` instead of `getQueryData`:

- Protected navigation should validate current session freshness, not trust a 5-minute-old cache.
- Expired access tokens can refresh before the next screen renders.
- Redirects happen early instead of after a half-rendered page throws.

The `getCurrentUserFn` behind `authMeQueryOptions` should validate the session, not echo session data:

```ts
export const getCurrentUserFn = createServerFn({ method: 'GET' }).handler(
  async () => {
    const { getSessionUser } = await import('~/lib/auth/server/session')
    return getSessionUser()  // returns null if role was revoked or session is stale
  },
)
```

## Fetch client — minimal surface

The shared fetch wrapper at `services/_shared/fetch-client/api-fetch.ts` is the only place that calls `ensureAccessToken()`. Every service function imports `api` from here and stays completely unaware of tokens, sessions, or refresh.

```ts
// src/services/_shared/fetch-client/api-fetch.ts
import { ensureAccessToken } from '~/lib/auth/server/ensure-access-token'
import { clearAuthSession } from '~/lib/auth/server/session'

async function request<T>(method, path, options, isRetry = false) {
  const headers = { ...options?.headers }

  if (!options?.skipAuth) {
    const accessToken = await ensureAccessToken()
    if (!accessToken) throw new ApiError(401, 'Unauthorized')
    headers.Authorization = `Bearer ${accessToken}`
  }

  const res = await fetch(url, { method, headers, body })

  if (res.status === 401 && !isRetry && !options?.skipAuth) {
    // Server rejected a token we thought was valid (clock skew, revocation).
    const refreshed = await ensureAccessToken({ force: true })
    if (refreshed) return request<T>(method, path, options, true)
    await clearAuthSession()
  }

  // ... normal response handling
}
```

Auth is fully encapsulated inside the fetch client — zero service files need to plumb tokens through context.

## Client surfaces that use `useSuspenseQuery`

Suspense queries throw auth errors into the nearest error boundary. A transient 401 during a rotating refresh — exactly the race the fix above prevents, but still possible under real failure modes — will unmount whichever subtree ran the query.

Wrap auth-sensitive surfaces in a narrow `CatchBoundary` with a reset key tied to the logged-in user:

```tsx
// src/components/some-surface/surface.tsx
import { CatchBoundary, useRouteContext } from '@tanstack/react-router'

export function Surface(props) {
  // Only valid when this component renders under _authed.
  const { user } = useRouteContext({ from: '/_authed' })

  return (
    <CatchBoundary
      getResetKey={() => user?.id ?? 'anon'}
      errorComponent={SurfaceErrorFallback}
    >
      <Suspense fallback={<SurfaceSkeleton />}>
        <SurfaceInner {...props} />
      </Suspense>
    </CatchBoundary>
  )
}
```

Keying on `user.id` makes the boundary reset automatically on login/logout/user-switch instead of being pinned to a static string forever.

Do not use this as an excuse to wrap everything in boundaries. It's for side surfaces (chat widgets, AI assistant panels, embeddable dashboards) where a transient 401 should not crash the whole route tree. The route-level `errorComponent` on `_authed` still handles real logout flow.

## Middleware — optional, not mandatory

TanStack Start supports server-function middleware via `createMiddleware({ type: 'function' })`. It's useful for:

- role / permission checks shared by many server functions
- workspace or tenant context injection
- request logging with typed context

```ts
const authMiddleware = createMiddleware({ type: 'function' }).server(
  async ({ next }) => {
    const accessToken = await ensureAccessToken()
    if (!accessToken) throw new Error('Unauthorized')
    const user = await requireSessionUser()
    return next({ context: { accessToken, user } })
  },
)
```

Rules:

- **Do not wrap `createServerFn` in opaque factories.** `createAuthedServerFn = () => createServerFn().middleware([...])` is fine; `makeResource = (schema, fn) => createServerFn(...)` that hides the boundary is not. Start's compiler must see the real `createServerFn(...)` call.
- **Do not use middleware to replace `ensureAccessToken()` inside the fetch client.** The fetch client runs downstream of the middleware's `next()`, so the middleware's refresh would execute in a separate request context than the service's fetch. Keep auth as close to the actual API call as possible.
- **Middleware is optional.** If you only have one or two surfaces that need `user` in context (server routes, SSE stream endpoints), they can call `ensureAccessToken()` + `requireSessionUser()` inline. Don't build a middleware just because the guide mentions it.

## Why not middleware-driven refresh, like Next.js?

Next.js edge middleware runs once per HTTP request before any route handler, so you can refresh tokens there, set new cookies on the response, and every downstream handler sees a consistent cookie. That pattern is structurally immune to the per-request session race.

TanStack Start doesn't have an equivalent hook. `createMiddleware` is scoped to individual server functions (it runs *inside* each server-function call), not to the HTTP request as a whole. SSR loaders, route `beforeLoad`, server routes, and server functions all take different entry points. Refresh has to happen at a boundary all of them cross, and for a BFF that boundary is the fetch client — which is where we put it.

The encrypted session cookie is the compensating pattern. It lets every entry point find the same user + tokens via `useAppSession()`, and the race-safe `ensureAccessToken` coordinates concurrent writes. It's not a security upgrade over Next.js's raw httpOnly token cookies — both are equally safe from XSS. It's a mechanism for colocating "who is logged in" with "which external tokens represent them" in a framework where there's no single refresh chokepoint.

If TanStack Start ever adds true per-HTTP-request middleware, this doc gets shorter.

## E-store vs CRM

Use the same core auth architecture in both apps with different protection scope.

CRM / admin:

- Almost everything is protected.
- `_authed` revalidates on every navigation (`staleTime: 0` in `fetchQuery`).
- Role check happens in `getSessionUser` — non-admin sessions are cleared eagerly.

Storefront / public app:

- Catalog, product, search, home, content pages stay anonymous.
- Only account, orders, wishlist, saved addresses require auth.
- Optional auth should enrich header/account/cart without blocking public navigation.
- `_authed` layout wraps only the authenticated subtree; public routes never touch the session.

## TanStack Query defaults for auth failures

Do not let Query retry auth failures repeatedly. That delays logout and creates the "invalid token → a few seconds of retries → eventually redirect" feel.

```ts
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: (failureCount, error) => !isAuthError(error) && failureCount < 2,
    },
    mutations: {
      retry: (failureCount, error) => !isAuthError(error) && failureCount < 1,
    },
  },
})
```

---

## RBAC

RBAC itself is framework-agnostic and mostly mirrors the Next.js architecture. Keep:

- Flat permission strings (`flows_view`, `flows_delete`, ...).
- Role hierarchy with numeric levels and `>=` comparison.
- Server-side permission checks inside server functions — never trust client-only checks for security.
- Route-level UX gating (`<Can permission="...">` components, `useAccess()` hook) only as a convenience to hide buttons and menu items.

```ts
// src/lib/rbac/server/server.ts
import { getSessionUser } from '~/lib/auth/server/session'

export async function requirePermission(permission: string): Promise<void> {
  const user = await getSessionUser()
  if (!user) throw new Error('Unauthorized')
  if (!user.permissions.includes(permission)) {
    throw new Error(`Missing permission: ${permission}`)
  }
}
```

Usage inside server functions:

```ts
export const deleteFlowFn = createServerFn({ method: 'POST' })
  .inputValidator(deleteFlowSchema)
  .handler(async ({ data }) => {
    await requirePermission('flows_delete')
    const { api } = await import('~/services/_shared/fetch-client/api-fetch')
    return api.delete(`/api/admin/flows/${data.id}`)
  })
```

Declarative client-side gating:

```tsx
<Can permission="flows_delete">
  <DeleteFlowButton flowId={flow.id} />
</Can>
```

This is UX only. The backend still enforces the same permission on the API call.

## Directory structure summary

```
src/lib/auth/                              # auth bridge
├── core/
│   └── roles.ts
└── server/
    ├── session.ts
    ├── refresh.ts
    ├── ensure-access-token.ts
    ├── ensure-access-token.test.ts
    └── login.ts

src/lib/rbac/                              # permissions + role checks
├── permissions.ts       # flat permission string constants
├── roles.ts             # role enum, hierarchy map
├── types.ts
├── validate.ts
├── server/
│   └── server.ts        # requirePermission, requireRole
└── client/
    └── client.ts        # useAccess hook, <Can> component

src/services/
├── _shared/
│   └── fetch-client/
│       ├── api-fetch.ts        # imports ensureAccessToken directly
│       └── constants.ts
└── auth/
    ├── auth.functions.ts       # loginFn, logoutFn, getCurrentUserFn (thin wrappers)
    ├── auth.query-options.ts
    ├── auth.hooks.ts
    ├── auth.schema.ts
    └── auth.types.ts
```

## Checklist when implementing or reviewing

- [ ] No barrels (`index.ts`) in `src/lib/auth/` or `src/lib/auth/server/`.
- [ ] No re-exports. Every symbol has exactly one owner file.
- [ ] `ensureAccessToken` splits HTTP refresh from session write.
- [ ] Refresh lock is keyed on the refresh token, not a global singleton.
- [ ] Session update happens in the caller, not inside the shared refresh promise.
- [ ] Concurrency test #3 (two parallel callers, manually-gated `performRefresh`) exists and passes.
- [ ] Login flow does not re-fetch `/api/auth/me` after the login response already returned the user.
- [ ] `_authed` layout uses `fetchQuery({ ...authMeQueryOptions(), staleTime: 0 })`, not `getQueryData`.
- [ ] `getSessionUser` clears the session when the user's role is no longer CRM-admissible.
- [ ] `services/_shared/fetch-client/api-fetch.ts` calls `ensureAccessToken()` on every auth'd request and `ensureAccessToken({ force: true })` on 401 retry.
- [ ] TanStack Query is configured to **not** retry auth errors.
- [ ] Suspense surfaces under `_authed` wrap their inner query in a `CatchBoundary` keyed on `user.id`.
- [ ] No `createServerFn` wrappers hide the boundary from Start's compiler.
- [ ] No tokens in `localStorage`, `sessionStorage`, or client-readable cookies.
- [ ] Every `.server.ts` stays out of the client-reachable import graph.
