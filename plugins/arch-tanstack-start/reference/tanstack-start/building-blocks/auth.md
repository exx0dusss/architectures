# Authentication Integration

Cookie-based JWT authentication for external backend integration. The backend issues tokens; this architecture stores, refreshes, and attaches them via `getWebRequest()`.

## Directory structure

```
src/lib/auth/
├── core/
│   ├── config.ts          # Cookie names, TTLs, options
│   ├── types.ts           # TokenPair, UserSession
│   └── jwt.ts             # Decode/verify JWT, expiry check
├── server/
│   ├── session.ts         # getSession(), requireSession() via getWebRequest()
│   ├── cookies.ts         # setTokens, clearTokens via vinxi/http
│   └── middleware.ts       # authMiddleware for server functions
├── client/
│   └── refresh-lock.ts    # Mutex for concurrent refresh prevention
└── refresh.ts             # Shared refresh logic
```

## `core/config.ts`

```typescript
import { env } from "~/env";

export const COOKIE_KEYS = {
  ACCESS_TOKEN: "access_token",
  REFRESH_TOKEN: "refresh_token",
} as const;

export const COOKIE_OPTIONS = {
  httpOnly: true,
  secure: env.COOKIE_SECURE,
  sameSite: "lax" as const,
  path: "/",
};

export const ACCESS_TOKEN_OPTIONS = {
  ...COOKIE_OPTIONS,
  maxAge: 15 * 60,
};

export const REFRESH_TOKEN_OPTIONS = {
  ...COOKIE_OPTIONS,
  maxAge: 7 * 24 * 60 * 60,
};
```

## `core/types.ts`

```typescript
export interface TokenPair {
  accessToken: string;
  refreshToken: string;
}

export interface UserSession {
  userId: string;
  email: string;
  role: string;
  workspacePermissions: Record<string, number[]>;
}
```

## `core/jwt.ts`

```typescript
import { z } from "zod";

const jwtPayloadSchema = z.object({
  userId: z.string(),
  sub: z.string(),
  role: z.string(),
  exp: z.number(),
  workspacePermissions: z.record(z.string(), z.array(z.number())).default({}),
});

export type JwtPayload = z.infer<typeof jwtPayloadSchema>;

export function decodeToken(token: string): JwtPayload | null {
  try {
    const payload = JSON.parse(atob(token.split(".")[1]));
    return jwtPayloadSchema.parse(payload);
  } catch {
    return null;
  }
}

export function isTokenExpired(token: string, bufferSeconds = 60): boolean {
  const payload = decodeToken(token);
  if (!payload) return true;
  const now = Math.floor(Date.now() / 1000);
  return payload.exp - bufferSeconds <= now;
}
```

## `server/cookies.ts`

```typescript
import { setCookie, deleteCookie, getCookie } from "vinxi/http";
import {
  COOKIE_KEYS,
  ACCESS_TOKEN_OPTIONS,
  REFRESH_TOKEN_OPTIONS,
} from "~/lib/auth/core/config";
import type { TokenPair } from "~/lib/auth/core/types";

export function setTokens(tokens: TokenPair): void {
  setCookie(COOKIE_KEYS.ACCESS_TOKEN, tokens.accessToken, ACCESS_TOKEN_OPTIONS);
  setCookie(COOKIE_KEYS.REFRESH_TOKEN, tokens.refreshToken, REFRESH_TOKEN_OPTIONS);
}

export function clearTokens(): void {
  deleteCookie(COOKIE_KEYS.ACCESS_TOKEN);
  deleteCookie(COOKIE_KEYS.REFRESH_TOKEN);
}

export function getAccessToken(): string | undefined {
  return getCookie(COOKIE_KEYS.ACCESS_TOKEN);
}

export function getRefreshToken(): string | undefined {
  return getCookie(COOKIE_KEYS.REFRESH_TOKEN);
}
```

## `server/session.ts`

```typescript
import { getWebRequest } from "@tanstack/react-start/server";
import { COOKIE_KEYS } from "~/lib/auth/core/config";
import { decodeToken, type JwtPayload } from "~/lib/auth/core/jwt";
import type { UserSession } from "~/lib/auth/core/types";
import { ServerApiError } from "~/services/_shared/errors";

function parseCookie(cookieHeader: string, name: string): string | undefined {
  const match = cookieHeader.match(new RegExp(`(?:^|;\\s*)${name}=([^;]*)`));
  return match ? decodeURIComponent(match[1]) : undefined;
}

function toUserSession(payload: JwtPayload): UserSession {
  return {
    userId: payload.userId,
    email: payload.sub,
    role: payload.role,
    workspacePermissions: payload.workspacePermissions,
  };
}

export function getSession(): UserSession | null {
  const request = getWebRequest();
  const cookieHeader = request.headers.get("cookie") ?? "";
  const accessToken = parseCookie(cookieHeader, COOKIE_KEYS.ACCESS_TOKEN);

  if (!accessToken) return null;

  const payload = decodeToken(accessToken);
  if (!payload) return null;

  return toUserSession(payload);
}

export function requireSession(): UserSession {
  const session = getSession();
  if (!session) {
    throw new ServerApiError("Unauthorized", 401, "UNAUTHORIZED");
  }
  return session;
}
```

## `server/middleware.ts`

```typescript
import { createMiddleware } from "@tanstack/react-start";
import { requireSession } from "./session";

export const authMiddleware = createMiddleware().server(async ({ next }) => {
  const session = requireSession();
  return next({ context: { session } });
});
```

## `client/refresh-lock.ts`

```typescript
let refreshPromise: Promise<boolean> | null = null;

export async function refreshWithLock(): Promise<boolean> {
  if (refreshPromise) return refreshPromise;

  refreshPromise = (async () => {
    try {
      const response = await fetch("/api/auth/refresh", {
        method: "POST",
        credentials: "include",
      });
      return response.ok;
    } catch {
      return false;
    } finally {
      refreshPromise = null;
    }
  })();

  return refreshPromise;
}
```

## `refresh.ts`

```typescript
import { env } from "~/env";
import type { TokenPair } from "./core/types";

export async function refreshTokens(refreshToken: string): Promise<TokenPair> {
  const response = await fetch(`${env.AUTH_BASE_URL}/api/auth/refresh-access-token`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ refreshToken }),
  });

  if (!response.ok) {
    throw new Error("Token refresh failed");
  }

  return response.json();
}
```

## Auth API route

```typescript
// src/routes/api/auth/refresh.ts
import { createAPIFileRoute } from "@tanstack/react-start/api";
import { getCookie, setCookie, deleteCookie } from "vinxi/http";
import { refreshTokens } from "~/lib/auth/refresh";
import { COOKIE_KEYS, ACCESS_TOKEN_OPTIONS, REFRESH_TOKEN_OPTIONS } from "~/lib/auth/core/config";

export const APIRoute = createAPIFileRoute("/api/auth/refresh")({
  POST: async () => {
    const refreshToken = getCookie(COOKIE_KEYS.REFRESH_TOKEN);
    if (!refreshToken) {
      return new Response(JSON.stringify({ message: "No refresh token" }), { status: 401 });
    }

    try {
      const newTokens = await refreshTokens(refreshToken);
      setCookie(COOKIE_KEYS.ACCESS_TOKEN, newTokens.accessToken, ACCESS_TOKEN_OPTIONS);
      setCookie(COOKIE_KEYS.REFRESH_TOKEN, newTokens.refreshToken, REFRESH_TOKEN_OPTIONS);
      return new Response(JSON.stringify({ ok: true }));
    } catch {
      deleteCookie(COOKIE_KEYS.ACCESS_TOKEN);
      deleteCookie(COOKIE_KEYS.REFRESH_TOKEN);
      return new Response(JSON.stringify({ message: "Refresh failed" }), { status: 401 });
    }
  },
});
```

## Route-level auth guard

Use `beforeLoad` on layout routes to protect all children:

```typescript
// src/routes/_authed.tsx
import { createFileRoute, redirect } from "@tanstack/react-router";
import { createServerFn } from "@tanstack/react-start";
import { getSession } from "~/lib/auth/server/session";

const getAuthSession = createServerFn({ method: "GET" })
  .handler(() => getSession());

export const Route = createFileRoute("/_authed")({
  beforeLoad: async () => {
    const session = await getAuthSession();
    if (!session) {
      throw redirect({ to: "/auth/login" });
    }
    return { session };
  },
  component: AuthedLayout,
});
```
