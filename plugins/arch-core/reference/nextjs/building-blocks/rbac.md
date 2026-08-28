# RBAC (Role-Based Access Control)

Role hierarchy + flat permission strings. Works on both server and client.

## Directory structure

```
src/lib/rbac/
├── permissions.ts         # Permission constants (flat strings)
├── roles.ts               # Role enum, hierarchy, helpers
├── types.ts               # Shared types
├── validate.ts            # Pure validation functions (no server/client deps)
├── server/
│   ├── server.ts          # requirePermission, requireRole (async, reads session)
│   └── utils.ts           # Link filtering helpers
└── client/
    ├── client.ts           # useAccess() hook
    └── utils.ts            # Link filtering helpers
```

## `roles.ts`

```typescript
export const ROLES = [
  "OWNER",
  "ADMIN",
  "TEAM_LEAD_MANAGER",
  "TEAM_LEAD",
  "MANAGER",
  "CHAT_ADMIN",
  "BUYER",
  "VIEWER",
  "USER",
] as const;

export type UserRole = (typeof ROLES)[number];

export const roleHierarchy: Record<UserRole, number> = {
  OWNER: 6,
  ADMIN: 5,
  TEAM_LEAD_MANAGER: 4,
  TEAM_LEAD: 4,
  MANAGER: 3,
  CHAT_ADMIN: 3,
  BUYER: 2,
  VIEWER: 1,
  USER: 0,
};

export function canManageRole(actorRole: UserRole, targetRole: UserRole): boolean {
  return roleHierarchy[actorRole] > roleHierarchy[targetRole];
}

export function getRoleOptionsForActor(actorRole: UserRole): UserRole[] {
  return ROLES.filter((role) => roleHierarchy[role] < roleHierarchy[actorRole]);
}
```

## `permissions.ts`

```typescript
// Flat permission strings organized by module and resource
// Customize this tree for your app's resources

export const permissions = {
  buying: {
    flows:    { view: "flows_view",    create: "flows_create",    edit: "flows_edit",    delete: "flows_delete" },
    channels: { view: "channels_view", create: "channels_create", edit: "channels_edit", delete: "channels_delete" },
    bots:     { view: "bots_view",     create: "bots_create",     edit: "bots_edit",     delete: "bots_delete" },
    domains:  { view: "domains_view",  create: "domains_create",  edit: "domains_edit",  delete: "domains_delete" },
    landings: { view: "landings_view", create: "landings_create", edit: "landings_edit", delete: "landings_delete" },
    accounts: { view: "accounts_view", create: "accounts_create", edit: "accounts_edit", delete: "accounts_delete" },
    proxies:  { view: "proxies_view",  create: "proxies_create",  edit: "proxies_edit",  delete: "proxies_delete" },
    users:    { view: "users_view",    create: "users_create",    edit: "users_edit",    delete: "users_delete" },
  },
  chatting: {
    bots:     { view: "chat-bots_view",    create: "chat-bots_create",    edit: "chat-bots_edit" },
    funnels:  { view: "funnels_view",      create: "funnels_create",      edit: "funnels_edit" },
    accounts: { view: "chat-accounts_view", create: "chat-accounts_create" },
  },
} as const;

// Extract all leaf permission strings as a union type
type ExtractPermissions<T> = T extends Record<string, infer V>
  ? V extends string
    ? V
    : ExtractPermissions<V>
  : never;

export type Permission = ExtractPermissions<typeof permissions>;
```

## `types.ts`

```typescript
import type { UserRole } from "./roles";
import type { Permission } from "./permissions";

export type Module = "buying" | "chatting"; // Add your modules

export interface AccessCheckOptions {
  permission?: Permission;
  anyPermission?: Permission[];
  allPermissions?: Permission[];
  role?: UserRole;
  module?: Module;
}
```

## `validate.ts` (pure — no server or client deps)

```typescript
import { roleHierarchy, type UserRole } from "./roles";
import type { UserSession } from "~/lib/auth/core/types";
import type { Module, Permission } from "./types";

export function hasPermission(
  user: UserSession,
  permission: Permission,
  workspaceId: string,
): boolean {
  const workspacePerms = user.workspacePermissions[workspaceId];
  if (!workspacePerms) return false;
  // Permission IDs are stored as numbers in the JWT
  // Your mapping logic depends on your backend's permission model
  return workspacePerms.includes(permissionToId(permission));
}

export function hasAnyPermission(
  user: UserSession,
  perms: Permission[],
  workspaceId: string,
): boolean {
  return perms.some((p) => hasPermission(user, p, workspaceId));
}

export function hasAllPermissions(
  user: UserSession,
  perms: Permission[],
  workspaceId: string,
): boolean {
  return perms.every((p) => hasPermission(user, p, workspaceId));
}

export function canAccessModule(
  user: UserSession,
  module: Module,
  workspaceId: string,
): boolean {
  // Check if user has ANY permission in the module
  const modulePerms = permissions[module];
  const allPerms = Object.values(modulePerms).flatMap((r) => Object.values(r));
  return hasAnyPermission(user, allPerms as Permission[], workspaceId);
}
```

## `server/server.ts` (server-only)

```typescript
import "server-only";
import { forbidden } from "next/navigation";
import { requireSession } from "~/lib/auth/server/session";
import { hasPermission, hasAnyPermission, hasAllPermissions, canAccessModule } from "../validate";
import { roleHierarchy, type UserRole } from "../roles";
import type { Permission, Module } from "../types";

// --- Checkers (return boolean) ---

export async function checkPermission(permission: Permission, workspaceId: string): Promise<boolean> {
  const session = await requireSession();
  return hasPermission(session, permission, workspaceId);
}

export async function checkAnyPermission(perms: Permission[], workspaceId: string): Promise<boolean> {
  const session = await requireSession();
  return hasAnyPermission(session, perms, workspaceId);
}

export async function checkModule(module: Module, workspaceId: string): Promise<boolean> {
  const session = await requireSession();
  return canAccessModule(session, module, workspaceId);
}

// --- Requirers (throw forbidden() on failure) ---

export async function requirePermission(permission: Permission, workspaceId: string): Promise<void> {
  const allowed = await checkPermission(permission, workspaceId);
  if (!allowed) forbidden();
}

export async function requireAnyPermission(perms: Permission[], workspaceId: string): Promise<void> {
  const allowed = await checkAnyPermission(perms, workspaceId);
  if (!allowed) forbidden();
}

export async function requireAllPermissions(perms: Permission[], workspaceId: string): Promise<void> {
  const session = await requireSession();
  if (!hasAllPermissions(session, perms, workspaceId)) forbidden();
}

export async function requireWorkspaceRole(minRole: UserRole, workspaceId: string): Promise<void> {
  const session = await requireSession();
  // Implement based on your backend's workspace-role model
  if (roleHierarchy[session.role] < roleHierarchy[minRole]) forbidden();
}

export async function requireModule(module: Module, workspaceId: string): Promise<void> {
  const allowed = await checkModule(module, workspaceId);
  if (!allowed) forbidden();
}
```

## `client/client.ts` (client-only)

```typescript
"use client";

import { useSession } from "~/providers/auth-provider"; // Your auth context
import { useWorkspaceId } from "~/lib/workspace/hooks";
import { hasPermission, hasAnyPermission, hasAllPermissions, canAccessModule } from "../validate";
import { roleHierarchy, canManageRole, type UserRole } from "../roles";
import type { Permission, Module } from "../types";
import type { ReactNode } from "react";

export function useAccess() {
  const session = useSession();
  const workspaceId = useWorkspaceId();

  return {
    hasPermission: (p: Permission) =>
      hasPermission(session, p, workspaceId),

    hasAnyPermission: (perms: Permission[]) =>
      hasAnyPermission(session, perms, workspaceId),

    hasAllPermissions: (perms: Permission[]) =>
      hasAllPermissions(session, perms, workspaceId),

    canAccessModule: (module: Module) =>
      canAccessModule(session, module, workspaceId),

    hasRole: (role: UserRole) =>
      roleHierarchy[session.role] >= roleHierarchy[role],

    canManageUser: (targetRole: UserRole) =>
      canManageRole(session.role as UserRole, targetRole),
  };
}

// Declarative permission gate
export function Can({
  permission,
  children,
  fallback = null,
}: {
  permission: Permission;
  children: ReactNode;
  fallback?: ReactNode;
}) {
  const { hasPermission } = useAccess();
  return hasPermission(permission) ? <>{children}</> : <>{fallback}</>;
}
```
