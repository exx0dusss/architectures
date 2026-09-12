---
status: stable
---

# Table actions — one descriptor, three surfaces

**A table declares its row actions ONCE, as a `RowAction[]`. The grid renders that one list into the `…` kebab column, the right-click context menu, and the selection footer's bulk bar.** Writing the kebab and the context menu as two separate arrays is how they drift apart (an action added to one and forgotten in the other, guards applied in one place only). A shared resolver makes mirroring structural rather than a convention someone has to remember.

## The descriptor

```tsx
interface RowAction<T> {
  key: string;
  label: string;
  icon?: LucideIcon;
  variant?: "default" | "destructive";
  separator?: boolean;              // divider before this item
  permission?: string;              // resolved once, by the resolver
  bulk?: boolean;                   // also appears in the selection footer
  hidden?: (row: T) => boolean;
  disabled?: (row: T) => boolean | string; // string = tooltip reason
  onSelect: (rows: T[]) => void;    // ALWAYS an array
}

const rowActions = useMemo<RowAction<Brand>[]>(() => [
  {
    key: "edit",
    label: t("common.edit"),
    icon: PencilIcon,
    permission: "catalog.brands.update",
    onSelect: (rows) => openEditor(rows[0]),
  },
  {
    key: "delete",
    label: t("common.delete"),
    icon: Trash2Icon,
    variant: "destructive",
    separator: true,
    permission: "catalog.brands.delete",
    bulk: true,
    onSelect: (rows) => setDeleteTargets(rows),
  },
], []);

<DataGrid table={table} enableRowSelection rowActions={rowActions} />
```

## Rules

1. **`onSelect` always receives an ARRAY.** Length 1 from the kebab or a single-row right-click, length N from the bulk bar or a right-click on a multi-row selection. A handler that only understands one row is what forces a second bulk code path into existence.
2. **Per-row variance uses `hidden(row)` / `disabled(row)`, never a `(row) => RowAction[]` factory.** Stable keys across rows are what make bulk resolution well-defined. `disabled` may return a **string**, which becomes the item's tooltip — a greyed-out item with no reason reads as a bug.
3. **`permission` is applied by the resolver.** Don't wrap items in permission components and don't hand-check `hasPermission` at call sites — that check existing in two places is exactly the drift this replaces.
4. **Only flag `bulk` on actions meaningful over a set.** "View" is not.
5. **Drop any hand-written `id: 'actions'` column when adopting `rowActions`** — the grid renders its own; leaving yours shows two kebabs.
6. **No second, menu-only escape hatch.** Do not add a `contextMenuItems`-style prop that feeds only the right-click menu — it re-creates the divergence one list exists to prevent. A shared table shell that needs domain extras exposes an `extraRowActions: RowAction[]` seam that merges into the ONE array.

## Context-menu semantics (Finder / VS Code behaviour)

| Right-click target | Menu acts on | Header |
|---|---|---|
| a row outside the selection | that row alone; selection untouched | — |
| a row inside a multi-row selection | the whole selection; non-`bulk` items drop out | "3 selected" |

Without this, right-clicking a selected row is ambiguous — the operator can't tell whether "Delete" means one row or forty.

## Bulk without a batch endpoint — `useBulkRunner`

Most resources only expose single-item DELETE/PATCH. A bulk runner fans one mutation out over a selection with a concurrency cap, live progress, and a partial-failure result the operator can retry:

```tsx
const bulkDelete = useBulkRunner<Brand>({
  run: (brand) => deleteBrandFn({ data: { id: brand.id } }),
});

<DataGrid
  bulkStatus={<BulkRunnerStatus state={bulkDelete.state} onRetry={bulkDelete.retryFailed} />}
/>
```

- **N requests are N transactions.** A partial failure leaves a partial result — report "38 ok, 2 failed [Retry]", never a bare success toast.
- **Call the server function, not a toasting mutation hook.** A hook that toasts and invalidates per call means 40 toasts and 40 refetches over a 40-row run. Invalidate once from `onSettled`.
- **Never hand-roll `for (const x of selected) await mutateAsync(x)`** — no progress, and one rejection silently aborts the rest.
- When a real batch endpoint lands, swap `onSelect` to call it and delete the runner. No UI changes.

## Bulk-bar layout

The selection footer partitions by variant, regardless of call-site order:

```
3 selected · [neutral ghost actions] │ [destructive solid-red group] ⟶ml-auto⟶ [Cancel]
```

- Neutral actions render as ghost buttons; destructive as solid red, last, behind a hairline divider.
- The cancel/clear-selection control pins to the far edge — never adjacent to a red button.
- Only genuinely irreversible actions get the destructive variant; reversible archive stays neutral.

## Parity

The embedded/section table takes the same `rowActions` / `enableRowSelection` / `bulkStatus` props with identical semantics, so an embedded table and a full-page grid behave the same. Bind the context menu to the `<tr>` via a render-prop trigger — a wrapper `<div>` between `<tbody>` and `<tr>` gets foster-parented out of the table by the HTML parser and desyncs hydration.

Legacy prop-driven kebabs (`onView`/`onEdit`/`onDelete`) remain correct only for **card and list-row kebabs** — surfaces with no row to right-click and no selection to bulk over. Never use them in a table column.
