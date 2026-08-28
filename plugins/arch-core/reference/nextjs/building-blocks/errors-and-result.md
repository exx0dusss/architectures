# Error Handling & Result Pattern

Never throw from server actions. Always return `Result<T, E>`.

## Result type (`lib/utils/result.ts`)

```typescript
export type Result<T, E = Error> =
  | { ok: true; value: T }
  | { ok: false; error: E };

export function ok<T>(value: T): Result<T, never> {
  return { ok: true, value };
}

export function err<E>(error: E): Result<never, E> {
  return { ok: false, error };
}

export function isOk<T, E>(result: Result<T, E>): result is { ok: true; value: T } {
  return result.ok;
}

export function isErr<T, E>(result: Result<T, E>): result is { ok: false; error: E } {
  return !result.ok;
}
```

## API Result type (`services/_shared/types.ts`)

```typescript
import type { Result } from "~/lib/utils/result";

export interface ApiErrorPayload {
  message: string;
  code: string;
  status?: number;
  fieldErrors?: Record<string, string[]>;
  rawData?: unknown;
}

export type ApiResult<T> = Result<T, ApiErrorPayload>;
```

## Error classes (`services/_shared/errors.ts`)

```typescript
export class BaseApiError extends Error {
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
    this.name = this.constructor.name;
    this.status = status;
    this.code = code ?? "UNKNOWN_ERROR";
    this.fieldErrors = fieldErrors;
    this.rawData = rawData;
  }
}

// Used in server-side code (serverFetch, queries, actions)
export class ServerApiError extends BaseApiError {}

// Used in client-side code (apiClient through proxy)
export class ClientApiError extends BaseApiError {}

// Type guards
export function isApiError(error: unknown): error is BaseApiError {
  return error instanceof BaseApiError;
}

export function isServerApiError(error: unknown): error is ServerApiError {
  return error instanceof ServerApiError;
}

export function isClientApiError(error: unknown): error is ClientApiError {
  return error instanceof ClientApiError;
}

// Normalize any error to ApiErrorPayload
export function toApiErrorPayload(error: unknown): ApiErrorPayload {
  if (isApiError(error)) {
    return {
      message: error.message,
      code: error.code,
      status: error.status,
      fieldErrors: error.fieldErrors,
      rawData: error.rawData,
    };
  }
  if (error instanceof Error) {
    return { message: error.message, code: "UNKNOWN_ERROR" };
  }
  return { message: "An unknown error occurred", code: "UNKNOWN_ERROR" };
}

// Convert Result to value or throw (for use in mutation functions)
export function unwrap<T>(result: Result<T, ApiErrorPayload>): T {
  if (!result.ok) {
    throw new ServerApiError(
      result.error.message,
      result.error.status ?? 500,
      result.error.code,
      result.error.fieldErrors,
      result.error.rawData,
    );
  }
  return result.value;
}
```

## Safe action wrapper (`services/_shared/safe-action.ts`)

```typescript
import { ok, err } from "~/lib/utils/result";
import { toApiErrorPayload } from "./errors";
import { logger } from "~/lib/logger";
import { ZodError } from "zod";
import type { ApiResult, ApiErrorPayload } from "./types";

interface ActionMeta {
  code: string;
  message: string;
}

export async function safeAction<T>(
  fn: () => Promise<T>,
  meta: ActionMeta,
): Promise<ApiResult<T>> {
  try {
    const result = await fn();
    return ok(result);
  } catch (error) {
    // Handle Zod validation errors specially — extract field errors
    if (error instanceof ZodError) {
      const fieldErrors: Record<string, string[]> = {};
      for (const issue of error.issues) {
        const path = issue.path.join(".");
        if (!fieldErrors[path]) fieldErrors[path] = [];
        fieldErrors[path].push(issue.message);
      }
      return err({
        message: meta.message,
        code: meta.code,
        fieldErrors,
      });
    }

    const payload = toApiErrorPayload(error);

    // Log based on severity
    if (payload.status && payload.status >= 500) {
      logger.error({ error, code: meta.code }, meta.message);
    } else {
      logger.warn({ error, code: meta.code }, meta.message);
    }

    return err({
      ...payload,
      code: meta.code,
      message: payload.message || meta.message,
    });
  }
}
```

## Usage pattern

```typescript
// Server action (actions.ts)
"use server";
export async function createFlow(request: CreateFlowRequest): Promise<ApiResult<Flow>> {
  return safeAction(
    async () => {
      const parsed = createFlowRequestSchema.parse(request);
      return await apiServer.main.v1.post("/flows/create/...", parsed.data, {
        headers: parsed.headers,
        schema: flowSchema,
      });
    },
    { code: "FLOWS_CREATE_FAILED", message: "Failed to create flow" },
  );
}

// Client mutation (use-flows.ts)
export function useCreateFlowMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (req: CreateFlowRequest) => {
      return unwrap(await createFlow(req)); // Result → value or throw
    },
    onSuccess: () => queryClient.invalidateQueries({ queryKey: flowKeys.all }),
    onError: (error) => toast.error(error.message),
  });
}
```
