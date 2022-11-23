# How to Run a Validator on ThunderCore Chain?

Copyright (C) 2017-2022 Thunder Token Ltd.

# Before Starting

## Suggested Requirements
* `4 cores of CPU` and `8 GB of memory (RAM)`.
* `500 GB` of free disk space.
* You need to open port `9201`.

## Pre-install
* Install Docker: https://docs.docker.com/engine/install/
* Install Docker-compose: https://docs.docker.com/compose/install/


## Prepare keys
### 1. Get code from github
```
git clone https://github.com/thundercore/public-full.git
git checkout validator
```

### 2. Prepare Stakin and Voter keys
```
git checkout validator
./run.sh -t genkey
```
* Create keys for Stakin and Voter and those files will be generated under `./keystore`

### 3. Get Stakin Address and Deposit  TT for Bid
```
cat ./keystore/stakein-keys.json | grep Addresses -A 2
```
* Deposit TT to the `Stakein` address which shows from previous step with `0x`. 
* Deposit amount shoud greater than `bid amount` for the gas fee.



# Quick Start
Testnet
```
./run.sh -c testnet -t start
```
Mainnet
```
./run.sh -c mainnet -t start
```
* This excution will download chain data. This may `take hours`.


# Quick Upgrade (Draft)
```
git pull origin validator
./run.sh -t force-upgrade
```


# Manual Start

### 1. Environment Variables:

Provide a `.env` file.

- Testnet
```
CHAIN=testnet
IMAGE_VERSION=r4.0.9
RECOVER_CHAIN_DATA_URL=https://chaindata-backup-prod-venus-us-east-1.s3.amazonaws.com/venus-latest
```

- Mainnet
```
CHAIN=mainnet
IMAGE_VERSION=r4.0.9
RECOVER_CHAIN_DATA_URL=https://chaindata-backup-prod-zeus-us-east-1.s3.amazonaws.com/zeus-latest
```

Apply .env
```
source .env
```
* If you need `full archive` chain data, Please contact us.


### 2. Config Files
Download Chain Config
```
wget https://github.com/thundercore/public-full/releases/download/${IMAGE_VERSION}-validator/${CHAIN}-validator-config-${IMAGE_VERSION}.tar.gz
tar -zxvf ${CHAIN}-config-${IMAGE_VERSION}.tar.gz
mv ${CHAIN} configs
```

Copy from repo
```
cp -rp configs-template/${CHAIN}/ configs
```

### 3. Chain Data
Download Chain Data
```
mkdir data
wget -q -O data/latest "${RECOVER_CHAIN_DATA_URL}"
CHAINDATA_URL=$(cut -d , -f 1 data/latest)
wget -c "${CHAINDATA_URL}" -O - | tar -C data -zx
```
* This step may take hours.

### 4. Run a Validator

Provide a `docker-compose.yml` file.

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
* It will be `fullnode` at first. Once the blocks synced, it will start bidding and try to become a `voter`.

2. If you are a validator, you will receive log with Notarization,
```
tail -f ./logs/thunder.verbose.log | grep reward

```
* Once you become a validator, you start to get reward in the the of the session. 


# Roadmap

🔨 = In Progress

🛠 = Feature complete. Additional testing required.

✅ = Feature complete


| Feature |  Status |
| ------- |  :------: |
| Testnet | 🛠 |
| Mainnet | 🛠 |
| Auto update bid amount | 🛠 |
