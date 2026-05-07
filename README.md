# load-balance-tn-ntn-5g

Combined workspace for 5G TN/NTN validation work built around:

- `open5gs-2.7.7/`
- `openairinterface5g/`

This repository is intended to keep the source trees, local NTN validation
configuration, and orchestration scripts together in one place for publication
and collaboration.

## Goal

This project is meant to support a progressive transition from terrestrial
network (`TN`) validation to non-terrestrial network (`NTN`) validation in 5G,
with two practical focus areas:

- validating OpenAirInterface + Open5GS end-to-end in NTN scenarios
- preparing future TN to NTN load-balancing and handover experiments

## Included

- Open5GS source tree with local validation scripts and Open5GS runtime configs
- OpenAirInterface source tree with local NTN fixed-delay and LEO configs
- NTN validation helper documentation
- combined repository structure ready for public sharing and reproducible tests

## Repository Layout

- `open5gs-2.7.7/`
  - Open5GS sources
  - local core scripts: `start-5gc.sh`, `stop-5gc.sh`, `ntn-validate.sh`
  - adjusted Open5GS configs under `build/configs/open5gs/`
- `openairinterface5g/`
  - OAI sources
  - local NTN gNB profiles in `ci-scripts/conf_files/`
  - local NTN UE profiles in `targets/PROJECTS/GENERIC-NR-5GC/CONF/`

## OAI Demonstrations Included

This repository reuses and adapts the ideas from the OAI documentation:

- NTN configuration:
  - `openairinterface5g/doc/ntn-configuration.md`
- optional NR UE command-line options for NTN/LEO:
  - `openairinterface5g/doc/ntn-configuration.md#optional-nr-ue-command-line-options`
- handover tutorial:
  - `openairinterface5g/doc/handover-tutorial.md`

The practical demonstrations covered here are:

1. `NTN fixed-delay baseline`
   - goal: validate RFsim, sync, SIB decoding, and core connectivity without
     orbital dynamics
   - profile pair:
     - `openairinterface5g/ci-scripts/conf_files/gnb.ntn-fixeddelay.local.conf`
     - `openairinterface5g/targets/PROJECTS/GENERIC-NR-5GC/CONF/ue.ntn-fixeddelay.local.conf`

2. `NTN LEO transparent satellite`
   - goal: validate `SAT_LEO_TRANS`, Doppler handling, and staged UE runtime
     compensation
   - profile pair:
     - `openairinterface5g/ci-scripts/conf_files/gnb.ntn-leo.local.conf`
     - `openairinterface5g/targets/PROJECTS/GENERIC-NR-5GC/CONF/ue.ntn-leo.local.conf`

3. `Handover / load-balancing preparation`
   - goal: use the OAI handover tutorial as the TN-side mobility foundation
     before introducing NTN-aware steering or xApp-driven policies
   - reference:
     - `openairinterface5g/doc/handover-tutorial.md`

## How To Exploit This Project

The recommended workflow is to use the repository in three phases.

### 1. Validate The 5GC

Start MongoDB manually if needed, then launch the Open5GS core:

```bash
cd open5gs-2.7.7
./ntn-validate.sh core-start
```

This starts or validates:

- `mongod`
- `NRF`
- `SCP`
- `UDR`
- `UDM`
- `AUSF`
- `NSSF`
- `BSF`
- `SMF`
- `UPF`
- `AMF`

### 2. Validate NTN In Fixed Delay First

This is the baseline recommended by the OAI NTN guide before enabling full LEO
dynamics.

```bash
cd open5gs-2.7.7
./ntn-validate.sh oai-stop
./ntn-validate.sh gnb-start fixed
./ntn-validate.sh ue-start fixed
./ntn-validate.sh evaluate fixed
./ntn-validate.sh collect-logs fixed-baseline
```

Expected milestones:

- `NGSetupResponse from AMF`
- `PBCH decoded`
- `UE synchronized`
- `SIB1 decoded`
- initial `PRACH` / `RA` / `RRC` activity

### 3. Reintroduce LEO Step By Step

The OAI NTN documentation explains that LEO needs more than a fixed
propagation delay. In particular, UE-side timing drift and Doppler compensation
must be staged carefully.

This repository implements the following staged LEO method in
`open5gs-2.7.7/ntn-validate.sh`:

- `leo-min`
  - `--rfsimulator.[0].prop_delay 20`
  - `--rfsimulator.[0].options chanmod`
- `leo-drift`
  - `+ --time-sync-I 0.1`
  - `+ --ntn-initial-time-drift -46`
- `leo-fo`
  - `+ --initial-fo 57340`
- `leo-full`
  - `+ --cont-fo-comp 2`
- `leo-full-auto-ta`
  - `+ --autonomous-ta`

Run them in order:

```bash
cd open5gs-2.7.7
./ntn-validate.sh oai-stop
./ntn-validate.sh gnb-start leo
LEO_STEP=leo-min ./ntn-validate.sh ue-start leo
./ntn-validate.sh evaluate leo
./ntn-validate.sh collect-logs leo-min
```

Then repeat with:

- `LEO_STEP=leo-drift`
- `LEO_STEP=leo-fo`
- `LEO_STEP=leo-full`
- `LEO_STEP=leo-full-auto-ta`

Decision rule:

- if LEO fails before `PBCH decoded`, the issue is still initial PHY sync
- if `PBCH` and `SIB1` pass but `RACH` fails, the issue is timing or frequency
  tracking
- if `RRC` passes but `NAS` does not, the problem is no longer radio-only

## Manual OAI Commands

If you prefer to run the components manually instead of using
`ntn-validate.sh`, the OAI docs map to this repository as follows.

### gNB Fixed Delay

```bash
cd openairinterface5g/cmake_targets/ran_build/build
sudo ./nr-softmodem -O ../../../ci-scripts/conf_files/gnb.ntn-fixeddelay.local.conf --rfsim
```

### UE Fixed Delay

```bash
cd openairinterface5g/cmake_targets/ran_build/build
sudo ./nr-uesoftmodem -O ../../../targets/PROJECTS/GENERIC-NR-5GC/CONF/ue.ntn-fixeddelay.local.conf --rfsim --band 254 -C 2488400000 --CO -873500000 -r 25 --numerology 0 --ssb 60
```

### gNB LEO

```bash
cd openairinterface5g/cmake_targets/ran_build/build
sudo ./nr-softmodem -O ../../../ci-scripts/conf_files/gnb.ntn-leo.local.conf --rfsim
```

### UE LEO Full

```bash
cd openairinterface5g/cmake_targets/ran_build/build
sudo ./nr-uesoftmodem -O ../../../targets/PROJECTS/GENERIC-NR-5GC/CONF/ue.ntn-leo.local.conf --rfsim --band 254 -C 2488400000 --CO -873500000 -r 25 --numerology 0 --ssb 60 --rfsimulator.[0].prop_delay 20 --rfsimulator.[0].options chanmod --time-sync-I 0.1 --ntn-initial-time-drift -46 --initial-fo 57340 --cont-fo-comp 2
```

### F1 Handover Reference

The handover tutorial is not yet wired into the validation script, but it is
the right next building block for TN mobility and later TN/NTN steering:

- build with telnet support
- run one CU and two DUs
- attach the UE
- trigger handover manually through telnet or measurement events

For the full procedure, see:

- `openairinterface5g/doc/handover-tutorial.md`

## Recommended Experiment Roadmap

1. Confirm that `fixed delay` reaches at least `SIB1` and ideally `RRC`/`NAS`.
2. Re-run the same setup with staged `LEO_STEP` values.
3. Record the first stage at which `PBCH`, `SIB1`, `RACH`, or `RRC` regresses.
4. Once TN and NTN are both stable, use the handover tutorial as the basis for
   mobility orchestration and future TN to NTN load balancing.

## Excluded On Purpose

Generated artifacts were excluded to keep the repository small and suitable for
GitHub publication, including:

- Open5GS `artifacts/`
- Open5GS `install/`
- large build outputs
- OAI `cmake_targets/ran_build/`
- runtime logs

## References

- OAI NTN guide:
  - `openairinterface5g/doc/ntn-configuration.md`
- OAI handover guide:
  - `openairinterface5g/doc/handover-tutorial.md`
- OAI optional NR UE NTN options:
  - `openairinterface5g/doc/ntn-configuration.md#optional-nr-ue-command-line-options`
