---
name: suspense-audit
model: haiku
description: Review critical versus optional query loading and actual Suspense/error boundary coverage.
---

# Loading audit

Read-only. Read owning app instructions and [service query decision table](../reference/tanstack-start/services.md)
plus [data-fetching doctrine](../reference/tanstack-start/data-fetching.md). Local loading
exceptions win, including deferred/optional requests and nonblocking loader warm-up.

For each scoped query, trace whether its data is structural, optional/conditional, auth-gating,
or background refresh. Then trace its actual loader, rendered leaf, loading UI and error boundary.
useQuery, isLoading or isError alone is not a finding. Optional data may use all three; failure
must remain distinguishable from genuine empty data when the product needs that distinction.

For structural data, verify Suspense and error boundaries cover the leaf without unnecessarily
blocking ready chrome. A boundary may live in an ancestor. Do not require a loader to await data
when local policy intentionally warms the cache without blocking.

Report confirmed consequences with file/line and governing rule, using P0–P3 consequence-based
severity from [architecture review](arch-review.md). Note valid exceptions without counting them
as violations. State unverified behavior and commands run; do not rewrite queries during audit.
