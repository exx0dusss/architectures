# Shared Schemas

Reusable Zod schemas for pagination, query params, request shapes, and workspace context.

## Pagination (`services/_shared/schema/paginate.ts`)

```typescript
import { z, type ZodSchema } from "zod";

export function paginate<T extends ZodSchema>(itemSchema: T) {
  return z.object({
    content: z.array(itemSchema),
    pageNumber: z.number(),
    pageSize: z.number(),
    totalElements: z.number(),
    totalPages: z.number(),
  });
}

export type PaginatedResponse<T> = {
  content: T[];
  pageNumber: number;
  pageSize: number;
  totalElements: number;
  totalPages: number;
};

// Variant with optional summary field
export function paginateWithSummary<T extends ZodSchema, S extends ZodSchema>(
  itemSchema: T,
  summarySchema: S,
) {
  return paginate(itemSchema).extend({
    summary: summarySchema.optional(),
  });
}
```

## Query schemas (`services/_shared/schema/query.ts`)

```typescript
import { z } from "zod";

export const pageableSchema = z.object({
  page: z.coerce.number().int().min(0).default(0),
  size: z.coerce.number().int().min(1).max(100).default(25),
  sort: z.string().optional(),
  sortBy: z.string().optional(),
  sortDirection: z.enum(["asc", "desc"]).optional(),
});

export const searchSchema = z.object({
  searchBy: z.string().optional(),
});

export const filteringSchema = z.object({
  userIds: z.array(z.string()).optional(),
});

// Combined — use as base for resource-specific query schemas
export const querySchema = pageableSchema
  .merge(searchSchema)
  .merge(filteringSchema)
  .extend({
    userId: z.string().optional(),
  });

export type QueryParams = z.infer<typeof querySchema>;
```

## Request schemas (`services/_shared/schema/request.ts`)

```typescript
import { z } from "zod";

// Every workspace-scoped request needs these
export const workspacePathParamsSchema = z.object({
  workspaceId: z.coerce.string(),
});

export const workspaceHeaderSchema = z.object({
  "X-Workspace-Id": z.string(),
});

// Extend for resource-specific paths
// Example: flowPathParamsSchema = workspacePathParamsSchema.extend({ flowId: z.coerce.string() })
```

## Query keys (`services/_shared/query-keys.ts`)

```typescript
export const KEY_SEGMENTS = {
  LISTS: "list",
  DETAILS: "detail",
  SKIPPED: "skipped",
} as const;

export type SkippedKey = typeof KEY_SEGMENTS.SKIPPED;
export type QueryScope = "main" | string;
```

## Query timing (`services/_shared/query-times.ts`)

```typescript
export const STALE_TIME_MS = 5 * 60 * 1000;    // 5 minutes
export const GC_TIME_MS = 10 * 60 * 1000;       // 10 minutes
export const CHECK_AVAILABILITY_GC_TIME_MS = 5 * 60 * 1000;
```

## Global URL parsers (`services/_shared/search-params.ts`)

```typescript
import {
  parseAsInteger,
  parseAsString,
  parseAsArrayOf,
  createSerializer,
  type inferParserType,
} from "nuqs/server";

export const paginationParsers = {
  page: parseAsInteger.withDefault(1),
  size: parseAsInteger.withDefault(10),
  sort: parseAsArrayOf(parseAsString).withDefault([]),
};

export const searchParsers = {
  search: parseAsString.withDefault(""),
};

// Every table resource extends this
export const globalParsers = {
  ...paginationParsers,
  ...searchParsers,
};

export type GlobalSearchParams = inferParserType<typeof globalParsers>;
```
