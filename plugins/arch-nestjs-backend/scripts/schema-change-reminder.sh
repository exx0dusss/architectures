#!/bin/sh
set -eu
exec python3 "$(dirname "$0")/hook_reminder.py" schema
