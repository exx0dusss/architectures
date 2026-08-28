# Authentication & RBAC

Cookie-based JWT auth with role hierarchy and flat permission strings.

## Authentication flow

```
Login → Backend returns access + refresh tokens → Stored in httpOnly cookies
Request → serverFetch reads cookie → Attaches Authorization header → Backend
401 → refreshWithLock() → New tokens → Retry original request
Expired + no refresh → Middleware redirects to /auth/login
```

## Cookie configuration

```typescript
// src/lib/auth/core/config.ts
export const AUTH_CONFIG = {
  cookies: {
    accessToken: {
      name: "access_token",
      maxAge: 15 * 60,              // 15 minutes
      httpOnly: true,
      secure: env.COOKIE_SECURE,
      sameSite: "lax" as const,
      path: "/",
    },
    refreshToken: {
      name: "refresh_token",
      maxAge: 7 * 24 * 60 * 60,     // 7 days
      httpOnly: true,
      secure: env.COOKIE_SECURE,
      sameSite: "lax" as const,
      path: "/",
    },
  },
};
```

## Token refresh (mutex)

Client-side refresh uses a lock to prevent concurrent refresh races:

```typescript
// src/lib/auth/client/refresh-lock.ts
let refreshPromise: Promise<void> | null = null;

export async function refreshWithLock(): Promise<void> {
  if (refreshPromise) return refreshPromise;

  refreshPromise = (async () => {
    try {
      await fetch("/api/auth/refresh", { method: "POST" });
    } finally {
      refreshPromise = null;
    }
  })();

  return refreshPromise;
}
```

When `apiClient` gets a 401, it calls `refreshWithLock()` then retries. Multiple concurrent 401s share the same refresh call.

## Middleware

```typescript
// src/proxy.ts (Next.js middleware)
export default async function middleware(request: NextRequest) {
  // 1. Check auth cookies
  const accessToken = request.cookies.get("access_token");
  const refreshToken = request.cookies.get("refresh_token");

  // 2. If no tokens and accessing protected route → redirect to login
  if (!accessToken && !refreshToken && isProtectedRoute(request)) {
    return NextResponse.redirect(new URL("/auth/login", request.url));
  }

  // 3. If access expired but refresh exists → attempt refresh
  if (!accessToken && refreshToken) {
    const refreshed = await handleRefresh(refreshToken);
    if (!refreshed) return NextResponse.redirect(new URL("/auth/login", request.url));
  }

  // 4. i18n locale detection (next-intl)
  return intlMiddleware(request);
}
```

## Auth directory structure

```
src/lib/auth/
├── core/
│   ├── config.ts          # Cookie config, TTLs
│   ├── types.ts           # User, Session types
│   └── jwt.ts             # JWT decode/verify utilities
├── server/
│   ├── session.ts         # getSession() — reads cookies, returns user
│   ├── cookies.ts         # setTokenCookies, clearTokenCookies
│   └── proxy/             # Auth proxy helpers for API routes
├── client/
│   └── refresh-lock.ts    # Mutex for concurrent refresh prevention
└── refresh.ts             # Shared refresh logic
```

---

## RBAC Model

### Role hierarchy

```typescript
// src/lib/rbac/roles.ts
export const ROLES = [
  "OWNER", "ADMIN", "TEAM_LEAD_MANAGER", "TEAM_LEAD",
  "MANAGER", "CHAT_ADMIN", "BUYER", "VIEWER", "USER",
] as const;

export type UserRole = (typeof ROLES)[number];

export const roleHierarchy: Record<UserRole, number> = {
  OWNER: 6,
  ADMIN: 5,
  TEAM_LEAD_MANAGER: 4,
  TEAM_LEAD: 4,
  MANAGER: 3,
  CHAT_ADMIN: 3,
  BUYER: 2,
  VIEWER: 1,
  USER: 0,
};
```

Higher number = more authority. Role checks use `>=` comparison.

### Permissions (flat strings)

```typescript
// src/lib/rbac/permissions.ts
export const permissions = {
  buying: {
    flows:    { view: "flows_view",    create: "flows_create",    edit: "flows_edit",    delete: "flows_delete" },
    channels: { view: "channels_view", create: "channels_create", edit: "channels_edit", delete: "channels_delete" },
    bots:     { view: "bots_view",     create: "bots_create",     edit: "bots_edit",     delete: "bots_delete" },
    // ... more resources
  },
  chatting: {
    bots:     { view: "chat-bots_view", create: "chat-bots_create", edit: "chat-bots_edit" },
    funnels:  { view: "funnels_view",   create: "funnels_create",   edit: "funnels_edit" },
    // ... more resources
  },
};
```

### Server-side enforcement

```typescript
// src/lib/rbac/server/server.ts
import { getSession } from "~/lib/auth/server/session";

export async function requirePermission(permission: string): Promise<void> {
  const session = await getSession();
  if (!session.permissions.includes(permission)) {
    throw forbidden(`Missing permission: ${permission}`);
  }
}

export async function requireRole(minRole: UserRole): Promise<void> {
  const session = await getSession();
  if (roleHierarchy[session.role] < roleHierarchy[minRole]) {
    throw forbidden(`Insufficient role: need ${minRole}`);
  }
}
```

Usage in server actions:

```typescript
"use server";

export async function deleteFlow(request: DeleteFlowRequest): Promise<ApiResult<void>> {
  return safeAction(async () => {
    await requirePermission("flows_delete");
    // ... proceed with deletion
  }, { code: "FLOWS_DELETE_FAILED", message: "Failed to delete flow" });
}
```

### Client-side checks

```typescript
// src/lib/rbac/client/client.ts
"use client";

export function useAccess() {
  const session = useSession();
  return {
    hasPermission: (p: string) => session.permissions.includes(p),
    hasRole: (role: UserRole) => roleHierarchy[session.role] >= roleHierarchy[role],
    canManageUser: (targetRole: UserRole) => roleHierarchy[session.role] > roleHierarchy[targetRole],
    canAccessModule: (module: "buying" | "chatting") => { /* module-level check */ },
  };
}

// Declarative component
export function Can({ permission, children }: { permission: string; children: ReactNode }) {
  const { hasPermission } = useAccess();
  if (!hasPermission(permission)) return null;
  return <>{children}</>;
}
```

Usage:

```tsx
const { hasPermission } = useAccess();

// Imperative
if (hasPermission("flows_create")) { /* show button */ }

// Declarative
<Can permission="flows_delete">
  <DeleteFlowButton flowId={flow.id} />
</Can>
```

## RBAC directory structure

```
src/lib/rbac/
├── permissions.ts         # Flat permission string constants
├── roles.ts               # Role enum, hierarchy map
├── types.ts               # Permission, Role types
├── validate.ts            # Shared validation logic
├── server/
│   ├── server.ts          # requirePermission, requireRole
│   └── utils.ts           # Helper utilities
└── client/
    └── client.ts          # useAccess hook, <Can> component
```

---

## Porting this architecture to frameworks without edge middleware

This whole refresh model — raw httpOnly access/refresh cookies, a client-side refresh lock, and rotation handled inside Next.js edge middleware — is **structurally immune** to one specific bug class: the per-request session race that bites BFFs with rotating refresh tokens.

The reason it's immune is that Next.js edge middleware runs **exactly once per HTTP request, before any route handler**. Refresh happens in one place, writes new cookies on the outgoing response, and every downstream handler in that same request sees a consistent cookie set. There is no way for two parallel server functions in the same render to both try to refresh and stomp on each other.

If you port this architecture to a framework without an equivalent hook, you lose that guarantee. TanStack Start is the canonical example: its server-function middleware runs *inside* each server function, not once per HTTP request, so refresh has to happen at some other chokepoint (usually the fetch client). When a browser reload fires N server functions in parallel, they each have their own per-request session instance built from the same incoming cookie. A naive shared-promise lock that writes tokens back via `session.update()` inside the shared promise will silently update only one of those N sessions — the rest keep the rotated (now-invalid) refresh token and log the user out on the next request.

**Read the TanStack Start architecture's auth doc before porting:** [`tanstack-start/auth-rbac.md` → Critical: the per-request session race](../tanstack-start/auth-rbac.md#critical-the-per-request-session-race). The fix is to split the shared HTTP refresh from the per-request session write. It doesn't apply to Next.js (edge middleware already serializes the write), but it's the shape you need in any framework that doesn't give you one.

If you're staying on Next.js, this section is just context. The architecture above is the correct pattern here.
