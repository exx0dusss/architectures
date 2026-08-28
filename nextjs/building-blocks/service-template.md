# Service Resource Template

Copy this template for every new backend resource. Replace `{Resource}`, `{resource}`, `{service}`, and `{path}` with your values.

**Example:** For a "channels" resource in the "main" service:
- `{Resource}` → `Channel`
- `{resource}` → `channel`
- `{resources}` → `channels`
- `{service}` → `main`
- `{path}` → `channels`

Create all 7 files in `src/services/{service}/{resources}/`.

---

## 1. `schema.ts`

```typescript
import { z } from "zod";
import { createSchemaFactory, identityTranslate, type TranslateFn } from "~/i18n/zod";

// ── Enums (at the TOP) ──────────────────────────────────────────

export const {RESOURCE}_STATUSES = ["ACTIVE", "INACTIVE", "ARCHIVED"] as const;
export const {Resource}StatusEnum = z.enum({RESOURCE}_STATUSES);
export type {Resource}Status = z.infer<typeof {Resource}StatusEnum>;

// ── Create schema (factory for i18n) ────────────────────────────

export function createCreate{Resource}Schema(t: TranslateFn) {
  const f = createSchemaFactory(t);
  return z.object({
    name: f.requiredString().max(255, f.maxLength(255)),
    // Add fields...
  });
}
export const create{Resource}Schema = createCreate{Resource}Schema(identityTranslate);
export type Create{Resource} = z.infer<typeof create{Resource}Schema>;

// ── Update schema ───────────────────────────────────────────────

export function createUpdate{Resource}Schema(t: TranslateFn) {
  return createCreate{Resource}Schema(t).partial();
}
export const update{Resource}Schema = createUpdate{Resource}Schema(identityTranslate);
export type Update{Resource} = z.infer<typeof update{Resource}Schema>;

// ── DTO schema ──────────────────────────────────────────────────

export function create{Resource}DtoSchema(t: TranslateFn) {
  return z.object({
    id: z.coerce.string(),
    name: z.string(),
    status: {Resource}StatusEnum,
    createdAt: z.iso.datetime({ local: true }),
    updatedAt: z.iso.datetime({ local: true }).optional(),
    // Add all DTO fields from backend...
  });
}
export const {resource}Schema = create{Resource}DtoSchema(identityTranslate);
export type {Resource} = z.infer<typeof {resource}Schema>;
```

---

## 2. `api-schema.ts`

```typescript
import { z } from "zod";
import {
  workspacePathParamsSchema,
  workspaceHeaderSchema,
} from "~/services/_shared/schema/request";
import { querySchema } from "~/services/_shared/schema/query";
import { create{Resource}Schema, {Resource}StatusEnum } from "./schema";

// ── Path params ─────────────────────────────────────────────────

const {resource}PathParamsSchema = workspacePathParamsSchema.extend({
  {resource}Id: z.coerce.string(),
});

// ── List request ────────────────────────────────────────────────

export const getAll{Resource}sRequestSchema = z.object({
  path: workspacePathParamsSchema,
  query: querySchema.extend({
    statusFilter: {Resource}StatusEnum.optional(),
  }),
  headers: workspaceHeaderSchema,
});
export type GetAll{Resource}sRequest = z.infer<typeof getAll{Resource}sRequestSchema>;

// ── Detail request ──────────────────────────────────────────────

export const get{Resource}ByIdRequestSchema = z.object({
  path: {resource}PathParamsSchema,
  headers: workspaceHeaderSchema,
});
export type Get{Resource}ByIdRequest = z.infer<typeof get{Resource}ByIdRequestSchema>;

// ── Create request ──────────────────────────────────────────────

export const create{Resource}RequestSchema = z.object({
  path: workspacePathParamsSchema,
  data: create{Resource}Schema,
  headers: workspaceHeaderSchema,
});
export type Create{Resource}Request = z.infer<typeof create{Resource}RequestSchema>;

// ── Update request ──────────────────────────────────────────────

export const update{Resource}RequestSchema = z.object({
  path: {resource}PathParamsSchema,
  data: create{Resource}Schema.partial(),
  headers: workspaceHeaderSchema,
});
export type Update{Resource}Request = z.infer<typeof update{Resource}RequestSchema>;

// ── Delete request ──────────────────────────────────────────────

export const delete{Resource}RequestSchema = z.object({
  path: {resource}PathParamsSchema,
  headers: workspaceHeaderSchema,
});
export type Delete{Resource}Request = z.infer<typeof delete{Resource}RequestSchema>;
```

---

## 3. `queries.ts`

```typescript
import "server-only";
import { cache } from "react";
import { apiServer } from "~/services/_shared/fetch-client/api-server";
import { paginate } from "~/services/_shared/schema/paginate";
import { {resource}Schema } from "./schema";
import {
  getAll{Resource}sRequestSchema,
  get{Resource}ByIdRequestSchema,
  type GetAll{Resource}sRequest,
  type Get{Resource}ByIdRequest,
} from "./api-schema";

export const getAll{Resource}s = cache(async (request: GetAll{Resource}sRequest) => {
  const { path, query, headers } = getAll{Resource}sRequestSchema.parse(request);
  return apiServer.{service}.v1.get(`/{path}/getAll/workspace/${path.workspaceId}`, {
    headers,
    query,
    schema: paginate({resource}Schema),
  });
});

export const get{Resource}ById = cache(async (request: Get{Resource}ByIdRequest) => {
  const { path, headers } = get{Resource}ByIdRequestSchema.parse(request);
  return apiServer.{service}.v1.get(`/{path}/${path.{resource}Id}/workspace/${path.workspaceId}`, {
    headers,
    schema: {resource}Schema,
  });
});
```

---

## 4. `query-options.ts`

```typescript
import {
  queryOptions,
  keepPreviousData,
} from "@tanstack/react-query";
import { apiClient } from "~/services/_shared/fetch-client/api-client";
import { paginate, type PaginatedResponse } from "~/services/_shared/schema/paginate";
import { KEY_SEGMENTS, type QueryScope } from "~/services/_shared/query-keys";
import { {resource}Schema, type {Resource} } from "./schema";
import {
  getAll{Resource}sRequestSchema,
  get{Resource}ByIdRequestSchema,
  type GetAll{Resource}sRequest,
  type Get{Resource}ByIdRequest,
} from "./api-schema";

export const {resource}Keys = {
  all: ["{module}", "{resources}"] as const,
  lists: () => [...{resource}Keys.all, KEY_SEGMENTS.LISTS] as const,
  list: (scope: QueryScope = "main", params: unknown = KEY_SEGMENTS.SKIPPED) =>
    [...{resource}Keys.lists(), scope, params] as const,
  details: () => [...{resource}Keys.all, KEY_SEGMENTS.DETAILS] as const,
  detail: (scope: QueryScope = "main", params: unknown = KEY_SEGMENTS.SKIPPED) =>
    [...{resource}Keys.details(), scope, params] as const,
};

export const {resource}Queries = {
  list: (request: GetAll{Resource}sRequest, opts?: { _scope?: QueryScope }) => {
    const parsed = getAll{Resource}sRequestSchema.parse(request);
    return queryOptions<PaginatedResponse<{Resource}>>({
      queryKey: {resource}Keys.list(opts?._scope ?? "main", parsed),
      queryFn: async () =>
        apiClient.{service}.v1.get(`/{path}/getAll/workspace/${parsed.path.workspaceId}`, {
          headers: parsed.headers,
          query: parsed.query,
          schema: paginate({resource}Schema),
        }),
      placeholderData: keepPreviousData,
    });
  },

  detail: (request: Get{Resource}ByIdRequest, opts?: { _scope?: QueryScope }) => {
    const parsed = get{Resource}ByIdRequestSchema.parse(request);
    return queryOptions<{Resource}>({
      queryKey: {resource}Keys.detail(opts?._scope ?? "main", parsed),
      queryFn: async () =>
        apiClient.{service}.v1.get(
          `/{path}/${parsed.path.{resource}Id}/workspace/${parsed.path.workspaceId}`,
          { headers: parsed.headers, schema: {resource}Schema },
        ),
      staleTime: 10 * 60 * 1000,
      gcTime: 30 * 60 * 1000,
      refetchOnMount: false,
      refetchOnWindowFocus: false,
    });
  },
};
```

---

## 5. `actions.ts`

```typescript
"use server";

import { apiServer } from "~/services/_shared/fetch-client/api-server";
import { safeAction } from "~/services/_shared/safe-action";
import type { ApiResult } from "~/services/_shared/types";
import { {resource}Schema, type {Resource} } from "./schema";
import {
  create{Resource}RequestSchema,
  update{Resource}RequestSchema,
  delete{Resource}RequestSchema,
  type Create{Resource}Request,
  type Update{Resource}Request,
  type Delete{Resource}Request,
} from "./api-schema";

export async function create{Resource}(
  request: Create{Resource}Request,
): Promise<ApiResult<{Resource}>> {
  return safeAction(
    async () => {
      const { path, data, headers } = create{Resource}RequestSchema.parse(request);
      return await apiServer.{service}.v1.post(
        `/{path}/create/workspace/${path.workspaceId}`,
        data,
        { headers, schema: {resource}Schema },
      );
    },
    { code: "{RESOURCES}_CREATE_FAILED", message: "Failed to create {resource}" },
  );
}

export async function update{Resource}(
  request: Update{Resource}Request,
): Promise<ApiResult<{Resource}>> {
  return safeAction(
    async () => {
      const { path, data, headers } = update{Resource}RequestSchema.parse(request);
      return await apiServer.{service}.v1.put(
        `/{path}/${path.{resource}Id}/workspace/${path.workspaceId}`,
        data,
        { headers, schema: {resource}Schema },
      );
    },
    { code: "{RESOURCES}_UPDATE_FAILED", message: "Failed to update {resource}" },
  );
}

export async function delete{Resource}(
  request: Delete{Resource}Request,
): Promise<ApiResult<void>> {
  return safeAction(
    async () => {
      const { path, headers } = delete{Resource}RequestSchema.parse(request);
      await apiServer.{service}.v1.delete(
        `/{path}/${path.{resource}Id}/workspace/${path.workspaceId}`,
        { headers },
      );
    },
    { code: "{RESOURCES}_DELETE_FAILED", message: "Failed to delete {resource}" },
  );
}
```

---

## 6. `use-{resources}.ts`

**Default: `useSuspenseQuery`.** Components that fetch data use `useSuspenseQuery` and live inside a `<Suspense>` boundary. `useQuery` is a last resort for auth checks, background polling, or optional conditional data.

```typescript
"use client";

import {
  useSuspenseQuery,
  useQuery,
  useMutation,
  useQueryClient,
  skipToken,
  keepPreviousData,
} from "@tanstack/react-query";
import { unwrap } from "~/services/_shared/errors";
import { {resource}Keys, {resource}Queries } from "./query-options";
import { create{Resource}, update{Resource}, delete{Resource} } from "./actions";
import type {
  GetAll{Resource}sRequest,
  Get{Resource}ByIdRequest,
  Create{Resource}Request,
  Update{Resource}Request,
  Delete{Resource}Request,
} from "./api-schema";

// ── Suspense hooks (primary — use these by default) ─────────────

export function useSuspense{Resource}s(request: GetAll{Resource}sRequest) {
  return useSuspenseQuery({resource}Queries.list(request));
}

export function useSuspense{Resource}(request: Get{Resource}ByIdRequest) {
  return useSuspenseQuery({resource}Queries.detail(request));
}

// ── useQuery hooks (last resort — auth, polling, optional data) ─

export function use{Resource}s(request?: GetAll{Resource}sRequest) {
  const options = request ? {resource}Queries.list(request) : null;
  return useQuery({
    queryKey: options?.queryKey ?? {resource}Keys.list("skipped"),
    queryFn: options?.queryFn ?? skipToken,
    ...options,
    placeholderData: keepPreviousData,
  });
}

export function use{Resource}(request?: Get{Resource}ByIdRequest) {
  const options = request ? {resource}Queries.detail(request) : null;
  return useQuery({
    queryKey: options?.queryKey ?? {resource}Keys.detail("skipped"),
    queryFn: options?.queryFn ?? skipToken,
    ...options,
  });
}

// ── Mutation hooks ──────────────────────────────────────────────

export function useCreate{Resource}Mutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (request: Create{Resource}Request) => {
      return unwrap(await create{Resource}(request));
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: {resource}Keys.all });
    },
  });
}

export function useUpdate{Resource}Mutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (request: Update{Resource}Request) => {
      return unwrap(await update{Resource}(request));
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: {resource}Keys.all });
    },
  });
}

export function useDelete{Resource}Mutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (request: Delete{Resource}Request) => {
      return unwrap(await delete{Resource}(request));
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: {resource}Keys.all });
    },
  });
}
```

---

## 7. `search-params.ts`

```typescript
import {
  parseAsString,
  parseAsStringEnum,
  createSerializer,
  type inferParserType,
} from "nuqs/server";
import { globalParsers } from "~/services/_shared/search-params";
import { {Resource}StatusEnum, type {Resource}Status } from "./schema";

// ── Resource-specific filter parsers ────────────────────────────

export const {resource}FiltersParsers = {
  status: parseAsStringEnum([...{Resource}StatusEnum.options, "all"] as const)
    .withDefault("all"),
  // Add more filters as needed...
};

// ── Full parsers (extend global) ────────────────────────────────

export const {resources}Parsers = {
  ...globalParsers,
  ...{resource}FiltersParsers,
};

export type {Resource}sSearchParams = inferParserType<typeof {resources}Parsers>;

// ── URL → API query converter ───────────────────────────────────

export function to{Resource}sQuery(params: {Resource}sSearchParams) {
  return {
    page: params.page - 1,          // API is 0-indexed, URL is 1-indexed
    size: params.size,
    sort: params.sort.length ? params.sort : undefined,
    searchBy: params.search || undefined,
    statusFilter: params.status !== "all" ? (params.status as {Resource}Status) : undefined,
  };
}

// ── Serializer for type-safe URL construction ───────────────────

export const {resources}Serializer = createSerializer({resources}Parsers);
```
