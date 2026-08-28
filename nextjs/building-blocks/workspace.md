# Workspace Management

Multi-tenant workspace isolation. All data is scoped to the active workspace.

## Directory structure

```
src/lib/workspace/
├── hooks.ts           # useWorkspace, useWorkspaceId, useSetActiveWorkspace
├── routes.ts          # Route helpers (isAuthRoute, workspacePath, etc.)
├── navigation.ts      # Sidebar link definitions per module
├── storage.ts         # Cookie-based workspace ID persistence
└── utils.ts           # getWorkspaceBasePath
```

## `storage.ts` (client-only)

```typescript
"use client";

const COOKIE_NAME = "active_workspace_id";

export const workspaceStorage = {
  get(): string | null {
    if (typeof document === "undefined") return null;
    const match = document.cookie.match(new RegExp(`${COOKIE_NAME}=([^;]+)`));
    return match ? match[1] : null;
  },

  set(workspaceId: string): void {
    document.cookie = `${COOKIE_NAME}=${workspaceId};path=/;max-age=${60 * 60 * 24 * 365}`;
  },

  remove(): void {
    document.cookie = `${COOKIE_NAME}=;path=/;max-age=0`;
  },

  subscribe(listener: (workspaceId: string | null) => void): () => void {
    const interval = setInterval(() => {
      listener(workspaceStorage.get());
    }, 1000);
    return () => clearInterval(interval);
  },
};
```

## `routes.ts`

```typescript
export const workspaceRoutes = {
  picker: "/workspaces",

  isAuthRoute(pathname: string): boolean {
    return pathname.startsWith("/auth/");
  },

  isWorkspacePickerRoute(pathname: string): boolean {
    return pathname === "/workspaces" || pathname === "/workspaces/";
  },

  shouldResolveWorkspace(pathname: string): boolean {
    return !this.isAuthRoute(pathname) && !this.isWorkspacePickerRoute(pathname);
  },

  workspacePath(workspaceId: string, subPath = ""): string {
    return `/workspace/${workspaceId}${subPath}`;
  },
};
```

## `hooks.ts` (client-only)

```typescript
"use client";

import { useParams } from "next/navigation";
import { useQueryClient } from "@tanstack/react-query";
import { workspaceStorage } from "./storage";

export function useWorkspaceId(): string {
  const params = useParams();
  return params.workspaceId as string;
}

export function useSetActiveWorkspace() {
  const queryClient = useQueryClient();

  return (workspaceId: string) => {
    workspaceStorage.set(workspaceId);
    // Invalidate all queries when switching workspace
    queryClient.invalidateQueries();
  };
}
```

## `navigation.ts` — Sidebar links

```typescript
import type { Permission } from "~/lib/rbac/permissions";
import type { UserRole } from "~/lib/rbac/roles";
import type { LucideIcon } from "lucide-react";

export interface SidebarLink {
  title: string;
  titleKey: string;     // i18n key
  path: string;         // Relative to workspace base
  icon: LucideIcon;
  permission?: Permission;  // Required permission to see this link
  role?: UserRole;          // Required minimum role
}

export interface SidebarConfig {
  links: SidebarLink[];
  footerLinks: SidebarLink[];
}

// Define per module
export const buyingSidebarPaths: SidebarConfig = {
  links: [
    { title: "Flows",    titleKey: "sidebar.flows",    path: "/buying/flows",    icon: WorkflowIcon,  permission: "flows_view" },
    { title: "Channels", titleKey: "sidebar.channels", path: "/buying/channels", icon: RadioIcon,     permission: "channels_view" },
    { title: "Bots",     titleKey: "sidebar.bots",     path: "/buying/bots",     icon: BotIcon,       permission: "bots_view" },
    // ... more links
  ],
  footerLinks: [
    { title: "Statistics", titleKey: "sidebar.stats", path: "/buying/statistics", icon: ChartIcon },
  ],
};

export const chattingSidebarPaths: SidebarConfig = {
  links: [
    { title: "Accounts", titleKey: "sidebar.accounts", path: "/chatting/accounts", icon: UserIcon, permission: "chat-accounts_view" },
    // ... more links
  ],
  footerLinks: [],
};

// Convert relative paths to full workspace URLs
export function toWorkspaceUrls(config: SidebarConfig, workspaceId: string): SidebarConfig {
  const map = (link: SidebarLink) => ({
    ...link,
    path: `/workspace/${workspaceId}${link.path}`,
  });
  return {
    links: config.links.map(map),
    footerLinks: config.footerLinks.map(map),
  };
}
```

## `utils.ts`

```typescript
export function getWorkspaceBasePath(workspaceId: string): string {
  return `/workspace/${workspaceId}`;
}
```

## How workspace scoping works

Every API call includes workspace context:

```typescript
// Path parameter
apiServer.main.v1.get(`/flows/getAll/workspace/${workspaceId}`, { ... });

// Header
headers: { "X-Workspace-Id": workspaceId }
```

The backend uses both to scope all data. Switching workspaces invalidates all TanStack Query caches.
