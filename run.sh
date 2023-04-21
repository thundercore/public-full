#!/bin/bash
set -e

usage() {
    echo -e "./$(basename "${0}") -c [mainnet/testnet] -t [start/upgrade/stop/down/clean-all/genkey]"
    echo -e " -b: specific boot nodes, string, using comma as a separator"
    echo -e "       ex: \"boot-public.thundercore.com:8888,boot-public-2.thundercore.com:8888\""
    echo -e "       default: boot-public.thundercore.com:8888(mainnet)"
    echo -e "                boot-public-testnet.thundercore.com:8888(testnet)"
    echo -e " -c: specific chain"
    echo -e "       mainnet: Thundercore mainnet"
    echo -e "       testnet: Thundercore testnet, default is testnet"
    echo -e "       custom: provide your own chain config under <public-full/configs-template/custom>"
    echo -e " -t: specific task" 
    echo -e "       start: start node"
    echo -e "       load-config: load default configs"
    echo -e "       force-reload-config: force reload default configs"
    echo -e "       upgrade: upgrade node to the latest version"
    echo -e "       force-upgrade: force upgrade node"
    echo -e "       stop: stop container"
    echo -e "       down: terminate container"
    echo -e "       restart: restart container"
    echo -e "       reload-chaindata: reload chaindata"
    echo -e "       clean-all: clean all config/chaindata/log"
    echo -e "       genkey: generate Stakin and Vote keys for validator"
    echo -e " -v: specific version, default is master"
    echo -e " "
    echo -e "Example:"
    echo -e "    Generate keys: ./$(basename "${0}") -c testnet -t genkey"
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
                echo "unknow argument"
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
    KEYSTORE_DIR="${DIR_PATH}/keystore"

    : "${CHAIN_NAME="testnet"}"
    : "${VERSION="master"}"

    if [[ "${CHAIN_NAME}" == "mainnet" ]] ; then
        : "${BOOT_NODE="boot-public.thundercore.com:8888"}"
    elif [[ "${CHAIN_NAME}" == "testnet" ]] ; then
        : "${BOOT_NODE="boot-public-testnet.thundercore.com:8888"}"
    elif [[ "${CHAIN_NAME}" == "custom" ]] && [[ "${BOOT_NODE}" == "" ]]  ; then
        echo "Please provide boot node with -b, or -h for help"
        exit 1
    fi
    if [[ -z ${TASK} ]]; then
        usage
        exit 1
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

check_chain_config(){
    OVERRIDE_FILE="${DIR_PATH}/configs/override.yaml"

    # 1. Check loggingId
    if grep '<YOUR_LOGGINGID>' "$OVERRIDE_FILE"; then
        read -p "Please provide a name/id for your validator (e.g. testnet-public-validator-david): " LOGGINGID
        sed -i "s#<YOUR_LOGGINGID>#${LOGGINGID}#g" "$OVERRIDE_FILE"
    fi

    # 2. Check bidder.rewardAddress
    if grep '<0xREWARD_ADDRESS_REPLACE_ME>' "$OVERRIDE_FILE"; then
        read -p "Please provide a address to get reward (e.g. 0x1234567890123456789012345678901234567890): " REWARD_ADDR
        sed -i "s#<0xREWARD_ADDRESS_REPLACE_ME>#${REWARD_ADDR}#g" "$OVERRIDE_FILE"
    fi

    # 3. Check bidder.amount
    if grep '<BID_AMOUNT_REPLACE_ME>' "$OVERRIDE_FILE"; then
        echo "[Hint] bid amount: "
        echo "  - amount >  0 : normal bid"
        echo "  - amount =  0 : bid 0 TT, lose election and then you can get all refund to stakin0"
        echo "  - amount = -1 : bid with default minBidAmount (1E+23 = 100,000 TT)"
        read -p "Please provide a bid amount (e.g 2E+23): " BID_AMOUNT
        sed -i "s#<BID_AMOUNT_REPLACE_ME>#${BID_AMOUNT}#g" "$OVERRIDE_FILE"
    fi
}

# Check and prepare chain config file
load_chain_config(){
    local boots boot_list
    if [[ -d "${CHAIN_CONFIG_DIR}" ]]; then
        ORI_IMAGE_VERSION=$(grep "^IMAGE_VERSION" "${DIR_PATH}/.env" | cut -d "=" -f 2 | xargs)
        NEW_IMAGE_VERSION=$(grep "^IMAGE_VERSION" "${DIR_PATH}/.env.example" | cut -d "=" -f 2 | xargs)

        read -p "Do you want to upgrade from ${ORI_IMAGE_VERSION} to ${NEW_IMAGE_VERSION}?(y/n): " FORCERELOAD

        if [[ "${FORCERELOAD}" == "y" ]]; then

            ORI_OVERRIDE_FILE="${DIR_PATH}/override-backup.yaml"
            OVERRIDE_FILE="${CHAIN_CONFIG_DIR}/override.yaml"

            cp -rp "${OVERRIDE_FILE}" "${ORI_OVERRIDE_FILE}"
            rm -rf "${CHAIN_CONFIG_DIR}"
            cp -rp "${DIR_PATH}/configs-template/${CHAIN}" "${CHAIN_CONFIG_DIR}"

            LOGGINGID=$(grep loggingId ${ORI_OVERRIDE_FILE} | cut -d ":" -f 2 | cut -d "#" -f 1 | xargs)
            REWARD_ADDR=$(grep rewardAddress ${ORI_OVERRIDE_FILE} | cut -d ":" -f 2 | xargs)
            BID_AMOUNT=$(grep "^  amount" ${ORI_OVERRIDE_FILE} | cut -d ":" -f 2 | xargs)

            sed -i "s#<YOUR_LOGGINGID>#${LOGGINGID}#g" "$OVERRIDE_FILE"
            sed -i "s#<0xREWARD_ADDRESS_REPLACE_ME>#${REWARD_ADDR}#g" "$OVERRIDE_FILE"
            sed -i "s#<BID_AMOUNT_REPLACE_ME>#${BID_AMOUNT}#g" "$OVERRIDE_FILE"

            echo_log "Force copy configs from configs-template"
        else
            exit 0
        fi
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

    check_chain_config
}

# Check and prepare chain date file
load_chain_data(){
    if [[ ! -d "${CHAIN_DATA_DIR}" ]]; then
        mkdir "${CHAIN_DATA_DIR}"
    fi
    if [[ "${1}" == "force" ]] || [[ ! -f "${CHAIN_DATA_DIR}/thunder/chaindata/CURRENT" ]]; then
        read -p "Download chaindata may take hours, start now? [y/n]: " DL_CHAIN_DATA
        if [[ "${DL_CHAIN_DATA}" == "y" ]] || [[ "${DL_CHAIN_DATA}" == "Y" ]]; then
            rm -rf "${CHAIN_DATA_DIR:?}/"* || true
            wget -q -O "${CHAIN_DATA_DIR}"/latest "${RECOVER_CHAIN_DATA_URL}"
            CHAINDATA_URL=$(cut -d , -f 1 "${CHAIN_DATA_DIR}"/latest)
            # MD5_CHECKSUM=$(cut -d , -f 2 "${CHAIN_DATA_DIR}"/latest)
            echo_log "Download and decompress chaindata from ${CHAIN_DATA_URL}"
            wget -cq "${CHAINDATA_URL}" -O - | tar -C "${CHAIN_DATA_DIR}" -zx
        else
            echo_log "Not ready to download chain data."
            exit 0
        fi
    fi
}

# Reload image version
reload_image_version(){
    ORI_IMAGE_VERSION=${IMAGE_VERSION}
    source "${DIR_PATH}/.env.example"
    sed -i "s#^IMAGE_VERSION=.*#IMAGE_VERSION=${IMAGE_VERSION}#g" "${DIR_PATH}/.env"
    source "${DIR_PATH}/.env"
    NEW_IMAGE_VERSION=${IMAGE_VERSION}
    echo_log "Reload image version from ${ORI_IMAGE_VERSION} to ${NEW_IMAGE_VERSION}"
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
    echo_log "Get code to the latest"
    git pull origin validator
}

# Generate stakin and vote keys
genkey(){
    if [[ ! -d "${KEYSTORE_DIR}" ]]; then
        mkdir "${KEYSTORE_DIR}"
    fi
    docker run -it -d --entrypoint /bin/sh --name thunder-genkey thundercore/thunder
    docker exec thunder-genkey sh -c './thundertool --noencrypt genvotekeys --num-keys 1; ./thundertool --noencrypt genstakeinkeys --num-keys 1'
    docker exec thunder-genkey sh -c 'cat /keys.json' > "${KEYSTORE_DIR}"/keys.json
    docker exec thunder-genkey sh -c './thundertool --noencrypt getkeys --num-keys 1 --key-type vote --output voter-keys.json --fs-srcdir .; cat voter-keys.json' > "${KEYSTORE_DIR}"/voter-keys.json
    docker exec thunder-genkey sh -c './thundertool --noencrypt getkeys --num-keys 1 --key-type stakein --output stakein-keys.json --fs-srcdir .; cat stakein-keys.json' > "${KEYSTORE_DIR}"/stakein-keys.json
    docker rm -f thunder-genkey
    chmod 400 ./keystore/*

    echo "Done. Please check ./keystore file."
}

main(){

    setup_parameter "$@"

    pushd "${DIR_PATH}" 1>/dev/null || return 1

    if [[ "${TASK}" == "genkey" ]]; then
        echo_log "Generate Stakin and Vote keys"
        genkey
        exit 0
    fi

    setup_env

    if [[ "${TASK}" == "start" ]]; then
        echo_log "Start chain"
        load_chain_config
        load_chain_data notForce
        load_docker_compose
        mkdir -p "${CHAIN_LOG_DIR}"
        docker-compose up -d
    elif [[ "${TASK}" == "load-config" ]]; then
        echo_log "Load configs"
        load_chain_config
        docker-compose restart
    elif [[ "${TASK}" == "upgrade" ]]; then
        echo_log "Upgrade chain config"
        get_code
        load_chain_config
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
