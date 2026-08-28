#!/bin/sh
# build-skill-refs.sh — regenerate the reference docs bundled with the arch-core plugin.
#
# The source directories — the stacks (nextjs/, tanstack-start/, nestjs-backend/) and the
# stack-agnostic contributing/ — remain the single source of truth and stay browsable on
# GitHub. The arch-* skills ship inside a plugin, so they need those docs on disk next to
# them; this script copies them into
#
#   plugins/arch-core/reference/<dir>/
#
# Whole files only — no slicing, no concatenation — so the copy is trivially verifiable
# and a doc edit can never half-land. Run after editing any source doc. CI runs it and
# fails if the working tree changes (see .github/workflows/skill-refs.yml).
#
# Usage:
#   sh scripts/build-skill-refs.sh            # regenerate
#   sh scripts/build-skill-refs.sh --check    # regenerate into a temp dir and diff

set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
STACKS="nextjs tanstack-start nestjs-backend"
SHARED="contributing"
DEST="$ROOT/plugins/arch-core/reference"

CHECK=0
[ "${1:-}" = "--check" ] && CHECK=1 && DEST=$(mktemp -d)

for stack in $STACKS; do
    src="$ROOT/$stack"
    [ -d "$src" ] || { echo "missing stack dir: $stack" >&2; exit 1; }

    out="$DEST/$stack"
    rm -rf "$out"
    mkdir -p "$out"

    # Top-level docs. README.md is a stack index for humans, not doctrine — skip it.
    for f in "$src"/*.md; do
        [ -e "$f" ] || continue
        [ "$(basename "$f")" = "README.md" ] && continue
        cp "$f" "$out/"
    done

    # Copy-ready code templates, when the stack has them.
    if [ -d "$src/building-blocks" ]; then
        mkdir -p "$out/building-blocks"
        cp "$src"/building-blocks/*.md "$out/building-blocks/"
    fi
done

# Stack-agnostic doctrine. No README to skip here — every file is doctrine.
for dir in $SHARED; do
    src="$ROOT/$dir"
    [ -d "$src" ] || { echo "missing shared dir: $dir" >&2; exit 1; }

    out="$DEST/$dir"
    rm -rf "$out"
    mkdir -p "$out"

    for f in "$src"/*.md; do
        [ -e "$f" ] || continue
        cp "$f" "$out/"
    done
done

cat > "$DEST/README.md" <<'EOF'
# Bundled reference

**Generated — do not edit.** Every file here is a verbatim copy of a stack doc or a
contribution doctrine doc from the repository root, produced by
`scripts/build-skill-refs.sh`.

Edit the source (`nextjs/`, `tanstack-start/`, `nestjs-backend/`, `contributing/`) and re-run
the script.
Edits made here are overwritten and will fail CI.

These copies exist because the `arch-*` skills ship inside the `arch-core` plugin and must
be able to read their reference material from the plugin's own directory.
EOF

if [ "$CHECK" -eq 1 ]; then
    if diff -r "$ROOT/plugins/arch-core/reference" "$DEST" >/dev/null 2>&1; then
        echo "skill refs: IN SYNC"
        rm -rf "$DEST"
    else
        echo "skill refs: STALE — run 'sh scripts/build-skill-refs.sh' and commit" >&2
        diff -r "$ROOT/plugins/arch-core/reference" "$DEST" || true
        rm -rf "$DEST"
        exit 1
    fi
else
    echo "skill refs: regenerated into plugins/arch-core/reference/"
fi
