# OAI Issue Draft

## Title

NTN fixed-delay RFsim: UE reaches PBCH/SIB1 but does not progress to visible AMF-side UE activity

## Summary

We are validating an OAI + Open5GS NTN setup with RFsim. In the fixed-delay NTN baseline, the UE consistently reaches PBCH decode, initial sync, and SIB1 decode, but we do not see successful progression to AMF-visible UE activity.

At the same time, the gNB does not show convincing PRACH / random access progress. This suggests the issue is likely between successful SIB1 acquisition and random access / RRC setup, rather than in Open5GS core-side PDU session or UPF/NAT handling.

## Environment

- OAI branch: `develop`
- OAI build includes `nr-softmodem`, `nr-uesoftmodem`, and `OAI_SIMU:BOOL=ON`
- Open5GS: `2.7.7`
- Scenario: NTN fixed-delay baseline over RFsim
- Band: `254`
- DL freq: `2488400000`
- UL offset: `-873500000`
- Numerology: `0`
- N_RB_DL: `25`
- SSB: `60`
- PLMN: `999/70`

## What Works

### gNB / core side
- gNB attaches to AMF
- `Received NGSetupResponse from AMF` is visible

### UE side
- `pbch decoded sucessfully`
- `Initial sync successful`
- `UE synchronized!`
- `SIB1 decoded`

## What Does Not Work

- No convincing UE progression into random access / RRC setup
- No AMF-side UE traces such as:
  - `InitialUEMessage`
  - `RAN_UE`
  - `Registration request`
  - `Authentication`

## Relevant UE Log Extract

```text
[PHY]    Initial sync: pbch decoded sucessfully, ssb index 0
[PHY]    Initial sync successful, PCI: 0
[PHY]    UE synchronized!
[NR_RRC] SIB1 decoded
```

## Relevant gNB Log Observation

The gNB reaches NG setup, but repeated PRACH-related indicators remain weak / inconclusive, for example repeated `prach_I0 = 0.0 dB`, and we do not see a clear successful random access / RRC setup sequence leading to AMF UE visibility.

## Current Interpretation

The issue appears to be before the core-network PDU/session plane. In other words:
- this does **not** currently look like a `UPF` NAT or DN breakout problem
- it looks more like an issue between NTN sync completion and random access / RRC progression

## Question

In the fixed-delay NTN baseline, after successful PBCH and SIB1 decode, are there known constraints or missing runtime/configuration parameters in OAI that can prevent PRACH / RRC progression in this setup?

In particular, is there any known limitation for NTN RFsim fixed-delay mode where UE sync succeeds but random access does not complete reliably?

## Additional Note

We also tested LEO staged options separately, but this issue report is specifically about the simpler fixed-delay baseline because it already reproduces the gap between `SIB1 decoded` and AMF-visible UE activity.
