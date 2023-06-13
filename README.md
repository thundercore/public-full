# How to Run a Fullnode on ThunderCore Chain?

Copyright (C) 2017-2023 Thunder Token Ltd.

# Before Starting

## Suggested Requirements
* `4 cores of CPU` and `8 GB of memory (RAM)`.
* `500 GB` of free disk space.
* You need to open port `8545`, `8546`, `9201`.

## Pre-install
* Install Docker: https://docs.docker.com/engine/install/
* Install Docker-compose: https://docs.docker.com/compose/install/

# Quick Start
```
git clone https://github.com/thundercore/public-full.git
cd public-full

# Testnet
./run.sh -c testnet -t start

# Mainnet
./run.sh -c mainnet -t start
```
* This excution will download chain data. This may `take hours`.


# Quick Upgrade

Upgrade to latest version
```
git pull
./run.sh -c <mainnet|testnet> -t upgrade
# Do you want to upgrade from <CURRENT_VERSION> to <NEW_VERSION>?(y/n): y
```

# Manual Start

### 1. Environment Variables:

Provide a `.env` file.

- Testnet
```
CHAIN=testnet
IMAGE_VERSION=r4.1.3
RECOVER_CHAIN_DATA_URL=https://chaindata-backup-prod-venus-us-east-1.s3.amazonaws.com/venus-latest
```

- Mainnet
```
CHAIN=mainnet
IMAGE_VERSION=r4.1.3
RECOVER_CHAIN_DATA_URL=https://chaindata-backup-prod-zeus-us-east-1.s3.amazonaws.com/zeus-latest
```

Apply .env
```
source .env
```
* If you need `full archive` chain data, Please contact us.


### 2. Config Files
Copy from repo
```
git clone https://github.com/thundercore/public-full.git
cp -rp public-full/configs-template/${CHAIN}/ configs
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

### 4. Run a Fullnode

Provide a `docker-compose.yml` file.

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
      - ./data:/datadir
      - ./configs:/config/fastpath/pala
      - ./logs:/logs
    entrypoint: [ "/sbin/tini", "--", "/entrypoint.sh" ]
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
