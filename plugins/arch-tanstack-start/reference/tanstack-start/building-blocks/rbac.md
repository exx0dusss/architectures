# RBAC (Role-Based Access Control)

Role hierarchy + flat permission strings. Framework-agnostic — identical to Next.js architecture.

## Directory structure

```
src/lib/rbac/
├── permissions.ts         # Permission constants (flat strings)
├── roles.ts               # Role enum, hierarchy, helpers
├── types.ts               # Shared types
├── validate.ts            # Pure validation functions (no server/client deps)
├── server/
│   └── server.ts          # requirePermission, requireRole
└── client/
    └── client.ts          # useAccess() hook, <Can> component
```

See [auth-rbac.md](../auth-rbac.md) for full implementation details. The RBAC code is identical to the Next.js version — only the server-side enforcement differs:

```typescript
// src/lib/rbac/server/server.ts
import { requireSession } from "~/lib/auth/server/session";
import { hasPermission } from "../validate";
import { ServerApiError } from "~/services/_shared/errors";

export function requirePermission(permission: Permission, workspaceId: string): void {
  const session = requireSession();
  if (!hasPermission(session, permission, workspaceId)) {
    throw new ServerApiError("Forbidden", 403, "FORBIDDEN");
  }
}
```

**Key difference from Next.js:** Uses `throw new ServerApiError()` instead of `forbidden()` from `next/navigation`.
