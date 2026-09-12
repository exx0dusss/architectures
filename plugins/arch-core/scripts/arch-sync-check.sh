#!/bin/sh
set -eu
exec python3 "$(dirname "$0")/arch_sync_check.py" "$@"
