---
status: stable
---

# Component Architecture

Atom-molecule-organism layering with category folders and colocated route components.

## Component layers

```
1. Atoms            → components/ui/           (Base UI/shadcn primitives, CVA variants)
2. Molecules        → components/{category}/   (badges/, buttons/, form/, filters/)
3. Organisms        → components/{domain}/     (data-fetching, domain-specific)
4. Route-specific   → routes/.../-components/
```

### Layer rules

| Layer | Data fetching | CVA variants | Example |
|-------|:------------:|:------------:|---------|
| Atom | Never | Yes (style-only) | `Button`, `Badge`, `Select` |
| Molecule | Never | No (uses atom variants) | `EnumBadge`, `TextField`, `FilterChip` |
| Organism | Yes (`useSuspenseQuery`, `useMutation`) | No | `OrderStatusBadge`, `FollowButton`, widget lists |

**Folder naming:** Use UI category names (`badges/`, `buttons/`, `inputs/`), not abstract layer names (`molecules/`, `organisms/`). Category names are findable; layer names are ambiguous.

**Registry rule:** If a component is installed from a shadcn registry, it stays in `ui/` — even if it composes other atoms internally.

## Shared components (`src/components/`)

Grouped by domain, NOT by feature:

```
components/
├── ui/                        # UI primitives (shadcn/Base UI components)
│   ├── button.tsx
│   ├── input.tsx
│   ├── dialog.tsx
│   ├── select.tsx
│   ├── checkbox.tsx
│   ├── tooltip.tsx
│   └── ...
├── layout/
│   ├── header/
│   └── sidebar/
├── avatars/                   # Avatar, AvatarGroup
├── badges/                    # StatusBadge, RoleBadge
├── buttons/                   # Composed buttons (CreateButton, etc.)
├── data-table/                # Generic table with sorting, pagination
├── filters/                   # FilterBar, FilterChip, DateRangeFilter
├── form/                      # TanStack Form field components
├── icons/                     # Icon wrappers (lucide-react)
├── inputs/                    # SearchInput, NumberInput
├── loaders/                   # Skeleton, Spinner, PageLoader
├── modals/                    # ConfirmDialog, AlertDialog wrappers
├── selectors/                 # UserSelector, WorkspaceSelector
├── sheets/                    # Side sheet components
├── suspense/                  # Suspense boundaries with fallbacks
└── table/                     # Table utilities, column helpers
```

## EnumBadge pattern

The standard way to render status/enum values as badges. Never inline status-to-variant maps in table columns.

```
Atom:     Badge (ui/badge.tsx)           → CVA variants, pure styling
Molecule: EnumBadge (badges/enum-badge)  → generic labels+variants mapper
Organism: OrderStatusBadge (badges/)     → knows the enum, provides label+variant maps
```

```tsx
// badges/enum-badge.tsx — generic base
interface EnumBadgeProps<T extends string | number> extends BadgeProps {
  value: T
  labels: Record<T, string>
  variants?: Record<T, BadgeProps["variant"]>
}

export function EnumBadge<T extends string | number>({ value, labels, variants, ...props }: EnumBadgeProps<T>) {
  return <Badge variant={variants?.[value] ?? "outline"} {...props}>{labels[value] ?? value}</Badge>
}

// badges/order-status-badge.tsx — domain wrapper
export function OrderStatusBadge({ status }: { status: OrderStatus }) {
  return <EnumBadge value={status} labels={ORDER_STATUS_LABELS} variants={ORDER_STATUS_VARIANTS} />
}
```

## Widget decomposition

Dashboard widgets follow a 3-file split that cleanly separates data fetching from rendering:

```
widgets/{domain}/
  {domain}-widget.tsx     → Card + Suspense boundary (shell)
  {domain}-list.tsx       → useSuspenseQuery (organism, data fetcher)
  {domain}-item.tsx       → Pure render + skeleton variant (molecule)
  my-{domain}-widget.tsx  → "My" profile variant (optional)
```

```tsx
// widget shell
export function RecentOrdersWidget() {
  return (
    <Card>
      <CardHeader><CardTitle>Recent Orders</CardTitle></CardHeader>
      <CardContent>
        <Suspense fallback={<OrderListSkeleton />}>
          <RecentOrdersList />
        </Suspense>
      </CardContent>
    </Card>
  )
}

// data fetcher
function RecentOrdersList() {
  const { data } = useSuspenseQuery(orderQueries.recent())
  return data.map(order => <OrderItem key={order.id} order={order} />)
}
```

## CVA conventions

All atoms in `ui/` use CVA for style variants. Export both the component and the variants function:

```tsx
const badgeVariants = cva("base-classes...", {
  variants: {
    variant: { default: "...", success: "...", destructive: "..." },
  },
  defaultVariants: { variant: "default" },
})

export { Badge, badgeVariants }
```

**When to use CVA:** Same DOM structure, different paint → CVA variant on the atom.
**When to use separate files:** Different DOM structure or different logic → separate file (molecule).

All components use `data-slot` attributes for debugging and CSS targeting.

## Route-specific components (`-components/`)

Every table/list route colocates its components in a dash-prefixed `-components/` folder:

```
src/routes/_authed/_workspace/buying/
├── flows.tsx                       # Route file
└── -components/
    ├── columns.tsx                 # TanStack Table column definitions
    ├── flows-table.tsx             # Table component
    ├── flows-toolbar.tsx           # Search, filters, bulk actions
    ├── flows-header.tsx            # Page title, create button
    ├── flows-page-loader.tsx       # Pending component skeleton
    └── modals/
        ├── flow-create-dialog.tsx
        └── flow-delete-confirm-alert.tsx
```

**Convention:** Prefix all route-specific components with the resource name (`flows-table`, `flows-toolbar`).

**Key difference from Next.js:** Uses `-components/` (dash prefix) instead of `_components/` (underscore). In TanStack Router, dash-prefixed directories are non-routable.

## Detail resolver pattern

When a table column needs to display a foreign-key name (e.g. `channelId` → channel name), use a Suspense-wrapped resolver:

```tsx
function ChannelName({ channelId }: { channelId: string }) {
  const workspaceId = useWorkspaceId();
  const { data: channel } = useSuspenseQuery(
    channelQueries.detail({
      path: { channelId, workspaceId },
      headers: { "X-Workspace-Id": workspaceId },
    }),
  );
  return <span>{channel.title || channelId}</span>;
}

// Usage in column definition
<Suspense fallback={<span>{row.channelId}</span>}>
  <ChannelName channelId={row.channelId} />
</Suspense>
```

TanStack Query deduplicates — multiple rows referencing the same channel make one request.

## Forms

See [forms.md](./forms.md) — the `useAppForm` factory, field registration, the `Field`/`FieldError` anatomy, the muted-variant rule, `SubscribeButton`, and the escape-hatch table.

## Route-level features

TanStack Router provides per-route configuration for loading and error states:

```typescript
export const Route = createFileRoute("/_authed/_workspace/buying/flows")({
  loader: ({ context }) => {
    context.queryClient.ensureQueryData(flowQueries.list(request));
  },
  component: FlowsPage,
  pendingComponent: FlowsPageLoader,     // replaces loading.tsx
  errorComponent: FlowsErrorPage,        // replaces error.tsx
  notFoundComponent: FlowsNotFound,      // replaces not-found.tsx
});
```

## Provider stack

Root layout (`__root.tsx`) wraps the app in this provider order:

```typescript
// src/routes/__root.tsx
import { createRootRouteWithContext } from "@tanstack/react-router";
import type { QueryClient } from "@tanstack/react-query";

interface RouterContext {
  queryClient: QueryClient;
}

export const Route = createRootRouteWithContext<RouterContext>()({
  component: RootComponent,
});

function RootComponent() {
  return (
    <html>
      <head>{/* meta, css */}</head>
      <body>
        <ThemeProvider attribute="class" defaultTheme="system" enableSystem>
          <NuqsAdapter>
            <Toaster />
            <Outlet />
          </NuqsAdapter>
        </ThemeProvider>
        <TanStackRouterDevtools />
        <ReactQueryDevtools />
      </body>
    </html>
  );
}
```

**Key difference from Next.js:** QueryClientProvider is handled by the router integration (`setupRouterSsrQueryIntegration`), not a manual provider wrapper.

## Design system

### Semantic color tokens (Tailwind v4)

```css
/* src/styles/styles.css */
:root {
  --background: #eff0f3;
  --foreground: #111113;
  --card: #ffffff;
  --surface: #f2f2f4;
  --muted: #f2f2f4;
  --border: oklch(...);
  --popover: #ffffff;
  --accent-primary: oklch(...);
  --accent-primary-subtle: oklch(...);
}

.dark {
  --background: #05010d;
  --foreground: white;
  /* ... dark overrides */
}
```

**Rule:** NEVER use raw colors (`text-white`, `bg-purple-400`). Always use tokens (`text-foreground`, `bg-accent-primary`).

### Typography tokens (semantic type scale)

Semantic roles replace raw Tailwind text-size utilities. Values match Tailwind's default ramp verbatim, so migrating is a pure rename with zero visual change:

| Raw Tailwind | Semantic role | Size / line-height | Usage |
|--------------|---------------|--------------------|-------|
| `text-3xl` | `text-display` | 30px / 36px | Page hero titles, splash screens |
| `text-2xl` | `text-title-lg` | 24px / 32px | Section headers, major emphasis |
| `text-xl` | `text-title` | 20px / 28px | Subsection headers |
| `text-lg` | `text-title-sm` | 18px / 28px | Dialog titles, list row titles |
| `text-base` | `text-body-lg` | 16px / 24px | Input content, long-form prose |
| `text-sm` | `text-body` | 14px / 20px | Standard body, table cells (app default) |
| `text-xs` | `text-body-sm` | 12px / 16px | Meta, help text, badges, timestamps |

Plus three semantic-only roles (hand-applied, no raw-size equivalent):

| Role | Size / line-height | Notes |
|------|--------------------|-------|
| `text-label` | 14px / 20px | Form labels, table headers — intrinsic weight 500 |
| `text-caption` | 12px / 16px | Figure captions, muted assist text |
| `text-code` | 14px / 20px | Code blocks — always pair with `font-mono` |

**Rules:**
- NEVER use raw Tailwind text sizes (`text-xs` … `text-3xl`). Wipe them from the build (`--text-*: initial;` in the theme CSS) so a raw utility renders nothing.
- Pick the role by visual hierarchy, not DOM depth — three nesting levels might all be `text-body`.
- Roles bundle size + line-height only; color is a separate token, weight overrides (`font-semibold`) are allowed.
- **CI guard:** back the convention with a check script (e.g. `scripts/check-type-scale.ts`, run as `bun scripts/check-type-scale.ts` in CI) that greps `src/` for reintroduced raw sizes and fails the build.

### Text overflow

`truncate` is `overflow-hidden text-ellipsis whitespace-nowrap` — three declarations that do
nothing until something bounds the element's width. Inside a centred column nothing does: `flex
flex-col items-center` sizes every child to its own content, so a label grows to `max-content` and
a long string spills out **both** sides of the card. Centred overflow cuts the *first* word off
the left edge instead of ellipsing the last one on the right, so it reads as a broken layout
rather than as truncated text — which is why it survives review.

- **Centred column** (`items-center`) → `w-full` on the truncating child.
- **Flex row** → `min-w-0` on the shrinking cell. A flex item's automatic minimum size is its
  content; `truncate` on the flex item *itself* carries `overflow-hidden`, which zeroes that
  minimum, so `flex-1 truncate` needs nothing extra while a truncating child inside a plain
  `flex-1` wrapper does.
- **Grid cell** → `min-w-0` on the cell, for the same reason (`auto` minimum track size).
- Pair truncation with `title` or an accessible tooltip, so the full string stays reachable.

Whether to truncate at all is a separate call: one line for **destinations** — nav rows, tiles
that align across a grid — and `line-clamp-2` for **records** whose name carries the information.
Verify against the longest string the data actually holds; languages with long compound nouns make
that the common case, not an edge case.

### Button variants

| Variant | Use case |
|---------|----------|
| `default` | Primary action (purple gradient) |
| `secondary` | Secondary action |
| `tertiary` | Tertiary/subtle action |
| `ghost` | No background, hover reveals |
| `outline` | Accent text with border |
| `toolbar` | Toolbar actions |
| `destructive` | Delete/danger actions |
| `link` | Text-only link style |
