# How to Run a Validator on ThunderCore Chain?

Copyright (C) 2017-2022 Thunder Token Ltd.

## Before Starting

### Suggested Requirements
* `4 cores of CPU` and `8 GB of memory (RAM)`.
* `500 GB` of free disk space.
* You need to open port `9201`.

### Pre-install
* Install Docker: https://docs.docker.com/engine/install/
* Install Docker-compose: https://docs.docker.com/compose/install/


## Prepare keys and configs
### 0. Get code from github
```
git clone https://github.com/thundercore/public-full.git
git checkout validator
```
### 1. Provide Your Logging ID
* Provide a name to identify your validator in `configs-template/<CHAIN>/override.yaml` and field `loggingId`

### 2. Provide Reward Address
* Provide a address to get reward in `configs-template/<CHAIN>/override.yaml` and field `bidder.rewardAddress`

### 3. Provide Bid Amount
* Provide a amount to bid as a validator in `configs-template/<CHAIN>/override.yaml` and field `bidder.amount`

### 4. Prepare Stakin and Voter keys
Create keys for Stakin and Voter.
```
git checkout validator
./run.sh -c [mainnet/testnet] -t genkey
```

Key files will be generated under `./keystore`

### 5. Get Stakin Address
```
cat ./keystore/stakein-keys.json | grep Addresses -A 2
```

### 6. Deposit TT
* Deposit TT to the `Stakein` address which shows from previous step with `0x`. 
* Deposit balance shoud greater than `bidder.amount` for the gas fee.


## Quick Start
* This excution will setup a validator.
  - **testnet**: `./run.sh -c testnet -t start`
  - **mainnet**: `./run.sh -c mainnet -t start`
* This excution will download chain data. This may **take hours**.
```
./run.sh -c mainnet -t start
```

## Quick Upgrade
```
git pull origin validator
./run.sh -t force-upgrade
```


## Manual Installation

### 1. Environment Variables:

* Provide a `.env` file.

Testnet
```
CHAIN=testnet
IMAGE_VERSION=r4.0.5
RECOVER_CHAIN_DATA_URL=https://chaindata-backup-prod-venus-us-east-1.s3.amazonaws.com/venus-latest
```

Mainnet
```
CHAIN=mainnet
IMAGE_VERSION=r4.0.5
RECOVER_CHAIN_DATA_URL=https://chaindata-backup-prod-zeus-us-east-1.s3.amazonaws.com/zeus-latest
```

* Source `.env` file.
* If you need **full archive** chain data, Please contact us.
```
source .env
```

### 2. Config Files
* Download from Github
```
wget https://github.com/thundercore/public-full/releases/download/${IMAGE_VERSION}/${CHAIN}-validator-config-${IMAGE_VERSION}.tar.gz
tar -zxvf ${CHAIN}-config-${IMAGE_VERSION}.tar.gz
mv ${CHAIN} configs
# cp -rp configs-template/${IMAGE_VERSION}/${CHAIN} configs # or you can copy from repo
```

### 3. Chain Data
* Download the chain data snapshot and extract.
```
mkdir data
wget -q -O data/latest "${RECOVER_CHAIN_DATA_URL}"

CHAINDATA_URL=$(cut -d , -f 1 data/latest)
# MD5_CHECKSUM=$(cut -d , -f 2 data/latest)

# This step may take hours.
wget -c "${CHAINDATA_URL}" -O - | tar -C data -zx
```


### Run a Validator

* Provide a `docker-compose.yml` file.

```
version: '3'

services:
  thunder-validator:
    container_name: thunder-validator
    image: thundercore/thunder:${IMAGE_VERSION}
    hostname: thunder-validator
    ports:
      - 9201:9201
    env_file:
      - ./.env
    environment:
      - CONFIG_PATH=/config/fastpath/pala
    volumes:
      - ./data:/datadir
      - ./configs:/config/fastpath/pala
      - ./logs:/logs
      - ./keystore:/keystore
    entrypoint: [ "/tini", "--", "/entrypoint.sh" ]
    restart: always
```
```
docker-compose up -d
```


## Check Validator Status

1. Check Log for curren role
```
tail -f ./logs/thunder.verbose.log | grep "I am"
```

2. If you are a validator, you will receive log with Notarization,
```
tail -f ./logs/thunder.verbose.log | grep onReceivedNotarization

```