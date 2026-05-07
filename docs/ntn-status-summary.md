# NTN Status Summary

## Current State

We validated the current Open5GS + OAI setup far enough to separate radio-sync issues from core-network and user-plane issues.

### What works

- MongoDB is running and the UE subscriber is provisioned.
- Open5GS core network functions can be started from the consolidated repository layout.
- The gNB reaches `NGSetupResponse from AMF`.
- In the `NTN fixed-delay baseline`, the UE reaches:
  - `PBCH decoded`
  - `Initial sync successful`
  - `UE synchronized`
  - `SIB1 decoded`

### What does not work yet

- We do not see convincing random access progression after `SIB1 decoded`.
- The gNB does not show a clear successful `PRACH` / `Msg3` / `RRCSetup` sequence.
- The AMF does not show UE-side signaling such as:
  - `InitialUEMessage`
  - `RAN_UE`
  - `Registration request`
  - `Authentication`
- Therefore, the UE is not yet visible to the 5GC at AMF level.

## Main Interpretation

The current blocker is not the UPF, NAT, or DN breakout.

The problem appears earlier in the chain:

1. UE radio sync succeeds
2. UE decodes `SIB1`
3. random access / RRC progression is missing or incomplete
4. AMF never receives UE signaling

So the current investigation boundary is between:
- successful NTN fixed-delay synchronization
- and successful random access / RRC / NAS entry into the core

## Validation Staging We Use

### Stage 1: Radio Synchronization
- gNB attached to AMF
- UE decodes `PBCH`
- UE synchronizes
- UE decodes `SIB1`

### Stage 2: Random Access And RRC
- gNB detects `PRACH`
- UE progresses into `RRC Setup`
- gNB sees `CCCH`, `Msg3`, or `RRCSetup`

### Stage 3: Core Visibility
- UE becomes visible in `amf.log`

### Stage 4: Optional User Plane
- `SMF`, `UPF`, `PDU Session`, DN routing, and NAT only matter after Stage 3

## Practical Conclusion

At this point, continuing broad local trial-and-error is unlikely to be efficient.
The issue report prepared for OAI is the right next step because the current behavior may be caused by:

- an NTN fixed-delay limitation in OAI
- a missing runtime/configuration parameter
- or an incomplete random access / RRC progression in this scenario

## Waiting For Upstream Feedback

Until the OAI response arrives, the most useful posture is:

- keep the current fixed-delay setup as the reproducible baseline
- keep the LEO setup as a secondary follow-up scenario
- avoid spending time on UPF/NAT tuning for now
- resume deeper testing once upstream clarifies whether this is expected, known, or misconfigured

## Key Files

- `README.md`
- `docs/oai-issue-draft.md`
- `open5gs-2.7.7/ntn-validate.sh`
- `openairinterface5g/ci-scripts/conf_files/gnb.ntn-fixeddelay.local.conf`
- `openairinterface5g/targets/PROJECTS/GENERIC-NR-5GC/CONF/ue.ntn-fixeddelay.local.conf`
- `openairinterface5g/ci-scripts/conf_files/gnb.ntn-leo.local.conf`
- `openairinterface5g/targets/PROJECTS/GENERIC-NR-5GC/CONF/ue.ntn-leo.local.conf`
