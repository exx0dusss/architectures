#!/bin/sh
# Nudge toward module-boundary doctrine when a file inside a domain module is touched.
# Reads the tool payload from CLAUDE_TOOL_INPUT; stays silent for every other edit.

set -u

printf '%s' "${CLAUDE_TOOL_INPUT:-}" |
    grep -qE 'src/modules/[a-z-]+/' || exit 0

# Only speak up when the edit actually reaches across a module boundary or inverts a layer.
printf '%s' "${CLAUDE_TOOL_INPUT:-}" |
    grep -qE "modules/[a-z-]+/(application|infrastructure|domain)|from '[^']*modules/|from \"[^\"]*modules/" || exit 0

echo 'Module internals touched — modules never import each other (shared excepted); use a {module}.{action} domain event. Invoke the arch-modules skill.'
