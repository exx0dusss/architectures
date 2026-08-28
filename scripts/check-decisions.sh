#!/usr/bin/env bash
# Guard the decision log: decisions/*.md against DECISIONS.md.
#
#   sh scripts/check-decisions.sh            # report
#   sh scripts/check-decisions.sh --strict   # report, exit 1 on any failure
#
# Checks:
#   1. frontmatter id matches the NNNN- filename prefix
#   2. every ADR file has an index row in DECISIONS.md, and vice versa
#   3. supersede chains are bidirectional (A supersedes B <=> B superseded_by A)
#   4. a superseded ADR has status: Superseded
#   5. every ADR-NNNN / decisions/NNNN- reference in the repo resolves to a file
#   6. no `Proposed` ADR older than 30 days
#   7. an ADR numbered 0009 or higher carries a non-empty `## Compliance`
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIR="$ROOT/decisions"
INDEX="$ROOT/DECISIONS.md"
STRICT=0
[ "${1:-}" = "--strict" ] && STRICT=1

FAILURES=0
fail() { printf 'FAIL  %s\n' "$1"; FAILURES=$((FAILURES + 1)); }
ok()   { printf 'ok    %s\n' "$1"; }
MARK=0
mark() { MARK=$FAILURES; }
# print the section line only when the section added no failures
section() { [ "$FAILURES" -eq "$MARK" ] && ok "$1"; mark; }

[ -d "$DIR" ]   || { fail "decisions/ not found"; exit 1; }
[ -f "$INDEX" ] || { fail "DECISIONS.md not found"; exit 1; }

# Read one frontmatter key from an ADR (frontmatter = lines between the first
# two `---` lines).
field() { awk -v k="$2" '
  NR==1 && $0=="---" { inFm=1; next }
  inFm && $0=="---"  { exit }
  inFm && index($0, k ":")==1 { sub("^" k ": *", ""); print; exit }
' "$1"; }

# Frontmatter list value `[0001, 0002]` -> newline-separated IDs.
ids() { field "$1" "$2" | tr -d '[]' | tr ',' '\n' | tr -d ' ' | grep -E '^[0-9]{4}$' || true; }

ADRS=$(find "$DIR" -name '[0-9][0-9][0-9][0-9]-*.md' ! -name '0000-*' | sort)
[ -n "$ADRS" ] || { fail "no ADR files in decisions/"; exit 1; }

# --- 1. id matches filename; 4. superseded status; 6. stale Proposed ---------
CUTOFF=$(date -u -v-30d +%Y-%m-%d 2>/dev/null || date -u -d '30 days ago' +%Y-%m-%d)
for f in $ADRS; do
  base=$(basename "$f")
  fid=${base%%-*}
  id=$(field "$f" id)
  status=$(field "$f" status)
  date_f=$(field "$f" date)

  [ "$id" = "$fid" ] || fail "$base: frontmatter id '$id' != filename prefix '$fid'"

  case "$status" in
    Proposed|Accepted|Superseded) ;;
    *) fail "$base: status '$status' is not Proposed/Accepted/Superseded" ;;
  esac

  if [ -n "$(ids "$f" superseded_by)" ] && [ "$status" != "Superseded" ]; then
    fail "$base: has superseded_by but status is '$status'"
  fi
  if [ "$status" = "Superseded" ] && [ -z "$(ids "$f" superseded_by)" ]; then
    fail "$base: status is Superseded but superseded_by is empty"
  fi

  if [ "$status" = "Proposed" ] && [ -n "$date_f" ] && [ "$date_f" \< "$CUTOFF" ]; then
    fail "$base: Proposed since $date_f (stale — decide it or drop it)"
  fi
done

section "frontmatter, statuses and staleness checked ($(echo "$ADRS" | wc -l | tr -d ' ') ADRs)"

# --- 7. ADRs from 0009 carry a non-empty Compliance section ---------------
# ADR-0009 added the section; ADRs 0001-0008 predate it and are immutable, so
# the check starts at 0009 rather than failing the whole log.
for f in $ADRS; do
  base=$(basename "$f")
  fid=${base%%-*}
  # Shell compares 0009 and 0010 correctly as zero-padded strings of equal
  # width, but strip the padding anyway so the intent survives ids past 0999.
  num=$(echo "$fid" | sed 's/^0*//')
  [ -n "$num" ] || num=0
  [ "$num" -ge 9 ] || continue

  body=$(awk '/^## Compliance$/{f=1;next} /^## /{f=0} f' "$f" | tr -d '[:space:]')
  [ -n "$body" ] || fail "$base: ## Compliance is missing or empty (ADR-0009)"
done
section "compliance sections present"

# --- 2. files <-> index rows -------------------------------------------------
for f in $ADRS; do
  id=$(basename "$f" | cut -d- -f1)
  grep -q "\[$id\](\./decisions/" "$INDEX" || fail "ADR-$id has no row in DECISIONS.md"
done
INDEXED=$(grep -oE '\[([0-9]{4})\]\(\./decisions/[^)]+\)' "$INDEX" | sed -E 's/^\[([0-9]{4})\].*/\1/' | sort -u)
for id in $INDEXED; do
  [ -n "$(find "$DIR" -name "$id-*.md")" ] || fail "DECISIONS.md lists ADR-$id but no file exists"
done
section "index rows and ADR files are in step"

# --- 3. bidirectional supersede chains --------------------------------------
for f in $ADRS; do
  id=$(basename "$f" | cut -d- -f1)
  for target in $(ids "$f" supersedes); do
    t=$(find "$DIR" -name "$target-*.md" | head -1)
    if [ -z "$t" ]; then
      fail "ADR-$id supersedes ADR-$target, which does not exist"
    elif ! ids "$t" superseded_by | grep -qx "$id"; then
      fail "ADR-$id supersedes ADR-$target, but ADR-$target does not list superseded_by: [$id]"
    fi
  done
  for target in $(ids "$f" superseded_by); do
    t=$(find "$DIR" -name "$target-*.md" | head -1)
    if [ -z "$t" ]; then
      fail "ADR-$id is superseded_by ADR-$target, which does not exist"
    elif ! ids "$t" supersedes | grep -qx "$id"; then
      fail "ADR-$id is superseded_by ADR-$target, but ADR-$target does not list supersedes: [$id]"
    fi
  done
done
section "supersede chains are bidirectional"

# --- 5. every ADR reference in the repo resolves -----------------------------
REFS=$(grep -rhoE 'ADR-[0-9]{4}' "$ROOT" \
  --include='*.md' --include='*.sh' --include='*.json' \
  --exclude-dir=.git --exclude-dir=node_modules 2>/dev/null |
  sed 's/^ADR-//' | sort -u)
for id in $REFS; do
  [ "$id" = "0000" ] && continue
  [ -n "$(find "$DIR" -name "$id-*.md")" ] || fail "reference to ADR-$id, but no such decision file"
done
section "ADR references resolve"

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "decision log OK"
  exit 0
fi
echo "$FAILURES failure(s)"
[ "$STRICT" -eq 1 ] && exit 1
exit 0
