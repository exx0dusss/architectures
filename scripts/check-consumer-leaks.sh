#!/usr/bin/env bash
# Guard the blueprint against consumer-specific detail — ADR-0006, and
# PATTERNS.md: "nothing here points at a downstream project".
#
#   sh scripts/check-consumer-leaks.sh
#
# This catches the shapes a regex can settle, and only those:
#
#   1. a ticket key other than the documented `PROJ-123` placeholder —
#      a real project's prefix is a consumer name in disguise (ADR-0008
#      bans it as a commit scope; it does not belong in doctrine either)
#   2. a local filesystem path — `/Users/…`, `/home/<user>/`, `~/GitHub/…`
#      is one machine's geography, never a rule
#   3. a `github.com/<owner>` other than this repo's — the blueprint may
#      cite a public reference repo by `owner/repo` in prose, but a link
#      out to a downstream project is the dependency ADR-0006 forbids
#
# Everything else a leak can be — a vendor, a currency, a locale, a dated
# finding — needs judgment, not a pattern. That is the `consumer-leak-auditor`
# agent's job, and this guard does not pretend to replace it. ADR-0010 asks
# for an existing tool before a bespoke one; no linter models "belongs to one
# consumer", so the tool here is grep, kept to what grep can actually prove.
#
# Skips `plugins/arch-core/reference/`: it is generated verbatim from the stack
# docs, so a hit there is a duplicate of one already reported at its source.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1

OWNER='exx0dusss'
FAILURES=0
fail() { printf 'FAIL  %s\n' "$1"; FAILURES=$((FAILURES + 1)); }
ok()   { printf 'ok    %s\n' "$1"; }

# Tracked files only, minus the generated reference tree and this guard's own
# pair of files — both necessarily contain the patterns they describe.
files() {
  git ls-files -z \
    | grep -zv '^plugins/arch-core/reference/' \
    | grep -zv '^scripts/check-consumer-leaks\.sh$' \
    | grep -zv '^\.github/workflows/leaks\.yml$'
}

scan() { # scan <label> <extended-regex> [<allowlist-regex>]
  hits="$(files | xargs -0 grep -nE "$2" 2>/dev/null \
    | { [ $# -ge 3 ] && grep -vE "$3" || cat; })"
  if [ -n "$hits" ]; then
    fail "$1"
    printf '%s\n' "$hits" | sed 's/^/      /'
  else
    ok "$1"
  fi
}

scan 'no ticket keys outside the PROJ-123 placeholder' \
     '\b[A-Z]{2,5}-[0-9]+' \
     '\b(ADR|PROJ)-[0-9]+'

scan 'no local filesystem paths' \
     '(/Users/|/home/[a-z]|~/GitHub/)'

scan "no links to a repo outside $OWNER" \
     'github\.com/[A-Za-z0-9_.-]+/' \
     "github\.com/$OWNER/"

echo
if [ "$FAILURES" -gt 0 ]; then
  echo "consumer leaks: $FAILURES check(s) failed"
  echo "A blueprint that names its consumers cannot be adopted by anyone else."
  exit 1
fi
echo "consumer leaks: none"
