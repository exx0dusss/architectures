# Shared Utilities

## `lib/utils/cn.ts` — Tailwind class merge

```typescript
import { clsx, type ClassValue } from "clsx";
import { extendTailwindMerge } from "tailwind-merge";

const customTwMerge = extendTailwindMerge({
  extend: {
    classGroups: {
      "font-size": [
        // Register custom typography tokens so they merge correctly
        "text-heading-2xl",
        "text-heading-xl",
        "text-heading-large",
        "text-heading-medium",
        "text-heading-small",
        "text-body-large",
        "text-body",
        "text-body-small",
        "text-xxs",
      ],
    },
  },
});

export function cn(...inputs: ClassValue[]) {
  return customTwMerge(clsx(inputs));
}
```

## `lib/utils/result.ts` — Result type

See [errors-and-result.md](./errors-and-result.md).

## `lib/utils/query.ts` — Query string builder

```typescript
export function buildQueryString(query: Record<string, unknown>): string {
  const params = new URLSearchParams();

  for (const [key, value] of Object.entries(query)) {
    if (value === undefined || value === null) continue;

    if (Array.isArray(value)) {
      for (const item of value) {
        params.append(key, String(item));
      }
    } else {
      params.set(key, String(value));
    }
  }

  const str = params.toString();
  return str ? `?${str}` : "";
}
```

## `lib/utils/date.ts` — Date formatting

```typescript
import dayjs from "~/lib/dayjs";

export function formatDateTime(date: string | Date): string {
  return dayjs(date).format("YYYY-MM-DD HH:mm:ss");
}

export function formatDate(date: string | Date): string {
  return dayjs(date).format("YYYY-MM-DD");
}

export function formatRelativeTime(date: string | Date): string {
  return dayjs(date).fromNow();
}

export function formatDateTimeUA(date: string | Date): string {
  return dayjs(date).format("DD.MM.YYYY HH:mm");
}
```

## `lib/utils/timezone.ts`

```typescript
export function getTimezoneDisplayName(zoneId: string, _locale?: string): string {
  return zoneId.replace(/_/g, " ");
}
```

## `lib/utils/time.ts` — Time unit conversion

```typescript
export type TimeUnit =
  | "milliseconds"
  | "seconds"
  | "minutes"
  | "hours"
  | "days"
  | "weeks"
  | "months"
  | "years";

const SECONDS_MAP: Record<TimeUnit, number> = {
  milliseconds: 0.001,
  seconds: 1,
  minutes: 60,
  hours: 3600,
  days: 86400,
  weeks: 604800,
  months: 2592000,
  years: 31536000,
};

export function toSeconds(value: number, unit: TimeUnit): number {
  return value * SECONDS_MAP[unit];
}

export function toMilliseconds(value: number, unit: TimeUnit): number {
  return toSeconds(value, unit) * 1000;
}
```

## `lib/utils/form-data.ts` — Object to FormData

```typescript
export function toFormData(
  obj: Record<string, unknown>,
  cfg?: { indices?: boolean },
  fd?: FormData,
  pre?: string,
): FormData {
  const formData = fd || new FormData();

  for (const [key, value] of Object.entries(obj)) {
    const formKey = pre ? `${pre}[${key}]` : key;

    if (value === undefined || value === null) continue;

    if (value instanceof File || value instanceof Blob) {
      formData.append(formKey, value);
    } else if (Array.isArray(value)) {
      value.forEach((item, index) => {
        const arrayKey = cfg?.indices ? `${formKey}[${index}]` : formKey;
        if (typeof item === "object" && !(item instanceof File)) {
          toFormData(item as Record<string, unknown>, cfg, formData, arrayKey);
        } else {
          formData.append(arrayKey, item as string | Blob);
        }
      });
    } else if (typeof value === "object" && !(value instanceof Date)) {
      toFormData(value as Record<string, unknown>, cfg, formData, formKey);
    } else {
      formData.append(formKey, String(value));
    }
  }

  return formData;
}
```

## `lib/utils/auth-error-handler.ts` — Form error handling

```typescript
import type { BaseApiError } from "~/services/_shared/errors";

export type AuthContext = "login" | "register" | "forgot-password" | "reset-password" | "confirm-email";

interface ErrorPayload {
  message: string;
  code?: string;
  status?: number;
  fieldErrors?: Record<string, string[]>;
}

export function parseServerError(error: unknown): ErrorPayload {
  if (error && typeof error === "object" && "message" in error) {
    return error as ErrorPayload;
  }
  return { message: "An unexpected error occurred" };
}

export function getLocalizedErrorMessage(
  t: (key: string) => string,
  parsed: ErrorPayload,
  context: AuthContext,
): string {
  // Map backend error codes to i18n keys
  const key = `errors.${context}.${parsed.code ?? "unknown"}`;
  const translated = t(key);
  // If translation key doesn't exist, fall back to raw message
  return translated === key ? parsed.message : translated;
}

export function handleFormError(
  error: unknown,
  t: (key: string) => string,
  context: AuthContext,
  setFieldError: (field: string, message: string) => void,
  setStatus: (message: string) => void,
): void {
  const parsed = parseServerError(error);

  // Apply field-level errors
  if (parsed.fieldErrors) {
    for (const [field, messages] of Object.entries(parsed.fieldErrors)) {
      setFieldError(field, messages[0]);
    }
    return;
  }

  // Apply form-level error
  setStatus(getLocalizedErrorMessage(t, parsed, context));
}
```

## `lib/dayjs.ts` — Pre-configured dayjs

```typescript
import dayjs from "dayjs";
import duration from "dayjs/plugin/duration";
import relativeTime from "dayjs/plugin/relativeTime";
import utc from "dayjs/plugin/utc";

dayjs.extend(duration);
dayjs.extend(relativeTime);
dayjs.extend(utc);

export default dayjs;
```

## `lib/logger.ts` — Pino logger

```typescript
import pino from "pino";
import { env } from "~/env";

export const logger = pino({
  level: env.LOG_LEVEL ?? "info",
  redact: {
    paths: [
      "password",
      "*.password",
      "accessToken",
      "refreshToken",
      "*.accessToken",
      "*.refreshToken",
      "headers.authorization",
      "headers.cookie",
    ],
    censor: "[REDACTED]",
  },
  serializers: {
    error: pino.stdSerializers.err,
  },
  transport:
    env.NEXT_PUBLIC_APP_MODE === "development"
      ? { target: "pino-pretty", options: { colorize: true } }
      : undefined,
});
```

## `lib/socket.ts` — Socket.IO client

```typescript
"use client";

import { io, type Socket } from "socket.io-client";
import { env } from "~/env";

let socket: Socket | null = null;

export function getSocket(): Socket {
  if (!socket) {
    socket = io(env.NEXT_PUBLIC_CHATTING_SOCKET_URL, {
      autoConnect: false,
      transports: ["websocket", "polling"],
    });
  }
  return socket;
}
```
