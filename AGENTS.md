# Architectures maintainer index

Generic doctrine and reusable agent workflows. Consumer business facts stay downstream.

- Edit source docs in nextjs/, tanstack-start/, nestjs-backend/, product-design/,
  contributing/ or agent-workflows/; regenerate plugin reference copies rather than editing them.
- Work in an isolated branch/worktree. Preserve unrelated commits and consumer checkouts.
- Before reversing doctrine or distribution rules, read DECISIONS.md and use arch-decision.
- Before changing source comments, commits or PR bodies, read the matching contributing/ doc.
- Before adding a skill/workflow, read agent-workflows/context-routing.md; keep host adapters thin,
  local exceptions authoritative, and packaged reference paths resolvable from an isolated install.
- Before promotion, read decisions/0006-blueprint-independent-of-consumers.md. Keep project paths,
  ticket identifiers, carrier APIs, currencies and brands out of generic doctrine.
- After hook changes: python3 scripts/build-hook-helpers.py.
- After source reference changes: sh scripts/build-skill-refs.sh.

## Verification

Run applicable tests plus all publication checks:

```bash
python3 -m unittest discover -s scripts/tests -v
python3 scripts/build-hook-helpers.py --check
sh scripts/build-skill-refs.sh --check
sh scripts/check-plugin-versions.sh
sh scripts/check-consumer-leaks.sh
sh scripts/check-decisions.sh --strict
```

Skill metadata/link checks do not prove behavioral correctness. Forward-test substantial
workflows against realistic tasks without providing the expected answer to the evaluator.
