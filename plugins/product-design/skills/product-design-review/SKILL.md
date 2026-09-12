---
name: product-design-review
description: Review rendered product pages or prototype variants against local design conventions.
---

# Product design review

Read the owning workspace's AGENTS.md and task-specific conventions first. Resolve their paths
from the declaring file, not the shell's current directory. Then read and perform [rendered review](../../agents/product-design-review.md).

This skill is the portable entrypoint to the packaged workflow. Run it directly with the host's
available read/search/shell tools; a named Claude agent is optional. Ignore that document's
Claude-specific model/tool frontmatter outside Claude, not its task constraints.

Keep review read-only: no edits, commits, production mutations or automatic PR comments.
Report actual scope, evidence and commands run. A missing tool/reference is an evidence gap,
not permission to invent results. Do not claim runtime loading or visual verification from
package presence or source inspection alone.
