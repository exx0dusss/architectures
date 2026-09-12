# Fetch Client Infrastructure

Server-side HTTP client for external backend integration. All requests go through server functions — no client-side proxy needed.

## Directory structure

```
src/services/_shared/fetch-client/
├── api-fetch.ts       # Server fetch + module factory
└── constants.ts       # Rate limit config
```

## `constants.ts`

```typescript
export const API_RATE_LIMIT = {
  maxRetries: 3,
  backoffMs: 1000,
};
```

## `api-fetch.ts`

Single fetch module. Used inside server functions only.

```typescript
import { getWebRequest } from "@tanstack/react-start/server";
import { env } from "~/env";
import { ServerApiError } from "~/services/_shared/errors";
import { logger } from "~/lib/logger";
import { buildQueryString } from "~/lib/utils/query";
import type { ZodSchema } from "zod";

// ── Types ───────────────────────────────────────────────────────

interface FetchOptions extends Omit<RequestInit, "body"> {
  baseUrl?: string;
  skipAuth?: boolean;
  query?: Record<string, unknown>;
  schema?: ZodSchema;
  body?: BodyInit | null;
}

interface RequestOptions {
  headers?: Record<string, string>;
  query?: Record<string, unknown>;
  schema?: ZodSchema;
}

// ── Cookie parser ───────────────────────────────────────────────

function parseCookie(cookieHeader: string, name: string): string | undefined {
  const match = cookieHeader.match(new RegExp(`(?:^|;\\s*)${name}=([^;]*)`));
  return match ? decodeURIComponent(match[1]) : undefined;
}

// ── Core fetch ──────────────────────────────────────────────────

async function serverFetch<T>(
  endpoint: string,
  init: FetchOptions = {},
): Promise<T> {
  const baseUrl = init.baseUrl ?? env.API_BASE_URL;
  const headers = new Headers(init.headers);

  // Auto-attach auth from the incoming request's cookies
  if (!init.skipAuth) {
    try {
      const request = getWebRequest();
      const cookieHeader = request.headers.get("cookie") ?? "";
      const accessToken = parseCookie(cookieHeader, "access_token");
      if (accessToken) {
        headers.set("Authorization", `Bearer ${accessToken}`);
      }
    } catch {
      // getWebRequest() may fail outside of request context (e.g., in tests)
    }
  }

  const queryString = init.query ? buildQueryString(init.query) : "";
  const fullUrl = `${baseUrl}${endpoint}${queryString}`;

  const start = performance.now();

  const response = await fetch(fullUrl, {
    ...init,
    headers,
  });

  const duration = Math.round(performance.now() - start);

  if (!response.ok) {
    const errorData = await response.json().catch(() => ({}));
    logger.error({
      url: fullUrl,
      status: response.status,
      duration,
      error: errorData,
    }, "API request failed");

    throw new ServerApiError(
      errorData.message ?? "Request failed",
      response.status,
      errorData.code,
      errorData.fieldErrors,
      errorData,
    );
  }

  logger.debug({ url: fullUrl, status: response.status, duration }, "API request success");

  const data = await response.json();

  if (init.schema) {
    return init.schema.parse(data) as T;
  }

  return data as T;
}

// ── Module factory ──────────────────────────────────────────────

function createServerModule(baseUrl: string, prefix: string) {
  const buildUrl = (path: string) => `${prefix}${path}`;

  return {
    get: <T>(path: string, opts?: RequestOptions) =>
      serverFetch<T>(buildUrl(path), {
        method: "GET",
        baseUrl,
        ...opts,
      }),

    post: <T>(path: string, data?: unknown, opts?: RequestOptions) =>
      serverFetch<T>(buildUrl(path), {
        method: "POST",
        baseUrl,
        body: data ? JSON.stringify(data) : undefined,
        headers: { "Content-Type": "application/json", ...opts?.headers },
        ...opts,
      }),

    put: <T>(path: string, data?: unknown, opts?: RequestOptions) =>
      serverFetch<T>(buildUrl(path), {
        method: "PUT",
        baseUrl,
        body: data ? JSON.stringify(data) : undefined,
        headers: { "Content-Type": "application/json", ...opts?.headers },
        ...opts,
      }),

    patch: <T>(path: string, data?: unknown, opts?: RequestOptions) =>
      serverFetch<T>(buildUrl(path), {
        method: "PATCH",
        baseUrl,
        body: data ? JSON.stringify(data) : undefined,
        headers: { "Content-Type": "application/json", ...opts?.headers },
        ...opts,
      }),

    delete: <T>(path: string, opts?: RequestOptions) =>
      serverFetch<T>(buildUrl(path), {
        method: "DELETE",
        baseUrl,
        ...opts,
      }),

    deleteWithBody: <T>(path: string, data?: unknown, opts?: RequestOptions) =>
      serverFetch<T>(buildUrl(path), {
        method: "DELETE",
        baseUrl,
        body: data ? JSON.stringify(data) : undefined,
        headers: { "Content-Type": "application/json", ...opts?.headers },
        ...opts,
      }),
  };
}

// ── Configure per backend service ───────────────────────────────

export const apiFetch = {
  main: {
    v1: createServerModule(env.API_BASE_URL, "/api/v1"),
  },
  auth: {
    api: createServerModule(env.AUTH_BASE_URL, "/api"),
  },
  chatting: {
    v1: createServerModule(env.CHATTING_BASE_URL, "/api/v1"),
  },
};
```

## Adding a new backend service

1. Add the URL to `env.ts` (server var)
2. Add a module to `apiFetch` in `api-fetch.ts`

That's it. No `apiClient`, no proxy route mapping, no `apiServer` — just one module.

## Key differences from Next.js

| Next.js | TanStack Start |
|---------|---------------|
| `apiClient` + `apiServer` (two modules) | `apiFetch` (one module) |
| `cookies()` from `next/headers` | `getWebRequest()` from `@tanstack/react-start/server` |
| `serverFetch` with `cache: "no-store"` | Plain `fetch()` (no Next.js cache to disable) |
| 4 files (api-client, api-server, server-fetch, constants) | 2 files (api-fetch, constants) |
