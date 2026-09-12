# Providers & Configuration

## Router setup (`src/router.tsx`)

```typescript
import { createRouter } from "@tanstack/react-router";
import { QueryClient } from "@tanstack/react-query";
import { setupRouterSsrQueryIntegration } from "@tanstack/react-router-ssr-query";
import { routeTree } from "./routeTree.gen";

export function getContext() {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: {
        staleTime: 60_000,
        gcTime: 5 * 60_000,
        refetchOnWindowFocus: false,
        refetchOnReconnect: true,
        retry: (count, error) => {
          if (error.status >= 400 && error.status < 500) return false;
          return count < 2;
        },
      },
      mutations: {
        retry: false,
      },
    },
  });

  return { queryClient };
}

export function createAppRouter() {
  const { queryClient } = getContext();

  const router = createRouter({
    routeTree,
    context: { queryClient },
    defaultPreload: "intent",
  });

  setupRouterSsrQueryIntegration({ router, queryClient });

  return router;
}
```

**Key differences from Next.js:**
- No `QueryClientProvider` wrapper needed — router integration handles it
- No `HydrationBoundary` wrapper needed — SSR query integration handles it
- No server/browser singleton pattern — the router manages query client lifecycle

## Root layout (`src/routes/__root.tsx`)

```typescript
import { createRootRouteWithContext, Outlet, ScrollRestoration } from "@tanstack/react-router";
import { Meta, Scripts } from "@tanstack/react-start";
import type { QueryClient } from "@tanstack/react-query";
import { ThemeProvider } from "~/components/theme-provider";
import { NuqsAdapter } from "nuqs/adapters/react";
import { Toaster } from "~/components/ui/toast";

interface RouterContext {
  queryClient: QueryClient;
}

export const Route = createRootRouteWithContext<RouterContext>()({
  component: RootComponent,
  head: () => ({
    meta: [
      { charSet: "utf-8" },
      { name: "viewport", content: "width=device-width, initial-scale=1" },
    ],
    links: [
      { rel: "stylesheet", href: "/src/styles/styles.css" },
    ],
  }),
});

function RootComponent() {
  return (
    <html lang="en" suppressHydrationWarning>
      <head>
        <Meta />
      </head>
      <body>
        <ThemeProvider attribute="class" defaultTheme="system" enableSystem>
          <NuqsAdapter>
            <Toaster />
            <Outlet />
          </NuqsAdapter>
        </ThemeProvider>
        <ScrollRestoration />
        <Scripts />
      </body>
    </html>
  );
}
```

## Vite config (`vite.config.ts`)

```typescript
import { defineConfig } from "vite";
import { tanstackStart } from "@tanstack/react-start/vite";
import tailwindcss from "@tailwindcss/vite";
import viteTsConfigPaths from "vite-tsconfig-paths";

export default defineConfig({
  plugins: [
    tanstackStart({
      react: {
        babel: {
          plugins: [["babel-plugin-react-compiler"]],
        },
      },
    }),
    tailwindcss(),
    viteTsConfigPaths(),
  ],
});
```

## Environment validation (`src/env.ts`)

```typescript
import { createEnv } from "@t3-oss/env-core";
import { z } from "zod";

export const env = createEnv({
  server: {
    API_BASE_URL: z.url(),
    AUTH_BASE_URL: z.url(),
    CHATTING_BASE_URL: z.url(),
    COOKIE_SECURE: z
      .string()
      .optional()
      .transform((v) => v === "true"),
    LOG_LEVEL: z.enum(["info", "debug", "error"]).default("info"),
  },
  clientPrefix: "VITE_",
  client: {
    VITE_APP_TITLE: z.string().optional(),
    VITE_MSW_ENABLED: z
      .string()
      .optional()
      .transform((v) => v === "true"),
  },
  runtimeEnv: {
    API_BASE_URL: process.env.API_BASE_URL,
    AUTH_BASE_URL: process.env.AUTH_BASE_URL,
    CHATTING_BASE_URL: process.env.CHATTING_BASE_URL,
    COOKIE_SECURE: process.env.COOKIE_SECURE,
    LOG_LEVEL: process.env.LOG_LEVEL,
    VITE_APP_TITLE: import.meta.env.VITE_APP_TITLE,
    VITE_MSW_ENABLED: import.meta.env.VITE_MSW_ENABLED,
  },
});
```

## Theme provider

```typescript
// src/components/theme-provider.tsx
import { ThemeProvider as NextThemesProvider } from "next-themes";
import type { ComponentProps } from "react";

export function ThemeProvider(props: ComponentProps<typeof NextThemesProvider>) {
  return <NextThemesProvider {...props} />;
}
```

`next-themes` works with any React framework despite the name.
