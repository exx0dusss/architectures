---
name: registry-audit
description: Audit a shadcn-style component registry for quality, token discipline and multi-app compatibility. Use before publishing a registry change, after adding a component, or when one consuming app renders a registry component wrongly and another does not.
tools: Read, Grep, Glob
model: haiku
---

# Registry component audit

Read-only. Scan every component in the registry's component directory — the path the workspace's
`registry.json` declares — for quality and consistency. Report; fix nothing.

A registry is published to more than one app by definition. That is what makes this audit
different from a component review: a component can be correct in the app it was written for and
still be wrong in the registry, because the registry promises it works in the others too.

## What to check

### Structure

- [ ] All components carry `data-slot` on the root and on sub-elements
- [ ] Interactive components build on Base UI / shadcn primitives, not bare DOM handlers
- [ ] CVA carries style variants — not inline ternaries
- [ ] Both the component and its variants function are exported: `export { Button, buttonVariants }`

### Tokens

- [ ] No hardcoded colours — semantic tokens only
- [ ] No `bg-white`, `text-white`, `bg-black` — the semantic token for that surface instead
- [ ] **No raw palette values.** A palette name is the giveaway: a token that names a colour rather
      than a role belongs to one app's theme, and shipping it in a registry exports that app's
      brand to every consumer

### Multi-app compatibility

This is the section that earns the audit. Each consuming app has its own base surface, and a
component hardcoded against one is broken in the other before anyone opens it.

- [ ] Components render correctly on **every** base surface a consumer uses, not just the one they
      were written against
- [ ] Surface-dependent styling is a variant prop, never a hardcoded background
- [ ] Dark-surface support wherever the component can land on one

### API stability

- [ ] No removed or renamed props against the previous version — a registry consumer upgrades on
      its own schedule and cannot see your rename coming
- [ ] New props are optional, with defaults
- [ ] No app-specific logic. A branch that names one consuming app is a leak, and the registry is
      the wrong place to resolve it

## Output

List violations grouped by component file, with line numbers and a specific fix for each.

If the registry currently has **no consumers**, say so first and stop ranking by severity — every
finding is theoretical until something imports it, and that fact belongs at the top of the report
rather than discovered at the bottom.
