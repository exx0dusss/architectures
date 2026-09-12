# Shared Utilities

All utilities are framework-agnostic and identical to the Next.js versions.

## `lib/utils/cn.ts` — Tailwind class merge

```typescript
import { clsx, type ClassValue } from "clsx";
import { extendTailwindMerge } from "tailwind-merge";

const customTwMerge = extendTailwindMerge({
  extend: {
    classGroups: {
      "font-size": [
        "text-heading-2xl", "text-heading-xl", "text-heading-large",
        "text-heading-medium", "text-heading-small",
        "text-body-large", "text-body", "text-body-small", "text-xxs",
      ],
    },
  },
});

export function cn(...inputs: ClassValue[]) {
  return customTwMerge(clsx(inputs));
}
```

## `lib/utils/query.ts` — Query string builder

```typescript
export function buildQueryString(query: Record<string, unknown>): string {
  const params = new URLSearchParams();
  for (const [key, value] of Object.entries(query)) {
    if (value === undefined || value === null) continue;
    if (Array.isArray(value)) {
      for (const item of value) params.append(key, String(item));
    } else {
      params.set(key, String(value));
    }
  }
  const str = params.toString();
  return str ? `?${str}` : "";
}
```

## `lib/utils/date.ts`, `lib/dayjs.ts`, `lib/logger.ts`, `lib/socket.ts`

Identical to the Next.js versions. See the [Next.js utilities building block](../../nextjs/building-blocks/utilities.md) for full code.

The only difference: logger transport check uses `VITE_*` instead of `NEXT_PUBLIC_*`:

```typescript
transport:
  import.meta.env.DEV
    ? { target: "pino-pretty", options: { colorize: true } }
    : undefined,
```
