---
model: sonnet
description: Generate a 3-file widget with Suspense boundary, data fetcher, and item renderer
---

# Widget Scaffold

Generate the widget decomposition pattern for a dashboard data widget.

## Input

Domain name (e.g., "recent-orders", "low-stock")

## Generated files

```
components/widgets/{domain}/
├── {domain}-widget.tsx          # Card + Suspense shell
├── {domain}-list.tsx            # useSuspenseQuery data fetcher
├── {domain}-item.tsx            # Pure render + skeleton
```

## Rules

- Always `useSuspenseQuery` in list component (never useQuery)
- Widget shell only handles Suspense boundary
- Item component is a pure molecule — no hooks, no fetching
- Every item has a Skeleton variant
- Query options imported from service layer
- Page components in `_components/` (underscore prefix for Next.js)
