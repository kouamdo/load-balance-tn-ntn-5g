#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_PARENT="$(cd "$ROOT_DIR/.." && pwd)"
OPEN5GS_LOG_DIR="$ROOT_DIR/install/var/log/open5gs"
OAI_ROOT="${OAI_ROOT:-$REPO_PARENT/openairinterface5g}"
OAI_BUILD_DIR="${OAI_BUILD_DIR:-$OAI_ROOT/cmake_targets/ran_build/build}"
MONGO_DBPATH="${MONGO_DBPATH:-/data/db}"
MONGO_LOG="${MONGO_LOG:-/var/log/mongodb/mongod.log}"
ARTIFACT_BASE="${ARTIFACT_BASE:-$ROOT_DIR/artifacts/ntn-validation}"

PROFILE="${PROFILE:-fixed}"
LEO_STEP="${LEO_STEP:-leo-full}"
AUTO_TA="${AUTO_TA:-0}"

GNB_FIXED_CONF="$OAI_ROOT/ci-scripts/conf_files/gnb.ntn-fixeddelay.local.conf"
UE_FIXED_CONF="$OAI_ROOT/targets/PROJECTS/GENERIC-NR-5GC/CONF/ue.ntn-fixeddelay.local.conf"
GNB_LEO_CONF="$OAI_ROOT/ci-scripts/conf_files/gnb.ntn-leo.local.conf"
UE_LEO_CONF="$OAI_ROOT/targets/PROJECTS/GENERIC-NR-5GC/CONF/ue.ntn-leo.local.conf"

GNB_LOG="$ARTIFACT_BASE/current-gnb.log"
UE_LOG="$ARTIFACT_BASE/current-ue.log"

usage() {
    cat <<'EOF'
Usage:
  ./ntn-validate.sh core-start
  ./ntn-validate.sh core-stop
  ./ntn-validate.sh gnb-start [fixed|leo]
  ./ntn-validate.sh ue-start [fixed|leo]
  ./ntn-validate.sh oai-stop
  ./ntn-validate.sh collect-logs [label]
  ./ntn-validate.sh evaluate [fixed|leo]
  ./ntn-validate.sh status

Environment:
  OAI_ROOT=../openairinterface5g
  OAI_BUILD_DIR=$OAI_ROOT/cmake_targets/ran_build/build
  PROFILE=fixed|leo
  LEO_STEP=leo-min|leo-drift|leo-fo|leo-full|leo-full-auto-ta
  AUTO_TA=1        # optional shortcut for LEO full mode
EOF
}

ensure_dirs() {
    mkdir -p "$ARTIFACT_BASE"
}

require_cmd() {
    local cmd="$1"
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "[ERROR] Missing command: $cmd" >&2
        exit 1
    }
}

require_file() {
    local path="$1"
    [[ -f "$path" ]] || {
        echo "[ERROR] Missing file: $path" >&2
        exit 1
    }
}

ensure_mongo() {
    if pgrep -f 'mongod.*127\.0\.0\.1.*27017' >/dev/null 2>&1 || pgrep -x mongod >/dev/null 2>&1; then
        echo "[OK] mongod already running"
        return 0
    fi

    require_cmd mongod
    mkdir -p "$MONGO_DBPATH"
    mkdir -p "$(dirname "$MONGO_LOG")"
    echo "[START] mongod"
    mongod --dbpath "$MONGO_DBPATH" \
           --bind_ip 127.0.0.1 \
           --port 27017 \
           --logpath "$MONGO_LOG" \
           --fork
}

core_start() {
    ensure_mongo
    "$ROOT_DIR/start-5gc.sh"
}

core_stop() {
    "$ROOT_DIR/stop-5gc.sh"
}

oai_stop() {
    echo "[STOP] OAI softmodems"
    pkill -f "$OAI_BUILD_DIR/nr-softmodem" || true
    pkill -f "$OAI_BUILD_DIR/nr-uesoftmodem" || true
}

gnb_conf_for_profile() {
    case "${1:-$PROFILE}" in
        fixed) printf '%s\n' "$GNB_FIXED_CONF" ;;
        leo) printf '%s\n' "$GNB_LEO_CONF" ;;
        *) echo "[ERROR] Unknown profile: $1" >&2; exit 1 ;;
    esac
}

ue_conf_for_profile() {
    case "${1:-$PROFILE}" in
        fixed) printf '%s\n' "$UE_FIXED_CONF" ;;
        leo) printf '%s\n' "$UE_LEO_CONF" ;;
        *) echo "[ERROR] Unknown profile: $1" >&2; exit 1 ;;
    esac
}

start_gnb() {
    local profile="${1:-$PROFILE}"
    local conf
    conf="$(gnb_conf_for_profile "$profile")"
    require_file "$conf"
    ensure_dirs

    echo "[START] gNB profile=$profile"
    nohup "$OAI_BUILD_DIR/nr-softmodem" -O "$conf" --rfsim >"$GNB_LOG" 2>&1 &
    disown
    echo "[INFO] gNB log: $GNB_LOG"
}

leo_ue_args() {
    local args=()
    args+=(--rfsimulator.[0].prop_delay 20)
    args+=(--rfsimulator.[0].options chanmod)

    case "$LEO_STEP" in
        leo-min)
            ;;
        leo-drift)
            args+=(--time-sync-I 0.1 --ntn-initial-time-drift -46)
            ;;
        leo-fo)
            args+=(--time-sync-I 0.1 --ntn-initial-time-drift -46 --initial-fo 57340)
            ;;
        leo-full)
            args+=(--time-sync-I 0.1 --ntn-initial-time-drift -46 --initial-fo 57340 --cont-fo-comp 2)
            ;;
        leo-full-auto-ta)
            args+=(--time-sync-I 0.1 --ntn-initial-time-drift -46 --initial-fo 57340 --cont-fo-comp 2 --autonomous-ta)
            ;;
        *)
            echo "[ERROR] Unknown LEO_STEP: $LEO_STEP" >&2
            exit 1
            ;;
    esac

    printf '%s\n' "${args[@]}"
}

start_ue() {
    local profile="${1:-$PROFILE}"
    local conf
    local common_args=(
      --rfsim
      --rfsimulator.[0].serveraddr 127.0.0.1
      --band 254
      -C 2488400000
      --CO -873500000
      -r 25
      --numerology 0
      --ssb 60
    )

    conf="$(ue_conf_for_profile "$profile")"
    require_file "$conf"
    ensure_dirs

    echo "[START] UE profile=$profile"
    if [[ "$profile" == "leo" ]]; then
        mapfile -t extra_args < <(leo_ue_args)
        nohup "$OAI_BUILD_DIR/nr-uesoftmodem" -O "$conf" "${common_args[@]}" "${extra_args[@]}" >"$UE_LOG" 2>&1 &
    else
        nohup "$OAI_BUILD_DIR/nr-uesoftmodem" -O "$conf" "${common_args[@]}" >"$UE_LOG" 2>&1 &
    fi
    disown
    echo "[INFO] UE log: $UE_LOG"
}

collect_logs() {
    local label="${1:-$(date +%Y%m%d-%H%M%S)}"
    local dst="$ARTIFACT_BASE/$label"

    mkdir -p "$dst"
    cp -f "$GNB_LOG" "$dst/gnb.log" 2>/dev/null || true
    cp -f "$UE_LOG" "$dst/ue.log" 2>/dev/null || true
    cp -f "$OPEN5GS_LOG_DIR/amf.log" "$dst/amf.log" 2>/dev/null || true
    cp -f "$OPEN5GS_LOG_DIR/smf.log" "$dst/smf.log" 2>/dev/null || true
    cp -f "$OPEN5GS_LOG_DIR/upf.log" "$dst/upf.log" 2>/dev/null || true
    cp -f "$OPEN5GS_LOG_DIR/nrf.log" "$dst/nrf.log" 2>/dev/null || true

    printf '[OK] Logs copied to %s\n' "$dst"
}

check_log_contains() {
    local label="$1"
    local file="$2"
    local pattern="$3"
    if grep -qE "$pattern" "$file" 2>/dev/null; then
        printf '[PASS] %s\n' "$label"
    else
        printf '[MISS] %s\n' "$label"
    fi
}

evaluate_profile() {
    local profile="${1:-$PROFILE}"

    echo "[INFO] Evaluating profile=$profile"
    check_log_contains "gNB NGSetupResponse" "$GNB_LOG" 'Received NGSetupResponse from AMF'
    check_log_contains "UE PBCH decoded" "$UE_LOG" 'pbch decoded sucessfully|pbch decoded successfully'
    check_log_contains "UE SIB1 decoded" "$UE_LOG" 'SIB1 decoded'
    check_log_contains "gNB PRACH/RA activity" "$GNB_LOG" 'PRACH|RACH|RRCSetup|CCCH|Msg3|Random Access'
    check_log_contains "AMF UE activity" "$OPEN5GS_LOG_DIR/amf.log" 'Registration request|Unknown UE by SUCI|Authentication|gmm_state|RAN_UE|InitialUEMessage'
    check_log_contains "SMF PDU activity" "$OPEN5GS_LOG_DIR/smf.log" 'PDU Session|UE address|Selected UPF|N1N2MessageTransfer|sm-context'
    check_log_contains "UPF user-plane activity" "$OPEN5GS_LOG_DIR/upf.log" 'GTP-U|PFCP session|Session'

    if [[ "$profile" == "leo" ]]; then
        echo "[INFO] LEO runtime step: $LEO_STEP"
        check_log_contains "UE LEO options visible" "$UE_LOG" 'ntn-initial-time-drift|cont-fo-comp|initial-fo|autonomous-ta|chanmod'
    fi
}

status() {
    echo "[INFO] MongoDB"
    pgrep -af mongod || true
    echo "[INFO] Open5GS"
    pgrep -af open5gs || true
    echo "[INFO] OAI"
    pgrep -af nr-softmodem || true
    pgrep -af nr-uesoftmodem || true
}

main() {
    local cmd="${1:-}"
    case "$cmd" in
        core-start) core_start ;;
        core-stop) core_stop ;;
        gnb-start) start_gnb "${2:-$PROFILE}" ;;
        ue-start) start_ue "${2:-$PROFILE}" ;;
        oai-stop) oai_stop ;;
        collect-logs) collect_logs "${2:-}" ;;
        evaluate) evaluate_profile "${2:-$PROFILE}" ;;
        status) status ;;
        ""|-h|--help|help) usage ;;
        *)
            echo "[ERROR] Unknown command: $cmd" >&2
            usage
            exit 1
            ;;
    esac
}

main "$@"
