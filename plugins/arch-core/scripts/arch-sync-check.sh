#!/bin/sh
# arch-sync-check.sh — is this repo on the current blueprint, and is it actually using it?
#
# Runs in a CONSUMER repo. Writes .claude/blueprint-sync.json so the answer is
# visible in git rather than only in someone's terminal.
#
# The direction matters: the consumer depends on the blueprint, so the consumer
# is where the check belongs. The blueprint repo knows nothing about who
# installs it.
#
# Two independent questions, because version equality is not sync:
#
#   1. VERSIONS — is the installed plugin the one the marketplace advertises?
#        CURRENT  — matches
#        BEHIND   — marketplace advertises newer; run `claude plugin update`
#        UNKNOWN  — plugin not found in the marketplace manifest
#
#   2. SHADOWING — does a project-level .claude/agents/<name>.md override a
#      plugin agent of the same name? Project agents win, so a vendored copy
#      silently disables the plugin's version and every version check still
#      reports CURRENT while the plugin does nothing.
#        DUPLICATE — byte-identical to the plugin agent; safe to delete
#        FORK      — differs; a human must rule on stale-ancestor vs local patch
#
# Everything mechanical lives here. The judgment calls — is a FORK a stale copy
# or a real patch, does a local convention contradict current doctrine — belong
# to the `arch-drift` agent in arch-core, which runs this script first.
#
# Exits 0 (report, don't fail) unless --strict, which exits 1 if anything is
# BEHIND or SHADOWED — use that in CI to gate on blueprint currency.
#
# Usage:
#   sh arch-sync-check.sh [--strict] [--marketplace <owner/repo>]

set -eu

STRICT=0
MARKETPLACE="exx0dusss/architectures"

while [ $# -gt 0 ]; do
    case "$1" in
        --strict) STRICT=1 ;;
        --marketplace) shift; MARKETPLACE="${1:?--marketplace needs a value}" ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
    shift
done

command -v claude >/dev/null 2>&1 || { echo "claude CLI not found on PATH" >&2; exit 2; }

MARKETPLACE_NAME=${MARKETPLACE##*/}
CACHE="$HOME/.claude/plugins/cache/$MARKETPLACE_NAME"
OUT_DIR=".claude"
OUT="$OUT_DIR/blueprint-sync.json"
SETTINGS="$OUT_DIR/settings.json"

ALL_PLUGINS="arch-core arch-nextjs arch-tanstack-start arch-nestjs-backend"

# Which plugins are enabled FOR THIS PROJECT. The plugin cache is shared across
# every repo on the machine, so scanning it alone reports plugins this repo
# never enabled — a repo with only arch-tanstack-start would show arch-nextjs as
# CURRENT purely because some other project installed it.
# Under `set -e`, a function whose LAST command fails makes `X=$(fn)` abort the
# script. Every consumer enables a subset of the plugins, so the last name in
# ALL_PLUGINS usually is not enabled — hence the explicit `if`, not `&&`.
enabled_plugins() {
    if [ -f "$SETTINGS" ]; then
        for p in $ALL_PLUGINS; do
            if grep -q "\"$p@$MARKETPLACE_NAME\" *: *true" "$SETTINGS"; then
                printf '%s ' "$p"
            fi
        done
    else
        # No project settings — fall back to whatever is in the cache.
        for p in $ALL_PLUGINS; do
            if [ -d "$CACHE/$p" ]; then
                printf '%s ' "$p"
            fi
        done
    fi
    return 0
}

# Installed version of a plugin = the version directory under its cache entry.
installed_version() {
    [ -d "$CACHE/$1" ] || return 1
    ls -1 "$CACHE/$1" 2>/dev/null | sort -V | tail -n 1
}

# Advertised version = what the marketplace manifest currently declares.
MANIFEST="$HOME/.claude/plugins/marketplaces/$MARKETPLACE_NAME/.claude-plugin/marketplace.json"
advertised_version() {
    [ -f "$MANIFEST" ] || return 1
    sed -n "/\"name\": *\"$1\"/,/}/p" "$MANIFEST" |
        sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' | head -n 1
}

ENABLED=$(enabled_plugins)
SCOPE="project"
[ -f "$SETTINGS" ] || SCOPE="machine-cache"

BEHIND=0
SHADOWED=0
ROWS=""
AGENT_ROWS=""

# ---------------------------------------------------------------- versions ---

for plugin in $ENABLED; do
    if ! have=$(installed_version "$plugin"); then
        continue
    fi
    want=$(advertised_version "$plugin" || echo "")

    if [ -z "$want" ]; then
        state="UNKNOWN"
    elif [ "$have" = "$want" ]; then
        state="CURRENT"
    else
        state="BEHIND"
        BEHIND=$((BEHIND + 1))
    fi

    printf '%-24s %-8s installed=%s advertised=%s\n' "$plugin" "$state" "$have" "${want:-?}"
    ROWS="$ROWS    \"$plugin\": { \"installed\": \"$have\", \"advertised\": \"${want:-}\", \"state\": \"$state\" },
"
done

if [ -z "$ROWS" ]; then
    echo "No arch-* plugins enabled here. Run /arch-init, or:"
    echo "  claude plugin marketplace add $MARKETPLACE"
    exit 0
fi

# --------------------------------------------------------------- shadowing ---

# Every agent the enabled plugins ship, as "<basename> <path>" pairs.
PLUGIN_AGENTS=""
for plugin in $ENABLED; do
    have=$(installed_version "$plugin") || continue
    dir="$CACHE/$plugin/$have/agents"
    [ -d "$dir" ] || continue
    for f in "$dir"/*.md; do
        [ -e "$f" ] || continue
        PLUGIN_AGENTS="$PLUGIN_AGENTS$(basename "$f") $f
"
    done
done

if [ -n "$PLUGIN_AGENTS" ]; then
    # Project-level agents anywhere in the repo — monorepos keep one set per app.
    #
    # Agent tooling checks out nested git worktrees inside the repo, each a full
    # copy carrying its own .claude/agents/. Those are other branches' files, not
    # this checkout's, and Claude Code never loads them — so they cannot shadow
    # anything, and counting them reports phantom shadows that deleting the real
    # copy does not clear. Skip the conventional path outright, and skip anything
    # git ignores: if it is not part of this checkout, it is not a project agent.
    LOCAL_AGENTS=$(find . -path '*/.claude/agents/*.md' \
        -not -path './node_modules/*' -not -path '*/node_modules/*' \
        -not -path '*/.claude/worktrees/*' \
        2>/dev/null | sort || true)

    if [ -n "$LOCAL_AGENTS" ] && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        IGNORED=$(printf '%s\n' "$LOCAL_AGENTS" | git check-ignore --stdin 2>/dev/null || true)
        if [ -n "$IGNORED" ]; then
            LOCAL_AGENTS=$(printf '%s\n' "$LOCAL_AGENTS" | grep -vxF "$IGNORED" || true)
        fi
    fi

    for local_agent in $LOCAL_AGENTS; do
        name=$(basename "$local_agent")
        plugin_agent=$(printf '%s' "$PLUGIN_AGENTS" | awk -v n="$name" '$1 == n { print $2; exit }')
        [ -n "$plugin_agent" ] || continue

        if cmp -s "$local_agent" "$plugin_agent"; then
            astate="DUPLICATE"
        else
            astate="FORK"
        fi
        SHADOWED=$((SHADOWED + 1))

        printf '%-24s %-8s %s\n' "${name%.md}" "$astate" "$local_agent"
        AGENT_ROWS="$AGENT_ROWS      { \"agent\": \"${name%.md}\", \"local\": \"$local_agent\", \"state\": \"$astate\" },
"
    done
fi

# ------------------------------------------------------------------ output ---

mkdir -p "$OUT_DIR"
{
    echo "{"
    echo "  \"marketplace\": \"$MARKETPLACE\","
    echo "  \"scope\": \"$SCOPE\","
    echo "  \"plugins\": {"
    printf '%s' "$ROWS" | sed '$ s/,$//'
    echo "  },"
    echo "  \"shadowedAgents\": ["
    [ -n "$AGENT_ROWS" ] && printf '%s' "$AGENT_ROWS" | sed '$ s/,$//'
    echo "  ]"
    echo "}"
} > "$OUT"

echo "---"
echo "Wrote $OUT"

if [ "$BEHIND" -gt 0 ]; then
    echo "$BEHIND plugin(s) behind — run: claude plugin update"
fi

if [ "$SHADOWED" -gt 0 ]; then
    echo "$SHADOWED plugin agent(s) shadowed by project copies — the plugin's versions are inert."
    echo "DUPLICATE = delete the local copy. FORK = run the arch-drift agent to rule on it."
fi

if [ "$STRICT" -eq 1 ] && { [ "$BEHIND" -gt 0 ] || [ "$SHADOWED" -gt 0 ]; }; then
    exit 1
fi
exit 0
