#!/bin/bash
set -e

usage() {
    echo -e "./$(basename "${0}") task(start/upgrade/stop/down/clean-all)"
    echo -e " "
    echo -e " start: start node"
    echo -e " upgrade: upgrade node"
    echo -e " stop: stop container"
    echo -e " down: terminate container"
    echo -e " clean-all: clean all config/chaindata/log"
}

echo_log() {
    echo "$(date +'%Y/%m/%d %T') : $*"
}

# Setup env
check_env() {
    if [[ "$(uname)" == "Darwin" ]] ; then
        DIR_PATH=$(cd "$(dirname "${0}")" || exit; pwd)
    else
        DIR_PATH=$(dirname "$(readlink -f "${0}")")
    fi

    CHAIN_DATA_DIR="${DIR_PATH}/data"
    CHAIN_CONFIG_DIR="${DIR_PATH}/configs"
    CHAIN_LOG_DIR="${DIR_PATH}/logs"
    DOCKER_COMPOSE_FILE="${DIR_PATH}/docker-compose.yml"

    # Check and prepare .env file
    if [[ ! -f "${DIR_PATH}/.env" ]]; then
        cp "${DIR_PATH}/.env.example" "${DIR_PATH}/.env"
        echo_log ".env copy from .env.example"
    fi
    source "${DIR_PATH}/.env"
}

# Check and prepare chain config file
load_chain_config(){
    if [[ -d "${CHAIN_CONFIG_DIR}" ]] && [[ "${1}" != "force" ]]; then
        :
    else
        cp -rp "${DIR_PATH}/configs-template/${CHAIN}" "${CHAIN_CONFIG_DIR}"
        echo_log "Configs copy from configs-template"
    fi
}

# Check and prepare chain date file
load_chain_data(){
    if [[ ! -d "${CHAIN_DATA_DIR}" ]]; then
        mkdir "${CHAIN_DATA_DIR}"
    fi
    if [[ ! -f "${CHAIN_DATA_DIR}/thunder/chaindata/CURRENT" ]]; then
        wget -q -O "${CHAIN_DATA_DIR}"/latest "${RECOVER_CHAIN_DATA_URL}"
        CHAINDATA_URL=$(cut -d , -f 1 "${CHAIN_DATA_DIR}"/latest)
        # MD5_CHECKSUM=$(cut -d , -f 2 "${CHAIN_DATA_DIR}"/latest)
        echo_log "Download and decompress chaindata from ${CHAIN_DATA_URL}"
        echo_log "It may take hours."
        wget -cq "${CHAINDATA_URL}" -O - | tar -C "${CHAIN_DATA_DIR}" -zx
    fi
}

# Reload image version
reload_image_version(){
    source "${DIR_PATH}/.env.example"
    sed -i "s/IMAGE_VERSION=.*/IMAGE_VERSION=${IMAGE_VERSION}/g" "${DIR_PATH}/.env"
    source "${DIR_PATH}/.env"
}

# Check and prepare docker-compose file
load_docker_compose(){
    if [[ ! -f "${DOCKER_COMPOSE_FILE}" ]]; then
        cp "${DIR_PATH}/docker-compose.yml.example" "${DOCKER_COMPOSE_FILE}"
        echo_log "docker-compose.yml copy from docker-compose.yml.example"
    fi
}

main(){
    if [ "${#}" != "1" ]; then
        usage
        exit 1
    fi

    check_env

    if [[ "${1}" == "start" ]]; then
        echo_log "Start chain"
        load_chain_config notForce
        load_chain_data
        load_docker_compose
        mkdir -p "${CHAIN_LOG_DIR}"
        docker-compose up -d
    elif [[ "${1}" == "upgrade" ]]; then
        echo_log "Upgrade chain"
        reload_image_version
        load_chain_config force
        docker-compose up -d
    elif [[ "${1}" == "stop" ]]; then
        echo_log "Stop container"
        docker-compose stop
    elif [[ "${1}" == "down" ]]; then
        echo_log "Terminate container"
        docker-compose down
    elif [[ "${1}" == "clean-all" ]]; then
        echo_log "Clean all"
        docker-compose down 2>/dev/null|| true
        rm -f "${DIR_PATH}/.env"
        rm -rf "${CHAIN_DATA_DIR}"
        rm -rf "${CHAIN_CONFIG_DIR}"
        rm -f "${DIR_PATH}/docker-compose.yml"
        rm -rf "${CHAIN_LOG_DIR}"
    else
        usage
        exit 1
    fi
    echo_log "Done"
}

main "$@"
