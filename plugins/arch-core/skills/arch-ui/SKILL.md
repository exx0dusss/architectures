---
name: arch-ui
description: Use when creating or changing any component, deciding where a component file belongs, adding a CVA variant, writing Tailwind classes, picking a colour or text size, adding an icon, building a widget or list/item decomposition, rendering an enum as a badge, or adding a Suspense boundary and skeleton. Also use when a component looks inconsistent with the rest of the app, a colour or font size is hardcoded, or a shared component is about to be forked.
stacks: [nextjs, tanstack-start]
---

# Components and design tokens

Before stack detection, read [owning-workspace routing](../../reference/agent-workflows/context-routing.md).
Here `package.json` and local conventions mean the target's owning workspace, not necessarily
repository root. Unsupported sibling stacks do not inherit this skill.

**Applies only to repos built on the `exx0dusss/architectures` blueprint.** If this repo has no
`docs/architecture/` directory and no `AGENTS.md` naming one of these stacks, this skill does not
apply — stop and ignore it.

Four layers. A component's layer decides whether it may fetch data and whether it may own style
variants.

| Layer | Location | Fetches data | Owns CVA variants |
| --- | --- | :---: | :---: |
| Atom | `components/ui/` | Never | Yes |
| Molecule | `components/{category}/` | Never | No |
| Organism | `components/{domain}/` | Yes | No |
| Route-specific | `_components/` (Next.js) · `-components/` (TanStack Start) | Yes | No |

## Read the reference for this repo's stack

| `package.json` has | Read |
| --- | --- |
| `next` | `../../reference/nextjs/components.md`, plus the token and icon sections of `../../reference/nextjs/patterns.md` |
| `@tanstack/react-start` | `../../reference/tanstack-start/components.md`, plus the token, animation, and icon sections of `../../reference/tanstack-start/patterns.md` |

If the repo has its own `docs/architecture/components.md` or `docs/conventions/` equivalents,
read those instead — a consumer's local instantiation outranks the blueprint.

## Rules that decide most changes

- **Anything installed from a registry stays in `components/ui/`**, even if it composes other atoms.
- **Never fork an atom for a new look** — add a `variant` to its CVA config.
- **Category folders, not layer folders.** `badges/`, not `molecules/`. Category names are findable.
- **Promote out of a route's component folder only when a second route needs it.** Not before.
- **Every suspending component needs a real skeleton** matching the final layout. A bare spinner in place of a list is not an acceptable fallback.
- **Render enums through the shared badge component**, with the label and variant maps living next to the enum in its schema file, so one enum has one rendering everywhere.

## Scroll affordance

- Primary persistent content — page bodies, tables, long lists, logs, chat history, and important
  side panels — keeps native scrollbar affordance. Do not hide a scrollbar because it looks noisy.
- Secondary gesture-driven strips may hide the scrollbar only when a replacement cue exists:
  clipped content, a position-aware edge fade, arrows, dots, or equivalent controls. Preserve touch,
  wheel, keyboard, focus-into-view, and screen-reader access.
- `overflow: auto` / `overflow-y-auto` is the default for reachable content. `overflow: hidden` is
  for known clipping — media wells, masks, animation panels, rounded shells, and bounded controls —
  not for suppressing unknown overflow.
- Horizontal overflow must be discoverable. A partial card or chip counts as a cue; a primary table
  with hidden scrollbar and no other cue does not.
- Edge fades must follow scroll position. At a scroll boundary, first/last complete item stays fully
  clear; fade only content that is actually clipped. Static masks that fade both edges regardless of
  overflow or position are not scroll affordances.
- Avoid nested scroll containers. One owner per axis; reserve and paint scrollbar gutter wherever
  header/body alignment depends on it.

## Red flags — stop and re-read the reference

- A hardcoded colour class (`text-white`, `bg-white/[0.xx]`, `text-purple-400`, `bg-slate-500`) → use a semantic token (`text-foreground`, `bg-card`, `border-border`, …)
- A raw `var(--custom-*)` inline → use the Tailwind semantic class mapped to it
- A raw text-size utility (`text-sm`, `text-xs`, `text-lg`) → use the typography scale (`text-body`, `text-title`, `text-caption`, …), and guard it in CI. **Consumers that deliberately have no type scale must say so in their own conventions** — do not half-introduce one in a single component
- A new colour picked directly in a component → add the palette step, map it to a semantic token, then use the token
- A semantic token added without its dark-mode value in the same commit → both, always
- A status colour picked as some blue/green/red → use the status token set
- An enum→variant map inlined in a table column → use the shared badge component
- `strokeOpacity` / `fillOpacity` on an icon → put `opacity-*` on the element
- An icon imported from a second icon library when the primary one has it → keep the spread narrow
- `truncate` on a child of a centred column (`flex flex-col items-center`) or inside a flex/grid cell with no `min-w-0` → nothing bounds its width, so it never ellipses and the text spills out both sides. See the text-overflow section of the stack's `components.md`
- A UI primitive imported from anywhere but `components/ui/` → fix the import
- **(TanStack Start)** `asChild` on `Button` → Base UI uses the `render` prop: `<Button render={<Link to="/" />} nativeButton={false}>`
- A primary scroll container hides its native scrollbar without a persistent replacement cue → keep
  the platform affordance or add an equivalent.
- A scroll edge uses a static fade/mask → make edge state position-aware and boundary-safe.
