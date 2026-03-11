#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "===== BUILDING IMAGE ====="
bash "$SCRIPT_DIR/build-image.sh"

echo "===== SENDING FILES TO SERVER ====="
bash "$SCRIPT_DIR/send-server.sh"

echo "SYNC COMPLETE"
