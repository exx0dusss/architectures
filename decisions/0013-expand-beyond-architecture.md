---
id: 0013
title: Expand marketplace from architecture blueprints to engineering playbook collections
date: 2026-09-04
status: Accepted
supersedes: []
superseded_by: []
tags: [distribution, plugins, product-design, repository-scope]
---

# ADR-0013 — Expand marketplace from architecture blueprints to engineering playbook collections

## Context

Repository began as stack architecture blueprints. It now also owns contribution doctrine,
decision workflows, promotion tooling, and general audit agents. Those capabilities are reusable
engineering judgment, but calling every one architecture obscures their boundaries.

A consumer also proved a product prototyping workflow: build design variants inside real app, keep
mock data behind replaceable seam, and accept variant from rendered evidence. Workflow is general;
consumer's CRM names, routes, components, and test files are not. Keeping general workflow local
would repeat split ownership that plugin distribution removed.

## Decision

Repository becomes personal engineering playbook with architecture as one collection, not entire
scope. New top-level collections may own browsable source docs and ship dedicated plugins whose
skills and agents apply those docs.

Collection qualifies when:

- doctrine captures reusable judgment rather than consumer facts;
- skill or agent turns doctrine into repeatable work;
- consumer's local conventions remain authoritative for implementation detail;
- plugin can be installed independently unless real dependency requires otherwise.

First new collection is `product-design`. It owns product prototyping and visual-language docs,
`product-prototype` execution skill, and `product-design-review` agent. Generated plugin references
preserve same source-doc/bundled-doc model used by architecture doctrine.

Repository name and existing `arch-*` plugin names remain unchanged. Their contracts are stable;
broader marketplace description and non-`arch` plugin namespace communicate expanded scope without
migration churn.

## Consequences

Repository gains explicit home for design, documentation, quality, and other engineering practices
that meet generality test. New collection must still resist becoming miscellaneous notes: docs
without execution path or consumer-specific playbooks remain out.

Marketplace can grow by domain rather than forcing unrelated behavior into `arch-core`. Consumers
install only collections they need. Shared build script and CI now verify generated references for
multiple plugins.

## Compliance

`scripts/check-plugin-versions.sh` verifies every marketplace entry maps to matching plugin manifest.
`scripts/build-skill-refs.sh --check` verifies bundled product-design docs match root source. Scope
and generality remain manual, supported by `consumer-leak-auditor`.

## Alternatives rejected

| Alternative | Why rejected |
|-------------|--------------|
| Keep all reusable tooling under `arch-core` | Makes architecture label meaningless and forces unrelated workflows into every architecture consumer. |
| Rename repository and every plugin | Breaks established marketplace and project configuration without improving collection boundaries. |
| Keep prototype workflow in originating consumer | General workflow stays invisible and can drift while multiple projects recreate it. |
| Ship skill without source docs | Hides judgment inside execution recipe, making doctrine hard to browse, review, and reuse from future skills or agents. |
