#!/bin/sh
# Nudge toward migration doctrine when a schema or migration file is touched.
# Reads the tool payload from CLAUDE_TOOL_INPUT; stays silent for every other edit.
#
# The failure this prevents is expensive and quiet: `drizzle-kit push` diffs against
# the live database, cannot express extensions, functional indexes, triggers or
# partitions, and offers to DROP the ones it cannot see.

set -u

payload="${CLAUDE_TOOL_INPUT:-}"

printf '%s' "$payload" |
    grep -qE 'database/schema/|drizzle\.config|/migrations/|\.sql"' || exit 0

echo 'Schema or migration touched — generate + review + migrate, never push. Invoke arch-services for the data layer, and read the migration SQL before committing it.'
