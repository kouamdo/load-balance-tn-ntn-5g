# load-balance-tn-ntn-5g

Combined workspace for 5G TN/NTN validation work built around:

- `open5gs-2.7.7/`
- `openairinterface5g/`

This repository is intended to keep the source trees, local NTN validation
configuration, and orchestration scripts together in one place for publication
and collaboration.

## Included

- Open5GS source tree with local validation scripts and Open5GS runtime configs
- OpenAirInterface source tree with local NTN fixed-delay and LEO configs
- NTN validation helper documentation

## Excluded On Purpose

Generated artifacts were excluded to keep the repository small and suitable for
GitHub publication, including:

- Open5GS `artifacts/`
- Open5GS `install/`
- large build outputs
- OAI `cmake_targets/ran_build/`
- runtime logs

## Suggested Next Steps

1. Review the copied trees for any credentials or environment-specific files.
2. Initialize the remote GitHub repository as `public`.
3. Commit the combined workspace.
4. Push the repository.
