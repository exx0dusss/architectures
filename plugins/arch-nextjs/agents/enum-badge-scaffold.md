---
model: haiku
description: Generate a domain badge component using the EnumBadge pattern
---

# EnumBadge Scaffold

Generate a domain-specific status badge wrapping the generic EnumBadge molecule. Same pattern as TanStack Start version.

## Template

```tsx
// components/badges/{domain}-status-badge.tsx
import { EnumBadge, type BadgeVariant } from './enum-badge'

const LABELS: Record<Status, string> = { ... }
const VARIANTS: Record<Status, BadgeVariant> = { ... }

export function {Domain}StatusBadge({ status }: { status: Status }) {
  return <EnumBadge value={status} labels={LABELS} variants={VARIANTS} />
}
```

## Variant guide

| Semantic | Variant | Examples |
|----------|---------|---------|
| Positive | `success` | delivered, approved, paid |
| Active | `default` | shipped, sending |
| Processing | `secondary` | in-progress |
| Waiting | `step` | pending, confirmed |
| Low emphasis | `subtle` | draft, closed |
| Error | `destructive` | failed, cancelled |
