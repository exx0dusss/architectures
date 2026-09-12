---
name: arch-init
description: Initialize or re-sync blueprint integration when requested, including owning-workspace instructions and runtime capability checks.
stacks: [nextjs, tanstack-start, nestjs-backend]
---

# Initialize blueprint integration

Read [context routing](../../reference/agent-workflows/context-routing.md). Inspect requested
workspace, existing instructions, accepted decisions and runtime before proposing changes.
An implementation request already authorizing setup does not need another approval loop; missing
product/architectural choices still need clarification. Preserve existing work and permissions.

## Runtime capabilities

Claude: inspect actual plugin registration and project enablement before installing. Use the
Claude plugin CLI with project scope for team configuration. Core plus owning stack are needed;
product-design is optional for product UI work. Run this plugin's scripts/arch-sync-check.sh
with --check; --write explicitly records a snapshot. Registered is not loaded: verify capabilities
in a fresh session. Do not infer installed version from highest cache directory.

Codex: use native marketplace/plugin capabilities available in the host. Portable skill workflows
can run directly with equivalent tools; named Claude agents, hooks and permissions do not become
Codex capabilities by installation. Check entrypoint and reference resolution in the actual
installed package. Do not run Claude configuration commands as a Codex substitute. Report missing
capabilities and use supported host configuration rather than editing cached manifests.

Other skills installers: verify they retain the reference and agent files linked by each skill.
If they copy only SKILL.md folders, prefer native plugin installation; do not claim portability
from successful file copying alone.

## Consumer-owned setup

- Keep compact root/app AGENTS indexes: essential safety, owning-app map, task-triggered reference
  table and verification commands. CLAUDE.md may bridge with @AGENTS.md. Conventions load by task,
  not by directory name. Preserve useful incident history behind pointers. See ADR-0014 upstream.
- Existing domain/ADR paths win. Do not create parallel decision logs or empty context files.
- Check required capabilities, not a universal third-party skill shopping list. Backend setup
  does not require visual-design skills. Choose one provider per overlapping workflow.
- Preserve local tokens/primitives. Read components.json if present; a private component registry
  is optional, never a prerequisite. Different apps may intentionally own different components.
- Inspect installed dependency skill paths from declared pointer bases. For TanStack intent setup,
  use the project's package manager/version policy, not an unconditional latest global install.
- Permissions and MCP connections belong to their host. Apply only authorized additions and keep
  unrelated entries. A Claude allow/deny list is not evidence of enforcement in another runtime.

## Verification

Check every new pointer from its documented base, run existing documentation/package guards,
and verify a representative root-launched and app-launched task can find the owning instructions.
After updates, run the portable blueprint-drift workflow or available arch-drift agent. It audits
local patches without silently overwriting them.

Report actual runtime, owner, source/version, requested/installed/loaded capabilities, commands
run, changed consumer files and remaining gaps. Never fill a status table with example successes.
Promote reusable patterns only through the upstream promote-pattern workflow; consumer-specific
paths, tickets, currencies and integrations stay downstream.
