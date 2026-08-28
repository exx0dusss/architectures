# Workspace Management

Multi-tenant workspace isolation. All data is scoped to the active workspace. Identical to Next.js except for routing hooks.

## Directory structure

```
src/lib/workspace/
├── hooks.ts           # useWorkspace, useWorkspaceId
├── routes.ts          # Route helpers
├── navigation.ts      # Sidebar link definitions per module
├── storage.ts         # Cookie-based workspace ID persistence
└── utils.ts           # getWorkspaceBasePath
```

## `hooks.ts`

```typescript
import { useParams } from "@tanstack/react-router";
import { useQueryClient } from "@tanstack/react-query";
import { workspaceStorage } from "./storage";

export function useWorkspaceId(): string {
  const { workspaceId } = useParams({ strict: false });
  return workspaceId as string;
}

export function useSetActiveWorkspace() {
  const queryClient = useQueryClient();

  return (workspaceId: string) => {
    workspaceStorage.set(workspaceId);
    queryClient.invalidateQueries();
  };
}
```

**Key difference from Next.js:** Uses `useParams` from `@tanstack/react-router` instead of `next/navigation`.

All other workspace files (storage, navigation, routes, utils) are identical to the Next.js version.
