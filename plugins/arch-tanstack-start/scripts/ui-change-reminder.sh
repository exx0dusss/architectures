#!/bin/sh
# Nudge toward the component/token doctrine when a styling-sensitive file is touched.
# Reads the tool payload from CLAUDE_TOOL_INPUT; stays silent for every other edit.

set -u

printf '%s' "${CLAUDE_TOOL_INPUT:-}" |
    grep -qE 'components/ui/|components/[a-z-]+/|styles/|globals\.css|tailwind' || exit 0

echo 'UI surface changed — invoke the arch-ui skill before adding variants, colours, or text sizes.'
