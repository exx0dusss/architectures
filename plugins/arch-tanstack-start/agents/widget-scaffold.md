---
model: sonnet
description: Generate a 3-file widget with Suspense boundary, data fetcher, and item renderer
---

# Widget Scaffold

Generate the widget decomposition pattern for a dashboard data widget.

## Input

Domain name (e.g., "recent-orders", "low-stock", "pending-reviews")

## Generated files

```
components/widgets/{domain}/
├── {domain}-widget.tsx          # Card + Suspense shell
├── {domain}-list.tsx            # useSuspenseQuery data fetcher
├── {domain}-item.tsx            # Pure render + skeleton
└── (optional) my-{domain}-widget.tsx  # "My" variant
```

## Templates

### {domain}-widget.tsx (shell)

```tsx
import { Suspense } from 'react'
import { Card, CardHeader, CardTitle, CardContent } from '~/components/ui/card'
import { {Domain}List, {Domain}ListSkeleton } from './{domain}-list'

export function {Domain}Widget() {
  return (
    <Card>
      <CardHeader>
        <CardTitle>{Title}</CardTitle>
      </CardHeader>
      <CardContent>
        <Suspense fallback={<{Domain}ListSkeleton />}>
          <{Domain}List />
        </Suspense>
      </CardContent>
    </Card>
  )
}
```

### {domain}-list.tsx (data fetcher)

```tsx
import { useSuspenseQuery } from '@tanstack/react-query'
import { {domain}QueryOptions } from '~/services/{resource}/{resource}.query-options'
import { {Domain}Item, {Domain}ItemSkeleton } from './{domain}-item'
import { Skeleton } from '~/components/ui/skeleton'

export function {Domain}List() {
  const { data } = useSuspenseQuery({domain}QueryOptions.list({ limit: 5 }))

  if (data.items.length === 0) {
    return <p className="text-sm text-muted-foreground">Немає даних</p>
  }

  return (
    <div className="space-y-3">
      {data.items.map((item) => (
        <{Domain}Item key={item.id} item={item} />
      ))}
    </div>
  )
}

export function {Domain}ListSkeleton() {
  return (
    <div className="space-y-3">
      {Array.from({ length: 3 }).map((_, i) => (
        <{Domain}ItemSkeleton key={i} />
      ))}
    </div>
  )
}
```

### {domain}-item.tsx (pure render)

```tsx
import { Skeleton } from '~/components/ui/skeleton'

interface {Domain}ItemProps {
  item: {ItemType}
}

export function {Domain}Item({ item }: {Domain}ItemProps) {
  return (
    <div className="flex items-center gap-3">
      {/* Render item */}
    </div>
  )
}

export function {Domain}ItemSkeleton() {
  return (
    <div className="flex items-center gap-3">
      <Skeleton className="size-8 rounded-full" />
      <div className="flex-1 space-y-1.5">
        <Skeleton className="h-3.5 w-32" />
        <Skeleton className="h-3 w-20" />
      </div>
    </div>
  )
}
```

## Rules

- Always `useSuspenseQuery` in list component (never useQuery)
- Widget shell only handles Suspense boundary — no data logic
- Item component is a pure molecule — no hooks, no fetching
- Every item has a Skeleton variant for loading state
- Query options imported from service layer (not inline queryFn)
