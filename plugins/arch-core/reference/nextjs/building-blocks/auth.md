# Authentication Integration

Cookie-based JWT authentication for external backend integration. The backend issues tokens; this architecture stores, refreshes, and attaches them.

## Directory structure

```
src/lib/auth/
├── core/
│   ├── config.ts          # Cookie names, TTLs, options
│   ├── types.ts           # TokenPair, UserSession
│   └── jwt.ts             # Decode/verify JWT, expiry check
├── server/
│   ├── session.ts         # getSession(), requireSession()
│   ├── cookies.ts         # getTokens(), setTokens(), clearTokens()
│   └── proxy/             # Auth proxy helpers (for /api/auth/ routes)
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
  maxAge: 15 * 60, // 15 minutes
};

export const REFRESH_TOKEN_OPTIONS = {
  ...COOKIE_OPTIONS,
  maxAge: 7 * 24 * 60 * 60, // 7 days
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
  // Extend with your backend's JWT payload fields
}
```

## `core/jwt.ts`

```typescript
import { z } from "zod";

const jwtPayloadSchema = z.object({
  userId: z.string(),
  sub: z.string(), // email
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

## `server/cookies.ts` (server-only)

```typescript
import "server-only";
import { cookies } from "next/headers";
import {
  COOKIE_KEYS,
  ACCESS_TOKEN_OPTIONS,
  REFRESH_TOKEN_OPTIONS,
} from "~/lib/auth/core/config";
import type { TokenPair } from "~/lib/auth/core/types";

export async function getTokens(): Promise<Partial<TokenPair> | null> {
  const cookieStore = await cookies();
  const accessToken = cookieStore.get(COOKIE_KEYS.ACCESS_TOKEN)?.value;
  const refreshToken = cookieStore.get(COOKIE_KEYS.REFRESH_TOKEN)?.value;

  if (!accessToken && !refreshToken) return null;
  return { accessToken, refreshToken };
}

export async function setTokens(tokens: TokenPair): Promise<void> {
  const cookieStore = await cookies();
  cookieStore.set(COOKIE_KEYS.ACCESS_TOKEN, tokens.accessToken, ACCESS_TOKEN_OPTIONS);
  cookieStore.set(COOKIE_KEYS.REFRESH_TOKEN, tokens.refreshToken, REFRESH_TOKEN_OPTIONS);
}

export async function clearTokens(): Promise<void> {
  const cookieStore = await cookies();
  cookieStore.delete(COOKIE_KEYS.ACCESS_TOKEN);
  cookieStore.delete(COOKIE_KEYS.REFRESH_TOKEN);
}
```

## `server/session.ts` (server-only)

```typescript
import "server-only";
import { redirect } from "next/navigation";
import { getTokens } from "./cookies";
import { decodeToken } from "~/lib/auth/core/jwt";
import type { UserSession } from "~/lib/auth/core/types";

export function toUserSession(payload: JwtPayload): UserSession {
  return {
    userId: payload.userId,
    email: payload.sub,
    role: payload.role,
    workspacePermissions: payload.workspacePermissions,
  };
}

export async function getSession(): Promise<UserSession | null> {
  const tokens = await getTokens();
  if (!tokens?.accessToken) return null;

  const payload = decodeToken(tokens.accessToken);
  if (!payload) return null;

  return toUserSession(payload);
}

export async function requireSession(): Promise<UserSession> {
  const session = await getSession();
  if (!session) {
    redirect("/auth/login");
  }
  return session;
}
```

## `client/refresh-lock.ts` (client-only)

```typescript
let refreshPromise: Promise<boolean> | null = null;

export async function refreshWithLock(): Promise<boolean> {
  // If a refresh is already in flight, reuse its promise
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
    cache: "no-store",
  });

  if (!response.ok) {
    throw new Error("Token refresh failed");
  }

  return response.json();
}
```

## Auth API routes

Dedicated auth routes handle login, register, refresh, and logout:

```
src/app/api/auth/
├── login/route.ts       # POST — calls backend, sets cookies
├── register/route.ts    # POST — calls backend, sets cookies
├── refresh/route.ts     # POST — refreshes tokens, sets new cookies
└── logout/route.ts      # POST — clears cookies
```

Example refresh route:

```typescript
// app/api/auth/refresh/route.ts
import { NextResponse } from "next/server";
import { getTokens, setTokens, clearTokens } from "~/lib/auth/server/cookies";
import { refreshTokens } from "~/lib/auth/refresh";

export async function POST() {
  const tokens = await getTokens();
  if (!tokens?.refreshToken) {
    return NextResponse.json({ message: "No refresh token" }, { status: 401 });
  }

  try {
    const newTokens = await refreshTokens(tokens.refreshToken);
    await setTokens(newTokens);
    return NextResponse.json({ ok: true });
  } catch {
    await clearTokens();
    return NextResponse.json({ message: "Refresh failed" }, { status: 401 });
  }
}
```

## Integration notes

This auth system is designed for **external backend integration**:
- The backend owns user management and token issuance
- Next.js only stores tokens in cookies and attaches them to requests
- JWT is decoded client-side (for session info) but never verified — the backend is the authority
- Token refresh is handled transparently by both the middleware (server) and `refreshWithLock` (client)
