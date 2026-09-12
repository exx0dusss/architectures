# Testing Infrastructure

## Setup

| Tool | Purpose |
|------|---------|
| Vitest | Unit tests |
| Playwright | E2E tests |
| MSW | API mocking |
| Custom RTL render | Provider-wrapped rendering |

## Custom render (`testing/render.tsx`)

```typescript
import { render, type RenderOptions } from "@testing-library/react";
import { QueryClientProvider } from "@tanstack/react-query";
import { NuqsTestingAdapter } from "nuqs/adapters/testing";
import { createTestQueryClient } from "./query-client";
import type { ReactElement, ReactNode } from "react";

function AllProviders({ children }: { children: ReactNode }) {
  const queryClient = createTestQueryClient();
  return (
    <QueryClientProvider client={queryClient}>
      <NuqsTestingAdapter>
        {children}
      </NuqsTestingAdapter>
    </QueryClientProvider>
  );
}

export function renderWithProviders(
  ui: ReactElement,
  options?: Omit<RenderOptions, "wrapper">,
) {
  return render(ui, { wrapper: AllProviders, ...options });
}
```

## Test query client (`testing/query-client.ts`)

```typescript
import { QueryClient } from "@tanstack/react-query";

export function createTestQueryClient() {
  return new QueryClient({
    defaultOptions: {
      queries: { retry: false, gcTime: 0 },
      mutations: { retry: false },
    },
  });
}
```

## MSW mock handlers

Mirror the `services/` structure:

```
src/mocks/
├── handlers/
│   ├── main/
│   │   ├── flows.ts
│   │   ├── channels.ts
│   │   └── ...
│   ├── auth/
│   │   └── authentication.ts
│   └── chatting/
│       └── chats.ts
├── data/                # Mock data factories
├── browser.ts           # Browser worker setup
└── server.ts            # Server worker setup (for tests)
```

Example handler (identical to Next.js):

```typescript
import { http, HttpResponse } from "msw";

const mockFlows = [
  { id: "1", name: "Test Flow", status: "ACTIVE", createdAt: "2024-01-01T00:00:00" },
];

export const flowHandlers = [
  http.get("*/api/v1/flows/getAll/workspace/:workspaceId", () => {
    return HttpResponse.json({
      content: mockFlows,
      pageNumber: 0,
      pageSize: 25,
      totalElements: mockFlows.length,
      totalPages: 1,
    });
  }),
];
```

## Scripts

```bash
pnpm test              # Run unit tests
pnpm test:coverage     # Coverage report
pnpm test:e2e          # E2E tests with Playwright
pnpm test:e2e:ui       # Interactive E2E UI
```
