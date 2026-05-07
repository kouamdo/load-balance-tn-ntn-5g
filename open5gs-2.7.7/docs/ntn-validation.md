# Validation NTN OAI/Open5GS

Ce guide exécute le plan de validation `NTN` par paliers avec les profils déjà préparés côté OAI :

- `fixed delay` : pas de `channelmod`, délai fixe `20 ms`
- `LEO` : `SAT_LEO_TRANS` + options runtime NTN UE

## Pré-requis

- `mongod` installable/exécutable localement
- abonné UE provisionné en base :
  - `IMSI=2089900007487`
  - `K=fec86ba6eb707ed08905757b1bb44b8f`
  - `OPc=C42449363BBAD02B66D16BC975D77CC1`
  - `DNN=oai`
  - `SST=1`
- OAI construit dans `/home/ledoux/openairinterface5g/cmake_targets/ran_build/build`

## Scripts

- [start-5gc.sh](/home/ledoux/open5gs-2.7.7/start-5gc.sh)
- [stop-5gc.sh](/home/ledoux/open5gs-2.7.7/stop-5gc.sh)
- [ntn-validate.sh](/home/ledoux/open5gs-2.7.7/ntn-validate.sh)

## Phase A — Baseline `fixed delay`

1. Démarrer le core :
```bash
cd /home/ledoux/open5gs-2.7.7
./ntn-validate.sh core-start
```

2. Relancer OAI proprement :
```bash
./ntn-validate.sh oai-stop
./ntn-validate.sh gnb-start fixed
./ntn-validate.sh ue-start fixed
```

3. Évaluer les critères :
```bash
./ntn-validate.sh evaluate fixed
./ntn-validate.sh collect-logs fixed-baseline
```

Critères attendus :
- `Received NGSetupResponse from AMF`
- `pbch decoded successfully`
- `SIB1 decoded`
- activité `PRACH/RA/RRC`
- activité UE côté `AMF`

## Phase B — `LEO`

1. Repartir d’OAI propre :
```bash
./ntn-validate.sh oai-stop
```

2. Lancer gNB et UE en `LEO` :
```bash
./ntn-validate.sh gnb-start leo
./ntn-validate.sh ue-start leo
```

3. Évaluer :
```bash
./ntn-validate.sh evaluate leo
./ntn-validate.sh collect-logs leo-full
```

Par défaut, le profil `LEO` ajoute les options UE documentées par OAI :
- `--rfsimulator.[0].prop_delay 20`
- `--rfsimulator.[0].options chanmod`
- `--time-sync-I 0.1`
- `--ntn-initial-time-drift -46`
- `--initial-fo 57340`
- `--cont-fo-comp 2`

## Phase C — Réduction contrôlée `LEO`

Le script supporte `LEO_STEP` pour activer les options UE progressivement, en suivant la doc OAI :

- `leo-min`
  - `--rfsimulator.[0].prop_delay 20`
  - `--rfsimulator.[0].options chanmod`
- `leo-drift`
  - `leo-min`
  - `--time-sync-I 0.1`
  - `--ntn-initial-time-drift -46`
- `leo-fo`
  - `leo-drift`
  - `--initial-fo 57340`
- `leo-full`
  - `leo-fo`
  - `--cont-fo-comp 2`
- `leo-full-auto-ta`
  - `leo-full`
  - `--autonomous-ta`

Exemples :
```bash
LEO_STEP=leo-min ./ntn-validate.sh ue-start leo
LEO_STEP=leo-drift ./ntn-validate.sh ue-start leo
LEO_STEP=leo-fo ./ntn-validate.sh ue-start leo
LEO_STEP=leo-full ./ntn-validate.sh ue-start leo
LEO_STEP=leo-full-auto-ta ./ntn-validate.sh ue-start leo
```

## Logs capturés

`collect-logs` copie dans `artifacts/ntn-validation/<label>/` :

- `gnb.log`
- `ue.log`
- `amf.log`
- `smf.log`
- `upf.log`
- `nrf.log`

## Arrêt

```bash
./ntn-validate.sh oai-stop
./ntn-validate.sh core-stop
```
