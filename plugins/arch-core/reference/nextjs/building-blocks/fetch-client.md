# Fetch Client Infrastructure

Multi-layer HTTP client for external backend integration. Client-side requests proxy through Next.js API routes (hiding backend URLs), server-side requests call backends directly.

## Directory structure

```
src/services/_shared/fetch-client/
├── api-client.ts      # Client-side fetch (through proxy)
├── api-server.ts      # Server-side fetch (direct)
├── server-fetch.ts    # Low-level server fetcher
└── constants.ts       # Rate limit config
```

## `constants.ts`

```typescript
export const API_RATE_LIMIT = {
  maxRetries: 3,
  backoffMs: 1000,
};
```

## `server-fetch.ts` (server-only)

The foundation. Both the proxy handler and `apiServer` use this.

```typescript
import "server-only";
import { cookies } from "next/headers";
import { env } from "~/env";
import { COOKIE_KEYS } from "~/lib/auth/core/config";
import { ServerApiError } from "~/services/_shared/errors";
import { logger } from "~/lib/logger";
import { buildQueryString } from "~/lib/utils/query";

interface FetchOptions extends RequestInit {
  baseUrl?: string;
  skipAuth?: boolean;
  query?: Record<string, unknown>;
  schema?: ZodSchema;
}

export async function serverFetch<T>(
  endpoint: string,
  init: FetchOptions = {},
): Promise<T> {
  const baseUrl = init.baseUrl ?? env.API_BASE_URL;
  const headers = new Headers(init.headers);

  // Auto-attach auth from cookies
  if (!init.skipAuth) {
    const cookieStore = await cookies();
    const accessToken = cookieStore.get(COOKIE_KEYS.ACCESS_TOKEN)?.value;
    if (accessToken) {
      headers.set("Authorization", `Bearer ${accessToken}`);
    }
  }

  const queryString = init.query ? buildQueryString(init.query) : "";
  const fullUrl = `${baseUrl}${endpoint}${queryString}`;

  const start = performance.now();

  const response = await fetch(fullUrl, {
    ...init,
    headers,
    cache: init.cache ?? "no-store", // CRITICAL: never cache
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

  // Validate response with Zod if schema provided
  if (init.schema) {
    return init.schema.parse(data) as T;
  }

  return data as T;
}
```

## `api-server.ts` (server-only)

Server module factory. Used in `queries.ts` and `actions.ts`.

```typescript
import "server-only";
import { serverFetch } from "./server-fetch";
import { env } from "~/env";
import type { ZodSchema } from "zod";

interface RequestOptions {
  headers?: Record<string, string>;
  query?: Record<string, unknown>;
  schema?: ZodSchema;
}

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

// Configure per backend service
export const apiServer = {
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

## `api-client.ts` (client-side)

Client module factory. Used in `query-options.ts`. Routes through the Next.js proxy.

```typescript
import type { ZodSchema } from "zod";
import { refreshWithLock } from "~/lib/auth/client/refresh-lock";
import { buildQueryString } from "~/lib/utils/query";
import { ClientApiError } from "~/services/_shared/errors";

interface RequestOptions {
  headers?: Record<string, string>;
  query?: Record<string, unknown>;
  schema?: ZodSchema;
}

async function baseFetch<T>(
  url: string,
  init: RequestInit & { schema?: ZodSchema } = {},
): Promise<T> {
  const response = await fetch(url, {
    ...init,
    credentials: "include", // Send cookies through proxy
  });

  // Auto-refresh on 401
  if (response.status === 401) {
    const refreshed = await refreshWithLock();
    if (refreshed) {
      // Retry original request
      const retryResponse = await fetch(url, { ...init, credentials: "include" });
      if (!retryResponse.ok) {
        const errorData = await retryResponse.json().catch(() => ({}));
        throw new ClientApiError(errorData.message, retryResponse.status, errorData.code);
      }
      const data = await retryResponse.json();
      return init.schema ? (init.schema.parse(data) as T) : (data as T);
    }
    // Refresh failed — redirect to login
    window.location.href = "/auth/login";
    throw new ClientApiError("Session expired", 401, "SESSION_EXPIRED");
  }

  if (!response.ok) {
    const errorData = await response.json().catch(() => ({}));
    throw new ClientApiError(
      errorData.message ?? "Request failed",
      response.status,
      errorData.code,
      errorData.fieldErrors,
    );
  }

  const data = await response.json();
  return init.schema ? (init.schema.parse(data) as T) : (data as T);
}

function createClientModule(service: string, prefix: string) {
  const buildUrl = (path: string, query?: Record<string, unknown>) => {
    const qs = query ? buildQueryString(query) : "";
    return `/api/${service}${prefix}${path}${qs}`;
  };

  return {
    get: <T>(path: string, opts?: RequestOptions) =>
      baseFetch<T>(buildUrl(path, opts?.query), {
        method: "GET",
        headers: opts?.headers,
        schema: opts?.schema,
      }),

    post: <T>(path: string, data?: unknown, opts?: RequestOptions) =>
      baseFetch<T>(buildUrl(path, opts?.query), {
        method: "POST",
        body: data instanceof FormData ? data : JSON.stringify(data),
        headers: data instanceof FormData
          ? opts?.headers
          : { "Content-Type": "application/json", ...opts?.headers },
        schema: opts?.schema,
      }),

    put: <T>(path: string, data?: unknown, opts?: RequestOptions) =>
      baseFetch<T>(buildUrl(path, opts?.query), {
        method: "PUT",
        body: JSON.stringify(data),
        headers: { "Content-Type": "application/json", ...opts?.headers },
        schema: opts?.schema,
      }),

    patch: <T>(path: string, data?: unknown, opts?: RequestOptions) =>
      baseFetch<T>(buildUrl(path, opts?.query), {
        method: "PATCH",
        body: JSON.stringify(data),
        headers: { "Content-Type": "application/json", ...opts?.headers },
        schema: opts?.schema,
      }),

    delete: <T>(path: string, opts?: RequestOptions) =>
      baseFetch<T>(buildUrl(path, opts?.query), {
        method: "DELETE",
        headers: opts?.headers,
        schema: opts?.schema,
      }),
  };
}

// Configure per backend service — maps to /api/{service}/...
export const apiClient = {
  main: {
    v1: createClientModule("main", "/api/v1"),
  },
  auth: {
    api: createClientModule("auth", "/api"),
  },
  chatting: {
    v1: createClientModule("chatting", "/api/v1"),
  },
};
```

## Adding a new backend service

1. Add the URL to `env.ts` (server var)
2. Add a module to `apiServer` in `api-server.ts`
3. Add a module to `apiClient` in `api-client.ts`
4. Add the mapping in the API route proxy (`SERVICE_URLS`)
