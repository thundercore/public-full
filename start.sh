#!/bin/bash
set -ex

if [ "$(uname)" == "Darwin" ] ; then
    DIR_PATH=$(cd "$(dirname "${0}")" || exit; pwd)
else
    DIR_PATH=$(dirname "$(readlink -f "${0}")")
fi

CHAIN_DATA_DIR="${DIR_PATH}/data"
CHAIN_CONFIG_DIR="${DIR_PATH}/configs"
DOCKER_COMPOSE_FILE="${DIR_PATH}/docker-compose.yml"

if [ ! -f "${DIR_PATH}/.env" ]; then
    cp "${DIR_PATH}/.env.example" "${DIR_PATH}/.env"
fi
source "${DIR_PATH}/.env"

if [ ! -f "${DOCKER_COMPOSE_FILE}" ]; then
    cp "${DIR_PATH}/docker-compose.yml.example" "${DOCKER_COMPOSE_FILE}"
fi

if [ ! -d "${CHAIN_DATA_DIR}" ]; then
    mkdir "${CHAIN_DATA_DIR}"
fi

if [ ! -f "${CHAIN_DATA_DIR}/thunder/chaindata/CURRENT" ]; then
    wget -q -O "${CHAIN_DATA_DIR}"/latest "${RECOVER_CHAIN_DATA_URL}"

    CHAINDATA_URL=$(cut -d , -f 1 "${CHAIN_DATA_DIR}"/latest)
    # MD5_CHECKSUM=$(cut -d , -f 2 "${CHAIN_DATA_DIR}"/latest)

    echo "Download and decompress chaindata"
    wget -cq "${CHAINDATA_URL}" -O - | tar -C "${CHAIN_DATA_DIR}" -zx
fi

if [ ! -d "${CHAIN_CONFIG_DIR}" ]; then
    cp -rp "${DIR_PATH}/configs-template/${CHAIN}" "${CHAIN_CONFIG_DIR}"
fi

docker-compose up -d