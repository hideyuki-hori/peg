#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/macos"
./scripts/build-app.sh
pkill -x Peg || true
open dist/Peg.app
