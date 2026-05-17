#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
echo "This project now uses one combined AAR: olcrtc + in-process tun2socks."
exec "${DIR}/build_combo_aar.sh"
