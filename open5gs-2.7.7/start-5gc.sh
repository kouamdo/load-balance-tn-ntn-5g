#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG_DIR="$ROOT_DIR/build/configs/open5gs"

ensure_not_running() {
    local name="$1"
    local binary="$2"

    if pgrep -f "$binary" >/dev/null 2>&1; then
        echo "[ERROR] $name is already running: $binary" >&2
        echo "        Stop the existing process first, then run this script again." >&2
        exit 1
    fi
}

run_nf() {
    local name="$1"
    local binary="$2"
    local config="$3"

    if [[ ! -x "$binary" ]]; then
        echo "[ERROR] Missing binary for $name: $binary" >&2
        exit 1
    fi

    if [[ ! -f "$config" ]]; then
        echo "[ERROR] Missing config for $name: $config" >&2
        exit 1
    fi

    ensure_not_running "$name" "$binary"

    echo "[START] $name"
    "$binary" -D -c "$config"
}

run_nf "NRF"  "$ROOT_DIR/build/src/nrf/open5gs-nrfd"   "$CFG_DIR/nrf.yaml"
run_nf "SCP"  "$ROOT_DIR/build/src/scp/open5gs-scpd"   "$CFG_DIR/scp.yaml"
run_nf "UDR"  "$ROOT_DIR/build/src/udr/open5gs-udrd"   "$CFG_DIR/udr.yaml"
run_nf "UDM"  "$ROOT_DIR/build/src/udm/open5gs-udmd"   "$CFG_DIR/udm.yaml"
run_nf "AUSF" "$ROOT_DIR/build/src/ausf/open5gs-ausfd" "$CFG_DIR/ausf.yaml"
run_nf "PCF"  "$ROOT_DIR/build/src/pcf/open5gs-pcfd"   "$CFG_DIR/pcf.yaml"
run_nf "NSSF" "$ROOT_DIR/build/src/nssf/open5gs-nssfd" "$CFG_DIR/nssf.yaml"
run_nf "BSF"  "$ROOT_DIR/build/src/bsf/open5gs-bsfd"   "$CFG_DIR/bsf.yaml"
run_nf "SMF"  "$ROOT_DIR/build/src/smf/open5gs-smfd"   "$CFG_DIR/smf.yaml"
run_nf "UPF"  "$ROOT_DIR/build/src/upf/open5gs-upfd"   "$CFG_DIR/upf.yaml"
run_nf "AMF"  "$ROOT_DIR/build/src/amf/open5gs-amfd"   "$CFG_DIR/amf.yaml"

echo "[OK] 5GC startup commands sent"
