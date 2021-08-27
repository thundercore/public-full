# How to Run a Fullnode on Thunder Core Chain?

Copyright (C) 2017-2021 Thunder Core Inc.

## Before Starting
### Prerequisite
* Install Docker: https://docs.docker.com/engine/install/
* Install Docker-compose: https://docs.docker.com/compose/install/

## Quick Installation
* This excution will setup a fullnode on **testnet**. If you want to run on **mainnet**, please update `.env.example` file.
* This excution will download chain data. This may **take hours**.
```
git clone https://github.com/thundercore/public-full.git
cd public-full
./start.sh
```

## Manual Installation
### Preparation

### 1. Environment Variables:

* Provide a `.env` file.

```
# Testnet
CHAIN=testnet
IMAGE_VERSION=R2.2
RECOVER_CHAIN_DATA_URL=https://chaindata-backup-prod-venus-us-east-1.s3.amazonaws.com/venus-latest

# Mainnet
CHAIN=mainnet
IMAGE_VERSION=R2.2
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
wget https://github.com/thundercore/public-full/releases/download/R2.2.0/${CHAIN}-config-R2.2.0.tar.gz
tar -zxvf ${CHAIN}-config-R2.2.0.tar.gz
mv ${CHAIN} configs
# cp -rp configs-template/${IMAGE_VERSION}/${CHAIN} configs # or you can copy from repo
```
* Modify `loggingId` with an identifiable in `configs/override.yaml`.


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


### Run a Fullnode

* Provide a `docker-compose.yml` file.

```
version: '3'

services:
  thunder-full:
    container_name: thunder-full
    image: thundercore/thunder:${IMAGE_VERSION}
    hostname: thunder-full
    ports:
      - 8545:8545
      - 8546:8546
      - 9201:9201
    env_file:
      - ./.env
    environment:
      - CONFIG_PATH=/config/fastpath/pala
    volumes:
      # - /var/log/nginx:/var/log/nginx
      - ./data:/datadir
      - ./configs:/config/fastpath/pala
      - ./logs:/logs
    entrypoint: [ "/tini", "--", "/entrypoint.sh" ]
    restart: always
```
```
docker-compose up -d
```


## Check Fullnode Status

1. Check Log
```
tail -f ./logs/thunder.verbose.log | grep process
```
* The process number will increase rapidly.

2. Check Chain ID from Local RPC
```
$ curl -s -X POST -H "Content-Type: application/json" \
       --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' 0.0.0.0:8545

# {"jsonrpc":"2.0","id":1,"result":"0x12"} # Testnet result
# {"jsonrpc":"2.0","id":1,"result":"0x6c"} # Mainnet result
```

3. Check Blocknumber
```
$ curl -s -X POST -H "Content-Type: application/json" \
       --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' 0.0.0.0:8545

# {"jsonrpc":"2.0","id":1,"result":"0x344368c"}
```
* You can compare result on https://scan.thundercore.com/ or https://scan-testnet.thundercore.com/
