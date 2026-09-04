# Visual language for product pages

Beautiful product UI comes from legible structure, deliberate density, and coherent repetition.
Novel decoration cannot rescue weak information architecture.

## Composition

- Give page one dominant task and one unmistakable visual anchor.
- Build hierarchy through scale, weight, spacing, and placement before color or ornament.
- Prefer few strong regions over grids of interchangeable cards. A card earns border and surface
  only when grouping or interaction needs containment.
- Align repeated content to shared axes. Use deliberate asymmetry for emphasis, not accidental
  offsets.
- Keep controls close to content they affect. Global actions live with page identity; local actions
  live with local object.
- Spend visual weight on decisions and exceptions. Routine metadata stays quiet.

## Density

Match density to task frequency. Operational surfaces favor scan speed and comparison; exploratory
surfaces can breathe more. Dense means compressed rhythm with preserved grouping, not smaller text
and reduced hit targets.

Use a small spacing vocabulary already encoded by consumer tokens. Larger gaps separate concepts;
smaller gaps express relationships. Repeated structures keep one rhythm across states.

## Typography and color

Use consumer's semantic type and color tokens. Typography establishes page hierarchy; color adds
meaning after hierarchy works in grayscale.

Reserve accent for current focus, primary action, selection, or domain meaning. Status colors map
to stable semantics. Muted text remains readable. Borders separate only where whitespace cannot.

## Interaction and states

Every interactive element communicates affordance, current state, and result. Hover cannot carry
meaning unavailable to touch or keyboard users. Motion explains causality or spatial change;
otherwise omit it. Respect reduced-motion preference.

Loading preserves final geometry. Empty state explains absence and next action. Error state remains
visible beside failed work. Disabled state explains why when reason is not obvious.

## Local truth

Consumer's existing shell, tokens, primitives, content vocabulary, and accepted pages define its
style. This document supplies judgment criteria, not substitute design system. New page should feel
inevitable in that product while making its hierarchy sharper.

## Review test

At each target viewport, inspect rendered page and answer:

1. What attracts eye first, second, third? Does order match task?
2. Can user locate primary action, current context, and exceptional state within seconds?
3. Which border, surface, label, icon, or control could disappear without losing meaning?
4. Do repeated objects align and scan as one system?
5. Does narrow layout preserve task priority rather than merely stack desktop regions?
