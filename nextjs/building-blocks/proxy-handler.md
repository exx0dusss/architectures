# API Route Proxy

Single dynamic route that forwards all client requests to backend services. This is how the client communicates with backends without knowing their URLs.

## API route (`app/api/[service]/[...path]/route.ts`)

```typescript
import { NextRequest } from "next/server";
import { env } from "~/env";
import { handleProxy } from "~/services/_shared/proxy-handler";

const SERVICE_URLS: Record<string, string> = {
  main: env.API_BASE_URL,
  auth: env.AUTH_BASE_URL,
  chatting: env.CHATTING_BASE_URL,
  chattingSocket: env.CHATTING_SOCKET_URL,
  // Add new services here
};

async function handler(
  request: NextRequest,
  { params }: { params: Promise<{ service: string; path: string[] }> },
) {
  const { service, path } = await params;
  const baseUrl = SERVICE_URLS[service];

  if (!baseUrl) {
    return Response.json(
      { message: `Unknown service: ${service}`, code: "UNKNOWN_SERVICE" },
      { status: 404 },
    );
  }

  return handleProxy(request, path, { baseUrl });
}

export const GET = handler;
export const POST = handler;
export const PUT = handler;
export const PATCH = handler;
export const DELETE = handler;
```

## Proxy handler (`services/_shared/proxy-handler.ts`)

```typescript
import { NextRequest, NextResponse } from "next/server";
import { cookies } from "next/headers";
import { COOKIE_KEYS } from "~/lib/auth/core/config";
import { logger } from "~/lib/logger";

// Headers that should NOT be forwarded to backends
const FILTERED_HEADERS = new Set([
  "host",
  "connection",
  "cookie",
  "transfer-encoding",
  "content-length",
]);

interface ProxyConfig {
  baseUrl: string;
}

export async function handleProxy(
  request: NextRequest,
  pathSegments: string[],
  config: ProxyConfig,
): Promise<NextResponse> {
  const targetPath = `/${pathSegments.join("/")}`;
  const queryString = request.nextUrl.search;
  const targetUrl = `${config.baseUrl}${targetPath}${queryString}`;

  // Build forwarded headers
  const headers = new Headers();
  for (const [key, value] of request.headers.entries()) {
    if (!FILTERED_HEADERS.has(key.toLowerCase())) {
      headers.set(key, value);
    }
  }

  // Attach auth token from cookies
  const cookieStore = await cookies();
  const accessToken = cookieStore.get(COOKIE_KEYS.ACCESS_TOKEN)?.value;
  if (accessToken) {
    headers.set("Authorization", `Bearer ${accessToken}`);
  }

  // Forward body (handle FormData and JSON)
  let body: BodyInit | null = null;
  if (request.method !== "GET" && request.method !== "HEAD") {
    const contentType = request.headers.get("content-type") ?? "";
    if (contentType.includes("multipart/form-data")) {
      body = await request.formData();
    } else {
      body = await request.text();
    }
  }

  try {
    const response = await fetch(targetUrl, {
      method: request.method,
      headers,
      body,
      cache: "no-store",
    });

    // Forward response
    const responseHeaders = new Headers();
    for (const [key, value] of response.headers.entries()) {
      if (key.toLowerCase() !== "transfer-encoding") {
        responseHeaders.set(key, value);
      }
    }

    const responseBody = await response.arrayBuffer();

    return new NextResponse(responseBody, {
      status: response.status,
      statusText: response.statusText,
      headers: responseHeaders,
    });
  } catch (error) {
    logger.error({ targetUrl, error }, "Proxy request failed");
    return NextResponse.json(
      { message: "Proxy error", code: "PROXY_ERROR" },
      { status: 502 },
    );
  }
}
```

## How it works

```
Browser: GET /api/main/api/v1/flows?page=0
  → Matches: app/api/[service="main"]/[...path="api/v1/flows"]/route.ts
  → SERVICE_URLS["main"] = "https://backend.example.com"
  → handleProxy → GET https://backend.example.com/api/v1/flows?page=0
  → Attaches Bearer token from cookies
  → Returns backend response to browser
```
