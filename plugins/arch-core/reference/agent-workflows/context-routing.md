# Resolve the owning workspace

Before applying stack doctrine, resolve the target file or requested feature to its owning
workspace. The repository root may only orchestrate several apps; its dependencies do not prove
which stack owns a nested file.

1. Read root AGENTS.md, then the owning app/package index and explicitly routed conventions.
   Resolve relative pointers from the file declaring them, unless it declares another base.
2. Read the owner's package.json and framework configuration. Use the nearest owning package,
   not an unrelated root package. For a new file, use its intended parent workspace.
3. Load only matching stack references. A marketing app on an unsupported stack does not inherit
   a sibling application's framework rules. Cross-app work loads each relevant owner separately.
4. Read accepted decisions and local exceptions before generic doctrine. Code proves implemented
   behavior; divergence from policy is a finding, not permission to silently reverse policy.
5. Identify a reviewed local implementation and its tests. Preserve project naming, monetary
   units, error protocol and public interfaces; generic examples do not establish business facts.

Keep essential safety and task routing in the index. Load other conventions when their trigger
matches, regardless of whether the document lives in conventions/ or patterns/. Claude imports
expand content; splitting imports does not lower context load. Other runtimes must explicitly
follow the pointers they need rather than assume Claude import behavior.

## Runtime and installation boundaries

A skill is a workflow, not proof that a named agent, connector, or hook is available. Check actual
runtime capabilities. Use equivalent read/search/shell tools when available; a Claude agent's
frontmatter is not a mandate to change models or grant tools in another runtime. A read-only
workflow stays read-only even when the host supplies write tools.

Resolve bundled references relative to the current SKILL.md or agent document. A plugin must
remain usable when installed alone in a cache directory. If a required sibling plugin is absent,
report the missing reference instead of guessing its path. Never infer loaded state from cache
presence. Installation, enablement and live session loading are different claims.

A skills-only installation must retain the bundled references and workflows reached by the
entrypoint. If an installer copies only the skill folder, use the native plugin package instead.
