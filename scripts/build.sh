#!/usr/bin/env bash
# Builds Rootward for Linux and Windows and its installers (ADR-0091); see scripts/build.py.
set -euo pipefail
exec python3 "$(dirname "$0")/build.py" "$@"
