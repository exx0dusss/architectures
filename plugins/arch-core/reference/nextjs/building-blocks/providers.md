# Providers & Configuration

## Provider stack (`providers/providers.tsx`)

```typescript
"use client";

import { ThemeProvider } from "./theme-provider";
import { QueryClientProvider } from "./query-client-provider";
import { NuqsAdapter } from "nuqs/adapters/next/app";
import { DevtoolsProvider } from "./devtools-provider";
import { MswInit } from "~/mocks/msw-init";
import { Toaster } from "~/components/ui/toast";
import type { ReactNode } from "react";

export function Providers({ children }: { children: ReactNode }) {
  return (
    <MswInit>
      <ThemeProvider attribute="class" defaultTheme="system" enableSystem>
        <QueryClientProvider>
          <NuqsAdapter>
            <DevtoolsProvider>
              <Toaster />
              {children}
            </DevtoolsProvider>
          </NuqsAdapter>
        </QueryClientProvider>
      </ThemeProvider>
    </MswInit>
  );
}
```

## Query client (`lib/query/get-query-client.ts`)

```typescript
import {
  QueryClient,
  defaultShouldDehydrateQuery,
  isServer,
} from "@tanstack/react-query";
import { refreshWithLock } from "~/lib/auth/client/refresh-lock";
import { isApiError } from "~/services/_shared/errors";

function makeQueryClient() {
  return new QueryClient({
    defaultOptions: {
      queries: {
        staleTime: 60 * 1000,       // 1 minute
        gcTime: 5 * 60 * 1000,      // 5 minutes
        refetchOnWindowFocus: false,
        refetchOnReconnect: true,
        retry: (failureCount, error) => {
          // Never retry client errors (except 401 which is handled separately)
          if (isApiError(error) && error.status >= 400 && error.status < 500) {
            return false;
          }
          return failureCount < 2;
        },
        retryDelay: (attemptIndex) => Math.min(1000 * 2 ** attemptIndex, 30000),
      },
      mutations: {
        retry: false,
      },
      dehydrate: {
        shouldDehydrateQuery: (query) =>
          defaultShouldDehydrateQuery(query) || query.state.status === "pending",
      },
    },
  });
}

let browserQueryClient: QueryClient | undefined;

export function getQueryClient(): QueryClient {
  if (isServer) {
    // Server: always create a new client (prevents cross-request leaks)
    return makeQueryClient();
  }
  // Browser: reuse a singleton
  if (!browserQueryClient) {
    browserQueryClient = makeQueryClient();

    // Global 401 handler — attempt refresh
    browserQueryClient.getQueryCache().config.onError = async (error) => {
      if (isApiError(error) && error.status === 401) {
        await refreshWithLock();
      }
    };
  }
  return browserQueryClient;
}
```

## Theme provider (`providers/theme-provider.tsx`)

```typescript
"use client";

import { ThemeProvider as NextThemesProvider } from "next-themes";
import type { ComponentProps } from "react";

export function ThemeProvider(props: ComponentProps<typeof NextThemesProvider>) {
  return <NextThemesProvider {...props} />;
}
```

## Query client provider (`providers/query-client-provider.tsx`)

```typescript
"use client";

import { QueryClientProvider as TanStackProvider } from "@tanstack/react-query";
import { getQueryClient } from "~/lib/query/get-query-client";
import type { ReactNode } from "react";

export function QueryClientProvider({ children }: { children: ReactNode }) {
  const queryClient = getQueryClient();
  return <TanStackProvider client={queryClient}>{children}</TanStackProvider>;
}
```

## MSW initialization (`mocks/msw-init.tsx`)

```typescript
"use client";

import { useEffect, useState, type ReactNode } from "react";
import { env } from "~/env";

export function MswInit({ children }: { children: ReactNode }) {
  const [ready, setReady] = useState(!env.NEXT_PUBLIC_MSW_ENABLED);

  useEffect(() => {
    if (!env.NEXT_PUBLIC_MSW_ENABLED) return;

    import("./browser").then(({ worker }) => {
      worker.start({ onUnhandledRequest: "bypass" }).then(() => setReady(true));
    });
  }, []);

  if (!ready) return null;
  return <>{children}</>;
}
```

## Environment validation (`env.ts`)

```typescript
import { createEnv } from "@t3-oss/env-nextjs";
import { z } from "zod";

export const env = createEnv({
  server: {
    API_BASE_URL: z.url(),
    AUTH_BASE_URL: z.url(),
    CHATTING_BASE_URL: z.url(),
    CHATTING_SOCKET_URL: z.url(),
    COOKIE_SECURE: z
      .string()
      .optional()
      .transform((v) => v === "true"),
    LOG_LEVEL: z.enum(["info", "debug", "error"]).default("info"),
  },
  client: {
    NEXT_PUBLIC_CHATTING_SOCKET_URL: z.url(),
    NEXT_PUBLIC_MSW_ENABLED: z
      .string()
      .optional()
      .transform((v) => v === "true"),
    NEXT_PUBLIC_URL: z.url().default("http://localhost:3000"),
    NEXT_PUBLIC_APP_MODE: z.enum(["development", "production"]),
  },
  runtimeEnv: {
    API_BASE_URL: process.env.API_BASE_URL,
    AUTH_BASE_URL: process.env.AUTH_BASE_URL,
    CHATTING_BASE_URL: process.env.CHATTING_BASE_URL,
    CHATTING_SOCKET_URL: process.env.CHATTING_SOCKET_URL,
    COOKIE_SECURE: process.env.COOKIE_SECURE,
    LOG_LEVEL: process.env.LOG_LEVEL,
    NEXT_PUBLIC_CHATTING_SOCKET_URL: process.env.NEXT_PUBLIC_CHATTING_SOCKET_URL,
    NEXT_PUBLIC_MSW_ENABLED: process.env.NEXT_PUBLIC_MSW_ENABLED,
    NEXT_PUBLIC_URL: process.env.NEXT_PUBLIC_URL,
    NEXT_PUBLIC_APP_MODE: process.env.NEXT_PUBLIC_APP_MODE,
  },
});
```

## Middleware (`proxy.ts`)

```typescript
import createMiddleware from "next-intl/middleware";
import { NextResponse, type NextRequest } from "next/server";
import { routing } from "~/i18n/routing";
import { COOKIE_KEYS } from "~/lib/auth/core/config";
import { isTokenExpired } from "~/lib/auth/core/jwt";
import { refreshTokens } from "~/lib/auth/refresh";

const intlMiddleware = createMiddleware(routing);

const PUBLIC_PATHS = ["/auth/login", "/auth/register", "/auth/reset-password"];

function isPublicPath(pathname: string): boolean {
  return PUBLIC_PATHS.some((p) => pathname.startsWith(p));
}

export default async function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;

  // Skip API routes and static files
  if (pathname.startsWith("/api/") || pathname.startsWith("/_next/")) {
    return NextResponse.next();
  }

  const accessToken = request.cookies.get(COOKIE_KEYS.ACCESS_TOKEN)?.value;
  const refreshToken = request.cookies.get(COOKIE_KEYS.REFRESH_TOKEN)?.value;

  // Public paths — allow through
  if (isPublicPath(pathname)) {
    // If already logged in, redirect to app
    if (accessToken && !isTokenExpired(accessToken)) {
      return NextResponse.redirect(new URL("/workspaces", request.url));
    }
    return intlMiddleware(request);
  }

  // Protected paths — require auth
  if (!accessToken && !refreshToken) {
    return NextResponse.redirect(new URL("/auth/login", request.url));
  }

  // Access token expired but refresh exists — try refresh
  if ((!accessToken || isTokenExpired(accessToken)) && refreshToken) {
    try {
      const newTokens = await refreshTokens(refreshToken);
      const response = intlMiddleware(request);
      response.cookies.set(COOKIE_KEYS.ACCESS_TOKEN, newTokens.accessToken);
      response.cookies.set(COOKIE_KEYS.REFRESH_TOKEN, newTokens.refreshToken);
      return response;
    } catch {
      // Refresh failed — clear and redirect to login
      const response = NextResponse.redirect(new URL("/auth/login", request.url));
      response.cookies.delete(COOKIE_KEYS.ACCESS_TOKEN);
      response.cookies.delete(COOKIE_KEYS.REFRESH_TOKEN);
      return response;
    }
  }

  return intlMiddleware(request);
}

export const config = {
  matcher: ["/((?!_next|api|.*\\..*).*)"],
};
```
