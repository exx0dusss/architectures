# Error Handling

Server functions throw on error. TanStack Query catches the throw and surfaces it via `onError`.

## Error class (`services/_shared/errors.ts`)

```typescript
export class ServerApiError extends Error {
  status: number;
  code: string;
  fieldErrors?: Record<string, string[]>;
  rawData?: unknown;

  constructor(
    message: string,
    status: number,
    code?: string,
    fieldErrors?: Record<string, string[]>,
    rawData?: unknown,
  ) {
    super(message);
    this.name = "ServerApiError";
    this.status = status;
    this.code = code ?? "UNKNOWN_ERROR";
    this.fieldErrors = fieldErrors;
    this.rawData = rawData;
  }
}

// Type guard
export function isApiError(error: unknown): error is ServerApiError {
  return error instanceof ServerApiError;
}

// Normalize any error to a consistent shape
export function toApiErrorPayload(error: unknown): {
  message: string;
  code: string;
  status?: number;
  fieldErrors?: Record<string, string[]>;
} {
  if (isApiError(error)) {
    return {
      message: error.message,
      code: error.code,
      status: error.status,
      fieldErrors: error.fieldErrors,
    };
  }
  if (error instanceof Error) {
    return { message: error.message, code: "UNKNOWN_ERROR" };
  }
  return { message: "An unknown error occurred", code: "UNKNOWN_ERROR" };
}
```

## Usage pattern

```typescript
// Server function (flows.functions.ts) — throws on error
export const createFlow = createServerFn({ method: "POST" })
  .validator((data: CreateFlowRequest) => createFlowRequestSchema.parse(data))
  .handler(async ({ data: { path, data, headers } }) => {
    // apiFetch throws ServerApiError on non-OK response
    return apiFetch.main.v1.post("/flows/create/...", data, {
      headers,
      schema: flowSchema,
    });
  });

// Client mutation (flows.hooks.ts) — TanStack Query catches the throw
export function useCreateFlowMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (req: CreateFlowRequest) => createFlow({ data: req }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: flowKeys.all }),
    onError: (error) => {
      if (isApiError(error)) {
        toast.error(error.message);
      }
    },
  });
}
```

## Result type (optional)

For complex flows that need explicit error handling without throwing:

```typescript
// src/lib/utils/result.ts
export type Result<T, E = Error> =
  | { ok: true; value: T }
  | { ok: false; error: E };

export function ok<T>(value: T): Result<T, never> {
  return { ok: true, value };
}

export function err<E>(error: E): Result<never, E> {
  return { ok: false, error };
}

export function unwrap<T, E>(result: Result<T, E>): T {
  if (!result.ok) throw result.error;
  return result.value;
}
```

This is NOT the default pattern — only use it for multi-step operations where you need to handle partial failures explicitly.

## Key difference from Next.js

| Next.js | TanStack Start |
|---------|---------------|
| `safeAction()` wraps every server action | Not needed — server functions throw naturally |
| `unwrap()` in every mutation | Not needed — TanStack Query catches throws |
| `ApiResult<T>` return type everywhere | Return the value directly, let errors throw |
| `Result` pattern is mandatory | `Result` pattern is optional |
