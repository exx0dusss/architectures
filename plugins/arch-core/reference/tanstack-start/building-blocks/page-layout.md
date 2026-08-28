---
status: stable
---

# Page layout — the 8-pattern taxonomy

Every admin/CRM page fits one of eight patterns, chosen **before** coding and stated in the plan. The patterns are not a style guide — they are a hard contract; deviating is what creates visual drift. If no pattern fits, stop and discuss before inventing a new one.

## The app shell

The whole app is: sidebar + global header + **ONE rounded content shell** that holds all page content. The shell has **zero inner padding** — content mounts full-width and owns its own background, padding, and margin. That is what lets radically different layouts share one shell without divergence. Rules:

1. Never add padding to the shell; if a layout needs a gutter, the page adds it.
2. Never wrap page content in a second rounded card — the shell is the only frame. Two rounded boxes = drift.
3. Page chrome (toolbar / header bar) sits flush at the top of the shell; only content is carded.

## The eight patterns

| Pattern | Use when | Chrome |
|---------|----------|--------|
| **A — Full-table** | Single-entity CRUD; the list IS the page | Toolbar flush at the top + full-bleed `DataGrid` (one slab, no inner card) |
| **B — Bento** | Heterogeneous widgets; no list dominates | `PageHeader` in the route, grid of `Card`s / `StatRow` |
| **C — Hybrid** | One list + context stats above it | `PageHeader` + `StatRow` + detached `SectionTable` |
| **D — Split-pane** | Thread/conversation browsing | Inner sidebar (thread list) + detail outlet |
| **E — Feed** | Chronological activity stream, date-grouped | Filter toolbar + date-grouped `Item` lists |
| **F — Sectioned Editor** | `$id` editor with ≥5 mixed-purpose form sections | Detail chrome; `SectionNav` left, sectioned Cards center, meta rail right, `DirtyBar` bottom |
| **G — Entity Detail** | `$id` page that isn't a sectioned editor | Detail chrome; single body, sidebar+body, or sub-view tabs |
| **H — Split-Pane Editor** | `$id` editor where a live sample/preview is essential (template DSLs, prompts, formulas) | Detail chrome; resizable editor + preview panes, `DirtyBar` bottom |

## Decision flow

```
$id detail/edit route? → use detail-page chrome (header bar with back · title · actions), then:
  live preview essential to authoring?          → H
  editor body has ≥5 mixed-purpose sections?    → F
  otherwise                                     → G
Non-detail page:
  browsing threads/conversations?               → D
  chronological activity stream?                → E
  one list dominates + context stats needed?    → C
  one list dominates, no stats?                 → A
  heterogeneous widgets?                        → B
```

Hesitating between B and C: if there is one table you'd hate to lose, it's C; if removing the table still leaves a useful page, it's B with a detached table. Between F and G: count form sections — ≥5 mixed-purpose Cards → F; a few sub-view tabs alone do NOT make an F.

## Composition law (applies to all patterns)

1. **Containers with border/shadow → `Card`.** Never hand-write `rounded-xl border bg-card`.
2. **List rows → `Item` + `ItemGroup`** with `ItemSeparator` dividers. Never `flex items-center gap-3 px-2 py-2`.
3. **Stats → `StatCard` inside `StatRow`.** Emphasis is all-or-none across a row — never 1-of-4.
4. **Title/subtitle → `PageHeader`** on non-detail routes; the detail header bar on `$id` routes. Never inline `<h1>` + description div.
5. **Tables → `DataGrid`** (full page) or `SectionTable` (embedded). Never wrap a table in a `Card` — grids are self-carding.
6. **The route owns page chrome; components render body only.**
7. **No hand-rolled headers, tab bars, or sidebars** — use the shared primitives.
8. **Domain components render naked bodies.** A component in `components/{domain}/` must not wrap itself in `<Card>` — the first caller that puts it inside another Card produces card-in-card drift. The caller owns the container.
9. **No card-in-card, ever.** Need a distinct group inside a Card? Heading + `ItemSeparator` + `ItemGroup`. A card that must host other cards uses a muted variant so surface treatments don't stack.
10. **Route entrance via CSS View Transitions** (router-level `defaultViewTransition`), not per-route `motion.div` opacity wrappers — those serialize invisible HTML into SSR and strand the page if hydration stalls.

**Rule of thumb before writing JSX:** if you are reaching for `rounded-xl`, `border border-border`, `px-2 py-2`, or `flex items-center gap-3` outside a primitive's internals, stop — you are about to drift. Grep the primitives first.

## Detail-page chrome (orthogonal to F/G/H)

Any `$id` route composes a header-slot portal + a single-row header bar: back link (required — points at the list route) · entity title · actions · optional inline tabs. Sub-view tab state lives in the URL (`validateSearch` with an optional enum; default tab = param dropped). Every sub-view/tab body sits inside ONE white panel card — tab content must never float on the page background next to a white sidebar.

## Fixed-height grid rule

Any card grid (StatRow, KPI row, widget grid) must have stable row height. Elements that vary in content (stat with/without delta) reserve the space (`reserveDelta`-style props, `min-h`, empty footer slots) so missing content collapses to transparent space, not height loss. Mixed heights on one visual row is the #1 tell of a hand-rolled layout.

## Plan requirement

Every plan touching UI states: the pattern (A–H), the reference page, and the primitives used/extracted. `$id` routes additionally state the detail chrome composition (back target, actions, sub-view tabs). Plans missing this get rejected in review — the requirement is what keeps the taxonomy enforced.
