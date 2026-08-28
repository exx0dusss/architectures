#!/bin/sh
# check-plugin-versions.sh — the marketplace must not advertise a version that does not exist.
#
# Written after a real failure: `.claude-plugin/marketplace.json` advertised
# arch-nestjs-backend 1.1.0 while plugins/arch-nestjs-backend/.claude-plugin/plugin.json
# still said 1.0.0. Consumers' arch-sync-check.sh then reported BEHIND forever, while
# `claude plugin update` correctly answered "already at the latest version" — an alarm
# nobody could clear from either side.
#
# Also verifies every plugin the manifest names actually exists on disk, and that the
# source directory matches the plugin's own name.
#
# Usage:
#   sh scripts/check-plugin-versions.sh

set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
MANIFEST="$ROOT/.claude-plugin/marketplace.json"

[ -f "$MANIFEST" ] || { echo "missing $MANIFEST" >&2; exit 2; }

FAIL=0

# name<TAB>version<TAB>source, one plugin per line.
python3 - "$MANIFEST" <<'PY' > /tmp/arch-plugin-rows.$$
import json, sys
d = json.load(open(sys.argv[1]))
for p in d["plugins"]:
    print("\t".join([p["name"], p["version"], p.get("source", "")]))
PY

while IFS="$(printf '\t')" read -r name version source; do
    dir="$ROOT/${source#./}"
    manifest="$dir/.claude-plugin/plugin.json"

    if [ ! -f "$manifest" ]; then
        echo "MISSING  $name — advertised at $version, no plugin.json at $manifest" >&2
        FAIL=$((FAIL + 1))
        continue
    fi

    have=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['version'])" "$manifest")
    own=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['name'])" "$manifest")

    if [ "$have" != "$version" ]; then
        echo "MISMATCH $name — marketplace advertises $version, plugin.json says $have" >&2
        FAIL=$((FAIL + 1))
    fi

    if [ "$own" != "$name" ]; then
        echo "NAME     $name — plugin.json calls itself $own" >&2
        FAIL=$((FAIL + 1))
    fi

    printf '%-24s %s\n' "$name" "$version"
done < /tmp/arch-plugin-rows.$$

rm -f /tmp/arch-plugin-rows.$$

if [ "$FAIL" -gt 0 ]; then
    echo "" >&2
    echo "plugin versions: $FAIL problem(s) — a consumer cannot install a version that does not exist" >&2
    exit 1
fi

echo "---"
echo "plugin versions: consistent"
exit 0
