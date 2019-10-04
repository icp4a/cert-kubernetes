#!/bin/bash

LVAR_SCRIPT_NAME="$(basename $0)"
LVAR_BAI_VERSION="3.2.0"
LVAR_LOCALHOST_IP=""

set -e

# Common script utilities
source ./utilities.sh

showHelp() {
    echo
    echo "--------------------------------------------------------------------------"
    echo "Update a Kafka release on minikube to advertise a new IP address."
    echo "--------------------------------------------------------------------------"
    echo "Prerequisites"
    echo "These files must be present in the same directory:"
    echo " - configuration/easy-install-kafka.yaml"
    echo
    echo "--------------------------------------------------------------------------"
    echo "Arguments:"
    echo "  -i <local machine IP address>"
    echo "      Mandatory. The remote IP address of your computer"
    echo
    echo "  -h"
    echo "      Displays this help."
    echo
    echo "Examples:"
    echo
    echo "  ./${LVAR_SCRIPT_NAME} -i 1.2.3.4"
    echo
    echo "---------------------------------------------------------------"
    exit 1
}
echo

while getopts hi: option;
do
    case ${option} in
        i)
            LVAR_LOCALHOST_IP=$OPTARG
            checkValidIP $LVAR_LOCALHOST_IP
            echo "Local machine IP address: $LVAR_LOCALHOST_IP"
            ;;
        h)
            showHelp
            ;;
        \?)
            echo "Invalid option: -${OPTARG}"
            exit 1
            ;;
    esac
done
echo

if [ -z "${LVAR_LOCALHOST_IP}" ]; then
    echo "ERROR: You must provide the external IP address of your computer...."
    showHelp
fi

checkFileExist "./configuration/easy-install-kafka.yaml"

echo "Initializing helm "
helm init --wait

echo "Tiller is $(which tiller)"

echo "Upgrading the Kafka installation with new IP address ${LVAR_LOCALHOST_IP}"
helm upgrade --wait --timeout 999999 --namespace kafka -f configuration/easy-install-kafka.yaml --set cp-kafka.customEnv.ADVERTISED_LISTENER_HOST=${LVAR_LOCALHOST_IP} kafka-release confluent/cp-helm-charts
