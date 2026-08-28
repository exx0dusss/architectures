# Component Architecture

Atom-molecule-organism layering with category folders and colocated page components.

## Component layers

```
1. Atoms            → components/ui/           (Radix/shadcn primitives, CVA variants)
2. Molecules        → components/{category}/   (badges/, buttons/, form/, filters/)
3. Organisms        → components/{domain}/     (data-fetching, domain-specific)
4. Page-specific    → app/.../{resource}/_components/
```

### Layer rules

| Layer | Data fetching | CVA variants | Example |
|-------|:------------:|:------------:|---------|
| Atom | Never | Yes (style-only) | `Button`, `Badge`, `Select` |
| Molecule | Never | No (uses atom variants) | `EnumBadge`, `TextField`, `FilterChip` |
| Organism | Yes (`useSuspenseQuery`, `useMutation`) | No | `OrderStatusBadge`, `FollowButton`, widget lists |

**Folder naming:** Use UI category names (`badges/`, `buttons/`, `inputs/`), not abstract layer names (`molecules/`, `organisms/`). Category names are findable; layer names are ambiguous.

**Registry rule:** If a component is installed from shadcn (or a custom registry), it stays in `ui/` — even if it composes other atoms internally.

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

## Page-specific components (`_components/`)

Every table/list page colocates its components in a private `_components/` folder:

```
src/app/.../buying/flows/
├── page.tsx
└── _components/
    ├── columns.tsx                 # TanStack Table column definitions
    ├── flows-table.tsx             # Table component
    ├── flows-toolbar.tsx           # Search, filters, bulk actions
    ├── flows-header.tsx            # Page title, create button
    ├── flows-page-loader.tsx       # Suspense skeleton
    └── modals/
        ├── flow-create-dialog.tsx
        └── flow-delete-confirm-alert.tsx
```

**Convention:** Prefix all page-specific components with the resource name (`flows-table`, `flows-toolbar`).

## Detail resolver pattern

When a table column needs to display a foreign-key name (e.g. `channelId` → channel name), use a Suspense-wrapped resolver:

```tsx
function ChannelName({ channelId }: { channelId: string }) {
  const { workspaceId } = useWorkspace();
  const { data: channel } = useSuspenseQuery(
    channelQueries.detail({
      path: { channelId, workspaceId: workspaceId! },
      headers: { "X-Workspace-Id": workspaceId! },
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

See [forms.md](./forms.md) — the `useAppForm` factory, field registration, validation, `ApiResult` submission, and multi-step wizards.

## Provider stack

Root layout wraps the app in this provider order:

```
<MswInit>                    # MSW mock initialization (dev only)
  <ThemeProvider>            # Light/dark theme
    <QueryClientProvider>    # TanStack Query
      <NuqsAdapter>          # URL state (nuqs)
        <ToastProvider>      # Toast notifications
          <AuthProvider>     # Auth session context
            <WorkspaceProvider>  # Active workspace
              <HydrationBoundary> # Server→client query hydration
                <SidebarProvider>  # Sidebar open/close state
                  {children}
                </SidebarProvider>
              </HydrationBoundary>
            </WorkspaceProvider>
          </AuthProvider>
        </ToastProvider>
      </NuqsAdapter>
    </QueryClientProvider>
  </ThemeProvider>
</MswInit>
```

## Design system

### Semantic color tokens (Tailwind v4)

```css
/* src/styles/globals.css */
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

### Typography tokens

| Token | Size |
|-------|------|
| `text-heading-2xl` | 32px |
| `text-heading-xl` | 30px |
| `text-heading-large` | 24px |
| `text-body-large` | 16px |
| `text-body` | 14px |
| `text-body-small` | 12px |

**Rule:** NEVER use raw Tailwind text sizes (`text-sm`, `text-xs`, `text-lg`). Always use typography tokens.

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
