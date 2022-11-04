#!/bin/bash
set -e

usage() {
    echo -e "./$(basename "${0}") -c [mainnet/testnet] -t [start/upgrade/stop/down/clean-all]"
    echo -e " -b: specific boot nodes, string, using comma as a separator"
    echo -e "       ex: \"boot-public.thundercore.com:8888,boot-public-2.thundercore.com:8888\""
    echo -e "       default: boot-public.thundercore.com:8888(mainnet)"
    echo -e "                boot-public-testnet.thundercore.com:8888(testnet)"
    echo -e " -c: specific chain"
    echo -e "       mainnet: Thundercore mainnet"
    echo -e "       testnet: Thundercore testnet, default is testnet"
    echo -e " -t: specific task" 
    echo -e "       start: start node"
    echo -e "       load-config: load default configs"
    echo -e "       force-reload-config: force reload default configs"
    echo -e "       upgrade: upgrade node"
    echo -e "       force-upgrade: force upgrade node"
    echo -e "       stop: stop container"
    echo -e "       down: terminate container"
    echo -e "       restart: restart container"
    echo -e "       reload-chaindata: reload chaindata"
    echo -e "       clean-all: clean all config/chaindata/log"
    echo -e " -v: specific version, default is master"
    echo -e " "
    echo -e "Example:"
    echo -e "    Start mainnet node: ./$(basename "${0}") -c mainnet -t start"
    echo -e "    Stop testnet node: ./$(basename "${0}") -c testnet -t stop"
}

setup_parameter() {
    while getopts "b:c:t:v:h?" arg ; do
        case $arg in
            b)
                export BOOT_NODE=$OPTARG
                ;;
            c)
                export CHAIN_NAME=$OPTARG
                ;;
            t)
                export TASK=$OPTARG
                ;;
            v)
                export VERSION=$OPTARG
                ;;
            h)
                usage
                exit 0
                ;;
            ?)
                echo "unkonw argument"
                usage
                exit 1
                ;;
        esac
    done

    if [[ "$(uname)" == "Darwin" ]] ; then
        DIR_PATH=$(cd "$(dirname "${0}")" || exit; pwd)
    else
        DIR_PATH=$(dirname "$(readlink -f "${0}")")
    fi
    CHAIN_DATA_DIR="${DIR_PATH}/data"
    CHAIN_CONFIG_DIR="${DIR_PATH}/configs"
    CHAIN_LOG_DIR="${DIR_PATH}/logs"
    DOCKER_COMPOSE_FILE="${DIR_PATH}/docker-compose.yml"

    : "${CHAIN_NAME="testnet"}"
    : "${VERSION="master"}"

    if [[ "${CHAIN_NAME}" == "mainnet" ]] ; then
        : "${BOOT_NODE="boot-public.thundercore.com:8888"}"
    else
        : "${BOOT_NODE="boot-public-testnet.thundercore.com:8888"}"
    fi
    if [[ -z ${TASK} ]]; then
        usage
    fi
}

echo_log() {
    echo "$(date +'%Y/%m/%d %T') : $*"
}

# Setup env
##setup_env chain_name
setup_env() {
    # Check and prepare .env file
    if [[ ! -f "${DIR_PATH}/.env" ]]; then
        cp "${DIR_PATH}/.env.example" "${DIR_PATH}/.env"
        echo_log ".env copy from .env.example"
        set -x
        if [[ "${CHAIN_NAME}" == "mainnet" ]]; then
            source "${DIR_PATH}/.env.example"
            sed -i "s#^CHAIN=.*#CHAIN=${MAINNET_CHAIN}#g" "${DIR_PATH}/.env"
            sed -i "s#^IMAGE_VERSION=.*#IMAGE_VERSION=${MAINNET_IMAGE_VERSION}#g" "${DIR_PATH}/.env"
            sed -i "s#^RECOVER_CHAIN_DATA_URL=.*#RECOVER_CHAIN_DATA_URL=${MAINNET_RECOVER_CHAIN_DATA_URL}#g" "${DIR_PATH}/.env"
        else
            source "${DIR_PATH}/.env.example"
            sed -i "s#^CHAIN=.*#CHAIN=${TESTNET_CHAIN}#g" "${DIR_PATH}/.env"
            sed -i "s#^IMAGE_VERSION=.*#IMAGE_VERSION=${TESTNET_IMAGE_VERSION}#g" "${DIR_PATH}/.env"
            sed -i "s#^RECOVER_CHAIN_DATA_URL=.*#RECOVER_CHAIN_DATA_URL=${TESTNET_RECOVER_CHAIN_DATA_URL}#g" "${DIR_PATH}/.env"
        fi
    fi

    source "${DIR_PATH}/.env"
    if [[ "${CHAIN}" != "${CHAIN_NAME}" ]]; then
        echo ".env file existed, and it's chain is ${CHAIN}. EXIT!"
        exit 1
    fi
}

# Check and prepare chain config file
load_chain_config(){
    local boots boot_list
    if [[ -d "${CHAIN_CONFIG_DIR}" ]] && [[ "${1}" != "force" ]]; then
        echo_log "No need to reload Configs from configs-template"
    elif [[ "${1}" == "force" ]]; then
        rm -rf "${CHAIN_CONFIG_DIR}"
        cp -rp "${DIR_PATH}/configs-template/${CHAIN}" "${CHAIN_CONFIG_DIR}"
        echo_log "Force copy configs from configs-template"
    else
        cp -rp "${DIR_PATH}/configs-template/${CHAIN}" "${CHAIN_CONFIG_DIR}"
        echo_log "Copy configs from configs-template"
    fi

    boots=$(echo ${BOOT_NODE} | tr "," "\n")
    boot_list="[ "
    for boot in ${boots}; do
        boot_list+="\"${boot}\", "
    done
    boot_list="${boot_list:0:-2} ]"
    if ! type yq; then
        snap install yq
    fi
    yq ".pala.bootnode.trusted = ${boot_list}" < "${CHAIN_CONFIG_DIR}/override.yaml" > "${CHAIN_CONFIG_DIR}/override.yaml-tmp"
    mv "${CHAIN_CONFIG_DIR}/override.yaml-tmp" "${CHAIN_CONFIG_DIR}/override.yaml"
}

# Check and prepare chain date file
load_chain_data(){
    if [[ ! -d "${CHAIN_DATA_DIR}" ]]; then
        mkdir "${CHAIN_DATA_DIR}"
    fi
    if [[ "${1}" == "force" ]] || [[ ! -f "${CHAIN_DATA_DIR}/thunder/chaindata/CURRENT" ]]; then
        rm -rf "${CHAIN_DATA_DIR:?}/"* || true
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
    sed -i "s#^IMAGE_VERSION=.*#IMAGE_VERSION=${IMAGE_VERSION}#g" "${DIR_PATH}/.env"
    source "${DIR_PATH}/.env"
}

# Check and prepare docker-compose file
load_docker_compose(){
    if [[ ! -f "${DOCKER_COMPOSE_FILE}" ]]; then
        cp "${DIR_PATH}/docker-compose.yml.example" "${DOCKER_COMPOSE_FILE}"
        echo_log "docker-compose.yml copy from docker-compose.yml.example"
    fi
}

# Git pull new code
get_code() {
    echo_log "Get code. Version: ${VERSION}"
    if [[ $(git ls-remote --tags origin "refs/tags/${VERSION}") != "" ]]; then
        git fetch origin --tag "${VERSION}:refs/tags/${VERSION}"
        git checkout "${VERSION}"
    else
        if [[ $(git rev-parse --abbrev-ref HEAD) == "${VERSION}" ]]; then
            git pull origin "${VERSION}"
        elif git fetch origin "${VERSION}:${VERSION}"; then
            if git checkout "${VERSION}"; then
                git pull origin "${VERSION}"
            fi
        else
            git checkout "${VERSION}"
        fi
    fi
}

main(){

    setup_parameter "$@"

    pushd "${DIR_PATH}" 1>/dev/null || return 1

    setup_env

    if [[ "${TASK}" == "start" ]]; then
        echo_log "Start chain"
        load_chain_config notForce
        load_chain_data notForce
        load_docker_compose
        mkdir -p "${CHAIN_LOG_DIR}"
        docker-compose up -d
    elif [[ "${TASK}" == "load-config" ]]; then
        echo_log "Load configs"
        load_chain_config notForce
        docker-compose restart
    elif [[ "${TASK}" == "force-reload-config" ]]; then
        echo_log "Force reload configs"
        load_chain_config force
        docker-compose restart
    elif [[ "${TASK}" == "upgrade" ]]; then
        echo_log "Upgrade chain"
        # get_code
        load_chain_config notForce
        reload_image_version
        docker-compose up -d
    elif [[ "${TASK}" == "force-upgrade" ]]; then
        echo_log "Force upgrade chain"
        # get_code
        load_chain_config force
        reload_image_version
        docker-compose up -d
    elif [[ "${TASK}" == "stop" ]]; then
        echo_log "Stop container"
        docker-compose stop
    elif [[ "${TASK}" == "down" ]]; then
        echo_log "Terminate container"
        docker-compose down
    elif [[ "${TASK}" == "restart" ]]; then
        echo_log "Restart container"
        docker-compose restart
    elif [[ "${TASK}" == "reload-chaindata" ]]; then
        echo_log "Restart container"
        docker-compose down
        load_chain_data force
    elif [[ "${TASK}" == "clean-all" ]]; then
        echo_log "Clean all"
        docker-compose down 2>/dev/null || true
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
    popd 1>/dev/null || return 0
}

main "$@"
