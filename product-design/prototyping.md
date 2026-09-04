# Product prototyping

## Purpose

Product prototypes answer layout, hierarchy, or interaction questions inside the real product.
They may replace unfinished integrations with realistic data, but retain production structure.

Prototype means **replaceable uncertainty**, not disposable UI. Route, shell, navigation, design
system, URL behavior, states, accessibility, and responsive behavior remain real.

## Required shape

1. **Question** — name decision prototype must resolve. Variants differ on that decision rather
   than decorating same composition.
2. **Stable surface** — build at intended product route or entry point, inside real shell.
3. **Source map** — inspect local conventions, tokens, components, and at least two neighboring
   surfaces before choosing structure.
4. **Replaceable boundary** — put fake data or unfinished integration behind typed seam matching
   planned contract. Rendering code cannot know which implementation supplied data.
5. **Real states** — loading, empty, partial, dense, error, disabled, and permission states use
   same primitives and behavior production surface will keep.
6. **Shareable controls** — put variant and meaningful filter state in URL. Gate prototype-only
   controls from production without creating parallel navigation or shell.
7. **Acceptance** — record winning variant and reason, delete losing variants and controls, then
   replace boundary implementation without rebuilding accepted page.

## Source order

Use sources in this order:

1. Consumer's instruction index and explicit product/design docs.
2. Existing neighboring product surfaces and semantic components.
3. Consumer's tokens, primitives, route conventions, and test helpers.
4. External references for hypotheses only.

Existing component wins by semantic contract, not visual resemblance. Search before writing.
Before composing a major primitive, follow [component source routing](./component-sources.md): load
provider skill, query provider MCP or official docs, inspect local wrapper, then inspect existing
usage. When no component fits, name semantic gap before adding one; place new component in normal
product layer rather than hiding it inside prototype.

## Verification

Visual completion requires rendered evidence:

- exercise every variant at representative wide and narrow viewports;
- exercise layout-changing overlays and relevant data states;
- capture screenshots and inspect images, not only DOM assertions;
- verify route and browser history, keyboard path, focus visibility, overflow, console errors, and
  stable key geometry;
- run consumer's relevant tests, typecheck, lint, and design-system audits.

Handoff names question, route, variants, source map, mock seam, screenshots, commands, winner or
remaining decision, and known gaps.
