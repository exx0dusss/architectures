#!/bin/sh
# build-skill-refs.sh — regenerate reference docs bundled with plugins.
#
# Root source directories remain the single source of truth and stay browsable on GitHub.
# Skills ship inside plugins, so they need those docs on disk next to them; this script copies
# architecture and contribution doctrine into arch-core, plus product-design doctrine into its
# own plugin.
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
SHARED="contributing agent-workflows"
CORE_DEST="$ROOT/plugins/arch-core/reference"
PRODUCT_DEST="$ROOT/plugins/product-design/reference"

CHECK=0
if [ "${1:-}" = "--check" ]; then
    CHECK=1
    TMP=$(mktemp -d)
    CORE_DEST="$TMP/arch-core"
    PRODUCT_DEST="$TMP/product-design"
fi
DEST="$CORE_DEST"

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

cat > "$CORE_DEST/README.md" <<'EOF'
# Bundled reference

**Generated — do not edit.** Every file here is a verbatim copy of a stack doc or a
contribution doctrine doc from the repository root, produced by
`scripts/build-skill-refs.sh`.

Edit the source (`nextjs/`, `tanstack-start/`, `nestjs-backend/`, `contributing/`, `agent-workflows/`) and re-run
the script.
Edits made here are overwritten and will fail CI.

These copies exist because the `arch-*` skills ship inside the `arch-core` plugin and must
be able to read their reference material from the plugin's own directory.
EOF

rm -rf "$PRODUCT_DEST"
mkdir -p "$PRODUCT_DEST"
cp "$ROOT"/product-design/*.md "$PRODUCT_DEST/"
cat > "$PRODUCT_DEST/README.md" <<'EOF'
# Bundled product-design reference

**Generated — do not edit.** Files here are verbatim copies of `product-design/*.md`, produced by
`scripts/build-skill-refs.sh`. Edit root source and regenerate.
EOF

for stack in tanstack-start nestjs-backend; do
    target="$ROOT/plugins/arch-$stack/reference"
    [ "$CHECK" -eq 0 ] || target="$TMP/arch-$stack-reference"
    rm -rf "$target"
    mkdir -p "$target/agent-workflows"
    cp -R "$CORE_DEST/$stack" "$target/$stack"
    cp "$ROOT/agent-workflows/context-routing.md" "$target/agent-workflows/"
done

if [ "$CHECK" -eq 1 ]; then
    FAIL=0
    diff -r "$ROOT/plugins/arch-core/reference" "$CORE_DEST" >/dev/null 2>&1 || FAIL=1
    diff -r "$ROOT/plugins/product-design/reference" "$PRODUCT_DEST" >/dev/null 2>&1 || FAIL=1
    for stack in tanstack-start nestjs-backend; do
        diff -r "$ROOT/plugins/arch-$stack/reference" "$TMP/arch-$stack-reference" >/dev/null 2>&1 || FAIL=1
    done
    if [ "$FAIL" -eq 0 ]; then
        echo "skill refs: IN SYNC"
        rm -rf "$TMP"
    else
        echo "skill refs: STALE — run 'sh scripts/build-skill-refs.sh' and commit" >&2
        diff -r "$ROOT/plugins/arch-core/reference" "$CORE_DEST" || true
        diff -r "$ROOT/plugins/product-design/reference" "$PRODUCT_DEST" || true
        rm -rf "$TMP"
        exit 1
    fi
else
    echo "skill refs: regenerated into plugin reference directories"
fi
