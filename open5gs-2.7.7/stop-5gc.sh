#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BINARIES=(
  "$ROOT_DIR/build/src/amf/open5gs-amfd"
  "$ROOT_DIR/build/src/ausf/open5gs-ausfd"
  "$ROOT_DIR/build/src/bsf/open5gs-bsfd"
  "$ROOT_DIR/build/src/nrf/open5gs-nrfd"
  "$ROOT_DIR/build/src/nssf/open5gs-nssfd"
  "$ROOT_DIR/build/src/pcf/open5gs-pcfd"
  "$ROOT_DIR/build/src/scp/open5gs-scpd"
  "$ROOT_DIR/build/src/smf/open5gs-smfd"
  "$ROOT_DIR/build/src/udm/open5gs-udmd"
  "$ROOT_DIR/build/src/udr/open5gs-udrd"
  "$ROOT_DIR/build/src/upf/open5gs-upfd"
)

stop_binary() {
    local binary="$1"
    local name

    name="$(basename "$binary")"
    if ! pgrep -f "$binary" >/dev/null 2>&1; then
        return 0
    fi

    echo "[STOP] $name"
    pkill -f "$binary" || true
}

for binary in "${BINARIES[@]}"; do
    stop_binary "$binary"
done

echo "[OK] Open5GS stop signals sent"
