---
status: stable
---

# Enumeration controls — icons on options AND on the trigger

Any control rendering a **known finite enumeration** — status, type, scope, role,
payment gateway, severity, rating, delivery method — gives every option a
distinguishing `icon`. Icons turn a wall of same-length text labels into
scannable glyphs and make the control read as intentional rather than stubbed.

Exempt: free-text lookups (customer search, product search), paginated
collections, and any list the author cannot enumerate at compile time.

Related: a value from a finite set is never collected as free text — see
[components](../components.md) for the layering and the `EnumBadge` sibling
pattern that renders the same enumerations read-only.

## The half that gets forgotten: the trigger

A filter at rest renders only its **placeholder**. So a toolbar of bare
`Status` / `Type` / `Scope` reads as unstyled text sitting next to a solid CTA,
while every option hidden behind it is iconed. The options were done; the
surface the operator actually looks at was not.

Give the selector ONE resolution chain for the empty trigger, so callers have a
choice and reviewers have a single thing to grep:

```tsx
// inside the Selector molecule
const resolvedEmptyIcon = allOption?.icon ?? emptyIcon ?? placeholderIcon
```

Any one of the three covers a call site:

```tsx
// multi-select, or single-select with no "All …" row → placeholderIcon
<Selector
  multiple
  placeholder={t.status}
  placeholderIcon={<ActivityIcon className="size-4" />}
  options={STATUS_OPTIONS}
/>

// single-select with an "All …" row → put the glyph there
<Selector
  placeholder={t.rating}
  options={RATING_OPTIONS}
  allOption={{ label: t.allRatings, icon: <StarIcon className="size-4" /> }}
/>
```

## Rules

1. **The placeholder icon names the AXIS, never a value.** The options already
   name the values. `Activity` = status/state, `Tag` / `Shapes` = type/kind,
   `Target` = scope, `Power` = enabled/disabled, `Star` = rating, `Wallet` =
   gateway. Reusing an option's own glyph makes an *unset* filter claim a value
   it does not hold.
2. **Filter chrome only.** A form selector sits under a field label inside a
   `Field`, which already names the axis — a trigger glyph there is noise. Keep
   the rule scoped or the next sweep "fixes" every labelled form control in the
   app — in a mature codebase that is well over a hundred call sites that are
   correct exactly as they stand.
3. **Grep the opening tag, not the option array — and count `allOption.icon` as
   covered.** A checker that looks only for `placeholderIcon` reports an order of
   magnitude too many hits.

## Why rule 3 is stated so bluntly

Measured on a mature codebase:

| Scan | Uncovered call sites |
|---|---|
| naive (`placeholderIcon` \| `leadingIcon` present?) | 160 |
| fallback-aware (also `emptyIcon`, `allOption.icon`) | **10** |

Every one of the 10 sat in a single module family that had never opted in
(promotions, campaigns, editorial stories, inventory, webhooks, egress
destinations) — against **zero** in the modules that passed `placeholderIcon`
from the start. A drift this cleanly clustered is a copy-paste lineage, not a
codebase-wide decay: find the first file in the family and the rest follow.

The separate scan for option sets with no icons at all found 9, and all 9 were
numeric (page size, row limit, period) — enumerations where a glyph per option
would add nothing. The read-side risk this rule guards against lives in the
*labels*, not the counts.
