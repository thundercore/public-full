# How to run a Fullnode on Thunder Core Chain?

Copyright (C) 2017-2021 Thunder Core Inc.

## Before Starting
### Prerequisite
#### Install Docker

* Please follow https://docs.docker.com/engine/install/ to install `docker`

#### Install Docker-compose:

* Please follow https://docs.docker.com/compose/install/ to install `docker-compse`


## Preparation

### 1. Environment Variables:

* Provide a `.env` file.

```
## testnet
CHAIN=testnet
IMAGE_VERSION=R2.2
RECOVER_CHAIN_DATA_URL=https://chaindata-backup-prod-venus-us-east-1.s3.amazonaws.com/venus-latest

## mainnet
CHAIN=mainnet
IMAGE_VERSION=R2.2
RECOVER_CHAIN_DATA_URL=https://chaindata-backup-prod-zeus-us-east-1.s3.amazonaws.com/zeus-latest
```

* Source `.env` file.
```
source .env
```

### 2. Config File
```
cp -rp configs-template/${CHAIN} configs
```
* Modify `loggingId` with an identifiable in `configs/override.yaml`.


### 3. Chain Data
Please download the chain data snapshot and extract to speed up.
```
mkdir data
wget -q -O data/latest "${RECOVER_CHAIN_DATA_URL}"

CHAINDATA_URL=$(cut -d , -f 1 data/latest)
# MD5_CHECKSUM=$(cut -d , -f 2 data/latest)

# This may take hours.
wget -c "${CHAINDATA_URL}" -O - | tar -C data -zx
```


## Run a Fullnode

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


## Check chain workable
```
$ tail -f ./logs/thunder.verbose.log | grep process
```
The process number will increase rapidly.
