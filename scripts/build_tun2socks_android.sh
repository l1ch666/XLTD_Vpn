#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
echo "Deprecated old external-process tun2socks build. Building combined in-process AAR instead."
exec "${DIR}/build_combo_aar.sh"
