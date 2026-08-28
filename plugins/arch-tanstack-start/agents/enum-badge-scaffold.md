---
model: haiku
description: Generate a domain badge component using the EnumBadge pattern
---

# EnumBadge Scaffold

Generate a domain-specific status badge wrapping the generic EnumBadge molecule.

## Input

- Domain name (e.g., "order", "review", "campaign")
- Enum type name and values
- Labels for each value
- Badge variant for each value

## Base pattern (if not already created)

```tsx
// components/badges/enum-badge.tsx
import { Badge, badgeVariants } from '~/components/ui/badge'
import type { VariantProps } from 'class-variance-authority'

type BadgeVariant = NonNullable<VariantProps<typeof badgeVariants>['variant']>

interface EnumBadgeProps<T extends string | number> extends React.ComponentProps<typeof Badge> {
  value: T
  labels: Record<T, string>
  variants?: Record<T, BadgeVariant>
}

export function EnumBadge<T extends string | number>({
  value, labels, variants, className, ...props
}: EnumBadgeProps<T>) {
  const variant = variants ? variants[value] : 'outline'
  const label = labels[value] ?? value
  return <Badge variant={variant} className={className} {...props}>{label}</Badge>
}

export type { BadgeVariant }
```

## Domain badge template

```tsx
// components/badges/{domain}-status-badge.tsx
import { EnumBadge, type BadgeVariant } from './enum-badge'

type {Domain}Status = '{value1}' | '{value2}' | '{value3}'

const {DOMAIN}_STATUS_LABELS: Record<{Domain}Status, string> = {
  {value1}: '{Label1}',
  {value2}: '{Label2}',
  {value3}: '{Label3}',
}

const {DOMAIN}_STATUS_VARIANTS: Record<{Domain}Status, BadgeVariant> = {
  {value1}: '{variant1}',
  {value2}: '{variant2}',
  {value3}: '{variant3}',
}

export function {Domain}StatusBadge({ status }: { status: {Domain}Status }) {
  return (
    <EnumBadge
      value={status}
      labels={{DOMAIN}_STATUS_LABELS}
      variants={{DOMAIN}_STATUS_VARIANTS}
    />
  )
}
```

## Variant selection guide

| Semantic | Badge variant | When to use |
|----------|:------------:|-------------|
| Positive/completed | `success` | delivered, approved, paid |
| Active/primary | `default` | shipped, sending, active |
| Processing/secondary | `secondary` | processing, in-progress |
| Intermediate/waiting | `step` | pending, confirmed, scheduled |
| Low emphasis | `subtle` | draft, resolved, closed |
| Neutral/bordered | `outline` | informational, no status |
| Error/danger | `destructive` | failed, cancelled, rejected |

## Rules

- Never inline status maps in table columns — always extract to a badge component
- Import types from API schema when available (not redeclare)
- One file per domain badge in `components/badges/`
