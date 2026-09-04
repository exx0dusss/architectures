---
name: product-prototype
description: Build or review high-fidelity product pages inside a real app when UI needs design variants, realistic mock data, interaction exploration, or a pre-integration vertical slice. Excludes detached marketing mockups and throwaway static comps.
---

# Product prototype

Build prototype as real product surface with replaceable uncertainty. Prototype depth may stop at
integration boundary; product structure and visual quality do not.

## Calibrate

1. Read consumer instruction index and locally referenced product, design, component, routing, and
   testing docs. Local rules outrank bundled doctrine.
2. Read [product prototyping](../../reference/prototyping.md),
   [component source routing](../../reference/component-sources.md), and
   [visual language](../../reference/visual-language.md).
3. State decision prototype must resolve.
4. For every major primitive or composition pattern, identify provider, load its installed skill,
   obtain project context through provider-supported command, inspect registry source/examples via
   MCP, then inspect matching official API docs, local wrapper, and existing usage.
5. Inspect at least two neighboring surfaces plus existing usage of every major semantic component
   needed. Derive source map: shell, navigation, layout pattern, tokens, component providers,
   wrappers, runtime states, and test helpers.

## Build

- Use intended route and real app shell. Add normal navigation entry; gate only unreleased entry and
  prototype controls when needed.
- Create genuinely different variants around named decision. Keep shared data and behavior behind
  one implementation so comparison tests composition rather than accidental code differences.
- Reuse semantic components and tokens. Name semantic gap before adding component.
- Put fake data or unfinished integration behind typed source/loader seam shaped like expected
  contract. Rendering components stay source-agnostic.
- Use validated URL state for shareable variant and filter state. Preserve browser history.
- Implement realistic loading, empty, dense, error, overlay, keyboard, and responsive behavior.

## Verify

Render every variant and layout-changing state at representative wide and narrow viewports. Capture
screenshots, inspect actual images, and iterate on hierarchy, alignment, density, overflow, and
responsive priority. Verify focus path, route/history behavior, console errors, and key geometry.
Run consumer's relevant tests, typecheck, lint, and design-system audits.

## Handoff

Report decision, route, variants, source map, provider skills and MCP/docs consulted, replaceable
seam, screenshot paths, verification commands, and gaps. After acceptance, delete losing variants and prototype controls. Preserve
accepted route and composition while swapping only boundary implementation.
